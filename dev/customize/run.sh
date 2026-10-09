#!/bin/bash
# Usage: bash dev/customize/run.sh <scene-or--s script> [user args]
G="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
until mkdir "$TEMP/echoes_godot.lock" 2>/dev/null; do sleep 5; done
trap 'rmdir "$TEMP/echoes_godot.lock"' EXIT
T="$1"; shift
"$G" --path D:/new-dev --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 $T -- --quality=1 "$@" 2>&1
