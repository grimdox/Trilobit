import sys
from PIL import Image
base,n,scale=sys.argv[1],int(sys.argv[2]),int(sys.argv[3])
m=open(base+".map").read().split("\n")[:n]
h=open(base+".height").read().split("\n")[:n]
col={'f':(34,85,45),'.':(60,70,50),'~':(30,70,140)}
hc={'1':(120,125,140),'2':(150,155,175),'3':(190,195,215),'4':(215,220,235),'5':(225,225,240),'6':(235,235,245),'7':(240,240,250),'9':(255,230,120),'A':(255,60,200)}
img=Image.new("RGB",(n,n)); px=img.load()
for y in range(n):
    for x in range(n):
        c=m[y][x]; hh=h[y][x]
        if c=='=': px[x,y]=(70,70,80)
        elif hh in hc: px[x,y]=hc[hh]
        else: px[x,y]=col.get(c,(40,40,40))
img.resize((n*scale,n*scale),Image.NEAREST).save(base+".png")
