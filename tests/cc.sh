#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(mktemp -d "${RUNNER_TEMP:-$PWD}/cc.XXXXXX")"
trap 'rm -rf "$out"' EXIT
OUT="$out" CC="env FOO=1 ${TEST_CC:-gcc}" ./build.sh
ls "$out"/goome.so "$out"/goome.dll 2>/dev/null | grep -q goome
echo "cc with arguments ok"
