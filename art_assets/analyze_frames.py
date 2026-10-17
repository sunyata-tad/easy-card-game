"""
卡框规范分析脚本 v2 — 修复边框检查 + 增加分隔线和可视化。

核心检查：
1. 边框宽度：从外向内找连续非透明区域的宽度
2. 分隔线区域（y=50%~52%）是否有边框内容
3. 透明区域精确边界
4. 生成可视化对比图（透明区 vs 代码渲染区）
5. 逐行透明度统计
"""
from PIL import Image, ImageDraw
import os

FRAME_DIR = os.path.join(os.path.dirname(__file__), "frames")
EXPECTED_W, EXPECTED_H = 512, 672

# 代码渲染区域（百分比）— 来自 deck_config_scene.gd
CODE_ART = {"x": (0.15, 0.85), "y": (0.10, 0.48)}
CODE_TEXT = {"x": (0.15, 0.85), "y": (0.52, 0.89)}
CODE_BAND = {"x": (0.15, 0.85), "y": (0.93, 0.97)}

# process_frames.py 镂空区域
CUT_ART = {"x": (0.15, 0.85), "y": (0.10, 0.50)}
CUT_DESC = {"x": (0.15, 0.85), "y": (0.52, 0.92)}


def analyze_frame(name):
    path = os.path.join(FRAME_DIR, name)
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()

    result = {"name": name, "w": w, "h": h}

    # 1. 边框宽度：从外向内找第一个透明像素
    def border_from_left(y):
        for x in range(w):
            if px[x, y][3] == 0:
                return x
        return w

    def border_from_right(y):
        for x in range(w - 1, -1, -1):
            if px[x, y][3] == 0:
                return w - 1 - x
        return w

    def border_from_top(x):
        for y in range(h):
            if px[x, y][3] == 0:
                return y
        return h

    def border_from_bottom(x):
        for y in range(h - 1, -1, -1):
            if px[x, y][3] == 0:
                return h - 1 - y
        return h

    # 在多个位置采样边框宽度
    sample_ys = [int(h * p) for p in [0.05, 0.25, 0.55, 0.75, 0.95]]
    sample_xs = [int(w * p) for p in [0.05, 0.25, 0.50, 0.75, 0.95]]

    borders = {}
    for y in sample_ys:
        borders[f"y={y/h*100:.0f}%"] = {
            "left": border_from_left(y),
            "right": border_from_right(y),
        }
    for x in sample_xs:
        borders[f"x={x/w*100:.0f}%"] = {
            "top": border_from_top(x),
            "bottom": border_from_bottom(x),
        }
    result["borders"] = borders

    # 2. 分隔线区域（y=50%~52%）透明度统计
    sep_y_start = int(h * 0.49)
    sep_y_end = int(h * 0.53)
    sep_total = 0
    sep_trans = 0
    for y in range(sep_y_start, sep_y_end):
        for x in range(int(w * 0.15), int(w * 0.85)):
            sep_total += 1
            if px[x, y][3] == 0:
                sep_trans += 1
    result["separator"] = {
        "y_range": (sep_y_start, sep_y_end),
        "transparency_pct": round(sep_trans / sep_total * 100, 1) if sep_total else 0,
    }

    # 3. 透明区域精确边界
    def find_trans_bounds(y_start, y_end):
        min_x, min_y = w, h
        max_x, max_y = 0, 0
        for y in range(y_start, min(y_end, h)):
            for x in range(w):
                if px[x, y][3] == 0:
                    if x < min_x: min_x = x
                    if x > max_x: max_x = x
                    if y < min_y: min_y = y
                    if y > max_y: max_y = y
        return {
            "x_pct": (round(min_x / w * 100, 1), round(max_x / w * 100, 1)),
            "y_pct": (round(min_y / h * 100, 1), round(max_y / h * 100, 1)),
        }

    result["art_trans"] = find_trans_bounds(int(h * 0.08), int(h * 0.55))
    result["desc_trans"] = find_trans_bounds(int(h * 0.50), int(h * 0.95))

    # 4. 逐区域透明度统计（检查镂空是否干净）
    def region_transparency(x0, y0, x1, y1):
        total = 0
        trans = 0
        for y in range(y0, y1):
            for x in range(x0, x1):
                total += 1
                if px[x, y][3] == 0:
                    trans += 1
        return round(trans / total * 100, 1) if total else 0

    # 卡图区应100%透明
    result["art_region_trans"] = region_transparency(
        int(w * 0.15), int(h * 0.10), int(w * 0.85), int(h * 0.48)
    )
    # 描述区应100%透明
    result["desc_region_trans"] = region_transparency(
        int(w * 0.15), int(h * 0.52), int(w * 0.85), int(h * 0.89)
    )
    # 分隔线区域应保留边框（低透明度）
    result["sep_region_trans"] = region_transparency(
        int(w * 0.15), int(h * 0.50), int(w * 0.85), int(h * 0.52)
    )
    # 色带区域应保留（低透明度）
    result["band_region_trans"] = region_transparency(
        int(w * 0.15), int(h * 0.93), int(w * 0.85), int(h * 0.97)
    )

    return result


