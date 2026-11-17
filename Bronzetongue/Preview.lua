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

local function Update(box)
  local text = box:GetText()
  local chatType = box.GetAttribute and box:GetAttribute("chatType")
  local spoken = BT.PreviewText(text, chatType)
  if not spoken then return Hide() end
  local f = Frame()
  f:ClearAllPoints()
  f:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 0, 4)
  f:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, 4)
  f.text:SetText("|cffc9ad6a>|r " .. spoken)
  f:SetHeight((f.text:GetStringHeight() or 12) + 8)
  f:Show()
end

local hooked = {}
--- Shows the preview for `box`. HookScript only: the box's own scripts stay as they are.
function BT.HookPreview(box)
  if type(box) ~= "table" or hooked[box] or type(box.HookScript) ~= "function" then return end
  hooked[box] = true
  box:HookScript("OnTextChanged", function(self) if not pcall(Update, self) then Hide() end end)
  box:HookScript("OnHide", Hide)
  box:HookScript("OnEditFocusLost", Hide)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
  for index = 1, 10 do BT.HookPreview(_G["ChatFrame" .. index .. "EditBox"]) end
end)
