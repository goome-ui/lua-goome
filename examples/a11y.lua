local goome = require("goome")

local g = assert(goome.open_offscreen(420, 360))
local ui = g:ui()
ui:a11y(true)
local roles = {}
for k, v in pairs(goome) do
  if type(k) == "string" and k:match("^ROLE_") then roles[v] = k:sub(6):lower() end
end

local dark, vol, name, fruit = true, 4, "goome", 2
local function frame()
  for ev in g:events(0) do ui:feed(ev) end
  if not ui:begin(0) then return end
  ui:app("Settings", goome.APP_TITLEBAR)
  ui:label("what a screen reader sees")
  dark = ui:checkbox("Dark mode", dark)
  vol = ui:slider("Volume", vol, 0, 10, "%.0f")
  name = ui:input("Name", name, 64)
  fruit = ui:combo("Fruit", fruit, {"Mango", "Kiwi", "Fig"})
  ui:a11y_role(goome.ROLE_BUTTON, "Big red knob")
  ui:a11y_value("spicy")
  ui:custom("knob", 40, 40, 0)
  ui:button("Save")
  ui:app_end()
  ui:finish()
end

frame()
local tree = ui:a11y_tree()
local depth = {}
for i, n in ipairs(tree) do
  depth[i] = n.parent and depth[n.parent] + 1 or 0
  local st = {}
  for _, s in ipairs({"focused", "checked", "disabled", "expanded", "selected"}) do
    if n[s] then st[#st + 1] = s end
  end
  print(string.format("%s%s \"%s\"%s%s", string.rep("  ", depth[i]), roles[n.role] or n.role, n.label,
    n.value ~= "" and " = " .. n.value or "", #st > 0 and " (" .. table.concat(st, ", ") .. ")" or ""))
end

for _, n in ipairs(tree) do
  if n.label == "Volume" then g:push{type = goome.CONTROL, msg = string.format("a11y set %.0f 9", n.id)} end
end
frame()
print("volume after the screen reader set it: " .. vol)
ui:close()
g:close()
