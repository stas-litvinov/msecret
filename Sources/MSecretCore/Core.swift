// SPDX-License-Identifier: Apache-2.0
import Foundation
import Security

public struct SecretError: Error, CustomStringConvertible {
    public let description: String
    public init(_ message: String) { description = message }
}
public func validateName(_ name: String) throws {
    guard name.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) == name.startIndex..<name.endIndex else {
        throw SecretError("Names must be environment variable identifiers, such as OPENAI_API_KEY.")
    }
}
public enum Command: Equatable {
    case help, version, list, set(String), get(String), delete(String), run([String], [String])
    public static func parse(_ args: [String]) throws -> Command {
        guard let verb = args.first else { return .help }
        switch verb {
        case "help", "--help", "-h": guard args.count == 1 else { break }; return .help
        case "--version": guard args.count == 1 else { break }; return .version
        case "list": guard args.count == 1 else { break }; return .list
        case "set", "get", "delete":
            guard args.count == 2 else { break }
            try validateName(args[1])
            if verb == "set" { return .set(args[1]) }
            if verb == "get" { return .get(args[1]) }
            return .delete(args[1])
        case "run":
            guard let separator = args.firstIndex(of: "--"), separator > 1, separator < args.count - 1 else { break }
            let names = Array(args[1..<separator])
            for name in names { try validateName(name) }
            guard Set(names).count == names.count else { throw SecretError("Duplicate secret names.") }
            return .run(names, Array(args[(separator + 1)...]))
        default: break
        }
        throw SecretError("Invalid arguments. Run msecret --help. Never pass a secret value as an argument.")
    }
}
public struct KeychainStore {
    private let service: String
    public init(service: String = "dev.msecret") { self.service = service }
    private func query(_ name: String? = nil) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrSynchronizable as String: false]
        if let name = name { q[kSecAttrAccount as String] = name }
        return q
    }
    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw SecretError("Secret not found in msecret's Keychain namespace.") }
            throw SecretError("Keychain error (\(status)): \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")")
        }
    }
    public func set(_ name: String, value: String) throws {
        try validateName(name)
        guard !value.isEmpty, !value.utf8.contains(0) else { throw SecretError("Secret must be nonempty and contain no NUL bytes.") }
        let data = Data(value.utf8)
        let status = SecItemUpdate(query(name) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query(name)
            q[kSecValueData as String] = data
            try check(SecItemAdd(q as CFDictionary, nil))
        } else { try check(status) }
    }
    public func get(_ name: String) throws -> String {
        try validateName(name)
        var q = query(name)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        try check(SecItemCopyMatching(q as CFDictionary, &result))
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8), !value.utf8.contains(0) else { throw SecretError("Secret is not valid environment text.") }
        return value
    }
    public func delete(_ name: String) throws {
        try validateName(name)
        try check(SecItemDelete(query(name) as CFDictionary))
    }
    public func list() throws -> [String] {
        var q = query()
        q[kSecReturnAttributes as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        try check(status)
        guard let items = result as? [[String: Any]] else { throw SecretError("Unexpected Keychain response.") }
        return items.compactMap { $0[kSecAttrAccount as String] as? String }.sorted()
    }
}
