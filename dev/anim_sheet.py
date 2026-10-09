"""DEV ONLY: contact sheet of anim_capture frames. python dev/anim_sheet.py <prefix> <out.png> [crop_w crop_h]"""
import sys, glob
from PIL import Image
pre, out = sys.argv[1], sys.argv[2]
cw, ch = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (420, 600)
files = sorted(glob.glob(pre + "*.png"))
ims = []
for f in files:
    im = Image.open(f); w, h = im.size
    ims.append(im.crop(((w - cw) // 2, (h - ch) // 2, (w + cw) // 2, (h + ch) // 2)))
cols = 6; rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (cols * cw, rows * ch))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % cols) * cw, (i // cols) * ch))
sheet.save(out)
print(out, sheet.size)
