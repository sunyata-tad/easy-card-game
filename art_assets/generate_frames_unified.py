"""
统一卡框生成：先AI生成一个高质量银灰底框，再用PIL派生5个稀有度版本。
保证框大小、设计完全一致，只有颜色和宝石不同。

Usage: python generate_frames_unified.py
"""
import urllib.request
import urllib.parse
import time
import os
import math
from PIL import Image, ImageDraw, ImageFilter

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FRAMES_DIR = os.path.join(BASE_DIR, "frames")
os.makedirs(FRAMES_DIR, exist_ok=True)

WIDTH, HEIGHT = 512, 672

BASE_PROMPT = (
    "dark fantasy card game frame, "
    "very wide thick broad ornate metallic border frame, "
    "the border takes up 15 percent of the card width on each side, "
    "heavy decorative corners with runes and filigree, "
    "the center is flat solid black with absolutely nothing inside, "
    "no artwork no illustration no portrait no image in the center, "
    "only the wide ornate border frame is visible, "
    "vertical portrait card layout, "
    "silver and dark grey metal tones with subtle wear, "
    "high quality game UI design, "
    "perfectly symmetrical left right mirror symmetry, "
    "perfectly straight horizontal vertical no tilt no rotation no perspective, "
    "flat 2D front view no 3D no angle, "
    "no text no watermark no letters no words"
)

RARITY_CONFIG = {
    "frame_basic":    {"color": None,                         "gem": None},
    "frame_uncommon": {"color": (0.25, 0.45, 0.85),           "gem": (0.30, 0.55, 1.00)},
    "frame_rare":     {"color": (0.85, 0.55, 0.20),           "gem": (1.00, 0.65, 0.20)},
    "frame_epic":     {"color": (0.60, 0.30, 0.80),           "gem": (0.70, 0.35, 1.00)},
    "frame_unique":   {"color": (0.85, 0.25, 0.25),           "gem": (1.00, 0.25, 0.25)},
}


def generate_base_frame(seed=42):
    """AI生成银灰底框"""
    encoded = urllib.parse.quote(BASE_PROMPT)
    url = (
        f"https://image.pollinations.ai/prompt/{encoded}"
        f"?width={WIDTH}&height={HEIGHT}&model=flux&nologo=true&seed={seed}"
    )
    filepath = os.path.join(FRAMES_DIR, "frame_base_raw.png")
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=180) as resp:
                data = resp.read()
            if len(data) < 1000:
                print(f"  FAIL (too small): attempt {attempt+1}")
                continue
            with open(filepath, "wb") as f:
                f.write(data)
            img = Image.open(filepath).convert("RGBA")
            img.save(filepath, "PNG")
            print(f"  OK ({len(data)} bytes): frame_base_raw.png")
            return filepath
        except Exception as e:
            print(f"  FAIL ({e}): attempt {attempt+1}")
        time.sleep(30)
    return None


def apply_tint(img, tint_color):
    """对边框像素应用色调：保留亮度，替换色相"""
    if tint_color is None:
        return img.copy()
    w, h = img.size
    pixels = img.load()
    result = img.copy()
    rp = result.load()
    tr, tg, tb = tint_color
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < 10 or (r < 15 and g < 15 and b < 15):
                continue
            brightness = (r + g + b) / (3.0 * 255.0)
            boost = 0.3
            nr = int((r / 255.0 * (1 - boost) + tr * brightness * boost) * 255)
            ng = int((g / 255.0 * (1 - boost) + tg * brightness * boost) * 255)
            nb = int((b / 255.0 * (1 - boost) + tb * brightness * boost) * 255)
            rp[x, y] = (max(0, min(255, nr)), max(0, min(255, ng)), max(0, min(255, nb)), a)
    return result


def draw_gem(img, gem_color, gem_pos=None):
    """在顶部中心绘制发光宝石"""
    if gem_color is None:
        return img
    w, h = img.size
    if gem_pos is None:
        cx, cy = w // 2, int(h * 0.045)
    else:
        cx, cy = gem_pos
    radius = int(w * 0.035)
    glow_radius = int(radius * 2.5)

    glow_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    gr, gg, gb = [int(c * 255) for c in gem_color]
    for r in range(glow_radius, radius, -1):
        alpha = int(80 * (1 - (r - radius) / max(1, glow_radius - radius)) ** 2)
        glow_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(gr, gg, gb, alpha))
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(3))

    gem_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gem_draw = ImageDraw.Draw(gem_layer)
    gem_draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=(gr, gg, gb, 255))
    highlight_r = int(radius * 0.4)
    hl_offset = int(radius * 0.3)
    gem_draw.ellipse(
        [cx - highlight_r - hl_offset, cy - highlight_r - hl_offset,
         cx + highlight_r - hl_offset, cy + highlight_r - hl_offset],
        fill=(255, 255, 255, 160)
    )
    gem_draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                     outline=(255, 255, 255, 200), width=2)

    result = Image.alpha_composite(img, glow_layer)
    result = Image.alpha_composite(result, gem_layer)
    return result


def main():
    print("=== Step 1: Generate base frame ===")
    base_path = os.path.join(FRAMES_DIR, "frame_base_raw.png")
    if os.path.exists(base_path):
        print("  base frame already exists, skipping generation")
    else:
        generate_base_frame()

    if not os.path.exists(base_path):
        print("FATAL: base frame generation failed")
        return

    print("\n=== Step 2: Derive rarity variants ===")
    base_img = Image.open(base_path).convert("RGBA")
    for name, cfg in RARITY_CONFIG.items():
        print(f"  {name}...")
        img = apply_tint(base_img, cfg["color"])
        img = draw_gem(img, cfg["gem"])
        out_path = os.path.join(FRAMES_DIR, f"{name}.png")
        img.save(out_path, "PNG")
        print(f"    saved: {out_path}")

    print("\n=== Step 3: Process (cutout center) ===")
    import process_frames
    for name in RARITY_CONFIG:
        process_frames.process_frame(f"{name}.png")

    print("\nDone! All 5 frames generated with unified border design.")


if __name__ == "__main__":
    main()