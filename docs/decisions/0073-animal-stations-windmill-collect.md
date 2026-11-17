# 0073: Animal Stations: the Windmill's coins are collected at the mill

Status: accepted (SHANNON, 2026-11-17: "1 is good 2 is good 3 is good and make collecting money from
the windmill", to the checkpoint of decision 0072). Changes decision 0072's Windmill rule. Task
STATION-068.

## What changed

- The Windmill no longer pays by itself. It fills at its coins an hour, also while its owner is
  away, until it holds eight hours' worth: then it is full and stops.
- The owner empties it at the mill: a till stands left of its door with a board that says what it
  holds ("342 coins", "20,000 coins (full)"), and a prompt, Collect. A message says what was
  collected.
- Buying a Windmill level empties it first, at the rate the coins were earned at, and the mill
  starts to fill again from then at its new rate.
- Whole coins: the time a part of a coin took stays on its clock, unless it was full.

Facts: `StationProgress.held` and `collect`, with a test; the server's `collect` request; the till
is built by `Ranch.luau` (a prompt tagged "Mill") and its board is written by the owner's client.

## The rest of that checkpoint

SHANNON accepted items 1 to 3 of decision 0072's checkpoint as they are: the draft prices and
numbers, a new ranch starting with three nests and room for eight stored eggs, and the Brooder
speeding up eggs that are already hatching.

## Not done

- Another player sees the till's board without a sum: only the owner's client knows it.
- Nothing tells a player who is elsewhere that their mill is full.
