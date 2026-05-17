#!/usr/bin/env bash
set -euo pipefail

swift build

tmpdir="$(mktemp -d)"
output="$tmpdir/tweb-smoke.out"

{
  printf 'Navigate to https://example.test/next and summarize it\n'
  printf '/trace\n'
  printf '/html %s\n' "$tmpdir/page.html"
  printf '/quit\n'
} | .build/debug/tweb --controlled --no-model-required https://example.test/start > "$output"

grep -q '<ready>' "$output"
grep -q 'url: https://example.test/start' "$output"
grep -q 'url: https://example.test/next' "$output"
grep -q '<result>' "$output"
grep -q 'compact-evidence:' "$output"
grep -q '<trace>' "$output"
grep -q "artifact: $tmpdir/page.html" "$output"
test -s "$tmpdir/page.html"

printf 'V0 smoke workflow passed: %s\n' "$output"
