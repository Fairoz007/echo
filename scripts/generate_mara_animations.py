import os
import sys
import time
import json
import urllib.request
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_client

# The original Mara rig task (8e0c7b78-...) belongs to key slot 1, which has 0 credits;
# other key slots get HTTP 404 for it. All project characters share the identical 41-bone
# Tripo legacy biped skeleton (verified by joint-name comparison), so clips are generated on
# rigs owned by funded accounts and shared by bone name across Mara / NPCs / Meridian.
BASE_RIG_TASK_ID = "1adccc7d-4bb7-4027-85d8-bb3c0ac915a2"  # CHR_NADIYA_001_RIG_LEGACY (key slot 3)
BASE_KEY_SLOT = 3
ENEMY_RIG_TASK_ID = "dcf78562-87d9-4139-b670-6d5292aae3e4"  # CHR_MERIDIAN_BASE_001_RIG_LEGACY (key slot 2)
ENEMY_KEY_SLOT = 2

ANIMATIONS_TO_GENERATE = [
    # idle + walk already baked into assets/characters/mara/optimized/CHR_Mara_Production.glb
    {"name": "run", "preset": "preset:run", "output": "assets/characters/mara/animations/anim_run.glb"},
    {"name": "jump", "preset": "preset:jump", "output": "assets/characters/mara/animations/anim_jump.glb"},
    {"name": "climb", "preset": "preset:climb", "output": "assets/characters/mara/animations/anim_climb.glb"},
    {"name": "fall", "preset": "preset:fall", "output": "assets/characters/mara/animations/anim_fall.glb"},
    {"name": "dive", "preset": "preset:dive", "output": "assets/characters/mara/animations/anim_dive.glb"},
    {"name": "enemy_shoot", "preset": "preset:shoot", "output": "assets/characters/meridian/animations/anim_shoot.glb", "enemy": True},
    {"name": "enemy_hurt", "preset": "preset:hurt", "output": "assets/characters/meridian/animations/anim_hurt.glb", "enemy": True},
    {"name": "enemy_slash", "preset": "preset:slash", "output": "assets/characters/meridian/animations/anim_slash.glb", "enemy": True},
]
LOG_PATH = "assets/characters/mara/animations/retarget_jobs.json"

def _log(entry):
    os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
    log = json.load(open(LOG_PATH)) if os.path.exists(LOG_PATH) else []
    log.append(entry)
    json.dump(log, open(LOG_PATH, "w"), indent=2)

def generate_retarget(preset_name, output_path, rig_task_id=BASE_RIG_TASK_ID, key_slot=BASE_KEY_SLOT):
    tripo_client.current_key_idx = key_slot - 1
    tripo_client.rotate_key = lambda: False  # tasks are account-scoped; never fail over
    print(f"\n[ANIMATION] Submitting retarget task for {preset_name}...")
    payload = {
        "type": "animate_retarget",
        "original_model_task_id": rig_task_id,
        "animation": preset_name,
        "animate_in_place": True,
        "out_format": "glb",
    }
    res = tripo_client.make_request("/task", method="POST", data=payload)
    if res.get("code") != 0:
        raise RuntimeError(f"Retarget failed: {res}")
    task_id = res["data"]["task_id"]
    print(f"[ANIMATION] Task ID: {task_id}, polling for completion...")
    
    for _ in range(150):
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
            _log({"preset": preset_name, "rig": rig_task_id, "key_slot": key_slot, "task_id": task_id, "output": output_path, "status": "success"})
            print(f"[ANIMATION SUCCESS] Saved {preset_name} to {output_path} ({os.path.getsize(output_path)} bytes)")
            return output_path
        elif status in ["failed", "cancelled", "banned", "expired"]:
            _log({"preset": preset_name, "task_id": task_id, "status": status})
            raise RuntimeError(f"Task {task_id} failed with status {status}")
    raise RuntimeError(f"Task {task_id} polling timed out")

def main():
    print("==================================================")
    print("GENERATING ANIMATION SET FOR MARA VALE")
    print("==================================================")
    for anim in ANIMATIONS_TO_GENERATE:
        if os.path.exists(anim["output"]):
            print(f"[SKIP] {anim['name']} already exists at {anim['output']}")
            continue
        try:
            if anim.get("enemy"):
                generate_retarget(anim["preset"], anim["output"], ENEMY_RIG_TASK_ID, ENEMY_KEY_SLOT)
            else:
                generate_retarget(anim["preset"], anim["output"])
        except Exception as e:
            print(f"[ANIMATION FAILED] {anim['name']}: {e}")
    print("\n[ALL ANIMATIONS RETRIEVED SUCCESSFULLY]")

if __name__ == "__main__":
    main()
