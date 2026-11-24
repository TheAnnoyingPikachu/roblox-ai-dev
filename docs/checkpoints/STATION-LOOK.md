# Animal Stations: Sun and Moon (the look, the layouts, the intro)

SHANNON, 2026-11-24: "go for your choice of C and implement what youve shown me". The concept canvas is
"Intro and HUD Concepts" (https://claude.ai/artifact/SZSzdXCMvVRFCPk2UcPC4s, 15 boards). This file is the
milestone's plan and its checkpoint list: what is built, what is left, and what SHANNON decides at the end.

## The look in one paragraph

Direction C. At the ranch and the hub: warm paper and brown ink, the Savanna kit that `Style.luau` already
is, tidied. In a fight: the same shapes in dark glass with a violet edge (`Style.N`), where gold is the one
loud colour and always means "press this now". Keys show on a PC, tap bubbles on a phone
(`UserInputService.PreferredInput`).

## Plan (one task each, in this order)

| Task | What | Boards | State |
|---|---|---|---|
| STATION-136 | The kit: night tokens and glass, icons, pills, key caps, rings, input mode, message styles | Kit | built |
| STATION-137 | Goals: the strip's rules and rewards (pure module, specs, server payout, decision 0115) | Explore, IntroOwn | built |
| STATION-138 | The ranch HUD: level and coin pills, the dock that is always up, goal strip, To battle, timers, notes | Explore | built (key caps on world prompts still to do) |
| STATION-139 | The fight in glass: plates along the bottom, the story along the top, run info; boon cards, the vote, the run's end | Fight, Result | built (not: the team mate's pill, the vote's ring) |
| STATION-140 | Menus: animals in three columns with Seen, eggs and vendor in one window with odds, the wave road, the ranch grid, the gifts' week | Animals, Eggs, Waves, RanchGifts | to do |
| STATION-141 | Moments: the hatch reveal with odds and where it goes, the level card, the server strip, the loading cover | Moments | to do |
| STATION-142 | The intro: the Ranger's loan, the fight that cannot be lost with its four lessons, the goodbye, three quick eggs, Skip (decision 0116) | Intro, IntroTaster, IntroOwn | to do |
| STATION-143 | Phone layouts of the ranch, the menus and the fight | PhoneExplore, PhoneFight | to do |

## Decisions taken on the recommended option (SHANNON reviews at the end)

1. Dock keys on a PC: 1 Animals, 2 Eggs, 3 Ranch, 4 Gifts, 5 Travel, B To battle. Rejected: letters, which
   clash with WASD and the fight's keys.
2. Icons: the studio's own outlined set already uploaded for Egg Garden (`Shared.GardenIcons`: paw, egg, home,
   gift, flag, lock). No new uploads. If rejected: draw a Stations set and upload it.
3. The loan team is the board's: Sphinx Jackal, Lava Rhino, Phoenix Flamingo, War Elephant.
4. The Ranger lends one legend again for the wave 10 boss, then once a day. (Board: "Mine: yes".)
5. "Skip intro" shows after ten seconds.

## Not in this milestone

A trade window in the new look (trading is switched off), new art or sounds, publishing (SHANNON's call
each time).
