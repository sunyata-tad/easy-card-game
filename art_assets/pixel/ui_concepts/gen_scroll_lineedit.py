"""像素滚动条与输入框纹理(滚动条 16x16 9-slice 3; 输入框 256x48 9-slice 4)"""
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

def gen_scroll():
    W, H = 16, 16
    states = {
        "normal":  {"bg":(54,50,72,255),  "edge":(110,92,54,255),  "hi":(180,150,80,255), "lo":(0,0,0,140)},
        "hover":   {"bg":(74,64,96,255),  "edge":(200,165,90,255), "hi":(255,225,140,255),"lo":(0,0,0,150)},
        "pressed": {"bg":(36,32,50,255),  "edge":(150,118,60,255), "hi":(210,180,100,255),"lo":(0,0,0,170)},
    }
    for name, p in states.items():
        img = new(W, H)
        rect_fill(img, 1, 1, W-2, H-2, p["bg"])
        rect_outline(img, 0, 0, W-1, H-1, p["edge"])
        for x in range(1, W-1):
            px(img, x, 1, p["hi"])
            px(img, x, H-2, p["lo"])
        for y in range(2, H-2):
            px(img, 1, y, p["hi"])
            px(img, W-2, y, p["lo"])
        mid = H // 2
        for x in range(3, W-3):
            px(img, x, mid-1, p["edge"])
            px(img, x, mid, p["edge"])
            px(img, x, mid+1, p["edge"])
        img.save(os.path.join(OUT, f"scroll_grabber_{name}.png"))
    bg = new(W, H)
    rect_fill(bg, 0, 0, W-1, H-1, (14, 14, 20, 255))
    rect_outline(bg, 0, 0, W-1, H-1, (40, 38, 50, 255))
    rect_outline(bg, 1, 1, W-2, H-2, (8, 8, 12, 255))
    bg.save(os.path.join(OUT, "scroll_bg.png"))

def gen_lineedit():
    W, H = 256, 48
    states = {
        "normal":  {"bg":(20,22,34,255),  "edge":(70,68,90,255),   "hi":(90,88,110,255),  "lo":(0,0,0,120)},
        "focus":   {"bg":(20,22,34,255),  "edge":(200,165,90,255), "hi":(255,225,140,255),"lo":(0,0,0,140)},
        "readonly":{"bg":(10,11,18,255),  "edge":(40,40,52,255),   "hi":(50,50,62,255),   "lo":(0,0,0,100)},
    }
    for name, p in states.items():
        img = new(W, H)
        rect_fill(img, 2, 2, W-3, H-3, p["bg"])
        rect_outline(img, 1, 1, W-2, H-2, p["edge"])
        rect_outline(img, 0, 0, W-1, H-1, p["edge"])
        for x in range(2, W-2):
            px(img, x, 2, p["hi"]); px(img, x, 3, p["hi"])
            px(img, x, H-3, p["lo"]); px(img, x, H-4, p["lo"])
        for y in range(4, H-4):
            px(img, 2, y, p["hi"]); px(img, W-3, y, p["lo"])
        img.save(os.path.join(OUT, f"lineedit_{name}.png"))

def gen():
    gen_scroll()
    gen_lineedit()
    with open(os.path.join(OUT, "scroll_lineedit.9.txt"), "w") as f:
        f.write("9-slice: scroll 16x16 margin=3; lineedit 256x48 margin=4\n")
    print("ok")

if __name__ == "__main__":
    gen()