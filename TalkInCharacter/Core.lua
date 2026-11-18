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
  wheel = true, wheelChat = "SAY", matched = false,
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
SlashCmdList.TALKINCHARACTER = function(input)
  local verb = (input or ""):lower():match("^%s*(%S*)")
  if verb == "on" or verb == "off" then
    BT.db.enabled = verb == "on"
    BT.Print(verb == "on" and "on. Your chat is spoken in your voice." or "off. Your chat goes out as typed.")
  elseif BT.OpenOptions then
    BT.OpenOptions()
  else
    BT.Print("/tic on, /tic off")
  end
end
