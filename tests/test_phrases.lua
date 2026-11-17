local BT = Harness.load({ "Engine/Protect.lua", "Engine/Voices.lua", "Engine/Engine.lua", "Engine/Moods.lua", "Engine/Phrases.lua" })
dofile("tests/testvoices.lua")(BT)
local P = BT.Phrases

function test_no_voice_nil()        assert(P.Pick("hello", { strength = 2 }, nil) == nil) end
function test_unknown_kind_nil()    assert(P.Pick("dance", { race = "p_race", strength = 2 }, nil) == nil) end
function test_token_line_excluded_without_target()
  for i = 1, 30 do assert(not P.Pick("hello", { race = "p_race", strength = 2 }, nil):find("{", 1, true)) end end
function test_token_line_excluded_when_name_missing()
  for i = 1, 30 do assert(not P.Pick("hello", { race = "p_race", strength = 2 }, { race = "Orc" }):find("{", 1, true)) end end
function test_token_filled()
  local seen for i = 1, 60 do local l = P.Pick("hello", { race = "p_race", strength = 2 }, { name = "Thrall" })
    if l == "Hi Thrall." then seen = true end assert(not l:find("{", 1, true)) end assert(seen) end
function test_class_lines_join_pool()
  local seen for i = 1, 60 do if P.Pick("hello", { race = "p_race", class = "p_class", strength = 2 }) == "Hail." then seen = true end end assert(seen) end
function test_class_only()          assert(P.Pick("hello", { class = "p_class", strength = 2 }):find("^Hail")) end
function test_no_immediate_repeat()
  local last for i = 1, 40 do local l = P.Pick("hello", { race = "p_race", strength = 2 }) assert(l ~= last) last = l end end
function test_mood_applies_but_not_to_name()
  for i = 1, 30 do
    local l = P.Pick("hello", { race = "p_race", strength = 2, mood = "drunk" }, { name = "Sass" })
    assert(not l:find("Shassh", 1, true) and not l:find("{", 1, true))
  end end
function test_mood_applies_to_line()
  local seen for i = 1, 30 do if P.Pick("bye", { race = "p_race", strength = 2, mood = "scared" }):find("%.%.%.$") then seen = true end end assert(seen) end
function test_name_with_percent_is_safe()
  local seen for i = 1, 60 do if P.Pick("hello", { race = "p_race", strength = 2 }, { name = "A%1b" }) == "Hi A%1b." then seen = true end end assert(seen) end
function test_slot_dead_zone()      assert(P.SlotAt(0, 0) == nil and P.SlotAt(20, 20) == nil) end
function test_slot_up()             assert(P.SlotAt(0, 60) == 1) end
function test_slot_clockwise()
  assert(P.SlotAt(50, 50) == 2 and P.SlotAt(60, 0) == 3 and P.SlotAt(50, -50) == 4 and P.SlotAt(0, -60) == 5)
  assert(P.SlotAt(-50, -50) == 6 and P.SlotAt(-60, 0) == 7 and P.SlotAt(-50, 50) == 8) end
function test_slot_edge_of_dead_zone() assert(P.SlotAt(0, 39) == nil and P.SlotAt(0, 40) == 1) end
function test_slot_far_flick()      assert(P.SlotAt(0, 900) == 1) end
