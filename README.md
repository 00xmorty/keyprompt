# keyprompt

**Why does macOS keep asking for my keychain password — and which binary is to blame?**

`keyprompt` is a small read-only CLI that explains a repeating macOS keychain prompt
(`"claude" wants to use your confidential information stored in "Claude Code-credentials" in your keychain`)
by reporting the **signature class of every local binary that owns such an item** and naming the
most likely cause. It never asks for your password, never decrypts a secret, and never changes anything.

```
$ keyprompt

gh (/opt/homebrew/bin/gh)
  service   : gh:github.com — GitHub CLI credential per host (gh auth login)
  item      : present (created 2026-02-10) account=***
  signature : adhoc team=not set id=a.out
  verdict   : UNSTABLE — ad-hoc (linker-signed) binary: the partition list can only store this build's cdhash
  fix       : No stable repair exists for this binary. Rebuild/reinstall it with a Developer ID
              signature (team ID), or accept the prompt after each update.

claude (/opt/homebrew/bin/claude)
  service   : Claude Code-credentials — Claude Code CLI OAuth credential
  item      : present (created 2026-03-08) account=***
  signature : developer-id team=Q6L2SF6YDW id=com.anthropic.claude-code
  verdict   : stable — signed by team Q6L2SF6YDW: identity is stable, so a repeating prompt
              means a team-ID or ACL mismatch

Summary: at least one keychain consumer has an unstable signature — a repeating prompt is expected.
Nothing was modified. keyprompt is read-only.
```

## The problem it diagnoses

A keychain item carries a **partition list**: the signing identities that may read it without asking.
macOS writes the *current* identity of the writer into that list:

- a **Developer ID** build writes `teamid:<TEAM>` — stable across updates
- an **ad-hoc / linker-signed** build writes the raw **cdhash** — different after every rebuild

So the prompt comes back in two distinct situations:

1. **cdhash drift** — the writer is ad-hoc signed (typical for Homebrew and npm-distributed CLIs).
   Every `brew upgrade` produces a new cdhash, and yesterday's trust no longer covers today's binary.
2. **team-ID mismatch** — the same item is written by two builds of different teams
   (for example a GitHub-built and a Microsoft-built CLI), so each one invalidates the other.

`keyprompt` separates these two cases instead of guessing, and points at the binary responsible.

## Install

Single file, no dependencies beyond macOS system tools (`codesign`, `security`, `sed`):

```sh
curl -fsSL https://raw.githubusercontent.com/00xmorty/keyprompt/main/keyprompt -o /usr/local/bin/keyprompt
chmod +x /usr/local/bin/keyprompt
keyprompt --version
```

Or clone and run it in place:

```sh
git clone https://github.com/00xmorty/keyprompt.git
cd keyprompt
./keyprompt
```

## Usage

```sh
keyprompt                       # scan the built-in consumer list
keyprompt --json                # machine-readable
keyprompt --service "mytool=my-service-name"   # add your own binary/service pair (repeatable)
keyprompt --only --service security            # ignore the built-in list
keyprompt --no-service          # signature analysis only (no keychain item probe)
keyprompt --show-account        # include item account names (masked by default)
keyprompt --explain             # print the mechanism behind the verdicts
keyprompt --self-test           # built-in parser/verdict tests
```

Exit codes: `0` no unstable consumer found, `1` at least one ad-hoc/unsigned consumer, `2` usage error.

Example JSON record:

```json
{"binary":"gh","path":"/opt/homebrew/bin/gh","service":"gh:github.com","item":"present",
 "created":"2026-02-10","account":"***","signature_class":"adhoc","team_id":"not set",
 "identifier":"a.out","stability":"unstable","cause":"cdhash-drift"}
```

## Safety

- **Read-only.** No keychain writes, no `defaults` changes, no `sudo`, no network, no telemetry.
- **Never asks for your password** and never decrypts a secret: it does not use
  `security -g`, `security -w` or `dump-keychain`.
- **Privacy:** keychain item account names are masked (`***`) unless you pass `--show-account`.
  No output contains a stored secret; only item metadata (existence, creation date) is read.
- **Repair commands are printed, never executed.** Anything that would touch a partition list is
  shown for you to review, because that command legitimately needs your keychain password.

## Limitations

- It reports **evidence**, not certainty: reading an item's stored partition list requires decrypting
  the item, which requires the password you are trying not to type. `keyprompt` infers the cause from
  signature class and item presence.
- The built-in consumer list is a starting point (`gh`, Claude Code CLI, Copilot CLI, Docker credential
  helper). Extend it with `--service BIN=SERVICE`.
- No stable repair exists for an ad-hoc signed binary: the fix is a Developer ID signature upstream.
- macOS only. Linux and Windows have no equivalent keychain partition list.

## Development

```sh
zsh -n keyprompt          # syntax
./keyprompt --self-test   # parser + verdict unit tests
sh test/test_keyprompt.sh # full local suite
```

CI runs the suite on `macos-latest` (see `.github/workflows/ci.yml`).

## License

MIT. See [LICENSE](LICENSE).
