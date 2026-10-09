#!/bin/bash
# Run one Godot script under the shared lock (compat/opengl3). usage: run_one.sh <timeout> <script> [user args...]
G="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
T=$1; S=$2; shift 2
until mkdir "$TEMP/echoes_godot.lock" 2>/dev/null; do sleep 5; done
trap 'rmdir "$TEMP/echoes_godot.lock" 2>/dev/null' EXIT
timeout $T "$G" --path D:/new-dev --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 -s $S -- "$@"
