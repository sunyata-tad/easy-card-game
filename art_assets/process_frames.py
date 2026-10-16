"""
处理卡框图片：
1. 用 PIL 重新保存为真正 PNG 格式（Pollinations.ai 返回 JPEG）
2. 精确镂空卡图区（上半部分）和描述区（下半部分），只保留外圈边框和中间分隔线

卡牌布局（512×672，比例 1:1.3125）：
- 外圈边框：约 11% 宽（扩大边框，防止遮挡）
- 卡图区：y = 8% ~ 50%, x = 11% ~ 89%  → 透明
- 中间分隔线：y = 50% ~ 52%  → 保留
- 描述区：y = 52% ~ 93%, x = 11% ~ 89%  → 透明
- 底部稀有度色带：y = 93% ~ 98%  → 保留
"""
from PIL import Image
import os

FRAME_DIR = os.path.join(os.path.dirname(__file__), "frames")

# 边框保留宽度（百分比）— 扩大到 15% 防止遮挡
BORDER_W_PCT = 0.15   # 左右边框保留 15%

# 卡图区（上半部分中间）→ 透明
ART_TOP_PCT = 0.10
ART_BOT_PCT = 0.50

# 描述区（下半部分中间）→ 透明
DESC_TOP_PCT = 0.52
DESC_BOT_PCT = 0.92


def process_frame(name):
    path = os.path.join(FRAME_DIR, name)
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    pixels = img.load()

    inner_left = int(w * BORDER_W_PCT)
    inner_right = int(w * (1 - BORDER_W_PCT))

    # 卡图区透明
    art_top = int(h * ART_TOP_PCT)
    art_bot = int(h * ART_BOT_PCT)
    for y in range(art_top, art_bot):
        for x in range(inner_left, inner_right):
            pixels[x, y] = (0, 0, 0, 0)

    # 描述区透明
    desc_top = int(h * DESC_TOP_PCT)
    desc_bot = int(h * DESC_BOT_PCT)
    for y in range(desc_top, desc_bot):
        for x in range(inner_left, inner_right):
            pixels[x, y] = (0, 0, 0, 0)

    img.save(path, "PNG")
    print(f"处理完成: {name} ({w}x{h})")
    print(f"  卡图区透明: ({inner_left},{art_top})-({inner_right},{art_bot})")
    print(f"  描述区透明: ({inner_left},{desc_top})-({inner_right},{desc_bot})")


if __name__ == "__main__":
    for name in ["frame_basic.png", "frame_uncommon.png", "frame_rare.png",
                 "frame_epic.png", "frame_unique.png"]:
        process_frame(name)
    print("全部处理完成！")