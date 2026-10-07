import os
import sys
import time
import json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo_client

ASSETS_TO_GENERATE = [
    {
        "id": "ARCH_BRIDGE_SPAN",
        "output": "assets/models/arch_bridge_span.glb",
        "prompt": "Ancient cyclopean stone bridge span over abyss, cracked weathered basalt masonry walkway with decorative acoustic runes, game ready 3d model"
    },
    {
        "id": "PROP_VAELOR_TURBINE_WHEEL",
        "output": "assets/models/prop_vaelor_turbine_wheel.glb",
        "prompt": "Ancient monolithic water sluice wheel and rotary acoustic turbine, weathered bronze and carved basalt stone machinery, game ready 3d prop"
    },
    {
        "id": "PROP_EXPEDITION_RADIO_STATION",
        "output": "assets/models/prop_expedition_radio_station.glb",
        "prompt": "Rugged field tactical communication radio transceiver station with antennas and battery pack on expedition case, game ready 3d prop"
    }
]

def main():
    print("==================================================")
    print("STARTING TRIPO3D CAMPAIGN ASSET GENERATION BATCH")
    print("==================================================")
    tripo_client.check_all_balances()
    
    for item in ASSETS_TO_GENERATE:
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
