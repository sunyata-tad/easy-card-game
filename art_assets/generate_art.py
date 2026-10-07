"""
Batch generate pixel-art game assets using Pollinations.ai + PIL post-processing.
Usage: python generate_art.py [--only enemies|cards|player] [--skip-raw]
"""
import urllib.request
import urllib.parse
import time
import os
import sys
from PIL import Image

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
RAW_DIR = os.path.join(BASE_DIR, "raw")
PIXEL_DIR = os.path.join(BASE_DIR, "pixel")

os.makedirs(RAW_DIR, exist_ok=True)
os.makedirs(PIXEL_DIR, exist_ok=True)

STYLE_BASE = (
    "dark fantasy digital painting game illustration "
    "dramatic lighting high contrast detailed shading "
    "centered composition plain dark background "
    "no text no watermark"
)

ASSETS = {
    "enemies": {
        "enemy_stone_guard": "a heavy stone armor guard warrior holding a massive shield and a broad sword, full body, imposing stance, rock and metal armor textures, grey and brown tones",
        "enemy_shadow_assassin": "a shadow assassin in dark leather armor dual wielding daggers, crouching stealthy pose, hooded face, dark purple and black tones, smoke and shadow effects",
        "enemy_corrupted_mage": "a corrupted mage wizard with tattered robes glowing with dark purple energy, holding a twisted staff, skull-like face, dark green and purple corruption veins",
    },
    "player": {
        "player_fighter": "a battle-hardened fighter warrior in worn steel armor, holding a notched longsword, confident combat stance, scars and battle damage, dark steel and red accents, heroic but grim",
    },
    "cards": {
        "card_zhanji": "an action illustration of a powerful sword slash attack, a blade cutting through air with motion blur and energy trail, dynamic diagonal composition",
        "card_gedang": "an illustration of a warrior raising a heavy shield to block, defensive stance, shield glowing with protective energy, blue and steel tones",
        "card_lieji": "an illustration of a devastating cleave attack cracking the ground, fissures and debris flying, impact shockwave, earthy brown and orange tones",
        "card_yazhi": "an illustration of a suppressing heavy strike pinning an enemy down, massive weight and force, crushing impact, dark red and grey tones",
        "card_pojia": "an illustration of armor shattering into fragments, a blade piercing through broken plate armor, metal shards flying, orange and grey tones",
        "card_qiyue": "an illustration of a dark blood contract being signed, a glowing crimson pact scroll with dark runes, blood ink, dark red and black tones",
        "card_reji": "an illustration of heat death and ember extinction, fading flames turning to ash and cinders, dying fire, dark orange and grey ash tones",
        "card_tiebi": "an illustration of an impenetrable iron wall shield barrier, multiple overlapping shields forming a fortress wall, blue and steel grey tones",
        "card_zhaojia": "an illustration of a parry stance, a fighter deflecting a blow with their blade, sparks flying at contact point, steel and orange spark tones",
        "card_pozhan": "an illustration of an enemy weakness exposed, a glowing red weak point on a figure, vulnerability mark, red and dark tones",
        "card_piming": "an illustration of a deadly fatal strike, a precision thrust to a vital point, lethal focused energy, crimson and black tones",
        "card_zhiruo": "an illustration of a weakening curse effect, a figure surrounded by draining purple energy, withering and decaying, purple and sickly green tones",
        "card_niliu": "an illustration of time reversal flow, swirling temporal energy vortex turning back, clock fragments, blue and cyan ethereal tones",
        "card_shengsilunzhuan": "an illustration of the cycle of life and death, a spinning yin-yang wheel of skulls and flowers, reincarnation motif, white and black and green tones",
    },
}


def generate_raw(prompt, filename, width=512, height=512, seed=42):
    """Call Pollinations.ai to generate a raw image."""
    encoded = urllib.parse.quote(prompt)
    url = f"https://image.pollinations.ai/prompt/{encoded}?width={width}&height={height}&model=flux&nologo=true&seed={seed}"
    filepath = os.path.join(RAW_DIR, filename)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = resp.read()
        if len(data) < 100:
            print(f"  FAIL (too small: {len(data)} bytes): {filename}")
            return False
        with open(filepath, "wb") as f:
            f.write(data)
        print(f"  RAW OK ({len(data)} bytes): {filename}")
        return True
    except Exception as e:
        print(f"  FAIL ({e}): {filename}")
        return False


def pixelate(raw_filename, pixel_filename, pixel_size=4, target=512, num_colors=16):
    """Post-process: downscale -> quantize -> upscale NEAREST."""
    raw_path = os.path.join(RAW_DIR, raw_filename)
    pixel_path = os.path.join(PIXEL_DIR, pixel_filename)
    img = Image.open(raw_path).convert("RGBA")
    small_w = target // pixel_size
    small_h = target // pixel_size
    small = img.resize((small_w, small_h), Image.LANCZOS)
    if num_colors > 0:
        small_rgb = small.convert("RGB").quantize(colors=num_colors, method=Image.MEDIANCUT)
        small = small_rgb.convert("RGBA")
        small.putalpha(img.resize((small_w, small_h), Image.LANCZOS).getchannel("A"))
    result = small.resize((target, target), Image.NEAREST)
    result.save(pixel_path)
    print(f"  PIXEL OK: {pixel_filename}")


def run(category_filter=None, skip_raw=False):
    total = 0
    ok = 0
    for category, items in ASSETS.items():
        if category_filter and category != category_filter:
            continue
        for name, desc in items.items():
            total += 1
            prompt = f"{desc}, {STYLE_BASE}"
            raw_file = f"{name}_raw.png"
            pixel_file = f"{name}.png"

            print(f"[{total}] {name}...")

            if not skip_raw:
                seed = hash(name) % 10000
                success = False
                for attempt in range(5):
                    if generate_raw(prompt, raw_file, seed=seed + attempt):
                        success = True
                        break
                    print(f"  retry {attempt + 1}/5, waiting 30s...")
                    time.sleep(30)
                if not success:
                    print(f"  SKIPPED after 5 retries: {name}")
                    continue
                time.sleep(15)
            else:
                if not os.path.exists(os.path.join(RAW_DIR, raw_file)):
                    print(f"  raw not found, skipping: {name}")
                    continue

            try:
                pixelate(raw_file, pixel_file)
                ok += 1
            except Exception as e:
                print(f"  PIXELATE FAIL: {e}")

    print(f"\nDone: {ok}/{total} succeeded")


if __name__ == "__main__":
    cat = None
    skip = False
    for arg in sys.argv[1:]:
        if arg == "--skip-raw":
            skip = True
        elif arg.startswith("--only="):
            cat = arg.split("=")[1]
        elif arg == "--only" and len(sys.argv) > sys.argv.index(arg) + 1:
            cat = sys.argv[sys.argv.index(arg) + 1]
    run(cat, skip)