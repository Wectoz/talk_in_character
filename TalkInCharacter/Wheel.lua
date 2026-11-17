local ADDON, BT = ...

-- The phrase wheel: hold the bound key, flick toward a slot, release to say a line.

BINDING_HEADER_TALKINCHARACTER = "Talk in Character"
BINDING_NAME_TALKINCHARACTER_WHEEL = "Hold for phrase wheel"

local LABELS = { hello = "Hello", follow = "Follow", wait = "Wait", cheer = "Cheer", battle = "Battle", bye = "Bye", help = "Help", thanks = "Thanks" }
local WHEEL_CHATS = { SAY = true, YELL = true, EMOTE = true, PARTY = true, RAID = true, GUILD = true }
local OUTER, INNER, LABEL_RADIUS = 84, 40, 62 -- INNER matches the dead zone in Phrases.SlotAt
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local frame, centreX, centreY
local lines = {} -- slot -> the line it will say (picked when the wheel opens)

--- Who the phrases are aimed at: name, race and class of the target, where readable.
function BT.WheelTarget()
  if not UnitExists or not UnitExists("target") then return nil end
  local ok, name = pcall(UnitName, "target")
  if not ok or not BT.Readable(name) then return nil end
  local target = { name = name }
  if UnitIsPlayer and UnitIsPlayer("target") then
    local okRace, race = pcall(UnitRace, "target")
    local okClass, class = pcall(UnitClass, "target")
    if okRace and BT.Readable(race) then target.race = race end
    if okClass and BT.Readable(class) then target.class = class end
  end
  return target
end

--- Says a wheel line in the chosen chat. It never opens the chat box: doing that from addon
--- code taints the box, and a tainted box loses messages during chat lockdown.
function BT.WheelSay(line)
  local chat = BT.db.wheelChat
  if not WHEEL_CHATS[chat] then chat = "SAY" end
  if chat == "RAID" and not (IsInRaid and IsInRaid()) then chat = "SAY" end
  if chat == "PARTY" and not (IsInGroup and IsInGroup()) then chat = "SAY" end
  local say = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if say then pcall(say, line, chat) end
end

local function Cursor()
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  return x / scale, y / scale
end

local function Circle(parent, layer, sublevel, size, r, g, b, a)
  local texture = parent:CreateTexture(nil, layer, nil, sublevel)
  texture:SetTexture(CIRCLE)
  texture:SetSize(size, size)
  texture:SetPoint("CENTER")
  texture:SetVertexColor(r, g, b, a)
  return texture
end

local function Build()
  frame = CreateFrame("Frame", nil, UIParent)
  frame:SetFrameStrata("TOOLTIP")
  frame:SetSize(OUTER * 2, OUTER * 2)
  frame:EnableMouse(false)
  Circle(frame, "BACKGROUND", 0, OUTER * 2 + 3, 0.502, 0.388, 0.173, 1)     -- bronze rim
  Circle(frame, "BACKGROUND", 1, OUTER * 2, 0.051, 0.043, 0.031, 0.92)      -- dark disc
  Circle(frame, "BACKGROUND", 2, INNER * 2, 0.502, 0.388, 0.173, 0.9)       -- inner ring
  Circle(frame, "BACKGROUND", 3, INNER * 2 - 3, 0.051, 0.043, 0.031, 1)
  frame.glow = Circle(frame, "BORDER", 0, 52, 0.725, 0.541, 0.243, 1)       -- behind the picked label
  frame.mark = frame:CreateTexture(nil, "ARTWORK")
  frame.mark:SetTexture("Interface\\AddOns\\TalkInCharacter\\Media\\infinity")
  frame.mark:SetSize(32, 16)
  frame.mark:SetPoint("CENTER")
  frame.labels = {}
  for slot, kind in ipairs(BT.KINDS) do
    local angle = math.rad((slot - 1) * 45)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", frame, "CENTER", LABEL_RADIUS * math.sin(angle), LABEL_RADIUS * math.cos(angle))
    label:SetText(LABELS[kind])
    label.x, label.y = LABEL_RADIUS * math.sin(angle), LABEL_RADIUS * math.cos(angle)
    frame.labels[slot] = label
  end

  local side = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  side:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  side:SetBackdropColor(0.067, 0.067, 0.067, 0.95)
  side:SetBackdropBorderColor(0.502, 0.388, 0.173, 1)
  side:SetWidth(240)
  side.kind = side:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  side.kind:SetPoint("TOPLEFT", 8, -6)
  side.kind:SetTextColor(0.788, 0.678, 0.416)
  side.line = side:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  side.line:SetPoint("TOPLEFT", side.kind, "BOTTOMLEFT", 0, -3)
  side.line:SetWidth(224)
  side.line:SetJustifyH("LEFT")
  side.line:SetWordWrap(true)
  side.line:SetTextColor(0.933, 0.933, 0.8)
  frame.side = side

  frame:SetScript("OnUpdate", function() BT.WheelRefresh() end)
  frame:Hide()
end

local function Slot()
  local x, y = Cursor()
  return BT.Phrases.SlotAt(x - centreX, y - centreY)
end

--- Highlights the slot under the cursor direction and shows its line.
function BT.WheelRefresh()
  local slot = Slot()
  for index, label in ipairs(frame.labels) do
    if index == slot then label:SetTextColor(0.098, 0.082, 0.063) else label:SetTextColor(0.933, 0.933, 0.8) end
  end
  local line = slot and lines[slot]
  if not line then
    frame.glow:Hide()
    frame.side:Hide()
    return
  end
  frame.glow:ClearAllPoints()
  frame.glow:SetPoint("CENTER", frame, "CENTER", frame.labels[slot].x, frame.labels[slot].y)
  frame.glow:Show()
  local side = frame.side
  side.kind:SetText(LABELS[BT.KINDS[slot]])
  side.line:SetText(line)
  side:SetHeight((side.line:GetStringHeight() or 12) + 28)
  side:ClearAllPoints()
  if centreX > GetScreenWidth() * 0.6 then
    side:SetPoint("RIGHT", frame, "LEFT", -10, 0)
  else
    side:SetPoint("LEFT", frame, "RIGHT", 10, 0)
  end
  side:Show()
end

local function Open()
  local db = BT.db
  if not db or not db.wheel or BT.InLockdown() then return end
  if not BT.voices[db.race or false] and not BT.voices[db.class or false] then
    BT.Print("Pick a voice in /tic first.")
    return
  end
  if not frame then Build() end
  local opts, target = BT.Options(), BT.WheelTarget()
  for slot, kind in ipairs(BT.KINDS) do lines[slot] = BT.Phrases.Pick(kind, opts, target) end
  centreX, centreY = Cursor()
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centreX, centreY)
  frame:Show()
  BT.wheelOpen = true
end

local function Close()
  if not BT.wheelOpen then return end
  BT.wheelOpen = false
  frame:Hide()
  local slot = Slot()
  local line = slot and lines[slot]
  if line and not BT.InLockdown() then BT.WheelSay(line) end
end

function TalkInCharacterWheel_OnKey(keystate)
  local ok, problem = pcall(keystate == "down" and Open or Close)
  if not ok then
    BT.wheelOpen = false
    if frame then frame:Hide() end
  end
end
