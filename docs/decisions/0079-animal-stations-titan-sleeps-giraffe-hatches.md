# 0079: Animal Stations: the Titan sleeps in its den; the Giraffe and the Diamond Giraffe hatch

Status: accepted (SHANNON, 2026-11-17: "make it so your active titan is asleep in the titan cave", "can
you make it lay flat with its eyes closed?", "can you add the giraffe to the admin menu and eggs
please"). Builds decisions 0075 and 0076. Task STATION-079.

## The Titan asleep

- The Titan that stands in its den plays a new pose, `sleep` (`TRAIN` in `Creatures.client.luau`): it
  lies flat, legs out front and back, its head down, breathing slowly. A "z Z z" floats over it.
- Its eyes are shut by lids: the eyes are painted into its texture, so the build now records where a
  creature's eyes are (pieces named "eye") and its brow's colour (`eyes`, `lid` in the manifest and
  `StationAssets`), and the client lays a ball of that colour over each eye, carried by the head. The
  three elephants' manifests were rebuilt for it; their uploaded models did not change.
- Fact: the "Zzz" sits in the player's gui with the Titan as its adornee: in the model it did not show.

## The Giraffe in the game

Adding it to the eggs needs a variant (every animal has one, decision 0037), so the Diamond Giraffe
concept of decision 0076 went in with it. Draft numbers (the recommendation of decision 0076):

- Giraffe: rare, utility, pack; speed 50, strength 60, stamina 45, mana 55, health 80, defence 25.
- Diamond Giraffe: mythic, twist defence.
- Safari Egg: Cheetah, Rhino, Flamingo, Lion and Giraffe 2,000 each in 10,000 (the four were 2,500);
  the Diamond Giraffe 1 in 10,000.
- Golden Egg: Lion 4,000 (was 5,000), Cheetah, Rhino and Flamingo 1,500, Giraffe 1,000, Elephant 500;
  the Diamond Giraffe 1 in 4,000.
- These two eggs now have eight rare finds: the vendor's row of them shrinks its pictures to stay one
  row.
- The roster spec now counts nine species, the Giraffe in the pack.
- The admin menu lists every species and variant, so both are in it.

## Not done

- The Giraffe uses the shared four-legged attack: no clip of its own (a head swing) yet.
- Only the elephants have eyes in the manifest so far; another animal gets them when it is next built.
- Not tried: a real Titan going to sleep after a wave, the Frost Mammoth's and War Elephant's lids, a phone.
