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
            any(g.tank(x, y, True) for x, y in ((19, 10), (19, 6), (17, 10), (4, 10), (18, 16))); any(g.tank(x, y) for x, y in ((20, 11), (3, 12), (3, 6), (20, 17))); g.f_("vase_white", 4, 19); g.f_("vase_tall", 20, 19); g.f_("bonsai", 4, 6); g.f_("neon_violet", 17, 4); g.f_("holo_ad", 15, 4)
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

    def pet(g, t):
        k = LOOK[t]
        shell(g, 2, 3, 21, 20, k["wall"], k["floor"], door="elock_c", win=k["win"])
        g.line(k["counter"], 5, 13, 16, 13)
        # fish wall along the north: wide tanks and small ones, more of them in the rich shop
        xs = (4, 8, 12, 16) if t == "r" else (4, 9, 14)
        for x in xs:
            g.tank(x, 5, True)
        for x in ((6, 10, 14, 18) if t == "r" else (7, 12, 17)):
            g.tank(x, 7, False)
        # animal pens on the south: lit pen displays and crates, with a few tame animals loose inside
        for x in (5, 9, 13, 17):
            g.f_("lightbox", x, 16); g.f_("crate", x, 18)
        g.mons += [("mon_trl_dog", 7, 17), ("mon_trl_cat", 11, 17), ("mon_trl_rabbit", 15, 17)]
        if t == "r":
            g.mons += [("mon_trl_cat", 19, 17)]
        g.line(k["shelf"], 19, 15, 19, 18)
        for x in (7, 9): g.f_(k["seat"], x, 11)
        decor(g, t)

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

    def substation(g):
        """a fenced transformer yard (no staff): where the grid's feeder cables come up in the city"""
        shell(g, 2, 3, 21, 20, "wall_concrete", "gravel", door="elock_c", win=False)
        g.extra = getattr(g, "extra", [])
        for y in (6, 10, 14, 18):
            for x in (5, 9, 13, 17):
                g.extra.append(("f_trl_transformer" if (x + y) % 8 else "f_trl_substation_unit", x, y)); g.occ.add((x, y))
        for x, y in ((3, 4), (20, 4), (3, 19), (20, 19)):
            g.extra.append(("f_trl_pylon", x, y)); g.occ.add((x, y))
        for x, y in ((11, 4), (11, 19), (3, 12), (20, 12)):
            g.f_("street_lamp", x, y)
        g.f_("neon_cyan", 7, 20); g.f_("neon_cyan", 15, 20)


    # ---- restaurants: five dining styles share a kitchen behind a counter
    fur = env["fur"]
    SOLID, SEAT, SURF = env["SOLID"], env["SEAT"], ["TRANSPARENT", "FLAT_SURF", "MOUNTABLE"]
    fur("kitchen_range", "kitchen range", "A heavy steel range with burners, a griddle and a hanging rack of pans.", "&", "light_gray", 4, flags=SOLID)
    fur("pizza_oven", "brick pizza oven", "A domed brick oven with a fire glowing in its mouth.", "O", "light_red", 8, flags=SOLID)
    fur("sushi_case", "sushi display case", "A chilled glass case of fish and rice, lit from within.", "=", "light_cyan", 5, flags=SOLID + ["FLAT_SURF"])
    fur("menu_board", "menu board", "A framed board listing the day's dishes and drinks.", "m", "white", 3, flags=SOLID, passable=True)
    fur("liquor_shelf", "liquor shelf", "A lit glass shelf of bottles behind the bar.", "H", "yellow", 5, flags=SOLID + ["FLAT_SURF"])
    fur("dining_table", "dining table", "A small table with a place setting.", "T", "brown", flags=SURF)
    fur("cloth_table", "white-cloth table", "A table dressed in white linen with a candle at its centre.", "T", "white", 3, flags=SURF)
    fur("kitchen_fridge", "kitchen cooler", "A steel walk-in cooler door with a frosted window.", "C", "light_cyan", flags=SOLID)

    def restaurant(g, t, kind):
        rec = SD.REST[kind]
        style, theme = rec[3], rec[2]
        k = LOOK[t]
        shell(g, 2, 3, 21, 20, k["wall"], k["floor"], door="elock_c", win=k["win"])
        # kitchen along the north: ranges, coolers, shelves; the specialty sets the main appliance
        main = {"pizza": "pizza_oven", "sushi": "sushi_case", "ramen": "counter_noodle", "kaiseki": "sushi_case"}.get(theme, "kitchen_range")
        for x in (5, 8, 11, 14, 17):
            g.f_(main if x in (8, 14) else "kitchen_range", x, 5)
        g.line("kitchen_fridge", 4, 4, 18, 4) if t != "p" else g.line("shelf_scrap", 4, 4, 18, 4)
        g.f_("workbench", 20, 5); g.f_("kitchen_fridge", 20, 8); g.f_("trash", 20, 10)
        # the counter, with the worker behind it
        g.line("counter_noodle" if style in ("counter", "stall") else k["counter"], 5, 11, 16, 11)
        if style == "bar" or theme == "lounge":
            g.line("liquor_shelf", 5, 9, 16, 9)
        else:
            g.line("shelf_scrap" if t == "p" else "shelf_clean", 5, 8, 16, 8)
        g.f_("menu_board", 3, 7); g.f_("menu_board", 17, 12)
        # dining room to the south
        seat, table = {"p": ("stool_plastic", "table_plastic"), "m": ("chair_office", "dining_table"), "r": ("chair_lounge", "cloth_table")}[t]
        if style in ("counter", "stall"):
            for x in range(5, 17, 2):
                g.f_("bar_stool", x, 12)
        if style == "bar":
            for x in range(5, 17, 2):
                g.f_("bar_stool", x, 12)
        if style in ("tables", "formal", "bar", "counter"):
            cols = (5, 9, 13, 17) if style != "formal" else (6, 11, 16)
            rows = (15, 18) if style != "stall" else (15,)
            for ty in rows:
                for tx in cols:
                    g.f_(table, tx, ty)
                    g.f_(seat, tx - 1, ty); g.f_(seat, tx + 1, ty)
        else:
            for tx in (6, 12, 18):
                g.f_("table_plastic", tx, 16); g.f_("stool_plastic", tx, 15); g.f_("stool_plastic", tx, 17)
        # theme dressing
        if theme in ("ramen", "sushi", "izakaya", "donburi", "kaiseki"):
            g.f_("lantern", 3, 14); g.f_("lantern", 20, 14); g.f_("wind_chime", 3, 18)
        if theme in ("pizza", "italian", "french", "spanish", "steak"):
            g.f_("vase_red", 20, 17)
        if t == "p":
            g.f_("neon_red", 11, 3); g.f_("fire_drum", 20, 19)
        elif t == "m":
            g.f_("neon_cyan", 11, 3); g.f_("fern", 3, 19); g.f_("holo_ad", 20, 19)
        else:
            g.f_("neon_pink", 11, 3); g.f_("bonsai", 3, 19); g.f_("vase_tall", 20, 19)
            any(g.tank(x, y, True) for x, y in ((18, 14), (15, 13), (4, 13), (18, 17)))
            any(g.tank(x, y) for x, y in ((3, 16), (20, 13), (20, 16), (3, 11)))
        if t == "m":
            any(g.tank(x, y) for x, y in ((20, 12), (3, 12), (20, 15)))

    FN = {"implant": implant, "nano": nano, "grocery": grocery, "android": android, "pet": pet}
    for kind, tiers in SD.TIERS.items():
        for t in tiers:
            def wrapped(g, kind=kind, t=t):
                (FN[kind] if kind in FN else (lambda g, t, kind=kind: restaurant(g, t, kind)))(g, t)
                ensure_lights(g)
            def with_post(g, kind=kind, t=t):
                wrapped(g)
                post(g, t)
            PLACES.append(dict(id=SD.pid(kind, t), name=SD.NAME[(kind, t)], sym=SD.SYM[kind], color=SD.COLOR[t], fn=with_post, tag="shop", service=True))
    def subst(g):
        substation(g); ensure_lights(g)
    PLACES.append(dict(id="trl_pl_substation", name="power substation", sym="S", color="yellow", fn=subst, tag="shop", service=True))
    for t in "mr":
        def hosp(g, t=t):
            hospital(g, t); ensure_lights(g)
        PLACES.append(dict(id=f"trl_pl_hospital_{t}", name={"m": "hospital", "r": "private hospital"}[t], sym="H", color="light_red" if t == "m" else "white",
                           fn=hosp, tag="shop", service=True))
