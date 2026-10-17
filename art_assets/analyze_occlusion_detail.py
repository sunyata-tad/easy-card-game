"""
精确分析缩放后遮挡的性质：
- 半透明幽灵像素（缩放插值产生，Godot中也会存在但几乎不可见）
- 实心边框侵入（完全不透明像素进入渲染区，可见问题）
"""
from PIL import Image
import os

FRAME_DIR = os.path.join(os.path.dirname(__file__), "frames")

def analyze_occlusion_detail(frame_name, tw, th):
    frame = Image.open(os.path.join(FRAME_DIR, frame_name)).convert("RGBA")
    frame_resized = frame.resize((tw, th), Image.LANCZOS)
    px = frame_resized.load()

    regions = {
        "卡图区": (int(tw*0.15), int(th*0.10), int(tw*0.85), int(th*0.48)),
        "文字区": (int(tw*0.15), int(th*0.52), int(tw*0.85), int(th*0.89)),
    }

    print(f"\n{frame_name} @ {tw}x{th}:")
    for rname, (x0, y0, x1, y1) in regions.items():
        # 按alpha分段统计
        bins = {">200(实心)": 0, "128~200": 0, "50~128": 0, "1~50": 0, "0(透明)": 0}
        occluded_positions = []
        for y in range(y0, y1):
            for x in range(x0, x1):
                a = px[x, y][3]
                if a == 0:
                    bins["0(透明)"] += 1
                elif a <= 50:
                    bins["1~50"] += 1
                    occluded_positions.append((x, y, a))
                elif a <= 128:
                    bins["50~128"] += 1
                    occluded_positions.append((x, y, a))
                elif a <= 200:
                    bins["128~200"] += 1
                    occluded_positions.append((x, y, a))
                else:
                    bins[">200(实心)"] += 1
                    occluded_positions.append((x, y, a))

        total = sum(bins.values())
        occluded = total - bins["0(透明)"]
        print(f"  {rname} ({x1-x0}x{y1-y0}={total}px):")
        print(f"    透明: {bins['0(透明)']}px ({bins['0(透明)']/total*100:.1f}%)")
        print(f"    遮挡: {occluded}px ({occluded/total*100:.1f}%)")
        for k in [">200(实心)", "128~200", "50~128", "1~50"]:
            if bins[k] > 0:
                print(f"      alpha {k}: {bins[k]}px")

        # 如果有实心像素侵入，报告位置
        solid = [(x,y,a) for x,y,a in occluded_positions if a > 200]
        if solid:
            xs = [p[0] for p in solid]
            ys = [p[1] for p in solid]
            print(f"    ⚠️ 实心像素侵入: x[{min(xs)}~{max(xs)}] y[{min(ys)}~{max(ys)}]")

        # 如果做alpha阈值128后还有多少遮挡
        after_threshold = sum(1 for x,y,a in occluded_positions if a >= 128)
        print(f"    alpha阈值128后仍遮挡: {after_threshold}px")


if __name__ == "__main__":
    for tw, th in [(120, 158), (268, 352)]:
        print(f"\n{'='*60}")
        print(f"尺寸 {tw}x{th}")
        print(f"{'='*60}")
        analyze_occlusion_detail("frame_basic.png", tw, th)