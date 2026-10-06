"""
Batch 3D World Generation Pipeline for ECHOES BENEATH using Tripo3D
Generates high-impact modular kits for terrain, ruins, caves, and props.
"""

import os
import sys
import time
from tripo_client import generate_text_to_3d

ASSETS_TO_GENERATE = [
    {
        "id": "ENV_BOULDER_MOSS",
        "path": "assets/models/env_boulder_moss.glb",
        "prompt": "Large rugged weathered mountain boulder with patches of green moss and lichen, photorealistic limestone rock formation, isolated 3d game environment asset"
    },
    {
        "id": "RUIN_PILLAR_VAELOR",
        "path": "assets/models/ruin_pillar_vaelor.glb",
        "prompt": "Ancient Vaelor carved monolithic stone pillar, dark basalt with concentric soundwave runes, weathered archaeological architectural column, game ready 3d model"
    },
    {
        "id": "RUIN_ARCH_PORTAL",
        "path": "assets/models/ruin_arch_portal.glb",
        "prompt": "Ancient cyclopean stone gateway arch with geometric Vaelor acoustic engravings, weathered underground temple portal entrance, game ready 3d model"
    },
    {
        "id": "ENV_STALAGMITE_CLUSTER",
        "path": "assets/models/env_stalagmite_cluster.glb",
        "prompt": "Limestone cave stalagmite cluster, wet underground mineral rock formation, natural geological cavern spire, game ready 3d model"
    },
    {
        "id": "PROP_MERIDIAN_CRATE",
        "path": "assets/models/prop_meridian_crate.glb",
        "prompt": "Modern military expedition supply crate, dark olive weathered composite storage box with heavy metal latches and handles, tactical adventure gear prop, isolated 3d model"
    }
]

def run_batch():
    print(f"Starting batch world generation ({len(ASSETS_TO_GENERATE)} assets)...")
    for i, item in enumerate(ASSETS_TO_GENERATE):
        if os.path.exists(item["path"]):
            print(f"[{i+1}/{len(ASSETS_TO_GENERATE)}] Asset already exists: {item['path']} - Skipping.")
            continue
        print(f"\n[{i+1}/{len(ASSETS_TO_GENERATE)}] Generating {item['id']}...")
        try:
            generate_text_to_3d(item["prompt"], item["path"])
            print(f"Successfully generated and saved: {item['path']}")
        except Exception as e:
            print(f"ERROR generating {item['id']}: {e}")
            break

if __name__ == "__main__":
    run_batch()
