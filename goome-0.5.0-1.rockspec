package = "goome"
version = "0.5.0-1"
source = {
  url = "git+https://github.com/goome-ui/lua-goome.git",
  tag = "v0.5.0",
}
description = {
  summary = "Overlays on top of everything, normal desktop apps, or ui inside your game",
  detailed = "goome for Lua 5.4 and LuaJIT. A see through overlay where only what you drew takes clicks, plus app windows, offscreen frames for engines, drawing, fonts, images and an immediate mode ui kit. One C module, no dependencies.",
  homepage = "https://github.com/goome-ui/lua-goome",
  license = "GPL-3.0",
}
dependencies = {
  "lua >= 5.1",
}
build = {
  type = "builtin",
  modules = {
    goome = {
      sources = {"native/goome_lib.c", "src/lgoome.c"},
      incdirs = {"native", "src"},
    },
  },
}
