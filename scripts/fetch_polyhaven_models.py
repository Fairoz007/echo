"""Download CC0 Poly Haven models (glTF, 1k textures) into assets/polyhaven/models/<id>/.

Usage: python scripts/fetch_polyhaven_models.py id1 id2 ...
Writes assets/polyhaven/models/SOURCES.json with name, authors, license and URL per asset.
"""
import json, pathlib, sys, urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "polyhaven" / "models"
UA = {"User-Agent": "EchoesBeneath-asset-fetch/1.0"}

def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()

def main(ids):
    ROOT.mkdir(parents=True, exist_ok=True)
    src_path = ROOT / "SOURCES.json"
    sources = json.loads(src_path.read_text()) if src_path.exists() else {}
    for aid in ids:
        files = json.loads(get(f"https://api.polyhaven.com/files/{aid}"))
        info = json.loads(get(f"https://api.polyhaven.com/info/{aid}"))
        g = files["gltf"]["1k"]["gltf"]
        out = ROOT / aid
        out.mkdir(exist_ok=True)
        (out / f"{aid}.gltf").write_bytes(get(g["url"]))
        size = 0
        for rel, meta in g.get("include", {}).items():
            p = out / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(get(meta["url"]))
            size += meta.get("size", 0)
        sources[aid] = {"name": info["name"], "authors": list(info.get("authors", {})), "license": "CC0 1.0",
                        "url": f"https://polyhaven.com/a/{aid}", "polycount": info.get("polycount")}
        print(f"{aid}: {info['name']} polys={info.get('polycount')} ~{size//1024} KB")
    src_path.write_text(json.dumps(sources, indent=1) + "\n")

if __name__ == "__main__":
    main(sys.argv[1:])
