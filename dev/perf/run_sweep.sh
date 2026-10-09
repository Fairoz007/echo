#!/bin/bash
# Runs dev/perf/preset_sweep.gd for presets given (default 0..4) under the shared lock, one Godot at a time.
# usage: dev/perf/run_sweep.sh <tag> [presets...]   logs -> dev/perf/logs/<tag>_q<N>.log
G="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
TAG=$1; shift
P=${@:-0 1 2 3 4}
mkdir -p /d/new-dev/dev/perf/logs
for q in $P; do
  until mkdir "$TEMP/echoes_godot.lock" 2>/dev/null; do sleep 5; done
  timeout 400 "$G" --path D:/new-dev --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 -s res://dev/perf/preset_sweep.gd -- --quality=$q $SWEEP_ARGS > /d/new-dev/dev/perf/logs/${TAG}_q$q.log 2>&1
  rmdir "$TEMP/echoes_godot.lock"
done
grep -h "SWEEP|" /d/new-dev/dev/perf/logs/${TAG}_q*.log
