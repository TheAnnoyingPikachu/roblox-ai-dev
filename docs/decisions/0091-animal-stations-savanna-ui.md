# 0091: Animal Stations: the Savanna UI

Status: accepted (SHANNON, 2026-11-19: "i like the look of the animal menu and agree all menus should look
like that, the palette and rarity colours are good and the rules are good", then "build it all except for the
new fight animations and stuff, go for option A with the pictures of the upgrades"); built by STATION-098.
Date: 2026-11-19. Task STATION-098.

## What SHANNON chose

From the concept pages (the player-journey page and the menu layouts page, both published as private
artifacts on 2026-11-19):

- The Savanna look for every menu: sand panels, white cards, a thick ink outline and a drop shadow under
  everything, chunky rounded buttons; sun for the main action, leaf to confirm, berry for fights and alerts,
  sky for travel and information. One set of rarity colours, used for nothing else.
- One menu frame: the menu's name and its tabs in a column on the left, the content on the right, a berry
  close button on the corner. A berry dot marks anything new.
- Ranch upgrades in three tabs of three (option A: Animals, Eggs, Earnings), each card with a picture of
  its building.
- Eggs: the Eggs menu starts eggs and shows every timer from anywhere; a ready egg opens only at the
  hatchery, as before. The menu's "Show me the way" draws a line to the egg's nest.
- Button feel: buttons lift under the pointer, squash onto their shadow when pressed and spring back; a
  greyed-out button shakes. Seven UI sounds made with ForgeGUI.

## How (facts)

- `src/stations-client/Style.luau` holds the palette (`Style.C`, `Style.RARITY`), the outlined and
  shadowed surfaces (`card`, `panel`, `button`, `chip`, `bar`, `dot`), the press motion, `Style.sound`,
  `Style.toast` and the menu frame (`Style.sheet`, `Style.tab`, `Style.pop`). Below 680 units wide (a phone
  held upright) a menu's tabs fold into a row along its top.
- `src/stations-client/Hud.client.luau` lays each menu out in the frame: Animals (tabs Your team, All,
  Training, Rainbows; a grid of small cards; a detail view with six stat tiles and the team button), Eggs
  (Hatching, In storage, a link to the vendor; free nests and the next Hatchery level), Egg vendor (one tab
  per egg), Ranch (option A), Waves (the wave picker and Fight button in the column), Trade (restyled
  only), Admin (the two admin sheets merged into two tabs).
- `Creatures.publishPortraits` now also publishes the `home_` buildings and the Speed Track's training
  areas, and `Portrait` frames a building by its bounding box.
- Sounds play on the client only (`SoundService:PlayLocalSound`). Asset ids are in
  `docs/assets/register.md`.

## Not done here

- The onboarding guide and the weekly and monthly planners: their own task, with their economy values for
  SHANNON's approval.
- The battle view's camera and cut-ins (the over-the-shoulder concept): not asked for yet.
- Trade's layout: SHANNON wants to talk it through first; it only takes the new look.
