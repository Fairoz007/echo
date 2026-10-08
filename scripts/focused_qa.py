"""Focused engine regressions. Passing these does not certify a finished game."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
GODOT = r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
TESTS = ["qa_hud_timers.gd", "qa_progression.gd", "qa_save_restore.gd", "qa_audio_references.gd", "qa_menu.gd", "qa_prologue_input.gd", "qa_mara_motion.gd", "qa_checkpoint_flow.gd", "qa_combat_cover.gd", "qa_water_input.gd", "qa_exploration_persistence.gd", "qa_graphics_profiles.gd"]

def main():
    evidence = []
    failed = []
    for test in TESTS:
        try:
            process = subprocess.run([GODOT, "--headless", "--path", str(ROOT), "-s", "res://scripts/" + test], capture_output=True, text=True, timeout=35)
            output = process.stdout + process.stderr
            bad = process.returncode != 0 or bool(re.search(r"SCRIPT ERROR:|ERROR:|Parse Error:", output)) or "QA PASS:" not in output or "\x00" in output
        except subprocess.TimeoutExpired as error:
            output = "TIMEOUT: test exceeded 35 seconds\n" + str(error.stdout or "") + str(error.stderr or "")
            bad = True
        evidence.append(f"=== {test}: {'FAIL' if bad else 'PASS'} ===\n{output}")
        print(evidence[-1], flush=True)
        (ROOT / "docs" / "focused_qa_latest.log").write_text("\n".join(evidence), encoding="utf-8")
        if bad:
            failed.append(test)
    (ROOT / "docs" / "focused_qa_latest.log").write_text("\n".join(evidence), encoding="utf-8")
    print(f"Focused checks: {len(TESTS)-len(failed)}/{len(TESTS)} passed. Human playthrough/visual QA remain required.")
    return bool(failed)

if __name__ == "__main__":
    sys.exit(main())
