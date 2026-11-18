# Talk in Character

A WoW: Forever addon that rewrites your chat in the voice of a race or faction and a class.
See `curseforge/description.md` for the player-facing description.

## Layout

- `TalkInCharacter/` the addon. This folder is what ships.
- `tests/` tests that run outside the game: `lua5.1 tests/run.lua`
- `tools/sync.sh` copies the addon into the Forever AddOns folder.
- `tools/gen_toc.sh` rewrites the file list in the TOC. Run it after adding a voice file.
- `tools/make_icon.py` draws the icon files.
- `tools/check_icons.sh` checks every voice icon is a real game icon (needs internet).
- `tools/package.py` builds `dist/TalkInCharacter-<version>.zip` for CurseForge.
- `docs/in-game-checklist.md` what to check in the game before releasing.

## Adding a voice

Copy a file under `TalkInCharacter/Voices/`, change the `id`, write the voice, run
`tools/gen_toc.sh` and `lua5.1 tests/run.lua`. The tests say what a voice needs. To make
"Match my character" pick it for a playable race, add the race's file token to `RACE_TOKENS`
in `TalkInCharacter/Core.lua`.

## Ages

`TalkInCharacter/Engine/Ages.lua` holds the Young and Elder rules: a few word swaps, a change
to punctuation, and asides that follow the catchphrase setting. A voice gives its own asides
in `ages = { young = { closers = {...} }, elder = { closers = {...} } }`.

## Chat commands

`/tic` opens the options. `/tic on|off`, `/tic calm|angry|drunk|scared`, `/tic adult|young|elder`
and `/tic light|medium|heavy` change a setting. `/tic keep <word>` leaves a word of your own as
typed (and tells Autocorrect Forever to do the same), `/tic forget <word>` undoes it, and
`/tic kept` lists them.

## Game terms

`TalkInCharacter/Engine/Terms.lua` lists the words no voice, accent or mood may change.
`STRICT` terms (LFM, WTS, tank, BRD) are always kept. `LOOSE` terms are everyday words with a
game meaning (need, run, hit): they are kept only in a message that also holds a strict term.
A message with a strict term in it takes no age and no mood. A swap whose key is a strict term fails the tests. The strict terms are also handed to Autocorrect
Forever at load (`Send.lua`), so it leaves them as typed.

## To check in game

Forever may offer races or classes beyond the classic eight and nine. To list race tokens:

    /run for i=1,40 do local r=C_CreatureInfo.GetRaceInfo(i) if r then print(i, r.clientFileString) end end

A race without a voice starts on "None".

## Known limits

- Does nothing during chat lockdown (boss encounters).
- Whispers typed in WIM, WhatTheWhisper or WhisperMessenger windows are not voiced.
- Battle.net whispers are never voiced.
- English only.
