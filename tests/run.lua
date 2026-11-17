-- lua5.1 tests/run.lua  : runs every global test_* function of every tests/test_*.lua
dofile("tests/harness.lua")
local files = {}
for f in io.popen("ls tests/test_*.lua 2>/dev/null"):lines() do files[#files + 1] = f end
local passed, failed = 0, 0
for _, file in ipairs(files) do
  for name in pairs(_G) do if type(name) == "string" and name:find("^test_") then _G[name] = nil end end
  local ok, err = xpcall(function() dofile(file) end, debug.traceback)
  if not ok then failed = failed + 1 print("FAIL " .. file .. " (load): " .. tostring(err)) end
  local names = {}
  for name, fn in pairs(_G) do
    if type(name) == "string" and name:find("^test_") and type(fn) == "function" then names[#names + 1] = name end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local ok2, err2 = xpcall(_G[name], debug.traceback)
    if ok2 then passed = passed + 1 else failed = failed + 1 print("FAIL " .. file .. " " .. name .. ": " .. tostring(err2)) end
  end
end
if failed > 0 then print(failed .. " failed, " .. passed .. " passed") os.exit(1) end
print("OK " .. passed .. " tests")
