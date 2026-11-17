# Bronzetongue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A WoW: Forever addon that rewrites outgoing chat in a chosen race or faction, class and mood voice, with a phrase wheel, live preview and options panel, ready for CurseForge.

**Architecture:** A pure-Lua engine (no game calls) turns text into voiced text from data-only voice files; it is unit-tested outside the game with `lua5.1`. Thin game-facing files (send hook, preview, wheel, options) call the engine. Voices are one file each so they can be written in parallel.

**Tech Stack:** Lua 5.1, WoW: Forever client API (interface 16001), `lua5.1` on this machine for tests. No libraries (no Ace).

**Spec:** `docs/superpowers/specs/2026-11-17-bronzetongue-design.md`. Read it before any task.

## Global Constraints

- Forever only: `## Interface: 16001`. Confirm in game with `select(4, GetBuildInfo())` before release. API reference is the `forever` branch of `Gethe/wow-ui-source`; check any game API there before using it.
- Never replace, wrap or hook-replace `SendChatMessage`, `C_ChatInfo.SendChatMessage` or any send function. Outgoing text changes only by `SetText` on the edit box inside the `ChatFrame.OnEditBoxPreSendText` EventRegistry callback.
- Never write the edit box's `chatType` attribute or any other secure attribute.
- Do nothing when `C_ChatInfo.InChatMessagingLockdown()` is true (guard existence, `pcall`).
- A message is never lost: every game-facing entry point runs the engine under `pcall`; on error the text stays as typed and one chat line reports it (once per session).
- Output over 255 bytes is never sent: fall back to lighter strength, then to the typed text.
- Never alter `|`-escape sequences (links, colours, textures), `{raid icon}` tags, URLs, slash commands, or readable names of target/party/raid members.
- Battle.net whispers are never rewritten.
- Depend on no chat addon. Never move or restyle another addon's frames.
- Unit names may be secret strings in combat/instances: test with `issecretvalue` when that global exists, and `pcall` any use; fall back to no target.
- No text or code from Yarrr or from other accent addons. Real in-game catchphrases and vocabulary are fine; sentences are written fresh.
- English voices only. No libraries. No minimap button.
- Colours: surfaces `#111111`, `#191919`, `#242424`; bronze edge `#80632c`; gold emphasis `#c9ad6a`; text `#eeeecc`.
- Addon namespace: every addon file starts `local ADDON, BT = ...`. Nothing global except `BronzetongueCharDB`, `BronzetongueWheel_OnKey`, `BINDING_*` strings and `SLASH_*`.

## Review Focus

1. **Non-ASCII text** ("hej på dig", "åäö", emoji bytes). Expected: words containing bytes above 127 pass through byte-for-byte; no rule splits a UTF-8 sequence. Test in Task 2.
2. **Links touching words** (`look at |cff0070dd|Hitem:1:::|h[Sword]|h|r!` and a message that is only a link). Expected: link bytes identical, surrounding words voiced. Test in Task 1 and Task 2.
3. **Chat shorthand and emoticons** (`gg`, `lol`, `:)`, `<3`, `ty`, `123`, `!!!`, whitespace-only). Expected: no error, emoticons and numbers untouched, whitespace-only text returned as is. Test in Task 2.
4. **A saved voice id that no longer exists** (old settings after a voice is renamed). Expected: treated as "None", no error, options show None. Test in Task 2 and Task 6.
5. **Rewrite that grows past 255 bytes** (a 250-byte message at heavy strength). Expected: lighter strength tried, else the typed text returned. Test in Task 2.

---

## File Structure

```
Bronzetongue/                 the addon folder (this is what ships)
  Bronzetongue.toc
  Bindings.xml                wheel key binding
  Core.lua                    namespace setup, saved settings, defaults, slash commands
  Engine/Protect.lua          shield and restore text that must not change
  Engine/Voices.lua           voice registry and validator
  Engine/Engine.lua           Speak: swaps, sound rules, interjections, strength, length fallback
  Engine/Moods.lua            angry, drunk, scared rules
  Engine/Phrases.lua          pick a wheel line; wheel slot geometry
  Voices/Races/<id>.lua       one voice per file
  Voices/Factions/<id>.lua
  Voices/Classes/<id>.lua
  Send.lua                    pre-send hook, lockdown, Autocorrect Forever interop
  Preview.lua                 live preview line
  Wheel.lua                   phrase wheel frame
  Options.lua                 settings panel
  Media/icon.tga              64x64
tests/
  harness.lua                 loads addon files outside the game
  run.lua                     runs every tests/test_*.lua
  test_*.lua
tools/
  sync.sh                     copy Bronzetongue/ into the Forever AddOns folder
  icon.svg, make_icon.sh      icon source and render
LICENSE  README.md  curseforge/description.md  curseforge/icon-400.png
```

TOC load order: `Core.lua`, `Engine/Protect.lua`, `Engine/Voices.lua`, `Engine/Engine.lua`, `Engine/Moods.lua`, `Engine/Phrases.lua`, all voice files, `Send.lua`, `Preview.lua`, `Wheel.lua`, `Options.lua`.

**Tests:** `lua5.1 tests/run.lua` prints `OK <n> tests` and exits 0, or the first failure and exits 1. Tests are plain functions using `assert`. `tests/harness.lua` exposes `Harness.load(files) -> BT`, which runs each file with `loadfile(path)("Bronzetongue", BT)` on a fresh `BT = {}`, and `Harness.seq(...)`, which returns a fake random function `random(n)` yielding the given numbers in order (then 1 forever).

---

### Task 1: Scaffold, test harness, Protect

**Files:**
- Create: `tests/harness.lua`, `tests/run.lua`, `tests/test_protect.lua`, `Bronzetongue/Engine/Protect.lua`, `Bronzetongue/Core.lua` (namespace line only for now)

**Interfaces:**
- Produces: `BT.Protect.Shield(text, names) -> shielded, parts` and `BT.Protect.Restore(shielded, parts) -> text`. `names` is a list of strings or nil. Each protected span is replaced by `"\1" .. index .. "\2"` (bytes 1 and 2), so word rules never match inside one. `parts[index]` is the original span.

- [ ] **Step 1: Write the failing tests** in `tests/test_protect.lua`

```lua
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
```

- [ ] **Step 2: Write `tests/harness.lua` and `tests/run.lua`** as described under File Structure. Run `lua5.1 tests/run.lua`. Expected: FAIL (Protect.lua missing).

- [ ] **Step 3: Implement `Shield` and `Restore`** in `Bronzetongue/Engine/Protect.lua`. Order: existing `\1`/`\2` bytes, `|c...|r` coloured links and bare `|H...|h...|h`, `|T...|t`, `|A...|a`, `|K...|k`, any remaining `|x` escape pair, `{...}` tags, URLs (`%a+://%S+` and `www%.%S+`), then names (whole word, case-insensitive, names with pattern characters escaped).

- [ ] **Step 4: Run** `lua5.1 tests/run.lua`. Expected: `OK 6 tests`.

