local ADDON, BT = ...

-- Shields the parts of a message that must reach other players byte for byte (links, textures,
-- raid icons, URLs, names). Each one becomes "\1<index>\2", which no word rule can match.
local Protect = {}
BT.Protect = Protect

local WORD = "%w\128-\255" -- bytes that can be part of a word or name, UTF-8 included

local function NamePattern(name)
  local pattern = name:gsub(".", function(c)
    if c:find("%a") then return "[" .. c:lower() .. c:upper() .. "]" end
    if c:find("[%w\128-\255]") then return c end
    return "%" .. c
  end)
  return "%f[" .. WORD .. "]" .. pattern .. "%f[^" .. WORD .. "]"
end

function Protect.Shield(text, names)
  local parts = {}
  local function keep(span)
    parts[#parts + 1] = span
    return "\1" .. #parts .. "\2"
  end
  text = text:gsub("[\1\2]", keep)
  text = text:gsub("||", keep)
  text = text:gsub("|c[^|]*|H.-|h.-|h|r", keep)
  text = text:gsub("|H.-|h.-|h", keep)
  text = text:gsub("|T.-|t", keep)
  text = text:gsub("|A.-|a", keep)
  text = text:gsub("|K.-|k", keep)
  text = text:gsub("|c%x%x%x%x%x%x%x%x", keep)
  text = text:gsub("|.", keep)
  text = text:gsub("{[^{}]*}", keep)
  text = text:gsub("%a+://%S+", keep)
  text = text:gsub("www%.%S+", keep)
  if names then
    for _, name in ipairs(names) do
      if type(name) == "string" and name ~= "" then text = text:gsub(NamePattern(name), keep) end
    end
  end
  return text, parts
end

function Protect.Restore(text, parts)
  -- Last first: a later span can hold an earlier placeholder, never the other way round.
  for index = #parts, 1, -1 do
    local span = parts[index]
    text = text:gsub("\1" .. index .. "\2", function() return span end)
  end
  return text
end
