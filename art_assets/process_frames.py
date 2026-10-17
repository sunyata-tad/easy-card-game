"""
处理卡框图片：
1. 用 PIL 重新保存为真正 PNG 格式（Pollinations.ai 返回 JPEG）
2. PIL 统一绘制宝石（AI 无法稳定生成宝石，改用代码绘制）
3. 精确镂空卡图区（上半部分）和描述区（下半部分），只保留外圈边框和中间分隔线

卡牌布局（512×672，比例 1:1.3125）：
- 外圈边框：约 15% 宽（扩大边框，防止遮挡）
- 宝石：顶部中心，y ≈ 3%~9%
- 卡图区：y = 10% ~ 50%, x = 15% ~ 85%  → 透明
- 中间分隔线：y = 50% ~ 52%  → 保留
- 描述区：y = 52% ~ 92%, x = 15% ~ 85%  → 透明
- 底部稀有度色带：y = 92% ~ 98%  → 保留
"""
from PIL import Image, ImageDraw
import os

FRAME_DIR = os.path.join(os.path.dirname(__file__), "frames")

# 边框保留宽度（百分比）— 镂空区比代码渲染区(15%)大1%，给缩放留余量
BORDER_W_PCT = 0.14

# 卡图区（上半部分中间）→ 透明 — 比代码渲染区(10%~48%)大，留余量
ART_TOP_PCT = 0.09
ART_BOT_PCT = 0.50

# 描述区（下半部分中间）→ 透明 — 比代码渲染区(52%~89%)大，留余量
DESC_TOP_PCT = 0.51
DESC_BOT_PCT = 0.93

# alpha 硬阈值 — 消除缩放插值产生的半透明"幽灵像素"
ALPHA_THRESHOLD = 128

# 宝石配置（按稀有度）
# basic 无宝石
GEM_CONFIG = {
    "frame_uncommon.png": {
        "color": (40, 220, 80),       # 绿宝石
        "highlight": (180, 255, 200), # 浅绿高光
        "edge": (10, 80, 25),         # 深绿描边
    },
    "frame_rare.png": {
        "color": (255, 170, 30),      # 琥珀/橙宝石
        "highlight": (255, 230, 150), # 浅金高光
        "edge": (100, 60, 0),         # 深棕描边
    },
    "frame_epic.png": {
        "color": (170, 60, 255),      # 紫宝石
        "highlight": (220, 170, 255), # 浅紫高光
        "edge": (60, 10, 100),        # 深紫描边
    },
    "frame_unique.png": {
        "color": (240, 40, 40),       # 红宝石
        "highlight": (255, 180, 180), # 浅红高光
        "edge": (100, 0, 0),          # 深红描边
    },
}


def draw_gem(img, config):
    """在卡框顶部中心绘制菱形宝石 + 高光 + 描边"""
    w, h = img.size
    cx = w // 2
    cy = int(h * 0.065)  # 宝石中心 y 位置

    gem_w = int(w * 0.11)  # 宝石半宽
    gem_h = int(h * 0.045) # 宝石半高

    draw = ImageDraw.Draw(img)

    # 菱形顶点（外圈描边）
    outer = [
        (cx, cy - gem_h - 3),
        (cx + gem_w + 3, cy),
        (cx, cy + gem_h + 3),
        (cx - gem_w - 3, cy),
    ]
    # 菱形主体
    main = [
        (cx, cy - gem_h),
        (cx + gem_w, cy),
        (cx, cy + gem_h),
        (cx - gem_w, cy),
    ]
    # 高光（左上小菱形）
    hl_w = int(gem_w * 0.4)
    hl_h = int(gem_h * 0.4)
    highlight = [
        (cx, cy - gem_h + 4),
        (cx - hl_w, cy - hl_h + 2),
        (cx - int(gem_w * 0.15), cy - int(gem_h * 0.15)),
        (cx - int(gem_w * 0.5), cy - int(gem_h * 0.5) + 4),
    ]

    # 先画描边（深色）
    draw.polygon(outer, fill=config["edge"])
    # 再画主体
    draw.polygon(main, fill=config["color"])
    # 高光
    draw.polygon(highlight, fill=config["highlight"])

    # 宝石底部金属底座（梯形）
    base_w = int(gem_w * 1.4)
    base_top = cy + gem_h + 3
    base_bot = base_top + 8
    draw.polygon([
        (cx - base_w, base_top),
        (cx + base_w, base_top),
        (cx + int(base_w * 0.7), base_bot),
        (cx - int(base_w * 0.7), base_bot),
    ], fill=config["edge"])


def cutout_frame(img):
    """镂空卡图区和描述区"""
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

    return (inner_left, art_top, inner_right, art_bot, desc_top, desc_bot)


def apply_alpha_threshold(img):
    """alpha 硬阈值：消除缩放插值产生的半透明幽灵像素。
    alpha < ALPHA_THRESHOLD 的像素强制设为完全透明。"""
    w, h = img.size
    pixels = img.load()
    changed = 0
    for y in range(h):
        for x in range(w):
            a = pixels[x, y][3]
            if 0 < a < ALPHA_THRESHOLD:
                pixels[x, y] = (0, 0, 0, 0)
                changed += 1
    return changed


def process_frame(name):
    path = os.path.join(FRAME_DIR, name)
    img = Image.open(path).convert("RGBA")
    w, h = img.size

    # 绘制宝石（basic 无宝石）
    if name in GEM_CONFIG:
        draw_gem(img, GEM_CONFIG[name])

    # 镂空
    info = cutout_frame(img)

    # alpha 硬阈值 — 消除半透明幽灵像素
    removed = apply_alpha_threshold(img)

    img.save(path, "PNG")
    gem_str = "有宝石" if name in GEM_CONFIG else "无宝石"
    print(f"处理完成: {name} ({w}x{h}) {gem_str}")
    print(f"  卡图区透明: ({info[0]},{info[1]})-({info[2]},{info[3]})")
    print(f"  描述区透明: ({info[0]},{info[4]})-({info[2]},{info[5]})")
    print(f"  alpha阈值: 移除{removed}个半透明像素")


if __name__ == "__main__":
    for name in ["frame_basic.png", "frame_uncommon.png", "frame_rare.png",
                 "frame_epic.png", "frame_unique.png"]:
        process_frame(name)
    print("全部处理完成！")