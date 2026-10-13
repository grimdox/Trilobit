#!/usr/bin/env python3
"""Trilobit service shops: pure data shared by gen_places (buildings), gen_androids (workers, stock, price rules) and gen_shops (android items).

Four shop types, three district tiers (p poor, m middle, r rich; android shops only m and r):
  implant  - back-alley / clinic / atelier, each with a surgery bay (autodoc)
  nano     - nanohack chips and cyberbrains, with a cyberbrain bay; repairs only in rich shops
  grocery  - food and drink, with cyber rations in every tier
  android  - android assistants for sale
Each place has VARIANTS stock sets (the mapgen picks one at random), so two shops of the same kind differ."""
import random
import limbdata as L
import fooddata as FD

VARIANTS = 5
TIERS = {"implant": "pmr", "nano": "pmr", "grocery": "pmr", "android": "mr", "pet": "mr"}
NAME = {
    ("implant", "p"): "back-alley implant shop", ("implant", "m"): "cybernetics clinic", ("implant", "r"): "premier implant atelier",
    ("nano", "p"): "back-room hack shop", ("nano", "m"): "nanohack outlet", ("nano", "r"): "nanohack boutique",
    ("grocery", "p"): "corner grocery", ("grocery", "m"): "supermarket", ("grocery", "r"): "gourmet market",
    ("android", "m"): "android showroom", ("android", "r"): "android atelier",
    ("pet", "m"): "pet shop", ("pet", "r"): "exotic pet boutique",
}
SYM = {"implant": "+", "nano": "n", "grocery": "g", "android": "a", "pet": "f"}
COLOR = {"p": "brown", "m": "light_cyan", "r": "light_green"}
WORKER = {"implant": "implant dealer", "nano": "nanohack dealer", "grocery": "grocer", "android": "android dealer", "pet": "pet seller"}
CHAT = {"implant": "Implants, grafts, repairs.  Buy a part, then lie down in the bay.", "nano": "Chips, brains, and no questions.",
        "grocery": "Fresh in this morning.  What can I get you?", "android": "Every model has a warranty.  Take your time.", "pet": "Fish, cats, dogs, rabbits.  Everything is healthy and papered.  Take your time."}


# ---------------------------------------------------------------- restaurants: each of the 36 is its own shop kind (restp01_p ...)
import gen_rest_data as RD
REST = {}                      # kind -> record
for _k, _t, _n, _rec in RD.kinds():
    REST[_k] = _rec
    TIERS[_k] = _t
    NAME[(_k, _t)] = _rec[1]
    SYM[_k] = "r"
    WORKER[_k] = _rec[7]
    CHAT[_k] = _rec[8]
GROCERY_PRICE = {i: y for i, y, _ in FD.STAPLES}


def pid(kind, tier):
    return f"trl_pl_{kind}_{tier}"


def rng_for(*key):
    return random.Random("trilobit-shop-" + "-".join(str(k) for k in key))


# ---------------------------------------------------------------- android models for sale
# key: (name, frame, role, price, description)
ANDROIDS = {
    "basic": ("basic assistant android", "lite", "assistant", 50000, "A light, cheap frame with weak joints and a basic work program: carries things and keeps watch.  Low health, few skills."),
    "standard": ("standard assistant android", "civ", "assistant", 110000, "A well-rounded civilian frame with a good work program and ordinary health."),
    "porter": ("porter android", "labor", "porter", 160000, "A strong, slow labor frame built to haul loads and take hits."),
    "bodyguard": ("bodyguard android", "sec", "guard", 300000, "An armored security frame with fast reflexes and a sidearm."),
    "elite": ("elite bodyguard android", "elite", "bodyguard", 500000, "A top-grade frame: very tough, very strong, very fast, armed and trained."),
}
ANDROID_TIER = {"m": ["basic", "standard", "porter"], "r": ["standard", "porter", "bodyguard", "elite"]}


def android_item(key):
    return f"trl_buy_{key}"


