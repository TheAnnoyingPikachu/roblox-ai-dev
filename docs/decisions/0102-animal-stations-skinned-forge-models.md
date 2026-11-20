# 0102: Animal Stations: whole ForgeGUI models, skinned to our rig

Status: accepted (SHANNON, 2026-11-19: "try forge gui auto rig ... just do it for the lion for now", then
"go ahead with your idea"); built by STATION-109.
Date: 2026-11-19. Task STATION-109.

## Context

- SHANNON wants the ForgeGUI lion working in game without the model being cut into pieces in Blender.
- **ForgeGUI's auto-rig was tried first** (one paid rig call, job 6dabe42b). Its 3D provider (Meshy) only
  rigs humanoids:
  - It put a human skeleton (hips, spine, arms, two legs) into the lion, with one "thigh" bone moving 35%
    of the mesh.
  - Its clips are human (walking_man, slash, shoot, climb).
  - Its file carried a stray "Icosphere" object.
  - It is not usable for a four-legged animal.

## What

- The ForgeGUI model stays one whole mesh, every face where ForgeGUI made it.
  `tools/blender/stations/skin_forge.py` adds a skeleton with our joints' names (`body` the root, `head`,
  `leg_fl`, `leg_fr`, `leg_bl`, `leg_br`, `tail`), each bone standing where that piece turns.
- **The skin:**
  - Each vertex's weights come from where it is, blending across a band at each joint, so long pieces
    (the torso, the tail, the legs) bend there.
  - A small loose island (the faceted mane's shards, under 0.06 of the model's size) takes its average
    weights, so it moves whole and never stretches.
  - Checked in Blender renders of bent poses.
- **In game:**
  - The asset is marked `skinned` (with `root`, where its `body` bone stands).
  - `Creatures.build` welds the one mesh to the Root and makes no Motor6Ds.
  - `Creatures.client` drives the bones' `Transform` with the same poses it gives Motor6Ds, turned from
    the Root's axes into each bone's. So every clip, the fight timings, hit-stop and slow motion work
    unchanged.
  - The feet-on-the-ground correction works only on jointed models; a skinned model goes without it.
- The asset is `creature_lion_forge`: the ForgeGUI (Meshy) lion, scaled to the old lion's length (13
  studs). It has its own rainbow coat. Once it was checked in Studio it became the lion
  (`StationRules.assetOf`); the old jointed `creature_lion` stays uploaded as the fallback.

## The second lion (same day)

- **What was wrong with the first lion:** the first ForgeGUI lion (job 01398b24) looked fractured in game.
  - It was 3,585 loose shards, and about a third of its faces pointed inward (Roblox draws only fronts,
    so those showed as holes).
  - Its texture was a mosaic of about 3,600 tiny pieces, each with its own painted light and dark. At
    Roblox's 1024 texture size their edges blur into cracks.
