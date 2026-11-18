local ADDON, BT = ...

-- Rewrites the message in the chat box just before the game reads it to send.
-- The game's send functions are never replaced or wrapped: a send that passes through addon
-- code is refused during chat lockdown (boss encounters) and the message is lost.

local ENABLED_TYPE = {}
for _, chatType in ipairs(BT.CHAT_TYPES) do ENABLED_TYPE[chatType] = true end

--- Whether the game has chat under its encounter restrictions. We then change nothing.
function BT.InLockdown()
  if GetCVarBool then
    local ok, forced = pcall(GetCVarBool, "addonChatRestrictionsForced")
    if ok and forced then return true end
  end
  local check = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
  if type(check) ~= "function" then return false end
  local ok, locked = pcall(check)
  return ok and locked and true or false
end

--- Whether `value` is a string we may read. In combat and instances the game can hand addons
--- "secret" strings: type() says string, but any use of one is an error.
local function Readable(value)
  if type(value) ~= "string" then return false end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret then return false end
  end
  return value ~= ""
end
BT.Readable = Readable

local function AddName(names, unit)
  local ok, name = pcall(UnitName, unit)
  if ok and Readable(name) then names[#names + 1] = name end
end

--- Names that must reach others unchanged: you, your target, your group.
function BT.ReadableNames()
  local names = {}
  AddName(names, "player")
  AddName(names, "target")
  if IsInRaid and IsInRaid() then
    for index = 1, 40 do AddName(names, "raid" .. index) end
  elseif IsInGroup and IsInGroup() then
    for index = 1, 4 do AddName(names, "party" .. index) end
  end
  return names
end

--- The engine options for the current settings.
function BT.Options()
  local db = BT.db
  return { race = db.race, class = db.class, mood = db.mood, strength = db.strength, names = BT.ReadableNames() }
end

--- Whether a message of this chat type would be spoken in the voice right now.
function BT.WillRewrite(chatType)
  local db = BT.db
  if not db or not db.enabled or not ENABLED_TYPE[chatType] or not db.chats[chatType] then return false end
  if not BT.voices[db.race or false] and not BT.voices[db.class or false] then return false end
  return not BT.InLockdown()
end

local reported = false
--- `text` in the current voice. Whatever goes wrong, the text comes back as typed.
function BT.Rewrite(text, chatType, opts)
  local ok, result = pcall(function()
    opts = opts or BT.Options()
    if chatType ~= "EMOTE" then return BT.Engine.Speak(text, opts) end
    -- An emote is narration: only what is said inside "quotes" is in your voice.
    -- Links are shielded first: an item name can hold a quote of its own.
    local shielded, parts = BT.Protect.Shield(text)
    shielded = shielded:gsub('"(.-)"', function(said)
      return '"' .. BT.Engine.Speak(BT.Protect.Restore(said, parts), opts) .. '"'
    end)
    local spoken = BT.Protect.Restore(shielded, parts)
    return #spoken <= 255 and spoken or text
  end)
  if ok and type(result) == "string" then return result end
  if not reported then
    reported = true
    BT.Print("something went wrong, so your message was left as typed (" .. tostring(result) .. "). /tic off stops me.")
  end
  return text
end

-- Autocorrect Forever builds its dictionary from this list at login, after every addon file has
-- loaded. A word in it is left as typed, so "strat" is no longer made into "start".
if type(AutocorrectForever_Known) == "string" then
  local words = {}
  for term in pairs(BT.Terms.strict) do
    words[#words + 1] = term
    if term:sub(-1) ~= "s" then words[#words + 1] = term .. "s" end
  end
  AutocorrectForever_Known = AutocorrectForever_Known .. " " .. table.concat(words, " ")
end

local busy = false
local function OnPreSendText(_, box)
  if busy or type(box) ~= "table" or type(box.GetText) ~= "function" then return end
  -- Ctrl+Enter: this one goes out as typed. (Not Alt+Enter, which the client may use to toggle fullscreen.)
  if IsControlKeyDown and IsControlKeyDown() then return end
  local chatType = box.GetAttribute and box:GetAttribute("chatType")
  if not BT.WillRewrite(chatType) then return end
  local text = box:GetText()
  if not Readable(text) then return end
  local spoken = BT.Rewrite(text, chatType)
  if spoken ~= text then
    busy = true
    box:SetText(spoken)
    busy = false
    -- Autocorrect Forever acts in this same event, in no set order. Its send-time step only
    -- runs on text equal to its lastText, so this keeps it from "correcting" accent words.
    if type(_G.AutocorrectForever) == "table" then _G.AutocorrectForever.lastText = false end
  end
end

if EventRegistry and type(EventRegistry.RegisterCallback) == "function" then
  EventRegistry:RegisterCallback("ChatFrame.OnEditBoxPreSendText", function(...)
    local ok = pcall(OnPreSendText, ...)
    if not ok then busy = false end
  end, BT)
end
