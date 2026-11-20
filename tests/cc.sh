#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(mktemp -d "${RUNNER_TEMP:-$PWD}/cc.XXXXXX")"
trap 'rm -rf "$out"' EXIT
OUT="$out" CC="env FOO=1 ${TEST_CC:-gcc}" ./build.sh
echo "cc with arguments ok"
