# 0055: Animal Stations: the meerkats, tortoises and flamingos, and a new variant of each

Status: proposed (concepts for SHANNON; nothing is in the game yet)
Date: 2026-11-15. Builds on 0050 to 0054 (the lions, elephants, jackals, cheetahs and rhinos). Task STATION-043.

## Decision

SHANNON, while the rhinos were being reworked: "after this commence concepts for the rest of the
animals". The rest are the meerkats, the tortoises and the flamingos, the last animals on the old
smooth models. Each family is built like the rhinos (flat face tones under a surface texture) and
gets one new variant in the tier it lacks, as the other families did.

- Meerkats (`assets/meerkats.py`). They now stand upright, a sentinel (the old one walked on four
  legs): a pear of a body with a pale belly, short haunches over long feet, thin arms held at the
  chest, a pointed face with dark eye patches, a long thin tail propped behind. The arms are the
  rig's "front legs" and the legs it stands on the "back legs", so the joints are the usual ones.
  - Meerkat: sandy, cream belly, dark bands across the back, amber eyes. 1,692 triangles.
  - Storm Meerkat (legendary, as now): thundercloud coat, Neon forked lightning down the back, a ruff
    of cloud, a crest of sparks, bolts from the shoulders, a ball of lightning between the paws, a
    charged tail. 2,000 triangles.
  - Star Meerkat (new, proposed mythic, twist speed): a coat of night sky (deep violet with a sparkle
    of far stars), Neon gold stars joined into constellations, a great star on the chest, a ring of
    stars round the head, a comet for a tail tip. 2,132 triangles.
- Tortoises (`assets/tortoises.py`): a high dome of six-sided plates, each a mound in tiers (four down
  the spine, four down each flank, sixteen round the rim), thick scaly legs splayed out, a wrinkled
  neck, a blunt head with a hooked beak.
  - Tortoise: olive, plates of horn (dark at the edge, pale on top), bone spikes round the rim.
    2,428 triangles.
  - Gemshell Tortoise (legendary, as now): a midnight shell set with cut rose gems in gold settings
    (the four down the spine Neon), rose and violet gems with gold beads round the rim, teal skin,
    gold claws and beak. Told apart from the Crystal Rhino: cut jewels in settings, one colour family,
    against raw crystals of every colour growing from rock. 3,556 triangles.
  - Island Tortoise (new, proposed mythic, twist health): mossy stone plates with grass on top, and
    an island on its back: an acacia with a flat crown and Neon fruit, rocks, tufts of grass, Neon
    flowers; vines hang from the rim, a sprout grows on its head. 3,292 triangles.
- Flamingos (`assets/flamingos.py`): a plump feathered body on two stilts with webbed feet, a neck in
  an S, a heavy hooked beak, folded wings (the rig's "back legs", as before) with rows of feathers.
  - Flamingo: pink, coral wings, black flight feathers, a pale beak with a black hook. 1,350 triangles.
  - Phoenix Flamingo (mythic, as now): fire-red with a gold neck, a Neon crest, flight feathers and
    long tail streamers of flame, gold flames up the breast. 1,478 triangles.
  - Peacock Flamingo (new, proposed legendary, twist stamina): teal with a royal blue neck, emerald
    wings with bronze flight feathers, a great fan of eleven tail feathers each with a Neon eye, a
    crest of three beaded plumes. 1,614 triangles.
- Sizes (wide x tall x long, studs), each scaled to the model it replaces where there is one:
  Meerkat 2.0 x 4.8 x 4.9 (upright: it was 2.1 tall and 4.6 long), Storm Meerkat 3.5 x 6.7 x 6.3,
  Star Meerkat 2.7 x 7.5 x 6.8; Tortoise about 5.9 x 3.6 x 9.0, Gemshell 7.8 x 4.8 x 12.0, Island
  8.6 x 9.9 (with its tree) x 13.9; Flamingo 2.0 x 8.0 x 5.9, Phoenix 3.5 x 11.3 x 10.3, Peacock
  5.6 x 9.8 x 7.0.
- `facet.py` gains two surfaces (`fur`, `scales`) and `lump` (a rock, a puff of cloud, a clump of
  leaves), moved out of `rhinos.py`. `assets/animals.py` keeps only the helpers the enemies
  (`foes.py`) are still built on; it builds no animal now.

## Open for SHANNON

- Approve the nine looks, or ask for changes.
- The three new variants: the ideas, their names, tiers and twists. Their place in the eggs is
  decided with the egg overhaul (decision 0056).
- The upright meerkat. The smaller option is to keep it on four legs like the old one; upright reads
  as a meerkat at a glance, but its clips (walk, attack) will need fitting.

## Not done

Concepts only: nothing is uploaded, `StationAssets` and the manifest are unchanged, and the game
still shows the old models. The clips have not been seen on the new shapes; the meerkat's will need
the most work. Each family had one or two rounds of looking at its card, not the many the lions had.
