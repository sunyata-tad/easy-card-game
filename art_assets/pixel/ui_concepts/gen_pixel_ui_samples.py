"""
像素美术 UI 示例图生成器（纯描点）
生成：卡框、按钮三态、面板边框、血条/能量条
Usage: python gen_pixel_ui_samples.py
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.dirname(os.path.abspath(__file__))


def new(w, h, bg=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), bg)


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect_fill(img, x0, y0, x1, y1, c):
    d = ImageDraw.Draw(img)
    d.rectangle([x0, y0, x1, y1], fill=c)


def rect_outline(img, x0, y0, x1, y1, c):
    d = ImageDraw.Draw(img)
    d.rectangle([x0, y0, x1, y1], outline=c)


# ---------- 1. 像素卡框 (80x112, 9-slice 友好) ----------
def gen_card_frame():
    W, H = 80, 112
    img = new(W, H)
    # 调色板：暗铁 + 金边
    DARK = (28, 26, 34, 255)
    MID = (52, 48, 60, 255)
    EDGE = (96, 84, 52, 255)
    GOLD = (180, 142, 64, 255)
    GOLD_HI = (240, 210, 120, 255)
    ART_BG = (18, 16, 22, 255)
    TXT_BG = (12, 11, 16, 255)
    # 外金边 1px
    rect_outline(img, 0, 0, W - 1, H - 1, GOLD)
    # 内暗铁填充
    rect_fill(img, 1, 1, W - 2, H - 2, DARK)
    # 上下金条（标题栏 + 稀有度条）
    rect_fill(img, 2, 2, W - 3, 8, MID)
    rect_fill(img, 2, H - 9, W - 3, H - 3, MID)
    rect_outline(img, 2, 2, W - 3, 8, GOLD)
    rect_outline(img, 2, H - 9, W - 3, H - 3, GOLD)
    # 竖向金边
    rect_fill(img, 2, 9, 4, H - 10, EDGE)
    rect_fill(img, W - 5, 9, W - 3, H - 10, EDGE)
    # 艺术区背景
    rect_fill(img, 5, 9, W - 6, 56, ART_BG)
    rect_outline(img, 5, 9, W - 6, 56, (60, 54, 70, 255))
    # 文本区背景
    rect_fill(img, 5, 57, W - 6, H - 10, TXT_BG)
    # 角宝石（左上菱形红宝石）
    gem = [(6, 4), (7, 3), (8, 4), (7, 5)]
    for (gx, gy) in gem:
        px(img, gx, gy, (200, 40, 50, 255))
    px(img, 7, 4, (255, 120, 120, 255))
    # 右上蓝宝石
    gem2 = [(W - 9, 4), (W - 8, 3), (W - 7, 4), (W - 8, 5)]
    for (gx, gy) in gem2:
        px(img, gx, gy, (40, 90, 200, 255))
    px(img, W - 8, 4, (120, 170, 255, 255))
    # 高光点
    for x in range(3, W - 3, 2):
        px(img, x, 2, GOLD_HI)
        px(img, x, H - 3, GOLD_HI)
    # 9-slice 切线标记（导出时去掉，这里仅示意用透明十字不画）
    img.save(os.path.join(OUT, "sample_card_frame.png"))
    # 同时导出 9-slice 元数据
    with open(os.path.join(OUT, "sample_card_frame.9.txt"), "w") as f:
        f.write("9-slice: left=5, top=9, right=5, bottom=9\n")


# ---------- 2. 像素按钮三态 (64x24) ----------
def gen_button_states():
    W, H = 64, 24
    states = {
        "normal": {"bg": (40, 36, 52, 255), "edge": (90, 78, 48, 255), "hi": (150, 120, 60, 255)},
        "hover": {"bg": (58, 50, 72, 255), "edge": (200, 160, 80, 255), "hi": (250, 220, 130, 255)},
        "pressed": {"bg": (24, 22, 32, 255), "edge": (140, 110, 56, 255), "hi": (200, 170, 90, 255)},
    }
    for name, p in states.items():
        img = new(W, H)
        rect_fill(img, 1, 1, W - 2, H - 2, p["bg"])
        rect_outline(img, 0, 0, W - 1, H - 1, p["edge"])
        # 顶部高光 1px
        for x in range(2, W - 2):
            px(img, x, 1, p["hi"])
        # 底部阴影 1px
        for x in range(2, W - 2):
            px(img, x, H - 2, (0, 0, 0, 120))
        # 斜面内角点
        px(img, 1, 1, p["hi"])
        px(img, W - 2, 1, p["hi"])
        px(img, 1, H - 2, (0, 0, 0, 120))
        px(img, W - 2, H - 2, (0, 0, 0, 120))
        # 简易像素箭头光标（hover 态）
        if name == "hover":
            ax, ay = 8, 9
            for (dx, dy) in [(0, 0), (1, 1), (2, 2), (0, 1), (0, 2), (0, 3)]:
                px(img, ax + dx, ay + dy, (255, 255, 255, 255))
        img.save(os.path.join(OUT, f"sample_button_{name}.png"))


# ---------- 3. 像素面板边框 (96x64, 9-slice) ----------
def gen_panel_border():
    W, H = 96, 64
    img = new(W, H)
    STONE = (54, 50, 64, 255)
    STONE_HI = (86, 80, 100, 255)
    STONE_LO = (28, 26, 34, 255)
    RUNE = (120, 200, 220, 255)
    rect_fill(img, 0, 0, W - 1, H - 1, (20, 18, 26, 255))
    # 双层石边
    rect_outline(img, 0, 0, W - 1, H - 1, STONE)
    rect_outline(img, 2, 2, W - 3, H - 3, STONE_HI)
    rect_outline(img, 3, 3, W - 4, H - 4, STONE_LO)
    # 角块（加粗角）
    for (cx, cy) in [(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)]:
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                px(img, cx + dx, cy + dy, STONE_HI)
    # 角符文点
    for (rx, ry) in [(4, 4), (W - 5, 4), (4, H - 5), (W - 5, H - 5)]:
        px(img, rx, ry, RUNE)
        px(img, rx + 1, ry, (60, 120, 140, 255))
    # 顶部标题凹陷条
    rect_fill(img, 6, 6, W - 7, 10, (12, 11, 18, 255))
    rect_outline(img, 6, 6, W - 7, 10, STONE_LO)
    img.save(os.path.join(OUT, "sample_panel_border.png"))
    with open(os.path.join(OUT, "sample_panel_border.9.txt"), "w") as f:
        f.write("9-slice: left=4, top=4, right=4, bottom=4\n")


# ---------- 4. 像素血条/能量条 ----------
def gen_bars():
    W, H = 120, 14
    # 血条
    img = new(W, H)
    rect_fill(img, 0, 0, W - 1, H - 1, (30, 12, 14, 255))
    rect_outline(img, 0, 0, W - 1, H - 1, (90, 40, 44, 255))
    fill = 78
    for x in range(2, 2 + fill):
        for y in range(2, H - 2):
            shade = (180, 40, 44, 255) if y < H // 2 else (120, 24, 28, 255)
            px(img, x, y, shade)
    # 顶部高光
    for x in range(2, 2 + fill):
        px(img, x, 2, (255, 120, 120, 255))
    # 分段刻度
    for x in range(2, 2 + fill, 6):
        px(img, x, 2, (0, 0, 0, 160))
        px(img, x, H - 3, (0, 0, 0, 160))
    img.save(os.path.join(OUT, "sample_bar_hp.png"))
    # 能量条
    img2 = new(W, H)
    rect_fill(img2, 0, 0, W - 1, H - 1, (14, 22, 40, 255))
    rect_outline(img2, 0, 0, W - 1, H - 1, (44, 80, 150, 255))
    fill2 = 52
    for x in range(2, 2 + fill2):
        for y in range(2, H - 2):
            shade = (60, 110, 220, 255) if y < H // 2 else (36, 70, 150, 255)
            px(img2, x, y, shade)
    for x in range(2, 2 + fill2):
        px(img2, x, 2, (150, 200, 255, 255))
    img2.save(os.path.join(OUT, "sample_bar_energy.png"))


if __name__ == "__main__":
    gen_card_frame()
    gen_button_states()
    gen_panel_border()
    gen_bars()
    print("done ->", OUT)