# 0084: Animal Stations: player trading; the admin menu is SHANNON's only

Status: accepted (SHANNON, 2026-11-18: "before this can we make player trading and the admin menu
accessible to me only in all lobbies"). Changes decision 0038's admin rule. A new remote contract (the
trade requests) and a save change (animals move between saves). Task STATION-087.

## The admin menu

`isAdmin` is now one fixed account: SHANNON's (UserId 96807256), in every server and in Studio. It was
the experience's owner or anyone in Studio: a test place made by SHANNON already counted, but a place
owned by a group would have let nobody in, and Studio let any account in. The server checks it on
every admin request, as before; the button only shows for it.

## Trading

- Who: two players in the same server. One asks from the new **Trade** button on the bottom bar; the
  other gets a message and accepts or declines within 30 seconds.
- What: each side puts in up to four of their own animals (`StationTrade.MAX`). Not one that is
  training. Coins, eggs and samples are not traded.
- Agreeing: both sides see both offers. Each presses Ready; any change to either offer makes both
  unready, so nobody can swap something in at the last moment. When both are ready the server checks
  both saves again (still owned, not training, room in each Barn) and swaps.
- What moves: a copy of each animal as it is (variant, rainbow coat, stat levels) under a new id in
  the save it lands in. An animal that leaves leaves the team; the Titan's slot passes to another
  Titan if there is one.
- A trade ends if either cancels or leaves.
- New requests: `trade_ask`, `trade_answer`, `trade_put`, `trade_ready`, `trade_cancel`; new client
  events `trade_invite` and `trade`. All arguments are checked by `Payload`, and the server decides
  everything. Pure rules: `src/shared/StationTrade.luau`, with a spec.

## Known risk (before a public release)

The two saves are written one after the other. If the server crashed, or one write failed, between
them, an animal could be duplicated or lost. Egg Garden solves this with a ledger and a heal at the
next login (`src/garden/Trades.luau`); Animal Stations should copy that before a public release. For
a private test with friends it is accepted as is.

Also not built: a trade log, a limit of trades a day, any check that a trade is fair, trading with a
player in another server.
