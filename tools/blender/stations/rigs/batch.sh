#!/bin/bash
# Every creature folder under <root> that has a model and no board yet, one after another (an overnight run):
# batch.sh <root>. A folder's clip set is the "clips" of its species.json, else its `clips` file's one word, else quad;
# its title is its folder's name. Renders one at a time: several at once hang the GPU.
P="$(cd "$(dirname "$0")" && pwd)"
for d in "$1"/*/; do
  d="${d%/}"
  [ -f "$d/raw.glb" ] && [ ! -f "$d/board/index.html" ] || continue
  set="quad"
  [ -f "$d/clips" ] && set="$(tr -d '[:space:]' < "$d/clips")"
  [ -f "$d/species.json" ] && set="$(python -c "import json,sys;print(json.load(open(sys.argv[1])).get('clips') or 'quad')" "$d/species.json")"
  echo "=== $(basename "$d") ($set)"
  bash "$P/run_creature.sh" "$d" "$(basename "$d")" "$set" > "$d/run.log" 2>&1 && grep -E "^CLIP" "$d/run.log" | awk '{print $2, $5}' | tr -d ',' | sort -k2 -n -r | head -1 || echo "FAILED: see $d/run.log"
done
