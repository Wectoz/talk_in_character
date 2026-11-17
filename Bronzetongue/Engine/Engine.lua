local ADDON, BT = ...

-- Turns typed text into voiced text. No game calls in here: it is tested outside the game.
local Engine = {}
BT.Engine = Engine

local MAX_BYTES = 255
local CHANCE = { [2] = 10, [3] = 35 } -- percent chance of an opener or closer, by strength

--- `output` in the letter case of `word`: SHOUTED, Capitalised, or as written.
local function Recase(word, output)
  if #word > 1 and word == word:upper() and word ~= word:lower() then return output:upper() end
  if #word > 1 and word:find("^%u") then
    -- The first letter, which may sit behind an apostrophe ('ave, 'em).
    return (output:gsub("^(%A*)(%l)", function(lead, letter) return lead .. letter:upper() end))
  end
  return output
end

local function Swap(voice, lower, strength, random)
  local swap = voice and voice.swaps[lower]
  if not swap or swap.tier > strength then return nil end
  return swap[#swap > 1 and random(#swap) or 1]
end

local function Sounds(voice, lower, strength)
  if not voice then return lower end
  for _, rule in ipairs(voice.sounds) do
    if rule.tier <= strength then lower = lower:gsub(rule.pattern, rule.repl) end
  end
  return lower
end

--- One word (ASCII letters and apostrophes) through the race voice, then the class voice.
local function Word(word, race, class, strength, random)
  local lead, core = word:match("^('*)(.*)$")
  if core == "" then return word end
  local lower = core:lower()
  local swapped = Swap(race, lower, strength, random) or Swap(class, lower, strength, random)
  if not swapped then
    -- A quoted word: 'hello' is looked up without its closing quote.
    local bare, tail = lower:match("^(.-)('+)$")
    if bare and bare ~= "" then
      local inner = Swap(race, bare, strength, random) or Swap(class, bare, strength, random)
      if inner then return lead .. Recase(core:sub(1, #bare), inner) .. tail end
    end
  end
  if swapped then return lead .. Recase(core, swapped) end
  if #lower < 4 or strength < 2 then return word end
  -- Sound rules are written for lower case, so only plainly cased words take them.
  if core ~= lower and core ~= core:upper() and not core:find("^%u%l+'?%l*$") then return word end
  local sounded = Sounds(class, Sounds(race, lower, strength), strength)
  if sounded == lower then return word end
  return lead .. Recase(core, sounded)
end

local function Interject(text, voice, strength, random)
  local chance = CHANCE[strength]
  if not chance or not voice then return text end
  local openers, closers = voice.openers, voice.closers
  if #openers == 0 and #closers == 0 then return text end
  if random(100) > chance then return text end
  local opener = random(2) == 1
  if opener and #openers == 0 then opener = false elseif not opener and #closers == 0 then opener = true end
  if opener then return openers[random(#openers)] .. " " .. text end
  return text .. " " .. closers[random(#closers)]
end

local function Attempt(text, race, class, opts, strength, random, mood)
  local shielded, parts = BT.Protect.Shield(text, opts.names)
  -- Words as typed: counted before any swap, and without the words inside a link or a name.
  -- "xD" is a face, not a word.
  local words = 0
  for run in shielded:gmatch("%a%a+") do
    if run:lower() ~= "xd" then words = words + 1 end
  end
  -- A run that touches a byte above 127 is someone's own language: left alone.
  shielded = shielded:gsub("[%a'\128-\255]+", function(run)
    if run:find("[\128-\255]") then return run end
    return Word(run, race, class, strength, random)
  end)
  if words >= 3 then
    shielded = Interject(shielded, race, strength, random)
    shielded = Interject(shielded, class, strength, random)
  end
  -- An emoticon, a number or a lone link has nothing to say in a mood.
  if BT.Moods and mood ~= "calm" and words >= 1 then
    local voices = {}
    if race then voices[#voices + 1] = race end
    if class then voices[#voices + 1] = class end
    shielded = BT.Moods.Apply(shielded, mood, random, voices)
  end
  return BT.Protect.Restore(shielded, parts)
end

--- opts: { race = id, class = id, mood = "calm"|..., strength = 1|2|3, names = list, random = function(n) }
function Engine.Speak(text, opts)
  if type(text) ~= "string" or text:find("^/") or not text:find("%S") then return text end
  local race, class = BT.voices[opts.race or false], BT.voices[opts.class or false]
  local mood = opts.mood or "calm"
  if not race and not class and mood == "calm" then return text end
  local random = opts.random or math.random
  local strength = opts.strength or 2
  for attempt = strength, 1, -1 do
    local result = Attempt(text, race, class, opts, attempt, random, mood)
    if #result <= MAX_BYTES then return result end
  end
  if mood ~= "calm" then
    local result = Attempt(text, race, class, opts, 1, random, "calm")
    if #result <= MAX_BYTES then return result end
  end
  return text
end
