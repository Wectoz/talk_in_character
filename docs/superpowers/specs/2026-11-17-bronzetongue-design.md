# Bronzetongue: design

A World of Warcraft: Forever addon that makes your chat sound like a chosen race or faction
and class. Mostly for fun, usable for roleplay. To be published on CurseForge.

Lines marked **(call)** are choices Claude made, not things the owner asked for. Everything
else is as the owner decided it.

## Intent and why

Chatting in character is funnier and more immersive when a gnome mage sounds clever and a
Bloodsail pirate sounds like one. The owner wants one addon that does this for any race,
faction and class, without having to write in character by hand.

Similar addons exist (Accents of Azeroth, Accent Chat, Tongues of Azeroth, Eloquence Revived).
They do racial accents. Bronzetongue is meant to stand apart through: a class layer, creature
and villain voices, moods, a phrase wheel, a live preview, target-aware phrases, and working
with autocorrect.

## Goals

1. **Auto mode.** What you type is rewritten in your chosen voice as it is sent.
2. **Two stacked choices plus a mood.** Race or faction sets accent and vocabulary. Class sets
   attitude. Either can be "None". Mood (calm, angry, drunk, scared) colours the result.
3. **Phrase wheel.** Hold a bound key: a small ring of eight phrase kinds appears at the cursor.
   Move toward one and release to say a line from your current voice. For people who do not
   want auto mode.
4. **Per-chat control.** A checkbox for each chat type decides where auto mode applies.
5. **Everything is togglable** from an options panel: the addon, auto mode per chat type, the
   wheel, the preview, autocorrect.
6. **Autocorrect.** Togglable from our panel, provided by the Autocorrect Forever addon.
7. **Live preview.** While typing, a line above the chat box shows what will be sent.
8. **Target-aware phrases.** Phrases can use the target's name, race or faction.
9. **Each character remembers its own voice.**
10. **As many voices as possible in the first version**, including ones other addons lack.
11. A name (Bronzetongue), an icon, and a CurseForge-ready package.

## Non-goals (first version)

- Changing how other people's messages look to you.
- Reputation-locked voices, a voice editor or sharing codes, hover-to-read-plain-text. These
  are planned as later updates.
- Other WoW clients (Retail, Classic). Forever only.
- Languages other than English. Voices rewrite English text.
- A minimap button.

## Anti-goals

- **A message is never lost or blocked.** If anything goes wrong, the message goes out as typed.
- **Never interfere during boss encounters or other chat lockdown.** The addon does nothing then.
- Never alter item/spell/quest links, player names, raid icons, slash commands or URLs.
- Never rewrite public channels (Trade, General) unless the player turns that on.
- No text or code copied from Yarrr (all rights reserved) or from other accent addons.
- Light strength must stay easy to read.

## Constraints (verified in the owner's Forever install, interface 16001)

- **How to change a message on send.** The game fires `ChatFrame.OnEditBoxPreSendText` through
  `EventRegistry` just before it reads the chat box. A callback may `SetText` the box. This is
  what Autocorrect Forever does (`AutocorrectForever.lua`, `OnPreSendText`). The game's send
  functions must never be replaced or wrapped: a send that passes through addon code is refused
  during chat lockdown and the message is silently swallowed.
- **Never write to the edit box's `chatType` attribute or other secure state** from our code.
  EllesmereUIChat documents that one tainted write makes every later send fail in lockdown.
- **Lockdown check:** `C_ChatInfo.InChatMessagingLockdown()` (may be absent: guard and `pcall`).
- **Secret strings.** In combat and instances the game can hand addons unit names that error on
  any use. Target-aware phrases must test readability first and fall back to a line without the
  target.
- **Message limit:** 255 bytes. Rewriting can lengthen text.
- **Works with any chat UI (owner requirement).** It must work with the default chat, EllesmereUI,
  Prat, BetterForeverChat "and so on". So: depend on no chat addon, use only the game's own
  chat edit boxes and the pre-send event, anchor the preview to whichever edit box is active
  rather than to a fixed frame, and never restyle or move another addon's frames. The owner
  has BetterForeverChat, EllesmereUIChat and WhisperMessenger installed; Prat is not installed.
- **Addons with their own message composer are not covered (call).** WhisperMessenger sends
  through its own window, not the game's chat box, so the pre-send event never fires there.
  Messages typed in such a window go out as typed. Bronzetongue must not break them. This is
  stated on the CurseForge page.
- **Autocorrect Forever** exposes `_G.AutocorrectForever`, a `/autocorrect on|off` slash
  command, and saved setting `enabled`. It also has its own troll, dwarf and pirate accents
  (`db.accent`), applied in the same pre-send event.
- Interface number must be confirmed in-game with `select(4, GetBuildInfo())` before release.
- Forever's project ID is `WOW_PROJECT_CAMELOT`; do not assume Classic or Retail behaviour.

## Approaches

### Autocorrect

