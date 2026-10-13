#!/usr/bin/env python3
"""Shop buildings: implant, nanohack, grocery and android shops in poor, middle and rich versions.
Imported by gen_places.py, which hands over its helpers through register(env)."""
import shopdata as SD

LOOK = {  # tier -> wall, floor, counter, shelf, seat
    "p": dict(wall="wall_rust", floor="slab", counter="table_plastic", shelf="shelf_scrap", seat="bench_scrap", neon="neon_red", win=False),
    "m": dict(wall="wall_corp", floor="floor_corp", counter="reception", shelf="shelf_clean", seat="chair_office", neon="neon_cyan", win=True),
    "r": dict(wall="wall_neon", floor="floor_wood", counter="reception", shelf="cabinet_lacquer", seat="chair_lounge", neon="neon_pink", win=True),
}


def register(env):
    G, shell, PLACES, ensure_lights = env["G"], env["shell"], env["PLACES"], env["ensure_lights"]

    def decor(g, t):
        """Tier flavour that every shop shares."""
        k = LOOK[t]
        g.f_(k["neon"], 11, 4); g.f_("holo_ad", 6, 4) if t != "p" else g.f_("lantern", 6, 4)
        if t == "p":
            g.f_("trash", 4, 19); g.f_("fire_drum", 20, 19); g.f_("neon_green", 17, 4); g.f_("crate", 19, 6)
        elif t == "m":
            g.f_("fern", 4, 19); g.f_("vending", 20, 19); g.f_("floor_lamp", 20, 5); g.f_("neon_amber", 17, 4)
        else:
            g.f_("aquarium", 19, 8); g.f_("vase_white", 4, 19); g.f_("vase_tall", 20, 19); g.f_("bonsai", 4, 6); g.f_("neon_violet", 17, 4); g.f_("holo_ad", 15, 4)
        g.f_("street_lamp" if t == "p" else "floor_lamp", 3, 5)

    def bay(g, fid, x, y):
        g.extra = getattr(g, "extra", [])
        g.extra.append((fid, x, y)); g.occ.add((x, y))
        for dx, dy, key in ((-1, 0, "desk_lamp"), (1, 0, "console"), (0, 1, "chair_office")):
            g.f_(key, x + dx, y + dy)

    def implant(g, t):
        k = LOOK[t]
        shell(g, 2, 3, 21, 20, k["wall"], k["floor"], door="elock_c", win=k["win"])
        g.line(k["counter"], 5, 13, 16, 13)
        g.line(k["shelf"], 5, 5, 18, 5)
        g.line("lightbox", 4, 14, 4, 18)
        g.line("lightbox", 6, 8, 16, 8) if t != "p" else g.line("shelf_scrap", 6, 8, 16, 8)
        bay(g, f"f_trl_autodoc_imp_{t}", 18, 16)
        for x in (7, 9, 11): g.f_(k["seat"], x, 18)
        decor(g, t)

    def nano(g, t):
        k = LOOK[t]
        shell(g, 2, 3, 21, 20, k["wall"], k["floor"], door="elock_c", win=k["win"])
        g.line(k["counter"], 5, 13, 16, 13)
        g.line("server_rack", 5, 5, 18, 5)
        for x in (6, 10, 14, 18): g.f_("console", x, 7)
        g.line("lightbox", 4, 15, 4, 18)
        g.f_("holo_ad", 12, 16); g.f_("holo_ad", 8, 16)
        bay(g, f"f_trl_autodoc_nano_{t}", 18, 16)
        for x in (7, 9): g.f_(k["seat"], x, 18)
        decor(g, t)

    def grocery(g, t):
        k = LOOK[t]
        shell(g, 2, 3, 21, 20, k["wall"], k["floor"], door="elock_c", win=k["win"])
        g.line(k["counter"], 7, 13, 15, 13)
        for y in (5, 8): g.line(k["shelf"] if t != "r" else "shelf_clean", 5, y, 18, y)
        for x in (6, 9, 13, 16): g.line("shelf_clean" if t != "p" else "shelf_scrap", x, 15, x, 18)
        for y in (6, 7, 8, 9, 10): g.f_("vending", 20, y)
        for y in (15, 16, 17): g.f_("vending", 3, y)
        g.f_("lightbox", 6, 13); g.f_("lightbox", 16, 13)
        decor(g, t)

    def android(g, t):
        k = LOOK[t]
        shell(g, 2, 3, 21, 20, k["wall"], k["floor"], door="elock_c", win=k["win"])
        g.line(k["counter"], 5, 13, 16, 13)
        for x in (5, 8, 11, 14, 17):
            g.f_("capsule", x, 5)
            g.f_("charging_pod", x + 1, 5)
        for x in (5, 9, 14, 18): g.f_("holo_ad", x, 7)
        g.line("lightbox", 4, 15, 4, 18)
        for x in (8, 11, 14): g.f_(k["seat"], x, 17)
        if t == "r":
            for x in (6, 17): g.f_("statue_fox", x, 16)
        decor(g, t)

    fur = env["fur"]
    SOLID, SEAT = env["SOLID"], env["SEAT"]
    fur("ward_bed", "hospital bed", "A rail-sided bed with a thin mattress and a clipboard.", "B", "light_cyan", flags=env["SOLID"], comfort=2)
    fur("ward_iv", "IV stand", "A drip stand on wheels.", "!", "white", flags=SOLID, passable=True)
    fur("ward_cabinet", "medicine cabinet", "A locked glass cabinet of drugs and dressings.", "C", "light_green", flags=SOLID)
    fur("ward_gurney", "ward_gurney", "A wheeled stretcher.", "=", "light_gray", flags=SOLID, passable=True)
    fur("ward_scanner", "body scanner", "A ring-shaped scanner with a padded table.", "O", "light_cyan", 8, flags=SOLID)

    def post(g, t):
        """a power charging post just outside the building's east wall"""
        g.extra = getattr(g, "extra", [])
        g.extra.append((f"f_trl_recharge_{t}", 22, 12)); g.occ.add((22, 12))

    def hospital(g, t):
        k = LOOK[t]
        shell(g, 2, 3, 21, 20, k["wall"], k["floor"], door="elock_c", win=k["win"] or True)
        g.line(k["counter"], 5, 13, 16, 13)
        for x in (4, 8, 12, 16):              # ward row along the north wall
            g.f_("ward_bed", x, 5); g.f_("ward_iv", x + 1, 5)
        for x in (4, 8, 12, 16):
            g.f_("ward_bed", x, 8); g.f_("ward_iv", x + 1, 8)
        g.line("ward_cabinet", 19, 5, 19, 9)
        g.f_("ward_scanner", 19, 16); g.f_("ward_gurney", 17, 16); g.f_("console", 20, 16)
        g.line("lightbox", 4, 15, 4, 18)
        for x in (7, 9, 11): g.f_(k["seat"], x, 18)
        g.f_("vending", 20, 19)
        decor(g, t)
        post(g, t); g.f_("street_lamp", 22, 14)

    FN = {"implant": implant, "nano": nano, "grocery": grocery, "android": android}
    for kind, tiers in SD.TIERS.items():
        for t in tiers:
            def wrapped(g, kind=kind, t=t):
                FN[kind](g, t)
                ensure_lights(g)
            def with_post(g, kind=kind, t=t):
                wrapped(g)
                post(g, t)
            PLACES.append(dict(id=SD.pid(kind, t), name=SD.NAME[(kind, t)], sym=SD.SYM[kind], color=SD.COLOR[t], fn=with_post, tag="shop", service=True))
    for t in "mr":
        def hosp(g, t=t):
            hospital(g, t); ensure_lights(g)
        PLACES.append(dict(id=f"trl_pl_hospital_{t}", name={"m": "hospital", "r": "private hospital"}[t], sym="H", color="light_red" if t == "m" else "white",
                           fn=hosp, tag="shop", service=True))
