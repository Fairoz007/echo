import os
import re

levels = [f for f in os.listdir("levels") if f.endswith(".tscn")]
levels.sort()

print("==================================================")
print("LEVEL BY LEVEL 3D ASSET AUDIT FOR ECHOES BENEATH")
print("==================================================")

for lvl in levels:
    path = os.path.join("levels", lvl)
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    
    ext_resources = re.findall(r'\[ext_resource type="PackedScene" path="([^"]+)"', content)
    models = [os.path.basename(m) for m in ext_resources if m.endswith(".glb")]
    
    csg_matches = re.findall(r'\[node name="([^"]+)" type="(CSG[^"]+|MeshInstance3D)"', content)
    props = [m[0] for m in csg_matches if not any(k in m[0].lower() for k in ["ground", "floor", "wall", "ceiling", "bound", "collision"])]
    
    print(f"\n[{lvl}]")
    print(f"  3D Models in Scene: {models}")
    print(f"  Remaining Primitive Nodes: {props}")
