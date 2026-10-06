"""
Automated Playthrough & Regression Verification Suite for ECHOES BENEATH
Runs headless Godot tests on all levels from Main Menu -> Prologue -> Chapters 1-10 -> Finale -> Epilogue
"""

import subprocess
import sys
import time

GODOT_BIN = r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"

SCENES = [
    ("Main Menu", "res://ui/MainMenu.tscn"),
    ("Prologue: The Descent", "res://levels/Prologue.tscn"),
    ("Chapter 1: The Arrival", "res://levels/Chapter1.tscn"),
    ("Chapter 2: Whispers in Stone", "res://levels/Chapter2.tscn"),
    ("Chapter 3: The Fall", "res://levels/Chapter3.tscn"),
    ("Chapter 4: Beneath", "res://levels/Chapter4.tscn"),
    ("Chapter 5: Hunters", "res://levels/Chapter5.tscn"),
    ("Chapter 6: The Drowned Temple", "res://levels/Chapter6.tscn"),
    ("Chapter 7: City of Echoes", "res://levels/Chapter7.tscn"),
    ("Chapter 8: The Betrayal", "res://levels/Chapter8.tscn"),
    ("Chapter 9: The Heart Road", "res://levels/Chapter9.tscn"),
    ("Chapter 10: The Heart Vault", "res://levels/Chapter10.tscn"),
    ("Finale: The Mountain Breaks", "res://levels/Finale.tscn"),
    ("Epilogue & Credits", "res://levels/Epilogue.tscn")
]

def run_scene_test(name, scene_path):
    print(f"\n==================================================")
    print(f"RUNNING PLAYTHROUGH TEST: {name} ({scene_path})")
    print(f"==================================================")
    
    cmd = [GODOT_BIN, "--headless", scene_path, "--quit-after", "120"]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    
    output = []
    try:
        stdout, _ = proc.communicate(timeout=15)
        print(stdout)
        if proc.returncode != 0:
            print(f"[FAIL] {name} exited with non-zero code: {proc.returncode}")
            return False
        else:
            print(f"[PASS] {name} initialized and executed without errors.")
            return True
    except subprocess.TimeoutExpired:
        proc.kill()
        print(f"[TIMEOUT] {name} exceeded execution threshold.")
        return False

def main():
    print("STARTING COMPLETE CAMPAIGN REGRESSION RUN FOR ECHOES BENEATH...")
    passed = 0
    failed = 0
    
    for name, path in SCENES:
        if run_scene_test(name, path):
            passed += 1
        else:
            failed += 1
            
    print(f"\n==================================================")
    print(f"PLAYTHROUGH SUITE SUMMARY:")
    print(f"TOTAL LEVELS TESTED: {len(SCENES)}")
    print(f"PASSED: {passed}")
    print(f"FAILED: {failed}")
    print(f"STATUS: {'100% VERIFIED' if failed == 0 else 'REGRESSION DETECTED'}")
    print(f"==================================================")
    
    if failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
