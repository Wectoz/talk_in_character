local ADDON, BT = ...

-- Voice registry. A voice is data only: see any file under Voices/ for the format.
BT.voices = {}
BT.KINDS = { "hello", "follow", "wait", "cheer", "battle", "bye", "help", "thanks" } -- wheel order, clockwise from top

local VOICE_KINDS = { race = true, faction = true, class = true }
local TOKENS = { target = true, targetRace = true, targetClass = true }

local function Strings(list)
  if type(list) ~= "table" then return false end
  for _, item in ipairs(list) do if type(item) ~= "string" then return false end end
  return true
end

local function Lines(list, what)
  if not Strings(list) then return what .. " must be a list of strings" end
  local plain = false
  for _, line in ipairs(list) do
    if #line > 255 then return what .. " has a line over 255 bytes" end
    for token in line:gmatch("{(.-)}") do
      if not TOKENS[token] then return what .. " uses unknown token {" .. token .. "}" end
    end
    if not line:find("{", 1, true) then plain = true end
  end
  return nil, plain
end

function BT.ValidateVoice(voice)
  if type(voice) ~= "table" then return false, "voice must be a table" end
  local id = voice.id
  if type(id) ~= "string" or not id:find("^[a-z0-9_]+$") then return false, "bad id" end
  local function fail(message) return false, id .. ": " .. message end
  if type(voice.name) ~= "string" or voice.name == "" then return fail("name missing") end
  if not VOICE_KINDS[voice.kind] then return fail("kind must be race, faction or class") end
  if type(voice.icon) ~= "string" then return fail("icon missing") end

  if type(voice.swaps) ~= "table" then return fail("swaps missing") end
  for key, swap in pairs(voice.swaps) do
    if type(key) ~= "string" or not key:find("^[a-z']+$") then return fail("swap key '" .. tostring(key) .. "' must be one lowercase word") end
    if type(swap) ~= "table" or (swap.tier ~= 1 and swap.tier ~= 2 and swap.tier ~= 3) then return fail("swap '" .. key .. "' needs tier 1, 2 or 3") end
    if #swap < 1 or not Strings(swap) then return fail("swap '" .. key .. "' needs at least one replacement") end
  end

  if type(voice.sounds) ~= "table" then return fail("sounds missing") end
  for index, rule in ipairs(voice.sounds) do
    if type(rule) ~= "table" or (rule.tier ~= 2 and rule.tier ~= 3) or type(rule.pattern) ~= "string" or type(rule.repl) ~= "string" then
      return fail("sound rule " .. index .. " needs tier 2 or 3, a pattern and a repl")
    end
    if not pcall(string.gsub, "test", rule.pattern, rule.repl) then return fail("sound rule " .. index .. " has a bad pattern") end
  end

  for _, field in ipairs({ "openers", "closers" }) do
    local problem = Lines(voice[field], field)
    if problem then return fail(problem) end
  end

  if voice.moods ~= nil then
    if type(voice.moods) ~= "table" then return fail("moods must be a table") end
    for mood, extra in pairs(voice.moods) do
      if type(extra) ~= "table" then return fail("mood " .. tostring(mood) .. " must be a table") end
      for _, field in ipairs({ "openers", "closers" }) do
        if extra[field] ~= nil then
          local problem = Lines(extra[field], "moods." .. tostring(mood) .. "." .. field)
          if problem then return fail(problem) end
        end
      end
    end
  end

  if type(voice.phrases) ~= "table" then return fail("phrases missing") end
  for _, kind in ipairs(BT.KINDS) do
    local list = voice.phrases[kind]
    if type(list) ~= "table" or #list < 3 then return fail("phrases." .. kind .. " needs at least 3 lines") end
    local problem, plain = Lines(list, "phrases." .. kind)
    if problem then return fail(problem) end
    if not plain then return fail("phrases." .. kind .. " needs a line without a {token}") end
  end
  return true
end

function BT.RegisterVoice(voice)
  local ok, problem = BT.ValidateVoice(voice)
  if not ok then error("Talk in Character voice rejected: " .. tostring(problem), 2) end
  if BT.voices[voice.id] then error("Talk in Character voice registered twice: " .. voice.id, 2) end
  BT.voices[voice.id] = voice
end

function BT.VoicesOfKind(kind)
  local list = {}
  for _, voice in pairs(BT.voices) do
    if voice.kind == kind then list[#list + 1] = voice end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end
