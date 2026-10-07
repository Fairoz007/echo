import os
import sys
import time
import json
import urllib.request
import urllib.error

# Add scripts directory to path to use tripo_client
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_client

MARA_PROMPT = (
    "Full-body realistic original female archaeological field explorer named Mara, early 30s, "
    "170 cm tall, athletic natural proportions, experienced expedition researcher. "
    "Weathered dark olive green expedition shirt, durable charcoal climbing trousers, rugged hiking boots, "
    "compact utility belt with pouches, lightweight climbing harness, compact 20L backpack on back. "
    "Realistic original face with natural outdoor skin detail, practical dark brown hair in a low ponytail, "
    "anatomically correct hands with 5 separate fingers, realistic footwear, natural cloth folds. "
    "Cinematic realistic third-person adventure character. "
    "Neutral animation-ready standing A-pose, symmetrical posture, arms separated from torso, "
    "hands clearly visible, legs separated, straight posture, clean silhouette, full body visible, "
    "no weapon held, no display platform, no base, no text, no fantasy or sci-fi armor, production PBR materials."
)


OUTPUT_SOURCE_DIR = "d:/new-dev/assets/characters/mara/source"
OUTPUT_FILE = os.path.join(OUTPUT_SOURCE_DIR, "CHR_Mara_Base.glb")

def main():
    print("==================================================")
    print("STARTING TRIPO3D CHARACTER GENERATION: MARA VALE")
    print("==================================================")
    os.makedirs(OUTPUT_SOURCE_DIR, exist_ok=True)
    
    print("[1] Querying credit balances...")
    tripo_client.check_all_balances()
    
    print(f"\n[2] Output target: {OUTPUT_FILE}")
    print(f"[3] Prompt:\n{MARA_PROMPT}\n")
    
    start_time = time.time()
    try:
        model_path = tripo_client.generate_text_to_3d(MARA_PROMPT, OUTPUT_FILE)
        elapsed = time.time() - start_time
        print(f"\n[TRIPO SUCCESS] Mara Vale generated and downloaded in {elapsed:.1f}s!")
        print(f"File: {model_path} ({os.path.getsize(model_path)} bytes)")
    except Exception as e:
        print(f"\n[TRIPO ERROR] Failed to generate Mara Vale: {e}")
        sys.exit(1)
        
    print("\n[4] Querying post-generation balances...")
    tripo_client.check_all_balances()

if __name__ == "__main__":
    main()
