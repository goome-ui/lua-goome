<p align="center">
  <img src="https://raw.githubusercontent.com/goome-ui/.github/main/profile/logo.png" alt="goome" width="150">
</p>

<h1 align="center">🌙 lua-goome 🌙</h1>

<p align="center">
<b>Overlays on top of everything, normal desktop apps, or ui inside your game, straight from Lua.</b>
</p>

<p align="center">
  <img src="https://goome.wtf/badges/lua-54-luajit.svg" alt="Lua 5.4 + LuaJIT">
  <img src="https://goome.wtf/badges/love2d-ready.svg" alt="LOVE drop in">
  <img src="https://goome.wtf/badges/dependencies-none.svg" alt="no dependencies">
  <img src="https://img.shields.io/badge/Linux-X11%20%2B%20Wayland-1b1d22?style=flat-square&logo=linux&logoColor=white" alt="Linux">
  <img src="https://img.shields.io/badge/Windows-10%20%2F%2011-1b1d22?style=flat-square&logo=windows11&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/macOS-14%2B-1b1d22?style=flat-square&logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/license-GPL--3.0-1b1d22?style=flat-square" alt="GPL-3.0">
</p>

<p align="center">
  <a href="https://goome.wtf/docs/">Docs</a> &nbsp;·&nbsp;
  <a href="https://goome.wtf/builder/">Builder</a> &nbsp;·&nbsp;
  <a href="https://github.com/goome-ui/examples">Examples</a> &nbsp;·&nbsp;
  <a href="https://github.com/goome-ui/c-goome">C</a> &nbsp;·&nbsp;
  <a href="https://github.com/goome-ui/csharp-goome">C#</a> &nbsp;·&nbsp;
  <a href="https://github.com/goome-ui/python-goome">Python</a> &nbsp;·&nbsp;
  <a href="https://github.com/goome-ui/java-goome">Java</a> &nbsp;·&nbsp;
  <a href="https://github.com/goome-ui/godot-goome">Godot</a> &nbsp;·&nbsp;
  <a href="https://github.com/goome-ui/go-goome">Go</a> &nbsp;·&nbsp;
  <a href="https://github.com/goome-ui/zig-goome">Zig</a>
</p>

<p align="center">
  Questions go in <a href="https://github.com/goome-ui/c-goome/discussions">Discussions</a>. If you want to help, the <a href="https://github.com/goome-ui/lua-goome/labels/good%20first%20issue">good first issues</a> are small ones to start with.
</p>

<p align="center">
  This is <a href="https://github.com/goome-ui/c-goome">goome</a> for Lua. Draw over the whole screen and clicks only stop where you drew something.<br>
  It does app windows and offscreen frames for game engines too. It's one C module you <code>require</code>, built from goome.h and a small binding file, and it works the same on Lua 5.4 and LuaJIT.<br>
  That means it drops right into <a href="https://love2d.org/">LÖVE</a>, see below.<br> <br>
  Do you like this project? If so, please let me know!
  <a href="https://sevvy-wevvy.com/discord">Discord</a>
</p>

<h3 align="center">🫥 An overlay on top of everything 🫥</h3>

```lua
local goome = require("goome")

local g = assert(goome.open("my overlay"))
local running = true
while running do
  for ev in g:events(16) do
    if ev.type == goome.QUIT then running = false end
  end
  local c = g:begin(0)
  if c then
    c:round_rect(100, 100, 220, 60, 12, 0xE0202838)
    c:text(118, 120, "im on top of everything", 0xFFFFFFFF)
    c:hit(100, 100, 220, 60)
    g:finish(c)
  end
end
g:close()
```

<h3 align="center">🪟 A normal app 🪟</h3>

```lua
local goome = require("goome")

local app = goome.app("My app", 960, 640)
local name = ""

app:frame(function(ui)
  name = ui:input("Name", name)
  if ui:button("Say hi") then ui:toast("hi " .. name) end
end)

app:run()
```

<h3 align="center">🎮 Inside a game engine 🎮</h3>

