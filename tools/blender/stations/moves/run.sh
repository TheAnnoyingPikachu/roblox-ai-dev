#!/bin/sh
# run.sh keys|full [animals...]: render each animal in turn (several EEVEE renderers at once hang the GPU)
mode=$1; shift
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
for a in "${@:-jackal tortoise meerkat cheetah rhino flamingo lion giraffe elephant}"; do
  for x in $a; do
    rm -rf "out/$x/keys"
    timeout 900 "$B" --background --factory-startup --python render.py -- creature_${x}_forge "$PWD/out/$x" $mode > "log_${mode}_$x.txt" 2>&1
    echo "$x $(grep -c Saved log_${mode}_$x.txt) $(grep -E '^DONE|Traceback' log_${mode}_$x.txt | head -1)"
  done
done
