dofile("tests/stubs.lua")
local BT = Harness.load({ "Core.lua", "Engine/Protect.lua", "Engine/Voices.lua", "Engine/Engine.lua", "Engine/Moods.lua",
  "Engine/Phrases.lua", "Send.lua", "Preview.lua", "Wheel.lua", "Options.lua" })
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
  for _, t in ipairs({ "SAY", "YELL", "PARTY", "RAID", "GUILD", "WHISPER" }) do assert(send("hello", t) == "ahoy", t) end
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
function test_ctrl_enter_sends_plain() Stub.ctrl = true assert(send("hello", "SAY") == "hello") Stub.ctrl = false end
function test_alt_enter_is_not_special() Stub.alt = true assert(send("hello", "SAY") == "ahoy") Stub.alt = false end
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

-- Preview
function test_preview_text()         assert(BT.PreviewText("hello", "SAY") == "ahoy") end
function test_preview_nil_when_same() assert(BT.PreviewText("zzz", "SAY") == nil) end
function test_preview_nil_when_off() BT.db.preview = false assert(BT.PreviewText("hello", "SAY") == nil) BT.db.preview = true end
function test_preview_nil_unticked() assert(BT.PreviewText("hello", "OFFICER") == nil) end
function test_preview_nil_slash()    assert(BT.PreviewText("/who", "SAY") == nil) end
function test_preview_nil_empty()    assert(BT.PreviewText("", "SAY") == nil and BT.PreviewText(nil, "SAY") == nil) end
function test_preview_nil_in_lockdown() Stub.lockdown = true assert(BT.PreviewText("hello", "SAY") == nil) Stub.lockdown = false end
function test_preview_stable()
  BT.db.strength, BT.db.mood = 3, "angry"
  local a = BT.PreviewText("hello there friend", "SAY")
  for i = 1, 20 do assert(BT.PreviewText("hello there friend", "SAY") == a) end
  assert(a == "ahoy there friend!")
  BT.db.strength, BT.db.mood = 1, "calm" end
function test_preview_never_hooks_chat_boxes()
  local box = FakeBox("hello", "SAY") local hooks = 0
  function box:HookScript() hooks = hooks + 1 end
  function box:SetScript() hooks = hooks + 1 end
  EventRegistry.Fire("ChatFrame.OnEditBoxPreSendText", box)
  Stub.activeBox = box BT.PreviewTick() Stub.activeBox = nil
  assert(hooks == 0) end
function test_preview_tick_follows_the_active_box()
  Stub.activeBox = FakeBox("hello", "SAY") assert(BT.PreviewTick() == "ahoy")
  Stub.activeBox = FakeBox("zzz", "SAY") assert(BT.PreviewTick() == nil)
  Stub.activeBox = nil assert(BT.PreviewTick() == nil) end
function test_preview_tick_ignores_a_hidden_box()
  local box = FakeBox("hello", "SAY") function box:IsShown() return false end
  Stub.activeBox = box assert(BT.PreviewTick() == nil) Stub.activeBox = nil end
function test_preview_secret_text_is_ignored()
  Stub.targetName = "hello" Stub.targetSecret = true assert(BT.PreviewText("hello", "SAY") == nil)
  Stub.targetName = nil Stub.targetSecret = false end
function test_send_secret_text_is_left_alone()
  Stub.targetName = "hello" Stub.targetSecret = true local _, box = send("hello", "SAY") assert(box.sets == 0)
  Stub.targetName = nil Stub.targetSecret = false end

-- Wheel
local function resetWheel() Stub.sent, Stub.opened, Stub.cursorX, Stub.cursorY = nil, nil, 500, 500 BT.db.wheelChat = "SAY" end
function test_wheelsay_sends_to_chosen_chat()
  resetWheel() BT.db.wheelChat = "YELL" BT.WheelSay("hi") assert(Stub.sent[1] == "hi" and Stub.sent[2] == "YELL") resetWheel() end
function test_wheelsay_party_falls_back_to_say()
  resetWheel() BT.db.wheelChat = "PARTY" Stub.inGroup = false BT.WheelSay("hi") assert(Stub.sent[2] == "SAY") resetWheel() end
function test_wheelsay_party_when_grouped()
  resetWheel() BT.db.wheelChat = "PARTY" Stub.inGroup = true BT.WheelSay("hi") assert(Stub.sent[2] == "PARTY") Stub.inGroup = false resetWheel() end
function test_wheelsay_raid_needs_a_raid()
  resetWheel() BT.db.wheelChat = "RAID" Stub.inGroup = true Stub.inRaid = false BT.WheelSay("hi") assert(Stub.sent[2] == "SAY") Stub.inGroup = false resetWheel() end
