"""
分析缩放后遮挡像素的分布，确定修复方案。
"""
from PIL import Image
import os

FRAME_DIR = os.path.join(os.path.dirname(__file__), "frames")

def analyze_occlusion(frame_name, tw, th):
    frame = Image.open(os.path.join(FRAME_DIR, frame_name)).convert("RGBA")
    frame_resized = frame.resize((tw, th), Image.LANCZOS)
    px = frame_resized.load()

    # 卡图区遮挡
    art_x0, art_x1 = int(tw * 0.15), int(tw * 0.85)
    art_y0, art_y1 = int(th * 0.10), int(th * 0.48)
    art_occluded = []
    for y in range(art_y0, art_y1):
        for x in range(art_x0, art_x1):
            if px[x, y][3] > 0:
                art_occluded.append((x, y, px[x, y][3]))

    # 文字区遮挡
    text_x0, text_x1 = int(tw * 0.15), int(tw * 0.85)
    text_y0, text_y1 = int(th * 0.52), int(th * 0.89)
    text_occluded = []
    for y in range(text_y0, text_y1):
        for x in range(text_x0, text_x1):
            if px[x, y][3] > 0:
                text_occluded.append((x, y, px[x, y][3]))

    print(f"\n{frame_name} @ {tw}x{th}:")
    if art_occluded:
        xs = [p[0] for p in art_occluded]
        ys = [p[1] for p in art_occluded]
        alphas = [p[2] for p in art_occluded]
        print(f"  卡图区遮挡: {len(art_occluded)}px")
        print(f"    x范围: {min(xs)}~{max(xs)} (区域 {art_x0}~{art_x1})")
        print(f"    y范围: {min(ys)}~{max(ys)} (区域 {art_y0}~{art_y1})")
        print(f"    alpha范围: {min(alphas)}~{max(alphas)}")
        print(f"    遮挡在边缘: 左{sum(1 for x in xs if x < art_x0+3)}px 右{sum(1 for x in xs if x > art_x1-3)}px")
        print(f"    遮挡在边缘: 上{sum(1 for y in ys if y < art_y0+3)}px 下{sum(1 for y in ys if y > art_y1-3)}px")
    if text_occluded:
        xs = [p[0] for p in text_occluded]
        ys = [p[1] for p in text_occluded]
        alphas = [p[2] for p in text_occluded]
        print(f"  文字区遮挡: {len(text_occluded)}px")
        print(f"    x范围: {min(xs)}~{max(xs)} (区域 {text_x0}~{text_x1})")
        print(f"    y范围: {min(ys)}~{max(ys)} (区域 {text_y0}~{text_y1})")
        print(f"    alpha范围: {min(alphas)}~{max(alphas)}")
        print(f"    遮挡在边缘: 左{sum(1 for x in xs if x < text_x0+3)}px 右{sum(1 for x in xs if x > text_x1-3)}px")
        print(f"    遮挡在边缘: 上{sum(1 for y in ys if y < text_y0+3)}px 下{sum(1 for y in ys if y > text_y1-3)}px")


if __name__ == "__main__":
    for tw, th in [(120, 158), (268, 352)]:
        print(f"\n{'='*60}")
        print(f"尺寸 {tw}x{th}")
        print(f"{'='*60}")
        analyze_occlusion("frame_basic.png", tw, th)
        # 只分析一个，因为5个卡框结构相同