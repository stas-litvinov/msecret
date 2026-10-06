// SPDX-License-Identifier: Apache-2.0
import Foundation
import Darwin
import MSecretCore

let help = """
msecret — developer secrets in macOS Keychain

Usage:
  msecret set NAME                     Hidden interactive input; creates or replaces
  msecret get NAME                     Prints the value to stdout
  msecret delete NAME                  Deletes a stored secret
  msecret list                         Prints names only
  msecret run NAME [NAME ...] -- COMMAND [ARG ...]
  msecret --help
  msecret --version

Values are never accepted as command-line arguments.
"""
func hiddenInput() throws -> String {
    // libc restores echo and handles terminal signals, including Ctrl-C.
    var buffer = [CChar](repeating: 0, count: 4097)
    defer { buffer.withUnsafeMutableBytes { _ = memset($0.baseAddress!, 0, $0.count) } }
    let value: String? = buffer.withUnsafeMutableBufferPointer { bytes in
        guard readpassphrase("Secret (hidden): ", bytes.baseAddress!, bytes.count, RPP_REQUIRE_TTY) != nil else { return nil }
        return String(validatingUTF8: bytes.baseAddress!)
    }
    guard let terminator = buffer.firstIndex(of: 0), buffer.dropFirst(terminator).allSatisfy({ $0 == 0 }) else { throw SecretError("Secret contains NUL bytes.") }
    guard let value = value, !value.isEmpty else { throw SecretError("set requires nonempty UTF-8 input from an interactive terminal.") }
    guard value.utf8.count < 4096 else { throw SecretError("Secret is too long (maximum 4095 UTF-8 bytes).") }
    return value
}
func execute(_ command: [String], environment: [String: String]) throws -> Never {
    let arguments = command.map { strdup($0) }
    let variables = environment.sorted { $0.key < $1.key }.map { strdup("\($0.key)=\($0.value)") }
    defer { arguments.forEach { free($0) }; variables.forEach { free($0) } }
    var argv = arguments + [nil]
    var envp = variables + [nil]
    let executable = command[0]
    let candidates = executable.contains("/") ? [executable] : (environment["PATH"] ?? "/usr/bin:/bin").components(separatedBy: ":").map { ($0.isEmpty ? "." : $0) + "/" + executable }
    var failure: Int32 = ENOENT
    for path in candidates {
        argv.withUnsafeMutableBufferPointer { a in
            envp.withUnsafeMutableBufferPointer { e in
                _ = execve(path, a.baseAddress!, e.baseAddress!)
            }
        }
        if errno == EACCES { failure = EACCES }
        else if errno != ENOENT && errno != ENOTDIR { failure = errno; break }
    }
    throw SecretError("Cannot execute command: \(String(cString: strerror(failure)))")
}
do {
    let store = KeychainStore()
    switch try Command.parse(Array(CommandLine.arguments.dropFirst())) {
    case .help: print(help)
    case .version: print("msecret 0.1.0")
    case .list: for name in try store.list() { print(name) }
    case .set(let name): try store.set(name, value: hiddenInput()); print("Stored \(name).")
    case .get(let name): print(try store.get(name))
    case .delete(let name): try store.delete(name); print("Deleted \(name).")
    case .run(let names, let command):
        var environment = ProcessInfo.processInfo.environment
        for name in names { environment[name] = try store.get(name) }
        try execute(command, environment: environment)
    }
} catch {
    fputs("msecret: \(error)\n", stderr)
    exit(1)
}
