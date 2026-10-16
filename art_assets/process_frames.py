"""
处理卡框图片：将中间区域设为透明，只保留边框和宝石装饰。
处理后的卡框可以作为最上层渲染，边框和宝石可见，中间透明不遮挡卡图和文字。
"""
from PIL import Image, ImageDraw
import os

FRAME_DIR = os.path.join(os.path.dirname(__file__), "frames")

# 边框保留宽度（百分比）
BORDER_W_PCT = 0.07  # 左右边框保留 7%
BORDER_H_PCT = 0.06  # 上下边框保留 6%

def process_frame(name):
    path = os.path.join(FRAME_DIR, name)
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    pixels = img.load()

    # 中间透明区域的边界
    inner_left = int(w * BORDER_W_PCT)
    inner_right = int(w * (1 - BORDER_W_PCT))
    inner_top = int(h * BORDER_H_PCT)
    inner_bottom = int(h * (1 - BORDER_H_PCT))

    # 将中间区域设为透明
    for y in range(inner_top, inner_bottom):
        for x in range(inner_left, inner_right):
            pixels[x, y] = (0, 0, 0, 0)

    # 保存
    img.save(path, "PNG")
    print(f"处理完成: {name} ({w}x{h}), 透明区域: ({inner_left},{inner_top})-({inner_right},{inner_bottom})")

if __name__ == "__main__":
    for name in ["frame_basic.png", "frame_uncommon.png", "frame_rare.png", "frame_epic.png", "frame_unique.png"]:
        process_frame(name)
    print("全部处理完成！")