| | Approach | Trade-off |
|---|---|---|
| **A (picked by owner)** | Team up with Autocorrect Forever: optional dependency, our panel switches it on and off | No copied code, always current, its author keeps credit. Only works when it is installed. |
| B | Bundle a copy of its engine and word list (MIT allows it) | Stands alone. +1.4 MB, we maintain another author's code, must stand down when the original is present. |
| C | Write a small typo list of our own | Tiny, but far weaker, and misspelled words would not match voice rules. |

### Rewriting on send **(call)**

| | Approach | Trade-off |
|---|---|---|
| **Picked** | Rewrite the chat box text in the pre-send event | Sanctioned by the game, proven by an installed addon, safe in lockdown. |
| Rejected | Replace `SendChatMessage` | Simple, but swallows messages in boss fights and breaks other chat addons. |
| Rejected | Rewrite as you type, word by word | Fights with autocorrect and makes editing your own text confusing. |

### Voices **(call)**

| | Approach | Trade-off |
|---|---|---|
| **Picked** | One small engine; every voice is a data file in a fixed format; layers compose | Voices can be written in parallel and added without code changes. Combinations are not hand-tuned. |
| Rejected | Hand-written voice per race and class pair | Best jokes per pair, but hundreds of files. |

## Design

### The pipeline

On pre-send, when not in lockdown, the addon is enabled, and the chat type is ticked:

1. Take the box text. Skip if it starts with `/` or is empty.
2. Protect what must not change: links and other `|`-escape sequences, raid icon tags like
   `{star}`, URLs, and names of the player's target, party and raid members when readable.
3. Apply layers in order: race or faction, then class, then mood.
4. Restore protected parts.
5. If the result is over 255 bytes, retry at a lighter strength, then give up and leave the
   text as typed.
6. `SetText` the result. Any error anywhere: leave the text as typed and report once in chat.

**Send plain once (call):** holding Alt while pressing Enter sends the message unchanged.

**With Autocorrect Forever (call):** both addons act in the same pre-send event and the order
is not guaranteed. Its send-time step only runs when the box text equals its `lastText` field,
and that field refreshes when we `SetText`. So right after our `SetText`, we set
`AutocorrectForever.lastText = false`. Result in each order:

- It runs first: last word is fixed, then we voice the message. Ideal.
- We run first: it skips the message, so it cannot "correct" our accent words. The last word
  misses its send-time fix; earlier words were already fixed as they were typed. Accepted.

This writes one undocumented field of another addon, guarded by a type check. No other
internals are touched. If its own accent setting is on, our panel shows a notice and offers to
turn that accent off, since both would apply.

### What a voice file holds

- `id`, display name, kind (`race`, `faction`, `class`), icon.
- **Word swaps:** whole-word replacements, each with a strength tier (light, medium, heavy).
  Several alternatives per word are allowed, picked at random.
- **Sound rules:** pattern rewrites such as dropping a final "g" (medium and heavy only).
- **Interjections:** openers and closers added sometimes (heavy, and sparingly at medium).
- **Wheel phrases:** for each of the eight kinds, at least three lines. Lines may contain
  `{target}`, `{targetRace}`, `{targetClass}`; a line with a token needs a token-free sibling.
- Case is preserved: "Hello" stays capitalised, "HELLO" stays shouted.

Race and faction voices carry most of the swaps and sound rules. Class voices carry vocabulary
and interjections. Stacking is just applying one after the other; a class never undoes a race
swap.

**Strength:** light = light-tier swaps only. Medium = all swaps and sound rules, rare
interjections. Heavy = everything.

### Moods **(call on the mechanics)**

Moods are mostly general rules in the engine, so every voice gets them for free:

- **Calm:** no change.
- **Angry:** exclamation marks, the odd shouted word, angry interjections.
- **Drunk:** slurred s sounds, a hiccup now and then, a dropped letter.
- **Scared:** stutters on first letters, trailing dots.

