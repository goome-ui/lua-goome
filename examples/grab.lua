local goome = require("goome")

if #arg < 1 then
  io.stderr:write("usage: grab.lua [monitor] [x y w h] out.ppm\n")
  os.exit(2)
end
local nums = {}
for i = 1, math.min(#arg - 1, 5) do nums[#nums + 1] = tonumber(arg[i]) or 0 end

local g, err = goome.open("goome grab")
if not g then
  io.stderr:write("cant open: " .. err .. "\n")
  os.exit(1)
end
local mon = (#nums == 1 or #nums == 5) and nums[1] or 0
local rect
if #nums >= 4 then rect = {nums[#nums - 3], nums[#nums - 2], nums[#nums - 1], nums[#nums]} end
local img, why, code = g:capture_wait(mon, rect)
if not img then
  io.stderr:write(string.format("grab failed: %s (%s)\n", goome.strerror(code), why))
  g:close()
  os.exit(1)
end
img:save_ppm(arg[#arg])
local a = img.area
print(string.format("%dx%d px of %d,%d %dx%d on monitor %d%s%s", img.w, img.h, a.x, a.y, a.w, a.h, mon,
  img.has_self and ", has our overlay" or "", img.has_cursor and ", has the cursor" or ""))
g:close()
