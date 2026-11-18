local ADDON, BT = ...

-- A line above the chat box showing what will be sent, as you type.

--- Picks the first alternative and never rolls an interjection or mood flourish, so the
--- preview holds still while typing. The message as sent may add one of those.
local function Steady(n) return n == 100 and 100 or 1 end

--- What `text` would be sent as, or nil when there is nothing worth showing.
function BT.PreviewText(text, chatType)
  if not BT.db or not BT.db.preview or not BT.Readable(text) or text:find("^/") then return nil end
  if not BT.WillRewrite(chatType) then return nil end
  local opts = BT.Options()
  opts.random = Steady
  local spoken = BT.Rewrite(text, chatType, opts)
  if spoken == text then return nil end
  return spoken
end

local frame
local function Frame()
  if frame then return frame end
  frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  frame:SetFrameStrata("DIALOG")
  frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  frame:SetBackdropColor(0.067, 0.067, 0.067, 0.9)       -- #111111
  frame:SetBackdropBorderColor(0.502, 0.388, 0.173, 1)   -- #80632c
  frame:EnableMouse(false)
  frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.text:SetPoint("TOPLEFT", 6, -4)
  frame.text:SetPoint("RIGHT", -6, 0)
  frame.text:SetJustifyH("LEFT")
  frame.text:SetWordWrap(true)
  frame.text:SetTextColor(0.933, 0.933, 0.8)             -- #eeeecc
  frame:Hide()
  return frame
end

local function Hide() if frame then frame:Hide() end end

local lastKey, lastSpoken
local function Update(box)
  local text = box:GetText()
  local chatType = box.GetAttribute and box:GetAttribute("chatType")
  if not BT.Readable(text) then Hide() return nil end
  -- Typing pauses far outnumber key presses: work only when the text or a setting changed.
  local db = BT.db
  local key = table.concat({ text, tostring(chatType), tostring(db.race), tostring(db.class), db.mood, db.age, db.strength, tostring(db.extras),
    tostring(db.enabled), tostring(db.preview), tostring(db.chats[chatType or ""]), tostring(BT.InLockdown()) }, "\0")
  if key == lastKey and (lastSpoken == nil or (frame and frame:IsShown())) then return lastSpoken end
  local spoken = BT.PreviewText(text, chatType)
  lastKey, lastSpoken = key, spoken
  if not spoken then Hide() return nil end
  local f = Frame()
  f:ClearAllPoints()
  f:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 0, 4)
  f:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, 4)
  f.text:SetText("|cffc9ad6a>|r " .. spoken)
  f:SetHeight((f.text:GetStringHeight() or 12) + 8)
  f:Show()
  return spoken
end

--- The chat box being typed in, or nil.
local function ActiveBox()
  local get = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow) or ChatEdit_GetActiveWindow
  if type(get) ~= "function" then return nil end
  local ok, box = pcall(get)
  if ok and type(box) == "table" and type(box.GetText) == "function" and box:IsShown() then return box end
end

--- Shows the preview for the active chat box. Returns what it shows, or nil.
function BT.PreviewTick()
  local box = ActiveBox()
  if not box then Hide() return nil end
  local ok, spoken = pcall(Update, box)
  if not ok then Hide() return nil end
  return spoken
end

-- The preview watches from its own frame. Nothing is hooked onto the game's chat boxes: a
-- script hook there taints the box's own handlers, and a tainted send is refused (and the
-- message lost) during chat lockdown.
local watcher = CreateFrame("Frame")
local elapsedSince = 0
watcher:SetScript("OnUpdate", function(_, elapsed)
  elapsedSince = elapsedSince + (elapsed or 0)
  if elapsedSince < 0.1 then return end
  elapsedSince = 0
  BT.PreviewTick()
end)
