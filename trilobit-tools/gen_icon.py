"""Draws the pink splash-screen car as the Trilobit icon (png + multi-size ico). Usage: python3 gen_icon.py OUTDIR"""
import sys, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops
S = 1024
out = sys.argv[1] if len(sys.argv) > 1 else "."
def car(d, ld, x, y, s, body, neon):
    pts = [(0,0),(10,-14),(40,-24),(78,-26),(105,-12),(130,-8),(138,0)]
    P = [(x+s*px, y+s*py) for px,py in pts]
    d.polygon(P+[(P[-1][0],y+s*8),(P[0][0],y+s*8)], fill=body)
    d.polygon([(x+s*42,y-s*22),(x+s*76,y-s*24),(x+s*98,y-s*12),(x+s*40,y-s*12)], fill=(20,30,60))
    for wx in (28,108):
        d.ellipse([x+s*wx-s*10,y-s*2,x+s*wx+s*10,y+s*18], fill=(8,8,14))
    ld.line([(x,y+s*2),(x+s*138,y+s*2)], fill=neon, width=int(s*1.6))
    ld.line([(x-s*4,y-s*6),(x-s*70,y-s*6)], fill=neon, width=int(s*2))
bg = Image.new("RGB", (S,S))
bd = ImageDraw.Draw(bg)
for yy in range(S):
    t = yy/S
    bd.line([(0,yy),(S,yy)], fill=(int(12+243*t*t),int(6+64*t*t),int(40+100*t*t)))
bd.ellipse([S*.5-300,S*.18,S*.5+300,S*.18+600], fill=(255,200,90))   # the sun
for i in range(5):
    bd.rectangle([S*.5-300,S*.18+300+i*45,S*.5+300,S*.18+300+i*45+8+i*5], fill=(120,30,110))
bd.rectangle([0,int(S*.72),S,S], fill=(16,10,30))
L = Image.new("RGB",(S,S),(0,0,0)); ld = ImageDraw.Draw(L)
for k in range(-5,6):
    ld.line([(S/2+k*14,S*.72),(S/2+k*260,S)], fill=(120,40,200), width=5)
car(bd, ld, 150, 800, 5.3, (210,20,90), (255,60,170))
g = L.filter(ImageFilter.GaussianBlur(14))
img = ImageChops.add(ImageChops.add(bg, g), L)
mask = Image.new("L",(S,S),0)
ImageDraw.Draw(mask).rounded_rectangle([0,0,S-1,S-1], radius=170, fill=255)
img = img.convert("RGBA"); img.putalpha(mask)
os.makedirs(out, exist_ok=True)
img.resize((256,256), Image.LANCZOS).save(os.path.join(out,"icon.png"))
img.save(os.path.join(out,"icon.ico"), sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
