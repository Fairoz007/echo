"""AAA audio pass: chapter-staged generation under a hard credit budget.

Usage:
  python scripts/produce_aaa_audio_pass.py quota
  python scripts/produce_aaa_audio_pass.py generate PRO      # one chapter at a time
Masters land in production/audio_masters (never overwritten). Mastering/OGG/registry
is done by scripts/build_dialogue_registry.py.
"""
import json
import sys
import time
from elevenlabs_client import ElevenLabsClient, ElevenLabsError, ROOT

RESERVE = 250  # never spend the last credits; keeps room for a retake
SFX_COST_PER_SEC = 10

# Pinned voice identities (one per character, never mixed).
VOICES = {
    "MARA": "EXAVITQu4vr4xnSDxMaL", "NADIYA": "XrExE9yKIg1WjnnlVkGX", "ELIAS": "JBFqnCBsd6RMkjVDRZzb",
    "TOMAS": "iP95p4xoKVk53GoZ742B", "ADRIAN": "cjVigY5qzO86Huf0OWal", "DRAKE": "onwK4e9ZLuTAKqWW03F9",
    "MERIDIAN": "CwhRBWXzGAHq8TQ4Fs17",
}
NARRATOR = "MARA"  # recaps are Mara's field-journal voice
VO_SETTINGS = {"stability": 0.55, "similarity_boost": 0.85, "style": 0.1, "use_speaker_boost": True}
RECAP_SETTINGS = {"stability": 0.7, "similarity_boost": 0.85, "style": 0.05, "use_speaker_boost": True}

PLAN_FILE = ROOT / "audio" / "aaa_production_plan.json"


def load_plan():
    return json.loads(PLAN_FILE.read_text(encoding="utf-8"))


def cost(item):
    return len(item["text"]) if item["kind"] in ("vo", "recap") else int(round(item["duration"] * SFX_COST_PER_SEC))


def remaining(client):
    s = client.read("/v1/user/subscription")
    return s["character_limit"] - s["character_count"], s


def generate(chapter):
    plan = load_plan()
    items = [i for i in plan["items"] if i["chapter"] == chapter]
    client = ElevenLabsClient()
    left, _ = remaining(client)
    todo = [i for i in items if not (ROOT / "production/audio_masters" / (i["asset_id"] + ".mp3")).exists()]
    need = sum(cost(i) for i in todo)
    print(json.dumps({"chapter": chapter, "pending": len(todo), "estimated_cost": need, "remaining_before": left}))
    if left - need < RESERVE:
        raise SystemExit(f"BUDGET STOP: {need} needed, {left} left, reserve {RESERVE}")
    log = []
    for i in todo:
        dest = ROOT / "production/audio_masters" / (i["asset_id"] + ".mp3")
        try:
            if i["kind"] in ("vo", "recap"):
                voice = VOICES[i["character"]]
                client.generate_dialogue(i["asset_id"], i["text"], voice, dest,
                                         settings=RECAP_SETTINGS if i["kind"] == "recap" else VO_SETTINGS)
            else:
                client.generate_sound_effect(i["asset_id"], i["prompt"], dest, i["duration"], loop=i.get("loop", False))
            log.append({"asset_id": i["asset_id"], "status": "GENERATED", "est_cost": cost(i)})
        except ElevenLabsError as e:
            log.append({"asset_id": i["asset_id"], "status": "FAILED", "reason": str(e)})
            print("FAILED", i["asset_id"], e, flush=True)
            break
        print("ok", i["asset_id"], flush=True)
    after, s = remaining(client)
    batch_file = ROOT / "production/aaa_audio_batches.json"
    batches = json.loads(batch_file.read_text()) if batch_file.exists() else []
    batches.append({"time_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "chapter": chapter,
                    "assets": log, "remaining_before": left, "remaining_after": after,
                    "used": s["character_count"], "limit": s["character_limit"]})
    batch_file.write_text(json.dumps(batches, indent=2))
    print(json.dumps({"chapter": chapter, "remaining_after": after, "spent": left - after}))


if __name__ == "__main__":
    if sys.argv[1] == "quota":
        left, s = remaining(ElevenLabsClient())
        print(json.dumps({"remaining": left, "used": s["character_count"], "limit": s["character_limit"], "tier": s.get("tier")}))
    elif sys.argv[1] == "estimate":
        plan = load_plan()
        by = {}
        for i in plan["items"]:
            if not (ROOT / "production/audio_masters" / (i["asset_id"] + ".mp3")).exists():
                by[i["chapter"]] = by.get(i["chapter"], 0) + cost(i)
        print(json.dumps(by), sum(by.values()))
    else:
        generate(sys.argv[2])
