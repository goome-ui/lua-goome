local goome = require("goome")

local g, err = goome.open("goome hello")
if not g then
  io.stderr:write("cant open an overlay: " .. err .. "\n")
  os.exit(1)
end

local mons = g:monitors()
print("backend: " .. g:backend_name())
for i, m in ipairs(mons) do
  local a = m.area
  print(string.format("monitor %d: %s %dx%d at %d,%d scale %.2f", i - 1, m.name, a.w, a.h, a.x, a.y, m.scale))
end
if not g:hotkey("alt+h", 1) then print("no global hotkeys here: " .. g:error()) end
io.stdout:flush()

local bx, by = mons[1].area.x + 80, mons[1].area.y + 80
local clicks, hidden, typing, running = 0, false, false, true
local typed = ""
local pace = goome.pacer(30)
while running do
  for ev in g:events(pace:wait()) do
    if ev.type == goome.QUIT then running = false end
    if ev.type == goome.DOWN then
      print(string.format("click %.0f,%.0f", ev.x, ev.y))
      if ev.x > bx + 250 and ev.y < by + 30 then
        running = false
      elseif ev.y > by + 80 then
        typing = not typing
        g:keyboard(typing)
      else
        clicks = clicks + 1
      end
    end
    if ev.type == goome.KEY then
      print(string.format("key %d mods %x text '%s'", ev.key, ev.mods, ev.text))
      if ev.key == goome.K_ESC then
        running = false
      elseif ev.key == goome.K_BACKSPACE and #typed > 0 then
        typed = typed:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
      elseif #ev.text > 0 and #typed + #ev.text < 40 then
        typed = typed .. ev.text
      end
    end
    if ev.type == goome.HOTKEY or (ev.type == goome.CONTROL and ev.msg == "hide") then hidden = not hidden end
    if ev.type == goome.SCROLL then by = by + ev.dy * 10 end
    io.stdout:flush()
  end
  local c = g:begin(0)
  if c then
    if not hidden then
      c:round_rect(bx, by, 280, 120, 14, 0xE0202838)
      c:frame(bx, by, 280, 120, 2, clicks % 2 == 1 and 0xFF6FDC5F or 0xFF8090A0)
      c:text(bx + 16, by + 12, "hello from goome", 0xFFFFFFFF, true)
      c:line(bx + 256, by + 10, bx + 268, by + 22, 2, 0xFFFF6B8B)
      c:line(bx + 268, by + 10, bx + 256, by + 22, 2, 0xFFFF6B8B)
      c:text(bx + 16, by + 46, "clicks: " .. clicks, 0xFFC0C8D0)
      c:round_rect(bx + 12, by + 80, 256, 28, 8, typing and 0xFF2E4A30 or 0xFF303848)
      local shown = typing and (typed ~= "" and typed or "type something...") or "click here to type"
      c:text(bx + 22, by + 86, shown, 0xFFFFFFFF)
      c:hit(bx, by, 280, 120)
    end
    g:finish(c)
  end
end
g:close()
