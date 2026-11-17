local BT = Harness.load({ "Engine/Protect.lua", "Engine/Voices.lua" })
local function good() local p = {} for _, k in ipairs(BT.KINDS) do p[k] = { "a", "b", "c" } end
  return { id = "x", name = "X", kind = "race", icon = "i", swaps = {}, sounds = {}, openers = {}, closers = {}, phrases = p } end
function test_valid_voice_passes() assert(BT.ValidateVoice(good())) end
function test_missing_kind_of_phrase_fails() local v = good() v.phrases.help = nil assert(not BT.ValidateVoice(v)) end
function test_fewer_than_three_lines_fails() local v = good() v.phrases.hello = { "a", "b" } assert(not BT.ValidateVoice(v)) end
function test_token_line_needs_plain_sibling() local v = good()
  v.phrases.hello = { "hi {target}", "yo {target}", "oi {targetRace}" } assert(not BT.ValidateVoice(v)) end
function test_unknown_token_fails() local v = good() v.phrases.hello[1] = "hi {nobody}" assert(not BT.ValidateVoice(v)) end
function test_line_over_255_fails() local v = good() v.phrases.bye[1] = string.rep("a", 256) assert(not BT.ValidateVoice(v)) end
function test_bad_swap_key_fails() local v = good() v.swaps["Two Words"] = { tier = 1, "x" } assert(not BT.ValidateVoice(v)) end
function test_swap_tier_required() local v = good() v.swaps.hi = { "x" } assert(not BT.ValidateVoice(v)) end
function test_swap_needs_an_alternative() local v = good() v.swaps.hi = { tier = 1 } assert(not BT.ValidateVoice(v)) end
function test_sound_rule_tier_one_fails() local v = good() v.sounds[1] = { tier = 1, pattern = "a", repl = "b" } assert(not BT.ValidateVoice(v)) end
function test_bad_kind_fails() local v = good() v.kind = "pet" assert(not BT.ValidateVoice(v)) end
function test_register_rejects_duplicate_id() BT.RegisterVoice(good()) assert(not pcall(BT.RegisterVoice, good())) end
function test_register_rejects_invalid() local v = good() v.id = "y" v.kind = "pet" assert(not pcall(BT.RegisterVoice, v)) assert(BT.voices.y == nil) end
function test_voices_of_kind_sorted()
  local b = good() b.id = "b2" b.name = "Beta" BT.RegisterVoice(b)
  local a = good() a.id = "a2" a.name = "Alpha" BT.RegisterVoice(a)
  local list = BT.VoicesOfKind("race")
  assert(list[1].id == "a2" and list[2].id == "b2" and #BT.VoicesOfKind("class") == 0)
end