```lua
local goome = require("goome")

local g = goome.open_offscreen(800, 600)
local ui = g:ui()
local win, volume = {x = 20, y = 20, w = 260}, 0.5
while true do
  g:push(goome.MOTION, {x = mouse_x, y = mouse_y})   -- your engines input goes in
  for ev in g:events(0) do ui:feed(ev) end
  if ui:begin(0) then
    if ui:window("Settings", win) then
      volume = ui:slider("Volume", volume)
    end
    ui:window_end()
    ui:finish()
  end
  local frame = g:last_frame()                       -- premultiplied BGRA pixels come out
  upload_texture(frame:ptr(), frame.w, frame.h)
end
```

<p align="center">
Overlay is still the default, nothing changes unless you ask for an app or offscreen. <code>end</code> is a Lua keyword, so the C <code>goome_end</code> and <code>goome_ui_end</code> are <code>g:finish(c)</code> and <code>ui:finish()</code> here.<br>
For mods inside other peoples games the other bindings are better, <a href="https://github.com/goome-ui/c-goome">c-goome</a> has the DirectX 9/11/12 and Vulkan backends plus Metal and GL, <a href="https://github.com/goome-ui/csharp-goome">csharp-goome</a> has Unity mod templates and <a href="https://github.com/goome-ui/java-goome">java-goome</a> does Fabric and NeoForge.
</p>

<details>
<summary align="center"><b>⬇️ Install ⬇️</b></summary>

<br>

<p align="center">
It isnt on the luarocks.org server, so <a href="https://luarocks.org/">LuaRocks</a> takes the rock from the <a href="https://github.com/goome-ui/lua-goome/releases">releases page</a>:
</p>

```sh
luarocks install https://github.com/goome-ui/lua-goome/releases/download/v0.5.5/goome-0.5.5-1.src.rock
```

<p align="center">
It builds the module with your C compiler, that takes a few seconds and only happens once. Add <code>--lua-version 5.1</code> for a LuaJIT tree. From a clone its <code>luarocks make goome-0.5.5-1.rockspec</code>.
</p>

<p align="center">
Or without LuaRocks, from a clone:
</p>

```sh
LUA_INC=/usr/include/lua5.4 ./build.sh test       # goome.so next to build.sh, then the tests
LUA_INC=/usr/include/luajit-2.1 LUA=luajit ./build.sh test
```

<p align="center">
On Linux and Mac the module never links against Lua, so one build works for any interpreter that matches the headers you built it with (5.4 headers for Lua 5.4, LuaJIT headers for LuaJIT and LÖVE).<br>
On Windows run it from git bash with mingw gcc and point <code>LUA_LIB</code> at your <code>lua54.dll</code> or <code>lua51.dll</code>, you get <code>goome.dll</code>.<br> <br>
If you don't have a compiler, on Debian/Ubuntu its <code>sudo apt install build-essential liblua5.4-dev</code>, on Mac <code>xcode-select --install</code>, on Windows <a href="https://www.mingw-w64.org/">mingw-w64</a>. <code>CC</code> picks a different one and <code>OUT</code> puts the module somewhere else.<br>
<code>tools/lua.sh lua-dist</code> builds Lua 5.4 and LuaJIT from source into <code>lua-dist/</code> if you just want something to test with, thats what CI does.
</p>
</details>

<details>
<summary align="center"><b>🚀 Quick Start 🚀</b></summary>

<br>

<p align="center">
A whole overlay that draws a box and prints clicks on it:
</p>

```lua
local goome = require("goome")

local g, err = goome.open("my overlay")
if not g then error("no overlay here: " .. err) end
local pace = goome.pacer(60)
local running = true
while running do
  for ev in g:events(pace:wait()) do
    if ev.type == goome.QUIT then running = false end
    if ev.type == goome.DOWN then print(string.format("clicked at %.0f,%.0f", ev.x, ev.y)) end
  end
  local c = g:begin(0)               -- monitor 0, nil when theres nothing to draw on
  if c then
    c:round_rect(100, 100, 200, 80, 12, 0xE0202838)
    c:text(116, 128, "click me", 0xFFFFFFFF, true)
    c:hit(100, 100, 200, 80)          -- only this part takes clicks
    g:finish(c)
  end
end
g:close()
```