function test_wheelsay_unknown_chat_falls_back_to_say()
  resetWheel() BT.db.wheelChat = "CHANNEL" BT.WheelSay("hi") assert(Stub.sent[2] == "SAY") resetWheel() end
function test_wheelsay_never_opens_the_chat_box()
  resetWheel() BT.db.wheelToBox = true BT.WheelSay("hello") BT.db.wheelToBox = nil
  assert(Stub.opened == nil and Stub.sent[1] == "hello") resetWheel() end
function test_wheel_closed_in_lockdown()
  resetWheel() Stub.lockdown = true BronzetongueWheel_OnKey("down") assert(not BT.wheelOpen) Stub.lockdown = false BronzetongueWheel_OnKey("up") end
function test_wheel_off_setting()
  resetWheel() BT.db.wheel = false BronzetongueWheel_OnKey("down") assert(not BT.wheelOpen) BT.db.wheel = true BronzetongueWheel_OnKey("up") end
function test_wheel_no_voice()
  resetWheel() BT.db.race, BT.db.class = nil, nil BronzetongueWheel_OnKey("down") assert(not BT.wheelOpen) BT.db.race = "t_race" BronzetongueWheel_OnKey("up") end
function test_wheel_up_without_slot_sends_nothing()
  resetWheel() BronzetongueWheel_OnKey("down") assert(BT.wheelOpen) BronzetongueWheel_OnKey("up") assert(Stub.sent == nil and not BT.wheelOpen) end
function test_wheel_flick_up_says_a_hello_line()
  resetWheel() BronzetongueWheel_OnKey("down") Stub.cursorY = 560 BronzetongueWheel_OnKey("up")
  assert(Stub.sent and (Stub.sent[1] == "a." or Stub.sent[1] == "b." or Stub.sent[1] == "c.") and Stub.sent[2] == "SAY") resetWheel() end
function test_wheel_up_without_down_is_harmless() resetWheel() BronzetongueWheel_OnKey("up") assert(Stub.sent == nil) end
function test_wheel_lockdown_starting_while_open_sends_nothing()
  resetWheel() BronzetongueWheel_OnKey("down") Stub.cursorY = 560 Stub.lockdown = true BronzetongueWheel_OnKey("up")
  Stub.lockdown = false assert(Stub.sent == nil) resetWheel() end
function test_wheel_target_secret_is_nil()
  Stub.targetName = "Thrall" Stub.targetSecret = true assert(BT.WheelTarget() == nil) Stub.targetSecret = false Stub.targetName = nil end
function test_wheel_target_name()
  Stub.targetName = "Thrall" assert(BT.WheelTarget().name == "Thrall") Stub.targetName = nil assert(BT.WheelTarget() == nil) end

-- Options (the panel itself is checked in game; these cover the logic around it)
function test_options_build_registers_category()
  BT.BuildOptions() assert(Stub.categoryName == "Bronzetongue" and Stub.registered ~= nil) end
function test_open_options()
  BT.BuildOptions() Stub.openedCategory = nil BT.OpenOptions() assert(Stub.openedCategory == 7) end
function test_open_options_waits_for_combat_to_end()
  BT.BuildOptions() Stub.openedCategory = nil Stub.combat = true BT.OpenOptions() Stub.combat = false assert(Stub.openedCategory == nil) end
function test_slash_without_argument_opens_options()
  BT.BuildOptions() Stub.openedCategory = nil SlashCmdList.BRONZETONGUE("") assert(Stub.openedCategory == 7) end
function test_bind_wheel_key_replaces_old_key()
  Stub.bindings, Stub.boundKey, Stub.bindingsSaved = {}, "F5", false
  assert(BT.BindWheelKey("ALT-G") == true)
  assert(Stub.bindings["F5"] == false and Stub.bindings["ALT-G"] == "BRONZETONGUE_WHEEL" and Stub.bindingsSaved)
  Stub.boundKey = nil end
function test_bind_wheel_key_clear()
  Stub.bindings, Stub.boundKey = {}, "F5" assert(BT.BindWheelKey(nil) == true and Stub.bindings["F5"] == false) Stub.boundKey = nil end
function test_bind_wheel_key_refused_in_combat()
  Stub.bindings, Stub.combat = {}, true assert(BT.BindWheelKey("G") == false and next(Stub.bindings) == nil) Stub.combat = false end
