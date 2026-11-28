#!/bin/bash
# The pipeline from a model to its board, for one creature: run_creature.sh <creature dir> "<title>" [clip set]
# <dir> holds raw.glb (the model). Its landmarks are measured (autoland.py -> species.json) unless a species.json is
# already there; writes split/, rig/, board/ under it. The remeshed body is only a weight proxy: the model itself,
# tidied, is what is rigged and shown (transfer_rig.py). NOKIT=1: no armour split (always, now the model is kept whole).
set -e
C="$1"; T="$2"; SET="${3:-quad}"; P="$(cd "$(dirname "$0")" && pwd)"
B="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"  # needs uv on the PATH too (for Pillow)
W=$(cygpath -m "$C")
AL=autoland.py; [ "$SET" = meerkat ] && AL=autoland_up.py  # (an upright animal is measured its own way)
[ -f "$C/species.json" ] || "$B" -b --factory-startup -P "$P/$AL" -- "$W/raw.glb" "$W/species.json" "$SET" 2>&1 | grep -E "AUTOLAND|rror|Trace"
[ -f "$C/species.json" ] || { echo "no landmarks: stopped"; exit 2; }
NOKIT=1 "$B" -b --factory-startup -P "$P/split_remesh.py" -- "$W/raw.glb" "$W/split" ${VOXEL:-0.0125} 0 2>&1 | grep -E "SPLIT|rror|Trace"
NORENDER=1 "$B" -b --factory-startup -P "$P/quadrig.py" -- "$W/species.json" "$W/split/body.glb" - "$W/rig" 2>&1 | grep -E "POLE|rror|Trace" | tr '\n' ' '; echo
T=$("$B" -b "$W/rig/rig.blend" -P "$P/transfer_rig.py" -- "$W/raw.glb" "$W/rig/rig_full.blend" 2>&1 | grep -E "TIDY|WEIGHTS|HOLES|rror|Trace")
echo "$T"
rm -rf "$C/board/clips" "$C/board/rom" "$C/board/bones"
"$B" -b "$W/rig/rig_full.blend" -P "$P/clips.py" -- "$W/board/clips" "$SET" 2>&1 | grep -E "CLIP|rror|Trace"
"$B" -b "$W/rig/rig_full.blend" -P "$P/rom.py" -- "$W/board/rom" 2>&1 | grep -E "ROM|rror|Trace" | awk '{print $NF}' | tr '\n' ' '; echo
"$B" -b "$W/rig/rig_full.blend" -P "$P/bones.py" -- "$W/board/bones" 2>&1 | grep -E "BONES|rror|Trace"
BOARD_TITLE="$T" uv run -q --with pillow python "$P/build_board.py" "$W/board"
