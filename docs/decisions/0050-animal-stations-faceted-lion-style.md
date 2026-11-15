# 0050: Animal Stations: the lions are faceted low-poly

Status: proposed (for SHANNON at the next Animal Stations checkpoint)
Date: 2026-11-15. Amends 0033 (animal models). Task STATION-033.

## Decision

SHANNON shared a reference picture of the Sun Lion (chunky, faceted low-poly, a mane of broad crystal
blades, big cream paws) and asked for all the lions to look like it.

- The Lion, Sun Lion and Shadow Lion are rebuilt in that style in `tools/blender/stations/assets/animals.py`
  (`poly_lion`): lofted blocky body and legs, a big head, three claws, and a mane of flat blades. Every piece
  is flat shaded (its edges are split) so the facets show in the game.
- The rig is unchanged: the same pieces (body, head, four legs, tail, glow pieces) and the same joint
  positions, so the clips and the glow handling keep working. The shapes differ, so the walk and attacks
  must be looked at in the game.
- Roughly 2,300 to 2,900 triangles each, far under the budget, and the body's texture is sharper because
  few pieces share the atlas.
- The other animals are unchanged. Whether they follow this style is SHANNON's call.

## Not done

Nothing is uploaded and `StationAssets` and the manifest are unchanged, so the game still shows the old
models until they are rebuilt and uploaded by the workflow.