<p align="center">
Colors are plain <code>0xAARRGGBB</code> numbers and every position is in logical desktop coords, same as in C.<br>
Things that can fail for a normal reason (no display, a file that isnt there, a combo that doesnt parse) give back <code>nil, message, code</code> like <code>io.open</code> does, so <code>assert(...)</code> works. Using something you already closed, or passing the wrong kind of thing, raises an error.<br>
Everything that holds native memory gets freed by the garbage collector, but <code>:close()</code> does it right away and closing twice is fine. On Lua 5.4 <code>local g &lt;close&gt; = assert(goome.open())</code> works too.
</p>
</details>

<details>
<summary align="center"><b>🎛️ UI Kit 🎛️</b></summary>

<br>

<p align="center">
The immediate mode ui works like in C, except widgets dont take pointers, they hand you the new value back. The second thing they return is if it changed this frame, like the int the C functions return. You keep your own variables and call the widgets every frame.
</p>

```lua
local goome = require("goome")

local g = assert(goome.open{title = "settings", no_capture = true})
local ui = g:ui()
local win = {x = 40, y = 40, w = 300, h = 0}      -- h 0 = fit the content
local logo = assert(goome.bitmap_load("logo.png"))
local volume, muted, name, changed = 0.5, false, "goome", false
local running = true
while running do
  for ev in g:events(16) do
    if ev.type == goome.QUIT then running = false end
    ui:feed(ev)
  end
  if ui:begin(0) then
    if ui:window("Settings", win, goome.WIN_MOVE + goome.WIN_COLLAPSE) then
      ui:image(logo, 64, 64, 12)
      if ui:button("Say hi") then print("hi") end
      volume, changed = ui:slider("Volume", volume, 0, 1, "%.2f")
      muted = ui:toggle("Muted", muted)
      name = ui:input("Name", name)
    end
    ui:window_end()
    ui:finish()
  end
end
```

<p align="center">
The window table keeps its spot, size and if its open between frames, goome writes into it. Set <code>win.open = false</code> to hide it, <code>WIN_CLOSE</code> gives it an x that does the same.<br>
Begins and ends work like C. <code>window</code>, <code>scroll</code>, <code>app</code>, <code>table</code> and <code>split</code> always need their <code>_end</code>. <code>menubar</code>, <code>menu</code>, <code>context</code>, <code>popup</code>, <code>modal</code> and <code>tree</code> only want it when they gave back true.<br>
Things C flips for you take a boolean and give it back as the second value: <code>shown, open = ui:collapsing("More", open)</code>, <code>shown, about = ui:modal("About", about)</code>, <code>clicked, wrap = ui:menu_item("Wrap", nil, wrap)</code>, <code>shown, frac = ui:split("main", frac)</code>.<br>
Lists are 1 based like the rest of Lua: <code>ui:combo</code>, <code>ui:tabs</code> and <code>ui:table_sort</code> use 1 for the first one, <code>ui:list_clip(count)</code> gives back <code>first, last</code> for a <code>for i = first, last</code> loop.
</p>

```lua
if ui:table("files", 3, 200, goome.TABLE_SORTABLE + goome.TABLE_STRIPES) then
  ui:table_column("Name")
  ui:table_column("Size", 80)
  ui:table_column("Kind")
  local changed, col, desc = ui:table_sort()
  for _, f in ipairs(files) do
    ui:table_row()
    ui:label(f.name)
    ui:table_next()
    ui:label(f.size)
    ui:table_next()
    ui:label(f.kind)
  end
end
ui:table_end()

text = ui:text_edit("body", text, 0, goome.EDIT_LINE_NUMBERS + goome.EDIT_WRAP)   -- h 0 = fill the rest
if ui:scroll("log", 200) then
  local first, last = ui:list_clip(#lines)        -- only the rows you can see
  for i = first, last do ui:label(lines[i]) end
end
ui:scroll_end()
ui:plot_lines("fps", fps_history)
speed = ui:drag_float("Speed", speed, 0.1, 0, 10)
pw = ui:password("Password", pw, "8 letters or more")
```