- [ ] **Step 5: Commit** `git add -A && git commit -m "Add test harness and Protect"`

---

### Task 2: Voice format, validator, engine, three example voices

**Files:**
- Create: `Bronzetongue/Engine/Voices.lua`, `Bronzetongue/Engine/Engine.lua`, `Bronzetongue/Voices/Races/gnome.lua`, `Bronzetongue/Voices/Classes/mage.lua`, `Bronzetongue/Voices/Factions/bloodsail.lua`, `tests/test_voices.lua`, `tests/test_engine.lua`

**Interfaces:**
- Consumes: `BT.Protect` (Task 1).
- Produces:
  - `BT.RegisterVoice(voice)`; `BT.voices[id]`; `BT.VoicesOfKind(kind) -> list sorted by name`; `BT.ValidateVoice(voice) -> true | false, message`.
  - `BT.KINDS = { "hello", "follow", "wait", "cheer", "battle", "bye", "help", "thanks" }` (wheel order, clockwise from top).
  - `BT.Engine.Speak(text, opts) -> string`. `opts = { race = id|nil, class = id|nil, mood = "calm"|"angry"|"drunk"|"scared", strength = 1|2|3, names = list|nil, random = function(n)|nil }`. `race` holds a race or faction voice id. Unknown ids count as nil. `random` defaults to `math.random`. Mood is applied by Task 3; until then mood is ignored.

**Voice file format (fixed; every voice file is exactly one call):**

```lua
local ADDON, BT = ...
BT.RegisterVoice({
  id = "gnome", name = "Gnome", kind = "race",          -- kind: "race" | "faction" | "class"
  icon = "Interface\\Icons\\Achievement_Character_Gnome_Male",
  swaps = {                    -- key: one lowercase word (letters and ' only)
    hello = { tier = 1, "greetings", "salutations" },   -- tier 1 light, 2 medium, 3 heavy
    kill  = { tier = 2, "eliminate" },
  },
  sounds = {                   -- Lua patterns, applied per word, tier 2 or 3 only
    { tier = 3, pattern = "ing$", repl = "in'" },
  },
  openers = { "By my calculations," },                  -- prepended sometimes
  closers = { "Fascinating!" },                         -- appended sometimes
  moods = { angry = { closers = { "This is unscientific!" } } },   -- optional
  phrases = { hello = { "..." , "...", "..." }, follow = {...}, wait = {...}, cheer = {...},
              battle = {...}, bye = {...}, help = {...}, thanks = {...} },
})
```

**Engine rules (the decisions):**
- Shield with `BT.Protect`, apply race voice, then class voice, restore.
- A word is a run of ASCII letters and apostrophes. A run touching any byte above 127 is not a word and is left alone.
- Swap: lowercase lookup, only if `swap.tier <= strength`; pick an alternative with `random(#swap)`. Case: all-caps word (2+ letters) gives all-caps output; capitalised word gives capitalised output; else as written in the voice file.
- A word produced by a swap is not passed to sound rules and is not swapped again by the class layer.
- Sound rules apply to unswapped words of 4+ letters, when `rule.tier <= strength`.
- Interjections: per voice, at strength 2 chance 10%, at strength 3 chance 35% (`random(100) <= chance`); one roll decides opener or closer (`random(2)`), then which. Never on text under 3 words. Strength 1: none.
- Text starting with `/`, empty, or whitespace-only is returned unchanged.
- If the result exceeds 255 bytes, retry at `strength - 1` down to 1, then return the original text.

- [ ] **Step 1: Write failing tests** `tests/test_voices.lua`

```lua
local BT = Harness.load({ "Engine/Protect.lua", "Engine/Voices.lua" })
local function good() local p = {} for _, k in ipairs(BT.KINDS) do p[k] = { "a", "b", "c" } end
  return { id = "x", name = "X", kind = "race", icon = "i", swaps = {}, sounds = {}, openers = {}, closers = {}, phrases = p } end
function test_valid_voice_passes() assert(BT.ValidateVoice(good())) end
function test_missing_kind_of_phrase_fails() local v = good() v.phrases.help = nil assert(not BT.ValidateVoice(v)) end
function test_fewer_than_three_lines_fails() local v = good() v.phrases.hello = { "a", "b" } assert(not BT.ValidateVoice(v)) end
function test_token_line_needs_plain_sibling() local v = good()
  v.phrases.hello = { "hi {target}", "yo {target}", "oi {targetRace}" } assert(not BT.ValidateVoice(v)) end
function test_line_over_255_fails() local v = good() v.phrases.bye[1] = string.rep("a", 256) assert(not BT.ValidateVoice(v)) end
function test_bad_swap_key_fails() local v = good() v.swaps["Two Words"] = { tier = 1, "x" } assert(not BT.ValidateVoice(v)) end
function test_swap_tier_required() local v = good() v.swaps.hi = { "x" } assert(not BT.ValidateVoice(v)) end
function test_bad_kind_fails() local v = good() v.kind = "pet" assert(not BT.ValidateVoice(v)) end
function test_register_rejects_duplicate_id() BT.RegisterVoice(good()) assert(not pcall(BT.RegisterVoice, good())) end
function test_voices_of_kind_sorted() assert(BT.VoicesOfKind("race")[1].id == "x") end
```

- [ ] **Step 2: Write failing tests** `tests/test_engine.lua` using two inline test voices (not the shipped ones, so content edits never break engine tests): race `t_race` with swaps `hello={tier=1,"ahoy"}`, `you={tier=2,"ye"}`, `my={tier=1,"me"}`, sounds `{tier=2, pattern="ing$", repl="in'"}`, openers `{"Arr,"}`, closers `{"Yarr!"}`; class `t_class` with swaps `kill={tier=1,"smite"}`, `hello={tier=1,"hail"}`.

