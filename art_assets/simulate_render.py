"""
生成模拟渲染图：卡框 + 卡图占位 + 文字占位，模拟游戏中实际显示效果。
然后用像素分析检查：卡图/文字是否被卡框遮挡。
"""
from PIL import Image, ImageDraw, ImageFont
import os

FRAME_DIR = os.path.join(os.path.dirname(__file__), "frames")
OUT_DIR = os.path.join(os.path.dirname(__file__), "frame_simulate")
os.makedirs(OUT_DIR, exist_ok=True)


def simulate_render(frame_name, tw, th, card_name="测试卡牌", card_desc="造成2点伤害"):
    """模拟游戏中的卡牌渲染"""
    # 1. 创建背景（Panel底色）
    canvas = Image.new("RGBA", (tw, th), (33, 36, 46, 255))

    # 2. 放置卡图（彩色渐变模拟）
    art_x0, art_x1 = int(tw * 0.15), int(tw * 0.85)
    art_y0, art_y1 = int(th * 0.10), int(th * 0.48)
    art = Image.new("RGBA", (art_x1 - art_x0, art_y1 - art_y0), (60, 80, 120, 255))
    canvas.paste(art, (art_x0, art_y0))

    # 3. 放置文字背景
    text_x0, text_x1 = int(tw * 0.15), int(tw * 0.85)
    text_y0, text_y1 = int(th * 0.52), int(th * 0.89)
    text_bg = Image.new("RGBA", (text_x1 - text_x0, text_y1 - text_y0), (15, 18, 26, 230))
    canvas.paste(text_bg, (text_x0, text_y0))

    # 4. 放置文字
    try:
        font_size = max(8, int(tw * 0.1))
        font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", font_size)
    except:
        font = ImageFont.load_default()
    draw = ImageDraw.Draw(canvas)
    draw.text((tw // 2, text_y0 + 2), card_name, fill=(255, 255, 255), font=font, anchor="mt")
    try:
        desc_font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", max(7, int(tw * 0.08)))
    except:
        desc_font = ImageFont.load_default()
    draw.text((tw // 2, text_y0 + 2 + font_size + 4), card_desc, fill=(180, 180, 190), font=desc_font, anchor="mt")

    # 5. 放置稀有度色带
    band_x0, band_x1 = int(tw * 0.15), int(tw * 0.85)
    band_y0, band_y1 = int(th * 0.93), int(th * 0.97)
    draw.rectangle([band_x0, band_y0, band_x1, band_y1], fill=(100, 200, 100, 255))

    # 6. 叠加卡框（alpha混合）
    frame = Image.open(os.path.join(FRAME_DIR, frame_name)).convert("RGBA")
    frame_resized = frame.resize((tw, th), Image.LANCZOS)

    # 检查卡框是否遮挡了卡图/文字
    px_frame = frame_resized.load()
    px_canvas = canvas.load()
    art_occluded = 0
    text_occluded = 0
    for y in range(th):
        for x in range(tw):
            fa = px_frame[x, y][3]
            if fa > 0:
                # 卡框在此像素有内容
                if art_x0 <= x < art_x1 and art_y0 <= y < art_y1:
                    art_occluded += 1
                elif text_x0 <= x < text_x1 and text_y0 <= y < text_y1:
                    text_occluded += 1

    # alpha混合
    result = Image.alpha_composite(canvas, frame_resized)

    return result, art_occluded, text_occluded


if __name__ == "__main__":
    sizes = {
        "small_120x158": (120, 158),
        "detail_268x352": (268, 352),
    }

    print("=" * 60)
    print("模拟渲染检查 — 卡框叠加卡图+文字后的实际遮挡")
    print("=" * 60)

    for size_name, (tw, th) in sizes.items():
        print(f"\n## {size_name} ({tw}x{th})")
        for fn in ["frame_basic.png", "frame_rare.png", "frame_unique.png"]:
            result, art_occ, text_occ = simulate_render(fn, tw, th)
            out_path = os.path.join(OUT_DIR, f"{fn.replace('.png','')}_{size_name}.png")
            result.save(out_path)
            status = "✅" if art_occ == 0 and text_occ == 0 else f"⚠️ 卡图{art_occ}px 文字{text_occ}px"
            print(f"  {fn}: {status} → {out_path}")

    print(f"\n模拟图保存到: {OUT_DIR}")
    print("这些图模拟了游戏中卡框+卡图+文字的实际显示效果")