<p align="center">
<code>ui:theme()</code> has every color and size from <code>goome_theme</code> as a field (<code>ui:theme().accent = 0xFF6FDC5F</code>), plus <code>dark()</code>, <code>light()</code>, <code>make(accent, dark, radius)</code>, <code>preset("midnight")</code> and <code>copy()</code>. Fonts go in <code>font</code>, skins are <code>{bitmap, l, t, r, b}</code> (or just <code>{bitmap, 8}</code>) and icons are <code>theme:icon(goome.ICON_CHECK, bitmap)</code>. The theme keeps the fonts and bitmaps you give it alive, even if you close them.<br>
For a few widgets use the style stack: <code>ui:push_color("accent", 0xFFF59E0B)</code>, <code>ui:push_num("radius", 99)</code>, <code>push_font</code>, <code>push_skin</code>, <code>push_icon</code>, <code>push_theme</code> and then <code>ui:pop(n)</code>.<br>
<code>ui:config()</code> is the <code>goome_ui_config</code> (<code>cfg.tip_delay_ms = 0</code>, <code>cfg.ease = function(t) return t * t end</code>, <code>cfg:cursor(slot, shape)</code>), <code>ui:bind(goome.ACT_COPY, "ctrl+c")</code> changes the keys.<br>
Your own widgets: <code>hit, item = ui:custom(id, w, h, flags)</code> gives you the item as a table, <code>ui:canvas()</code> draws right there and <code>ui:store(id, n)</code> keeps n numbers per widget (<code>store[1]</code>).
</p>
</details>

<details>
<summary align="center"><b>🪟 App Mode 🪟</b></summary>

<br>

<p align="center">
<code>goome.app</code> is the easy way. It opens the window, runs the loop, only redraws when something happened (or while the ui is animating, or when you set <code>app.animate = true</code>), and closes when someone hits the x.
</p>

```lua
local goome = require("goome")

local app = goome.app("Notes", 960, 640, {flags = goome.APP_MENUBAR + goome.APP_STATUSBAR})
local about = false

app:frame(function(ui)
  if ui:menubar() then
    if ui:menu("File") then
      if ui:menu_item("Quit", "Ctrl+Q") then app:quit() end
      ui:menu_end()
    end
    ui:menubar_end()
  end
  ui:label("hello")
  local shown
  shown, about = ui:modal("About", about)
  if shown then
    ui:label("made with goome")
    ui:modal_end()
  end
  ui:statusbar("ready")
end)

app:on_close(function() return true end)   -- false keeps it open
app:run()
```

<p align="center">
<code>app:event(fn)</code> gets every event before the ui does (return true to eat it), <code>app:on_start(fn)</code> runs once the window is up, <code>app:redraw()</code> asks for a frame. <code>app:start()</code> / <code>app:step()</code> / <code>app:stop()</code> let you run the loop yourself.<br>
Without the helper, <code>goome.open_app("title", 960, 640)</code> gives you a normal goome object, the window is monitor 0. <code>goome.open{mode = "window", width =, height =, min_width =, min_height =, window_flags =}</code> does the same with every option.<br>
<code>g:window_title(t)</code>, <code>g:window_size(w, h)</code>, <code>g:window_pos([x, y])</code>, <code>g:window_state([state])</code>, <code>g:window_drag(edges)</code>, <code>g:window_show(on)</code>, <code>g:cursor([shape])</code> and <code>g:clipboard([text])</code> are the window calls. <code>CLOSE</code>, <code>FOCUS</code> and <code>DROP</code> events come in like the rest, a drop has the full path on <code>ev.path</code>.
</p>
</details>

<details>
<summary align="center"><b>🎮 Engines And Offscreen 🎮</b></summary>

<br>