- **The replacement:** SHANNON made a new one on the ForgeGUI site ("Low poly, Game-ready, Stylized
  roblox lion with NO baseplate", artifact 4fffb41e). It is 2,961 faces, one object, no baseplate, and
  joins into a single closed piece. It replaces the first as `creature_lion_forge`.
- **`tidy` in skin_forge.py:**
  - Joins the vertices ForgeGUI exports loose.
  - Turns each face outwards (rays from both sides).
  - Sets the shading: flat for a low-poly model.
- `Creatures.build` draws a skinned mesh two-sided (`MeshPart.DoubleSided`) in case a thin piece remains.
- ForgeGUI's own animation (the paid route) stays the fallback if this rig is not good enough.

## The jackal and the tortoise (same day)

- SHANNON asked for as many animals as the credits allowed, base animals first, then varieties, then
  enemies, and to see each model before it was rigged.
- Each model at high quality costs 4,000 credits. Three were made (jackal, tortoise, meerkat) before the
  account ran out (3,476 left). The other prompts were not charged.
- SHANNON saw them on a preview page and chose the jackal and the tortoise. The meerkat was left out: its
  dark back bands came out as scattered black triangles in its texture.
- Both are single pieces with no baseplate. Each has its own weights (`jackal_weights`,
  `tortoise_weights` in skin_forge.py, from measured leg and tail columns) and smooth shading.
- The tortoise is thinned to 5,000 triangles. The jackal stays at full detail (14,103): thinned, its
  smooth shading showed dark patches.
- The jackal's faces are not re-turned (`turn: False`): they already face out, and the ray test misread its
  thin ears and neck.
- `StationRules.FORGE` now lists the jackal, the lion and the tortoise. Their varieties keep the Blender
  models.

## The Pharaoh Jackal (same day)

- SHANNON made three more jackals on the ForgeGUI site.
- "anubis jackal" (artifact 4f9138bf) is one jackal: black with purple crystal shards, solid all round, no
  baseplate, 5,130 triangles. SHANNON chose it as the Pharaoh Jackal ("Pharaoh Jackal (Recommended)").
  It replaces the black-and-gold Blender look. Its weights are `anubis_weights`, shading flat (the lion's
  style).
- The other two held three jackals in a row (plain, Pharaoh, Sphinx) in one model: one on rock bases,
  one only an eighth as deep as it is long. Neither can be rigged. They are to be made again one jackal
  per model.
- `StationRules.FORGE` takes a variant's id as well as a species', so a variant can have a ForgeGUI
  model: `pharaoh_jackal` is `creature_jackal_pharaoh_forge`.
- The tortoise's first texture never loaded in Studio (the rainbow coat from the same upload did); a
  second upload loaded.

## The Pharaoh Jackal again (same day)

- SHANNON did not want the purple Anubis as the Pharaoh ("no not that one"), nor three jackals cut from
  the row model ("get rid of the jackals you just did"). Asked for "the one made just after the image
  with the three and the standing model": the "Low-Poly Anubis Guardian in Gold and Blue" (artifact
  518bf4a5, 22:49).
- It is a four-legged black jackal with a blue-and-gold striped headdress, gold bands, small folded wings
  and an ankh, with no baseplate and 3,135 triangles. It is the Pharaoh Jackal now, under the same asset
  name, and the purple Anubis is gone from the game (`pharaoh_weights` replaces `anubis_weights`).
- Then SHANNON: "rig the latest two models as well, the sandy sphinx and regular version. it should only
  be these three jackals in the game". The Jackal is now the "Low-Poly Anubis with Egyptian Headdress"
  (artifact d3835931, 22:52): sandy, with a striped headdress, gold bands and a blue-and-gold tail, 3,089
  triangles, under the old name `creature_jackal_forge`. The jackal made earlier (job c93507d6) is gone.
  The Sphinx Jackal is the "Sphinx variant" (artifact dd7695be, 22:51): a sandy lion's body with a
  sphinx's face and striped headdress, 5,271 triangles, `creature_jackal_sphinx_forge`.
- So the three jackals (the Jackal, the Pharaoh and the Sphinx) are all SHANNON's ForgeGUI models, flat
  shaded in the lion's polygon style.
- Then SHANNON: "do it for the two most recent jackal models, get rid of both of those jackals apart from
  the middle one", after seeing them ("yes rig these two"). The Jackal is now the "Low-Poly Jackal in
  Profile" (artifact 0a34fc4d, 23:00): tan with a black saddle, 5,027 triangles. The Sphinx Jackal is the
  "Low-Poly Anubis Statue" (artifact 54ef40ce, 22:58): a sandstone jackal with a striped headdress, 4,950
  triangles. The 22:52 jackal and the 22:51 human-faced Sphinx are gone; the Pharaoh (22:49) stays.

## The rhinos (same day)

- SHANNON: "now rig the rhinos, the regular one the crystal one and the first lava one".
- The Rhino is the "Low-Poly Rhino using this reference" (artifact 9f6a531e, 23:06, 3,040 triangles).
- The Crystal Rhino is the "Rainbow Crystal Rhino" (artifact f70447fd, 23:08, 5,096 triangles).
- The Lava Rhino is the first "Molten Lava Rhino Warrior" (artifact f93e493b, 23:09, 14,087 triangles).
  The later lava ones (23:12, 23:20) are not used.
- The three share one body plan, so one weights function (`rhino_weights`) and one joint layout
  (`rhino`) serve all three; only the length, the tail's start and the legs' top differ.

## The tortoises (same day)

- SHANNON: "now rig one of each tortoise, it doesnt matter what gem version you choose".
- The Tortoise is the "Low-Poly Stone Tortoise" (artifact ea214a64, 23:25, 3,047 triangles), in place of
  the tortoise generated earlier (job bfdcf1b3, whose thinning and smooth shading went with it).
