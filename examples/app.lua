local goome = require("goome")

local app = goome.app("Notes", 960, 640, {flags = goome.APP_MENUBAR + goome.APP_STATUSBAR})
local notes = {{name = "groceries", text = "milk\neggs\nmore milk"}, {name = "ideas", text = "a goome app in lua"}}
local pick, split, about, wrap = 1, 0.28, false, true

app:frame(function(ui)
  if ui:menubar() then
    if ui:menu("File") then
      if ui:menu_item("New note", "Ctrl+N") then
        notes[#notes + 1] = {name = "note " .. (#notes + 1), text = ""}
        pick = #notes
      end
      ui:menu_separator()
      if ui:menu_item("Quit", "Ctrl+Q") then app:quit() end
      ui:menu_end()
    end
    if ui:menu("View") then
      local _
      _, wrap = ui:menu_item("Wrap lines", nil, wrap)
      ui:menu_end()
    end
    if ui:menu("Help") then
      if ui:menu_item("About") then about = true end
      ui:menu_end()
    end
    ui:menubar_end()
  end
  local shown
  shown, split = ui:split("main", split)
  if shown then
    for i, n in ipairs(notes) do
      if ui:selectable(n.name, i == pick) then pick = i end
      if ui:context("ctx" .. i) then
        if ui:menu_item("Delete") and #notes > 1 then
          table.remove(notes, i)
          if pick > #notes then pick = #notes end
          ui:toast("deleted it")
        end
        ui:context_end()
      end
    end
    ui:split_next()
    local n = notes[pick]
    n.name = ui:input("Name", n.name, 64)
    n.text = ui:text_edit("body" .. pick, n.text, 0, goome.EDIT_LINE_NUMBERS + (wrap and goome.EDIT_WRAP or 0))
  end
  ui:split_end()
  shown, about = ui:modal("About", about)
  if shown then
    ui:label("made with goome " .. goome.VERSION)
    if ui:button("Ok") then about = false end
    ui:modal_end()
  end
  ui:statusbar(#notes .. " notes")
end)

app:on_close(function()
  return true
end)

local ok, err = app:run()
if not ok then
  io.stderr:write("cant open a window: " .. tostring(err) .. "\n")
  os.exit(1)
end
