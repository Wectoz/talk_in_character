local BT = Harness.load({ "Engine/Protect.lua", "Engine/Voices.lua", "Engine/Engine.lua", "Engine/Moods.lua" })
dofile("tests/testvoices.lua")(BT)
local A = function(t, m, ...) return BT.Moods.Apply(t, m, Harness.seq(...), {}) end
local function never() return 99 end

function test_calm_identity()        assert(A("hello there.", "calm") == "hello there.") end
function test_unknown_mood_identity() assert(A("hello", "sleepy") == "hello") end
function test_angry_punctuation()    assert(A("go away.", "angry", 99, 99, 99) == "go away!") end
function test_angry_adds_bang()      assert(A("go away", "angry", 99, 99, 99) == "go away!") end
function test_angry_keeps_question() assert(A("why?", "angry", 99, 99) == "why?") end
function test_angry_shouts_word()    assert(A("go away now", "angry", 1, 99, 99) == "go AWAY now!") end
function test_angry_shout_gate()     assert(A("away", "angry", 16, 99) == "away!" and A("away", "angry", 15, 99) == "AWAY!") end
function test_angry_builtin_closer() assert(A("go away", "angry", 99, 1, 1) == "go away! Grr!") end
function test_angry_closer_gate()    assert(A("go away", "angry", 99, 31) == "go away!") end
function test_drunk_slur()           assert(A("yes sir", "drunk", 99, 99) == "yesh shir") end
function test_drunk_slur_capital()   assert(A("Sir", "drunk", 99) == "Shir") end
function test_drunk_keeps_sh()       assert(A("ship", "drunk", 99) == "ship") end
function test_drunk_hic()            assert(A("one two", "drunk", 1, 99) == "one *hic* two") end
function test_drunk_hic_gate()       assert(A("one two", "drunk", 9, 99) == "one two" and A("one two", "drunk", 8, 99) == "one *hic* two") end
function test_drunk_never_two_hics() assert(A("one two three", "drunk", 1, 1, 99) == "one *hic* two three") end
function test_scared_stutter()       assert(A("Hello you", "scared", 1, 99) == "H-Hello you...") end
function test_scared_gate()          assert(A("hello", "scared", 21) == "hello..." and A("hello", "scared", 20) == "h-hello...") end
function test_scared_short_words_spared() assert(A("go on", "scared", 1, 1) == "go on...") end
function test_scared_dots()          assert(A("run.", "scared", 99) == "run...") end
function test_scared_keeps_question() assert(A("who?", "scared", 99) == "who?") end
function test_placeholder_untouched() assert(A("see \0011\002 sir", "drunk", 99, 99, 99) == "shee \0011\002 shir") end
function test_non_ascii_untouched()  assert(A("påse", "drunk", 99) == "påse") end
function test_voice_mood_closer()
  local v = { moods = { angry = { closers = { "Unscientific!" } } } }
  assert(BT.Moods.Apply("go away", "angry", Harness.seq(99, 1, 1), { v }) == "go away! Unscientific!") end
function test_mood_applied_in_speak()
  assert(BT.Engine.Speak("yes", { race = "t_race", strength = 1, mood = "drunk", random = never }) == "yesh") end
function test_mood_applies_with_no_voice()
  assert(BT.Engine.Speak("yes", { strength = 1, mood = "drunk", random = never }) == "yesh") end
function test_mood_dropped_on_overflow()
  local t = string.rep("sass ", 50) .. "sas"            -- 253 bytes; slurring would add about 100
  assert(BT.Engine.Speak(t, { race = "t_race", strength = 1, mood = "drunk", random = never }) == t) end
function test_mood_does_not_touch_links()
  local L = "|cff0070dd|Hitem:1:::|h[Sass Ring]|h|r"
  assert(BT.Engine.Speak("yes " .. L, { race = "t_race", strength = 1, mood = "drunk", random = never }) == "yesh " .. L) end

-- A message with no words (an emoticon, a number, a lone link) is left exactly as typed.
function test_wordless_messages_take_no_mood_or_interjection()
  local L = "|cff0070dd|Hitem:1:::|h[Great Big Sword]|h|r"
  local function first() return 1 end
  for _, mood in ipairs({ "angry", "drunk", "scared" }) do
    for _, text in ipairs({ ":)", "<3", "123", "!!!", ":D", L, "a" }) do
      local out = BT.Engine.Speak(text, { race = "t_race", strength = 3, mood = mood, random = first })
      assert(out == text, mood .. " changed '" .. text .. "' to '" .. out .. "'")
    end
  end end
function test_link_words_do_not_count_toward_interjections()
  local L = "|cff0070dd|Hitem:1:::|h[Great Big Sword]|h|r"
  assert(BT.Engine.Speak("see " .. L, { race = "t_race", strength = 3, random = function() return 1 end }) == "see " .. L) end

function test_typed_words_are_counted_before_swaps()
  local L = "|cff0070dd|Hitem:1:::|h[Sword]|h|r"   -- two typed words; the swap "ahoy there" must not make it three
  BT.voices.t_race.swaps.hi = { tier = 1, "ahoy there" }
  local out = BT.Engine.Speak("hi " .. L .. " ok", { race = "t_race", strength = 3, random = function() return 1 end })
  BT.voices.t_race.swaps.hi = nil
  assert(out == "ahoy there " .. L .. " ok", out) end
function test_xd_is_an_emoticon_not_a_word()
  for _, text in ipairs({ "xD", "XD", "xD xD" }) do
    assert(BT.Engine.Speak(text, { race = "t_race", strength = 3, mood = "angry", random = function() return 1 end }) == text) end end
function test_short_words_still_take_a_mood()
  assert(BT.Engine.Speak("no", { race = "t_race", strength = 1, mood = "angry", random = function() return 99 end }) == "no!") end
