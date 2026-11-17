local ADDON, BT = ...

-- Picks the line a wheel slot says, and maps a cursor offset to a wheel slot.
local Phrases = {}
BT.Phrases = Phrases

local DEAD_ZONE = 40 -- pixels: inside this the wheel picks nothing
local TOKENS = { target = "name", targetRace = "race", targetClass = "class" }
local last = {}      -- kind -> the line template picked last time

local function Fillable(line, target)
  for token in line:gmatch("{(.-)}") do
    local value = target and target[TOKENS[token]]
    if type(value) ~= "string" or value == "" then return false end
  end
  return true
end

--- A line of `kind` in the current voice, with the target filled in, or nil.
function Phrases.Pick(kind, opts, target)
  local pool = {}
  for _, id in ipairs({ opts.race or false, opts.class or false }) do
    local voice = BT.voices[id]
    local lines = voice and voice.phrases[kind]
    if lines then
      for _, line in ipairs(lines) do
        if Fillable(line, target) then pool[#pool + 1] = line end
      end
    end
  end
  if #pool == 0 then return nil end

  local random = opts.random or math.random
  local voices = {}
  for _, id in ipairs({ opts.race or false, opts.class or false }) do
    if BT.voices[id] then voices[#voices + 1] = BT.voices[id] end
  end
  for attempt = 1, 5 do
    local index = random(#pool)
    if pool[index] == last[kind] and #pool > 1 then index = index % #pool + 1 end
    local template = pool[index]
    -- Shielding hides the {tokens}, so the mood cannot slur or stutter a name.
    local shielded, parts = BT.Protect.Shield(template)
    shielded = BT.Moods.Apply(shielded, opts.mood or "calm", random, voices)
    local line = BT.Protect.Restore(shielded, parts):gsub("{(.-)}", function(token) return target[TOKENS[token]] end)
    if #line <= 255 then
      last[kind] = template
      return line
    end
  end
  return nil
end

--- The wheel slot (1..8, 1 straight up, clockwise) for a cursor offset from the ring centre.
function Phrases.SlotAt(dx, dy)
  if dx * dx + dy * dy < DEAD_ZONE * DEAD_ZONE then return nil end
  local degrees = math.deg(math.atan2(dx, dy)) -- 0 is up, growing clockwise
  return math.floor(((degrees + 22.5) % 360) / 45) + 1
end
