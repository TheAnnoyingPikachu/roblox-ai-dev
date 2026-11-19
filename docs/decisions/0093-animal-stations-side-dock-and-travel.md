# 0093: Animal Stations: the side dock and travel from anywhere

Status: accepted (SHANNON, 2026-11-19: "go for the side dock with a little menu button that makes it slide
out", from the hub and UI concepts page); built by STATION-098.
Date: 2026-11-19. Task STATION-098.

## What SHANNON chose

- The four-button bar along the bottom is gone. A small Menu button on the left edge slides a dock of big
  buttons out: Travel, Animals, Eggs, Waves, Trade. A berry dot on Menu shows when any of them has news.
- Travel pops out a list: the hub, your ranch, the wave arena. The glowing teleport pads at the hub and
  inside every ranch gate are gone, with their "To your ranch" and "To the hub" signs. The roads and the
  pass are still there to walk.
- The training areas' own name boards (on the gateway arch and the board at the first level) are gone; the
  smaller signs where each path leaves the homestead name every area.
- The Egg Cellar upgrade is called Egg Storage (the cellar and its greenhouse).

## How (facts)

- Remote contract: a new request `travel` with "hub" or "arena"; the existing `home` goes to the player's
  ranch. Both leave a fight first (WaveShow.clear), as Home did.
- `Hud.client.luau` builds the dock: one column of five buttons, or two columns on a short screen (under
  560 units tall, a phone held sideways). The power plates of a fight moved to the bottom right.
- The area models were rebuilt without the boards; the level 0 to 1 piece of five areas held nothing else
  and is gone (the gym's keeps its other pieces).
