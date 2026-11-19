# 0038: Animal Stations admin menu for looking at the animals

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13.

## Decision

From SHANNON: "add an admin menu for me to spawn all the animals and have a look at them".

- An **Admin** button under the Animals button, shown only to an admin: the game's owner (the
  account that owns the place), and anyone running the game in Studio.
- Its list stands any animal or variant in front of you, or all sixteen in a row; plays idle,
  walk, attack or magic on everything it spawned; and clears them.
- These are display models only: nothing is added to a save, and the server checks the admin on
  every request, so the button being hidden is not what keeps other players out.

## Limits

- A game owned by a group has no admin outside Studio: the check is the owning user's id.
- No way yet to add other admins.