function test_key_chord_ignores_bare_modifiers()
  assert(BT.KeyChord("LSHIFT") == nil and BT.KeyChord("RCTRL") == nil and BT.KeyChord("G") == "G")
  Stub.alt = true assert(BT.KeyChord("G") == "ALT-G") Stub.alt = false end
function test_autocorrect_state()
  _G.AutocorrectForever, _G.AutocorrectForeverDB = nil, nil
  assert(BT.AutocorrectState() == nil)
  _G.AutocorrectForever = {} assert(BT.AutocorrectState().enabled == false)
  _G.AutocorrectForeverDB = { enabled = true, accent = "pirate" }
  local state = BT.AutocorrectState() assert(state.enabled == true and state.accent == true)
  _G.AutocorrectForever, _G.AutocorrectForeverDB = nil, nil end
function test_autocorrect_switch_uses_its_slash_command()
  local said SlashCmdList.AUTOCORRECTFOREVER = function(msg) said = msg end
  BT.SetAutocorrect(false) assert(said == "off") BT.SetAutocorrect(true) assert(said == "on")
  SlashCmdList.AUTOCORRECTFOREVER = nil BT.SetAutocorrect(true) end

-- Small issues fixed after the first review
function test_emote_voices_only_quoted_speech()
  assert(send('waves and says "hello" to you', "EMOTE") == 'waves and says "ahoy" to you')
  assert(send('says "hello" then "hello"', "EMOTE") == 'says "ahoy" then "ahoy"') end
function test_emote_without_quotes_is_left_alone() assert(send("waves hello", "EMOTE") == "waves hello") end
function test_emote_preview_matches() assert(BT.PreviewText('says "hello"', "EMOTE") == 'says "ahoy"' and BT.PreviewText("waves hello", "EMOTE") == nil) end
function test_lockdown_cvar_counts_as_lockdown()
  Stub.cvars = { addonChatRestrictionsForced = true } assert(BT.InLockdown() == true and send("hello", "SAY") == "hello")
  Stub.cvars = nil assert(BT.InLockdown() == false) end
function test_bind_wheel_key_refuses_a_key_in_use()
  Stub.bindings, Stub.boundKey, Stub.actions, Stub.prints = {}, nil, { G = "TOGGLEGUILDTAB" }, 0
  assert(BT.BindWheelKey("G") == false and next(Stub.bindings) == nil and Stub.prints == 1) Stub.actions = nil end
function test_bind_wheel_key_allows_its_own_key_again()
  Stub.bindings, Stub.boundKey, Stub.actions = {}, "G", { G = "BRONZETONGUE_WHEEL" }
  assert(BT.BindWheelKey("G") == true and Stub.bindings.G == "BRONZETONGUE_WHEEL") Stub.actions, Stub.boundKey = nil, nil end
function test_bind_wheel_key_reports_a_failed_bind()
  Stub.bindings, Stub.bindFails, Stub.prints = {}, true, 0
  assert(BT.BindWheelKey("G") == false and Stub.prints == 1) Stub.bindFails = nil end

-- Second review
function test_emote_keeps_a_link_with_quotes_in_its_name()
  local L = '|cff0070dd|Hitem:1:::|h["Hello" Kitty]|h|r'
  assert(send("holds " .. L .. ' up and says "hello"', "EMOTE") == "holds " .. L .. ' up and says "ahoy"') end
function test_failed_bind_keeps_the_old_key()
  Stub.bindings, Stub.boundKey, Stub.bindFails, Stub.prints = {}, "F5", true, 0
  assert(BT.BindWheelKey("G") == false and Stub.bindings["F5"] == nil)
  Stub.bindFails, Stub.boundKey = nil, nil end
function test_refusal_names_the_action_readably()
  Stub.bindings, Stub.actions, Stub.printed = {}, { G = "CLICK Foo:LeftButton" }, nil
  GetBindingName = function(action) return "Foo Button" end
  BT.BindWheelKey("G") assert(Stub.printed:find("Foo Button", 1, true))
  GetBindingName, Stub.actions = nil, nil end
function test_preview_does_not_recompute_unchanged_text()
  local real, calls = BT.Engine.Speak, 0
  BT.Engine.Speak = function(...) calls = calls + 1 return real(...) end
  Stub.activeBox = FakeBox("hello", "PARTY")
  assert(BT.PreviewTick() == "ahoy" and BT.PreviewTick() == "ahoy" and calls == 1)
  BT.db.strength = 2 assert(BT.PreviewTick() == "ahoy" and calls == 2) BT.db.strength = 1
  Stub.activeBox.text = "hello you" BT.PreviewTick() assert(calls == 3)
  BT.Engine.Speak = real Stub.activeBox = nil end
