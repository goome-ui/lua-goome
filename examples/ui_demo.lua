local goome = require("goome")

local FRUITS = {"Mango", "Banana", "Cherry", "Kiwi", "Apple", "Lemon", "Grape", "Fig", "Dragonfruit", "Pear"}
local TABS = {"Widgets", "Images", "Theme", "About"}

local function make_gradient()
  local px = {}
  for y = 0, 127 do
    for x = 0, 127 do
      local r = 0x2A + math.floor(x * (0x6F - 0x2A) / 127)
      local gg = 0x40 + math.floor(y * (0xDC - 0x40) / 127)
      local b = 0x9A - math.floor((x + y) * 0x50 / 254)
      px[y * 128 + x + 1] = 0xFF000000 + r * 65536 + gg * 256 + b
    end
  end
  return assert(goome.bitmap_from_argb(px, 128, 128))
end

local function plural(n, none, one, many)
  if n == 0 then return none end
  if n == 1 then return one end
  return string.format(many, n)
end

local g, err = goome.open{title = "goome ui", no_capture = true}
if not g then
  io.stderr:write("cant open an overlay: " .. err .. "\n")
  os.exit(1)
end
local u = g:ui()
local mons = g:monitors()
local a = mons[1] and mons[1].area or {x = 0, y = 0, w = 1280, h = 720}

local s = {
  logo = make_gradient(),
  main = {x = a.x + 40, y = a.y + 40, w = 440, h = 620},
  stats = {x = a.x + 500, y = a.y + 40, w = 280, h = 0},
  tab = 1, clicks = 0, grid = true, wifi = true, notify = false, mode = 1,
  count = 42, fruit = 3, picked = 0, more = true,
  light = 0, own_accent = false, solid = false, always = false, img_clicks = 0,
  volume = 0.65, radius = 10, anim = 120,
  highlight = 0xFF4FA3FF, accent = 0xFF6FDC5F,
  name = "goome", search = "",
  fps = 0, frame_ms = 0, running = true,
}

local function set_theme()
  local t = u:theme()
  if s.light == 1 then t:light() else t:dark() end
  if s.own_accent then t.accent = s.accent end
  t.radius, t.anim_ms = s.radius, s.anim
  if s.solid then t.panel = 0xFF000000 + t.panel % 0x1000000 end
end

local function widgets()
  u:heading("Buttons")
  u:row(3)
  if u:button("Click me") then s.clicks = s.clicks + 1 end
  if u:button("Reset") then s.clicks = 0 end
  u:button("Hover me")
  u:tooltip("hi :)")
  u:label(plural(s.clicks, "not clicked yet", "clicked once", "clicked %d times"))
  u:separator()
  u:heading("Switches")
  s.grid = u:checkbox("Show grid", s.grid)
  u:same_line()
  s.notify = u:checkbox("Notifications", s.notify)
  s.wifi = u:toggle("Wi-Fi", s.wifi)
  for i, name in ipairs({"Small", "Medium", "Large"}) do
    if i > 1 then u:same_line() end
    s.mode = u:radio(name, s.mode, i - 1)
  end
  u:separator()
  u:heading("Values")
  s.volume = u:slider("Volume", s.volume, 0, 1, "%.2f")
  s.count = u:slider_int("Count", s.count, 0, 100)
  u:progress(s.volume, string.format("%d%%", math.floor(s.volume * 100 + 0.5)))
  u:progress(-1)
  u:row(2)
  s.name = u:input("Name", s.name, 64)
  s.search = u:input("Search", s.search, 64)
  s.fruit = u:combo("Fruit", s.fruit, FRUITS)
  s.highlight = u:color("Highlight", s.highlight)
  local _
  _, s.more = u:collapsing("More stuff", s.more)
  if s.more then
    u:wrapped("a long list so theres something to scroll. pick one, it shows up under it.")
    if u:scroll("list", 150) then
      for i = 1, 30 do
        if u:selectable("Item " .. i, s.picked == i) then s.picked = i end
      end
    end
    u:scroll_end()
    u:label(s.picked > 0 and ("picked item " .. s.picked) or "nothing picked")
  end
end

