#!/usr/bin/env python3
"""Apartment towers (design doc M15): six tall residential mid-rises (7 to 10 floors) with flats full of named human residents.
Two poor, two middle and two rich towers.  Run AFTER gen_midrise.py, gen_midrise2.py and gen_residents.py.  usage: gen_apts.py <mod dir>"""
import hashlib, json, os, random, sys
MOD = sys.argv[1]
sys.argv = [sys.argv[0], MOD]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_midrise as mr
from gen_midrise import gp, T, F, FLOORS
import gen_midrise2  # registers its furniture
import gen_residents as gr

B3 = []
def a(id, name, sym, color, tier, stories, wall, window, floor_g, floor_u, room_g, room_u, hall, lobby, loot, signs):
    B3.append(dict(id=f"trl_apt{len(B3)+1:02d}_{id}", name=name, theme="apt", sym=sym, color=color, stories=stories, tier=tier,
                   wall_g=wall, wall_u=wall, window=window, floor_g=floor_g, floor_u=floor_u,
                   ground=("apts", dict(room=room_g, hall=hall, lobby_items=lobby)), upper=("apts", dict(room=room_u, hall=hall)),
                   loot_g=loot, loot_u=loot, signs=signs))

POOR_R = [("futon", 2), ("table_low", 1), ("hotplate", 1), ("laundry", 1), ("tv_static", 1), ("desk_lamp", 1)]
MID_R = [("futon", 1), ("table_low", 1), ("desk_corp", 1), ("chair_office", 1), ("floor_lamp", 1), ("console", 1), ("fern", 1)]
RICH_R = [("futon", 1), ("cabinet_lacquer", 1), ("chair_lounge", 2), ("vase_white", 1), ("bonsai", 1), ("floor_lamp", 1), ("holo_ad", 1)]
a("tenement_tower", "tenement tower (cheap flats)", "A", "brown", "poor", 8, "wall_concrete", "window", "slab", "floor_dirty",
  POOR_R, POOR_R, [("laundry", 2), ("bike_rack", 1), ("trash", 1)], [("vending", 1), ("trash", 1)], "dingy", ["neon_amber", "lantern"])
a("rusted_stack", "rusted housing stack", "A", "red", "poor", 7, "wall_rust", "window_bars", "slab", "floor_dirty",
  POOR_R, POOR_R, [("laundry", 2), ("pipes", 1)], [("fire_drum", 1), ("trash", 2)], "dingy", ["neon_red", "lantern"])
a("family_tower", "family apartment tower", "A", "light_gray", "mid", 9, "wall_concrete", "window", "floor_wood", "floor_wood",
  MID_R, MID_R, [("fern", 1), ("laundry", 1), ("bike_rack", 1)], [("fern", 2), ("vending", 1), ("reception", 1)], "food", ["neon_green", "lantern"])
a("salaried_tower", "salaried residence tower", "A", "light_blue", "mid", 10, "wall_corp", "window", "carpet_red", "floor_corp",
  MID_R, MID_R, [("fern", 2), ("water_cooler", 1)], [("reception", 1), ("fern", 2), ("neon_cyan", 1)], "decor", ["neon_cyan", "neon_amber"])
a("luxury_residences", "luxury residence tower", "A", "light_green", "rich", 10, "wall_neon", "window", "floor_wood", "floor_wood",
  RICH_R, RICH_R, [("vase_white", 2), ("bonsai", 1)], [("reception", 1), ("bonsai", 2), ("vase_tall", 1), ("holo_ad", 1)], "decor", ["neon_pink", "neon_violet"])
a("skyline_condos", "skyline condominiums", "A", "white", "rich", 9, "wall_mural", "window", "floor_corp", "floor_wood",
  RICH_R, RICH_R, [("vase_tall", 2), ("fern", 1)], [("reception", 1), ("bonsai", 2), ("fountain", 1), ("holo_ad", 1)], "decor", ["neon_pink", "neon_cyan"])


def main():
    gp.assign_chars()
    mr.emit(B3, "midrise3", new_t=set(), new_f=set(), write_loot=False)
    path = os.path.join(MOD, "midrise3", "mapgen.json")
    mg = json.load(open(path))
    byid = {m["om_terrain"][0]: m for m in mg}
    total = 0
    for S in B3:
        jobs = list(gr.JOBS[S["tier"]])
        for z in range(0, S["stories"]):
            if z == 0:
                continue                       # the ground floor is the lobby; residents live upstairs
            g = S["_g"][z]
            rooms = [(3, 3, 7, 8), (9, 3, 14, 8), (16, 3, 20, 8), (3, 16, 7, 20), (16, 16, 20, 20)]
            npcs = []
            r = random.Random(f"{S['id']}-{z}")
            for ri, (x0, y0, x1, y1) in enumerate(rooms):
                if r.random() < 0.55:          # about half of the flats are occupied
                    cells = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if g.free(x, y)]
                    if not cells:
                        continue
                    h = int(hashlib.md5(f"{S['id']}/{z}/{ri}".encode()).hexdigest()[:8], 16)
                    job = jobs[h % len(jobs)]
                    x, y = r.choice(cells)
                    npcs.append({"class": gr.template_id(S["tier"], job), "x": x, "y": y})
                    g.occ.add((x, y))
            if npcs:
                mg_obj = byid[f"{S['id']}_z{z}"]["object"]
                mg_obj["place_npcs"] = npcs
                total += len(npcs)
    json.dump(mg, open(path, "w"), indent=1)
    # weights: these are a prominent part of the mid-rise district
    ro_path = os.path.join(MOD, "region_overlay.json")
    ro = json.load(open(ro_path))
    for S in B3:
        ro[0]["city"]["parks"][S["id"]] = 1296 * 2
    json.dump(ro, open(ro_path, "w"), indent=1)
    print(len(B3), "apartment towers,", total, "residents")


if __name__ == "__main__":
    main()
