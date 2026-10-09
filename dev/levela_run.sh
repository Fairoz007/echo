#!/bin/bash
# Level A: run godot under the shared lock. usage: levela_run.sh <timeout> [--headless] <args...>
G="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
T=$1; shift
H=""
if [ "$1" == "--headless" ]; then H="--headless"; shift; fi
until mkdir "$TEMP/echoes_godot.lock" 2>/dev/null; do sleep 5; done
trap 'rmdir "$TEMP/echoes_godot.lock" 2>/dev/null' EXIT
timeout $T "$G" $H --path D:/new-dev --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 "$@"
