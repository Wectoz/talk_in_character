# Talk in Character: in-game checklist

Run `tools/sync.sh`, start Forever (or `/reload`), and work down the list. Note anything that fails.

## Loading

1. **Build number.** `/run print(select(4, GetBuildInfo()))` prints `16001`. If not, note the number.
2. **Loads cleanly.** No error in BugSack. The addon list shows the pixel-art smiley icon.
3. **Second character.** A new character starts matched to its own race and class, with only Say
   and Yell ticked, age Adult, mood Calm and catchphrases off.

## Options panel (`/tic`)

4. **Look.** Bronze edges, the small smiley by the title, dropdown rows with icons. Nothing overlaps.
   Age and Strength sit under Class and Mood. Note any voice icon that shows as a green square.
5. **Fits.** Every section is reachable: Voice, Auto mode, Phrase wheel, Autocorrect, Kept words. If the
   panel is too short, the mouse wheel scrolls it and a thin bar shows at the right.
6. **Controls.** Every control works and its setting survives `/reload`. Checkboxes and text boxes
   light up gold under the mouse, and hovering shows help where there is some.
7. **Strength slider.** Drags smoothly, settles on Light, Medium or Heavy, and answers the mouse wheel.
8. **Sample.** Typing in "You type" changes "Others see" at once. With the voice off, or no voice
   picked, it says so instead. A long sentence wraps to two lines.
9. **Kept words.** Type a word and press Enter: it appears as a button. Clicking it removes it.

## Chat

10. **Auto mode.** A ticked chat is voiced, an unticked one is not. In `/e`, only text in "quotes" is voiced.
11. **Game terms.** `LFM UBRS need tank and healer, PST` goes out as typed, whatever the mood and age.
    `I need to run home` is voiced.
12. **Ages and moods.** Try Young and Elder, and each mood, with a few sentences.
13. **Catchphrases.** With the box ticked, now and then a message gets an opener or a closer, and the
    closer follows a full stop.
14. **Group chat.** With "Keep game words plain" ticked, `stack on boss` stays plain in party chat.
15. **Chat commands.** `/tic drunk`, `/tic elder`, `/tic heavy`, `/tic keep <word>`, `/tic kept`.
16. **Links.** Shift-click an item into a message. The link still works for other players.
17. **Send as typed.** Ctrl+Enter sends the message unchanged. A Battle.net whisper is never changed.
18. **Preview.** The line appears above the chat box, in the right place, under each chat UI, one at
    a time: default, EllesmereUI or EUIStandaloneChat, BetterForeverChat, Prat, FlareUI, Chattynator,
    HydraUI.
19. **Shared hook.** With Prat, FlareUI and EUIStandaloneChat each enabled, a voiced message sends
    once and correctly.

## Autocorrect Forever

20. **Together.** With it on, a typo is fixed and then voiced. `strat`, `brez` and `scholo` are left
    alone. No warning line appears in chat a few seconds after login.
21. **Its own accent.** With its accent set, the panel shows the notice and "Turn it off" works.
22. **Kept words.** `/tic keep <word>` also shows the word in `/autocorrect list`.

## Phrase wheel

23. **Wheel.** Bind a key in the panel (a key already in use is refused with a message; clicking
    elsewhere cancels), hold it, flick, release. The ring is round, small and centred on the cursor,
    with the smiley in the middle. If the game refuses Say or Yell outdoors, set "Speak in" to Party
    or Guild and note it.
24. **Targets.** Target a player, then an NPC: wheel greetings use the name. In combat inside an
    instance, no error appears.

## Boss fights

25. **Lockdown.** In a dungeon boss fight, chat sends normally and unvoiced, the wheel does not
    open, and no error appears afterwards.
