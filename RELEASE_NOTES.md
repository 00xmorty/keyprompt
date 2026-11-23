# keyprompt v0.1.0 — 2026-11-23

First public release. A read-only CLI that explains why macOS keeps asking for a keychain password.

## What it does

- Scans a built-in list of keychain consumers (`gh`, Claude Code CLI, Copilot CLI, Docker credential helper),
  plus any binary you add with `--service BIN=SERVICE`.
- Reports each consumer's signature class: `adhoc`, `developer-id`, `apple`, `unsigned`, or `missing`.
- Reads keychain item **metadata only** (existence, creation date) — no decryption, no password prompt.
- Names the likely root cause:
  - `cdhash-drift` — ad-hoc/linker-signed writer, partition list stores a cdhash that changes every rebuild
  - `teamid-or-acl` — stable Developer ID signature, so a repeat means a team-ID or ACL mismatch
  - `policy` — Apple-signed component
- Prints the repair command **without running it**.

## Options

`--json`, `--only`, `--service BIN=SERVICE`, `--no-service`, `--show-account`, `--explain`, `--self-test`,
`--version`, `--help`.

Exit codes: `0` no unstable consumer, `1` unstable consumer found, `2` usage/environment error.

## Verified on

- macOS 26.6.2 (Tahoe), Apple Silicon (`arm64`)

Real diagnosis from the development host: `gh` (Homebrew) reported `adhoc` + `TeamIdentifier=not set`
with a `gh:github.com` item created 2026-02-10; `claude` reported `developer-id` team `Q6L2SF6YDW`;
`copilot` reported `developer-id` team `VEKTX9H2N7` — the two-team mismatch pattern that makes the prompt loop.

## Safety

Read-only, no `sudo`, no telemetry, no network. Never uses `security -g`, `-w` or `dump-keychain`.
Account names masked unless `--show-account`. Repair commands are printed, never executed.

## Known limitations

- Cannot read the stored partition list (that would require the keychain password), so it reports
  evidence and the most likely cause rather than certainty.
- The consumer list is a starting point; extend it with `--service`.
- No stable fix exists for an ad-hoc signed binary — that requires a Developer ID signature upstream.
- macOS only.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/00xmorty/keyprompt/main/keyprompt -o /usr/local/bin/keyprompt
chmod +x /usr/local/bin/keyprompt
keyprompt
```
