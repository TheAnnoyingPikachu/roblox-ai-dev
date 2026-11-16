# 0066: Animal Stations: one animal to a training ground, seen at its work

Status: accepted (SHANNON, 2026-11-16: "now make animations for each animal being trained and make it
so each training ground can have 1 animal training at a time"). Task STATION-059.

## The rule (a change to the training rules)

- A station trains one animal at a time. Starting a second there, or moving one in, is refused
  (`station_busy`: "Another animal is training there: stop it first"). The ground is free again when
  its animal stops, moves to another station, or reaches level 70 in that stat.
- The Ranch House still sets how many animals train at once (2 on a new ranch, up to 6). With six
  stations and one animal each, six is now also the most that can ever train.
- A stored save that has two animals at one station keeps the first training and frees the other
  when it is read (`sanitize`); it loses no levels.

Assumption: this slows a player who used to train several animals in the same stat at once. That is
the point of the rule as asked; the numbers (level times, the Ranch House's places) are unchanged
and not rebalanced.

## What is seen

The animal that trains at a station stands in that station's area, doing its work, for as long as
it trains. It leaves the roaming field for that time, and comes back to it when it stops.

| Station | What the animal does | Where |
|---|---|---|
| Speed Track | gallops laps; from Training Grounds level 2 it leaps the three hurdles | the second lane (the dirt oval on a new ranch) |
| Strength Gym | sinks under the weight, shakes, drives up, stands | at the boulder; under the barbell from level 2 |
| Swim Pool | paddles a length, turns, paddles back | the pond; the pool's middle lane from level 1 |
| Magic Library | reads: its eyes on the book, along the lines, a paw to the page now and then | at the book on its stand; at the great book from level 1 |
| Healing Spring | lies low in the water, legs folded, breathing slowly | the spring; the first bath from level 1 |
| Guard Yard | set low against the blow, thrown back as it lands, set again | at a straw man; against the first ram from level 1 |

- Six clips (`TRAIN` in `stations-client/Creatures.client.luau`), written like the walk: every
  animal plays them, scaled to its own legs. The meerkats, which stand upright, have their own
  version of each (arms up under the bar, sitting back in the bath). The flamingo stands in the
  bath and dips its head, since its long legs do not fold.
- A reader looks at the book wherever that is from its own head: a meerkat up, an elephant down
  (`Gaze`, worked out by the server from the animal's size).
- `Areas.act` says where an animal stands and what it plays for a station and level, in the area's
  own numbers; `StationsServer` stands it there and moves the two that travel, as it moves the
  herd. When the Training Grounds are upgraded the animal is stood again in the new area.
- Display only: nothing here decides or delays any training.

## Not done

- The kit does not move: the ram does not swing, the bar does not rise, no water splashes. The
  animal alone moves.
- The Animals menu does not show which grounds are taken before a player tries one; the refusal
  says so.
- One clip a station, not one a species: a rhino and a jackal brace the same way, at their own
  size. Only the meerkats and the flamingo have poses of their own.
- The track's and pool's animals are moved by the server, like the herd, so they may step a little
  on a slow connection.
