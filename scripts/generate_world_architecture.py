import os
import sys
import time
import json
import urllib.request
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_client

WORLD_MODELS_TO_GENERATE = [
    {
        "id": "ARCH_WALL_VAELOR",
        "output": "assets/models/arch_wall_vaelor.glb",
        "prompt": "Ancient cyclopean stone wall section with carved geometric acoustic Vaelor runes and weathered basalt masonry, modular dungeon wall game asset, isolated 3d model"
    },
    {
        "id": "ARCH_FLOOR_STONE",
        "output": "assets/models/arch_floor_stone.glb",
        "prompt": "Ancient modular stone tile floor slab, weathered ancient ruin flagstones with carved soundwave acoustic geometric patterns, seamless game ready 3d tile asset"
    },
    {
        "id": "ARCH_GLASS_BARRIER",
        "output": "assets/models/arch_glass_barrier.glb",
        "prompt": "Modern high-tech transparent reinforced ballistic glass security barrier with heavy industrial brushed steel frame, archaeological expedition outpost barrier prop, isolated 3d model"
    }
]

def main():
    print("==================================================")
    print("STARTING TRIPO3D MODULAR WORLD ASSET GENERATION")
    print("==================================================")
    tripo_client.check_all_balances()
    
    for item in WORLD_MODELS_TO_GENERATE:
        out_path = item["output"]
        if os.path.exists(out_path):
            print(f"[SKIP] {item['id']} already exists at {out_path}")
            continue
        print(f"\n[GENERATING] {item['id']} -> {out_path}")
        print(f"Prompt: {item['prompt']}")
        try:
            tripo_client.generate_text_to_3d(item["prompt"], out_path)
            print(f"[SUCCESS] Generated {out_path} ({os.path.getsize(out_path)} bytes)")
        except Exception as e:
            print(f"[ERROR] Failed to generate {item['id']}: {e}")
            break
            
    print("\n[POST-GENERATION BALANCES]")
    tripo_client.check_all_balances()

if __name__ == "__main__":
    main()
