local BT = Harness.load({ "Engine/Protect.lua", "Engine/Terms.lua", "Engine/Voices.lua", "Engine/Engine.lua", "Engine/Ages.lua", "Engine/Moods.lua", "Engine/Phrases.lua" })
dofile("tests/testvoices.lua")(BT)
local function never() return 99 end
local S = function(t, o) o.random = o.random or never return BT.Engine.Speak(t, o) end

function test_adult_changes_nothing() assert(S("it is very big.", { age = "adult" }) == "it is very big.") end
function test_young_words_and_ending()
  assert(S("It is very big.", { age = "young" }) == "It is sooo huge!")
  assert(S("VERY nice", { age = "young" }) == "SOOO neat!") end
function test_young_keeps_other_endings()
  assert(S("is it big?", { age = "young" }) == "is it huge?")
  assert(S("wait...", { age = "young" }) == "wait...")
  assert(S("nice :)", { age = "young" }) == "neat :)") end
function test_young_aside()   -- rolls: aside (20), which closer (1)
  assert(S("look at that", { age = "young", random = Harness.seq(20, 1) }) == "look at that! Can we go now?") end
function test_no_aside_when_extras_off_or_short()
  assert(S("look at that", { age = "young", extras = false, random = Harness.seq(1, 1) }) == "look at that!")
  assert(S("look there", { age = "young", random = Harness.seq(1, 1) }) == "look there!") end
function test_elder_words_and_pause()   -- roll: the comma becomes a pause (30)
  assert(S("ok, the kids are tired", { age = "elder", random = Harness.seq(30, 99) }) == "very well... the youngsters are weary") end
function test_elder_opener_and_closer()   -- rolls: aside (1), opener (1) or closer (2), which (1)
  assert(S("the road is long", { age = "elder", random = Harness.seq(1, 1, 1) }) == "Hmm... the road is long")
  assert(S("the road is long", { age = "elder", random = Harness.seq(1, 2, 1) }) == "the road is long. Back in my day, we walked.") end
function test_age_after_voice_and_with_terms()
  assert(S("hello lfm brd", { race = "t_race", strength = 1, age = "young" }) == "ahoy lfm brd") end
function test_age_with_mood()
  assert(S("very big", { age = "young", mood = "drunk" }) == "shooo huge!") end
function test_age_dropped_when_over_255()
  local t = string.rep("very ", 50) .. "ok"   -- 252 bytes; "sooo" would not grow it, the "!" fits, an aside would not
  local out = S(t, { age = "young", random = Harness.seq(1, 1) })
  assert(#out <= 255) end
function test_wheel_line_takes_the_age()
  assert(BT.Phrases.Pick("hello", { race = "p_race", age = "young", extras = false, random = Harness.seq(1) }, nil) == "Hi!") end
function test_voice_wins_over_age()
  BT.voices.t_race.swaps.fine = { tier = 1, "very well" }
  local hello = S("hello fine", { race = "t_race", strength = 1, age = "elder" })
  BT.voices.t_race.swaps.fine = nil
  assert(hello == "ahoy very well") end
function test_voice_has_its_own_aside()
  BT.voices.t_race.ages = { young = { closers = { "Arr, I be small!" } } }
  local own = S("look at that", { race = "t_race", strength = 1, age = "young", random = Harness.seq(20, 1) })
  local plain = S("look at that", { race = "t_race", strength = 1, age = "elder", random = Harness.seq(20, 2, 1) })
  BT.voices.t_race.ages = nil
  assert(own == "look at that! Arr, I be small!" and plain == "look at that. Back in my day, we walked.") end
