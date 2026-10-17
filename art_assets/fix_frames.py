"""
修复已处理的卡框：
1. 扩大镂空区域（从15%改为14%，给缩放留余量）
2. alpha 硬阈值（消除半透明幽灵像素）
不重新绘制宝石（宝石已画好）。
"""
from PIL import Image
import os

FRAME_DIR = os.path.join(os.path.dirname(__file__), "frames")

# 新的镂空区域（比之前大1%）
BORDER_W_PCT = 0.14
ART_TOP_PCT = 0.09
ART_BOT_PCT = 0.50
DESC_TOP_PCT = 0.51
DESC_BOT_PCT = 0.93
ALPHA_THRESHOLD = 128


def fix_frame(name):
    path = os.path.join(FRAME_DIR, name)
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()

    # 扩大镂空
    inner_left = int(w * BORDER_W_PCT)
    inner_right = int(w * (1 - BORDER_W_PCT))

    art_top = int(h * ART_TOP_PCT)
    art_bot = int(h * ART_BOT_PCT)
    for y in range(art_top, art_bot):
        for x in range(inner_left, inner_right):
            px[x, y] = (0, 0, 0, 0)

    desc_top = int(h * DESC_TOP_PCT)
    desc_bot = int(h * DESC_BOT_PCT)
    for y in range(desc_top, desc_bot):
        for x in range(inner_left, inner_right):
            px[x, y] = (0, 0, 0, 0)

    # alpha 硬阈值
    removed = 0
    for y in range(h):
        for x in range(w):
            a = px[x, y][3]
            if 0 < a < ALPHA_THRESHOLD:
                px[x, y] = (0, 0, 0, 0)
                removed += 1

    img.save(path, "PNG")
    print(f"修复: {name} 扩大镂空到 x[{BORDER_W_PCT*100:.0f}%~{(1-BORDER_W_PCT)*100:.0f}%] 移除{removed}个半透明像素")


if __name__ == "__main__":
    for name in ["frame_basic.png", "frame_uncommon.png", "frame_rare.png",
                 "frame_epic.png", "frame_unique.png"]:
        fix_frame(name)
    print("修复完成！")