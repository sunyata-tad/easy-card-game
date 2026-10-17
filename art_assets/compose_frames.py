"""
PIL按稀有度拼装卡框（部件化方案 v2）。
基础边框用AI生成，装饰部件用PIL绘制（AI小尺寸质量差）。

线性递增：basic=0层 → uncommon=1层 → rare=2层 → epic=3层 → unique=4层
  basic:    base_frame
  uncommon: base_frame + corner×4          → 绿色调
  rare:     base_frame + corner×4 + gem    → 金色调
  epic:     base_frame + corner×4 + gem + flourish×2    → 紫色调
  unique:   base_frame + corner×4 + gem + flourish×2 + crest → 红色调
"""
from PIL import Image, ImageDraw
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PARTS_DIR = os.path.join(BASE_DIR, "parts")
FRAMES_DIR = os.path.join(BASE_DIR, "frames")
os.makedirs(FRAMES_DIR, exist_ok=True)

FRAME_W, FRAME_H = 512, 672

BORDER_W_PCT = 0.14
ART_TOP_PCT = 0.09
ART_BOT_PCT = 0.50
DESC_TOP_PCT = 0.51
DESC_BOT_PCT = 0.93
ALPHA_THRESHOLD = 128

TINT = {
    "basic":    (1.0, 1.0, 1.0),
    "uncommon": (0.4, 1.0, 0.4),
    "rare":     (1.0, 0.85, 0.35),
    "epic":     (0.7, 0.35, 1.0),
    "unique":   (1.0, 0.35, 0.35),
}

GEM_COLORS = {
    "rare":     {"color": (255, 170, 30), "highlight": (255, 230, 150), "edge": (100, 60, 0)},
    "epic":     {"color": (170, 60, 255), "highlight": (220, 170, 255), "edge": (60, 10, 100)},
    "unique":   {"color": (240, 40, 40), "highlight": (255, 180, 180), "edge": (100, 0, 0)},
}


def load_base_frame():
    """加载AI基础边框并抠图"""
    path = os.path.join(PARTS_DIR, "base_frame.png")
    if not os.path.exists(path):
        return None
    img = Image.open(path).convert("RGBA")
    px = img.load()
    w, h = img.size
    corners = [px[0, 0], px[w-1, 0], px[0, h-1], px[w-1, h-1]]
    bg_r = sum(c[0] for c in corners) // 4
    bg_g = sum(c[1] for c in corners) // 4
    bg_b = sum(c[2] for c in corners) // 4
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if abs(r - bg_r) < 60 and abs(g - bg_g) < 60 and abs(b - bg_b) < 60:
                px[x, y] = (0, 0, 0, 0)
    return img


def apply_tint(img, tint):
    if tint == (1.0, 1.0, 1.0):
        return img
    px = img.load()
    w, h = img.size
    rg, gg, bg = tint
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0:
                px[x, y] = (min(255, int(r * rg)), min(255, int(g * gg)), min(255, int(b * bg)), a)
    return img


