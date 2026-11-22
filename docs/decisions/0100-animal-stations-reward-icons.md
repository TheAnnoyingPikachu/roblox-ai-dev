# 0100: Animal Stations: reward icons

Status: accepted (SHANNON, 2026-11-19: "all the icons are go", from the reward icons concept page); built by
STATION-107.
Date: 2026-11-19. Task STATION-107.

## What

- One picture for each kind of reward, in the Savanna look (thick ink outline, warm colours): coins, samples,
  each egg in its own colours (Meadow, Wild, Safari, Golden), a gold star for "your best egg", hatching x2,
  training x2, the rainbow paw, the wheel and a gift. The outlined sticker finish (the page's
  recommendation).
- Where they show:
  - The weekly and monthly planner cards: the icon above the words. A second, smaller icon sits at its foot
    for what comes with it (samples with coins, a boost with an egg), and the star marks the best egg. The
    month's rainbow animal keeps its own picture.
  - The wheel's slices: the icon and a short caption.
  - The toast after a reward, a wheel prize or a boss chest.

## How (facts)

- Made by `tools/icons/stations_rewards.py` (SVG rendered to 256 x 256 PNG with a clear background by Edge
  headless) into `assets/stations/icons/`.
- Uploaded with Studio's image upload. The ids are `ICON` in `Hud.client.luau` and are listed in
  `docs/assets/register.md`.
- `Style.toast` takes an optional image in place of its round sign.
