local dir = love.filesystem.getSource()
local base = love.filesystem.getSourceBaseDirectory()
package.cpath = dir .. "/?.so;" .. dir .. "/?.dll;" .. base .. "/?.so;" .. base .. "/?.dll;" .. package.cpath

local goome = require("goome")

local g, ui, data, image
local win = {x = 20, y = 20, w = 260, h = 0}
local volume, name, paused, clicks, angle = 0.5, "player", false, 0, 0

local keys = {
  backspace = goome.K_BACKSPACE, tab = goome.K_TAB, ["return"] = goome.K_ENTER, escape = goome.K_ESC,
  delete = goome.K_DELETE, left = goome.K_LEFT, right = goome.K_RIGHT, up = goome.K_UP, down = goome.K_DOWN,
  home = goome.K_HOME, ["end"] = goome.K_END, pageup = goome.K_PGUP, pagedown = goome.K_PGDN,
}

local function mods()
  local m = 0
  if love.keyboard.isDown("lshift", "rshift") then m = m + goome.SHIFT end
  if love.keyboard.isDown("lctrl", "rctrl") then m = m + goome.CTRL end
  if love.keyboard.isDown("lalt", "ralt") then m = m + goome.ALT end
  if love.keyboard.isDown("lgui", "rgui") then m = m + goome.SUPER end
  return m
end

local function fit(w, h)
  if g then
    g:resize(w, h, 1)
  else
    g = assert(goome.open_offscreen(w, h, 1))
    ui = g:ui()
  end
  data = love.image.newImageData(w, h)
  image = love.graphics.newImage(data)
end

function love.load()
  love.window.setMode(800, 600, {resizable = true})
  fit(love.graphics.getDimensions())
end

function love.resize(w, h)
  fit(w, h)
end

function love.mousemoved(x, y)
  g:push(goome.MOTION, {x = x, y = y})
end

function love.mousepressed(x, y, button)
  if g:hit(x, y) or ui:wants_mouse() then
    g:push(goome.DOWN, {x = x, y = y, button = button == 2 and 3 or button == 3 and 2 or button})
  elseif button == 1 then
    clicks = clicks + 1
  end
end

function love.mousereleased(x, y, button)
  g:push(goome.UP, {x = x, y = y, button = button == 2 and 3 or button == 3 and 2 or button})
end

function love.wheelmoved(_, dy)
  local x, y = love.mouse.getPosition()
  g:push(goome.SCROLL, {x = x, y = y, dy = dy > 0 and -1 or 1})
end

function love.textinput(t)
  g:push_text(t)
end

function love.keypressed(key)
  local k = keys[key] or (#key == 1 and key:byte()) or nil
  local m = mods()
  if k and (keys[key] or m >= goome.CTRL) then g:push(goome.KEY, {key = k, mods = m}) end
  if ui:wants_keyboard() then return end
  if key == "space" then paused = not paused end
  if key == "escape" then love.event.quit() end
end

function love.update(dt)
  if not paused then angle = angle + dt end
  for ev in g:events(0) do ui:feed(ev) end
  if ui:begin(0) then
    if ui:window("Mod menu", win, goome.WIN_MOVE + goome.WIN_COLLAPSE) then
      ui:label("game clicks: " .. clicks)
      volume = ui:slider("Volume", volume, 0, 1, "%.2f")
      name = ui:input("Name", name, 32)
      paused = ui:checkbox("Paused", paused)
      if ui:button("Reset clicks") then clicks = 0 end
    end
    ui:window_end()
    ui:finish()
  end
  local r = g:frame_dirty()
  if r then
    g:frame_copy(goome.FMT_RGBA_PREMUL, r, data:getPointer(), data:getWidth() * 4, true)
    image:replacePixels(data)
  end
  love.mouse.setCursor(love.mouse.getSystemCursor(g:cursor() == goome.CURSOR_IBEAM and "ibeam" or g:cursor() == goome.CURSOR_HAND and "hand" or "arrow"))
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  love.graphics.clear(0.1, 0.11, 0.14)
  love.graphics.push()
  love.graphics.translate(w / 2, h / 2)
  love.graphics.rotate(angle)
  love.graphics.setColor(0.44, 0.86, 0.37)
  love.graphics.polygon("fill", 0, -120, 104, 60, -104, 60)
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(image)
  love.graphics.setBlendMode("alpha")
  love.graphics.print(name .. (paused and " (paused)" or ""), 10, h - 24)
end

function love.quit()
  ui:close()
  g:close()
end
