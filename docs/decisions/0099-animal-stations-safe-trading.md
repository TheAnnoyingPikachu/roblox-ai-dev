# 0099: Animal Stations: safe trading

Status: accepted (SHANNON, 2026-11-19: "trading is also all go Player level 5 to trade, and 20 trades a day
Animals only A trading post at the hub (walk up to trade) as well as the Trade menu"); built by STATION-106.
Date: 2026-11-19. Task STATION-106. Builds on decision 0084 and replaces its "not one transaction" shortcut.

## What SHANNON chose

- From the safe trading plan: player level 5 to trade, 20 trades a day, animals only (no coins, eggs or
  Robux), the Trading Post at the hub (walk up: it opens Trade) as well as the Trade menu.
- **The one rule:** both sides' animals move in one step decided by the server, only after both players have
  seen the final offer and confirmed it.

## How it works (facts)

- **Ask:** in Trade, or at the hub's Trading Post. Requests to the same player wait 10 s between them. A
  player can turn requests off (saved) or block a player for the session.
- **Build:** up to 4 of your own animals; not training ones, not locked ones. Lock an animal on its page in
  Animals; a traded copy arrives unlocked.
- **Any change** unreadies both sides, flashes the changed slot berry for 5 s on both screens, and holds Ready
  for 3 s.
- **Confirm:** once both are ready the window locks. A summary shows what goes each way, and Confirm opens
  after 5 s. Giving a mythic or a rainbow animal needs a 2 s hold.
- **The fairness meter** (a guide, never a block) weighs each side by power x rarity weight (common 1,
  uncommon 1.5, rare 2.5, epic 4, legendary 8, mythic 20) x 3 for a rainbow coat. It warns when one side is
  worth under 40% of the other.
- The window shows the other player's level and how many trades they have finished, and how many trades you
  have left today. Tapping an animal's picture shows its full card (power and every stat level).
- The history (the newest 20; the save keeps 40) is under Trade.
- **The ledger** (`TradeLedger`, DataStore `StationsTrades<suffix>`, one key a player): the server checks both
  saves on copies, writes both sides, checks again and applies both with no yield between. A side whose trade
  stopped after it was written is marked cancelled. At login, every side younger than 12 hours whose id the
  save does not have (its history) is applied; `StationTrade.commit` does nothing for an id it already has,
  so the heal is safe to run again. With both saves offline (Studio) there is nothing to protect and no
  ledger; one online and one offline is refused.

## Schema and contracts

- Save (StationProgress):
  - `Animal.locked`.
  - `trades = { day, count, total, off, log }`: log entries are `{ id, with, gave, got, at }`.
  - Older saves load with none.
- Remotes:
  - New: `trade_confirm`, `trade_off`, `trade_block`, `lock`.
  - `trade` pushes now also carry `level`, `traded`, `stage`, `readyIn`, `confirmIn`, `confirmed`,
    `theyConfirmed`, `flash` and `left`.
  - New fx: `trade_done`.

## Not proven

The ledger and the heal need DataStores, so they are only proven in a published test place (rule 7: needs
SHANNON's approval to publish). A full two-player trade cannot be played in single-player Studio; the rules
are covered by `tests/StationTrade.spec.luau`.
