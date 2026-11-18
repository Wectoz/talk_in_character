local ADDON, BT = ...

-- Saved settings (per character), defaults, slash commands.

BT.CHAT_TYPES = { "SAY", "YELL", "EMOTE", "PARTY", "RAID", "GUILD", "OFFICER", "WHISPER", "INSTANCE_CHAT", "CHANNEL" }

-- UnitRace file token -> voice id
BT.RACE_TOKENS = {
  Human = "human", Dwarf = "dwarf", NightElf = "nightelf", Gnome = "gnome",
  Orc = "orc", Troll = "troll", Tauren = "tauren", Scourge = "forsaken", Goblin = "goblin",
}

local DEFAULTS = {
  enabled = true, mood = "calm", age = "adult", strength = 2, preview = true, extras = false,
  wheel = true, wheelChat = "SAY", matched = false, plainGroups = false,
  keep = {}, -- keep[word] = true: the player's own words, never changed (/tic keep)
  chats = {
    SAY = true, YELL = true, EMOTE = true, PARTY = true, RAID = true, GUILD = true, WHISPER = true,
    OFFICER = false, INSTANCE_CHAT = false, CHANNEL = false,
  },
}

--- Fills the keys `db` lacks, so settings added in a later version appear in an old save.
function BT.ApplyDefaults(db)
  for key, value in pairs(DEFAULTS) do
    if type(value) == "table" then
      if type(db[key]) ~= "table" then db[key] = {} end
      for inner, innerValue in pairs(value) do
        if db[key][inner] == nil then db[key][inner] = innerValue end
      end
    elseif db[key] == nil then
      db[key] = value
    end
  end
  return db
end

function BT.Print(message)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffc9ad6aTalk in Character:|r " .. tostring(message)) end
end

--- Sets the voice from the character's own race and class. Unknown ones become "None".
function BT.MatchCharacter()
  local _, raceToken = UnitRace("player")
  local _, classToken = UnitClass("player")
  local race = BT.RACE_TOKENS[raceToken or ""]
  local class = type(classToken) == "string" and classToken:lower() or nil
  BT.db.race = BT.voices[race or false] and race or nil
  BT.db.class = (BT.voices[class or false] and BT.voices[class].kind == "class") and class or nil
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" then
    if name ~= ADDON then return end
    if type(TalkInCharacterCharDB) ~= "table" then TalkInCharacterCharDB = {} end
    BT.db = BT.ApplyDefaults(TalkInCharacterCharDB)
  elseif event == "PLAYER_LOGIN" then
    if BT.db and not BT.db.matched then
      BT.MatchCharacter()
      BT.db.matched = true
    end
    -- A moment later, so Autocorrect Forever has built its dictionary whichever addon logs in first.
    if C_Timer and C_Timer.After and BT.CheckAutocorrect then C_Timer.After(3, BT.CheckAutocorrect) end
  end
end)

SLASH_TALKINCHARACTER1, SLASH_TALKINCHARACTER2 = "/talkincharacter", "/tic"
local MOODS = { calm = true, angry = true, drunk = true, scared = true }
local AGES = { adult = true, young = true, elder = true }
local STRENGTHS = { light = 1, medium = 2, heavy = 3 }
local HELP = "/tic on, off | calm, angry, drunk, scared | adult, young, elder | light, medium, heavy | "
  .. "keep <word>, forget <word>, kept"

--- Passes a kept word on to Autocorrect Forever, so one command covers both addons.
local function TellAutocorrect(command)
  local other = SlashCmdList.AUTOCORRECTFOREVER
  if type(other) == "function" then pcall(other, command) end
end

--- Keeps (or stops keeping) one word as typed. Returns the word as stored, or nil if `word`
--- is not a single word.
function BT.Keep(word, on)
  word = type(word) == "string" and word:lower():match("^%s*([%w\128-\255]+)%s*$")
  if not word then return nil end
  BT.db.keep[word] = on and true or nil
  BT.keepStamp = (BT.keepStamp or 0) + 1
  TellAutocorrect((on and "keep " or "forget ") .. word)
  return word
end

--- The kept words, in order.
function BT.KeptWords()
  local words = {}
  for word in pairs(BT.db.keep) do words[#words + 1] = word end
  table.sort(words)
  return words
end

SlashCmdList.TALKINCHARACTER = function(input)
  local db = BT.db
  local verb, rest = (input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  if verb == "on" or verb == "off" then
    db.enabled = verb == "on"
    BT.Print(verb == "on" and "on. Your chat is spoken in your voice." or "off. Your chat goes out as typed.")
  elseif MOODS[verb] then
    db.mood = verb
    BT.Print("mood: " .. verb)
  elseif AGES[verb] then
    db.age = verb
    BT.Print("age: " .. verb)
  elseif STRENGTHS[verb] then
    db.strength = STRENGTHS[verb]
    BT.Print("strength: " .. verb)
  elseif verb == "keep" or verb == "forget" then
    local word = BT.Keep(rest, verb == "keep")
    if not word then
      BT.Print("One word at a time: /tic " .. verb .. " <word>")
    else
      BT.Print(verb == "keep" and (word .. " will be left as typed.") or (word .. " is no longer kept."))
    end
  elseif verb == "kept" then
    local words = BT.KeptWords()
    BT.Print(#words > 0 and ("kept words: " .. table.concat(words, ", ")) or "no kept words. /tic keep <word> adds one.")
  elseif verb == "" and BT.OpenOptions then
    return BT.OpenOptions()
  else
    BT.Print(HELP)
  end
  if BT.RefreshOptions then BT.RefreshOptions() end
end