```lua
local S = function(t, o) o.random = o.random or Harness.seq(1, 99, 99, 99) return BT.Engine.Speak(t, o) end
function test_swap_light()          assert(S("hello there", { race = "t_race", strength = 1 }) == "ahoy there") end
function test_tier_gates_swap()     assert(S("hello you", { race = "t_race", strength = 1 }) == "ahoy you") end
function test_medium_adds_tier2()   assert(S("hello you", { race = "t_race", strength = 2 }) == "ahoy ye") end
function test_case_capitalised()    assert(S("Hello", { race = "t_race", strength = 1 }) == "Ahoy") end
function test_case_shouted()        assert(S("HELLO", { race = "t_race", strength = 1 }) == "AHOY") end
function test_whole_word_only()     assert(S("hellos mymy", { race = "t_race", strength = 3 }) == "hellos mymy") end
function test_sound_rule()          assert(S("going fishing", { race = "t_race", strength = 2 }) == "goin' fishin'") end
function test_sound_rule_off_light()assert(S("going", { race = "t_race", strength = 1 }) == "going") end
function test_class_stacks()        assert(S("hello kill", { race = "t_race", class = "t_class", strength = 1 }) == "ahoy smite") end
function test_class_does_not_reswap_race_output()
  assert(S("hello", { race = "t_race", class = "t_class", strength = 1 }) == "ahoy") end
function test_class_alone()         assert(S("hello", { class = "t_class", strength = 1 }) == "hail") end
function test_no_voice_is_identity()assert(S("hello you", { strength = 3 }) == "hello you") end
function test_unknown_voice_id_is_none() assert(S("hello", { race = "gone", class = "gone", strength = 3 }) == "hello") end
function test_slash_command_untouched() assert(S("/who hello", { race = "t_race", strength = 3 }) == "/who hello") end
function test_empty_and_whitespace() assert(S("", { race = "t_race", strength = 3 }) == "" and S("   ", { race = "t_race", strength = 3 }) == "   ") end
function test_emoticons_numbers()   assert(S("gg :) <3 123 !!!", { race = "t_race", strength = 3 }) == "gg :) <3 123 !!!") end
function test_non_ascii_untouched() assert(S("hej på dig åäö hello", { race = "t_race", strength = 1 }) == "hej på dig åäö ahoy") end
function test_non_ascii_word_not_sound_ruled() assert(S("spårning", { race = "t_race", strength = 3 }) == "spårning") end
function test_link_survives() local L = "|cff0070dd|Hitem:1:::|h[Hello Ring]|h|r"
  assert(S("hello " .. L, { race = "t_race", strength = 1 }) == "ahoy " .. L) end
function test_names_survive()       assert(S("hello My", { race = "t_race", strength = 1, names = { "My" } }) == "ahoy My") end
function test_opener_heavy()        -- rolls: swap pick, chance 1 (<=35), opener (1), which (1)
  assert(S("hello there friend", { race = "t_race", strength = 3, random = Harness.seq(1, 1, 1, 1) }) == "Arr, ahoy there friend") end
function test_closer_heavy()        assert(S("hello there friend", { race = "t_race", strength = 3, random = Harness.seq(1, 1, 2, 1) }) == "ahoy there friend Yarr!") end
function test_no_interjection_short() assert(S("hello there", { race = "t_race", strength = 3, random = Harness.seq(1, 1, 1, 1) }) == "ahoy there") end
function test_no_interjection_light() assert(S("hello there friend", { race = "t_race", strength = 1, random = Harness.seq(1, 1, 1, 1) }) == "ahoy there friend") end
function test_over_255_falls_back_lighter()
  local t = string.rep("going ", 42) .. "ok"            -- 254 bytes; strength 2 would add nothing but
  assert(#S(t, { race = "t_race", strength = 3, random = Harness.seq(1, 1, 1) }) <= 255) end
function test_over_255_returns_original()
  -- t_long is a third inline test voice: race, swap a={tier=1,"aaaaaaaaaa"}
  local t = string.rep("a ", 120) assert(S(t, { race = "t_long", strength = 1 }) == t) end
```

If a `Harness.seq` roll order in the two interjection tests does not match the natural order of the implementation, keep the implementation's order and adjust the sequence in the test; the asserted strings stay.

