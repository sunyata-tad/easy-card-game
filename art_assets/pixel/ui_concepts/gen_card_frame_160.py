"""生成适配 Card.tscn (160x210) 的像素卡框，9-slice 10/18/10/18"""
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
    W, H = 160, 210
    img = new(W, H)
    DARK=(28,26,34,255); MID=(52,48,60,255); EDGE=(96,84,52,255)
    GOLD=(180,142,64,255); GOLD_HI=(240,210,120,255)
    ART_BG=(18,16,22,255); TXT_BG=(12,11,16,255)
    # 外金边 2px
    rect_outline(img, 0,0,W-1,H-1, GOLD)
    rect_outline(img, 1,1,W-2,H-2, GOLD)
    rect_fill(img, 2,2,W-3,H-3, DARK)
    # 上下标题/稀有度金条
    rect_fill(img, 3,3,W-4,16, MID)
    rect_fill(img, 3,H-17,W-4,H-4, MID)
    rect_outline(img, 3,3,W-4,16, GOLD)
    rect_outline(img, 3,H-17,W-4,H-4, GOLD)
    # 竖向金边
    rect_fill(img, 3,17,9,H-18, EDGE)
    rect_fill(img, W-10,17,W-4,H-18, EDGE)
    # 艺术区
    rect_fill(img, 10,17,W-11,104, ART_BG)
    rect_outline(img, 10,17,W-11,104, (60,54,70,255))
    # 文本区
    rect_fill(img, 10,105,W-11,H-18, TXT_BG)
    # 角宝石（左上红、右上蓝）
    for (gx,gy) in [(12,7),(13,6),(14,7),(13,8)]:
        px(img,gx,gy,(200,40,50,255)); 
    px(img,13,7,(255,120,120,255))
    for (gx,gy) in [(W-15,7),(W-14,6),(W-13,7),(W-14,8)]:
        px(img,gx,gy,(40,90,200,255))
    px(img,W-14,7,(120,170,255,255))
    # 顶部高光点
    for x in range(4,W-4,3):
        px(img,x,3,GOLD_HI); px(img,x,H-4,GOLD_HI)
    img.save(os.path.join(OUT, "card_frame_160x210.png"))
    with open(os.path.join(OUT,"card_frame_160x210.9.txt"),"w") as f:
        f.write("9-slice: left=10, top=18, right=10, bottom=18\n")
    print("ok")

if __name__ == "__main__":
    gen()