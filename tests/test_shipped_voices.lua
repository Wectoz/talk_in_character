-- Every shipped voice loads (so it validates) and meets the quality bar.
local files = { "Engine/Protect.lua", "Engine/Voices.lua", "Engine/Engine.lua" }
for path in io.popen("find TalkInCharacter/Voices -name '*.lua' | sort"):lines() do
  files[#files + 1] = path:gsub("^TalkInCharacter/", "")
end
local BT = Harness.load(files)

local REQUIRED = { "gnome", "mage", "bloodsail",
  "human", "dwarf", "nightelf", "orc", "troll", "tauren", "forsaken",
  "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "warlock", "druid",
  "goblin", "defias", "scarlet", "ventureco", "murloc", "kobold", "ogre", "gnoll",
  "darkiron", "argentdawn", "cenarion", "timbermaw", "centaur", "naga", "zandalar" }

local function each(fn) for id, voice in pairs(BT.voices) do fn(id, voice) end end
local function count(t, pred) local n = 0 for k, v in pairs(t) do if not pred or pred(k, v) then n = n + 1 end end return n end

function test_required_voices_exist()
  local missing = {}
  for _, id in ipairs(REQUIRED) do if not BT.voices[id] then missing[#missing + 1] = id end end
  assert(#missing == 0, "missing voices: " .. table.concat(missing, ", "))
end
function test_swap_counts()
  each(function(id, v)
    local total, light = count(v.swaps), count(v.swaps, function(_, s) return s.tier == 1 end)
    local needTotal, needLight = 40, 12
    if v.kind == "class" then needTotal, needLight = 20, 8 end
    assert(total >= needTotal, id .. " has " .. total .. " swaps, needs " .. needTotal)
    assert(light >= needLight, id .. " has " .. light .. " light swaps, needs " .. needLight)
  end)
end
function test_openers_and_closers()
  each(function(id, v) assert(#v.openers >= 4 and #v.closers >= 4, id .. " needs 4 openers and 4 closers") end)
end
function test_phrase_counts_length_and_targets()
  each(function(id, v)
    local kindsWithTarget = 0
    for _, kind in ipairs(BT.KINDS) do
      local list, hasTarget = v.phrases[kind], false
      assert(#list >= 5, id .. "." .. kind .. " needs 5 lines")
      for _, line in ipairs(list) do
        assert(#line <= 120, id .. "." .. kind .. " line over 120 bytes: " .. line)
        if line:find("{target}", 1, true) then hasTarget = true end
      end
      if hasTarget then kindsWithTarget = kindsWithTarget + 1 end
    end
    assert(kindsWithTarget >= 2, id .. " needs {target} lines in at least 2 kinds")
  end)
end
function test_angry_closers()
  each(function(id, v)
    assert(v.moods and v.moods.angry and v.moods.angry.closers and #v.moods.angry.closers >= 3, id .. " needs 3 angry closers")
  end)
end
function test_swaps_do_not_feed_themselves()
  each(function(id, v)
    for key, swap in pairs(v.swaps) do
      for _, value in ipairs(swap) do
        local lower = value:lower()
        assert(lower ~= key, id .. ": swap '" .. key .. "' maps to itself")
        assert(not v.swaps[lower], id .. ": swap value '" .. value .. "' is also a key")
      end
    end
  end)
end
function test_class_voices_leave_common_words_to_races()
  each(function(id, v)
    if v.kind == "class" then
      for _, word in ipairs({ "hello", "you", "yes", "my" }) do assert(not v.swaps[word], id .. " must not swap '" .. word .. "'") end
    end
  end)
end
function test_gnome_mage_sample()
  local input = "hello, can you help me kill this boss?"
  local out = BT.Engine.Speak(input, { race = "gnome", class = "mage", strength = 3 })
  assert(out ~= input and #out <= 255)
end

function test_ing_rule_spares_short_nouns()
  each(function(id, v)
    local opts = { strength = 3, random = function() return 99 end }
    opts[v.kind == "class" and "class" or "race"] = id
    local out = BT.Engine.Speak("the king will bring a ring and a thing", opts)
    for _, bad in ipairs({ "kin'", "brin'", "rin'", "thin'" }) do
      assert(not out:find(bad, 1, true), id .. " turns a short noun into " .. bad .. ": " .. out)
    end
  end) end
function test_no_is_only_swapped_at_heavy_strength()
  each(function(id, v) assert(not v.swaps.no or v.swaps.no.tier == 3, id .. " swaps 'no' below heavy strength") end) end
