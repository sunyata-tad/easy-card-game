"""
三段式提示词生成统一卡框：规范+风格+稀有度细节
Usage: python generate_frames.py
"""
import urllib.request
import urllib.parse
import time
import os
from PIL import Image

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FRAMES_DIR = os.path.join(BASE_DIR, "frames")
os.makedirs(FRAMES_DIR, exist_ok=True)

SPEC = (
    "vertical portrait card frame, "
    "wide ornate border occupying 15 percent width on each side, "
    "center is completely empty solid black, "
    "no artwork no illustration no portrait no image in the center, "
    "card art area top 10 to 50 percent and text area bottom 52 to 92 percent must be empty, "
    "perfectly symmetrical left right mirror symmetry, "
    "no tilt no rotation no perspective, flat 2D front view, "
    "no text no letters no words no watermark"
)

STYLE = (
    "dark fantasy card game frame, "
    "heavy metallic ornate border with runes and filigree, "
    "decorative corners, intricate scrollwork, "
    "high quality game UI design, detailed, sharp"
)

RARITY_DETAIL = {
    "frame_basic": (
        "weathered iron metal, dark steel grey tones, "
        "simple plain border without any gem or jewel, "
        "common basic card frame"
    ),
    "frame_uncommon": (
        "polished bronze metal with green patina, "
        "a glowing bright emerald gem embedded at top center of border, "
        "green magical energy emanating from the gem"
    ),
    "frame_rare": (
        "shining gold metal, warm golden tones, "
        "a glowing amber gem embedded at top center of border, "
        "golden energy emanating from the gem"
    ),
    "frame_epic": (
        "dark obsidian metal with purple veins, "
        "a glowing amethyst gem embedded at top center of border, "
        "purple arcane energy emanating from the gem"
    ),
    "frame_unique": (
        "crimson red metal with fire patterns, "
        "a glowing ruby gem embedded at top center of border, "
        "red fiery energy emanating from the gem, legendary card frame"
    ),
}


def generate(prompt, filename, width=512, height=672, seed=42):
    encoded = urllib.parse.quote(prompt)
    url = (
        f"https://image.pollinations.ai/prompt/{encoded}"
        f"?width={width}&height={height}&model=flux&nologo=true&seed={seed}"
    )
    filepath = os.path.join(FRAMES_DIR, filename)
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
    total = len(RARITY_DETAIL)
    ok = 0
    for i, (name, detail) in enumerate(RARITY_DETAIL.items()):
        prompt = f"{detail}, {STYLE}, {SPEC}"
        filename = f"{name}.png"
        print(f"[{i+1}/{total}] {name}...")
        print(f"  prompt: {detail[:60]}...")
        seed = hash(name) % 10000
        if generate(prompt, filename, seed=seed):
            ok += 1
            time.sleep(30)
    print(f"\nDone: {ok}/{total} succeeded")

    if ok == total:
        print("\n=== Processing (cutout center) ===")
        import process_frames
        for name in RARITY_DETAIL:
            process_frames.process_frame(f"{name}.png")


if __name__ == "__main__":
    main()