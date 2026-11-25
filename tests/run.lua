local here = (arg and arg[0] or "tests/run.lua"):gsub("[^/\\]*$", "")
if here == "" then here = "./" end
local root = here .. "../"
if not os.getenv("LUA_CPATH") then package.cpath = root .. "?.so;" .. root .. "?.dll;" .. package.cpath end

local goome = require("goome")

local passed, failed, skipped = 0, 0, 0
local only = os.getenv("GOOME_ONLY")

local function test(name, fn)
  if only and not name:find(only, 1, true) then return end
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    passed = passed + 1
    print("ok   " .. name)
  elseif type(err) == "string" and err:find("SKIP: ", 1, true) then
    skipped = skipped + 1
    print("skip " .. name .. " (" .. err:match("SKIP: ([^\n]*)") .. ")")
  else
    failed = failed + 1
    print("FAIL " .. name .. "\n" .. tostring(err))
  end
end

local function skip(why)
  error("SKIP: " .. why, 0)
end

local function eq(got, want, what)
  if got ~= want then
    error(string.format("%s: got %s, wanted %s", what or "value", tostring(got), tostring(want)), 2)
  end
end

local function yes(v, what)
  if not v then error((what or "check") .. " failed", 2) end
end

local function hex(v)
  return string.format("%08x", v)
end

local function raises(fn, what)
  local ok = pcall(fn)
  if ok then error((what or "call") .. " should have raised", 2) end
end

