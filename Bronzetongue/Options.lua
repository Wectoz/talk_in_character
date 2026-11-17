local ADDON, BT = ...

-- The settings panel (Game Menu > Options > AddOns > Bronzetongue), drawn in Forever's bronze.

local COLOR = {
  bg = { 0.067, 0.067, 0.067 },        -- #111111
  reading = { 0.098, 0.098, 0.098 },   -- #191919
  surface = { 0.141, 0.141, 0.141 },   -- #242424
  border = { 0.376, 0.376, 0.376 },    -- #606060
  bronze = { 0.502, 0.388, 0.173 },    -- #80632c
  gold = { 0.788, 0.678, 0.416 },      -- #c9ad6a
  text = { 0.933, 0.933, 0.8 },        -- #eeeecc
  muted = { 0.667, 0.667, 0.667 },     -- #aaaaaa
}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local WHEEL_COMMAND = "BRONZETONGUE_WHEEL"
local SAMPLE = "hello, can you help me kill this boss?"

local CHAT_LABELS = {
  SAY = "Say", YELL = "Yell", EMOTE = "Emote", PARTY = "Party", RAID = "Raid", GUILD = "Guild",
  OFFICER = "Officer", WHISPER = "Whisper", INSTANCE_CHAT = "Instance", CHANNEL = "Channels",
}
local MOODS = { { "calm", "Calm" }, { "angry", "Angry" }, { "drunk", "Drunk" }, { "scared", "Scared" } }
local WHEEL_CHATS = { { "SAY", "Say" }, { "YELL", "Yell" }, { "EMOTE", "Emote" }, { "PARTY", "Party" }, { "RAID", "Raid" }, { "GUILD", "Guild" } }
local STRENGTHS = { "Light", "Medium", "Heavy" }
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true }

-- ---------------------------------------------------------------------------------------------
-- Logic the panel calls (kept apart from the drawing so it can be tested outside the game)

--- The key name with its held modifiers, or nil for a bare modifier key.
function BT.KeyChord(key)
  if MODIFIERS[key] then return nil end
  local chord = ""
  if IsAltKeyDown() then chord = chord .. "ALT-" end
  if IsControlKeyDown() then chord = chord .. "CTRL-" end
  if IsShiftKeyDown() then chord = chord .. "SHIFT-" end
  return chord .. key
end

--- Binds the wheel to `key` (nil clears it). Key bindings cannot change in combat.
function BT.BindWheelKey(key)
  if InCombatLockdown() then
    BT.Print("Key bindings can't change in combat.")
    return false
  end
  if key and GetBindingAction then
    local action = GetBindingAction(key)
    if type(action) == "string" and action ~= "" and action ~= WHEEL_COMMAND then
      local name = (GetBindingName and GetBindingName(action)) or _G["BINDING_NAME_" .. action] or action
      BT.Print(key .. " is already used for \"" .. tostring(name) .. "\". Pick another key, or unbind it in Key Bindings first.")
      return false
    end
  end
  local old = { GetBindingKey(WHEEL_COMMAND) }
  -- The new key first: if the game refuses it, the old key stays.
  if key and not SetBinding(key, WHEEL_COMMAND) then
    BT.Print("The game would not bind " .. key .. ". Try another key.")
    return false
  end
  for _, oldKey in ipairs(old) do
    if oldKey ~= key then SetBinding(oldKey, nil) end
  end
  SaveBindings(GetCurrentBindingSet())
  return true
end

--- Autocorrect Forever's switches, or nil when that addon is not loaded.
function BT.AutocorrectState()
  if type(_G.AutocorrectForever) ~= "table" then return nil end
  local db = type(_G.AutocorrectForeverDB) == "table" and _G.AutocorrectForeverDB or {}
  return { enabled = db.enabled == true, accent = db.accent ~= nil and db.accent ~= false }
end

--- Flips Autocorrect Forever through its own slash command, the one public switch it has.
function BT.SetAutocorrect(on)
  local command = SlashCmdList and SlashCmdList.AUTOCORRECTFOREVER
  if type(command) == "function" then pcall(command, on and "on" or "off") end
end

-- ---------------------------------------------------------------------------------------------
-- Drawing helpers

local function Surface(frame, bg, border, alpha)
  frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  frame:SetBackdropColor(bg[1], bg[2], bg[3], alpha or 1)
  frame:SetBackdropBorderColor(border[1], border[2], border[3], 1)
end

local function Label(parent, text, color, font)
  local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  label:SetTextColor(color[1], color[2], color[3])
  label:SetText(text)
  return label
