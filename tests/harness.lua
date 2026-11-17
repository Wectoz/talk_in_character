-- Loads addon files outside the game: each file gets the (addonName, namespace) varargs.
Harness = {}
local ROOT = "Bronzetongue/"

function Harness.load(files, BT)
  BT = BT or {}
  for _, file in ipairs(files) do
    local chunk = assert(loadfile(ROOT .. file))
    chunk("Bronzetongue", BT)
  end
  return BT
end

--- A fake random(n): yields the given numbers in order, then 1 forever.
function Harness.seq(...)
  local values, i = { ... }, 0
  return function() i = i + 1 return values[i] or 1 end
end