def draw_corner(canvas, x, y, size, color, flip_x=False, flip_y=False):
    """PIL绘制L形角饰"""
    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    s = size
    edge = color
    mid = tuple(min(255, c + 40) for c in color)
    dark = tuple(max(0, c - 40) for c in color)

    # L形主体
    thickness = s // 4
    draw.rectangle([0, 0, s, thickness], fill=edge)
    draw.rectangle([0, 0, thickness, s], fill=edge)
    # 内侧高光
    draw.rectangle([thickness//2, thickness//2, s, thickness], fill=mid)
    draw.rectangle([thickness//2, thickness//2, thickness, s], fill=mid)
    # 装饰菱形
    cx, cy = thickness + s//6, thickness + s//6
    ds = s // 6
    draw.polygon([(cx, cy-ds), (cx+ds, cy), (cx, cy+ds), (cx-ds, cy)], fill=mid)
    draw.polygon([(cx, cy-ds), (cx+ds, cy), (cx, cy+ds), (cx-ds, cy)], outline=dark)
    # 小高光点
    draw.ellipse([cx-2, cy-2, cx+2, cy+2], fill=(255, 255, 255, 200))

    if flip_x:
        overlay = overlay.transpose(Image.FLIP_LEFT_RIGHT)
    if flip_y:
        overlay = overlay.transpose(Image.FLIP_TOP_BOTTOM)

    canvas.paste(overlay, (x, y), overlay)


def draw_gem(canvas, cx, cy, size, config):
    """PIL绘制宝石"""
    overlay = Image.new("RGBA", (size*3, size*3), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    ocx, ocy = size*3//2, size*3//2

    gem_w = size
    gem_h = int(size * 0.8)
    outer = [(ocx, ocy-gem_h-3), (ocx+gem_w+3, ocy), (ocx, ocy+gem_h+3), (ocx-gem_w-3, ocy)]
    main = [(ocx, ocy-gem_h), (ocx+gem_w, ocy), (ocx, ocy+gem_h), (ocx-gem_w, ocy)]
    hl_w, hl_h = int(gem_w*0.4), int(gem_h*0.4)
    highlight = [(ocx, ocy-gem_h+4), (ocx-hl_w, ocy-hl_h+2),
                 (ocx-int(gem_w*0.15), ocy-int(gem_h*0.15)),
                 (ocx-int(gem_w*0.5), ocy-int(gem_h*0.5)+4)]

    draw.polygon(outer, fill=config["edge"])
    draw.polygon(main, fill=config["color"])
    draw.polygon(highlight, fill=config["highlight"])

    base_w = int(gem_w * 1.4)
    base_top = ocy + gem_h + 3
    base_bot = base_top + 8
    draw.polygon([(ocx-base_w, base_top), (ocx+base_w, base_top),
                  (ocx+int(base_w*0.7), base_bot), (ocx-int(base_w*0.7), base_bot)],
                 fill=config["edge"])

    px = canvas.load()
    op = overlay.load()
    ow, oh = overlay.size
    for oy in range(oh):
        for ox in range(ow):
            if op[ox, oy][3] > 0:
                tx, ty = cx - ocx + ox, cy - ocy + oy
                if 0 <= tx < canvas.size[0] and 0 <= ty < canvas.size[1]:
                    px[tx, ty] = op[ox, oy]


def draw_flourish(canvas, x, y, w, h, color, flip_x=False):
    """PIL绘制竖向花纹"""
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    mid = tuple(min(255, c + 30) for c in color)
    dark = tuple(max(0, c - 30) for c in color)

    cx = w // 2
    # 中心竖线
    draw.rectangle([cx-2, 0, cx+2, h], fill=color)
    # 菱形链
    n = 4
    for i in range(n):
        cy = h * (i + 1) // (n + 1)
        ds = w // 3
        draw.polygon([(cx, cy-ds), (cx+ds, cy), (cx, cy+ds), (cx-ds, cy)], fill=mid)
        draw.polygon([(cx, cy-ds), (cx+ds, cy), (cx, cy+ds), (cx-ds, cy)], outline=dark)
    # 端点圆
    draw.ellipse([cx-4, 0, cx+4, 8], fill=color)
    draw.ellipse([cx-4, h-8, cx+4, h], fill=color)

    if flip_x:
        overlay = overlay.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.paste(overlay, (x, y), overlay)


def draw_crest(canvas, cx, cy, w, h, color):
    """PIL绘制横向徽章"""
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    mid = tuple(min(255, c + 30) for c in color)
    dark = tuple(max(0, c - 30) for c in color)

    # 中心盾形
    sh = h
    sw = w // 3
    sx = (w - sw) // 2
    draw.polygon([(sx, 0), (sx+sw, 0), (sx+sw, sh//2), (sx+sw//2, sh), (sx, sh//2)], fill=color)
    draw.polygon([(sx, 0), (sx+sw, 0), (sx+sw, sh//2), (sx+sw//2, sh), (sx, sh//2)], outline=dark)
    # 盾内菱形
    dcx, dcy = sx + sw//2, sh//2
    ds = sw // 4
    draw.polygon([(dcx, dcy-ds), (dcx+ds, dcy), (dcx, dcy+ds), (dcx-ds, dcy)], fill=mid)
    # 两侧翼
    draw.rectangle([0, h//3, sx, h*2//3], fill=color)
    draw.rectangle([sx+sw, h//3, w, h*2//3], fill=color)
    # 翼端装饰
    for ex in [0, w-8]:
        draw.ellipse([ex, h//3, ex+8, h*2//3], fill=mid)

    canvas.paste(overlay, (cx - w//2, cy - h//2), overlay)


def compose_frame(rarity):
    base = load_base_frame()
    if base is None:
        return None

    base = apply_tint(base, TINT[rarity])
    canvas = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    canvas.paste(base, (0, 0))

    tint_color = tuple(int(200 * t) for t in TINT[rarity])

    if rarity in ("uncommon", "rare", "epic", "unique"):
        cs = 80
        margin = 3
        draw_corner(canvas, margin, margin, cs, tint_color)
        draw_corner(canvas, FRAME_W - margin - cs, margin, cs, tint_color, flip_x=True)
        draw_corner(canvas, margin, FRAME_H - margin - cs, cs, tint_color, flip_y=True)
        draw_corner(canvas, FRAME_W - margin - cs, FRAME_H - margin - cs, cs, tint_color, flip_x=True, flip_y=True)

    if rarity in ("rare", "epic", "unique"):
        gc = GEM_COLORS.get(rarity)
        if gc:
            draw_gem(canvas, FRAME_W // 2, int(FRAME_H * 0.055), 35, gc)

    if rarity in ("epic", "unique"):
        fw, fh = 40, 150
        fy = (FRAME_H - fh) // 2
        draw_flourish(canvas, 12, fy, fw, fh, tint_color)
        draw_flourish(canvas, FRAME_W - 12 - fw, fy, fw, fh, tint_color, flip_x=True)

    if rarity == "unique":
        draw_crest(canvas, FRAME_W // 2, int(FRAME_H * 0.075), 150, 35, tint_color)

    cutout(canvas)
    apply_alpha_threshold(canvas)
    return canvas


def cutout(img):
    w, h = img.size
    px = img.load()
    inner_left = int(w * BORDER_W_PCT)
    inner_right = int(w * (1 - BORDER_W_PCT))
    for y in range(int(h * ART_TOP_PCT), int(h * ART_BOT_PCT)):
        for x in range(inner_left, inner_right):
            px[x, y] = (0, 0, 0, 0)
    for y in range(int(h * DESC_TOP_PCT), int(h * DESC_BOT_PCT)):
        for x in range(inner_left, inner_right):
            px[x, y] = (0, 0, 0, 0)


def apply_alpha_threshold(img):
    w, h = img.size
    px = img.load()
    for y in range(h):
        for x in range(w):
            if 0 < px[x, y][3] < ALPHA_THRESHOLD:
                px[x, y] = (0, 0, 0, 0)


RARITY_FILES = {
    "basic": "frame_basic.png", "uncommon": "frame_uncommon.png",
    "rare": "frame_rare.png", "epic": "frame_epic.png", "unique": "frame_unique.png",
}


def main():
    print("=" * 60)
    print("部件化拼装卡框 v2（PIL装饰 + AI基础边框）")
    print("=" * 60)
    for rarity, filename in RARITY_FILES.items():
        layers = {"basic": 0, "uncommon": 1, "rare": 2, "epic": 3, "unique": 4}[rarity]
        print(f"\n[{rarity}] {layers}层装饰 → {filename}")
        canvas = compose_frame(rarity)
        if canvas:
            canvas.save(os.path.join(FRAMES_DIR, filename), "PNG")
            px = canvas.load()
            non_trans = sum(1 for y in range(canvas.size[1]) for x in range(canvas.size[0]) if px[x,y][3] > 30)
            print(f"  非透明: {non_trans} ({non_trans/(FRAME_W*FRAME_H)*100:.1f}%)")
    print("\n拼装完成！")


if __name__ == "__main__":
    main()