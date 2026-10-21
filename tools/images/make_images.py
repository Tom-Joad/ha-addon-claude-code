"""Render the add-on's icon.png and logo.png: Anton caps on ink, red full stop.

    python3 tools/images/make_images.py <Anton .woff2 or .ttf> claude-code

Needs Pillow, fontTools and brotli (for .woff2): pip install pillow fonttools brotli.
"""
import sys, tempfile
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

INK, PAPER, RED = "#16130d", "#f2ead9", "#d5482a"
GAP = 0.06

def render(ttf, out, lines, w, h, max_w, max_h, final, cap_size):
    scale = 4  # draw large, then scale down for clean edges
    W, H = w * scale, h * scale
    def block(size):
        font = ImageFont.truetype(ttf, size)
        texts = lines[:-1] + [lines[-1] + "."]
        boxes = [font.getbbox(t) for t in texts]
        cap = font.getbbox("H"); line_h = cap[3] - cap[1]
        width = max(b[2] - b[0] for b in boxes)
        height = len(lines) * line_h + (len(lines) - 1) * GAP * size
        return font, texts, boxes, cap, line_h, width, height
    size = int(cap_size * scale)
    while True:
        font, texts, boxes, cap, line_h, bw, bh = block(size)
        if bw <= max_w * W and bh <= max_h * H: break
        size -= 2
    img = Image.new("RGB", (W, H), INK); d = ImageDraw.Draw(img)
    y = (H - bh) / 2 - cap[1]
    for i, (t, b) in enumerate(zip(texts, boxes)):
        x = (W - (b[2] - b[0])) / 2 - b[0]
        if i == len(texts) - 1:
            word = t[:-1]; d.text((x, y), word, font=font, fill=PAPER)
            d.text((x + font.getlength(word), y), ".", font=font, fill=RED)
        else:
            d.text((x, y), t, font=font, fill=PAPER)
        y += line_h + GAP * size
    img.resize(final, Image.LANCZOS).save(out, optimize=True)

font, outdir = sys.argv[1], sys.argv[2]
ttf = tempfile.NamedTemporaryFile(suffix=".ttf", delete=False).name
f = TTFont(font); f.flavor = None; f.save(ttf)
# icon.png: square, 128 px as Home Assistant recommends; same proportions as the Unraid icons.
render(ttf, f"{outdir}/icon.png", ["CLAUDE", "CODE"], 512, 512, 0.78, 0.62, (128, 128), 150)
# logo.png: 250x100 is Home Assistant's size; rendered at twice that for sharp screens.
render(ttf, f"{outdir}/logo.png", ["CLAUDE CODE"], 500, 200, 0.80, 0.50, (500, 200), 120)
