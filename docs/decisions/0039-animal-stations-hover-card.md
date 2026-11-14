# 0039: Animal Stations: a card under the cursor for any animal

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-13.

## Decision

From SHANNON: "when you hover your cursor over an animal give it a little index box with a name
and stats and rarity colours and a health bar".

- Pointing at any animal (a ranch's herd, or one from the admin menu) shows a small card that
  follows the cursor: its name and rarity in the rarity's colour with a matching border, its role
  and group, the six stats and a health bar.
- An owned animal shows its own stats with its training; a display model shows its version's.
- Health is full for now: fights are not built. The bar reads the model's `Hp` when one is set.
- The server puts what the card needs on each model as attributes, so it works for other
  players' animals too. The cursor finds a model by an unseen box round it.

## Limits

- Hover needs a mouse. Phones and gamepads get nothing yet.
- The box is the animal's bounding box, so a little air round a thin animal also counts.
