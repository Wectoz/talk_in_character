# Talk in Character: in-game checklist

None of this has been checked in the game yet. Run `tools/sync.sh`, start Forever (or `/reload`),
and work down the list. Note anything that fails.

1. **Build number.** `/run print(select(4, GetBuildInfo()))` prints `16001`. If not, tell me the number.
2. **Loads cleanly.** No error in BugSack. `/tic` opens the panel. Every control works and its
   setting survives `/reload`.
3. **Panel look.** Bronze edges, the infinity mark by the title, dropdown rows with icons. Note any
   voice whose icon shows as a green square.
4. **Auto mode.** Say, Yell, Party, Guild and Whisper are voiced. In `/e`, only text in "quotes" is voiced. Officer and Trade are not,
   until ticked.
5. **Links.** Shift-click an item into a message. The link still works for other players.
6. **Send as typed.** Ctrl+Enter sends the message unchanged (tell me if Ctrl+Enter does not send at all). A Battle.net whisper is never changed.
7. **Preview.** The line appears above the chat box, in the right place, under each chat UI, one at
   a time: default, EllesmereUI or EUIStandaloneChat, BetterForeverChat, Prat, FlareUI, Chattynator,
   HydraUI.
8. **Shared hook.** With Prat, FlareUI and EUIStandaloneChat each enabled, a voiced message sends
   once and correctly.
9. **Autocorrect Forever.** With it on, a typo is fixed and then voiced. With its own accent set,
   the panel shows the notice and "Turn it off" works. The "Fix my spelling first" box follows it.
10. **Wheel.** Bind a key in the panel (a key already used for something else is refused with a message; clicking elsewhere cancels), hold it, flick, release. The ring is round, small and centred
    on the cursor. Does the phrase send in Say and in Yell outdoors? If the game refuses, set
    "Speak in" to Party or Guild and tell me.
11. **Boss fight.** In a dungeon boss fight, chat sends normally and unvoiced, the wheel does not
    open, and no error appears afterwards.
12. **Targets.** Target a player, then an NPC: wheel greetings use the name. In combat inside an
    instance, no error appears.
13. **Second character.** It starts matched to its own race and class, with its own settings.
