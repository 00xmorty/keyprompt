#!/bin/sh
# Local test suite for keyprompt. Requires macOS (codesign/security).
# Run: sh test/test_keyprompt.sh
set -u

cd "$(dirname "$0")/.." || exit 2
BIN=./keyprompt
fails=0

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }

expect_rc() { # name expected_rc actual_rc
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (want rc=$2, got rc=$3)"; fi
}

# 1. syntax
if zsh -n "$BIN" 2>/dev/null; then pass "zsh -n syntax"; else fail "zsh -n syntax"; fi

# 2. built-in unit tests
if "$BIN" --self-test >/dev/null 2>&1; then pass "--self-test"; else fail "--self-test"; fi

# 3. version + help
if "$BIN" --version | grep -q '^keyprompt '; then pass "--version"; else fail "--version"; fi
if "$BIN" --help | grep -q 'USAGE'; then pass "--help"; else fail "--help"; fi

# 4. JSON is valid and declares read-only
"$BIN" --json --no-color > /tmp/keyprompt_test.json 2>/dev/null
if python3 -c 'import json,sys; d=json.load(open("/tmp/keyprompt_test.json")); sys.exit(0 if d["read_only"] is True and len(d["results"])>0 else 1)' 2>/dev/null; then
  pass "--json valid + read_only"
else
  fail "--json valid + read_only"
fi

# 5. account names masked by default
if python3 -c 'import json,sys; d=json.load(open("/tmp/keyprompt_test.json")); sys.exit(0 if all(r["account"] in ("", "***") for r in d["results"]) else 1)' 2>/dev/null; then
  pass "account masked by default"
else
  fail "account masked by default"
fi

# 6. Apple-signed binary is stable (exit 0)
"$BIN" --only --no-service --service security >/dev/null 2>&1
expect_rc "apple-signed -> rc 0" 0 $?

# 7. ad-hoc signed binary is flagged (exit 1)
tmpdir=$(mktemp -d)
if cp /usr/bin/true "$tmpdir/adhocprobe" 2>/dev/null && codesign -f -s - "$tmpdir/adhocprobe" >/dev/null 2>&1; then
  PATH="$tmpdir:$PATH" "$BIN" --only --no-service --service adhocprobe >/dev/null 2>&1
  expect_rc "ad-hoc signed -> rc 1" 1 $?
  if PATH="$tmpdir:$PATH" "$BIN" --only --no-service --service adhocprobe 2>/dev/null | grep -q 'cdhash-drift\|UNSTABLE'; then
    pass "ad-hoc cause reported"
  else
    fail "ad-hoc cause reported"
  fi
else
  fail "could not create ad-hoc probe binary"
fi
rm -rf "$tmpdir"

# 8. bad argument -> rc 2
"$BIN" --definitely-not-a-flag >/dev/null 2>&1
expect_rc "unknown flag -> rc 2" 2 $?

# 9. never uses secret-reading keychain flags
if sed -e 's/[[:space:]]*#.*$//' "$BIN" | grep -Eq 'dump-keychain|security[^|]*-[a-zA-Z]*[gw]([[:space:]]|$)'; then
  fail "no secret-reading keychain flags"
else
  pass "no secret-reading keychain flags"
fi

printf '\n'
if [ "$fails" -eq 0 ]; then
  printf 'test suite: all checks passed\n'
  exit 0
fi
printf 'test suite: %s failure(s)\n' "$fails"
exit 1
