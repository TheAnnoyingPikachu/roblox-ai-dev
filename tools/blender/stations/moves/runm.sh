#!/bin/sh
# runm.sh keys|full asset-words...: render magic concepts one model at a time (word = creature_<word>_forge)
mode=$1; shift
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
for x in $*; do
  rm -rf "outm/$x/keys"
  [ "$mode" = full ] && rm -rf "outm/$x/frames"
  timeout 1500 "$B" --background --factory-startup --python render_magic.py -- creature_${x}_forge "$PWD/outm/$x" $mode > "log_m${mode}_$x.txt" 2>&1
  echo "$x $(grep -c Saved log_m${mode}_$x.txt) $(grep -E '^DONE|Traceback' log_m${mode}_$x.txt | head -1) $(grep -E '^[A-Za-z]*Error' log_m${mode}_$x.txt | head -1)"
  [ "$mode" = keys ] && python keysheet.py outm/$x m_$x.jpg
done