- The Island Tortoise is the 23:27 "Low-Poly Stone Tortoise" (artifact e1ded7d6), a tortoise carrying a
  jungle island (2,933 triangles).
- One body plan for both: `tortoise_weights` and `tortoise`.
- No gem tortoise was found among SHANNON's ForgeGUI models at first (searched "tortoise", "gem",
  "shell", "turtle"). The 23:31 and 23:32 models, named "Stone Tortoise" and nothing, came out as a
  meerkat and a green alien creature.
- SHANNON then made one ("Rainbow Gemstone Tortoise" as the reference) and downloaded it as
  `now-make-this-in-the-roblox-style.glb`: a dark purple tortoise with rainbow gems in gold frames on its
  shell, crystals along the top and gem bands on its legs, 5,156 triangles. It is the Gemshell Tortoise
  (`creature_tortoise_gemshell_forge`), on the same tortoise body plan.

## The meerkats (2026-11-20)

- SHANNON: "now rig the three most recent meerkat models, show me what models first as well", then "yes
  rig these three models please".
- The Meerkat is the 23:47 model (artifact 836fe118): tan with dark stripes and a ringed tail, 15,187
  triangles.
- The Star Meerkat is the 23:46 model (artifact 5d3b0709): its prompt asked for the alien meerkat, but it
  came out as a star meerkat (purple with gold stars, a gold crest, a comet tail), 4,983 triangles.
- The Storm Meerkat's place takes the 23:45 Alien Meerkat with UFO Tail (artifact 1f8645af), 14,552
  triangles. Its name stays "Storm Meerkat" (SHANNON was asked and said to rig the three as shown).
- Then SHANNON: "can you quickly rename the alien meerkat and commet meerkat as well". The Storm Meerkat
  is now the Alien Meerkat and the Star Meerkat the Comet Meerkat. Their ids (`storm_meerkat`,
  `star_meerkat`) stay, so saves, eggs and odds are unchanged.
- They stand upright: `meerkat_weights` gives the legs everything below the hips, the arms what hangs in
  front of the belly between the hips and the shoulders, the head everything above the neck, and the
  tail what is behind the rump below the shoulders (a crest down the back is the head's). They are
  scaled by height (`height`), not length. `Creatures.build` makes them upright (Biped) because their
  shoulder joints stand more than twice as high as their hips.

## The cheetahs (2026-11-20)

- SHANNON: "ok now rig the cheetahs".
- The Cheetah is the 23:40 "Angular Roblox-Style Cheetah with Glowing Eyes" (artifact 1a08317f): golden
  with square spots and a ringed tail, 5,102 triangles.
- The Lightning Cheetah is the 23:54 storm-cloud cheetah (artifact 91e6733c): blue clouds, a spiky cloud
  mane, lightning down its legs and a storm cloud for a tail tip, 14,869 triangles.
- The 23:51 model (the same prompt as 23:40) came out as a cluster of several small cheetahs in one model
  (209 loose pieces) and is not used. No fire cheetah was made, so the Fire Cheetah keeps its Blender
  model.
- Both use `quad_weights`, a four-legged layout built from each model's measurements.
- Then SHANNON: "the three cheetahs should all be the new models, get rid of the fire cheetah for
  whatever lightning or thunder cheetah isnt in yet", and of the 23:51 model's big cheetah: "yes thats the
  lightning cheetah".
  - The Lightning Cheetah is now the big cheetah of the 23:51 concept sheet (artifact d4747ca8): cut out
    on its own (the small views beside it left out) and turned 69.4 degrees to stand straight. Golden
    with black spots and spiky lightning shards, 1,991 triangles. Its legs stand close under it, so
    `feet_weights` gives each leg what lies near its own foot.
  - The storm-cloud cheetah (23:54) takes the Fire Cheetah's place as the Thunder Cheetah
    (`creature_cheetah_thunder_forge`). The variant keeps its id `fire_cheetah` (saves, eggs and their
    odds are unchanged); only its name is now "Thunder Cheetah" (`StationConfig`, the roster in
    `game7-animals.md`).

## The flamingos (2026-11-20)

- SHANNON: "ok now rig the flamingos and rename them if necessary for example king flamingo for peacock
  flamingo, dont change the pheonix flamingo".
- The Flamingo is the 00:02 pink flamingo (artifact c9dca2cc, 5,001 triangles).
- The King Flamingo (the Peacock Flamingo renamed; id `peacock_flamingo` kept, so saves, eggs and odds
  are unchanged) is the 00:03 peacock flamingo with a crown (artifact a84542a7, 14,686 triangles).
- The Phoenix Flamingo (name unchanged) is the 00:04 Flamingo of Fire (artifact 675a6361, 15,029
  triangles).
- `flamingo_weights`: the game builds a flamingo's wings as its back legs, so the wing feathers on the
  body's sides follow `leg_bl` / `leg_br`; each leg follows the column it stands on (the pink one stands
  with its right leg further back); the neck and head follow the head joint at the neck's foot; the
  fan or flames behind are the tail. Loose feathers and flames under `small` move whole (0.12 for the
  King, 0.25 for the Phoenix), so they do not stretch. Scaled by height, as they stand tall.

