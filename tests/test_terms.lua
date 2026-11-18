local BT = Harness.load({ "Engine/Protect.lua", "Engine/Terms.lua", "Engine/Voices.lua", "Engine/Engine.lua", "Engine/Moods.lua" })
dofile("tests/testvoices.lua")(BT)
local function never() return 99 end
local S = function(t, o) o.random = o.random or never return BT.Engine.Speak(t, o) end

function test_abbreviations_survive_a_mood()
  assert(S("WTS mats", { mood = "drunk" }) == "WTS mats")
  assert(S("sm st os", { mood = "drunk" }) == "sm st os") end
function test_plural_of_a_term_is_kept() assert(S("healers", { mood = "drunk" }) == "healers") end
function test_letters_with_digits_are_kept() assert(S("lf1m 10s is", { mood = "drunk" }) == "lf1m 10s ish") end
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
function test_terms_count_as_words()   -- an angry "wts" still gets its "!"
  assert(S("wts", { mood = "angry" }) == "wts!") end
function test_possessive_and_link()
  local L = "|cff0070dd|Hitem:1:::|h[Tank Ring]|h|r"
  assert(S("tank's " .. L, { mood = "drunk" }) == "tank'sh " .. L) end
