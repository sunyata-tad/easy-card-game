"""像素面板边框(256x192, 9-slice 6/6/6/6)，中间单色暗背景，双层石边+角符文"""
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
    W, H = 256, 192
    img = new(W, H)
    STONE=(54,50,64,255); STONE_HI=(86,80,100,255); STONE_LO=(28,26,34,255)
    RUNE=(120,200,220,255); MID_BG=(20,18,26,255)
    # 中间单色背景（拉伸后均匀）
    rect_fill(img, 0, 0, W-1, H-1, MID_BG)
    # 双层石边
    rect_outline(img, 0, 0, W-1, H-1, STONE)
    rect_outline(img, 1, 1, W-2, H-2, STONE_HI)
    rect_outline(img, 2, 2, W-3, H-3, STONE_LO)
    rect_outline(img, 5, 5, W-6, H-6, STONE_LO)
    # 四角加粗角块 6x6
    for (cx, cy) in [(0,0),(W-1,0),(0,H-1),(W-1,H-1)]:
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                px(img, cx+dx, cy+dy, STONE_HI)
    # 角符文点
    for (rx, ry) in [(7,7),(W-8,7),(7,H-8),(W-8,H-8)]:
        px(img, rx, ry, RUNE); px(img, rx+1, ry, (60,120,140,255))
    img.save(os.path.join(OUT, "panel_border.png"))
    with open(os.path.join(OUT, "panel_border.9.txt"), "w") as f:
        f.write("9-slice: left=6, top=6, right=6, bottom=6\n")
    print("ok")

if __name__ == "__main__":
    gen()