def generate_visual(name):
    """生成可视化对比图：卡框 + 代码渲染区域标注"""
    path = os.path.join(FRAME_DIR, name)
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    vis = img.copy()
    draw = ImageDraw.Draw(vis)

    # 红色框：代码卡图区
    draw.rectangle([
        int(w * 0.15), int(h * 0.10), int(w * 0.85), int(h * 0.48)
    ], outline=(255, 0, 0, 255), width=2)
    # 绿色框：代码文字区
    draw.rectangle([
        int(w * 0.15), int(h * 0.52), int(w * 0.85), int(h * 0.89)
    ], outline=(0, 255, 0, 255), width=2)
    # 蓝色框：代码色带区
    draw.rectangle([
        int(w * 0.15), int(h * 0.93), int(w * 0.85), int(h * 0.97)
    ], outline=(0, 100, 255, 255), width=2)
    # 黄色框：镂空卡图区
    draw.rectangle([
        int(w * 0.15), int(h * 0.10), int(w * 0.85), int(h * 0.50)
    ], outline=(255, 255, 0, 255), width=1)
    # 黄色框：镂空描述区
    draw.rectangle([
        int(w * 0.15), int(h * 0.52), int(w * 0.85), int(h * 0.92)
    ], outline=(255, 255, 0, 255), width=1)

    out_path = os.path.join(FRAME_DIR, name.replace(".png", "_vis.png"))
    vis.save(out_path)
    return out_path


def print_report(results):
    print("=" * 80)
    print("卡框规范分析报告 v2（像素级精确检查）")
    print("=" * 80)

    print("\n图例: 红=代码卡图区 绿=代码文字区 蓝=代码色带区 黄=镂空区域")

    # 边框宽度
    print("\n## 1. 边框宽度（从外向内到第一个透明像素）")
    print(f"  规范要求: 左右边框 >= 15% = {int(EXPECTED_W*0.15)}px")
    for r in results:
        print(f"\n  {r['name']} ({r['w']}×{r['h']}):")
        for key, val in r["borders"].items():
            if "left" in val:
                lp = val["left"] / r["w"] * 100
                rp = val["right"] / r["w"] * 100
                sym = "⚠️不对称" if abs(val["left"] - val["right"]) > 5 else "✅"
                print(f"    {key}: 左={val['left']}px({lp:.1f}%) 右={val['right']}px({rp:.1f}%) {sym}")
            else:
                tp = val["top"] / r["h"] * 100
                bp = val["bottom"] / r["h"] * 100
                print(f"    {key}: 上={val['top']}px({tp:.1f}%) 下={val['bottom']}px({bp:.1f}%)")

    # 透明区域
    print("\n## 2. 透明区域精确边界")
    print(f"  规范: 卡图区 x[15%~85%] y[10%~50%], 描述区 x[15%~85%] y[52%~92%]")
    for r in results:
        at = r["art_trans"]
        dt = r["desc_trans"]
        print(f"  {r['name']}:")
        print(f"    卡图区透明: x[{at['x_pct'][0]}%~{at['x_pct'][1]}%] y[{at['y_pct'][0]}%~{at['y_pct'][1]}%]")
        print(f"    描述区透明: x[{dt['x_pct'][0]}%~{dt['x_pct'][1]}%] y[{dt['y_pct'][0]}%~{dt['y_pct'][1]}%]")

    # 区域透明度
    print("\n## 3. 区域透明度（应100%透明的区域）")
    print(f"  卡图区(代码渲染区) 应100%透明, 描述区(代码渲染区) 应100%透明")
    print(f"  分隔线区(y50%~52%) 应低透明度(保留边框), 色带区(y93%~97%) 应低透明度(保留)")
    for r in results:
        print(f"  {r['name']}:")
        print(f"    卡图区透明度={r['art_region_trans']}% {'✅' if r['art_region_trans'] > 99 else '⚠️未完全透明'}")
        print(f"    描述区透明度={r['desc_region_trans']}% {'✅' if r['desc_region_trans'] > 99 else '⚠️未完全透明'}")
        print(f"    分隔线透明度={r['sep_region_trans']}% {'✅有边框' if r['sep_region_trans'] < 50 else '⚠️分隔线缺失'}")
        print(f"    色带透明度={r['band_region_trans']}% {'✅有内容' if r['band_region_trans'] < 80 else '⚠️色带缺失'}")

    # 分隔线
    print("\n## 4. 分隔线区域（y=49%~53%）详细分析")
    for r in results:
        sep = r["separator"]
        print(f"  {r['name']}: 透明度={sep['transparency_pct']}%")

    # 对齐问题
    print("\n## 5. 对齐问题诊断")
    for r in results:
        at = r["art_trans"]
        dt = r["desc_trans"]
        issues = []
        # 卡图区透明是否覆盖代码渲染区
        if at["y_pct"][1] < 47.5:
            issues.append(f"卡图镂空区底部 {at['y_pct'][1]}% < 代码卡图底部 48%，卡图被边框遮挡")
        # 描述区透明是否覆盖代码渲染区
        if dt["y_pct"][1] < 88.5:
            issues.append(f"描述镂空区底部 {dt['y_pct'][1]}% < 代码文字底部 89%，文字被边框遮挡")
        # 分隔线是否有内容
        if r["sep_region_trans"] > 50:
            issues.append(f"分隔线区域透明度 {r['sep_region_trans']}%，分隔线缺失")
        # 色带是否有内容
        if r["band_region_trans"] > 80:
            issues.append(f"色带区域透明度 {r['band_region_trans']}%，色带缺失")

        if issues:
            print(f"  {r['name']}: ❌")
            for iss in issues:
                print(f"    - {iss}")
        else:
            print(f"  {r['name']}: ✅ 无问题")

    print("\n" + "=" * 80)


if __name__ == "__main__":
    frame_names = [
        "frame_basic.png", "frame_uncommon.png", "frame_rare.png",
        "frame_epic.png", "frame_unique.png",
    ]
    results = [analyze_frame(n) for n in frame_names]
    print_report(results)

    # 生成可视化对比图
    print("\n生成可视化对比图...")
    for n in frame_names:
        p = generate_visual(n)
        print(f"  {p}")

    print("\n完成！可视化图中: 红=卡图区 绿=文字区 蓝=色带区 黄=镂空区")