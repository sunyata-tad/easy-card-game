"""
Generate card frame assets for different rarities using Pollinations.ai (free).
Usage: python generate_frames.py
"""
import urllib.request
import urllib.parse
import time
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FRAMES_DIR = os.path.join(BASE_DIR, "frames")
os.makedirs(FRAMES_DIR, exist_ok=True)

STYLE = (
    "dark fantasy card game frame border ONLY, "
    "hollow empty center with nothing inside, "
    "the entire middle area is pure solid black flat color with no details, "
    "only the outer ornate metallic border frame is visible, "
    "decorative corners and runes on the border, "
    "vertical portrait card layout, "
    "silver and dark grey metal tones with subtle wear, "
    "high quality game UI design, symmetrical, "
    "no text no watermark no letters no words no illustration no image inside"
)

FRAMES = {
    "frame_basic": (
        "plain simple border, no gem, no jewel, "
        "common basic card frame"
    ),
    "frame_uncommon": (
        "a glowing bright blue sapphire gem embedded at the top center of the border, "
        "blue magical energy emanating from the gem"
    ),
    "frame_rare": (
        "a glowing warm orange amber gem embedded at the top center of the border, "
        "orange golden magical energy emanating from the gem"
    ),
    "frame_epic": (
        "a glowing vivid purple amethyst gem embedded at the top center of the border, "
        "purple arcane energy emanating from the gem"
    ),
    "frame_unique": (
        "a glowing crimson red ruby gem embedded at the top center of the border, "
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
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = resp.read()
        if len(data) < 1000:
            print(f"  FAIL (too small: {len(data)} bytes): {filename}")
            return False
        with open(filepath, "wb") as f:
            f.write(data)
        print(f"  OK ({len(data)} bytes): {filename}")
        return True
    except Exception as e:
        print(f"  FAIL ({e}): {filename}")
        return False


def main():
    total = len(FRAMES)
    ok = 0
    for i, (name, gem_desc) in enumerate(FRAMES.items()):
        prompt = f"{gem_desc}, {STYLE}"
        filename = f"{name}.png"
        print(f"[{i+1}/{total}] {name}...")
        seed = hash(name) % 10000
        success = False
        for attempt in range(5):
            if generate(prompt, filename, seed=seed + attempt):
                success = True
                break
            print(f"  retry {attempt+1}/5, waiting 30s...")
            time.sleep(30)
        if success:
            ok += 1
            time.sleep(15)
        else:
            print(f"  SKIPPED after 5 retries: {name}")
    print(f"\nDone: {ok}/{total} succeeded")


if __name__ == "__main__":
    main()