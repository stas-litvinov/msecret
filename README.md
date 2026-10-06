# msecret

A minimal macOS Keychain CLI for storing and using developer secrets safely.

`msecret` keeps secret values in macOS Keychain and injects selected values into a command's environment. No third-party runtime dependencies, configuration files, or provider-specific integrations.

## Requirements and installation

- macOS 12 or newer
- Swift 5.9 or newer (Xcode or compatible Command Line Tools)

```sh
git clone https://github.com/stas-litvinov/msecret.git
cd msecret
./install.sh
```

The installer builds locally and copies the binary to `~/.local/bin`. Add that directory to your shell's `PATH` if needed:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Use `PREFIX=/your/prefix ./install.sh` for another installation location. Keep the installed binary at a stable path; macOS may prompt for Keychain access after rebuilding or replacing it.

## Usage

```sh
msecret set OPENAI_API_KEY
msecret list
msecret run OPENAI_API_KEY -- your-command
msecret run OPENAI_API_KEY ANTHROPIC_API_KEY -- your-command arg
msecret get OPENAI_API_KEY
msecret delete OPENAI_API_KEY
```

`set` reads a nonempty, single-line UTF-8 value from the controlling terminal with echo disabled. It creates or replaces the item. Secret values are never accepted as arguments or piped input. Use Enter to submit or Ctrl-C to cancel. Values are limited to 4095 UTF-8 bytes.

`list` prints sorted names, never values. Names must match `[A-Za-z_][A-Za-z0-9_]*`.

`get` deliberately prints a value to standard output, including a trailing newline. Terminal recording, redirected output, and logs can expose it. Prefer `run` for day-to-day use.

`run` retrieves every selected secret before starting the command, replaces matching inherited environment variables, and preserves other variables. Arguments after `--` are passed literally without shell expansion. The process is replaced with the command, preserving its exit status and signals. Commands must be executable binaries or scripts with a shebang; shell functions and aliases require an explicit shell.

```sh
msecret run MY_TOKEN -- sh -c 'your-command "$MY_TOKEN"'
```

If the command itself passes a secret as an argument or prints it, that can expose the value. Prefer tools that read secrets directly from their environment.

## Storage and security boundaries

Items are generic passwords with service `dev.msecret` and account equal to the secret name. The CLI uses Apple's Security framework directly; values are never passed to the `security` command or written to project files. It requests non-synchronizing items and uses the user's default Keychain and its normal access controls. Keychain access may trigger a macOS authorization prompt.

This is a local developer convenience tool. Child processes and their descendants receive selected values in their environment; debugging tools, privileged software, or compromised processes may read them. Values exist in process memory and are not guaranteed to be securely erased. It does not protect against a compromised user account or machine, and does not provide team sharing, rotation, auditing, or recovery.

Secret names are metadata, not encrypted application data. Do not store sensitive information in names. Keychain backup and migration follow your macOS configuration; cloning this repository does not restore your secrets.

The `.gitignore` excludes common local environment files as a precaution. It cannot prevent committing secrets in other files or removing them from Git history.

## Development

```sh
swift test
swift build -c release
```

The default tests validate argument handling without accessing Keychain. To run the integration test explicitly on your own Mac:

```sh
MSECRET_KEYCHAIN_TESTS=1 swift test
```

That test uses dummy values in a unique `dev.msecret.tests.<UUID>` namespace and cleans up its item. It never reads production secrets. A Keychain prompt may appear; interruption can leave a dummy test item to remove in Keychain Access.

Contributions are welcome through issues and pull requests. Use dummy values in examples, tests, screenshots, and reports. Do not publish real credentials in issues.

## Uninstall

Remove the installed binary from your chosen prefix. Stored Keychain items remain; delete them with `msecret delete NAME` before uninstalling if desired.

## License

Copyright 2026 Stas Litvinov. Licensed under the [Apache License 2.0](LICENSE).
