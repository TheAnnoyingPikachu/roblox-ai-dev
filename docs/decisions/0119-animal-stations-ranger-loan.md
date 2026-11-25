# 0119: Animal Stations: the Ranger's loan

Status: proposed (SHANNON, 2026-11-24: "Wave 10 boss, then daily"; 2026-11-25: the player picks the legend, it
replaces one animal, at max level, for one wave; the save fields and the remote wait for SHANNON's OK at the
checkpoint). Task STATION-159. Date: 2026-11-25.

## Context

- Fact: the intro (decision 0116) lends four legends for one borrowed fight; after it the player fights only with
  their own animals.
- SHANNON wanted the Ranger back: for the first boss, then once a day.

## What

- The legends are the intro's four (`StationIntro.TEAM`: Sphinx Jackal, Lava Rhino, Phoenix Flamingo, War
  Elephant). The player picks one, and which of their own fighting animals it stands in for: the War Elephant
  only for their Titan, the others only for one of their team. It fights at `MAX_LEVEL` in every stat, for one
  wave, in that animal's place (at full health, whatever the run carried for that place).
- When (`StationIntro.loanFor`): the first loan is for the first boss, wave `LOAN_WAVE` (10) only. Once it has
  been used, one loan a UTC day, for any wave. The boss's loan counts as that day's.
- The legend is never owned or saved as an animal. It is met (decision 0118) when its wave starts.
- Shared fights: each member may bring their own loan; it replaces only that member's animal.

## Save (data schema)

- `Profile.loan = { boss: boolean, day: number }`: the boss's loan is used, and the UTC day (`os.time() // 86400`)
  of the last loan. `sanitize` keeps a boolean and an integer, defaults `{ boss = false, day = 0 }`.
- Written only by `StationIntro.useLoan`, when a wave with the loan in it has started (a refused wave never uses
  it). `StationProgress.VERSION` 4 covers it with `met` (decision 0118).

## Remote contract

- New request `loan(k, replaces)`: `k` 1 to 4 (0 takes the loan back), `replaces` an animal id. The server checks
  `StationIntro.canLend` and keeps the choice in memory (`loans`, dropped when the player leaves) until the
  player's next wave it fits; refusals `loan`, `loan_used`, `loan_titan`, `loan_slot`.
- The fight's team is built by the server as before, with the legend in that animal's place. The client never
  sends stats or levels.

## Not changed

Pay, waves, boons, the intro. A loaned legend does not change what a wave pays.

## If rejected

Drop the `loan` request and the Waves card; `loan` can stay in saves unread.
