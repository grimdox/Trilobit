#!/usr/bin/env python3
"""Render floor plans of the generated towers to PNG. usage: render_towers.py <mod dir> <out dir>"""
import sys, os
sys.argv_orig = sys.argv[:]
out = sys.argv[2]; sys.argv = [sys.argv[0], sys.argv[1]]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_towers as g
from PIL import Image, ImageDraw
S = 8
COL = {"air": (14, 14, 22), "walk": (60, 60, 70), "pave": (70, 70, 80), "grass": (40, 90, 50), "water": (30, 70, 150), "shallow": (60, 120, 190),
       "roof": (80, 80, 90), "balcony": (110, 110, 120), "rail": (200, 200, 210), "window": (110, 200, 220), "wall_glass": (110, 200, 220),
       "door_c": (80, 220, 240), "wdoor": (190, 140, 70), "ldoor": (160, 100, 50), "mdoor": (150, 150, 160), "mdoor_l": (190, 90, 90),
       "shutter_c": (200, 80, 60), "screen_c": (170, 220, 140), "bars": (230, 230, 240), "cell_door": (230, 200, 120),
       "stair_up": (255, 255, 255), "stair_down": (255, 230, 120), "marble": (225, 225, 235), "carpet_red": (150, 40, 50),
       "carpet_grey": (95, 95, 105), "carpet_teal": (40, 110, 115), "floor_wood": (130, 90, 50), "tatami": (150, 170, 100),
       "tile_bath": (130, 170, 200), "floor_clean": (200, 230, 240), "epoxy": (80, 80, 85), "hazard": (200, 170, 40), "slab": (105, 100, 95),
       "checker": (170, 170, 175), "floor_corp": (160, 185, 190), "floor_plain": (140, 135, 130), "grating": (90, 100, 105),
       "neon_cyan": (60, 220, 240), "neon_amber": (240, 180, 50), "neon_pink": (240, 80, 190), "wall_neon": (230, 70, 180)}
def col(k):
    if k in COL: return COL[k]
    if k.startswith("wall_"): return {"wall_gilt": (200, 160, 40), "wall_lacquer": (35, 30, 40), "wall_clean": (235, 240, 245), "wall_corp": (225, 225, 230),
                                       "wall_rust": (140, 70, 50), "wall_brick": (130, 60, 55), "wall_pipes": (70, 80, 85), "wall_mural": (80, 120, 170),
                                       "wall_slat": (110, 80, 50)}.get(k, (150, 150, 150))
    return (120, 120, 120)
def render(L):
    im = Image.new("RGB", (L.W * S, L.H * S)); d = ImageDraw.Draw(im)
    for y in range(L.H):
        for x in range(L.W): d.rectangle([x * S, y * S, x * S + S - 1, y * S + S - 1], fill=col(L.t[y][x]))
    for k, x, y in L.f:
        lit = g.F[k]["light"] > 0
        c = (255, 235, 120) if lit else (30, 30, 35)
        if lit: d.rectangle([x * S + 2, y * S + 2, x * S + S - 3, y * S + S - 3], fill=c)
        else: d.ellipse([x * S + 2, y * S + 2, x * S + S - 3, y * S + S - 3], fill=c)
    return im
os.makedirs(out, exist_ok=True)
sheet = []
for b in g.BUILDINGS:
    lv = g.build_levels(b)
    n = len(lv); W, H = lv[0].W * S, lv[0].H * S
    cols = n if W * n <= 2400 else (n + 1) // 2
    rows = (n + cols - 1) // cols
    im = Image.new("RGB", (cols * (W + 8) + 8, rows * (H + 24) + 8), (20, 20, 28)); d = ImageDraw.Draw(im)
    for i, L in enumerate(lv):
        cx, cy = 8 + (i % cols) * (W + 8), 8 + (i // cols) * (H + 24)
        im.paste(render(L), (cx, cy + 14)); d.text((cx, cy), f"{b['name']} - floor {i}" if i < n - 1 else f"{b['name']} - roof", fill=(230, 230, 240))
    im.save(os.path.join(out, b["id"] + ".png"))
    sheet.append((b, lv[0]))
# contact sheet of ground floors
cw = max(L.W for _, L in sheet) * 4 + 12
cols = 5; rows = (len(sheet) + cols - 1) // cols
mx = max(L.H for _, L in sheet) * 4 + 22
cs = Image.new("RGB", (cols * cw + 8, rows * mx + 8), (20, 20, 28)); d = ImageDraw.Draw(cs)
for i, (b, L) in enumerate(sheet):
    im = render(L).resize((L.W * 4, L.H * 4), Image.NEAREST)
    x, y = 8 + (i % cols) * cw, 8 + (i // cols) * mx
    cs.paste(im, (x, y + 14)); d.text((x, y), b["id"][4:] + " " + b["name"], fill=(230, 230, 240))
cs.save(os.path.join(out, "overview_ground_floors.png"))
print("rendered", len(sheet))
