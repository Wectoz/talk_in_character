-- Loads every file exactly as the TOC lists it, as the game does, then logs in.
dofile("tests/stubs.lua")
local files, interface, savedVar = {}, nil, nil
for line in io.lines("TalkInCharacter/TalkInCharacter.toc") do
  line = line:gsub("%s+$", "")
  if line:find("^## Interface:") then interface = line:match("(%d+)") end
  if line:find("^## SavedVariablesPerCharacter:") then savedVar = line:match(":%s*(%S+)") end
  if line:find("%.lua$") then files[#files + 1] = (line:gsub("\\", "/")) end
end
TalkInCharacterCharDB = nil
local BT = Harness.load(files)
Stub.race, Stub.class = "Gnome", "MAGE"
Stub.Event("ADDON_LOADED", "TalkInCharacter")
Stub.Event("PLAYER_LOGIN")

function test_toc_targets_the_installed_forever_build() assert(interface == "16001") end
function test_saved_variable_name_matches_the_code() assert(savedVar == "TalkInCharacterCharDB") end
function test_whole_addon_loads_and_logs_in()
  assert(TalkInCharacterCharDB == BT.db and BT.db.race == "gnome" and BT.db.class == "mage")
  assert(Stub.categoryName == "Talk in Character") end
function test_every_voice_is_loaded_and_selectable()
  local n = #BT.VoicesOfKind("race") + #BT.VoicesOfKind("faction") + #BT.VoicesOfKind("class")
  assert(n == 33, "voices loaded: " .. n) end
function test_first_message_after_login_is_voiced()
  local box = FakeBox("hello friend, this is great", "SAY")
  EventRegistry.Fire("ChatFrame.OnEditBoxPreSendText", box)
  assert(box:GetText() ~= "hello friend, this is great" and #box:GetText() <= 255) end
function test_wheel_opens_and_says_a_line_for_every_voice()
  for _, kind in ipairs({ "race", "faction", "class" }) do
    for _, voice in ipairs(BT.VoicesOfKind(kind)) do
      BT.db.race, BT.db.class = nil, nil
      BT.db[kind == "class" and "class" or "race"] = voice.id
      Stub.sent, Stub.cursorX, Stub.cursorY = nil, 500, 500
      TalkInCharacterWheel_OnKey("down") Stub.cursorY = 580 TalkInCharacterWheel_OnKey("up")
      assert(Stub.sent and #Stub.sent[1] > 0, "wheel said nothing for " .. voice.id)
    end
  end
  BT.db.race, BT.db.class = "gnome", "mage" end
function test_binding_names_match_bindings_xml()
  local xml = io.open("TalkInCharacter/Bindings.xml"):read("*a")
  local name, header, body = xml:match('name="([^"]+)"'), xml:match('header="([^"]+)"'), xml:match(">%s*([%w_]+)%(keystate%)")
  assert(_G["BINDING_NAME_" .. name] and _G["BINDING_HEADER_" .. header] and type(_G[body]) == "function") end
