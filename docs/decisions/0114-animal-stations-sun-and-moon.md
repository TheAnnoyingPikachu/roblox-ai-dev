# 0114: Animal Stations: the Sun and Moon look, and two layouts

Status: accepted (SHANNON, 2026-11-24: "go for your choice of C and implement what youve shown me").
Tasks STATION-136, 138 to 141, 143. Date: 2026-11-24.

## Context

- Fact: the concept canvas "Intro and HUD Concepts" (https://claude.ai/artifact/SZSzdXCMvVRFCPk2UcPC4s) drew the
  same parts in three looks. SHANNON picked C.
- Fact: the Savanna look (decision 0091) already is C's ranch half: sand panels, white cards, ink outlines, a
  lip under every button.
- Fact: Roblox tells a game which input the player is using (`UserInputService.PreferredInput`) and its
  guidelines say to lay out for it and to keep the bottom corners of a phone clear.

## What

- Two surfaces, one set of shapes. At the ranch and the hub: paper and ink (`Style.C`, as before). In a fight:
  dark glass with a thin violet edge (`Style.N`, `Style.glass`), where gold is the only loud colour and always
  means "press this now". Sizes, corners and words are the same on both.
- New kit parts in `Style.luau`: `glass`, `pill` (paper over the world, soft shadow), `small` (Nunito small
  print), `icon`, `key` (a key cap), `pie` (a ring's fill), `touch` and `onInput`.
- Icons: the studio's own outlined set already uploaded for Egg Garden (`Shared.GardenIcons`, GARDEN-055), shown
  through `rbxthumb`. No new assets.
- Keys on a PC, tap bubbles on a phone. A key cap is hidden on a touch screen, and layouts change with the
  input, live. A player's `UiInput` attribute ("touch" or "keys") stands in for the device on a desktop.
- The ranch HUD has no menu to open: five buttons are always up (1 Animals, 2 Eggs, 3 Ranch, 4 Gifts,
  5 Travel), with the goal at the top (decision 0115) and To battle (B) at the bottom.

## To confirm at the checkpoint

1. The dock's keys are the numbers 1 to 5 and B. Rejected: letters, which clash with WASD and the fight's keys.
2. Reusing Egg Garden's icons. If rejected: draw a Stations set (`tools/icons`) and upload it.
