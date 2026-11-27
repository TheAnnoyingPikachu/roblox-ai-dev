# Animal Stations: erasing a player's data

What to do when Roblox sends a "Right to erasure" request for a user of Animal Stations (decision 0121,
answer 35). Deleting player data needs SHANNON's approval (CLAUDE.md rule 7); this says what to delete.

## Where a player's data is

| Store | Key | What |
|---|---|---|
| `StationsProfile` (and `StationsProfile_staging`) | `player_<UserId>` | the whole save: coins, animals, eggs, upgrades, goals, receipts |
| `StationsTrades` (and `StationsTrades_staging`) | `player_<UserId>` | the player's own trade ledger: their sides of recent trades |
| `StationsBestWave` (and `StationsBestWave_staging`), an OrderedDataStore | `<UserId>` | the player's best wave, for the hub's top-100 board (decision 0129) |
| Other players' saves, `trades.log` | inside `player_<OtherId>` | the player's **display name** as the trade partner (`with`), and the animals' names |

- Fact: analytics events are aggregated by Roblox and carry no data we store.
- Fact: nothing else is stored: no other OrderedDataStore, no MemoryStore or outside service (checked 2026-11-27).

## Steps

1. **Read the request** in the Roblox messages to the experience owner. It gives the UserId and the experiences.
2. **Delete the save and the ledger** with the Open Cloud DataStore API or the Creator Hub's data store tools,
   in every universe the game runs in: `StationsProfile` and `StationsTrades` key `player_<UserId>`, and
   `StationsBestWave` key `<UserId>`, in both the plain and the `_staging` store.
3. **Partners' trade logs:** the display name stays in other players' `trades.log`. A save keeps its newest 40
   trades (`StationProgress.TRADE_LOG`), so it falls out in time; if the request needs it gone now, a `sanitize`
   change that blanks `with` in entries naming that player is the way (shipped as an update, SHANNON approving).
   Trading is off at launch (`StationTrade.ON`), so these logs are empty unless it was on in the beta.
4. **Confirm** within the time Roblox gives, and note the date and UserId in the task of the request (no other
   personal details in the repo).
