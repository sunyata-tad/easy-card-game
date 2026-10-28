"""像素血条背景与填充(32x14, 9-slice 2/2/2/2)"""
import os
from PIL import Image, ImageDraw

OUT = os.path.dirname(os.path.abspath(__file__))

def new(w, h, bg=(0,0,0,0)): return Image.new("RGBA", (w, h), bg)
def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)
def rect_fill(img, x0, y0, x1, y1, c):
    ImageDraw.Draw(img).rectangle([x0,y0,x1,y1], fill=c)
def rect_outline(img, x0, y0, x1, y1, c):
    ImageDraw.Draw(img).rectangle([x0,y0,x1,y1], outline=c)

def gen():
    W, H = 32, 14
    # 背景：暗色凹槽 + 石边
    bg = new(W, H)
    rect_fill(bg, 0, 0, W-1, H-1, (18, 16, 22, 255))
    rect_outline(bg, 0, 0, W-1, H-1, (54, 50, 64, 255))
    rect_outline(bg, 1, 1, W-2, H-2, (28, 26, 34, 255))
    # 顶部内阴影
    for x in range(2, W-2):
        px(bg, x, 2, (10, 9, 14, 255))
    bg.save(os.path.join(OUT, "progress_bg.png"))

    # 填充：红色 + 顶高光 + 底阴影
    fill = new(W, H)
    rect_fill(fill, 0, 0, W-1, H-1, (150, 30, 34, 255))
    for x in range(0, W):
        px(fill, x, 0, (220, 60, 64, 255))
        px(fill, x, 1, (255, 110, 110, 255))
        px(fill, x, H-1, (90, 18, 22, 255))
        px(fill, x, H-2, (110, 22, 26, 255))
    fill.save(os.path.join(OUT, "progress_fill.png"))
    with open(os.path.join(OUT, "progress.9.txt"), "w") as f:
        f.write("9-slice: bg left=2, top=2, right=2, bottom=2; fill stretch\n")
    print("ok")

if __name__ == "__main__":
    gen()