local BT = Harness.load({ "Engine/Protect.lua", "Engine/Terms.lua", "Engine/Voices.lua", "Engine/Engine.lua" })
dofile("tests/testvoices.lua")(BT)
local function never() return 99 end
local S = function(t, o) o.random = o.random or never return BT.Engine.Speak(t, o) end

function test_swap_light()          assert(S("hello there", { race = "t_race", strength = 1 }) == "ahoy there") end
function test_tier_gates_swap()     assert(S("hello you", { race = "t_race", strength = 1 }) == "ahoy you") end
function test_medium_adds_tier2()   assert(S("hello you", { race = "t_race", strength = 2 }) == "ahoy ye") end
function test_case_capitalised()    assert(S("Hello", { race = "t_race", strength = 1 }) == "Ahoy") end
function test_case_shouted()        assert(S("HELLO", { race = "t_race", strength = 1 }) == "AHOY") end
function test_whole_word_only()     assert(S("hellos mymy", { race = "t_race", strength = 3 }) == "hellos mymy") end
function test_punctuation_kept()    assert(S("hello, you!", { race = "t_race", strength = 2 }) == "ahoy, ye!") end
function test_quoted_word()         assert(S("'hello'", { race = "t_race", strength = 1 }) == "'ahoy'") end
function test_sound_rule()          assert(S("going fishing", { race = "t_race", strength = 2 }) == "goin' fishin'") end
function test_sound_rule_keeps_case() assert(S("Going FISHING", { race = "t_race", strength = 2 }) == "Goin' FISHIN'") end
function test_sound_rule_off_light() assert(S("going", { race = "t_race", strength = 1 }) == "going") end
function test_sound_rule_skips_short_words() assert(S("ing", { race = "t_race", strength = 3 }) == "ing") end
function test_class_stacks()        assert(S("hello kill", { race = "t_race", class = "t_class", strength = 1 }) == "ahoy smite") end
function test_class_does_not_reswap_race_output()
  assert(S("hello", { race = "t_race", class = "t_class", strength = 1 }) == "ahoy") end
function test_class_alone()         assert(S("hello", { class = "t_class", strength = 1 }) == "hail") end
function test_no_voice_is_identity() assert(S("hello you", { strength = 3 }) == "hello you") end
function test_unknown_voice_id_is_none() assert(S("hello", { race = "gone", class = "gone", strength = 3 }) == "hello") end
function test_slash_command_untouched() assert(S("/who hello", { race = "t_race", strength = 3 }) == "/who hello") end
function test_empty_and_whitespace()
  assert(S("", { race = "t_race", strength = 3 }) == "" and S("   ", { race = "t_race", strength = 3 }) == "   ") end
function test_emoticons_numbers()   assert(S("gg :) <3 123 !!!", { race = "t_race", strength = 3 }) == "gg :) <3 123 !!!") end
function test_non_ascii_untouched() assert(S("hej på dig åäö hello", { race = "t_race", strength = 1 }) == "hej på dig åäö ahoy") end
function test_non_ascii_word_not_sound_ruled() assert(S("spårning", { race = "t_race", strength = 3 }) == "spårning") end
function test_link_survives() local L = "|cff0070dd|Hitem:1:::|h[Hello Ring]|h|r"
  assert(S("hello " .. L, { race = "t_race", strength = 1 }) == "ahoy " .. L) end
function test_names_survive()       assert(S("hello My", { race = "t_race", strength = 1, names = { "My" } }) == "ahoy My") end
function test_opener_heavy()        -- rolls: chance 1 (<=35), opener (1), which (1)
  assert(S("hello there friend", { race = "t_race", strength = 3, random = Harness.seq(1, 1, 1) }) == "Arr, ahoy there friend") end
function test_closer_heavy()
  assert(S("hello there friend", { race = "t_race", strength = 3, random = Harness.seq(1, 2, 1) }) == "ahoy there friend Yarr!") end
function test_chance_gate_medium()  -- 10% at medium: a roll of 11 adds nothing, 10 does
  assert(S("hello there friend", { race = "t_race", strength = 2, random = Harness.seq(11) }) == "ahoy there friend")
  assert(S("hello there friend", { race = "t_race", strength = 2, random = Harness.seq(10, 1, 1) }) == "Arr, ahoy there friend") end
function test_chance_gate_heavy()
  assert(S("hello there friend", { race = "t_race", strength = 3, random = Harness.seq(36) }) == "ahoy there friend") end
function test_no_interjection_short()
  assert(S("hello there", { race = "t_race", strength = 3, random = Harness.seq(1, 1, 1) }) == "ahoy there") end
function test_no_interjection_light()
  assert(S("hello there friend", { race = "t_race", strength = 1, random = Harness.seq(1, 1, 1) }) == "ahoy there friend") end
function test_over_255_falls_back_lighter()
  local t = string.rep("going ", 42) .. "ok"            -- 254 bytes; an opener would push it past 255
  local out = S(t, { race = "t_race", strength = 3, random = Harness.seq(1, 1, 1) })
  assert(#out <= 255 and not out:find("Arr", 1, true)) end
function test_over_255_returns_original()
  local t = string.rep("a ", 120) assert(S(t, { race = "t_long", strength = 1 }) == t) end
function test_default_random_works() assert(BT.Engine.Speak("hello", { race = "t_race", strength = 1 }) == "ahoy") end

function test_capital_survives_a_leading_apostrophe()
  assert(S("Them", { class = "t_class", strength = 1 }) == "'Em" and S("them", { class = "t_class", strength = 1 }) == "'em") end
