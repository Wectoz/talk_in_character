dofile("tests/stubs.lua")
local BT = Harness.load({ "Core.lua", "Engine/Protect.lua", "Engine/Voices.lua", "Engine/Engine.lua", "Engine/Moods.lua",
  "Engine/Phrases.lua", "Send.lua" })
dofile("tests/testvoices.lua")(BT)
Stub.Event("ADDON_LOADED", "Bronzetongue")
BT.db.race, BT.db.class, BT.db.strength, BT.db.matched = "t_race", nil, 1, true

local function send(text, chatType)
  local b = FakeBox(text, chatType)
  EventRegistry.Fire("ChatFrame.OnEditBoxPreSendText", b)
  return b:GetText(), b
end

function test_addon_loaded_creates_saved_settings()
  assert(BronzetongueCharDB == BT.db and BT.db.enabled == true and BT.db.chats.SAY == true and BT.db.chats.OFFICER == false) end
function test_other_addon_loading_is_ignored()
  local before = BT.db Stub.Event("ADDON_LOADED", "SomethingElse") assert(BT.db == before) end
function test_say_rewritten()        assert(send("hello", "SAY") == "ahoy") end
function test_each_default_chat()
  for _, t in ipairs({ "SAY", "YELL", "EMOTE", "PARTY", "RAID", "GUILD", "WHISPER" }) do assert(send("hello", t) == "ahoy", t) end
  for _, t in ipairs({ "OFFICER", "INSTANCE_CHAT", "CHANNEL" }) do assert(send("hello", t) == "hello", t) end end
function test_unticked_chat_untouched() assert(send("hello", "OFFICER") == "hello") end
function test_ticking_a_chat_enables_it()
  BT.db.chats.OFFICER = true assert(send("hello", "OFFICER") == "ahoy") BT.db.chats.OFFICER = false end
function test_bn_whisper_never()
  BT.db.chats.BN_WHISPER = true assert(send("hello", "BN_WHISPER") == "hello") BT.db.chats.BN_WHISPER = nil end
function test_unknown_chat_type()    assert(send("hello", "SOMETHING") == "hello" and send("hello", nil) == "hello") end
function test_disabled()             BT.db.enabled = false assert(send("hello", "SAY") == "hello") BT.db.enabled = true end
function test_lockdown()             Stub.lockdown = true assert(send("hello", "SAY") == "hello") Stub.lockdown = false end
function test_lockdown_api_missing()
  local f = C_ChatInfo.InChatMessagingLockdown C_ChatInfo.InChatMessagingLockdown = nil
  assert(send("hello", "SAY") == "ahoy") C_ChatInfo.InChatMessagingLockdown = f end
function test_lockdown_api_erroring_counts_as_open()
  local f = C_ChatInfo.InChatMessagingLockdown C_ChatInfo.InChatMessagingLockdown = function() error("x") end
  assert(send("hello", "SAY") == "ahoy") C_ChatInfo.InChatMessagingLockdown = f end
function test_alt_sends_plain()      Stub.alt = true assert(send("hello", "SAY") == "hello") Stub.alt = false end
function test_no_voice_chosen()      BT.db.race = nil assert(send("hello", "SAY") == "hello") BT.db.race = "t_race" end
function test_stale_voice_id()       BT.db.race = "removed_voice" assert(send("hello", "SAY") == "hello") BT.db.race = "t_race" end
function test_unchanged_text_is_not_set() local _, box = send("zzz", "SAY") assert(box.sets == 0) end
function test_engine_error_keeps_text_and_reports_once()
  local real = BT.Engine.Speak BT.Engine.Speak = function() error("boom") end
  Stub.prints = 0
  assert(send("hello", "SAY") == "hello" and send("hello", "SAY") == "hello")
  BT.Engine.Speak = real
  assert(Stub.prints == 1) end
function test_box_without_gettext_is_ignored() EventRegistry.Fire("ChatFrame.OnEditBoxPreSendText", {}) EventRegistry.Fire("ChatFrame.OnEditBoxPreSendText", nil) end
function test_autocorrect_lasttext_cleared()
  _G.AutocorrectForever = { lastText = "hello" } send("hello", "SAY")
  assert(_G.AutocorrectForever.lastText == false) _G.AutocorrectForever = nil end
function test_autocorrect_untouched_when_unchanged()
  _G.AutocorrectForever = { lastText = "zzz" } send("zzz", "SAY")
  assert(_G.AutocorrectForever.lastText == "zzz") _G.AutocorrectForever = nil end
function test_target_name_protected()
  Stub.targetName = "My" assert(send("hello My", "SAY") == "ahoy My") Stub.targetName = nil end
function test_secret_target_name_is_skipped()
  Stub.targetName = "My" Stub.targetSecret = true assert(send("hello My", "SAY") == "ahoy Me")
  Stub.targetName = nil Stub.targetSecret = false end
function test_defaults_filled_on_old_save()
  local old = { enabled = false, chats = { SAY = false } } BT.ApplyDefaults(old)
  assert(old.enabled == false and old.chats.SAY == false and old.chats.GUILD == true and old.strength == 2) end
function test_match_character()
  local race, class = BT.db.race, BT.db.class
  BT.RACE_TOKENS.TestRace = "t_race" Stub.race = "TestRace" Stub.class = "T_CLASS" BT.MatchCharacter()
  assert(BT.db.race == "t_race" and BT.db.class == "t_class")
  BT.db.race, BT.db.class = race, class end
function test_match_unknown_race_and_class()
  local race, class = BT.db.race, BT.db.class
  Stub.race = "Dracthyr" Stub.class = "EVOKER" BT.MatchCharacter() assert(BT.db.race == nil and BT.db.class == nil)
  BT.db.race, BT.db.class = race, class end
function test_race_tokens_cover_the_eight_races()
  local want = { Human = "human", Dwarf = "dwarf", NightElf = "nightelf", Gnome = "gnome", Orc = "orc", Troll = "troll", Tauren = "tauren", Scourge = "forsaken" }
  for token, id in pairs(want) do assert(BT.RACE_TOKENS[token] == id, token) end end
function test_first_login_matches_character_once()
  BT.db.matched = false BT.RACE_TOKENS.TestRace = "t_race" Stub.race = "TestRace" Stub.class = "NOPE"
  Stub.Event("PLAYER_LOGIN") assert(BT.db.matched == true and BT.db.race == "t_race")
  BT.db.race = nil Stub.Event("PLAYER_LOGIN") assert(BT.db.race == nil)
  BT.db.race = "t_race" end
function test_slash_on_off()
  SlashCmdList.BRONZETONGUE("off") assert(BT.db.enabled == false)
  SlashCmdList.BRONZETONGUE(" ON ") assert(BT.db.enabled == true)
  assert(SLASH_BRONZETONGUE1 == "/bronzetongue" and SLASH_BRONZETONGUE2 == "/bronze") end
function test_toc_lists_every_lua_file()
  local listed = {}
  for line in io.lines("Bronzetongue/Bronzetongue.toc") do
    if line:find("%.lua%s*$") then listed[line:gsub("\\", "/"):gsub("%s+$", "")] = true end
  end
  for path in io.popen("find Bronzetongue -name '*.lua'"):lines() do
    local rel = path:gsub("^Bronzetongue/", "")
    assert(listed[rel], "not in TOC: " .. rel) listed[rel] = nil
  end
  assert(next(listed) == nil, "TOC lists a missing file: " .. tostring(next(listed))) end
