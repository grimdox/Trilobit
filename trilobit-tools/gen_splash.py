import random, math, sys
from PIL import ImageDraw as _ID
_R=_ID.ImageDraw.rectangle
def _rect(self,xy,*a,**k):
    x0,y0,x1,y1=xy
    return _R(self,[min(x0,x1),min(y0,y1),max(x0,x1),max(y0,y1)],*a,**k)
_ID.ImageDraw.rectangle=_rect
from PIL import Image, ImageDraw, ImageFilter, ImageChops
W,H=1280,720
def grad(top,bot):
    im=Image.new("RGB",(W,H)); d=ImageDraw.Draw(im)
    for y in range(H):
        t=y/H; d.line([(0,y),(W,y)],fill=tuple(int(top[i]*(1-t)+bot[i]*t) for i in range(3)))
    return im
def glow(base,layer,r=12,k=1.0):
    g=layer.filter(ImageFilter.GaussianBlur(r))
    base=ImageChops.add(base,g.point(lambda v:int(v*k)))
    return ImageChops.add(base,layer)
def skyline(d,rng,y0,col,hmin,hmax,win=None):
    x=-20
    while x<W:
        w=rng.randint(40,110); h=rng.randint(hmin,hmax)
        d.rectangle([x,y0-h,x+w,y0+200],fill=col)
        if win:
            for wy in range(y0-h+10,y0,14):
                for wx in range(x+6,x+w-6,12):
                    if rng.random()<0.35: d.rectangle([wx,wy,wx+4,wy+6],fill=rng.choice(win))
        if rng.random()<.3: d.line([(x+w//2,y0-h),(x+w//2,y0-h-rng.randint(20,60))],fill=col,width=2)
        x+=w+rng.randint(0,8)
def sun(img,cx,cy,r,c1,c2):
    d=ImageDraw.Draw(img)
    for i in range(r,0,-2):
        t=i/r; d.ellipse([cx-i,cy-i,cx+i,cy+i],fill=tuple(int(c1[k]*t+c2[k]*(1-t)) for k in range(3)))
def sign(L,rng,n,cols):
    d=ImageDraw.Draw(L)
    for _ in range(n):
        x=rng.randint(0,W-60);y=rng.randint(80,380);c=rng.choice(cols)
        if rng.random()<.5: d.rectangle([x,y,x+rng.randint(8,16),y+rng.randint(40,110)],fill=c)
        else: d.rectangle([x,y,x+rng.randint(30,70),y+rng.randint(8,14)],outline=c,width=2)
def finish(img,name,L):
    img=glow(img,L,14,1.3)
    # scanlines + vignette
    d=ImageDraw.Draw(img,"RGBA")
    for y in range(0,H,3): d.line([(0,y),(W,y)],fill=(0,0,0,38))
    v=Image.new("L",(W,H),0); vd=ImageDraw.Draw(v); vd.ellipse([-W*.25,-H*.4,W*1.25,H*1.4],fill=255)
    v=v.filter(ImageFilter.GaussianBlur(120)); img=Image.composite(img,Image.new("RGB",(W,H),(5,3,14)),v)
    img.save(name)
def car(d,x,y,s,body,neon,Ld,facing=1):
    f=facing
    pts=[(0,0),(10,-14),(40,-24),(78,-26),(105,-12),(130,-8),(138,0)]
    P=[(x+f*s*px/1.0,y+s*py) for px,py in pts]
    d.polygon(P+[(P[-1][0],y+s*8),(P[0][0],y+s*8)],fill=body)
    d.polygon([(x+f*s*42,y-s*22),(x+f*s*76,y-s*24),(x+f*s*98,y-s*12),(x+f*s*40,y-s*12)],fill=(20,30,60))
    for wx in (28,108):
        d.ellipse([x+f*s*wx-s*10,y-s*2,x+f*s*wx+s*10,y+s*18],fill=(8,8,14))
    Ld.line([(x,y+s*2),(x+f*s*138,y+s*2)],fill=neon,width=3)
    Ld.line([(x-f*s*4,y-s*6),(x-f*s*160,y-s*6)],fill=neon,width=4)
def scene_race():
    rng=random.Random(7); img=grad((12,6,40),(255,70,140)); d=ImageDraw.Draw(img)
    sun(img,W//2,330,150,(255,220,90),(255,80,150)); d=ImageDraw.Draw(img)
    for i in range(6): d.rectangle([W//2-160,300+i*22,W//2+160,300+i*22+i*2+1],fill=(255,70,150)) if False else None
    skyline(d,rng,420,(26,12,56),90,300,[(255,190,60),(90,230,255)])
    skyline(d,rng,450,(12,6,30),50,200,[(255,90,180),(120,255,220)])
    d.rectangle([0,440,W,H],fill=(16,10,30))
    L=Image.new("RGB",(W,H),(0,0,0)); ld=ImageDraw.Draw(L)
    sign(L,rng,30,[(0,255,230),(255,40,160),(255,230,60)])
    # road perspective
    vx=W//2; vy=440
    d.polygon([(vx-30,vy),(vx+30,vy),(W+400,H),(-400,H)],fill=(24,20,40))
    for k in range(-6,7):
        ld.line([(vx+k*8,vy),(vx+k*260,H)],fill=(120,40,200),width=2)
    for j in range(1,14):
        y=vy+(H-vy)*(j/13)**2; ld.line([(0,y),(W,y)],fill=(80,30,150),width=1)
    ld.line([(vx-28,vy),(-380,H)],fill=(0,255,230),width=5); ld.line([(vx+28,vy),(W+380,H)],fill=(255,40,160),width=5)
    d=ImageDraw.Draw(img)
    car(d,200,640,2.2,(210,20,90),(255,60,170),ld,1)
    car(d,860,560,1.6,(20,160,220),(0,255,230),ld,1)
    car(d,520,500,1.0,(240,200,40),(255,230,60),ld,1)
    for k in range(50): 
        x=rng.randint(0,W);y=rng.randint(480,H); ld.line([(x,y),(x-rng.randint(40,160),y)],fill=(90,60,160),width=1)
    finish(img,"gfx/splash/trilobit_splash_1_race.png",L)
def humanoid(d,Ld,x,y,s,col,neon,pose):
    d.ellipse([x-12*s,y-110*s,x+12*s,y-86*s],fill=col)
    Ld.ellipse([x-5*s,y-102*s,x+7*s,y-96*s],fill=neon)
    d.polygon([(x-22*s,y-84*s),(x+22*s,y-84*s),(x+14*s,y-36*s),(x-14*s,y-36*s)],fill=col)
    d.line([(x-8*s,y-36*s),(x-14*s,y)],fill=col,width=int(11*s)); d.line([(x+8*s,y-36*s),(x+22*s,y-4*s)],fill=col,width=int(11*s))
    a=pose
    d.line([(x+18*s,y-78*s),(x+a[0]*s,y+a[1]*s)],fill=col,width=int(9*s)); d.line([(x-18*s,y-78*s),(x-a[2]*s,y+a[3]*s)],fill=col,width=int(9*s))
    for (px,py) in [(x+a[0]*s,y+a[1]*s),(x-a[2]*s,y+a[3]*s)]:
        Ld.ellipse([px-6*s,py-6*s,px+6*s,py+6*s],fill=neon)
    Ld.line([(x-14*s,y-70*s),(x+14*s,y-70*s)],fill=neon,width=2)
def scene_cyborg():
    rng=random.Random(3); img=grad((8,16,48),(40,10,90)); d=ImageDraw.Draw(img)
    skyline(d,rng,500,(14,10,36),150,420,[(0,160,150)])
    skyline(d,rng,540,(8,6,22),100,260,[(160,140,40)])
    d.rectangle([0,540,W,H],fill=(14,10,26))
    L=Image.new("RGB",(W,H),(0,0,0)); ld=ImageDraw.Draw(L)
    sign(L,rng,40,[(0,255,230),(255,40,160),(255,230,60)])
    for y in range(560,H,16): ld.line([(0,y),(W,y)],fill=(30,20,70),width=1)
    for i in range(60):
        x=rng.randint(0,W); ld.line([(x,0),(x-30,H)],fill=(25,40,70),width=1)  # rain
    d=ImageDraw.Draw(img)
    humanoid(d,ld,400,650,3.4,(70,78,130),(0,255,230),(80,-30,60,-90))
    humanoid(d,ld,880,650,3.4,(110,70,120),(255,50,160),(-90,-80,-20,-30))
    # katana-like beam & impact
    ld.line([(520,330),(760,250)],fill=(255,255,255),width=5); ld.line([(520,330),(760,250)],fill=(0,255,230),width=11)
    for k in range(40):
        a=rng.random()*6.28; r=rng.randint(10,120)
        ld.line([(640,300),(640+r*math.cos(a),300+r*math.sin(a))],fill=(255,220,120),width=2)
    ld.ellipse([620,280,660,320],fill=(255,255,255))
    ld.rectangle([0,640,W,644],fill=(0,200,200))
    finish(img,"gfx/splash/trilobit_splash_2_cyborg.png",L)
def mech(d,Ld,x,y,s,col,neon,f):
    d.rectangle([x-40*s,y-250*s,x+40*s,y-170*s],fill=col)   # torso
    d.polygon([(x-30*s,y-250*s),(x+30*s,y-250*s),(x+18*s,y-290*s),(x-18*s,y-290*s)],fill=col) # head
    Ld.rectangle([x+f*4*s-14*s,y-278*s,x+f*4*s+14*s,y-270*s],fill=neon)
    d.rectangle([x-55*s,y-250*s,x-35*s,y-220*s],fill=col); d.rectangle([x+35*s,y-250*s,x+55*s,y-220*s],fill=col) # shoulders
    d.polygon([(x-30*s,y-170*s),(x+30*s,y-170*s),(x+22*s,y-135*s),(x-22*s,y-135*s)],fill=col)
    for sx in (-1,1):
        lx=x+sx*20*s
        d.line([(lx,y-135*s),(lx+sx*10*s,y-70*s),(lx,y)],fill=col,width=int(22*s))
        d.rectangle([lx-22*s,y-8*s,lx+22*s,y+6*s],fill=col)
    ax=x+f*50*s
    d.line([(ax,y-235*s),(ax+f*60*s,y-190*s)],fill=col,width=int(20*s))
    d.rectangle([ax+f*50*s-18*s,y-200*s,ax+f*110*s,y-180*s],fill=col)  # cannon
    Ld.rectangle([ax+f*100*s,y-196*s,ax+f*112*s,y-184*s],fill=neon)
    Ld.line([(x-30*s,y-215*s),(x+30*s,y-215*s)],fill=neon,width=3)
    Ld.line([(x-6*s,y-170*s),(x+6*s,y-170*s)],fill=neon,width=3)
def scene_mech():
    rng=random.Random(11); img=grad((30,10,60),(255,120,60)); d=ImageDraw.Draw(img)
    sun(img,W//2,300,220,(255,240,150),(255,100,60)); d=ImageDraw.Draw(img)
    skyline(d,rng,520,(40,16,70),100,360,[(255,200,80)])
    skyline(d,rng,560,(14,8,32),60,200,[(0,160,150)])
    d.rectangle([0,560,W,H],fill=(12,8,24))
    L=Image.new("RGB",(W,H),(0,0,0)); ld=ImageDraw.Draw(L)
    sign(L,rng,25,[(0,255,230),(255,40,160),(255,230,60)])
    for y in range(570,H,18): ld.line([(0,y),(W,y)],fill=(60,24,100),width=1)
    d=ImageDraw.Draw(img)
    mech(d,ld,300,690,2.1,(70,60,118),(0,255,230),1)
    mech(d,ld,980,690,2.1,(120,56,110),(255,50,160),-1)
    # beams / missiles
    ld.line([(520,370),(850,330)],fill=(0,255,230),width=9); ld.line([(520,370),(850,330)],fill=(255,255,255),width=3)
    for k in range(7):
        y=250+k*12; ld.line([(900,y-40+k*4),(560,y+60+k*10)],fill=(255,200,120),width=1)
    ld.ellipse([840,305,880,355],fill=(255,255,255))
    for k in range(50):
        a=rng.random()*6.28;r=rng.randint(10,90); ld.line([(860,330),(860+r*math.cos(a),330+r*math.sin(a))],fill=(255,80,160),width=2)
    finish(img,"gfx/splash/trilobit_splash_3_mechs.png",L)
scene_race(); scene_cyborg(); scene_mech()