<p align="center">
<code>goome.open_offscreen(w, h, scale)</code> never opens a window. You push your engines input in, goome draws into a buffer it owns, and you copy that onto a texture. It never blocks and never starts a thread.
</p>

| | |
|:--|:--|
| `g:push(goome.DOWN, {x =, y =, button = 1})` / `g:push(event)` | feed it input, any mode. `g:push_click(x, y)` and `g:push_text("hi")` are shortcuts |
| `g:last_frame()` | the frame from the last finish, with `:pixel(x, y)`, `:pixels()`, `:ptr()`, `:bytes()`, `:hash()`. Good until the next `begin` |
| `g:frame_dirty()` | the rect (real px) that changed since you last asked, `nil` if nothing did. The first one is the whole frame |
| `g:frame_copy(fmt, rect)` | that part of the frame as a string. `fmt` is `FMT_BGRA_PREMUL`, `FMT_RGBA_PREMUL`, `FMT_BGRA` or `FMT_RGBA` (the last two unpremultiply) |
| `g:frame_copy(fmt, rect, ptr, stride, true)` | copies straight into memory you own, `ptr` is a light userdata like LÖVE's `ImageData:getPointer()`. With `true` it points at the whole buffer, so the rect lands in the right spot |
| `g:resize(w, h, scale)` | new size, sends `MONITORS` |
| `g:hit(x, y)` | true when that spot is on the ui. Only send clicks to goome when its true and your game gets the rest |
| `ui:wants_mouse()` / `ui:wants_keyboard()` | if the ui is using the mouse or keyboard right now, skip your own controls then |

<p align="center">
<code>:pixels()</code> on a canvas, image, frame or bitmap is a view straight over goome's memory, nothing gets copied. <code>p[i]</code> (0 based, <code>stride</code> per row), <code>p:get(x, y)</code>, <code>p:set(x, y, v)</code>, <code>#p</code>. A grab or frame stays good until you grab that monitor again (or begin a new frame), after that it raises, call <code>image:copy()</code> to keep it as a bitmap.<br>
On LuaJIT <code>ffi.cast("uint32_t *", p:ptr())</code> gives you the raw pixels if you want to go fast.
</p>
</details>

<details>
<summary align="center"><b>💜 LÖVE 💜</b></summary>

<br>

<p align="center">
LÖVE runs on LuaJIT, so build the module with the LuaJIT headers and it just loads:
</p>

```sh
LUA_INC=/usr/include/luajit-2.1 ./build.sh       # goome.so, on windows LUA_LIB=path/to/lua51.dll gives goome.dll
cp goome.so my-game/
love my-game
```

<p align="center">
LÖVE looks for C modules in its save folder and next to the .love file, not inside your game folder, so put this at the top of <code>main.lua</code> before the <code>require</code>:
</p>

```lua
local dir = love.filesystem.getSource()
package.cpath = dir .. "/?.so;" .. dir .. "/?.dll;" .. love.filesystem.getSourceBaseDirectory() .. "/?.so;" .. package.cpath
local goome = require("goome")
```

<p align="center">
A zipped .love can't load a library from inside itself, so ship <code>goome.so</code> / <code>goome.dll</code> next to the .love or the fused exe (thats what <code>getSourceBaseDirectory</code> is for).<br>
Then run goome offscreen at the window size and copy the changed part of each frame into an <code>ImageData</code>:
</p>

```lua
local g = assert(goome.open_offscreen(love.graphics.getDimensions()))
local ui = g:ui()
local data = love.image.newImageData(love.graphics.getDimensions())
local image = love.graphics.newImage(data)

function love.update()
  for ev in g:events(0) do ui:feed(ev) end
  if ui:begin(0) then
    -- your ui here
    ui:finish()
  end
  local r = g:frame_dirty()
  if r then
    g:frame_copy(goome.FMT_RGBA_PREMUL, r, data:getPointer(), data:getWidth() * 4, true)
    image:replacePixels(data)
  end
end

function love.draw()
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(image)
  love.graphics.setBlendMode("alpha")
end
```