- [ ] **Step 3: Run** `lua5.1 tests/run.lua`. Expected: FAIL.
- [ ] **Step 4: Implement `Engine/Voices.lua`** (`RegisterVoice` errors on invalid voice or duplicate id, with the validator's message).
- [ ] **Step 5: Implement `Engine/Engine.lua`** per the rules above.
- [ ] **Step 6: Write the three example voices** to the quality bar in Task 5 (they are the examples other voice writers copy). Gnome: clever, technical, precise. Mage: scholarly, arcane, a little smug. Together a gnome mage "will sound very smart" (owner's words). Bloodsail: pirate, written fresh.
- [ ] **Step 7: Add `tests/test_shipped_voices.lua`**: load every file under `Bronzetongue/Voices/` (list with `io.popen("find Bronzetongue/Voices -name '*.lua' | sort")`) through the harness; loading must not error (so every voice validates); assert for each voice the minimums in Task 5; assert `Speak("hello, can you help me kill this boss?", {race="gnome", class="mage", strength=3})` differs from the input and is at most 255 bytes.
- [ ] **Step 8: Run** `lua5.1 tests/run.lua`. Expected: all pass.
- [ ] **Step 9: Commit** `git commit -am "Add voice format, engine and example voices"` (after `git add -A`).

---

### Task 3: Moods

**Files:**
- Create: `Bronzetongue/Engine/Moods.lua`, `tests/test_moods.lua`
- Modify: `Bronzetongue/Engine/Engine.lua` (call moods after the class layer, before restore; include in the 255 fallback: on overflow at strength 1, retry once with mood `calm`, then return the original)

**Interfaces:**
- Produces: `BT.Moods.Apply(shieldedText, mood, random, voices) -> text`. `voices` is the list of active voice tables (for optional `voice.moods[mood].openers/closers`). `calm` or unknown mood returns the text unchanged. Works on shielded text; never touches `\1n\2` placeholders or non-ASCII runs.

**Rules:**
- **angry:** a final `.` becomes `!`; text with no final punctuation gets `!`; each word of 4+ letters is upper-cased with chance 15%; with chance 30% append one mood closer from the active voices, or from the built-in list `{ "Grr!", "Enough!", "Bah!" }` when none is defined.
- **drunk:** every `s` not followed by `h` becomes `sh` (`S` becomes `Sh`); after each word, chance 8% to insert ` *hic*`; never two in a row.
- **scared:** each word of 3+ letters, chance 20%: stutter the first letter (`hello` becomes `h-hello`, case kept on both); a final `.` or no final punctuation becomes `...`.

- [ ] **Step 1: Write failing tests** `tests/test_moods.lua`

```lua
local A = function(t, m, ...) return BT.Moods.Apply(t, m, Harness.seq(...), {}) end
function test_calm_identity()        assert(A("hello there.", "calm") == "hello there.") end
function test_unknown_mood_identity()assert(A("hello", "sleepy") == "hello") end
function test_angry_punctuation()    assert(A("go away.", "angry", 99, 99, 99) == "go away!") end
function test_angry_adds_bang()      assert(A("go away", "angry", 99, 99, 99) == "go away!") end
function test_angry_keeps_question() assert(A("why?", "angry", 99, 99) == "why?") end
function test_angry_shouts_word()    assert(A("go away now", "angry", 1, 99, 99) == "go AWAY now!") end
function test_angry_builtin_closer() assert(A("go away", "angry", 99, 1, 1) == "go away! Grr!") end
function test_drunk_slur()           assert(A("yes sir", "drunk", 99, 99) == "yesh shir") end
function test_drunk_keeps_sh()       assert(A("ship", "drunk", 99) == "ship") end
function test_drunk_hic()            assert(A("one two", "drunk", 1, 99) == "one *hic* two") end
function test_scared_stutter()       assert(A("Hello you", "scared", 1, 99) == "H-Hello you...") end
function test_scared_dots()          assert(A("run.", "scared", 99) == "run...") end
function test_placeholder_untouched()assert(A("see \0011\002 sir", "drunk", 99, 99, 99) == "shee \0011\002 shir") end
function test_non_ascii_untouched()  assert(A("påse", "drunk", 99) == "påse") end
function test_voice_mood_closer()
  local v = { moods = { angry = { closers = { "Unscientific!" } } } }
  assert(BT.Moods.Apply("go away", "angry", Harness.seq(99, 1, 1), { v }) == "go away! Unscientific!") end
```

Add to `tests/test_engine.lua`: `test_mood_applied_in_speak` (`S("yes", {race="t_race", strength=1, mood="drunk"}) == "yesh"`) and `test_mood_dropped_on_overflow` (a 254-byte text of `s` words with mood `drunk` returns at most 255 bytes).

Same note as Task 2: if the natural roll order differs, change the `Harness.seq` numbers, not the asserted strings.

- [ ] **Step 2: Run** tests. Expected: FAIL.
- [ ] **Step 3: Implement** `Engine/Moods.lua` and the Engine change.
- [ ] **Step 4: Run** tests. Expected: all pass.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Add moods"`

---

### Task 4: Phrase picking and wheel geometry

**Files:**
- Create: `Bronzetongue/Engine/Phrases.lua`, `tests/test_phrases.lua`

**Interfaces:**
- Consumes: `BT.voices`, `BT.KINDS`, `BT.Moods.Apply`.
- Produces:
  - `BT.Phrases.Pick(kind, opts, target) -> line | nil`. `opts` as for `Speak`. `target = { name = string|nil, race = string|nil, class = string|nil } | nil`. Pool = that kind's lines from the race voice plus the class voice. Lines whose tokens cannot all be filled from `target` are excluded. Never returns the same line as the previous call for that kind when the pool has 2+ lines. Tokens `{target}`, `{targetRace}`, `{targetClass}` are filled, then mood applied (target text shielded so moods do not alter the name). Returns nil when no voice is chosen. Result is at most 255 bytes (re-pick up to 5 times, else nil).
  - `BT.Phrases.SlotAt(dx, dy) -> index | nil`. `dx`, `dy` in pixels from the ring centre, y up. Distance under 40 gives nil (dead zone); otherwise the slot (1..8) whose 45-degree sector contains the angle, slot 1 centred straight up, increasing clockwise. Any distance of 40 or more counts (no outer limit), so a fast flick still picks.

- [ ] **Step 1: Write failing tests** `tests/test_phrases.lua` (inline voices `p_race` with `hello = { "Hi.", "Hi {target}.", "Yo." }` and `p_class` with `hello = { "Hail." }`, other kinds three plain lines each)

```lua
local P = BT.Phrases
function test_no_voice_nil()        assert(P.Pick("hello", { strength = 2 }, nil) == nil) end
function test_token_line_excluded_without_target()
  for i = 1, 30 do assert(not P.Pick("hello", { race = "p_race", strength = 2 }, nil):find("{", 1, true)) end end
function test_token_filled()
  local seen for i = 1, 60 do local l = P.Pick("hello", { race = "p_race", strength = 2 }, { name = "Thrall" })
    if l == "Hi Thrall." then seen = true end assert(not l:find("{", 1, true)) end assert(seen) end
function test_class_lines_join_pool()
  local seen for i = 1, 60 do if P.Pick("hello", { race = "p_race", class = "p_class", strength = 2 }) == "Hail." then seen = true end end assert(seen) end
function test_no_immediate_repeat()
  local last for i = 1, 40 do local l = P.Pick("hello", { race = "p_race", strength = 2 }) assert(l ~= last) last = l end end
function test_mood_applies_but_not_to_name()
  local l = P.Pick("hello", { race = "p_race", strength = 2, mood = "drunk", random = Harness.seq(2, 99, 99, 99) }, { name = "Sass" })
  assert(not l:find("Shassh", 1, true)) end
function test_slot_dead_zone()      assert(P.SlotAt(0, 0) == nil and P.SlotAt(20, 20) == nil) end
function test_slot_up()             assert(P.SlotAt(0, 60) == 1) end
function test_slot_clockwise()      assert(P.SlotAt(50, 50) == 2 and P.SlotAt(60, 0) == 3 and P.SlotAt(0, -60) == 5 and P.SlotAt(-60, 0) == 7 and P.SlotAt(-50, 50) == 8) end
function test_slot_far_flick()      assert(P.SlotAt(0, 900) == 1) end
```

- [ ] **Step 2: Run** tests. Expected: FAIL.
- [ ] **Step 3: Implement** `Engine/Phrases.lua` (`math.atan2` exists in Lua 5.1 and in the game).
- [ ] **Step 4: Run** tests. Expected: all pass.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Add phrase picking and wheel geometry"`

---

### Task 5: Write the voices (parallel batches)

**Files:**
- Create: one file per voice under `Bronzetongue/Voices/Races/`, `Factions/`, `Classes/` (ids below)
- Test: `tests/test_shipped_voices.lua` (from Task 2) is the gate.

**Interfaces:**
- Consumes: the voice file format (Task 2) and the three example voices.
- Produces: voice ids used by options and "Match my character".

**Batches. Run them as parallel agents; each agent gets this task text, the format block from Task 2, and the three example voice files.**

| Batch | Voices (id: display name) |
|---|---|
| A races | `human`: Human, `dwarf`: Dwarf, `nightelf`: Night Elf |
| B races | `orc`: Orc, `troll`: Troll, `tauren`: Tauren, `forsaken`: Forsaken |
| C classes | `warrior`: Warrior, `paladin`: Paladin, `hunter`: Hunter, `rogue`: Rogue |
| D classes | `priest`: Priest, `shaman`: Shaman, `warlock`: Warlock, `druid`: Druid |
| E factions | `goblin`: Goblin (Steamwheedle), `defias`: Defias Brotherhood, `scarlet`: Scarlet Crusade, `ventureco`: Venture Co. |
| F creatures | `murloc`: Murloc, `kobold`: Kobold, `ogre`: Ogre, `gnoll`: Gnoll |
| G factions | `darkiron`: Dark Iron, `argentdawn`: Argent Dawn, `cenarion`: Cenarion Circle, `timbermaw`: Timbermaw Furbolg |
| H factions | `centaur`: Centaur, `naga`: Naga, `zandalar`: Zandalar |

`kind` is `race` for batches A and B, `class` for C and D, `faction` for the rest.

**Quality bar (asserted by `test_shipped_voices.lua`):**
- Race and faction voices: at least 40 swaps, of which at least 12 are tier 1; at least 4 openers and 4 closers.
- Class voices: at least 20 swaps, of which at least 8 are tier 1; at least 4 openers and 4 closers. Class swaps avoid the commonest words (`hello`, `you`, `yes`, `my`), which belong to races.
- Every voice: at least 5 lines per phrase kind, at least 2 of the 8 kinds having a `{target}` line (with its plain sibling); every line at most 120 bytes; `moods.angry.closers` with at least 3 lines.
- No swap value equals its own key. No swap value (single word) is itself a key in the same voice.

**Writing rules (not machine-checked; reviewer reads for them):**
- Tier 1 must read as normal English with flavour: a stranger understands the sentence at once. Heavier spelling changes go in tier 2 and 3.
- Use real in-game greetings and sayings where they exist (Night Elf "Ishnu-alah", "Elune be with you"; Orc "Lok'tar ogar", "Zug zug"; Troll "mon"; Goblin "Time is money, friend"; Kobold "You no take candle"; Murloc "Mrglgl"). Check spelling against the game or a WoW wiki. Write every full sentence fresh.
- Creature voices (murloc, kobold, ogre, gnoll) may lean on sound rules and broken grammar, but tier 1 stays readable.
- Keep it friendly: no slurs, nothing sexual, no real-world ethnic stereotypes beyond what the game's own voice lines do.
- Nothing from Yarrr or any accent addon.
- Icon: a stock `Interface\\Icons\\...` texture that exists in the Forever client (verify the path in the `forever` branch art listing or pick a classic-era icon name; a missing texture shows as a green square).

- [ ] **Step 1: Extend `tests/test_shipped_voices.lua`** with the quality-bar assertions and an assertion that every id in the table above exists. Run. Expected: FAIL (voices missing).
- [ ] **Step 2: Dispatch batches A to H in parallel.** Each agent writes its files and runs `lua5.1 tests/run.lua` until its own voices pass the bar.
- [ ] **Step 3: Check for extra playable races and classes.** Look in the `forever` branch of `Gethe/wow-ui-source` (character creation data, `Blizzard_APIDocumentationGenerated`) for race and class lists beyond the eight races and nine classes here. For each extra one, write a voice to the same bar and add its id to the test. If the list cannot be determined from source, note it in `README.md` under "To check in game" with the command `/run for i=1,30 do local c=C_CreatureInfo.GetRaceInfo(i) if c then print(i,c.clientFileString) end end`.
- [ ] **Step 4: Run** `lua5.1 tests/run.lua`. Expected: all pass.
- [ ] **Step 5: Read-through.** Print `Speak("hello friend, can you help me kill this boss? thanks, see you later", ...)` at strengths 1, 2, 3 for every race and faction, and for gnome+mage, orc+warrior, nightelf+druid, forsaken+warlock. Fix any tier 1 output that is hard to read.
- [ ] **Step 6: Commit** `git add -A && git commit -m "Add voices"`

---

### Task 6: TOC, settings, slash commands, send hook

**Files:**
- Create: `Bronzetongue/Bronzetongue.toc`, `Bronzetongue/Send.lua`, `tools/sync.sh`, `tests/test_send.lua`, `tests/stubs.lua`
- Modify: `Bronzetongue/Core.lua`

**Interfaces:**
- Consumes: `BT.Engine.Speak`, `BT.voices`.
- Produces:
  - `BronzetongueCharDB` (per character), reached as `BT.db` after `ADDON_LOADED`. Defaults: `{ enabled = true, race = nil, class = nil, mood = "calm", strength = 2, preview = true, wheel = true, wheelChat = "SAY", matched = false, chats = { SAY = true, YELL = true, EMOTE = true, PARTY = true, RAID = true, GUILD = true, WHISPER = true, OFFICER = false, INSTANCE_CHAT = false, CHANNEL = false } }`. Missing keys are filled from defaults on load (so new settings appear for old saves).
  - `BT.MatchCharacter()`: sets `db.race`/`db.class` from `UnitRace("player")` and `UnitClass("player")` file tokens via `BT.RACE_TOKENS` (`Human=human, Dwarf=dwarf, NightElf=nightelf, Gnome=gnome, Orc=orc, Troll=troll, Tauren=tauren, Scourge=forsaken`, plus any from Task 5 Step 3) and lower-cased class token; unknown gives nil. Runs once on first login (`db.matched`).
  - `BT.CHAT_TYPES = { "SAY", "YELL", "EMOTE", "PARTY", "RAID", "GUILD", "OFFICER", "WHISPER", "INSTANCE_CHAT", "CHANNEL" }`.
  - `BT.InLockdown() -> boolean`.
  - `BT.Options() -> opts` for `Speak` from `BT.db` (includes `names` from `BT.ReadableNames()`: target, party and raid member names that pass the secret-string check).
  - `BT.WillRewrite(chatType) -> boolean`: enabled, not lockdown, `chatType` is in `db.chats` and ticked, and a race or class is chosen. `BN_WHISPER` and unknown types give false.
  - `BT.Rewrite(text, chatType) -> text`: `Speak` under `pcall`; on error returns `text` and prints one line once.
  - `BT.Print(msg)`: chat line prefixed `|cffc9ad6aBronzetongue:|r`.
  - Slash: `/bronzetongue` and `/bt`. No argument opens options (`BT.OpenOptions`, defined in Task 9; until then prints help). `on`, `off` set `db.enabled`.

**Send hook (`Send.lua`):** register on `EventRegistry` for `"ChatFrame.OnEditBoxPreSendText"` with owner `BT`. Callback `(_, box)`: return if a re-entrancy flag is set, `box` lacks `GetText`, `IsAltKeyDown()` is true, or `not BT.WillRewrite(box:GetAttribute("chatType"))`. Read the text; `new = BT.Rewrite(text, chatType)`; if `new ~= text`, `box:SetText(new)` under the flag, then if `type(_G.AutocorrectForever) == "table"` set `_G.AutocorrectForever.lastText = false`. The whole callback body runs under `pcall`.

- [ ] **Step 1: Write `tests/stubs.lua`**: minimal fakes for `EventRegistry` (stores callbacks; `Fire(event, ...)`), `C_ChatInfo.InChatMessagingLockdown`, `IsAltKeyDown`, `UnitRace`, `UnitClass`, `UnitName`, `CreateFrame` (returns a table accepting any method), `DEFAULT_CHAT_FRAME`, and `FakeBox(text, chatType)` with `GetText`, `SetText`, `GetAttribute`. Each fake reads a field on a `Stub` table so tests can flip it.

- [ ] **Step 2: Write failing tests** `tests/test_send.lua` (voices: `t_race` from the engine tests; `BT.db` set directly to the defaults with `race = "t_race"`, `strength = 1`)

```lua
local function send(text, chatType) local b = FakeBox(text, chatType) EventRegistry.Fire("ChatFrame.OnEditBoxPreSendText", b) return b:GetText() end
function test_say_rewritten()        assert(send("hello", "SAY") == "ahoy") end
function test_unticked_chat_untouched() assert(send("hello", "OFFICER") == "hello") end
function test_bn_whisper_never()     BT.db.chats.BN_WHISPER = true assert(send("hello", "BN_WHISPER") == "hello") end
function test_unknown_chat_type()    assert(send("hello", "SOMETHING") == "hello" and send("hello", nil) == "hello") end
function test_disabled()             BT.db.enabled = false assert(send("hello", "SAY") == "hello") BT.db.enabled = true end
function test_lockdown()             Stub.lockdown = true assert(send("hello", "SAY") == "hello") Stub.lockdown = false end
function test_lockdown_api_missing() local f = C_ChatInfo.InChatMessagingLockdown C_ChatInfo.InChatMessagingLockdown = nil
  assert(send("hello", "SAY") == "ahoy") C_ChatInfo.InChatMessagingLockdown = f end
function test_alt_sends_plain()      Stub.alt = true assert(send("hello", "SAY") == "hello") Stub.alt = false end
function test_no_voice_chosen()      BT.db.race = nil assert(send("hello", "SAY") == "hello") BT.db.race = "t_race" end
function test_stale_voice_id()       BT.db.race = "removed_voice" assert(send("hello", "SAY") == "hello") BT.db.race = "t_race" end
function test_engine_error_keeps_text() local real = BT.Engine.Speak BT.Engine.Speak = function() error("boom") end
  assert(send("hello", "SAY") == "hello") BT.Engine.Speak = real end
function test_autocorrect_lasttext_cleared() _G.AutocorrectForever = { lastText = "hello" } send("hello", "SAY")
  assert(_G.AutocorrectForever.lastText == false) _G.AutocorrectForever = nil end
function test_autocorrect_untouched_when_unchanged() _G.AutocorrectForever = { lastText = "zzz" } send("zzz", "SAY")
  assert(_G.AutocorrectForever.lastText == "zzz") _G.AutocorrectForever = nil end
function test_target_name_protected() Stub.targetName = "My" assert(send("hello My", "SAY") == "ahoy My") Stub.targetName = nil end
function test_defaults_filled_on_old_save() local old = { enabled = false, chats = { SAY = false } } BT.ApplyDefaults(old)
  assert(old.enabled == false and old.chats.SAY == false and old.chats.GUILD == true and old.strength == 2) end
function test_match_character()      Stub.race = "Scourge" Stub.class = "WARLOCK" BT.MatchCharacter()
  assert(BT.db.race == "forsaken" and BT.db.class == "warlock") end
function test_match_unknown_race()   Stub.race = "Dracthyr" BT.MatchCharacter() assert(BT.db.race == nil) end
```

(`BT.ApplyDefaults(db)` is the fill-missing-keys function in `Core.lua`.)

- [ ] **Step 3: Run** tests. Expected: FAIL.
- [ ] **Step 4: Implement** `Core.lua` and `Send.lua`.
- [ ] **Step 5: Write `Bronzetongue.toc`**: `## Interface: 16001`, `## Title: Bronzetongue`, `## Notes: Speak like your race, faction and class. /bt for options.`, `## Author:` (leave for the owner to fill; do not put their email), `## Version: 1.0.0`, `## OptionalDeps: AutocorrectForever`, `## SavedVariablesPerCharacter: BronzetongueCharDB`, `## IconTexture: Interface\AddOns\Bronzetongue\Media\icon`, then the files in the load order above (voice files listed explicitly, alphabetical within each folder). Add a test `test_toc_lists_every_lua_file` in `tests/test_send.lua`: every `.lua` under `Bronzetongue/` appears in the TOC and every TOC entry exists.
- [ ] **Step 6: Write `tools/sync.sh`**: `rsync -a --delete Bronzetongue/ "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/Bronzetongue/"`.
- [ ] **Step 7: Run** `lua5.1 tests/run.lua`. Expected: all pass.
- [ ] **Step 8: Commit** `git add -A && git commit -m "Add settings, slash commands and send hook"`

---

### Task 7: Live preview

**Files:**
- Create: `Bronzetongue/Preview.lua`
- Modify: `tests/test_send.lua` (add preview text tests), `tests/stubs.lua` if needed

**Interfaces:**
- Consumes: `BT.WillRewrite`, `BT.Options`, `BT.Engine.Speak`.
- Produces: `BT.PreviewText(text, chatType) -> string | nil` (pure decision: nil when `db.preview` is off, `WillRewrite` is false, text is empty or starts with `/`, or the result equals the text); `BT.HookPreview(box)`.

**Behaviour:** the preview must show a stable result while typing, so `PreviewText` calls `Speak` with a deterministic random (`function() return 1 end` for picks, and interjection chance rolls returning 100 so none are added). The frame text is prefixed with a small gold `>`; a tooltip-style note is not needed. Because sent text uses real randomness, an interjection may be added on send that the preview did not show; this is expected.

**Frame:** one frame for the addon, re-anchored to the active box on each update: `BOTTOMLEFT` of the frame to `TOPLEFT` of the box, offset (0, 4), width of the box, height to fit one or two lines, word wrap on, strata above the chat frame. Backdrop `#111111` at 0.9 alpha, 1px edge `#80632c`, font `GameFontNormalSmall` coloured `#eeeecc`. Hide on the box's `OnHide` and `OnEditFocusLost`. Hook boxes with `HookScript("OnTextChanged", ...)` only (never `SetScript`); hook `ChatFrame1EditBox` to `ChatFrame10EditBox` at `PLAYER_LOGIN` when they exist, and any other box lazily from the pre-send callback. Each hooked box is recorded so it is hooked once. All handler bodies under `pcall`.

- [ ] **Step 1: Write failing tests**

```lua
function test_preview_text()         assert(BT.PreviewText("hello", "SAY") == "ahoy") end
function test_preview_nil_when_same()assert(BT.PreviewText("zzz", "SAY") == nil) end
function test_preview_nil_when_off() BT.db.preview = false assert(BT.PreviewText("hello", "SAY") == nil) BT.db.preview = true end
function test_preview_nil_unticked() assert(BT.PreviewText("hello", "OFFICER") == nil) end
function test_preview_nil_slash()    assert(BT.PreviewText("/who", "SAY") == nil) end
function test_preview_stable()       BT.db.strength = 3 local a = BT.PreviewText("hello there friend", "SAY")
  for i = 1, 20 do assert(BT.PreviewText("hello there friend", "SAY") == a) end BT.db.strength = 1 end
```

- [ ] **Step 2: Run** tests. Expected: FAIL.
- [ ] **Step 3: Implement** `Preview.lua`; add it to the TOC.
- [ ] **Step 4: Run** tests. Expected: all pass.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Add live preview"`

---

### Task 8: Phrase wheel

**Files:**
- Create: `Bronzetongue/Wheel.lua`, `Bronzetongue/Bindings.xml`
- Modify: `tests/test_send.lua` (wheel send decision tests)

**Interfaces:**
- Consumes: `BT.Phrases.Pick`, `BT.Phrases.SlotAt`, `BT.KINDS`, `BT.InLockdown`, `BT.Options`.
- Produces: global `BronzetongueWheel_OnKey(keystate)` (`"down"` opens, `"up"` closes and acts); `BT.WheelTarget() -> target | nil` (name, localized race and class of the current target; nil when there is no target or any value is secret); `BT.WheelSay(line)`.

**Binding:** `Bindings.xml` with one binding, `name="BRONZETONGUE_WHEEL"`, `runOnUp="true"`, category `ADDONS`, body `BronzetongueWheel_OnKey(keystate)`. Strings: `BINDING_HEADER_BRONZETONGUE = "Bronzetongue"`, `BINDING_NAME_BRONZETONGUE_WHEEL = "Hold for phrase wheel"`. Unbound by default. Check in the `forever` branch how addon `Bindings.xml` is loaded on this client (auto-loaded from the addon folder versus listed in the TOC) and do what that client needs.

**Behaviour:**
- Key down: do nothing if `not db.wheel`, in lockdown, or no voice chosen (print one hint line: "Pick a voice in /bt first."). Otherwise show the ring centred on the cursor (`GetCursorPosition()` divided by `UIParent:GetEffectiveScale()`), remember the centre, and pick one line per slot now with `BT.Phrases.Pick` so the shown line is the line that is sent.
- While shown (`OnUpdate`): compute `SlotAt(dx, dy)` from the cursor; highlight that slot; show its line in the side box (to the right of the ring; to the left when the ring is in the right 40% of the screen).
- Key up: hide. If a slot is highlighted and its line is not nil, `BT.WheelSay(line)`.
- `BT.WheelSay(line)`: `C_ChatInfo.SendChatMessage or SendChatMessage` called directly with `(line, db.wheelChat)` under `pcall`. `db.wheelChat` is one of `SAY`, `YELL`, `EMOTE`, `PARTY`, `RAID`, `GUILD`. For `PARTY`/`RAID` when not in such a group, fall back to `SAY`.
- **Fallback if the game refuses addon-sent SAY/YELL from a key release** (owner checks this in game, Task 10): `db.wheelToBox = true` makes `WheelSay` instead open the chat box with the line filled in, using the client's own open-chat function (`ChatFrameUtil.OpenChat(line)` if present, else `ChatFrame_OpenChat(line)`), for the player to press Enter. Default false. Lines put in the box are marked so the pre-send hook does not voice them again: store the line in `BT.wheelLine`; `Send.lua` skips rewriting when the box text equals `BT.wheelLine`, then clears it.

**Look:** ring outer radius 84, inner radius 40 (matches `SlotAt`), labels on radius 62: `Hello, Follow, Wait, Cheer, Battle, Bye, Help, Thanks` in `GameFontNormalSmall`, `#eeeecc`; highlighted label `#191510` on a bronze wedge. Thin bronze rim (`#80632c`) at the outer radius, dark fill `#0d0b08` at 0.88 alpha between the radii, small bronze infinity mark at the centre. Build the ring from textures available in the client (a ring/circle mask texture tinted, or eight rotated wedge textures); choose whichever the client supports and looks clean. Side box: backdrop `#111111`, 1px `#80632c` edge, kind name in `#c9ad6a`, line in `#eeeecc`, max width 240, word wrap. Frame strata `TOOLTIP`. The frame never takes mouse input.

- [ ] **Step 1: Write failing tests** (stubs gain a recorder for `C_ChatInfo.SendChatMessage` and `IsInGroup`/`IsInRaid`)

```lua
function test_wheelsay_sends_to_chosen_chat() BT.db.wheelChat = "YELL" BT.WheelSay("hi") assert(Stub.sent[1] == "hi" and Stub.sent[2] == "YELL") end
function test_wheelsay_party_falls_back_to_say() BT.db.wheelChat = "PARTY" Stub.inGroup = false BT.WheelSay("hi") assert(Stub.sent[2] == "SAY") end
function test_wheelsay_to_box_mode()   BT.db.wheelToBox = true Stub.sent = nil BT.WheelSay("hello") assert(Stub.sent == nil and Stub.opened == "hello" and BT.wheelLine == "hello")
  assert(send("hello", "SAY") == "hello" and BT.wheelLine == nil) BT.db.wheelToBox = false end
function test_wheel_closed_in_lockdown() Stub.lockdown = true BronzetongueWheel_OnKey("down") assert(not BT.wheelOpen) Stub.lockdown = false end
function test_wheel_off_setting()      BT.db.wheel = false BronzetongueWheel_OnKey("down") assert(not BT.wheelOpen) BT.db.wheel = true end
function test_wheel_no_voice()         BT.db.race, BT.db.class = nil, nil BronzetongueWheel_OnKey("down") assert(not BT.wheelOpen) BT.db.race = "t_race" end
function test_wheel_up_without_slot_sends_nothing() Stub.sent = nil BronzetongueWheel_OnKey("down") BronzetongueWheel_OnKey("up") assert(Stub.sent == nil) end
function test_wheel_target_secret_is_nil() Stub.targetSecret = true assert(BT.WheelTarget() == nil) Stub.targetSecret = false end
```

- [ ] **Step 2: Run** tests. Expected: FAIL.
- [ ] **Step 3: Implement** `Wheel.lua`, `Bindings.xml`, the `wheelToBox`/`wheelLine` change in `Send.lua`, defaults `wheelToBox = false`; add to the TOC as that client requires.
- [ ] **Step 4: Run** tests. Expected: all pass.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Add phrase wheel"`

---

### Task 9: Options panel

**Files:**
- Create: `Bronzetongue/Options.lua`
- Modify: `Bronzetongue/Core.lua` (slash with no argument calls `BT.OpenOptions()`)

**Interfaces:**
- Consumes: `BT.db`, `BT.VoicesOfKind`, `BT.MatchCharacter`, `BT.CHAT_TYPES`, `BT.Engine.Speak`.
- Produces: `BT.OpenOptions()`.

**Registration:** a single custom-drawn panel registered with the client's settings system as a canvas category named `Bronzetongue` (check the `forever` branch for `Settings.RegisterCanvasLayoutCategory` and `Settings.RegisterAddOnCategory`; fall back to `InterfaceOptions_AddCategory` only if the Settings API is absent). `BT.OpenOptions` opens it with `Settings.OpenToCategory(categoryID)`; never call that in combat lockdown (print "Options open after combat." instead).

**Layout (top to bottom), matching `.superpowers/brainstorm/*/content/bronze-theme-v3.html`:**

| Section | Controls |
|---|---|
| Title bar | Infinity mark and "Bronzetongue", version on the right |
| **Voice** | Checkbox "Enabled" (`db.enabled`). Dropdown "Race / faction": None, then races, then factions, each row with the voice icon (`db.race`). Dropdown "Class": None, then classes with icons (`db.class`). Dropdown "Mood": Calm, Angry, Drunk, Scared (`db.mood`). Button "Match my character". Slider "Strength" with 3 steps labelled Light, Medium, Heavy (`db.strength`). Sample box: "You type: hello, can you help me kill this boss?" and "Others see: <Speak of that line with current settings>", refreshed on any change and by a small "Again" button. |
| **Auto mode: rewrite what I type in** | One checkbox per `BT.CHAT_TYPES` entry, labelled Say, Yell, Emote, Party, Raid, Guild, Officer, Whisper, Instance, Channels (`db.chats[type]`). Small grey note: "Battle.net whispers are never changed. Hold Alt while pressing Enter to send one message as typed." Checkbox "Show a preview above the chat box" (`db.preview`). |
| **Phrase wheel** | Checkbox "Enabled" (`db.wheel`). Key button showing the current binding of `BRONZETONGUE_WHEEL` or "Not bound"; clicking it captures the next key press and binds it with `SetBinding` then `SaveBindings(GetCurrentBindingSet())`; Escape cancels, right-click clears. Not usable in combat. Dropdown "Speak in": Say, Yell, Emote, Party, Raid, Guild (`db.wheelChat`). Checkbox "Put the phrase in my chat box instead of sending it" (`db.wheelToBox`). |
| **Autocorrect** | Checkbox "Fix my spelling first". If `_G.AutocorrectForever` is a table: checked state mirrors `AutocorrectForeverDB.enabled` (read only; `AutocorrectForeverDB` may be nil, treat as off); clicking runs `SlashCmdList.AUTOCORRECTFOREVER("on" or "off")`. Grey note: "Uses the Autocorrect Forever addon. This switch is shared by all your characters." If its saved `accent` is set, a gold line: "Autocorrect Forever's own accent is on, so messages get two accents." with a button "Turn it off" running `SlashCmdList.AUTOCORRECTFOREVER("accent off")`. If the addon is absent: checkbox disabled and the note reads "Install Autocorrect Forever to use this." |

**Style:** panel background `#111111`; section headers `#c9ad6a`, small caps style (upper-case text) with a 1px `#80632c` rule fading right; dropdown and input surfaces `#242424` with `#606060` border; checkbox boxes `#191919` with `#80632c` border and a `#c9ad6a` tick; slider thumb bronze. Build small local helper functions in `Options.lua` for checkbox, dropdown, slider and header (four helpers, used many times). Dropdown rows show a 20px icon then the name. All controls refresh from `BT.db` in the panel's `OnShow`, so a change made by slash command shows correctly.

No unit tests (pure UI). Verification is syntax plus the in-game checklist.

- [ ] **Step 1: Implement** `Options.lua` and the `Core.lua` slash change; add to the TOC.
- [ ] **Step 2: Syntax check** every addon file: `for f in $(find Bronzetongue -name '*.lua'); do lua5.1 -e "assert(loadfile('$f'))" || echo FAIL $f; done`. Expected: no output. Run `lua5.1 tests/run.lua`. Expected: all pass.
- [ ] **Step 3: Commit** `git add -A && git commit -m "Add options panel"`

---

### Task 10: Icon, release files, in-game checklist

**Files:**
- Create: `tools/icon.svg`, `tools/make_icon.sh`, `Bronzetongue/Media/icon.tga`, `curseforge/icon-400.png`, `curseforge/description.md`, `README.md`, `LICENSE`, `tools/package.sh`, `docs/in-game-checklist.md`

- [ ] **Step 1: Draw the icon** as `tools/icon.svg` (square): dark ground with a warm centre glow, a bronze-rimmed speech bubble with a tail at lower left, Forever's infinity mark inside it in bevelled bronze with a pale highlight, and a bronze square border like a game icon. Base it on option B in `.superpowers/brainstorm/*/content/bronze-theme-v3.html`, with more depth: gradient bronze (`#f0d9a0` to `#b98a3e` to `#5e4318`), inner shadow on the bubble, highlight on the upper left of the loop. `tools/make_icon.sh` renders `curseforge/icon-400.png` (400x400) and `Bronzetongue/Media/icon.tga` (64x64, 32-bit, uncompressed) using whichever of `rsvg-convert`, `inkscape`, ImageMagick `convert` or Python `cairosvg`/`Pillow` is installed; check with `which` first and say what was used. Verify: `file Bronzetongue/Media/icon.tga` reports Targa 64 x 64. Show the PNG to the owner for approval.
- [ ] **Step 2: Write `LICENSE`** (MIT, year 2026; copyright holder name left as `<your name>` for the owner) and `README.md` (what it does, install, `/bt`, known limits).
- [ ] **Step 3: Write `curseforge/description.md`**: short pitch; feature list (voices with counts taken from the files, class layer, moods, phrase wheel, live preview, per-chat switches, per-character settings, works with Autocorrect Forever); "Good to know": does nothing during boss encounters and other chat lockdown; Battle.net whispers never changed; whispers typed in WIM, WhatTheWhisper or WhisperMessenger windows go out as typed; Alt+Enter sends one message as typed; English only; Forever only. Optional dependency: Autocorrect Forever. No claim of in-game testing that has not happened.
- [ ] **Step 4: Write `tools/package.sh`**: builds `dist/Bronzetongue-<version from TOC>.zip` containing only the `Bronzetongue/` folder. Run it; verify with `unzip -l` that the top level is `Bronzetongue/` and no test or tool files are inside.
- [ ] **Step 5: Write `docs/in-game-checklist.md`** for the owner. Run `tools/sync.sh` first. Items:
  1. `/run print(select(4, GetBuildInfo()))` prints 16001 (else update the TOC).
  2. Addon loads with no error (BugSack empty); `/bt` opens the panel; every control works and survives `/reload`.
  3. Say, Yell, Emote, Party, Guild, Whisper are voiced; Officer and Trade are not until ticked.
  4. Shift-click an item into a message: the link still works for others.
  5. Alt+Enter sends as typed. A Battle.net whisper is not changed.
  6. Preview line appears above the chat box, in the right place, under each chat UI: default, EllesmereUI or EUIStandaloneChat, BetterForeverChat, Prat, FlareUI, Chattynator, HydraUI (one at a time).
  7. With Prat, FlareUI and EUIStandaloneChat each enabled: a voiced message sends once, correctly.
  8. With Autocorrect Forever on: a typo is fixed and then voiced; with its accent set, the panel shows the notice and "Turn it off" works.
  9. Wheel: bind a key, hold, flick, release. Does the phrase send in Say and Yell outdoors? If the game refuses it, tick "Put the phrase in my chat box instead" and report it so the default can be changed.
  10. In a dungeon boss fight: chat sends normally, unvoiced; the wheel does not open; no error after the fight.
  11. Target a player and an NPC: wheel greetings use the name; in combat in an instance no error appears.
  12. Log a second character: it starts matched to its own race and class with its own settings.
- [ ] **Step 6: Run** `lua5.1 tests/run.lua` and the syntax loop from Task 9. Expected: all pass, no output.
- [ ] **Step 7: Commit** `git add -A && git commit -m "Add icon, release files and in-game checklist"`
- [ ] **Step 8: Before creating the CurseForge project,** confirm the name "Bronzetongue" is free by searching curseforge.com directly, and list Autocorrect Forever as an optional dependency on the project page.
