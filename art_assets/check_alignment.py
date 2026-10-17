"""
生成卡框+渲染区域合成对比图，直观显示对齐情况。

在 120×158（小卡牌）和 268×352（详情卡）两种尺寸下：
- 将卡框缩放到目标尺寸
- 用彩色矩形标注代码渲染区域（卡图区、文字区、色带区）
- 用半透明填充标注镂空区域
- 输出合成图供直接查看
"""
from PIL import Image, ImageDraw, ImageFont
import os

FRAME_DIR = os.path.join(os.path.dirname(__file__), "frames")
OUT_DIR = os.path.join(os.path.dirname(__file__), "frame_compare")
os.makedirs(OUT_DIR, exist_ok=True)

# 目标尺寸
SIZES = {
    "small_120x158": (120, 158),
    "detail_268x352": (268, 352),
    "original_512x672": (512, 672),
}

# 代码渲染区域（百分比）
REGIONS = {
    "art": {"x": (0.15, 0.85), "y": (0.10, 0.48), "color": (255, 0, 0, 80), "label": "卡图区"},
    "text": {"x": (0.15, 0.85), "y": (0.52, 0.89), "color": (0, 255, 0, 80), "label": "文字区"},
    "band": {"x": (0.15, 0.85), "y": (0.93, 0.97), "color": (0, 100, 255, 80), "label": "色带区"},
}


def make_composite(frame_name, target_w, target_h):
    """生成合成图：卡框 + 渲染区域标注"""
    frame_path = os.path.join(FRAME_DIR, frame_name)
    frame = Image.open(frame_path).convert("RGBA")
    frame_resized = frame.resize((target_w, target_h), Image.LANCZOS)

    # 创建合成图（左边卡框，右边标注对比）
    composite = Image.new("RGBA", (target_w * 2 + 20, target_h + 30), (20, 20, 30, 255))
    draw = ImageDraw.Draw(composite)

    # 左边：纯卡框
    composite.paste(frame_resized, (0, 30))

    # 右边：卡框 + 区域标注
    right_x = target_w + 20
    composite.paste(frame_resized, (right_x, 30))
    overlay = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)

    for key, r in REGIONS.items():
        x0 = int(target_w * r["x"][0])
        x1 = int(target_w * r["x"][1])
        y0 = int(target_h * r["y"][0])
        y1 = int(target_h * r["y"][1])
        # 半透明填充
        odraw.rectangle([x0, y0, x1, y1], fill=r["color"])
        # 边框
        edge_color = r["color"][:3] + (255,)
        odraw.rectangle([x0, y0, x1, y1], outline=edge_color, width=2)

    composite.paste(overlay, (right_x, 30), overlay)

    # 标注文字
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 12)
    except:
        font = ImageFont.load_default()

    draw.text((5, 5), f"{frame_name} {target_w}x{target_h}", fill=(255, 255, 255), font=font)
    draw.text((right_x, 5), "+ 区域标注", fill=(255, 255, 255), font=font)

    # 在右边图上标注区域名称
    for key, r in REGIONS.items():
        x0 = int(target_w * r["x"][0])
        y0 = int(target_h * r["y"][0])
        draw.text((right_x + x0 + 2, 30 + y0 + 2), r["label"],
                  fill=r["color"][:3] + (255,), font=font)

    return composite


def make_alignment_check(frame_name, target_w, target_h):
    """生成对齐检查图：检查卡框透明区域是否与代码渲染区域对齐。
    绿色=对齐（透明区覆盖渲染区），红色=未对齐（渲染区有边框遮挡）"""
    frame_path = os.path.join(FRAME_DIR, frame_name)
    frame = Image.open(frame_path).convert("RGBA")
    frame_resized = frame.resize((target_w, target_h), Image.LANCZOS)
    px = frame_resized.load()

    img = Image.new("RGBA", (target_w, target_h), (20, 20, 30, 255))
    draw = ImageDraw.Draw(img)

    # 检查卡图区：代码渲染区内的每个像素，卡框是否透明
    art_x0 = int(target_w * 0.15)
    art_x1 = int(target_w * 0.85)
    art_y0 = int(target_h * 0.10)
    art_y1 = int(target_h * 0.48)
    art_issues = 0
    for y in range(art_y0, art_y1):
        for x in range(art_x0, art_x1):
            if px[x, y][3] == 0:
                img.putpixel((x, y), (0, 255, 0, 200))  # 绿=透明(对齐)
            else:
                img.putpixel((x, y), (255, 0, 0, 200))  # 红=不透明(遮挡)
                art_issues += 1

    # 检查文字区
    text_x0 = int(target_w * 0.15)
    text_x1 = int(target_w * 0.85)
    text_y0 = int(target_h * 0.52)
    text_y1 = int(target_h * 0.89)
    text_issues = 0
    for y in range(text_y0, text_y1):
        for x in range(text_x0, text_x1):
            if px[x, y][3] == 0:
                img.putpixel((x, y), (0, 255, 0, 200))
            else:
                img.putpixel((x, y), (255, 0, 0, 200))
                text_issues += 1

    # 绘制边框轮廓
    draw.rectangle([art_x0, art_y0, art_x1, art_y1], outline=(255, 255, 0, 255), width=1)
    draw.rectangle([text_x0, text_y0, text_x1, text_y1], outline=(255, 255, 0, 255), width=1)

    return img, art_issues, text_issues


if __name__ == "__main__":
    frame_names = [
        "frame_basic.png", "frame_uncommon.png", "frame_rare.png",
        "frame_epic.png", "frame_unique.png",
    ]

    print("=" * 70)
    print("卡框对齐检查 — 缩放后像素级验证")
    print("=" * 70)

    for size_name, (tw, th) in SIZES.items():
        print(f"\n## 尺寸 {size_name} ({tw}x{th})")
        print(f"  卡图区: x[{int(tw*0.15)}~{int(tw*0.85)}] y[{int(th*0.10)}~{int(th*0.48)}]")
        print(f"  文字区: x[{int(tw*0.15)}~{int(tw*0.85)}] y[{int(th*0.52)}~{int(th*0.89)}]")

        for fn in frame_names:
            comp = make_composite(fn, tw, th)
            comp_path = os.path.join(OUT_DIR, f"{fn.replace('.png','')}_{size_name}_composite.png")
            comp.save(comp_path)

            align_img, art_iss, text_iss = make_alignment_check(fn, tw, th)
            align_path = os.path.join(OUT_DIR, f"{fn.replace('.png','')}_{size_name}_align.png")
            align_img.save(align_path)

            status = "✅" if art_iss == 0 and text_iss == 0 else "❌"
            print(f"  {fn}: {status} 卡图遮挡={art_iss}px 文字遮挡={text_iss}px")

    print(f"\n合成图保存到: {OUT_DIR}")
    print("  *_composite.png: 左=纯卡框 右=卡框+区域标注")
    print("  *_align.png: 绿=透明(对齐) 红=不透明(遮挡) 黄=区域边界")
    print("=" * 70)