<p align="center">
<code>examples/love/main.lua</code> is a whole one with mouse, keys and text going in, and clicks on the menu not counting as game clicks.<br>
The <a href="https://github.com/goome-ui/examples/tree/main/engines/love2d">love2d example</a> in goome-ui/examples does the same thing with no C module at all, through LuaJIT's ffi and a plain libgoome. This module is the easier one, you dont have to copy goome's structs into ffi.cdef by hand.
</p>
</details>

<details>
<summary align="center"><b>📚 The API 📚</b></summary>

<br>

<p align="center">
Everything from <a href="https://github.com/goome-ui/c-goome/blob/main/include/goome.h">goome.h</a> is in here, the names are the C ones without <code>goome_</code> (and without <code>goome_ui_</code> on the ui object). Constants drop the <code>GOOME_</code> too, so <code>GOOME_WIN_MOVE</code> is <code>goome.WIN_MOVE</code>. <a href="https://goome.wtf/docs/">The docs</a> explain every part of it.
</p>

```lua
local g = goome.open{title = "title", backend = "test"}   -- or open_app / open_offscreen
g:monitors()                          -- {area = {x, y, w, h}, scale, pw, ph, name, ...}
g:events(16)                          -- an iterator of event tables, waits up to 16 ms for the first
g:hotkey("alt+h", 1)                  -- comes back as a HOTKEY event with id 1
local img = g:capture(0, {0, 0, 200, 100})
local bmp = goome.bitmap_load("logo.png")       -- also bitmap_from_bytes, bitmap_from_argb, bitmap_wrap
local font = goome.font_system()                -- font:measure(text, size) gives w, h
local key, mods = goome.parse_combo("ctrl+shift+f5")
```

<p align="center">
The rest is <code>g:pointer()</code>, <code>g:keyboard(on)</code>, <code>g:grab(on)</code>, <code>g:control_path()</code> and <code>goome.send(dir, msg)</code> for the control fifo, <code>goome.pacer(fps)</code>, <code>goome.now_ms()</code>, <code>g:alpha_at(x, y)</code>, <code>g:can(goome.CAP_HOTKEYS)</code> and <code>goome.canvas(w, h, stride, scale)</code> for your own canvases.
</p>
</details>

<details>
<summary align="center"><b>🎨 Drawing 🎨</b></summary>

<br>

<p align="center">
The canvas methods are the C draw functions without the <code>goome_draw_</code> part:
</p>

```lua
c:rect(x, y, w, h, color)
c:rrect(x, y, w, h, 12, color)                 -- one radius
c:rrect(x, y, w, h, {4, 20, 0, 33}, color)     -- tl tr br bl
c:rrect_grad(x, y, w, h, 12, top, bottom, sideways)
c:shadow(x, y, w, h, radius, blur, color)
c:circle(cx, cy, r, color); c:ring(cx, cy, r, width, color); c:arc(cx, cy, r, width, a0, a1, color)
c:poly({80, 5, 98, 85, 40, 35}, color)          -- or {{80, 5}, {98, 85}, {40, 35}}
c:line(x0, y0, x1, y1, width, color); c:triangle(x0, y0, x1, y1, x2, y2, color)
c:frame(x, y, w, h, width, color); c:rrect_line(x, y, w, h, 12, width, color)
c:erase(x, y, w, h)
c:bitmap(bmp, x, y, w, h, radius, tint)
c:text(x, y, "built in font", color, big)
c:font_text(font, 20, x, y, "real font", color)
c:clip_push(20, 15, 80, 50) ... c:clip_pop()
```

<p align="center">
<code>c:blit(other, alpha, dx, dy)</code> draws another canvas on top of this one, <code>c:damage(rect)</code> marks a part as changed after you wrote pixels yourself.
</p>
</details>

<details>
<summary align="center"><b>🎞️ Animations 🎞️</b></summary>

<br>

<p align="center">
<code>ui:anim(id, target, ms, ease)</code> gives you a number that slides toward <code>target</code> over <code>ms</code>. Call it every frame with the same id, change the target whenever you want and it moves from wherever it is right now. <code>ui:anim_color</code> does the same for a color.
</p>

