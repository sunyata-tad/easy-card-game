"""生成匹配显示尺寸的像素按钮三态(256x56, 9-slice 4/4/4/4)，高光加粗"""
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
    W, H = 256, 56
    states = {
        "normal":  {"bg":(44,38,58,255),  "edge":(110,92,54,255),  "hi":(200,165,90,255),  "lo":(0,0,0,150)},
        "hover":   {"bg":(64,54,80,255),  "edge":(220,175,90,255), "hi":(255,225,140,255), "lo":(0,0,0,160)},
        "pressed": {"bg":(26,23,36,255),  "edge":(150,118,60,255), "hi":(210,180,100,255), "lo":(0,0,0,180)},
    }
    for name, p in states.items():
        img = new(W, H)
        rect_fill(img, 2, 2, W-3, H-3, p["bg"])
        rect_outline(img, 1, 1, W-2, H-2, p["edge"])
        rect_outline(img, 0, 0, W-1, H-1, p["edge"])
        # 顶部高光 3px
        for x in range(2, W-2):
            px(img, x, 2, p["hi"]); px(img, x, 3, p["hi"]); px(img, x, 4, p["hi"])
        # 底部阴影 3px
        for x in range(2, W-2):
            px(img, x, H-3, p["lo"]); px(img, x, H-4, p["lo"]); px(img, x, H-5, p["lo"])
        # 左右侧高光 1px
        for y in range(5, H-5):
            px(img, 2, y, p["hi"]); px(img, W-3, y, p["lo"])
        img.save(os.path.join(OUT, f"button_{name}.png"))
    with open(os.path.join(OUT, "button.9.txt"), "w") as f:
        f.write("9-slice: left=4, top=4, right=4, bottom=4\n")
    print("ok")

if __name__ == "__main__":
    gen()