end

--- A section title in gold capitals with a bronze rule fading to the right.
local function Header(parent, text, y)
  local label = Label(parent, text:upper(), COLOR.gold, "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", 18, y)
  local rule = parent:CreateTexture(nil, "ARTWORK")
  rule:SetTexture(WHITE)
  rule:SetHeight(1)
  rule:SetPoint("LEFT", label, "RIGHT", 10, 0)
  rule:SetPoint("RIGHT", parent, "RIGHT", -18, 0)
  rule:SetGradient("HORIZONTAL", CreateColor(COLOR.bronze[1], COLOR.bronze[2], COLOR.bronze[3], 1),
    CreateColor(COLOR.bronze[1], COLOR.bronze[2], COLOR.bronze[3], 0))
  return label
end

local refreshers = {} -- every control's refresh, run when the panel shows

local function Check(parent, text, x, y, get, set)
  local check = CreateFrame("Button", nil, parent, "BackdropTemplate")
  check:SetSize(16, 16)
  check:SetPoint("TOPLEFT", x, y)
  Surface(check, COLOR.reading, COLOR.bronze)
  check.tick = check:CreateTexture(nil, "OVERLAY")
  check.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check.tick:SetPoint("TOPLEFT", -3, 3)
  check.tick:SetPoint("BOTTOMRIGHT", 3, -3)
  check.tick:SetVertexColor(COLOR.gold[1], COLOR.gold[2], COLOR.gold[3])
  check.label = Label(check, text, COLOR.text)
  check.label:SetPoint("LEFT", check, "RIGHT", 6, 0)
  check:SetHitRectInsets(0, -(check.label:GetStringWidth() + 8), 0, 0)
  function check:Refresh() self.tick:SetShown(get() and true or false) end
  check:SetScript("OnClick", function(self)
    if self.locked then return end
    set(not get())
    BT.RefreshOptions()
  end)
  --- Greys the box out and stops clicks.
  function check:SetLocked(locked)
    self.locked = locked
    self:SetAlpha(locked and 0.45 or 1)
  end
  refreshers[#refreshers + 1] = check
  return check
end

local function TextButton(parent, text, width, onClick)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(width, 22)
  Surface(button, COLOR.surface, COLOR.bronze)
  button.label = Label(button, text, COLOR.gold)
  button.label:SetPoint("CENTER")
  button:SetScript("OnClick", onClick)
  button:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(COLOR.gold[1], COLOR.gold[2], COLOR.gold[3], 1) end)
  button:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(COLOR.bronze[1], COLOR.bronze[2], COLOR.bronze[3], 1) end)
  return button
end

-- One shared list for every dropdown, with a full-screen catcher behind it so a click
-- anywhere else closes it.
local popup, catcher
local ROW_HEIGHT, ROWS_PER_COLUMN, COLUMN_WIDTH = 20, 14, 190

local function ClosePopup()
  if popup then popup:Hide() end
  if catcher then catcher:Hide() end
end