local function images()
  u:heading("Generated gradient")
  for i, r in ipairs({18, 60, 0}) do
    if i > 1 then u:same_line() end
    u:image(s.logo, 120, 120, r)
  end
  u:label("image buttons")
  for i = 0, 3 do
    if i > 0 then u:same_line() end
    if u:image_button("img" .. i, s.logo, 56, 56) then s.img_clicks = s.img_clicks + 1 end
  end
  u:label(plural(s.img_clicks, "no image clicks yet", "one image click", "%d image clicks"))
  u:image(s.logo, 0, 90, 10)
end

local function theme()
  u:heading("Theme")
  local was, ch, c = s.light, false, false
  s.light = u:radio("Dark", s.light, 0)
  u:same_line()
  s.light = u:radio("Light", s.light, 1)
  ch = s.light ~= was
  s.accent, c = u:color("Accent", s.accent)
  if c then s.own_accent, ch = true, true end
  s.radius, c = u:slider("Corner radius", s.radius, 0, 20, "%.0f px")
  ch = ch or c
  s.anim, c = u:slider("Animation", s.anim, 0, 400, "%.0f ms")
  ch = ch or c
  s.solid, c = u:toggle("Solid panels", s.solid)
  ch = ch or c
  if u:button("Reset theme") then
    s.light, s.own_accent, s.radius, s.anim, s.solid, s.accent = 0, false, 10, 120, false, 0xFF6FDC5F
    ch = true
  end
  if ch then set_theme() end
  if not s.own_accent then s.accent = u:theme().accent end
end

local function about()
  u:heading("About")
  u:wrapped("made with goome. try clicking next to this window, your desktop still gets it.")
  u:label("goome " .. goome.VERSION .. " on " .. g:backend_name())
  u:label(string.format("%.0f fps, %.2f ms a frame", s.fps, s.frame_ms))
  if not s.stats.open and u:button("Show stats") then s.stats.open = true end
end

local pages = {widgets, images, theme, about}

local function draw()
  local flags = goome.WIN_MOVE + goome.WIN_RESIZE + goome.WIN_COLLAPSE
  if u:window("goome ui", s.main, flags) then
    s.tab = u:tabs("tabs", TABS, s.tab)
    u:push_id(TABS[s.tab])
    if u:scroll("page") then pages[s.tab]() end
    u:scroll_end()
    u:pop_id()
  end
  u:window_end()
  if u:window("Stats", s.stats, flags + goome.WIN_CLOSE) then
    u:label(string.format("%.0f fps", s.fps))
    u:label(string.format("%.2f ms a frame", s.frame_ms))
    u:progress(s.frame_ms / 16.7, string.format("%d%% of a 60 fps frame", math.floor(s.frame_ms * 100 / 16.7 + 0.5)))
    s.always = u:toggle("Redraw every frame", s.always)
    if u:button("Quit") then s.running = false end
  end
  u:window_end()
end

local test = g:backend_name():match("^test") ~= nil
local spent, tframes, acc_ms, acc_n, fps_n = 0, 0, 0, 0, 0
local fps_t = goome.now_ms()
local pace = goome.pacer(60)
local dirty = true
while s.running do
  local busy = dirty or s.always or test or u:animating()
  for ev in g:events(busy and pace:wait() or 500) do
    if ev.type == goome.QUIT then s.running = false end
    u:feed(ev)
    dirty = true
  end
  if not s.running then break end
  if dirty or s.always or test or u:animating() then
    dirty = false
    local t0 = goome.now_ms()
    if u:begin(0) then
      draw()
      u:finish()
      local t1 = goome.now_ms()
      spent, tframes = spent + t1 - t0, tframes + 1
      acc_ms, acc_n, fps_n = acc_ms + t1 - t0, acc_n + 1, fps_n + 1
      if t1 - fps_t >= 500 then
        s.fps = fps_n * 1000 / (t1 - fps_t)
        s.frame_ms = acc_ms / acc_n
        fps_t, fps_n, acc_ms, acc_n = t1, 0, 0, 0
      end
    end
  end
end
if tframes > 0 then print(string.format("%d frames, %.2f ms a frame", tframes, spent / tframes)) end
s.logo:close()
u:close()
g:close()
