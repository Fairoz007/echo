"""DEV ONLY: contact sheets + motion metrics for screenshots/nature/q<N>/.
python dev/nature/nature_sheet.py screenshots/nature/q1
Per case: mean abs frame-to-frame difference (motion), max (explosion check)."""
import sys, glob, os, re
import numpy as np
from PIL import Image

d = sys.argv[1]
cases = {}
for f in sorted(glob.glob(os.path.join(d, "*_f??.png"))):
    cases.setdefault(re.sub(r"_f\d\d\.png$", "", os.path.basename(f)), []).append(f)
os.makedirs(os.path.join(d, "sheets"), exist_ok=True)
for name, files in cases.items():
    ims = [Image.open(f).convert("RGB") for f in files]
    arr = [np.asarray(i, dtype=np.float32) for i in ims]
    diffs = [np.abs(arr[i + 1] - arr[i]).mean() for i in range(len(arr) - 1)]
    # Region with motion >12 levels, as % of pixels (how much of the frame moves).
    moving = [100.0 * (np.abs(arr[i + 1] - arr[i]).max(axis=2) > 12).mean() for i in range(len(arr) - 1)]
    print(f"{name:22s} n={len(files):2d} motion={np.mean(diffs):5.2f} max={np.max(diffs):5.2f} moving%={np.mean(moving):5.1f}")
    w, h = ims[0].size
    cols = 4
    rows = (len(ims) + cols - 1) // cols
    s = 0.4
    sheet = Image.new("RGB", (int(w * s) * cols, int(h * s) * rows))
    for i, im in enumerate(ims):
        sheet.paste(im.resize((int(w * s), int(h * s))), ((i % cols) * int(w * s), (i // cols) * int(h * s)))
    sheet.save(os.path.join(d, "sheets", name + ".png"))