local function OpenPopup(anchor, items, current, onPick)
  if not popup then
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetScript("OnClick", ClosePopup)
    popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(catcher:GetFrameLevel() + 10)
    popup:SetClampedToScreen(true)
    Surface(popup, COLOR.bg, COLOR.bronze)
    popup.rows = {}
  end
  for _, row in ipairs(popup.rows) do row:Hide() end
  for index, item in ipairs(items) do
    local row = popup.rows[index]
    if not row then
      row = CreateFrame("Button", nil, popup)
      row:SetSize(COLUMN_WIDTH, ROW_HEIGHT)
      row.highlight = row:CreateTexture(nil, "BACKGROUND")
      row.highlight:SetAllPoints()
      row.highlight:SetTexture(WHITE)
      row.highlight:SetVertexColor(COLOR.bronze[1], COLOR.bronze[2], COLOR.bronze[3], 0.45)
      row.highlight:Hide()
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(16, 16)
      row.icon:SetPoint("LEFT", 6, 0)
      row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      row.label = Label(row, "", COLOR.text)
      row.label:SetPoint("LEFT", 28, 0)
      row:SetScript("OnEnter", function(self) self.highlight:Show() end)
      row:SetScript("OnLeave", function(self) self.highlight:Hide() end)
      popup.rows[index] = row
    end
    local column = math.floor((index - 1) / ROWS_PER_COLUMN)
    local line = (index - 1) % ROWS_PER_COLUMN
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 4 + column * COLUMN_WIDTH, -4 - line * ROW_HEIGHT)
    row.icon:SetTexture(item.icon)
    row.icon:SetShown(item.icon ~= nil)
    row.label:SetText(item.text)
    local color = item.value == current and COLOR.gold or COLOR.text
    row.label:SetTextColor(color[1], color[2], color[3])
    row:SetScript("OnClick", function()
      ClosePopup()
      onPick(item.value)
    end)
    row:Show()
  end
  local columns = math.ceil(#items / ROWS_PER_COLUMN)
  popup:SetSize(8 + columns * COLUMN_WIDTH, 8 + math.min(#items, ROWS_PER_COLUMN) * ROW_HEIGHT)
  popup:ClearAllPoints()
  popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  catcher:Show()
  popup:Show()
end

--- items(): list of { value =, text =, icon = }. A nil value is allowed (the "None" row).
local function Dropdown(parent, width, x, y, items, get, set)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(width, 24)
  button:SetPoint("TOPLEFT", x, y)
  Surface(button, COLOR.surface, COLOR.border)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetSize(18, 18)
  button.icon:SetPoint("LEFT", 4, 0)
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.label = Label(button, "", COLOR.text)
  button.label:SetPoint("LEFT", 28, 0)
  button.label:SetPoint("RIGHT", -18, 0)
  button.label:SetJustifyH("LEFT")
  button.label:SetWordWrap(false)
  local arrow = Label(button, "v", COLOR.gold)
  arrow:SetPoint("RIGHT", -6, 0)
  function button:Refresh()
    local current = get()
    local shown
    for _, item in ipairs(items()) do
      if item.value == current then shown = item end
    end
    shown = shown or items()[1] -- a saved voice that no longer exists shows as the first row, "None"
    self.icon:SetTexture(shown.icon)
    self.icon:SetShown(shown.icon ~= nil)
    self.label:SetText(shown.text)
  end
  button:SetScript("OnClick", function(self)
    if popup and popup:IsShown() then return ClosePopup() end
    OpenPopup(self, items(), get(), function(value)
      set(value)
      BT.RefreshOptions()
    end)
  end)
  button:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(COLOR.gold[1], COLOR.gold[2], COLOR.gold[3], 1) end)
  button:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(COLOR.border[1], COLOR.border[2], COLOR.border[3], 1) end)
  refreshers[#refreshers + 1] = button
  return button
end

local function VoiceItems(...)
  local kinds = { ... }
  return function()
    local list = { { value = nil, text = "None" } }
    for _, kind in ipairs(kinds) do
      for _, voice in ipairs(BT.VoicesOfKind(kind)) do
        list[#list + 1] = { value = voice.id, text = voice.name, icon = voice.icon }
      end
    end
    return list
  end
end

local function PlainItems(pairsList)
  local list = {}
  for _, pair in ipairs(pairsList) do list[#list + 1] = { value = pair[1], text = pair[2] } end
  return function() return list end
end

-- ---------------------------------------------------------------------------------------------
-- The panel

local panel, category

function BT.RefreshOptions()
  if not panel then return end
  for _, control in ipairs(refreshers) do control:Refresh() end
end

local function BuildVoice(y)
  local db = BT.db
  Header(panel, "Voice", y)
  Check(panel, "Enabled", 20, y - 24, function() return db.enabled end, function(v) db.enabled = v end)
  Label(panel, "Race / faction", COLOR.muted):SetPoint("TOPLEFT", 120, y - 20)
  Dropdown(panel, 190, 120, y - 34, VoiceItems("race", "faction"), function() return db.race end, function(v) db.race = v end)
  Label(panel, "Class", COLOR.muted):SetPoint("TOPLEFT", 320, y - 20)
  Dropdown(panel, 130, 320, y - 34, VoiceItems("class"), function() return db.class end, function(v) db.class = v end)
  Label(panel, "Mood", COLOR.muted):SetPoint("TOPLEFT", 460, y - 20)
  Dropdown(panel, 100, 460, y - 34, PlainItems(MOODS), function() return db.mood end, function(v) db.mood = v end)
  panel.match = TextButton(panel, "Match my character", 140, function()
    BT.MatchCharacter()
    BT.RefreshOptions()
  end)
  panel.match:SetPoint("TOPLEFT", 20, y - 70)

  Label(panel, "Strength", COLOR.muted):SetPoint("TOPLEFT", 190, y - 75)
  local slider = CreateFrame("Slider", nil, panel, "BackdropTemplate")
  slider:SetOrientation("HORIZONTAL")
  slider:SetSize(150, 6)
  slider:SetPoint("TOPLEFT", 250, y - 79)
  Surface(slider, COLOR.surface, COLOR.border)
  slider:SetMinMaxValues(1, 3)
  slider:SetValueStep(1)
  slider:SetObeyStepOnDrag(true)
  slider:SetHitRectInsets(0, 0, -8, -8) -- the bar is thin; this makes it easy to grab
  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(WHITE)
  thumb:SetSize(9, 16)
  thumb:SetVertexColor(COLOR.gold[1], COLOR.gold[2], COLOR.gold[3])
  slider:SetThumbTexture(thumb)
  slider.value = Label(panel, "", COLOR.gold)
  slider.value:SetPoint("LEFT", slider, "RIGHT", 10, 0)
  function slider:Refresh()
    self.refreshing = true
    self:SetValue(db.strength)
    self.refreshing = false
    self.value:SetText(STRENGTHS[db.strength] or "")
  end
  slider:SetScript("OnValueChanged", function(self, value)
    if self.refreshing then return end
    local step = math.floor(value + 0.5)
    if step ~= db.strength then
      db.strength = step
      BT.RefreshOptions()
    end
  end)
  refreshers[#refreshers + 1] = slider

  local sample = CreateFrame("Frame", nil, panel, "BackdropTemplate")
  sample:SetPoint("TOPLEFT", 20, y - 100)
  sample:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
  sample:SetHeight(46)
  Surface(sample, COLOR.reading, COLOR.bronze)
  sample.typed = Label(sample, "|cffaaaaaaYou type:|r " .. SAMPLE, COLOR.text)
  sample.typed:SetPoint("TOPLEFT", 8, -7)
  sample.seen = Label(sample, "", COLOR.text)
  sample.seen:SetPoint("TOPLEFT", sample.typed, "BOTTOMLEFT", 0, -5)
  sample.seen:SetPoint("RIGHT", -70, 0)
  sample.seen:SetJustifyH("LEFT")
  sample.seen:SetWordWrap(false)
  function sample:Refresh()
    local opts = BT.Options()
    opts.names = nil
    self.seen:SetText("|cffaaaaaaOthers see:|r " .. BT.Rewrite(SAMPLE, "SAY", opts))
  end
  local again = TextButton(sample, "Again", 54, function() sample:Refresh() end)
  again:SetPoint("RIGHT", -6, 0)
  refreshers[#refreshers + 1] = sample
  return y - 160
end

local function BuildAuto(y)
  local db = BT.db
  Header(panel, "Auto mode: rewrite what I type in", y)
  for index, chatType in ipairs(BT.CHAT_TYPES) do
    local column, row = (index - 1) % 5, math.floor((index - 1) / 5)
    Check(panel, CHAT_LABELS[chatType], 20 + column * 112, y - 24 - row * 24,
      function() return db.chats[chatType] end, function(v) db.chats[chatType] = v end)
  end
  local note = Label(panel, "Battle.net whispers are never changed. Hold Ctrl while pressing Enter to send one message as typed.", COLOR.muted)
  note:SetPoint("TOPLEFT", 20, y - 76)
  note:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
  note:SetJustifyH("LEFT")
  Check(panel, "Show a preview above the chat box", 20, y - 96, function() return db.preview end, function(v) db.preview = v end)
  return y - 130
end

local function BuildWheel(y)
  local db = BT.db
  Header(panel, "Phrase wheel", y)
  Check(panel, "Enabled", 20, y - 24, function() return db.wheel end, function(v) db.wheel = v end)

  Label(panel, "Hold key", COLOR.muted):SetPoint("TOPLEFT", 120, y - 26)
  local key = TextButton(panel, "", 150, nil)
  key:SetPoint("TOPLEFT", 180, y - 21)
  key:RegisterForClicks("AnyUp")
  local function Stop()
    key.capturing = false
    key:EnableKeyboard(false)
    key:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    key:Refresh()
  end
  -- A click anywhere else gives the keyboard back.
  key:SetScript("OnEvent", function(self)
    if self.capturing and not self:IsMouseOver() then Stop() end
  end)
  function key:Refresh()
    if self.capturing then
      self.label:SetText("Press a key (Esc cancels)")
    else
      self.label:SetText(GetBindingKey(WHEEL_COMMAND) or "Not bound: click to set")
    end
  end
  key:SetScript("OnClick", function(self, mouseButton)
    if self.capturing then
      -- A mouse button can be the wheel key too, except the two used to work this button.
      local name = ({ MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" })[mouseButton]
      if name then BT.BindWheelKey(BT.KeyChord(name)) end
      return Stop()
    end
    if mouseButton == "RightButton" then
      BT.BindWheelKey(nil)
      return self:Refresh()
    end
    if InCombatLockdown() then return BT.Print("Key bindings can't change in combat.") end
    self.capturing = true
    self:EnableKeyboard(true)
    self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    self:Refresh()
  end)
  key:SetScript("OnKeyDown", function(self, pressed)
    if not self.capturing then return end
    if pressed ~= "ESCAPE" then
      local chord = BT.KeyChord(pressed)
      if not chord then return end -- a bare modifier: keep waiting for the real key
      BT.BindWheelKey(chord)
    end
    Stop()
  end)
  key:SetScript("OnHide", Stop)
  refreshers[#refreshers + 1] = key
  Label(panel, "Right-click clears", COLOR.muted):SetPoint("LEFT", key, "RIGHT", 8, 0)

  Label(panel, "Speak in", COLOR.muted):SetPoint("TOPLEFT", 450, y - 26)
  Dropdown(panel, 90, 505, y - 20, PlainItems(WHEEL_CHATS), function() return db.wheelChat end, function(v) db.wheelChat = v end)
  return y - 60
end

local function BuildAutocorrect(y)
  Header(panel, "Autocorrect", y)
  local check = Check(panel, "Fix my spelling first", 20, y - 24,
    function() local state = BT.AutocorrectState() return state and state.enabled end,
    function(v) BT.SetAutocorrect(v) end)
  local note = Label(panel, "", COLOR.muted)
  note:SetPoint("TOPLEFT", 190, y - 26)
  note:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
  note:SetJustifyH("LEFT")
  local warning = Label(panel, "Autocorrect Forever's own accent is on, so messages get two accents.", COLOR.gold)
  warning:SetPoint("TOPLEFT", 20, y - 62)
  local fix = TextButton(panel, "Turn it off", 90, function()
    local command = SlashCmdList and SlashCmdList.AUTOCORRECTFOREVER
    if type(command) == "function" then pcall(command, "accent off") end
    BT.RefreshOptions()
  end)
  fix:SetPoint("LEFT", warning, "RIGHT", 10, 0)
  local section = {}
  function section:Refresh()
    local state = BT.AutocorrectState()
    check:SetLocked(state == nil)
    note:SetText(state and "Uses the Autocorrect Forever addon. This switch is shared by all your characters."
      or "Install Autocorrect Forever to use this.")
    local doubled = state ~= nil and state.accent
    warning:SetShown(doubled)
    fix:SetShown(doubled)
  end
  refreshers[#refreshers + 1] = section
  return y - 80
end

--- Builds the panel and registers it with the game's settings. Safe to call twice.
function BT.BuildOptions()
  if panel or not BT.db then return end
  panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  panel:Hide()
  Surface(panel, COLOR.bg, COLOR.bronze)

  local title = Label(panel, "Bronzetongue", COLOR.gold, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 46, -14)
  local mark = panel:CreateTexture(nil, "ARTWORK")
  mark:SetTexture("Interface\\AddOns\\Bronzetongue\\Media\\infinity")
  mark:SetSize(24, 12)
  mark:SetPoint("RIGHT", title, "LEFT", -6, 0)
  local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata
  local version = Label(panel, getMetadata and ("v" .. tostring(getMetadata(ADDON, "Version"))) or "", COLOR.muted)
  version:SetPoint("TOPRIGHT", -18, -18)

  local y = -48
  y = BuildVoice(y)
  y = BuildAuto(y)
  y = BuildWheel(y)
  BuildAutocorrect(y)

  panel:SetScript("OnShow", BT.RefreshOptions)
  panel:SetScript("OnHide", ClosePopup)

  if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, "Bronzetongue")
    Settings.RegisterAddOnCategory(category)
  elseif InterfaceOptions_AddCategory then
    panel.name = "Bronzetongue"
    InterfaceOptions_AddCategory(panel)
  end
end

function BT.OpenOptions()
  if InCombatLockdown() then return BT.Print("Options open after combat.") end
  BT.BuildOptions()
  if category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(category:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory and panel then
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
  local ok, problem = pcall(BT.BuildOptions)
  if not ok then BT.Print("the options panel could not be built (" .. tostring(problem) .. "). Chat still works.") end
end)