## The lions (2026-11-20)

- SHANNON: "rig the lions and make sure you use the second model for the shadow and sun lion and the
  latest regular lion model", then, after seeing the picks, "yes rig those lions".
- The Lion is the 00:19 regular lion (artifact c46416c2): tawny with a red-brown spiky mane, 5,222
  triangles. It replaces the 22:03 lion (artifact 4fffb41e) and its `lion_weights`.
- The Shadow Lion is the 00:13 Shadowfang Purple Lion (artifact 68e2e5b5), the second of the two
  crescent shadow lions (00:11, 00:13): near-black, purple mane, a crescent on the tail, 15,063 triangles.
- The Sun Lion is the 00:17 Sunmane (artifact efa580ee), the second of the two sun lions (the 00:15 one
  was asked for as "Shadowfang" but came out a sun lion): golden, a flame mane, a sun on the tail tip,
  3,156 triangles.
- One body plan: `lion` (with `quad_weights`).

## The giraffes (2026-11-20)

- SHANNON: "rig the giraffes as well", then "make a new spot for the acacia giraffe and add it to the
  eggs and such" (decision 0103).
- The Giraffe is the 00:24 giraffe (artifact c2e4bf29, 5,192 triangles); the Diamond Giraffe the 00:26
  one (artifact f1abf347, 3,152 triangles); the new Acacia Giraffe the 00:31 one with acacias growing on
  it (artifact 6e93bd49, 15,066 triangles, its 300 loose leaves moving whole).
- Giraffes stand tall, so they are scaled by height. Their head joint is the neck's foot, as on the
  Blender giraffe, so the head swings the whole neck (and the acacias on it).

## The elephants (2026-11-20)

- SHANNON: "rig the elephants, do the second regular elephant model the only snow mammoth one and the
  last war elephant that was generated".
- Of the models made 00:41 to 00:57: 00:41 the Frostfur Mammoth (the only snow one); 00:43, 00:46 and
  00:51 armoured war mammoths; 00:50 an axe on its own; 00:56 and 00:57 plain elephants (asked for as
  armoured mammoths, made from the "Faceted Elephant" picture).
- The Elephant (the Titan) is 00:57, the second plain one (artifact fc30d94a, 4,817 triangles). The Frost
  Mammoth is 00:41 (artifact 29d6a1a2, 5,316 triangles). The War Elephant is 00:51, the last war one
  (artifact 90a97f25, 5,298 triangles).
- The head takes everything ahead of the shoulders: ears, trunk, tusks, the War Elephant's trunk axe.
- The sleeping Titan's eyelids come from eye pieces the Blender model recorded (decision 0079); a skinned
  model has none, so it sleeps without them (its "Zzz" still shows).
- SHANNON: "give all the titans better resting positions/animations for being in the titan den". The
  den pose (`sleep` in Creatures.client, four-legged branch) is now a loaf: front legs out along the
  floor, hind legs tucked under the belly, the body down 0.75 of the front legs' height, the head up 30
  degrees so the trunk, tusks and the War Elephant's axe lie forward on the floor instead of through it.
  It breathes slowly, sighs every 13 s (head and body lift a little and settle) and flicks its tail.
  The old pose splayed the legs straight out front and back. skin_forge.py's test renders show it as
  `den` for the elephants.

## Facts

- The sources are in `assets/stations/sources/creature_<animal>_forge.glb`: the lion (ForgeGUI artifact
  4fffb41e), the jackal (job c93507d6) and the tortoise (job bfdcf1b3).
- 2,961 triangles, 1,484 vertices once joined, one piece; one 1024 texture.
