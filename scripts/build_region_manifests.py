"""Build content/region_manifests.json: res:// assets each level's _ready loads synchronously.

RegionHandoff.prepare() threaded-requests these so the dressing build at a region
threshold hits the resource cache instead of disk. Re-run after editing a level or its
dressing script:  python scripts/build_region_manifests.py
"""
import json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSET = re.compile(r'"(res://[^"]+\.(?:glb|gltf|png|jpg|jpeg|webp|tres|res|tscn|gdshader|ogg|wav|mp3))"')
SCRIPT = re.compile(r'"(res://[^"]+\.gd)"')

def scan(gd: pathlib.Path, seen: set, assets: set) -> None:
    if gd in seen or not gd.exists():
        return
    seen.add(gd)
    text = gd.read_text(encoding="utf-8", errors="ignore")
    for a in ASSET.findall(text):
        if (ROOT / a[6:]).exists():
            assets.add(a)
    for s in SCRIPT.findall(text):
        # Follow level-specific helpers only; shared systems are already resident.
        if "/levelb/" in s or "/environment/" in s or "CampaignExploration" in s:
            scan(ROOT / s[6:], seen, assets)

manifest = {}
for level in sorted((ROOT / "levels").glob("*.gd")):
    assets: set = set()
    scan(level, set(), assets)
    manifest[f"res://levels/{level.stem}.tscn"] = sorted(assets)
out = ROOT / "content" / "region_manifests.json"
out.write_text(json.dumps(manifest, indent=1) + "\n")
print(out, {k.split('/')[-1]: len(v) for k, v in manifest.items()})
