# Security Policy

## Design guarantees

`keyprompt` is a read-only diagnostic. It is built so that running it cannot leak or change keychain state:

- No write operations: it never calls `security add-*`, `delete-*`, `set-*`, and never executes a repair command.
- No secret access: it does not use `security -g` / `-w` / `dump-keychain`, so it never decrypts item data.
- No privilege escalation: no `sudo`, no authorization prompts, no network access, no telemetry.
- Privacy: keychain account names are masked (`***`) by default; `--show-account` is opt-in.
- It reads only local metadata: signature classes via `codesign -dv` and item attributes via
  `security find-generic-password -s <service>` (attributes only, no password prompt).

## Reporting a vulnerability

Open a private security advisory on this repository
(https://github.com/00xmorty/keyprompt/security/advisories/new) or email the maintainer listed in the
repository profile. Please do not open a public issue for a vulnerability that would expose a secret or
a user's keychain metadata.

Include: affected version, macOS version, exact command, expected vs actual behaviour, and whether any
prompt appeared. Never include real credentials, account names, or captured item data in a report.

## Out of scope

- Prompts caused by a bug in a third-party app's own keychain handling. `keyprompt` diagnoses and explains
  the class of cause; it does not patch other vendors' binaries.
- Recovering a forgotten keychain password.
- Any behaviour that requires modifying the partition list — that command is intentionally left to the user.