```lua
local x = ui:anim("panel", open and 300 or 0, 250, goome.EASE_OUT)
local col = ui:anim_color("panel color", hover and 0xFF4FB3F7 or 0xFF2A2F38, 150, goome.EASE_LINEAR)
c:rrect(x, 40, 200, 120, 12, col)
local t = goome.ease(goome.EASE_BOUNCE, 0.25)   -- just the curve, 0..1 in
```

<p align="center">
The eases are <code>EASE_LINEAR</code>, <code>EASE_IN</code>, <code>EASE_OUT</code>, <code>EASE_IN_OUT</code>, <code>EASE_SMOOTH</code>, <code>EASE_BACK</code>, <code>EASE_SPRING</code> and <code>EASE_BOUNCE</code> (spring and back go past the end a bit). <code>EASE_CUSTOM</code> uses your <code>ui:config().ease</code> function.<br>
While something is still moving <code>ui:animating()</code> is true, so <code>goome.app</code> keeps drawing until it stops by itself.
</p>
</details>

<details>
<summary align="center"><b>🌍 Emoji, RTL, IME And Screen Readers 🌍</b></summary>

<br>

<p align="center">
Fonts do color emoji (COLR, CBDT and sbix), skin tones, ZWJ sequences, Hebrew and Arabic now. <code>goome.font_system()</code> already adds the system emoji font, for your own fonts chain one on:
</p>

```lua
local font = assert(goome.font_load("MyFont.ttf"))
font:fallback(assert(goome.font_load("NotoColorEmoji.ttf")))   -- tried for anything MyFont doesnt have
goome.text_dir("rtl")                                          -- "auto" (default), "ltr" or "rtl", or goome.DIR_*
```

