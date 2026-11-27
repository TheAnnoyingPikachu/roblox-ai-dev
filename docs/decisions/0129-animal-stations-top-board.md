# 0129: Animal Stations: the top-100 best-wave board at the hub

Status: accepted (SHANNON, 2026-11-27, Round 2 build 5 B: "A, plus a top-100 board at the hub for all servers",
then "do everything you can without credits for now"). Task STATION-189. Date: 2026-11-27.

## What

- Data: a new OrderedDataStore `StationsBestWave` (+ `_staging` until a production universe id is set, like the
  saves), key = the player's UserId, value = their best wave. Written when the save's `best` rises, at most once a
  minute a player, and again on leaving (`BestBoard.report`, `BestBoard.leave`). Nothing else is stored.
- Display: a wooden board on the hub between the notice board and the Hall of Fame (`STOPS.best`, 37 studs out at
  287 degrees): "BEST WAVES · ALL SERVERS", the top 100 in four columns of 25 ("1. Name  wave"), names from
  `Players:GetNameFromUserIdAsync` (cached). Each server reads the top 100 every two minutes.
- Display only: a failed read or write is logged and tried later; no save reads it.
- Data erasure: a player's entry is one more key to delete (docs/production/game7-data-erasure-runbook.md should
  list `StationsBestWave` once this is merged).

## Costs

- Fact: one ordered-store write a player at most once a minute and one sorted read a server every two minutes,
  well inside Roblox's data store limits.
