#!/usr/bin/env bash
set -euo pipefail
out="${1:?usage: tools/lua.sh <folder>}"
lua_ver="${LUA_VERSION:-5.4.8}"
jit_ref="${LUAJIT_REF:-63c8f1a9b479ba5518cf6a170ff7729178bc3cfd}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
work="$out/src"
mkdir -p "$work"
cd "$work"
os="$(uname -s)"
cc="${CC:-cc}"
mk=make
case "$os" in
MINGW* | MSYS* | CYGWIN*) win=1; cc="${CC:-gcc}"; command -v make >/dev/null || mk=mingw32-make ;;
*) win=0 ;;
esac
if [ ! -d "lua-$lua_ver" ]; then
  curl -fsSL "https://www.lua.org/ftp/lua-$lua_ver.tar.gz" | tar xz
fi
mkdir -p "$out/54/include"
(
  cd "lua-$lua_ver/src"
  if [ "$win" = 1 ]; then
    core=$(ls *.c | grep -v -e '^lua\.c$' -e '^luac\.c$')
    "$cc" -O2 -DLUA_BUILD_AS_DLL -shared -o "$out/54/lua54.dll" $core
    "$cc" -O2 -o "$out/54/lua.exe" lua.c "$out/54/lua54.dll"
  elif [ "$os" = Darwin ]; then
    "$mk" -s macosx
    cp lua "$out/54/lua"
  else
    "$mk" -s linux MYCFLAGS=-fPIC
    cp lua "$out/54/lua"
  fi
  cp lua.h luaconf.h lualib.h lauxlib.h lua.hpp "$out/54/include/"
)
if [ ! -d "LuaJIT-$jit_ref" ]; then
  curl -fsSL "https://github.com/LuaJIT/LuaJIT/archive/$jit_ref.tar.gz" | tar xz
fi
mkdir -p "$out/jit/include"
(
  cd "LuaJIT-$jit_ref"
  if [ "$os" = Darwin ]; then export MACOSX_DEPLOYMENT_TARGET=11.0; fi
  "$mk" -s -C src CC="$cc"
  if [ "$win" = 1 ]; then
    cp src/luajit.exe src/lua51.dll "$out/jit/"
  else
    cp src/luajit "$out/jit/luajit"
  fi
  mkdir -p "$out/jit/jit"
  cp src/jit/*.lua "$out/jit/jit/"
  cp src/lua.h src/luaconf.h src/lualib.h src/lauxlib.h src/luajit.h "$out/jit/include/"
)
echo "lua $lua_ver and luajit ${jit_ref:0:10} are in $out"
