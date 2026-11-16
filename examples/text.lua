local goome = require("goome")

local font = arg[1] and goome.font_load(arg[1]) or goome.font_system()
if arg[2] and font then
  local emoji = goome.font_load(arg[2])
  if emoji then font:fallback(emoji) end
end

local app = goome.app("Text", 640, 460)
local lines = {
  "emoji \240\159\152\128 \240\159\145\141\240\159\143\189 \240\159\145\169\226\128\141\240\159\146\187 \226\157\164\239\184\143",
  "\215\169\215\156\215\149\215\157 \215\162\215\149\215\156\215\157 (123) goome",
  "\217\133\216\177\216\173\216\168\216\167 \216\168\216\167\217\132\216\185\216\167\217\132\217\133",
  "mixed: hi \215\169\215\156\215\149\215\157 and \217\133\216\177\216\173\216\168\216\167 2026",
}
local dir, typed, preedit, last = 1, "", "", ""

app:event(function(ev)
  if ev.type == goome.PREEDIT then preedit = ev.ime end
  if ev.type == goome.TEXT then last = ev.ime end
end)

app:frame(function(ui)
  if font then ui:push_font(font) end
  dir = ui:combo("Direction", dir, {"auto", "left to right", "right to left"})
  goome.text_dir(dir - 1)
  for _, l in ipairs(lines) do ui:label(l) end
  typed = ui:input("Type here (ime works too)", typed, 256)
  ui:label("composing: " .. preedit)
  ui:label("last commit: " .. last)
  if font then ui:pop() end
end)

local ok, err = app:run()
if not ok then
  io.stderr:write("cant open a window: " .. tostring(err) .. "\n")
  os.exit(1)
end
