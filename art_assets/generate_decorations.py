"""
AI生成卡框装饰部件（部件化方案）。
每个部件单独生成，设定尺寸和描述，拼装时缩放使用。

部件清单：
  base_frame    512×672  基础金属边框（所有稀有度共用）
  deco_corner   128×128  角饰（第1层，uncommon+）
  deco_gem      128×128  宝石+底座（第2层，rare+）
  deco_flourish  64×256  侧边花纹（第3层，epic+）
  deco_crest    256×64   徽章（第4层，unique）

部件在纯黑背景上生成，PIL用色键抠图（黑色→透明）。
Usage: python generate_decorations.py
"""
import urllib.request
import urllib.parse
import time
import os
from PIL import Image

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PARTS_DIR = os.path.join(BASE_DIR, "parts")
os.makedirs(PARTS_DIR, exist_ok=True)

# 部件定义：(文件名, 宽, 高, 描述, seed)
PARTS = [
    (
        "base_frame.png", 512, 672,
        "simple metallic border frame, polished silver steel color, "
        "plain clean border without any decorations or ornaments, "
        "center area is solid pure black, "
        "border occupies 15 percent width on each side, "
        "perfectly symmetrical left right mirror symmetry, "
        "flat 2D front view, no tilt no perspective, "
        "no text no letters no watermark",
        1001,
    ),
    (
        "deco_corner.png", 128, 128,
        "ornate metal corner decoration piece, "
        "intricate scrollwork and filigree, "
        "symmetrical L-shaped corner ornament, "
        "bright polished metal on pure black background, "
        "the metal decoration is clearly visible and the background is pure black, "
        "flat 2D front view, no text",
        2002,
    ),
    (
        "deco_gem.png", 128, 128,
        "a faceted gemstone with metal prongs setting, "
        "diamond cut gem glowing with inner light, "
        "metal bezel setting with prongs, "
        "the gem and setting are bright and clearly visible on pure black background, "
        "flat 2D front view, no text",
        3003,
    ),
    (
        "deco_flourish.png", 64, 256,
        "vertical ornamental metal flourish, "
        "decorative scrollwork running vertically, "
        "intricate filigree pattern, "
        "bright polished metal on pure black background, "
        "the ornament is clearly visible and the background is pure black, "
        "flat 2D front view, no text",
        4004,
    ),
    (
        "deco_crest.png", 256, 64,
        "heraldic banner crest ornament, "
        "metal shield with decorative scrollwork, "
        "ornate horizontal banner, "
        "bright polished metal on pure black background, "
        "the crest is clearly visible and the background is pure black, "
        "flat 2D front view, no text",
        5005,
    ),
]


def generate(prompt, filename, width, height, seed):
    encoded = urllib.parse.quote(prompt)
    url = (
        f"https://image.pollinations.ai/prompt/{encoded}"
        f"?width={width}&height={height}&model=flux&nologo=true&seed={seed}"
    )
    filepath = os.path.join(PARTS_DIR, filename)
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
            print(f"  OK ({len(data)} bytes): {filename}")
            return True
        except Exception as e:
            print(f"  FAIL ({e}): attempt {attempt+1}")
        time.sleep(30)
    return False


def main():
    total = len(PARTS)
    ok = 0
    for i, (filename, w, h, prompt, seed) in enumerate(PARTS):
        print(f"[{i+1}/{total}] {filename} ({w}x{h})...")
        print(f"  prompt: {prompt[:70]}...")
        if generate(prompt, filename, w, h, seed):
            ok += 1
            if i < total - 1:
                time.sleep(30)
    print(f"\nDone: {ok}/{total} succeeded")
    print(f"部件保存到: {PARTS_DIR}")


if __name__ == "__main__":
    main()