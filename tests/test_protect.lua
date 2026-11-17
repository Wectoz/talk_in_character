local BT = Harness.load({ "Engine/Protect.lua" })
local P = BT.Protect
local LINK = "|cff0070dd|Hitem:1:::|h[Sword of Hello]|h|r"

function test_link_is_shielded_and_restored()
  local s, parts = P.Shield("look at " .. LINK .. "!", nil)
  assert(not s:find("Sword", 1, true))
  assert(P.Restore(s, parts) == "look at " .. LINK .. "!")
end
function test_only_a_link() local s, p = P.Shield(LINK) assert(P.Restore(s, p) == LINK) end
function test_raid_icon_and_url()
  local s = P.Shield("kill {skull} see https://example.com/hello now")
  assert(not s:find("skull", 1, true) and not s:find("example", 1, true))
  assert(s:find("kill", 1, true) and s:find("now", 1, true))
end
function test_names_whole_word_any_case()
  local s, p = P.Shield("thrall and Thrall, not thralls", { "Thrall" })
  assert(s:find("thralls", 1, true))
  assert(select(2, s:gsub("\1%d+\2", "")) == 2)
  assert(P.Restore(s, p) == "thrall and Thrall, not thralls")
end
function test_texture_escape() local s = P.Shield("hi |TInterface\\Icons\\x:16|t there") assert(not s:find("Icons", 1, true)) end
function test_existing_control_bytes_do_not_break()
  local t = "a\1b\2c" local s, p = P.Shield(t) assert(P.Restore(s, p) == t)
end