A voice file may add its own mood interjections (a gnome's angry outburst differs from an
orc's). Those are optional.

### Voices in the first version

"As big as possible." The builder writes every voice below, and adds any other playable race
or class the Forever client actually offers (check the client, do not assume).

- **Races:** Human, Dwarf, Night Elf, Gnome, Orc, Troll, Tauren, Forsaken.
- **Factions and creatures:** Bloodsail Buccaneers, Goblin (Steamwheedle), Defias Brotherhood,
  Scarlet Crusade, Venture Co., Murloc, Kobold, Ogre, Dark Iron, Argent Dawn, Cenarion Circle,
  Timbermaw furbolg, Gnoll, Centaur, Naga, Zandalar.
- **Classes:** Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid.

Character notes the owner gave: a gnome mage "will sound very smart".

**Sources.** Real in-game greetings, battle cries and catchphrases (Ishnu-alah, Lok'tar ogar,
"Time is money, friend") and vocabulary from the game client and wikis. Full sentences are
written fresh. Nothing from Yarrr or other accent addons.

**Writing them.** The owner asked for several agents in parallel. Each agent gets the voice
format, one or two finished voices as examples, and a batch of voices. A test checks every
file (see Testing).

### Phrase wheel

- A key binding ("Hold for phrase wheel") in the game's own key bindings. Unbound by default.
- While held: a ring about 170 px across appears centred on the cursor, eight slots: Hello,
  Thanks, Follow, Wait, Cheer, Battle, Bye, Help. One-word labels, thin bronze rim, bronze
  highlight on the slot nearest the cursor direction, infinity mark in the centre.
- A small box beside the ring shows the full line that will be said for the highlighted slot.
- Release over a slot: the line is sent to the chat chosen in options (default Say). Release in
  the centre: nothing is sent.
- The line is picked at random from the race or faction and class pools for that kind, not
  repeating the previous pick. Mood applies. Target tokens are filled when the target is
  readable.
- In lockdown the wheel does not open **(call)**. Sending from addon code is what the game
  refuses there.
- **If the game refuses an addon-sent Say or Yell on key release (call):** the builder checks
  this in the game first. If it is refused, the wheel instead puts the line into the chat box,
  ready for the player to press Enter. The wheel's look and slots stay the same.

### Live preview

A single bronze-edged line above the active chat box showing the rewritten text as you type,
updated on text change, hidden when it equals what you typed or when auto mode will not apply
to the current chat type. Togglable.

### Options panel

In the game's AddOns settings, plus `/bronzetongue` and `/bt` to open it and
`/bt on|off` to toggle **(call)**. Sections:

- **Voice:** enabled; race or faction dropdown and class dropdown, each row with its icon (the
  game's own race crests, faction emblems, class icons, or a fitting stock icon); mood
  dropdown; "Match my character" button that sets race and class from the logged-in character;
  strength slider; a live sample ("You type / Others see").
- **Auto mode:** checkboxes for Say, Yell, Emote, Party, Raid, Guild, Officer, Whisper,
  Instance, Channels. "Whisper" means in-game whispers only; Battle.net whispers are never
  rewritten **(call)**, since they reach real-life friends, possibly in other games. Defaults on: Say, Yell, Emote, Party, Raid, Guild, Whisper. Off:
  Officer, Instance, Channels **(call)**. Live preview checkbox.
- **Phrase wheel:** enabled; key binding; chat to speak in.
- **Autocorrect:** "Fix my spelling first" checkbox. It mirrors Autocorrect Forever's own
  on/off switch **(call)**: it shows that addon's current state and flips it through its public
  slash command. That switch is account-wide, so it is the one setting here that is not per
  character, and the panel says so. If it is not installed, the checkbox is greyed out with a
  line saying to install Autocorrect Forever.

**Look:** as in the approved mockup. Dark neutral surfaces (`#111111`, `#191919`, `#242424`),
bronze edges (`#80632c`), pale gold emphasis (`#c9ad6a`), text `#eeeecc`. Mockups are kept in
`.superpowers/brainstorm/` (`bronze-theme-v3.html`).

### Saved settings

Per character **(call)**: everything. A new character starts with "Match my character"
applied, mood calm, strength medium, wheel unbound.

### Name, icon, packaging

- **Name:** Bronzetongue. Search found no addon using it; confirm on CurseForge before creating
  the project.
- **Icon:** Forever's infinity mark inside a bronze speech bubble on a dark ground. The builder
  draws it as vector art and renders a 64x64 game texture and a 400x400 PNG for CurseForge
  **(call)**. It is drawn, not hand-painted; the owner approves the image before release and
  may supply their own instead.
- **TOC:** `## Interface: 16001`, `## OptionalDeps: AutocorrectForever`, per-character saved
  variables, the icon. On CurseForge, list Autocorrect Forever as an optional dependency.
- **Licence (call):** MIT. The owner can change this before publishing.
- **CurseForge page text:** a short description and a feature list, written with the release.

## Testing

- The engine (protect, swap, sound rules, moods, length fallback) is plain Lua with no game
  calls, so it is tested outside the game with the `lua5.1` already on this machine.
- A voice-file check: required fields present, eight wheel kinds with at least three lines
  each, a token-free line per kind, no line over 255 bytes, no swap that rewrites its own
  output in a loop.
- In the game, by the owner: each chat type, a linked item, Alt+Enter, lockdown in a dungeon
  boss fight, with and without Autocorrect Forever, and under each chat UI: default,
  EllesmereUI, BetterForeverChat, and Prat (the owner would need to install Prat to try it).

## Left to the builder

- File layout, how the repo is synced into the Forever AddOns folder, and the settings API
  calls. The Forever branch of `Gethe/wow-ui-source` is the reference for any API.
- How the cursor-centred ring and its hit-testing are drawn.
- Which icon each faction and creature voice uses.
- How many agents and how voices are batched.
- Exact swap lists, phrases and mood rules, within the notes above.
