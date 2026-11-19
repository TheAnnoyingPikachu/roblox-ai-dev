# 0044: Animal Stations: a new UI with animal portraits, for desktop, tablet and phone

Status: proposed (for SHANNON at the first Animal Stations checkpoint)
Date: 2026-11-14. Builds on 0036, 0038 and 0043.

## Decision

From SHANNON: "lets start with the UI, make an appealing UI with simple navigation, animal portraits
as you said, making sure the layout works on phones and tablets as well."

- **Simple navigation.** A bottom bar with big buttons opens the screens a player needs most, from
  anywhere: Animals and Waves (it first also had Eggs, taken off by decision 0045: eggs stay at the
  ranch). The places in the world keep their jobs: the Ranch House door opens
  the upgrades (Your ranch), the egg vendor's stall opens its shop (buying), and the wave gate and
  the egg storage open their screens too. Every screen is the same kind of **sheet**: a title, a row
  of small facts, a close button (tap the dark backdrop to close too) and a scrolling body. One
  sheet is open at a time and the bar hides while one is.
- **Portraits.** Every animal, egg contents, enemy and team member is shown by a small picture of its
  own model (a ViewportFrame). The server publishes a still copy of each uploaded model in
  `ReplicatedStorage.Portraits` (`Creatures.publishPortraits`); the client frames it from the front,
  a little to the side and above (`Portrait.luau`, the distance from `UiLayout.frameDistance`).
  Portraits scrolled out of a list's window are hidden, as a picture frame costs a little every frame.
- **Cards.** Animals (portrait, rarity colour, role, group, status, six stat buttons, team button),
  eggs (colour, hatch bar and countdown), upgrades (level pips, price, button), egg vendor (egg,
  price, hatch time, portraits of what it can hatch), waves (a stepper, the enemies' portraits, the
  pay, your team's portraits, a big Fight button at the top) and the fight's result panel.
- **One layout for every screen.** All of it is laid out in design units inside one root frame that is
  scaled to the screen: `UiLayout.scale` gives 0.9 on a phone (about 890 x 400 units in landscape
  and 430 x 940 in portrait), 1.1 on a tablet and up to 1.2 on a big monitor. Cards have fixed
  sizes and wrap, so one, two or three fit across; every button is at least 44 units tall.
- **Look-at aids.** A player's `UiSize` attribute (a Vector2) stands in for the screen and `UiOpen`
  (a sheet's name) opens a sheet, so a phone or tablet layout can be looked at on a desktop.

## Why

- The first pass was plain text panels; the screens players use every minute needed to look like
  the game and to be usable with a thumb.
- Pictures of the animals tell them apart at a glance; text did not.
- One scaled root and wrapping cards make a phone, a tablet and a desktop the same code.

## Costs and limits

- Looked at on a desktop in Studio at 800 x 360, 390 x 844, 1024 x 768 and full size, not on a real
  phone or tablet: touch feel, the device's top notch and real text sharpness are not checked.
- Each portrait is a picture frame with the model's meshes (about 10 parts); a sheet shows at most
  a screenful of them at once, and all 21 models are replicated to every client.
- The hover card (desktop only) keeps its old style; touch players have no way to read an
  enemy's stats outside the wave list yet.
- Opening Eggs and Waves from anywhere on the bar is new: the wave fight itself still teleports the
  player to the arena as before.
- No sound, no animations or transitions on the sheets, no icons beyond colour accents.
