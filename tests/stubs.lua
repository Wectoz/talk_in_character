-- Minimal fakes of the game API for testing game-facing files outside the game.
-- Tests flip fields on Stub to change what the fakes report.
Stub = { lockdown = false, alt = false, race = "Gnome", class = "MAGE", inGroup = false, inRaid = false, combat = false }

local registry = {}
EventRegistry = {
  RegisterCallback = function(self, event, fn, owner)
    registry[event] = registry[event] or {}
    table.insert(registry[event], { fn = fn, owner = owner })
  end,
  Fire = function(event, ...)
    for _, cb in ipairs(registry[event] or {}) do cb.fn(cb.owner, ...) end
  end,
}

C_ChatInfo = {
  InChatMessagingLockdown = function() return Stub.lockdown end,
  SendChatMessage = function(...) Stub.sent = { ... } end,
}
function IsAltKeyDown() return Stub.alt end
function InCombatLockdown() return Stub.combat end
function IsInGroup() return Stub.inGroup end
function IsInRaid() return Stub.inRaid end
function UnitRace(unit) return Stub.race, Stub.race end
function UnitClass(unit) return Stub.class, Stub.class end
function UnitExists(unit) return unit == "target" and Stub.targetName ~= nil end
function UnitName(unit)
  if unit == "target" then return Stub.targetName end
  if unit == "player" then return "Tester" end
end
function issecretvalue(value) return Stub.targetSecret and value == Stub.targetName end
function GetCursorPosition() return Stub.cursorX or 500, Stub.cursorY or 500 end
function GetScreenWidth() return 1920 end
function GetTime() return 0 end

-- A frame that accepts any method call and remembers its scripts.
local function Frame()
  local frame = { scripts = {}, shown = false }
  function frame:SetScript(name, fn) self.scripts[name] = fn end
  function frame:HookScript(name, fn) self.scripts[name] = fn end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  function frame:IsShown() return self.shown end
  function frame:GetEffectiveScale() return 1 end
  function frame:GetWidth() return 400 end
  function frame:GetStringHeight() return 12 end
  function frame:GetStringWidth() return 60 end
  function frame:GetHeight() return 20 end
  function frame:GetID() return 7 end
  return setmetatable(frame, { __index = function(t, key)
    return function(...) return Frame() end
  end })
end
Stub.frames = {}
function CreateFrame(kind, name)
  local frame = Frame()
  Stub.frames[#Stub.frames + 1] = frame
  if name then _G[name] = frame end
  return frame
end
UIParent = Frame()
DEFAULT_CHAT_FRAME = { AddMessage = function(self, text) Stub.printed = text Stub.prints = (Stub.prints or 0) + 1 end }
SlashCmdList = {}
function CreateColor() return {} end
Settings = {
  RegisterCanvasLayoutCategory = function(panel, name) Stub.categoryName = name return CreateFrame("Frame") end,
  RegisterAddOnCategory = function(category) Stub.registered = category end,
  OpenToCategory = function(id) Stub.openedCategory = id end,
}
function GetBindingKey() return Stub.boundKey end
function SetBinding(key, command) Stub.bindings = Stub.bindings or {} Stub.bindings[key] = command or false return true end
function SaveBindings() Stub.bindingsSaved = true end
function GetCurrentBindingSet() return 1 end
function IsControlKeyDown() return false end
function IsShiftKeyDown() return false end
ChatFrameUtil = { OpenChat = function(text) Stub.opened = text end }

--- A chat edit box holding `text`, set to `chatType`.
function FakeBox(text, chatType)
  local box = { text = text, sets = 0, scripts = {} }
  function box:GetText() return self.text end
  function box:SetText(new) self.text = new self.sets = self.sets + 1 end
  function box:GetAttribute(key) if key == "chatType" then return chatType end end
  function box:HookScript(name, fn) self.scripts[name] = fn end
  function box:IsShown() return true end
  return box
end

--- Fires an event at every frame that has an OnEvent script (as the game would).
function Stub.Event(event, ...)
  for _, frame in ipairs(Stub.frames) do
    local handler = frame.scripts.OnEvent
    if handler then handler(frame, event, ...) end
  end
end
