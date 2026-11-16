local goome = require("goome")

local path = arg[1] or "offscreen.ppm"
local script = {
  [2] = {{goome.DOWN, 40, 109}, {goome.UP, 40, 109}},
  [3] = {{goome.DOWN, 60, 163}},
  [4] = {{goome.MOTION, 250, 163}},
  [5] = {{goome.UP, 250, 163}},
  [6] = {{goome.DOWN, 150, 223}, {goome.UP, 150, 223}},
  [7] = {{"type", " from an engine"}},
  [8] = {{goome.MOTION, 80, 279}},
}

local g = assert(goome.open_offscreen(360, 330, 2))
local ui = g:ui()
ui:theme().anim_ms = 0
local win = {x = 20, y = 20, w = 320, h = 0}
local check, volume, name = false, 0.25, "goome"
for frame = 0, 9 do
  for _, step in ipairs(script[frame] or {}) do
    if step[1] == "type" then
      g:push_text(step[2])
    else
      g:push(step[1], {x = step[2], y = step[3], button = 1})
    end
  end
  for ev in g:events(0) do ui:feed(ev) end
  if ui:begin(0) then
    if ui:window("offscreen", win, goome.WIN_MOVE) then
      ui:label("no window, the engine owns the screen")
      check = ui:checkbox("Pushed a click", check)
      volume = ui:slider("Volume", volume, 0, 1, "%.2f")
      name = ui:input("Name", name, 64)
      ui:progress(volume)
      ui:button("Hover me")
    end
    ui:window_end()
    ui:finish()
  end
end

local f = g:last_frame()
local out = goome.canvas(f.w, f.h)
for y = 0, f.h - 1, 16 do
  for x = 0, f.w - 1, 16 do
    out:rect(x, y, 16, 16, (math.floor(x / 16) + math.floor(y / 16)) % 2 == 0 and 0xFF2E3C4A or 0xFF3A4A5A)
  end
end
local layer = goome.canvas(f.w, f.h)
local px = layer:pixels()
for y = 0, f.h - 1 do
  for x = 0, f.w - 1 do px:set(x, y, f:pixel(x, y)) end
end
out:blit(layer, 1, 0, 0)
out:save_ppm(path)
local cursors = {"arrow", "ibeam", "hand", "move", "resize_ew", "resize_ns", "resize_nwse", "resize_nesw", "wait", "no", "hidden"}
print(string.format("check %d volume %.2f name '%s' cursor %s -> %s", check and 1 or 0, volume, name, cursors[g:cursor() + 1], path))
ui:close()
g:close()
