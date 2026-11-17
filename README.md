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

## To check in game

Forever may offer races or classes beyond the classic eight and nine. To list race tokens:

    /run for i=1,40 do local r=C_CreatureInfo.GetRaceInfo(i) if r then print(i, r.clientFileString) end end

A race without a voice starts on "None".

## Known limits

- Does nothing during chat lockdown (boss encounters).
- Whispers typed in WIM, WhatTheWhisper or WhisperMessenger windows are not voiced.
- Battle.net whispers are never voiced.
- English only.