local function data(name)
  local f = assert(io.open(root .. "tests/data/" .. name, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local windows = package.config:sub(1, 1) == "\\"
local out = root .. "test-out/"
if windows then os.execute('mkdir "' .. out:gsub("/", "\\") .. '" 2>nul') else os.execute('mkdir -p "' .. out .. '"') end

local function strict()
  return os.getenv("GOOME_STRICT") ~= nil
end

local function compiler()
  local cands = {os.getenv("CC") or "cc", "cc", "gcc", "clang"}
  for _, c in ipairs(cands) do
    if c and c ~= "" then
      local null = windows and "nul" or "/dev/null"
      local r = os.execute(c .. " --version >" .. null .. " 2>&1")
      if r == true or r == 0 then return c end
    end
  end
end

local function run_c(src, name, args)
  local cc = compiler()
  if not cc then
    if strict() then error("no C compiler to check against") end
    skip("no C compiler, set CC")
  end
  local exe = out .. name .. (windows and ".exe" or "")
  local cmd = cc .. ' -std=c99 -I"' .. root .. 'native" -o "' .. exe .. '" "' .. src .. '"'
  local r = os.execute(cmd)
  yes(r == true or r == 0, "compiling " .. src)
  local run = windows and exe:gsub("/", "\\") or exe
  local p = assert(io.popen('"' .. run .. '"' .. (args or ""), "r"))
  local s = p:read("*a")
  p:close()
  os.remove(exe)
  return s
end

local function header()
  local s = assert(read(root .. "native/goome.h"))
  return s:match("^(.-)#ifdef GOOME_IMPLEMENTATION") or s
end

test("layout matches C", function()
  local want = run_c(root .. "tests/layout.c", "layout"):gsub("\r", "")
  local got = goome._layout()
  yes(#want > 1000, "layout output")
  local wl, gl = {}, {}
  for l in want:gmatch("[^\n]+") do wl[#wl + 1] = l end
  for l in got:gmatch("[^\n]+") do gl[#gl + 1] = l end
  eq(#gl, #wl, "layout lines")
  for i = 1, #wl do eq(gl[i], wl[i], "layout line " .. i) end
end)

test("constants", function()
  local n = 0
  for body in header():gmatch("enum%s*{(.-)}") do
    body = body:gsub("//[^\n]*", "")
    for item in body:gmatch("[^,]+") do
      local name = item:match("^%s*GOOME_([A-Z0-9_]+)")
      if name then
        yes(type(goome[name]) == "number", "goome." .. name)
        n = n + 1
      end
    end
  end
  yes(n > 250, "enum count")
  eq(goome.TEST, 7, "TEST")
  eq(goome.OFFSCREEN, 8, "OFFSCREEN")
  eq(goome.K_ESC, 27, "K_ESC")
  eq(goome.K_LEFT, 0x90, "K_LEFT")
  eq(goome.ALT, 0x400, "ALT")
  eq(goome.EAGAIN, -5, "EAGAIN")
  eq(goome.ICON_COUNT, 22, "ICON_COUNT")
  eq(goome.VERSION, header():match('#define GOOME_VERSION "([^"]+)"'), "VERSION")
end)

test("every C function is wrapped", function()
  local src = assert(read(root .. "src/lgoome.c"))
  local missing = {}
  for name in header():gmatch("[%w_%*]+%s+%**(goome_[%w_]+)%s*%(") do
    if not src:find(name .. "(", 1, true) and not src:find(name .. ")", 1, true) and not src:find(name .. ",", 1, true) then
      missing[#missing + 1] = name
    end
  end
  eq(table.concat(missing, " "), "", "not wrapped")
end)

test("combos", function()
  local k, m = goome.parse_combo("alt+h")
  eq(k, string.byte("h"), "key")
  eq(m, goome.ALT, "mods")
  k, m = goome.parse_combo("Ctrl+Shift+F5")
  eq(k, goome.K_F1 + 4)
  eq(m, goome.CTRL + goome.SHIFT)
  k, m = goome.parse_combo("alt+?")
  eq(k, string.byte("/"))
  eq(m, goome.ALT + goome.SHIFT)
  k, m = goome.parse_combo("super+space")
  eq(k, 32)
  eq(m, goome.SUPER)
  k, m = goome.parse_combo("cmd+left")
  eq(k, goome.K_LEFT)
  eq(m, goome.SUPER)
  k, m = goome.parse_combo("H")
  eq(k, string.byte("h"))
  eq(m, goome.SHIFT)
  for _, bad in ipairs({"alt+", "alt+f13", ""}) do
    local a, msg, code = goome.parse_combo(bad)
    eq(a, nil, bad)
    yes(type(msg) == "string" and code < 0, "error for " .. bad)
  end
end)

test("pacer", function()
  local p = goome.pacer(50)
  eq(p:wait(), 0, "first wait")
  local w = p:wait()
  yes(w > 0 and w <= 20, "second wait " .. w)
  local t = goome.now_ms()
  yes(t >= 0 and goome.now_ms() >= t, "now_ms")
end)

local SCRIPT = "screen 640x360 2; 1 click 20,20; 1 click 300,300; 2 hotkey alt+j; 3 key Hi\\b; 4 send ping; 5 scroll 30,30 -1; 6 hold 25,25 8; end 10"

test("scripted run", function()
  local g = assert(goome.open{title = "t", backend = "test", test_script = SCRIPT})
  eq(g:backend_name():match("^%S+"), "test", "backend")
  local mons = g:monitors()
  eq(#mons, 1, "monitors")
  eq(mons[1].area.w, 640)
  eq(mons[1].scale, 2)
  eq(mons[1].pw, 1280)
  assert(g:hotkey("alt+j", 7))
  assert(g:keyboard(true))
  local n = {down = 0, up = 0, hot = 0, keys = 0, ctl = 0, scroll = 0, held = 0}
  local text, quit, frames = "", false, 0
  while not quit and frames < 100 do
    local c = g:begin(0)
    yes(c, "canvas")
    eq(c.scale, 2)
    eq(c.w, 1280)
    c:rect(10, 10, 40, 40, 0xFF336699)
    c:hit(10, 10, 40, 40)
    assert(g:finish(c))
    eq(c:valid(), false, "canvas after finish")
    frames = frames + 1
    local x, y, b = g:pointer()
    if x and b ~= 0 then n.held = n.held + 1 end
    for ev in g:events(1) do
      if ev.type == goome.DOWN then n.down = n.down + 1
      elseif ev.type == goome.UP then n.up = n.up + 1
      elseif ev.type == goome.HOTKEY and ev.id == 7 then n.hot = n.hot + 1
      elseif ev.type == goome.KEY then
        n.keys = n.keys + 1
        text = text .. ev.text
      elseif ev.type == goome.CONTROL and ev.msg == "ping" then n.ctl = n.ctl + 1
      elseif ev.type == goome.SCROLL and ev.dy == -1 then n.scroll = n.scroll + 1
      elseif ev.type == goome.QUIT then quit = true end
    end
  end
  eq(n.down, 2, "downs")
  eq(n.up, 2, "ups")
  eq(n.hot, 1, "hotkeys")
  eq(n.keys, 3, "keys")
  eq(text, "Hi", "text")
  eq(n.ctl, 1, "control")
  eq(n.scroll, 1, "scroll")
  yes(quit, "quit")
  yes(n.held >= 1, "held")

  local img = assert(g:capture(0, {10, 10, 40, 40}))
  eq(img.w, 80)
  eq(img.h, 80)
  eq(img.has_self, true)
  eq(img:pixel(0, 0), 0xFF336699)
  local px = img:pixels()
  eq(px[0], 0xFF336699)
  eq(#px, 80 * img.stride)
  eq(px:get(79, 79), img:pixel(79, 79))
  local kept = img:copy()
  eq(kept.w * kept.h, 80 * 80)
  eq(kept:pixel(0, 0), 0xFF336699)
  eq(g:alpha_at(20, 20), 255)
  eq(g:alpha_at(200, 200), 0)

  local again = assert(g:capture(0))
  eq(img.fresh, false, "old grab fresh")
  raises(function() return img:pixel(0, 0) end, "stale image")
  raises(function() return px[0] end, "stale pixels")
  eq(again.w, 1280)
  eq(again.h, 720)
  local path = out .. "grab.ppm"
  assert(again:save_ppm(path))
  eq(read(path):sub(1, 2), "P6")
  os.remove(path)
  g:close()
  eq(g:closed(), true)
  raises(function() g:monitors() end, "closed goome")
  eq(again.fresh, false)
  eq(kept:pixel(0, 0), 0xFF336699, "copy outlives goome")
  kept:close()
end)

test("errors", function()
  raises(function() goome.open{backend = "nope"} end, "bad backend")
  local g, msg, code = goome.open{backend = "test", test_frames = root .. "no/such/frames"}
  eq(g, nil, "missing frames")
  eq(code, goome.ENODISPLAY, "code")
  yes(type(msg) == "string", "message")
  yes(#goome.strerror(goome.ENOTSUP) > 0, "strerror")
end)

test("close twice", function()
  local g = assert(goome.open{backend = "test", test_script = "end 3"})
  local c = g:begin(0)
  g:close()
  g:close()
  eq(c:valid(), false)
  raises(function() c:rect(0, 0, 1, 1, 0xFFFFFFFF) end, "draw after close")
  raises(function() g:poll() end, "poll after close")
end)

test("frame and no state dir", function()
  local g = assert(goome.open{backend = "test", test_script = "end 3"})
  eq(g:control_path(), nil)
  local c = g:begin(0)
  c:rect(0, 0, 10, 10, 0xFFFF0000)
  assert(g:finish(c, {{0, 0, 10, 10}}))
  eq(g:alpha_at(5, 5), 255)
  eq(g:hit(5, 5), true)
  local f = assert(g:last_frame())
  eq(f:pixel(0, 0), 0xFFFF0000)
  g:close()
end)

local STAR = {80, 5, 98, 85, 40, 35, 120, 35, 62, 85}

local SHAPES = {
  {0xA7B3B4C5, 0x0FB29A82, 0x1A98CF16, 0x1E7B729F, 0x21FD3B05, 0x241CE7FD, 0x6910B0D5, 0x7180B28E, 0x6F33AC30, 0xB48ADFA3, 0x796B9105, 0x2D93DC92, 0x1F908FAD, 0x23A6CF0C},
  {0x73429A18, 0xD9BD97AB, 0xD031F56C, 0xD2D9FA9A, 0xD639A1A7, 0xA77C3E9E, 0x7BD3FEAD, 0xAC76561E, 0x5BD0648D, 0xD0AC70E1, 0x0BB5DDA0, 0xE7C304C7, 0xCCEF8860, 0xEFC1F212},
  {0x9175788F, 0x6E99EA87, 0x935CC8E1, 0x0B73F68D, 0x23891BE5, 0xA28476C1, 0xEA64F655, 0x87DC9430, 0x909D11B5, 0x0550BB7A, 0x6455EE86, 0xD8C08E2B, 0xFD0DD1FD, 0x28C27977},
}

local IMAGES = {
  {"png-gray-1-bit.png", 9, 3, 0x01975AD8},
  {"png-palette-4-bit-trns-interlaced.png", 6, 6, 0xAF77E7E2},
  {"png-rgb-16-bit.png", 5, 4, 0xDD60C23E},
  {"png-gray-alpha-stored-interlaced.png", 5, 5, 0x52D68985},
  {"png-rgba-fixed-huffman-split.png", 8, 6, 0x66DB9DCD},
  {"png-gray-key.png", 7, 4, 0x843ED605},
  {"png-rgba-16-bit-interlaced.png", 9, 9, 0xDC2F91D5},
  {"jpeg-420.jpg", 16, 16, 0x32E2C9CE},
  {"jpeg-422-restarts.jpg", 13, 9, 0x0E230BAF},
  {"jpeg-444.jpg", 10, 10, 0x34FC5275},
  {"jpeg-progressive-420-restarts.jpg", 14, 11, 0x5BCEE932},
  {"jpeg-gray.jpg", 9, 7, 0xF010B3C8},
  {"jpeg-exif-rotated.jpg", 6, 10, 0x65909E25},
  {"bmp-4-bit.bmp", 5, 3, 0x9256D097},
  {"bmp-32-bit-alpha-top-down.bmp", 3, 2, 0x6BDB3A29},
  {"bmp-24-bit.bmp", 5, 3, 0x09D94C56},
  {"ppm.ppm", 3, 2, 0xC6FDF725},
  {"pgm-16-bit.pgm", 3, 1, 0x35029201},
  {"qoi.qoi", 6, 4, 0x23AF45AD},
}

local function shape(c, k, b)
  if k == 0 then c:rrect(10.3, 8.6, 120, 70.2, {4, 20, 0, 33}, 0xE02060C0)
  elseif k == 1 then c:rrect_line(10.3, 8.6, 120, 70.2, goome.radius(18), 2.5, 0xFF20A060)
  elseif k == 2 then c:rrect_grad(10, 10, 130, 70, 12, 0xFF102040, 0x8080C0FF)
  elseif k == 3 then c:rrect_grad(10, 10, 130, 70, 35, 0xFFFF4080, 0x004080FF, true)
  elseif k == 4 then c:shadow(30, 20, 90, 50, 10, 16, 0x80000000)
  elseif k == 5 then
    c:circle(50.5, 50.2, 30.7, 0xFFFFC020)
    c:circle(120, 30, 1.3, 0xFF000000)
  elseif k == 6 then c:ring(80, 50, 30, 5, 0xC0208080)
  elseif k == 7 then
    c:arc(50, 50, 30, 6, 0.3, 4.5, 0xFF3060E0)
    c:arc(120, 50, 20, 30, 2, 2.5, 0xFF905020)
  elseif k == 8 then c:poly(STAR, 0xFF2040A0)
  elseif k == 9 then c:bitmap(b, 10, 10, 100.5, 75.3, 20)
  elseif k == 10 then c:bitmap(b, 10, 10, 24, 16, 0, 0x80FF8080)
  elseif k == 11 then c:bitmap(b, 10, 10, 9, 5, 2)
  elseif k == 12 then c:bitmap_part(b, 4, 2, 8, 8, 100, 10, 40, 40)
  else
    c:clip_push(20, 15, 80, 50)
    c:rrect(0, 0, 160, 100, 30, 0xFF4080FF)
    c:clip_push(50, 0, 100, 40)
    c:circle(70, 40, 30, 0xFFFF4040)
    c:text(30, 30, "clip", 0xFF000000, true)
    c:shadow(40, 20, 60, 30, 8, 10, 0xFF000000)
    c:bitmap(b, 40, 10, 48, 32, 6)
    c:clip_pop()
    c:line(0, 0, 160, 100, 3, 0xFF00A000)
    local pts = {}
    for i = 1, #STAR, 2 do pts[#pts + 1] = {STAR[i], STAR[i + 1]} end
    c:poly(pts, 0x80000000)
    c:clip_pop()
    c:frame(20, 15, 80, 50, 1, 0x80000000)
  end
end

local function make_bitmap()
  local store = goome.canvas(27, 16)
  local p = store:pixels()
  for y = 0, 15 do
    for x = 0, 23 do
      local a = math.floor(x * 255 / 23)
      local v = (math.floor(x / 4) + math.floor(y / 4)) % 2 == 1 and 0xFFFFFF or 0x2050C0
      local r, gg, bb = math.floor(v / 65536) % 256, math.floor(v / 256) % 256, v % 256
      p[y * 27 + x] = a * 16777216 + math.floor(r * a / 255) * 65536 + math.floor(gg * a / 255) * 256 + math.floor(bb * a / 255)
    end
  end
  return goome.bitmap_wrap(p, 24, 16, 27)
end

local function premultiplied(c)
  local p = c:pixels()
  for i = 0, #p - 1 do
    local v = p[i]
    local a = math.floor(v / 16777216)
    if math.floor(v / 65536) % 256 > a or math.floor(v / 256) % 256 > a or v % 256 > a then return false end
  end
  return true
end

local function zero_cols(c, x0, x1)
  for y = 0, c.h - 1 do
    for x = x0, x1 - 1 do
      if c:pixels():get(x, y) ~= 0 then return false end
    end
  end
  return true
end

test("drawing basic", function()
  local c = goome.canvas(160, 100, 200, 1.5)
  c:round_rect(5, 5, 60, 40, 8, 0xC0203040)
  c:line(0, 0, 100, 60, 3, 0xFFFF0000)
  c:triangle(10, 50, 60, 50, 35, 10, 0x8000FF00)
  c:text(8, 8, "goome!", 0xFFFFFFFF, true)
  c:frame(70, 10, 30, 30, 2, 0xFF00FFFF)
  local p = c:pixels()
  for y = 0, 99 do eq(p[y * 200 + 170], 0, "past the width") end
  yes(c.dx1 > c.dx0 and c.dy1 > c.dy0, "damage")
  eq(hex(c:hash(200, 100)), hex(0xB93B60CF), "basic hash")
  c:clear()
  eq(hex(c:hash(200, 100)), hex(goome.canvas(200, 100):hash()), "cleared")
  yes(c:text_width("abc") > 0, "text width")
end)

test("drawing shapes", function()
  local b = make_bitmap()
  for s, sc in ipairs({1, 1.25, 2}) do
    local got, want = {}, {}
    for k = 0, 13 do
      local w, h = math.floor(160 * sc), math.floor(100 * sc)
      local c = goome.canvas(w, h, w + 3, sc)
      shape(c, k, b)
      got[#got + 1] = hex(c:hash(w + 3, h))
      want[#want + 1] = hex(SHAPES[s][k + 1])
      yes(c.dx1 > c.dx0, "damage " .. k)
      yes(zero_cols(c, w, w + 3), "stride gap " .. k)
      if sc == 1 then yes(premultiplied(c), "premultiplied " .. k) end
      if k == 13 then
        local x0, y0 = math.floor(20 * sc + 0.5), math.floor(15 * sc + 0.5)
        local x1, y1 = math.floor(100 * sc + 0.5), math.floor(65 * sc + 0.5)
        c = goome.canvas(w, h, w + 3, sc)
        c:clip_push(20, 15, 80, 50)
        shape(c, 8, b)
        shape(c, 4, b)
        shape(c, 9, b)
        c:text(0, 20, "outside", 0xFFFFFFFF, true)
        yes(c.dx0 >= x0 and c.dy0 >= y0 and c.dx1 <= x1 and c.dy1 <= y1 and c.dx1 > c.dx0, "clip damage")
        local p = c:pixels()
        for y = 0, h - 1 do
          for x = 0, w - 1 do
            if (x < x0 or x >= x1 or y < y0 or y >= y1) and p[y * (w + 3) + x] ~= 0 then error("drew outside the clip") end
          end
        end
        c:clip_pop()
        eq(c.nclip, 0, "nclip")
      end
    end
    eq(table.concat(got, " "), table.concat(want, " "), "scale " .. sc)
  end
  b:close()
end)

test("image and blit", function()
  local src = goome.canvas(20, 20)
  src:image(0, 0, 20, 20, {0xFF00FF00, 0xFF00FF00, 0xFF00FF00, 0xFF00FF00, 0xFF00FF00, 0xFF00FF00, 0xFF00FF00, 0xFF00FF00,
    0xFF00FF00, 0xFF00FF00, 0xFF00FF00, 0xFF00FF00, 0xFF00FF00, 0xFF00FF00, 0xFF00FF00, 0xFF00FF00}, 4, 4)
  eq(src:pixel(0, 0), 0xFF00FF00)
  local dst = goome.canvas(40, 40)
  dst:blit(src, 1.0, 10, 10)
  eq(dst:pixel(10, 10), 0xFF00FF00)
  eq(dst:pixel(0, 0), 0)
  dst:erase(0, 0, 40, 40)
  eq(dst:pixel(10, 10), 0)
  dst:image(0, 0, 2, 1, string.char(0, 0, 255, 255, 255, 0, 0, 255), 2, 1)
  eq(dst:pixel(0, 0), 0xFFFF0000)
  eq(dst:pixel(1, 0), 0xFF0000FF)
  local p = dst:pixels()
  p:set(5, 5, 0xFF123456)
  eq(dst:pixel(5, 5), 0xFF123456)
  p[0] = 0xFF010203
  eq(p:get(0, 0), 0xFF010203)
  yes(type(p:ptr()) == "userdata", "ptr")
  eq(#p:bytes(), 40 * 40 * 4)
end)

test("lua hash matches C", function()
  local function bxor(a, b)
    local r, bit = 0, 1
    for _ = 1, 8 do
      if (a % 2) ~= (b % 2) then r = r + bit end
      a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
    end
    return r
  end
  local c = goome.canvas(3, 2)
  c:rect(0, 0, 2, 1, 0xC0806040)
  local v = 2166136261
  local s = c:bytes()
  for i = 1, #s do
    local lo = v % 256
    v = v - lo + bxor(lo, s:byte(i))
    v = (v * 403 + (v % 256) * 16777216) % 4294967296
  end
  eq(hex(c:hash()), hex(v))
end)

test("fonts", function()
  local ttf, otf = data("dejavu-sub.ttf"), data("dejavu-sub.otf")
  eq(goome.font_from_bytes("nope, not a font"), nil, "junk font")
  eq(goome.font_from_bytes(ttf:sub(1, 40)), nil, "cut font")
  local f, o = assert(goome.font_from_bytes(ttf)), assert(goome.font_from_bytes(otf))
  local w, h = f:measure("goome!", 20)
  yes(w > 76.97 and w < 76.98 and h > 23.2 and h < 23.3, "measure " .. w .. " " .. h)
  for _, font in ipairs({f, o}) do
    yes(font:width("AV", 20) < font:width("A", 20) + font:width("V", 20) - 1, "kerning")
  end
  w, h = f:measure("a\nbb\n", 20)
  yes(h > 3 * 23.2 and h < 3 * 23.3, "lines")
  yes(f:width("\255\195(\237\160\128\244\144\128\128", 20) > 0, "bad utf8")
  yes(f:line_height(20) > 0, "line height")
  local want = {0x412C299F, 0xBCD42095}
  local inks = {}
  for k, font in ipairs({f, o}) do
    local c = goome.canvas(200, 120, 240, 1.5)
    c.kx1, c.ky1 = 200, 120
    c:font_text(font, 13, 4, 2, "goome! Hi\195\169\nAVAWAY Ty.@ \226\152\131")
    c:font_text(font, 30, 2.3, 24, "Hig", 0xC0FF8040)
    c.kx0, c.ky0, c.kx1, c.ky1, c.nclip = 30, 60, 90, 100, 1
    c:font_text(font, 40, 10, 50, "WoW", 0xFF2080FF)
    yes(zero_cols(c, 200, 240), "past width")
    for y = 100, 119 do
      for x = 0, 239 do
        if c:pixels():get(x, y) ~= 0 then error("drew below the clip") end
      end
    end
    yes(c.dx0 >= 0 and c.dx1 <= 200 and c.dy1 <= 100 and c.dx1 > c.dx0, "damage")
    eq(hex(c:hash(240, 120)), hex(want[k]), "font hash " .. k)
    c = goome.canvas(240, 120)
    c.kx1, c.ky1 = 240, 120
    c:font_text(font, 31, 3, 3, "goome Hi\nmoge")
    inks[k] = c
  end
  local ink, diff = 0, 0
  local a, b = inks[1]:pixels(), inks[2]:pixels()
  for i = 0, #a - 1 do
    local x, y = math.floor(a[i] / 16777216), math.floor(b[i] / 16777216)
    ink = ink + x
    diff = diff + math.abs(x - y)
  end
  yes(ink > 0 and diff * 50 < ink, "ttf and otf look the same")
  local c = goome.canvas(200, 120, 240)
  c.kx1, c.ky1 = 200, 120
  for cut = 0, #otf - 1, 7 do
    local byte = otf:byte(cut + 1)
    local nb = 0
    local bit, x, y = 1, byte, 0x5A
    for _ = 1, 8 do
      if x % 2 ~= y % 2 then nb = nb + bit end
      x, y, bit = math.floor(x / 2), math.floor(y / 2), bit * 2
    end
    local bad = otf:sub(1, cut) .. string.char(nb) .. otf:sub(cut + 2)
    if cut % 2 == 0 then bad = bad:sub(1, cut + 12) end
    local bf = goome.font_from_bytes(bad)
    c:font_text(bf, 20, 0, 0, "goome! AV")
    if bf then bf:close() end
  end
  c = goome.canvas(200, 120, 240)
  eq(c:font_text(nil, 12, 0, 0, "ab\nabc"), (goome.measure("abc", 12)), "builtin advance")
  f:close()
  f:close()
  o:close()
  raises(function() f:measure("x", 10) end, "closed font")
end)

test("builtin font", function()
  yes(goome.font_count() >= 1, "font count")
  goome.set_font(0)
  yes(goome.line_height(12) > 0, "line height")
end)

test("font file", function()
  local p = out .. "f.ttf"
  local fh = assert(io.open(p, "wb"))
  fh:write(data("dejavu-sub.ttf"))
  fh:close()
  local f = assert(goome.font_load(p))
  yes(f:width("goome", 12) > 0)
  f:close()
  f = assert(goome.font_load(p, 0))
  yes(f:width("goome", 12) > 0)
  f:close()
  os.remove(p)
  eq(goome.font_load(out .. "gone.ttf"), nil, "missing font")
end)

test("bitmaps", function()
  for _, case in ipairs(IMAGES) do
    local name, w, h, hv = case[1], case[2], case[3], case[4]
    local raw = data(name)
    local b = assert(goome.bitmap_from_bytes(raw))
    eq(b.w, w, name)
    eq(b.h, h, name)
    eq(b.owned, true, name)
    eq(hex(b:hash()), hex(hv), name)
    b:close()
    eq(b.closed, true)
    b:close()
    local half = goome.bitmap_from_bytes(raw:sub(1, math.floor(#raw / 2)))
    if half then
      yes(half.w > 0)
      half:close()
    end
  end
end)

test("bitmap errors", function()
  local b, msg, code = goome.bitmap_from_bytes(data("jpeg-arithmetic.jpg"))
  eq(b, nil)
  eq(code, goome.ENOTSUP)
  yes(msg:find("arithmetic"), "message " .. msg)
  b, msg, code = goome.bitmap_from_bytes("GIF89a......")
  eq(code, goome.ENOTSUP)
  eq(goome.bitmap_from_bytes("\137PNG\r\n\26\n"), nil)
  eq(goome.bitmap_load("no/such/file.png"), nil)
end)

test("bitmap from argb", function()
  local b = assert(goome.bitmap_from_argb({0xFFFF0000, 0x80FFFFFF, 0x00123456, 0x40804020}, 2, 2))
  eq(b:pixel(0, 0), 0xFFFF0000)
  eq(b:pixel(1, 0), 0x80808080)
  eq(b:pixel(0, 1), 0)
  eq(b:pixel(1, 1), 0x40201008)
  b:close()
  raises(function() return b:pixels() end, "closed bitmap")
  raises(function() goome.bitmap_from_argb({1, 2}, 2, 2) end, "short table")
  raises(function() goome.bitmap_from_argb(goome.canvas(4, 4), 4, 40) end, "more rows than the source")
  raises(function() goome.canvas(8, 8):image(0, 0, 8, 8, goome.canvas(4, 4), 4, 40) end, "image taller than the source")
  local p = out .. "x.qoi"
  local fh = assert(io.open(p, "wb"))
  fh:write(data("qoi.qoi"))
  fh:close()
  b = assert(goome.bitmap_load(p))
  eq(b.w, 6)
  eq(b.h, 4)
  b:close()
  os.remove(p)
end)

local UI_SCRIPT = "screen 400x360 1; 1 click 35,71; 2 click 29,106; 3 hold 40,157 6; 4 hover 120,157; " ..
  "7 click 100,213; 8 key ab; 9 key \\n; 10 key zz; 11 click 120,273; 13 click 120,206; " ..
  "15 click 300,20; 16 hold 100,20 20; 18 hover 150,40; end 22"

test("ui scripted", function()
  local g = assert(goome.open{backend = "test", test_script = UI_SCRIPT})
  local u = g:ui()
  local th = u:theme()
  th.font = nil
  th.font_size = 14
  local win = {x = 10, y = 10, w = 220, h = 0}
  local val, check, pick, text = 0.0, false, 1, ""
  local quit, frames, clicks, downs, keys_off, kb_seen = false, 0, 0, 0, 0, false
  local hs = {}
  while not quit and frames < 100 do
    for ev in g:events(0) do
      if ev.type == goome.QUIT then quit = true end
      if ev.type == goome.DOWN then downs = downs + 1 end
      if ev.type == goome.KEY and frames > 10 then keys_off = keys_off + 1 end
      u:feed(ev)
    end
    local c = u:begin(0)
    yes(c, "ui canvas")
    if u:window("test", win, goome.WIN_MOVE) then
      if u:button("Go") then clicks = clicks + 1 end
      check = u:checkbox("Check", check)
      val = u:slider("Val", val, 0, 1)
      text = u:input("Text", text, 16)
      pick = u:combo("Pick", pick, {"one", "two", "three"})
    end
    u:window_end()
    u:finish()
    eq(c:valid(), false, "canvas after finish")
    if frames == 8 then kb_seen = text ~= "" end
    if frames == 0 or frames == 12 or frames == 21 then hs[#hs + 1] = frames .. "=" .. hex(g:last_frame():hash()) end
    frames = frames + 1
  end
  eq(clicks, 1, "clicks")
  eq(check, true, "check")
  yes(val > 0.45 and val < 0.55, "slider " .. val)
  yes(kb_seen, "keyboard")
  eq(text, "ab", "text")
  eq(keys_off, 0, "keys after unfocus")
  eq(pick, 2, "combo")
  eq(win.x, 60, "win x")
  eq(win.y, 30, "win y")
  eq(downs, 7, "downs")
  eq(table.concat(hs, " "), "0=51713294 12=b52f16c5 21=ea01692c", "ui hashes")
  u:close()
  g:close()
end)

test("ui widgets", function()
  local g = assert(goome.open{backend = "test", test_script = "screen 800x600 1; 2 click 60,80; end 6"})
  local u = g:ui()
  local t = u:theme()
  t.font = nil
  t:light()
  yes(t.text >= 0x01000000, "light text")
  t:dark()
  t.accent = 0xFF6FDC5F
  eq(t.accent, 0xFF6FDC5F)
  t.radius = 4
  t.pad = 8
  t.anim_ms = 0
  eq(t.radius, 4)
  raises(function() t.nope = 1 end, "unknown theme field")
  yes(#t:fields() > 80, "theme fields")
  local win = {x = 20, y = 20, w = 400, h = 0}
  local stats = {x = 500, y = 20, w = 200, h = 0}
  local logo = assert(goome.bitmap_from_argb((function() local a = {} for i = 1, 64 do a[i] = 0xFF2A409A end return a end)(), 8, 8))
  local tab, vol, n, color, mode, on, more, name = 1, 0.5, 3, 0xFF4FA3FF, 1, false, true, "hi"
  local text = "line one\nline two"
  local split, about, tree = 0.4, true, true
  for _ = 1, 8 do
    for ev in g:events(0) do u:feed(ev) end
    local c = u:begin(0)
    if c then
      if u:window("main", win, goome.WIN_MOVE + goome.WIN_RESIZE + goome.WIN_COLLAPSE) then
        tab = u:tabs("tabs", {"A", "B"}, tab)
        u:push_id(tab)
        if u:scroll("page", 300) then
          u:heading("Head")
          u:row(2)
          u:button("One")
          u:button("Two")
          u:tooltip("tip")
          u:hovered()
          u:label("100% sure %s %d")
          u:label(42)
          u:wrapped("some long text that wraps around a bit")
          u:separator()
          u:space(4)
          u:width(120)
          on = u:toggle("Toggle", on)
          mode = u:radio("Small", mode, 0)
          u:same_line()
          mode = u:radio("Big", mode, 1)
          vol = u:slider("Vol", vol, 0, 1, "%.2f")
          n = u:slider_int("N", n, 0, 10)
          u:progress(vol, string.format("%d%%", vol * 100))
          u:progress(-1)
          color = u:color("Color", color)
          name = u:input("Name", name)
          name = u:input_ex("Hint", name, goome.INPUT_ENTER_RETURNS, "type")
          u:password("Pw", "secret", "8 letters")
          local shown
          shown, more = u:collapsing("More", more)
          if shown then
            for k = 0, 2 do u:selectable("Item " .. k, k == 1) end
          end
          u:collapsing("Self kept")
          u:image(logo, 32, 32, 6)
          u:image_button("img", logo, 24, 24)
          text = u:text_edit("body", text, 80, goome.EDIT_LINE_NUMBERS)
          if u:table("files", 2, 80, goome.TABLE_SORTABLE) then
            u:table_column("Name")
            u:table_column("Size", 60)
            u:table_sort()
            for i = 1, 3 do
              u:table_row()
              u:label("f" .. i)
              u:table_next()
              u:label(i * 10)
            end
          end
          u:table_end()
          local open
          open, tree = u:tree("Tree", tree)
          if open then
            u:label("leaf")
            u:tree_end()
          end
          local a, b = u:list_clip(100, 20)
          yes(a >= 1 and b >= 0, "list clip")
          u:drag_float("Speed", 1.5, 0.1, 0, 10)
          u:drag_int("Count", 3, 1, 0, 10)
          u:number("Price", 1.25, 0.01, "%.2f")
          u:plot_lines("fps", {1, 3, 2, 5, 4})
          u:plot_bars("bars", {1, 3, 2}, 0, 5, 40)
          local sh
          sh, split = u:split("sp", split, false)
          if sh then
            u:label("left")
            u:split_next()
            u:label("right")
          end
          u:split_end()
          u:button("drag me")
          u:drag_source("txt", "hello")
          u:button("drop here")
          eq(u:drop_target("txt"), nil, "nothing dropped")
          u:spinner(12)
          u:link("a link")
          u:badge("new")
          u:push_color("accent", 0xFFF59E0B)
          u:push_num(goome.S_RADIUS, 99)
          u:push_radii({2, 4, 6, 8})
          u:push_font(nil)
          u:push_skin("button", {logo, 2})
          u:push_icon(goome.ICON_CHECK, logo)
          u:button("Styled")
          u:pop(6)
          u:pos(5, 5)
          u:size(30, 20)
          local hit, item = u:custom("knob", 40, 40, goome.ITEM_DRAG_Y)
          yes(type(item.x) == "number" and type(hit) == "boolean", "custom")
          local cc = u:canvas()
          if cc then cc:circle(item.x + 20, item.y + 20, 10, 0xFFFFFFFF) end
          local st = u:store("knob", 2)
          st[1] = st[1] + 1
          yes(#st == 2 and st[1] >= 1, "store")
          u:focused()
          u:set_focus()
          u:button("focus me")
          if u:context("ctx") then
            u:menu_item("Copy", "Ctrl+C")
            u:context_end()
          end
          u:popup_open("pop")
          if u:popup("pop") then
            u:label("in a popup")
            u:popup_close()
            u:popup_end()
          end
        end
        u:scroll_end()
        u:pop_id()
      end
      u:window_end()
      if u:window("Stats", stats, goome.WIN_MOVE + goome.WIN_CLOSE) then
        u:label("stats")
      end
      u:window_end()
      local shown
      shown, about = u:modal("About", about)
      if shown then
        u:label("made with goome")
        u:modal_end()
      end
      u:toast("hi", 100)
      u:hit(0, 0, 4, 4)
      u:animating()
      u:wants()
      u:wants_mouse()
      u:wants_keyboard()
      u:finish()
    end
  end
  eq(stats.open, true)
  stats.open = false
  u:begin(0)
  eq(u:window("Stats", stats, goome.WIN_CLOSE), false)
  u:window_end()
  u:finish()
  logo:close()
  u:close()
  g:close()
end)

test("ui app and menus", function()
  local g = assert(goome.open{backend = "test", test_script = "screen 600x400 1; end 4"})
  local u = g:ui()
  local checked = false
  for _ = 1, 3 do
    for ev in g:events(0) do u:feed(ev) end
    if u:begin(0) then
      if u:app("Notes", goome.APP_MENUBAR + goome.APP_STATUSBAR) then
        if u:menubar() then
          if u:menu("File") then
            local _
            _, checked = u:menu_item("Wrap", nil, checked)
            u:menu_separator()
            u:menu_item("Quit", "Ctrl+Q")
            u:menu_end()
          end
          u:menubar_end()
        end
        u:label("hello")
        u:statusbar("ready")
      end
      u:app_end()
      u:finish()
    end
  end
  u:close()
  g:close()
end)

test("theme objects and config", function()
  local g = assert(goome.open{backend = "test", test_script = "end 4"})
  local u = g:ui()
  local t = goome.theme()
  t:preset("midnight")
  raises(function() t:preset("nope") end, "bad preset")
  t:make(0xFF6FDC5F, true, 6)
  local copy = u:theme():copy()
  copy.accent = 0xFF000000
  yes(u:theme().accent ~= 0xFF000000, "copy is separate")
  u:theme_preset("paper")
  u:theme_make(0xFFF59E0B, false, 8)
  u:scale(1.25)
  local f = assert(goome.font_from_bytes(data("dejavu-sub.ttf")))
  u:theme().font = f
  eq(u:theme().font, f, "theme font")
  f:close()
  eq(u:theme().font, f, "font kept while the theme uses it")
  local bm = assert(goome.bitmap_from_argb({0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF}, 2, 2))
  u:theme().skin_button = {bm, 1}
  eq(u:theme().skin_button[1], bm, "skin")
  u:theme():icon(goome.ICON_CLOSE, bm)
  eq(u:theme():icon(goome.ICON_CLOSE), bm, "icon")
  bm:close()
  local cfg = u:config()
  cfg.tip_delay_ms = 0
  eq(cfg.tip_delay_ms, 0)
  cfg.esc_closes = false
  eq(cfg.esc_closes, false)
  local eased = 0
  cfg.ease = function(x)
    eased = eased + 1
    return x
  end
  cfg.mask = "*"
  eq(cfg.mask, "*")
  yes(#cfg:keys(goome.ACT_COPY) >= 1, "copy keys")
  assert(u:bind(goome.ACT_COPY, "ctrl+c, ctrl+insert"))
  cfg:cursor(goome.CUR_BUTTON, goome.CURSOR_HAND)
  eq(cfg:cursor(goome.CUR_BUTTON), goome.CURSOR_HAND)
  for _ = 1, 3 do
    for ev in g:events(0) do u:feed(ev) end
    if u:begin(0) then
      u:push_theme(t)
      if u:window("w", {x = 10, y = 10, w = 200, h = 0}) then
        u:button("hi")
        u:input("pw", "abc")
      end
      u:window_end()
      u:pop()
      u:finish()
    end
  end
  cfg:reset()
  eq(cfg.ease, nil, "reset ease")
  u:close()
  raises(function() u:button("x") end, "closed ui")
  raises(function() return cfg.tip_delay_ms end, "config of closed ui")
  g:close()
end)

test("ui outlives nothing", function()
  local g = assert(goome.open{backend = "test", test_script = "end 3"})
  local u = g:ui()
  g:close()
  eq(u:closed(), true, "ui closed with goome")
  u:close()
  raises(function() u:begin(0) end, "begin on closed ui")
end)

test("offscreen", function()
  local g = assert(goome.open_offscreen(200, 150, 2))
  local u = g:ui()
  u:theme().anim_ms = 0
  local win = {x = 10, y = 10, w = 180, h = 0}
  local check = false
  g:push_click(30, 50)
  g:push_text("hi")
  for _ = 1, 3 do
    for ev in g:events(0) do u:feed(ev) end
    if u:begin(0) then
      if u:window("off", win, goome.WIN_MOVE) then
        check = u:checkbox("Check", check)
      end
      u:window_end()
      u:finish()
    end
  end
  local f = assert(g:last_frame())
  eq(f.w, 400)
  eq(f.h, 300)
  local r = g:frame_dirty()
  yes(r and r.w > 0, "dirty rect")
  local bytes = g:frame_copy(goome.FMT_RGBA, {0, 0, 4, 2})
  eq(#bytes, 4 * 2 * 4)
  eq(#g:frame_copy(), 400 * 300 * 4)
  assert(g:resize(300, 200, 1))
  eq(g:hit(1000, 1000), false)
  yes(type(g:cursor()) == "number", "cursor")
  assert(g:clipboard("copied"))
  eq(g:clipboard(), "copied")
  g:push(goome.MOTION, {x = 5, y = 5})
  g:push({type = goome.KEY, key = 97, text = "a"})
  u:close()
  g:close()
end)

test("gc", function()
  for _ = 1, 50 do
    local g = goome.open{backend = "test", test_script = "end 2"}
    local u = g:ui()
    local b = goome.bitmap_from_argb({0xFFFFFFFF}, 1, 1)
    local f = goome.font_from_bytes(data("dejavu-sub.ttf"))
    u:theme().font = f
    u:theme().skin_panel = b
    local c = g:begin(0)
    local p = c:pixels()
    local _ = p
  end
  collectgarbage()
  collectgarbage()
end)

local scenes_out
local function scenes()
  if not scenes_out then
    scenes_out = run_c(root .. "tests/scenes.c", "scenes", " " .. root .. "tests/data"):gsub("\r", "")
  end
  return scenes_out
end

local function c_line(tag)
  for l in scenes():gmatch("[^\n]+") do
    if l:sub(1, #tag + 1) == tag .. " " then return l end
  end
  error("the C scenes didnt print " .. tag)
end

local function c_block(tag)
  local lines, on = {}, false
  for l in scenes():gmatch("[^\n]+") do
    if on and not l:match("^%-?%d+ %-?%d+ %d+ ") then break end
    if on then lines[#lines + 1] = l end
    if l:match("^" .. tag .. " %d+$") then on = true end
  end
  return lines
end

local function hexes(list)
  local t = {}
  for i, v in ipairs(list) do t[i] = hex(v) end
  return table.concat(t, " ")
end

test("ease", function()
  eq(goome.EASE_SMOOTH, 0, "EASE_SMOOTH")
  eq(goome.EASE_CUSTOM, 5, "EASE_CUSTOM")
  eq(goome.EASE_IN, 6, "EASE_IN")
  eq(goome.EASE_SPRING, 7, "EASE_SPRING")
  eq(goome.EASE_BOUNCE, 8, "EASE_BOUNCE")
  eq(goome.ease(goome.EASE_LINEAR, 0.25), 0.25, "linear")
  eq(goome.ease(goome.EASE_IN, 0.5), 0.125, "in")
  eq(goome.ease(goome.EASE_OUT, 0.5), 0.875, "out")
  eq(goome.ease(goome.EASE_IN_OUT, 0.25), 0.0625, "in out")
  eq(goome.ease(goome.EASE_BOUNCE, 0.25), 0.47265625, "bounce")
  eq(goome.ease(goome.EASE_OUT, -3), 0, "clamp low")
  eq(goome.ease(goome.EASE_IN, 7), 1, "clamp high")
  local peak = 0
  for i = 1, 99 do peak = math.max(peak, goome.ease(goome.EASE_SPRING, i / 100)) end
  yes(peak > 1.1 and peak < 1.25, "spring overshoot " .. peak)
end)

test("anim frames match C", function()
  local g = assert(goome.open{backend = "test", mode = "window", width = 300, height = 200, test_script = "end 100000"})
  local u = g:ui()
  local k = {on = false}
  local function frame()
    for ev in g:events(0) do u:feed(ev) end
    if not u:begin(0) then return end
    local r = u:canvas()
    k.box = u:anim("box", k.on and 200 or 10, 160, goome.EASE_OUT)
    k.sp = u:anim("spring", k.on and 1 or 0, 320, goome.EASE_SPRING)
    k.col = u:anim_color("col", k.on and 0xFF20D060 or 0, 200, goome.EASE_LINEAR)
    k.last = u:anim("gone", k.on and 5 or 0, 100, goome.EASE_LINEAR)
    if r then
      r:rect(k.box, 20, 60, 40, 0xFFE0A030)
      r:rrect(20 + k.sp * 180, 90, 50, 30, 15, 0xFF4FB3F7)
      r:rect(20, 140, 260, 40, k.col)
    end
    u:finish()
    k.hash = g:last_frame():hash()
  end
  frame()
  yes(k.box == 10 and k.sp == 0 and k.col == 0 and k.last == 0, "start values")
  frame()
  eq(u:animating(), false, "animating at rest")
  k.on = true
  local hs, prev, over, mid = {}, k.box, 0, nil
  for f = 0, 59 do
    frame()
    if f == 1 or f == 4 or f == 8 then hs[#hs + 1] = k.hash end
    yes(k.box >= prev, "box only grows")
    prev = k.box
    over = math.max(over, k.sp)
    if f == 6 then mid = k.col end
  end
  hs[#hs + 1] = k.hash
  yes(k.box == 200 and k.sp == 1 and k.col == 0xFF20D060 and k.last == 5, "end values")
  yes(over > 1.05, "spring overshoot")
  local a = math.floor(mid / 16777216)
  yes(a > 0x70 and a < 0x90, "half way color")
  eq(hexes(hs), "0226f2f5 906d3ce5 db5848ad 12bea72d", "anim hashes")
  eq("anim " .. hexes(hs), c_line("anim"), "anim hashes vs C")
  u:close()
  g:close()
end)

local function txt_hash(c, f, size, s, argb, dir, w, h)
  c:pixels():fill(0)
  c.w, c.h, c.kx0, c.ky0, c.kx1, c.ky1 = w, h, 0, 0, w, h
  goome.text_dir(dir)
  c:font_text(f, size, 4, 4, s, argb)
  goome.text_dir(goome.DIR_AUTO)
  c.w, c.h = 400, 120
  return c:hash()
end

test("emoji and rtl text match C", function()
  local f = assert(goome.font_from_bytes(data("colr.ttf")))
  local cb = assert(goome.font_from_bytes(data("cbdt.ttf")))
  local sb = assert(goome.font_from_bytes(data("sbix.ttf")))
  local d = assert(goome.font_from_bytes(data("dejavu-sub.ttf")))
  local function near(a, b) return math.abs(a - b) < 0.01 end
  yes(near(f:width("\240\159\152\128\240\159\143\187", 30), 24), "skin tone")
  yes(near(f:width("\240\159\152\128\226\128\141\240\159\152\128", 30), 24), "zwj")
  yes(near(f:width("\226\157\164", 30), 18) and near(f:width("\226\157\164\239\184\143", 30), 24), "variation selector")
  local c = goome.canvas(400, 120)
  local heb = "ab \215\144\215\145\215\146 (12) c"
  local arab = "\216\168\217\132\216\167\217\133 \216\168\216\168\216\168 \217\132\217\133 \216\168\217\142\216\168"
  local got = {}
  got[1] = txt_hash(c, f, 30, "ab \240\159\152\128 \240\159\152\128\240\159\143\187 \240\159\152\128\226\128\141\240\159\152\128 \226\157\164 \226\157\164\239\184\143", 0xFF2040A0, "auto", 400, 60)
  c:pixels():fill(0)
  c.kx0, c.ky0, c.kx1, c.ky1 = 0, 0, 0, 0
  c:font_text(cb, 16, 4, 4, "\240\159\144\177", 0xFFFFFFFF)
  c:font_text(cb, 64, 30, 4, "\240\159\144\177", 0xFFFFFFFF)
  c:font_text(sb, 40, 120, 4, "\240\159\144\177\240\159\144\177", 0x80FFFFFF)
  local mid = c:pixel(65, 44)
  yes(math.floor(mid / 16777216) == 255, "cat is solid")
  got[2] = c:hash()
  eq(d:fallback(f), d, "fallback returns the font")
  d:fallback(d)
  d:fallback(f)
  yes(near(d:width("goome! \240\159\152\128", 20), d:width("goome! ", 20) + 16), "fallback width")
  got[3] = txt_hash(c, d, 20, "goome! \240\159\152\128 Hi", 0xFFFFFFFF, goome.DIR_AUTO, 400, 40)
  got[4] = txt_hash(c, f, 24, heb, 0xFFFFFFFF, "auto", 400, 40)
  eq(hex(txt_hash(c, f, 24, heb, 0xFFFFFFFF, "ltr", 400, 40)), hex(got[4]), "ltr = auto here")
  got[5] = txt_hash(c, f, 24, heb, 0xFFFFFFFF, goome.DIR_RTL, 400, 40)
  got[6] = txt_hash(c, f, 30, arab, 0xFFFFFFFF, "auto", 400, 50)
  raises(function() goome.text_dir("sideways") end, "bad dir")
  eq(hexes(got), "3bab3875 85fe883a d3add387 b79518dd 49a72d7d 469719e1", "emoji rtl hashes")
  eq("emoji " .. hexes(got), c_line("emoji"), "emoji rtl hashes vs C")
  eq(string.format("measure %.3f %.3f", d:width("goome! \240\159\152\128", 20), f:width("\216\168\217\132\216\167\217\133 \216\168\216\168\216\168 \217\132\217\133", 20)), c_line("measure"), "measure vs C")
  f:close()
  yes(d:width("goome! \240\159\152\128", 20) > d:width("goome! ", 20) + 15, "fallback still alive after close")
  d:close()
  cb:close()
  sb:close()
end)

test("font fallback lifetime", function()
  for _ = 1, 30 do
    local a = goome.font_from_bytes(data("dejavu-sub.ttf"))
    local b = goome.font_from_bytes(data("colr.ttf"))
    a:fallback(b)
    b:fallback(a)
    b:close()
  end
  collectgarbage()
  collectgarbage()
  local a = goome.font_from_bytes(data("dejavu-sub.ttf"))
  a:fallback(goome.font_from_bytes(data("colr.ttf")))
  collectgarbage()
  collectgarbage()
  local c = goome.canvas(100, 40)
  c:font_text(a, 20, 0, 0, "\240\159\152\128")
  yes(c:hash() ~= goome.canvas(100, 40):hash(), "fallback kept alive by its font")
  a:close()
  raises(function() a:fallback(a) end, "closed font")
end)

test("ime events", function()
  local long = string.rep("q", 80)
  local g = assert(goome.open{backend = "test", mode = "window", width = 100, height = 100,
    test_script = "1 text " .. long .. ";2 preedit \227\129\171\227\129\187\227\130\147 3;3 preedit abc;4 preedit;end 10"})
  eq(goome.TEXT, goome.DROP + 1, "TEXT")
  eq(goome.PREEDIT, goome.DROP + 2, "PREEDIT")
  assert(g:push_ime("hi"))
  local ev = g:poll(0)
  yes(ev and ev.type == goome.TEXT and ev.msg == "hi" and ev.ime == "hi", "pushed text")
  eq(g:event_text(), "hi", "event_text")
  assert(g:text_input(true, {10, 20, 1, 16}))
  assert(g:text_input(false))
  local got, quit = 0, false
  for _ = 1, 20 do
    for e in g:events(0) do
      if e.type == goome.QUIT then quit = true end
      if e.type == goome.TEXT then
        got = got + 1
        eq(#e.msg, 63, "cut msg")
        eq(e.ime, long, "full text")
        eq(g:event_text(), long, "event_text full")
      end
      if e.type == goome.PREEDIT and e.ime == "\227\129\171\227\129\187\227\130\147" then
        got = got + 2
        eq(e.caret, 3, "caret")
        eq(g:preedit_cursor(), 3, "preedit_cursor")
      end
      if e.type == goome.PREEDIT and e.msg == "abc" then
        got = got + 4
        eq(e.caret, 3, "caret at end")
      end
      if e.type == goome.PREEDIT and e.msg == "" then
        got = got + 8
        yes(e.caret == 0 and e.ime == "" and g:event_text() == "", "preedit done")
      end
    end
    local c = g:begin(0)
    if c then g:finish(c) end
    if quit then break end
  end
  eq(got, 15, "ime events seen")
  g:close()
end)

local function ime_ui(in_text, ed_text, focus)
  local g = assert(goome.open{backend = "test", mode = "window", width = 300, height = 200, test_script = "end 100000"})
  local u = g:ui()
  local th = u:theme()
  th.font, th.font_size, th.anim_ms = nil, 14, 0
  u:config().blink_ms = 0
  local k = {g = g, u = u, input = in_text, ed = ed_text}
  function k.frame(fo)
    for e in g:events(0) do u:feed(e) end
    if not u:begin(0) then return end
    if fo == 1 then u:set_focus() end
    k.input = u:input_ex("in", k.input, goome.INPUT_NO_SELECT_ON_FOCUS, nil, 64)
    if fo == 2 then u:set_focus() end
    k.ed = u:text_edit("ed", k.ed, 80, 0, 96)
    u:finish()
    k.hash = g:last_frame():hash()
  end
  function k.ime(text) g:push_ime(text) k.frame(0) end
  function k.preedit(text, cur) g:push_preedit(text, cur) k.frame(0) end
  k.frame(focus)
  k.frame(0)
  return k
end

test("ime in the ui kit matches C", function()
  local k = ime_ui("ab", "", 1)
  local h = {k.hash}
  k.preedit("xyz", 1)
  h[2] = k.hash
  k.preedit("xyz", 3)
  h[3] = k.hash
  yes(h[1] ~= h[2] and h[2] ~= h[3] and k.input == "ab", "preedit draws but doesnt type")
  k.preedit("", 0)
  eq(hex(k.hash), hex(h[1]), "preedit gone")
  k.ime("\230\151\165\230\156\172")
  eq(k.input, "ab\230\151\165\230\156\172", "commit")
  eq("commit " .. k.input, c_line("commit"), "commit vs C")
  k.u:close()
  k.g:close()
  k = ime_ui("", "line", 2)
  h[4] = k.hash
  k.preedit("kana", 2)
  local edh = k.hash
  k.preedit("", 0)
  k.ime("\227\129\139\227\129\170\n")
  eq(k.ed, "\227\129\139\227\129\170\nline", "text edit commit")
  k.u:close()
  k.g:close()
  eq(hex(h[2]) .. " " .. hex(h[3]) .. " " .. hex(edh), "2e20540f ceafcbad c9c1add5", "ime hashes")
  eq("ime " .. hexes({h[1], h[2], h[3], h[4], edh}), c_line("ime"), "ime hashes vs C")
end)

test("a11y tree matches C", function()
  local g = assert(goome.open{backend = "test", mode = "window", width = 420, height = 700, test_script = "end 100000"})
  local u = g:ui()
  u:theme().font = nil
  local k = {ok = 0, dark = false, mode = 0, vol = 2, name = "Bo", fruit = 1, tab = 1, open = false, note = "", knob = 0}
  local tree
  local function frame()
    for e in g:events(0) do u:feed(e) end
    if not u:begin(0) then return end
    u:app("Demo", goome.APP_TITLEBAR + goome.APP_STATUSBAR)
    u:label("Hello there")
    if u:button("OK") then k.ok = k.ok + 1 end
    k.dark = u:checkbox("Dark", k.dark)
    k.mode = u:radio("Big", k.mode, 1)
    k.vol = u:slider("Volume", k.vol, 0, 10, "%.1f")
    k.name = u:input("Name", k.name, 64)
    k.fruit = u:combo("Fruit", k.fruit, {"Mango", "Kiwi", "Fig"})
    k.tab = u:tabs("tabs", {"One", "Two"}, k.tab)
    local shown
    shown, k.open = u:tree("Folder", k.open)
    if shown then
      u:label("inside")
      u:tree_end()
    end
    u:progress(0.25)
    k.note = u:text_edit("Notes", k.note, 60, 0, 256)
    u:a11y_role(goome.ROLE_BUTTON, "Knob")
    u:a11y_value("11")
    local _, it = u:custom("knob", 40, 40, 0)
    if it.clicked then k.knob = k.knob + 1 end
    u:statusbar("ready")
    u:app_end()
    u:finish()
    tree = u:a11y_tree()
  end
  local function find(role, label)
    for i, n in ipairs(tree) do
      if n.role == role and n.label == label then return i, n end
    end
  end
  local function send(verb, role, label, text)
    local _, n = find(role, label)
    yes(n, "node " .. label)
    g:push{type = goome.CONTROL, msg = string.format("a11y %s %.0f%s", verb, n.id, text and " " .. text or "")}
  end
  local function dump()
    local t = {}
    for i, n in ipairs(tree) do
      t[i] = string.format("%d %d %d %.3f %.3f %.3f %.3f [%s] [%s] %.0f %.3f %.3f %.3f %d", n.role, (n.parent or 0) - 1, n.states,
        n.x, n.y, n.w, n.h, n.label, n.value, n.id, n.num, n.min, n.max, n.caret)
    end
    return t
  end
  local function same(want, what)
    local got = dump()
    eq(#got, #want, what .. " count")
    for i = 1, #want do eq(got[i], want[i], what .. " node " .. i) end
  end
  frame()
  yes(#tree > 15, "tree size")
  local app, root = find(goome.ROLE_WINDOW, "Demo")
  yes(app == 1 and root.parent == nil, "root window")
  local _, ok = find(goome.ROLE_BUTTON, "OK")
  yes(ok.parent == 1 and ok.w > 0 and ok.h > 0, "ok button")
  local _, vol = find(goome.ROLE_SLIDER, "Volume")
  yes(vol.num == 2 and vol.min == 0 and vol.max == 10 and vol.value == "2.0", "slider node")
  local _, two = find(goome.ROLE_TAB, "Two")
  local _, one = find(goome.ROLE_TAB, "One")
  yes(tree[two.parent].role == goome.ROLE_GROUP and not two.selected and one.selected, "tabs")
  yes(one.states == goome.A11Y_SELECTED, "states number")
  local _, knob = find(goome.ROLE_BUTTON, "Knob")
  eq(knob.value, "11", "custom value")
  same(c_block("a11y"), "first frame")
  send("press", goome.ROLE_BUTTON, "OK")
  send("press", goome.ROLE_CHECKBOX, "Dark")
  send("set", goome.ROLE_SLIDER, "Volume", "7.5")
  send("set", goome.ROLE_INPUT, "Name", "hello there")
  send("expand", goome.ROLE_TREE, "Folder")
  send("press", goome.ROLE_TAB, "Two")
  frame()
  frame()
  eq(string.format("state %d %d %.3f %s %d %d", k.ok, k.dark and 1 or 0, k.vol, k.name, k.open and 1 or 0, k.tab - 1), c_line("state"), "state vs C")
  local _, dark = find(goome.ROLE_CHECKBOX, "Dark")
  yes(dark.checked, "checked")
  local _, folder = find(goome.ROLE_TREE, "Folder")
  local _, inside = find(goome.ROLE_TEXT, "inside")
  yes(folder.expanded and inside and tree[inside.parent] == folder, "tree open")
  same(c_block("a11y after"), "after actions")
  u:a11y(false)
  frame()
  eq(#tree, 0, "a11y off")
  u:close()
  g:close()
  local o = assert(goome.open_offscreen(200, 100))
  local ou = o:ui()
  ou:theme().font = nil
  for pass = 0, 1 do
    if ou:begin(0) then ou:button("Hi") ou:finish() end
    eq(#ou:a11y_tree(), pass, "offscreen a11y pass " .. pass)
    ou:a11y(true)
  end
  ou:close()
  o:close()
end)

print(string.format("%d passed, %d failed, %d skipped (%s)", passed, failed, skipped, jit and jit.version or _VERSION))
os.exit(failed == 0 and 0 or 1)
