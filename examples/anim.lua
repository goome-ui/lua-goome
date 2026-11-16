local goome = require("goome")

local app = goome.app("Animations", 560, 420)
local eases = {
  {"linear", goome.EASE_LINEAR}, {"in", goome.EASE_IN}, {"out", goome.EASE_OUT}, {"in out", goome.EASE_IN_OUT},
  {"smooth", goome.EASE_SMOOTH}, {"back", goome.EASE_BACK}, {"spring", goome.EASE_SPRING}, {"bounce", goome.EASE_BOUNCE},
}
local on, ms = false, 600

app:frame(function(ui)
  if ui:button(on and "Slide back" or "Slide") then on = not on end
  ui:same_line()
  ms = ui:slider("Time", ms, 100, 2000, "%.0f ms")
  local _, it = ui:custom("track", 0, #eases * 30, 0)
  local c = ui:canvas()
  for i, e in ipairs(eases) do
    local y = it.y + (i - 1) * 30
    local t = ui:anim(e[1], on and 1 or 0, ms, e[2])
    local col = ui:anim_color(e[1] .. " color", on and 0xFF4FB3F7 or 0xFFE0A030, ms, e[2])
    c:text(it.x, y + 8, e[1], 0xFFB0B8C0)
    c:rrect(it.x + 70 + t * (it.w - 110), y + 2, 36, 24, 8, col)
  end
  local t = ui:anim("fade", on and 1 or 0, ms, goome.EASE_OUT)
  ui:label(string.format("fade %.2f, ease(spring, 0.5) = %.3f", t, goome.ease(goome.EASE_SPRING, 0.5)))
end)

local ok, err = app:run()
if not ok then
  io.stderr:write("cant open a window: " .. tostring(err) .. "\n")
  os.exit(1)
end