# ---------------------------------------------------------------- stock per variant
def stock(kind, tier, v):
    """Return (list of (item, min, max), {item: price in yen})."""
    r = rng_for(kind, tier, v)
    rows, price = [], {}
    if kind == "implant":
        pool = L.TIER_LINES[tier]
        for line in r.sample(pool, r.choice([2, 3, 3, 4])):
            for bid in L.LINES[line]["ids"]:
                rows.append((bid, 1, 1))
                price[bid] = int(round(L.IMPL[bid]["price"] * L.PRICE_MULT[tier], -2))
    elif kind == "nano":
        chips = r.sample(L.NANO_TIER[tier], r.choice([6, 7, 8, 9]))
        for sid in chips:
            item = "trl_chip_nh_" + sid[len("trl_nh_"):]
            rows.append((item, 1, 2)); price[item] = L.CHIP_PRICE[sid]
        for b in r.sample(L.NANO_BRAINS[tier], r.choice([1, 2])):
            rows.append((b, 1, 1)); price[b] = L.PRICE[b]
    elif kind == "grocery":
        by = {0: [f for f in FD.F if f[10] == 0], 1: [f for f in FD.F if f[10] == 1], 2: [f for f in FD.F if f[10] == 2]}
        pick = {"p": [(0, 15), (1, 3)], "m": [(0, 6), (1, 10), (2, 2)], "r": [(0, 4), (1, 10), (2, 4)]}[tier]
        rngc = {0: (3, 8), 1: (2, 5), 2: (1, 3)}
        for q, n in pick:
            for f in r.sample(by[q], min(n, len(by[q]))):
                item = f"trl_f_{f[0]}"
                rows.append((item, rngc[q][0], rngc[q][1])); price[item] = f[9]
        for item, yen, _ in FD.STAPLES:
            rows.append((item, 3, 8)); price[item] = yen
        cyb = FD.CYBER_TIER[tier]
        for cid in r.sample(cyb, min(len(cyb), r.choice([2, 3, 4]))):
            item = f"trl_cf_{cid}"
            rows.append((item, 1, 4)); price[item] = next(c[7] for c in FD.CYBER if c[0] == cid)
    elif kind == "pet":
        import gen_fish_data as FS
        fish = [f for f in FS.FISH if (f[4] <= 15000 if tier == "m" else True)]
        for f in r.sample(fish, min(len(fish), r.choice([8, 9, 10] if tier == "m" else [12, 14, 16]))):
            item = f"trl_fish_{f[0]}"
            rows.append((item, 1, 3)); price[item] = f[4]
        for tid, _n, cap, yen, _v, _d in FS.TANKS:
            if tier == "r" or cap < 3:
                item = f"trl_tank_{tid}"
                rows.append((item, 1, 2)); price[item] = yen
        for pid, _m, _n, yen, _d, _c in FS.PETS:
            item = f"trl_pet_{pid}"
            rows.append((item, 1, 2)); price[item] = yen
        for item, yen, _ in FD.STAPLES:
            if item in ("dogfood", "catfood", "birdfood"):
                rows.append((item, 3, 8)); price[item] = yen
    elif kind in REST:
        rec = REST[kind]
        dishes, soft, booze = rec[4], rec[5], rec[6]
        # each variant drops a dish or two so two restaurants of one kind differ a little
        drop = set(r.sample(dishes, r.choice([0, 1, 1, 2]))) if len(dishes) > 6 else set()
        for i in dishes:
            if i not in drop:
                rows.append((i, 2, 6)); price[i] = RD.price(i, tier, GROCERY_PRICE)
        for i in soft + booze:
            rows.append((i, 3, 8)); price[i] = RD.price(i, tier, GROCERY_PRICE)
    elif kind == "android":
        pool = ANDROID_TIER[tier]
        for key in r.sample(pool, min(len(pool), r.choice([2, 3] if tier == "m" else [2, 3, 4]))):
            item = android_item(key)
            rows.append((item, 1, 2)); price[item] = ANDROIDS[key][3]
    return rows, price


# ---------------------------------------------------------------- workers: roles for gen_androids, placement per variant
def role_key(kind, tier, v):
    return f"{kind}_{tier}_{'abcde'[v]}"


ROLES_NEW = {}
HOURS_NEW = {}
VARIANT_PLACEMENT = {}   # place id -> [ [ (frame, role, firmware), ... ] per variant ]
GROUPS = {}              # tag -> [(item, min, max)]
for kind, tiers in TIERS.items():
    for tier in tiers:
        place = pid(kind, tier)
        VARIANT_PLACEMENT[place] = []
        for v in range(VARIANTS):
            rk = role_key(kind, tier, v)
            rows, price = stock(kind, tier, v)
            GROUPS[rk] = rows
            ROLES_NEW[rk] = dict(name=WORKER[kind], routine="post", frames=["civ"], worn=["suit", "dress_shoes"], carry=[], weapon=[],
                                 chat=CHAT[kind], skills={"speech": 5}, shop=[rk], fw=["stock"],
                                 rules=[(i, y) for i, y in price.items()])
            HOURS_NEW[rk] = (7, 22)
            ws = [("civ", rk, "stock")]
            if tier == "r" or (kind == "android" and tier == "m"):
                ws.append(("sec", "guard", "stock"))
            VARIANT_PLACEMENT[place].append(ws)

# extra roles for purchased androids (frames lite and elite are added in gen_androids)
ROLES_BOUGHT = {
    "assistant": dict(name="assistant", routine="post", frames=["lite", "civ"], worn=["jumpsuit", "sneakers"], carry=[("flashlight", 30)], weapon=[],
                      chat="How may I help you?", skills={"speech": 3, "firstaid": 2, "computer": 2}, fw=["stock"]),
    "bodyguard": dict(name="elite bodyguard", routine="post", frames=["elite"], worn=["ballistic_vest_light", "pants_cargo", "boots_combat", "gloves_light"],
                      carry=[], weapon=[("trl_gun_hp9", 60), ("baton-extended", 40)], chat="You are under my protection.",
                      skills={"melee": 6, "pistol": 6, "dodge": 5}, fw=["stock"]),
}
FRAMES_NEW = {
    "lite": dict(name="light frame", desc="A cheap frame with weak joints.", hp=-0.3, bonus={"str": -1}),
    "elite": dict(name="elite frame", desc="A top-grade frame: tough, strong and fast.", hp=0.8, bonus={"str": 5, "dex": 3, "per": 3}),
}
