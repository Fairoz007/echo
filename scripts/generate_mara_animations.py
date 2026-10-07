import os
import sys
import time
import json
import urllib.request
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_client

BASE_RIG_TASK_ID = "8e0c7b78-d432-4525-b738-2361015244b3"

ANIMATIONS_TO_GENERATE = [
    {"name": "idle", "preset": "preset:idle", "output": "assets/characters/mara/animations/anim_idle.glb"},
    {"name": "run", "preset": "preset:run", "output": "assets/characters/mara/animations/anim_run.glb"},
    {"name": "jump", "preset": "preset:jump", "output": "assets/characters/mara/animations/anim_jump.glb"}
]

def generate_retarget(preset_name, output_path):
    print(f"\n[ANIMATION] Submitting retarget task for {preset_name}...")
    payload = {
        "type": "animate_retarget",
        "original_model_task_id": BASE_RIG_TASK_ID,
        "animation": preset_name
    }
    res = tripo_client.make_request("/task", method="POST", data=payload)
    if res.get("code") != 0:
        raise RuntimeError(f"Retarget failed: {res}")
    task_id = res["data"]["task_id"]
    print(f"[ANIMATION] Task ID: {task_id}, polling for completion...")
    
    while True:
        time.sleep(4)
        status_res = tripo_client.make_request(f"/task/{task_id}")
        data = status_res.get("data", {})
        status = data.get("status")
        progress = data.get("progress", 0)
        print(f"  {preset_name} ({task_id}): {status} ({progress}%)")
        if status == "success":
            model_url = data.get("output", {}).get("model") or data.get("result", {}).get("model")
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            urllib.request.urlretrieve(model_url, output_path)
            print(f"[ANIMATION SUCCESS] Saved {preset_name} to {output_path} ({os.path.getsize(output_path)} bytes)")
            return output_path
        elif status in ["failed", "cancelled"]:
            raise RuntimeError(f"Task {task_id} failed with status {status}")

def main():
    print("==================================================")
    print("GENERATING ANIMATION SET FOR MARA VALE")
    print("==================================================")
    for anim in ANIMATIONS_TO_GENERATE:
        if os.path.exists(anim["output"]):
            print(f"[SKIP] {anim['name']} already exists at {anim['output']}")
            continue
        generate_retarget(anim["preset"], anim["output"])
    print("\n[ALL ANIMATIONS RETRIEVED SUCCESSFULLY]")

if __name__ == "__main__":
    main()