<p align="center">
The font keeps its fallbacks alive, closing the fallback yourself is fine. Up to 8 per font like in C.<br> <br>
IME (Japanese, Chinese, Korean, dead keys...) works in <code>ui:input</code> and <code>ui:text_edit</code> by itself. If you do your own text box, <code>g:text_input(true, {x, y, w, h})</code> turns it on and puts the candidate window by your caret, then you get <code>TEXT</code> events (finished text) and <code>PREEDIT</code> events (what's being typed). <code>ev.ime</code> has all of it (<code>ev.msg</code> gets cut at 63 bytes) and <code>ev.caret</code> is where the caret is in the preedit, in bytes. <code>g:push_ime(text)</code> and <code>g:push_preedit(text, caret)</code> fake them for tests or engines.<br> <br>
The ui kit builds an accessibility tree every frame, screen readers get it in window mode. Offscreen and in overlays its off until <code>ui:a11y(true)</code>, then <code>ui:a11y_tree()</code> gives you the nodes so your engine can hand them to its own screen reader stuff:
</p>

```lua
for i, n in ipairs(ui:a11y_tree()) do
  print(i, n.role == goome.ROLE_BUTTON, n.label, n.value, n.parent, n.checked, n.focused)
end
ui:a11y_role(goome.ROLE_SLIDER, "Hue")   -- for the next ui:custom
ui:a11y_value("120")
```

<p align="center">
Each node has <code>role</code>, <code>label</code>, <code>value</code>, <code>x y w h</code>, <code>id</code>, <code>num min max</code>, <code>caret</code>, <code>states</code> plus <code>focused checked disabled expanded selected</code> as booleans. <code>parent</code> is the index of the parent in the same list and <code>nil</code> on the root.
</p>
</details>

<details>
<summary align="center"><b>🧩 Examples 🧩</b></summary>

<br>

- `examples/hello.lua` - a box you can click and type into, alt+h hides it, esc or the x quits
- `examples/grab.lua` - `lua examples/grab.lua [monitor] [x y w h] out.ppm` saves a screen grab
- `examples/ui_demo.lua` - the ui kit demo with every widget, a theme editor and a stats window
- `examples/app.lua` - a notes app in a normal window with menus, a split pane, a multiline editor, right click menus and a dialog
- `examples/offscreen.lua` - draws the ui with no window and saves it as a picture
- `examples/anim.lua` - every ease racing each other, press the button to send them back
- `examples/text.lua` - emoji, Hebrew and Arabic with a direction picker and a text box for your IME. `lua examples/text.lua font.ttf emoji.ttf` uses your own fonts
- `examples/a11y.lua` - prints what a screen reader would see of a small settings window
- `examples/love/main.lua` - a LÖVE game with a goome mod menu on top

They're ports of the C examples. Way more small projects live in [goome-ui/examples](https://github.com/goome-ui/examples).

```sh
./build.sh && lua examples/ui_demo.lua
```
</details>

<details>
<summary align="center"><b>🖥️ Where It Works 🖥️</b></summary>

<br>

Linux (X11 and Wayland), Windows 10 / 11 and macOS 14+, same as goome. Not every desktop can do everything, the <a href="https://github.com/goome-ui/c-goome#readme">c-goome README</a> has the table and <code>g:can(goome.CAP_HOTKEYS)</code> tells you at runtime.

On Mac stay on the main thread.
</details>

<details>
<summary align="center"><b>🧪 Testing Without A Screen 🧪</b></summary>

<br>

<p align="center">
goome has a <b>test</b> backend that fakes a screen and plays a script of what the "user" does. Thats what all the tests here run on, no display needed:
</p>

```sh
./build.sh test                              # plain lua scripts, no busted needed
LUA=luajit ./build.sh test
```

<p align="center">
You can test your own overlay the same way, either with env vars and no code changes:
</p>

```sh
GOOME_BACKEND=test GOOME_TEST_SCRIPT="1 click 400,300; 2 key hi\n; end 10" lua myapp.lua
```

<p align="center">
or straight from Lua:
</p>

```lua
local g = goome.open{backend = "test", test_script = "screen 800x600 1; 1 click 120,90; end 5"}
```

<p align="center">
The script format is in the <a href="https://github.com/goome-ui/c-goome#readme">c-goome README</a>. The drawing and ui tests check the exact same pixel hashes as the tests in c-goome, on every OS and on both Lua 5.4 and LuaJIT.
</p>
</details>

<details>
<summary align="center"><b>🔧 Updating goome 🔧</b></summary>

<br>

```sh
tools/update_native.sh ../c-goome      # or a path to any goome.h, or nothing to clone main
./build.sh test
```

<p align="center">
<code>native/VERSION</code> keeps the commit it came from and <code>src/consts.h</code> gets made again from the new header. If the layout test fails after that, a struct changed and <code>src/lgoome.c</code> needs the same change.
</p>
</details>

<details>
<summary align="center"><b>🛠 Pull Requests 🛠</b></summary>

<br>

<p align="center">
Want to help with lua-goome? Make A pull request to <b>dev</b>!<br>
Small fixes are the easiest to merge, for anything bigger open an issue first so we can talk about it. Bugs in the C side go to <a href="https://github.com/goome-ui/c-goome">c-goome</a>.<br> <br>
As long as it works and doesn't add a dependency its very likely to get accepted!<br>
Read <a href="CONTRIBUTING.md">CONTRIBUTING.md</a> before you send one.
</p>
</details>

<details>
<summary align="center"><b>⚖️ License ⚖️</b></summary>

<br>

<p align="center">
lua-goome is under the <a href="LICENSE">GPL-3.0</a>.<br> <br>
<sub>
• You can use it, change it and share it<br>
• If you share something made with it, you have to share your source too, under the same license<br>
• Keep the credits
</sub><br> <br>
In short: play fair, keep it open, and give credit where it's due.
</p>
</details>

<details>
<summary align="center"><b>🩷 Donate 🩷</b></summary>

<br>

<p align="center">
<a href="https://sevvy-wevvy.com/kofi">Ko-fi</a> (Preferred)<br>
<a href="https://sevvy-wevvy.com/patreon">Patreon</a><br>
<a href="https://sevvy-wevvy.com/throne">Throne</a>
</p>
</details>
