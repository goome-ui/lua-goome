local path = arg[1] or "native/goome.h"
local out = arg[2] or "src/consts.h"
local f = assert(io.open(path, "rb"))
local src = f:read("*a")
f:close()
local head = src:match("^(.-)#ifdef GOOME_IMPLEMENTATION") or src
local names, seen = {}, {}
for body in head:gmatch("enum%s*{(.-)}") do
  body = body:gsub("//[^\n]*", "")
  for item in body:gmatch("[^,]+") do
    local n = item:match("^%s*GOOME_([A-Z0-9_]+)")
    if n and not seen[n] then
      seen[n] = true
      names[#names + 1] = n
    end
  end
end
local o = assert(io.open(out, "wb"))
for _, n in ipairs(names) do
  o:write(string.format("{\"%s\", GOOME_%s},\n", n, n))
end
o:close()
print(#names .. " constants in " .. out)
