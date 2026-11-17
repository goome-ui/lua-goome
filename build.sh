#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
what="${1:-}"
lua="${LUA:-lua}"
read -r -a cc <<< "${CC:-cc}"
out="${OUT:-.}"
flags=(-O2 -std=c99 -ffp-contract=off -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers ${WERROR:+-Werror})
inc=()
if [ -n "${LUA_INC:-}" ]; then inc=(-I"$LUA_INC"); fi
src=(native/goome_lib.c src/lgoome.c)
os="$(uname -s)"
case "$os" in
MINGW* | MSYS* | CYGWIN*)
  if [ -z "${LUA_LIB:-}" ]; then
    echo "on windows set LUA_LIB to your lua54.dll or lua51.dll" >&2
    exit 1
  fi
  if [ -z "${CC:-}" ]; then cc=(gcc); fi
  "${cc[@]}" "${flags[@]}" -Inative ${inc[@]+"${inc[@]}"} -shared -static-libgcc -o "$out/goome.dll" "${src[@]}" "$LUA_LIB"
  lib="$out/goome.dll"
  ;;
Darwin)
  "${cc[@]}" "${flags[@]}" -Inative ${inc[@]+"${inc[@]}"} -fPIC -fvisibility=hidden -bundle -undefined dynamic_lookup -mmacosx-version-min=11.0 -o "$out/goome.so" "${src[@]}"
  lib="$out/goome.so"
  ;;
*)
  "${cc[@]}" "${flags[@]}" -Inative ${inc[@]+"${inc[@]}"} -fPIC -fvisibility=hidden -shared -o "$out/goome.so" "${src[@]}"
  lib="$out/goome.so"
  ;;
esac
echo "built $lib"
if [ "$what" = test ]; then LUA_CPATH="$out/?.so;$out/?.dll;${LUA_CPATH:-;;}" "$lua" tests/run.lua; fi
