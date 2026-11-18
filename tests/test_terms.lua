local BT = Harness.load({ "Engine/Protect.lua", "Engine/Terms.lua", "Engine/Voices.lua", "Engine/Engine.lua", "Engine/Moods.lua" })
dofile("tests/testvoices.lua")(BT)
local function never() return 99 end
local S = function(t, o) o.random = o.random or never return BT.Engine.Speak(t, o) end

function test_abbreviations_survive_a_mood()
  assert(S("WTS mats", { mood = "drunk" }) == "WTS mats")
  assert(S("sm st os", { mood = "drunk" }) == "sm st os") end
function test_plural_of_a_term_is_kept() assert(S("healers", { mood = "drunk" }) == "healers") end
function test_letters_with_digits_are_kept() assert(S("5pm 10s is", { mood = "drunk" }) == "5pm 10s ish") end
function test_game_word_kept_only_in_game_talk()
  assert(S("lfm kill boss", { class = "t_class", strength = 1 }) == "lfm kill boss")
  assert(S("kill it", { class = "t_class", strength = 1 }) == "smite it") end
function test_rest_of_a_game_message_is_still_voiced()
  assert(S("hello lfm brd", { race = "t_race", strength = 1 }) == "ahoy lfm brd") end
function test_term_is_safe_from_sound_rules()
  assert(S("tanking going", { race = "t_race", strength = 2 }) == "tanking goin'") end
function test_exact_case_abbreviation()
  assert(S("HoTs", { mood = "drunk" }) == "HoTs" and S("hots", { mood = "drunk" }) == "hotsh") end
function test_foreign_word_is_not_a_term()
  assert(S("spårning kill", { class = "t_class", strength = 1 }) == "spårning smite") end
function test_jargon_message_takes_no_mood_or_age()
  assert(S("wts sword, pls", { mood = "drunk" }) == "wts sword, pls")
  assert(S("lfm brd, need tank", { age = "elder", random = function() return 1 end }) == "lfm brd, need tank")
  assert(S("hello lfm brd", { race = "t_race", strength = 1, mood = "angry" }) == "ahoy lfm brd") end
function test_kept_words()
  local o = function() return { class = "t_class", strength = 1, mood = "drunk", keep = { kill = true, moss = true } } end
  assert(S("kill moss is", o()) == "kill moss ish") end
function test_forced_game_talk_keeps_everyday_game_words_and_the_mood()
  assert(S("kill boss is", { class = "t_class", strength = 1, mood = "drunk", game = true }) == "kill boss ish") end
function test_possessive_and_link()
  local L = "|cff0070dd|Hitem:1:::|h[Tank Ring]|h|r"
  assert(S("tank's " .. L, { mood = "drunk" }) == "tank's " .. L) end
function test_verb_forms_of_a_term_are_kept()
  for _, word in ipairs({ "taunting", "taunted", "ganked", "specced", "pugging", "ganker", "gankers" }) do
    assert(S(word .. " is", { mood = "drunk" }) == word .. " is", word) end end
function test_everyday_lookalikes_are_not_terms()   -- summ-er, st-ing, def-er
  assert(S("summer sting", { mood = "drunk" }) == "shummer shting")
  assert(S("kill deferred", { class = "t_class", strength = 1 }) == "smite deferred") end
function test_ah_is_an_everyday_word_unless_shouted()
  assert(S("ah yes is", { mood = "drunk" }) == "ah yesh ish")
  assert(S("AH is", { mood = "drunk" }) == "AH is") end
function test_jargon_message_takes_no_catchphrase()
  assert(S("hello lfm brd", { race = "t_race", strength = 3, random = Harness.seq(1, 1, 1) }) == "ahoy lfm brd") end
