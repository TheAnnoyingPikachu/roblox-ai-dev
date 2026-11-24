# 0111: Animal Stations: saves that never go blank or backwards

Status: accepted (SHANNON, 2026-11-24: beta blockers 5 A, 6 A, 7 A, 8 B). Task STATION-131.
Date: 2026-11-24.

## Context

- Fact: the kit ran a session whose save another server still held ("busy") on a blank 300-coin profile that
  never saves, and StationsServer passed no `onStatus`, so nothing told the player.
- Fact: every load sanitised the record with the running server's config and wrote it back, so an older build
  would drop species, variants or eggs it does not know.
- Fact: the kit's PlayerRemoving closed the session before the game banked a run's pot.
- Fact: 156 models loaded once with no retry.

## What

- `kit/Saves` `waitBusy`: a busy load is tried again every 5 s, up to `waitBusy` seconds (Stations: 120), with the
  player's `ProfileLoading` attribute set (the client's `LoadCover` says "Loading your ranch") and requests held
  (`isLoaded` false). Stations kicks a session that is not online ("couldn't load", "opened on another server";
  never in Studio, where saves are always offline).
- `kit/SaveStore` `tooNew`: a record it calls newer is never loaded, sanitised or written back; the session is
  "newer" and offline. Stations calls a save newer when its `version` is above `StationProgress.VERSION`, and kicks
  with "A new update is out". Rule: bump `StationProgress.VERSION` with every release that adds species, variants,
  eggs or coats.
- `kit/Saves` `beforeFinish`: runs before a leaving player's session closes and for everyone still in at shutdown;
  Stations banks the run's pot there.
- `Creatures.insert`: three tries, 2 s then 4 s apart, at most 8 loads at once.
- The game stays on SHANNON's account (8 B): moving it to a group later means uploading every model again.

## Not tested

The busy, newer and lost paths need real DataStores: the private test place (blocker 15).
