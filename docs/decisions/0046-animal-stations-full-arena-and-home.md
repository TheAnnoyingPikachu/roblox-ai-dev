# 0046: Animal Stations: the full, menacing arena, and a Home button

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-14. Builds on 0045. The Breach, heads and columns are added by decision 0047.

## Decision

From SHANNON: "make the arena area full, give it lots of good detail and make it feel menacing and
such", and, while it was being built, "add a button to the ui that lets you teleport right to base".

- **The arena is built in its own module** (`Arena.luau`, about 900 parts, a fixed seed) and runs the
  length of the pit, from the mouth to the Hexbound's gate, 190 studs:
  - **Walls** of dark brick down both sides, with crenellations, buttresses topped with bone horns and
    glowing eyes, tattered red banners with violet sigils, skulls set in the wall face, leaning iron
    stakes at the foot, and braziers (warm orange near the team, violet near the gate).
  - **A gatehouse** where players come in: two brick towers with burning braziers, a raised portcullis
    and, over the arch, a huge horned skull with glowing eyes.
  - **The floor:** paving with violet cracks leaking light, scorch marks and old blood, a glowing blue
    dais for the team (steps, a ring and four lantern posts) and, in front of the gate, a violet summoning
    circle with runes where the enemies step out.
  - **The Hexbound's gate:** towers with horns, a lintel with spires, fangs, a glowing eye, hanging
    chains and a shimmering violet portal in a neon frame.
  - **Menace:** six stone demon-knight statues on plinths, gallows with hanging cages that hold a glowing
    soul, bone piles, spears with torn pennants, rubble, drifting embers, falling ash and low mist.
  - **A dusk** (`ArenaMood.client.luau`): walking into the canyon fades this player's light from the hub's
    bright day to a low violet dusk with heavier haze and glow, and back out again. It changes only the
    local player's Lighting.
- **Deeper in.** The team's dais moved from 40 to 75 studs in and the enemies' gate from 140 to 190, so
  the enemies have a longer walk out of the portal and the fight camera has room behind the team. The
  camera now looks from higher (38 degrees) and further round (40 degrees), over the walls, not
  from behind the gatehouse.
- **A Home button** on the bottom bar (Animals, Waves, Home): one tap teleports the player to their own
  ranch's gate, leaving a fight and its camera if they are in one (the fight's result still shows).

## Why

- The canyon was a stage with a back wall; now it is a place, and one that looks like what lives
  at its end.
- A phone player should not have to run a road to get home.

## Costs and limits

- About 900 more parts and about 25 lights and emitters in a world that is loaded whole on joining
  (StreamingEnabled is off): measured nowhere but a desktop in Studio, not on a phone.
- The fight camera can still be crossed by a gallows or a banner when a fight is very wide.
- The bone horns on the buttresses read as plain planks from above.
- The dusk fades by distance, not by the fight, so a player who walks into the canyon between fights also
  gets it. This is wanted, but it is not the same as a fight-only mood.
- Home has no cooldown and works anywhere, including the middle of a fight.
