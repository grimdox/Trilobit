#!/usr/bin/env python3
"""Build data/items.json, the Godot game's item definitions, from Trilobit's own content tables.
Guns come from tools/content/guns.py; ammunition, gun mods, melee weapons, containers, armor, engines, food and charms are defined below.
Sprites are looked up by item id in gfx/Trilobit64 (drawn by tools/content/gen_tiles64.py).  usage: export_items.py  (run from godot-spike/)"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "content"))
import guns

items = guns.records()
# ammunition: one item per caliber and kind; a box holds `rounds`.  kind modifiers live in the game (gunplay.gd).
AMMO = [("9mm", ["fmj", "ap", "hp"], 18, 14), (".357", ["fmj", "ap", "hp"], 12, 18), ("5.56", ["fmj", "ap", "hp"], 20, 24), ("12ga", ["shot", "slug"], 10, 20),
        (".338", ["fmj", "ap"], 10, 40), ("7.62", ["fmj", "ap"], 30, 30), ("12.7", ["fmj", "ap"], 20, 50), ("40mm", ["he"], 3, 45), ("cell", ["cell"], 20, 30)]
KINDN = {"fmj": "ball", "ap": "armor-piercing", "hp": "hollow-point", "shot": "buckshot", "slug": "slug", "he": "HE grenade", "cell": "charge pack"}
# Bullets carry ALL the damage (guns have none).  BULLETS: caliber -> (damage min, damage max of a ball/standard round, effective range in tiles).
# Past its effective range a bullet loses 1/effective-range of its damage for every tile (so it is spent at twice that distance).  Numbers started from the
# averages of the guns that fire the caliber (the old per-gun damage); effective range from the old per-class range (SMG 12, pistol/revolver 10, rifle 18,
# shotgun 6, sniper 30, MG 16, heavy MG 20, launcher 14, laser 15).  KIND_DMG scales a kind from the standard round (armor-piercing 0.9, hollow-point 1.25).
BULLETS = {"9mm": (9, 13, 12), ".357": (14, 22, 10), "5.56": (16, 24, 18), "12ga": (20, 34, 6), ".338": (30, 48, 30), "7.62": (12, 18, 16), "12.7": (16, 23, 20),
           "40mm": (40, 70, 14), "cell": (14, 23, 15)}
KIND_DMG = {"fmj": 1.0, "ap": 0.9, "hp": 1.25, "shot": 1.0, "slug": 1.0, "he": 1.0, "cell": 1.0}
KIND_ER = {("12ga", "slug"): 12}      # a slug carries much farther than buckshot
for cal, kinds, rounds, price in AMMO:
    for k in kinds:
        lo, hi, er = BULLETS[cal]
        m = KIND_DMG[k]
        items.append({"id": "trl_ammo_%s_%s" % (cal.replace(".", ""), k), "name": "%s %s box" % (cal, KINDN[k]), "weight_g": rounds * 10, "volume_ml": rounds * 6, "length_mm": 80,
                      "price": price * (2 if k == "ap" else 1), "tags": ["ammo"],
                      "ammo": {"cal": cal, "kind": k, "rounds": rounds, "dmg": [max(1, round(lo * m)), max(1, round(hi * m))], "eff_range": KIND_ER.get((cal, k), er)}})
# gun mods.  effects: acc (flat, percentage points; 5 points = 1 on the 2d10 roll), max_aim (more aim points can be banked), aim_speed (change to the aim points gained per aiming turn; optics are slower to settle but allow range precision through rangepen_pct), hip (bonus when not aiming), range_pct, rangepen_pct (less accuracy lost per tile),
# close_pen (penalty inside 4 tiles), recoil_pct (less aim lost per bullet), noise_cap (shots are heard no further than this), dmg_pct, mag_pct, jam (percentage points), reload (turns), spread_pct
MODS = [
    ("redot", "red-dot sight", "optic", {"acc": 5, "max_aim": 1, "aim_speed": -0.05, "rangepen_pct": 10}, 90, 120, "Fast, forgiving.  A little steadier on the first aimed turn."),
    ("holo", "holographic sight", "optic", {"acc": 7, "max_aim": 1, "aim_speed": -0.08, "rangepen_pct": 20}, 150, 220, "Wide window, bright reticle."),
    ("scope4", "4x scope", "optic", {"acc": 8, "max_aim": 1, "aim_speed": -0.12, "range_pct": 30, "rangepen_pct": 40, "close_pen": 8}, 300, 400, "Reaches out; clumsy up close."),
    ("scope8", "8x sniper scope", "optic", {"acc": 10, "max_aim": 2, "aim_speed": -0.25, "range_pct": 70, "rangepen_pct": 65, "close_pen": 18}, 700, 900, "For long streets and rooftops.  Useless at arm's length."),
    ("smartlink", "smartlink sight", "optic", {"acc": 12, "max_aim": 1, "aim_speed": -0.05, "hip": 6, "rangepen_pct": 30}, 600, 1100, "Reads your optic nerve.  The gun knows where you are looking."),
    ("laser", "laser sight", "under", {"hip": 10, "close_pen": -4, "aim_speed": 0.05}, 70, 80, "A red dot on the target.  Helps most when you are not taking time to aim."),
    ("foregrip", "foregrip", "under", {"recoil_pct": -25, "acc": 2}, 40, 150, "Hold it down in bursts."),
    ("bipod", "folding bipod", "under", {"recoil_pct": -15, "max_aim": 1, "acc": 3, "aim_speed": -0.05}, 80, 500, "Steadies a long gun if you are not walking."),
    ("suppressor", "suppressor", "muzzle", {"noise_cap": 5, "dmg_pct": -6, "range_pct": -5, "jam": 0.2}, 500, 350, "Quiet shots.  Nobody comes to look."),
    ("compensator", "compensator", "muzzle", {"recoil_pct": -30, "noise_cap": 99}, 120, 200, "Tames the muzzle."),
    ("flashhider", "flash hider", "muzzle", {"recoil_pct": -10, "acc": 1}, 60, 100, "A little less climb, a little less glare."),
    ("longbarrel", "long barrel", "barrel", {"acc": 4, "range_pct": 25, "dmg_pct": 6}, 160, 450, "More velocity and more reach."),
    ("shortbarrel", "short barrel", "barrel", {"acc": -3, "range_pct": -20, "close_pen": -6, "reload": 0}, 90, 250, "Handy in corridors."),
    ("choke", "choke tube", "barrel", {"spread_pct": -35, "range_pct": 20}, 100, 120, "Tighter pattern, more reach."),
    ("extmag", "extended magazine", "mag", {"mag_pct": 50, "jam": 0.3}, 110, 120, "Half again as many rounds."),
    ("drum", "drum magazine", "mag", {"mag_pct": 150, "jam": 1.5, "reload": 1, "acc": -2}, 260, 400, "Lots of lead; slow to swap, fond of jamming."),
    ("quickmag", "quick-release magazine", "mag", {"reload": -1}, 70, 90, "Swaps in a heartbeat."),
    ("stock", "adjustable stock", "stock", {"recoil_pct": -20, "acc": 3}, 90, 450, "Solid against the shoulder."),
    ("cheekrest", "cheek rest and padded stock", "stock", {"recoil_pct": -30, "max_aim": 1, "acc": 2}, 160, 700, "Built for precision."),
]
for mid, name, slot, eff, price, wt, desc in MODS:
    items.append({"id": "trl_mod_" + mid, "name": name, "desc": desc, "weight_g": wt, "volume_ml": max(40, wt // 2), "length_mm": 150, "price": price,
                  "tags": ["mod"], "mod": {"slot": slot, "fx": eff}})
# melee weapons: strictly Japanese or Russian.  Three grades each (plain, forged, masterwork).  fields: dmg, reach, acc, fast (chance of a second strike),
# slow (attack takes two turns), parry (percent off enemy melee hit chance), stun/trip/entangle/disarm (chances), bleed, sneak (backstab multiplier),
# sweep (also hits others beside you), brace (reach strike on a charger does more), flail (ignores the target's parry), verb
JP = "Japanese"
RU = "Russian"
MELEE = [
    # id, name, culture, class tag, dmg, reach, weight g, length mm, price, extras
    ("kama", "kama", JP, "blade", [6, 11], 1, 600, 400, 60, {"fast": 0.4, "trip": 0.2, "bleed": True, "verb": "hook"}),
    ("wakizashi", "wakizashi", JP, "blade", [9, 15], 1, 900, 650, 220, {"parry": 10, "fast": 0.15, "bleed": True, "verb": "cut"}),
    ("katana", "katana", JP, "blade", [12, 20], 1, 1200, 1000, 450, {"parry": 15, "bleed": True, "verb": "cut"}),
    ("tanto", "tanto", JP, "blade", [6, 10], 1, 300, 300, 90, {"sneak": 5, "fast": 0.3, "bleed": True, "verb": "stab"}),
    ("nodachi", "nodachi", JP, "blade", [16, 28], 2, 2800, 1600, 700, {"slow": True, "parry": 10, "bleed": True, "knock": 0.35, "verb": "cleave"}),
    ("naginata", "naginata", JP, "polearm", [11, 18], 2, 2200, 2100, 380, {"sweep": True, "parry": 10, "bleed": True, "verb": "slash"}),
    ("yari", "yari", JP, "polearm", [10, 16], 2, 1800, 2000, 200, {"brace": True, "verb": "thrust"}),
    ("bo", "bo staff", JP, "staff", [5, 9], 2, 1000, 1800, 40, {"stun": 0.25, "parry": 20, "knock": 0.4, "verb": "crack"}),
    ("jo", "jo staff", JP, "staff", [4, 8], 1, 500, 1300, 30, {"stun": 0.2, "parry": 15, "verb": "rap"}),
    ("nunchaku", "nunchaku", JP, "blunt", [6, 11], 1, 450, 350, 50, {"fast": 0.4, "stun": 0.1, "verb": "whip"}),
    ("kusarigama", "kusarigama", JP, "chain", [7, 12], 2, 1100, 1500, 260, {"entangle": 0.35, "bleed": True, "verb": "lash"}),
    ("sai", "sai", JP, "blunt", [5, 9], 1, 600, 400, 140, {"parry": 20, "disarm": 0.3, "fast": 0.2, "verb": "jab"}),
    ("jitte", "jitte", JP, "blunt", [6, 10], 1, 700, 450, 170, {"parry": 20, "disarm": 0.45, "stun": 0.1, "verb": "strike"}),
    ("tessen", "tessen (iron fan)", JP, "blunt", [3, 6], 1, 400, 300, 160, {"parry": 20, "sneak": 3, "fast": 0.3, "verb": "rap"}),
    ("kunai", "kunai", JP, "blade", [4, 8], 1, 200, 220, 45, {"sneak": 5, "fast": 0.25, "verb": "stab"}),
    ("ono", "ono (axe)", JP, "axe", [14, 22], 1, 3500, 1100, 300, {"slow": True, "bleed": True, "knock": 0.5, "verb": "chop"}),
    ("tonfa", "tonfa", JP, "blunt", [5, 9], 1, 600, 450, 70, {"parry": 15, "stun": 0.2, "verb": "strike"}),
    ("shashka", "shashka", RU, "blade", [11, 18], 1, 1100, 900, 320, {"parry": 15, "fast": 0.15, "bleed": True, "verb": "slash"}),
    ("kinzhal", "kinzhal", RU, "blade", [7, 12], 1, 500, 450, 130, {"sneak": 5, "fast": 0.25, "bleed": True, "verb": "stab"}),
    ("finka", "Finka knife", RU, "blade", [6, 10], 1, 250, 280, 70, {"sneak": 5, "fast": 0.25, "bleed": True, "verb": "stab"}),
    ("lopata", "MPL-50 sapper shovel", RU, "axe", [9, 15], 1, 1300, 500, 55, {"stun": 0.15, "knock": 0.3, "verb": "chop"}),
    ("kistien", "kistien flail", RU, "chain", [8, 16], 1, 900, 500, 90, {"stun": 0.2, "flail": True, "knock": 0.4, "verb": "smash"}),
    ("chekan", "chekan axe-hammer", RU, "axe", [10, 17], 1, 900, 650, 150, {"bleed": True, "stun": 0.1, "verb": "hack"}),
    ("topor", "topor axe", RU, "axe", [12, 20], 1, 1600, 700, 100, {"bleed": True, "knock": 0.3, "verb": "chop"}),
    ("kastet", "kastet knuckles", RU, "blunt", [4, 8], 1, 250, 100, 40, {"fast": 0.45, "stun": 0.15, "verb": "punch"}),
]
GRADES = [("", "", 1.0, 0, 1.0, 0), ("_f", "forged ", 1.2, 4, 3.5, 0), ("_m", "masterwork ", 1.45, 8, 9.0, 5)]
for mid, name, culture, klass, dmg, reach, wt, ln, price, extra in MELEE:
    for suf, pre, dm, acc, pm, parry_bonus in GRADES:
        m = {"dmg": [max(1, round(dmg[0] * dm)), max(1, round(dmg[1] * dm))], "reach": reach, "acc": acc}
        m.update(extra)
        if "parry" in m or parry_bonus:
            m["parry"] = m.get("parry", 0) + parry_bonus
        items.append({"id": "trl_mel_" + mid + suf, "name": pre + name, "desc": "A %s weapon (%s)." % (culture, klass), "weight_g": wt, "volume_ml": max(60, wt // 3),
                      "length_mm": ln, "price": int(price * pm), "tags": ["melee", klass, culture.lower()], "melee": m, "culture": culture})
# containers: the pocket model
P = lambda i, vol, wt, flex=False, tags=None, water=False, length=0: {"id": i, "max_volume_ml": vol, "max_weight_g": wt, "flexible": flex,
                                                                    "allow_tags": tags or [], "watertight": water, "max_item_length_mm": length}
items += [
    {"id": "trl_backpack", "name": "commuter backpack", "desc": "A commuter backpack.  Worn on the back: 12 more inventory tiles.", "weight_g": 700, "volume_ml": 1500, "length_mm": 450, "price": 120, "tags": ["pocket"],
     "pocket": {"slot": "back", "tiles": 12, "allow": []}},
    {"id": "trl_coat", "name": "long coat", "desc": "A long coat with deep pockets and a little armor.  Worn on the chest: 4 more inventory tiles.", "weight_g": 1400, "volume_ml": 3000, "length_mm": 800, "price": 300, "tags": ["pocket", "worn"],
     "armor": {"slot": "chest", "phys": 1, "dur": 20}, "pocket": {"slot": "chest", "tiles": 4, "allow": []}},
    {"id": "trl_helmet", "name": "ballistic helmet", "desc": "Armor 3 on the head.", "weight_g": 1200, "volume_ml": 3000, "length_mm": 300, "price": 350, "tags": ["armor", "worn"], "armor": {"slot": "head", "phys": 3, "dur": 40}},
    {"id": "trl_visor", "name": "riot visor helmet", "desc": "Armor 5 on the head.", "weight_g": 1900, "volume_ml": 4000, "length_mm": 320, "price": 800, "tags": ["armor", "worn"], "armor": {"slot": "head", "phys": 5, "dur": 60}},
    {"id": "trl_vest", "name": "ballistic vest", "desc": "Armor 4 on the chest.", "weight_g": 3200, "volume_ml": 5000, "length_mm": 500, "price": 500, "tags": ["armor", "worn"], "armor": {"slot": "chest", "phys": 4, "dur": 60}},
    {"id": "trl_vest_heavy", "name": "plate carrier", "desc": "Armor 7 on the chest.", "weight_g": 6800, "volume_ml": 8000, "length_mm": 520, "price": 1400, "tags": ["armor", "worn"], "armor": {"slot": "chest", "phys": 7, "dur": 90}},
    {"id": "trl_bracers", "name": "composite arm guards", "desc": "Armor 2 on both arms.", "weight_g": 1100, "volume_ml": 2000, "length_mm": 350, "price": 300, "tags": ["armor", "worn"], "armor": {"slot": "arms", "phys": 2, "dur": 40}},
    {"id": "trl_greaves", "name": "shin guards", "desc": "Armor 2 on both legs.", "weight_g": 1500, "volume_ml": 2500, "length_mm": 400, "price": 300, "tags": ["armor", "worn"], "armor": {"slot": "legs", "phys": 2, "dur": 40}},
    {"id": "trl_pouch", "name": "belt pouch", "desc": "A pouch on the belt: 4 more inventory tiles.", "weight_g": 120, "volume_ml": 250, "length_mm": 180, "price": 20, "tags": ["pocket"],
     "pocket": {"slot": "belt", "tiles": 4, "allow": []}},
    {"id": "trl_fanny", "name": "fanny pack", "desc": "A small pack worn on the belt: 3 more inventory tiles.", "weight_g": 150, "volume_ml": 300, "length_mm": 200, "price": 25, "tags": ["pocket"],
     "pocket": {"slot": "belt", "tiles": 3, "allow": []}},
    {"id": "trl_water_bottle", "name": "water bottle", "desc": "Holds up to 500 mL of water.  Drink from it to ease thirst.", "weight_g": 80, "volume_ml": 600, "length_mm": 230, "price": 5, "tags": ["bottle"], "bottle": {"ml": 500}},
    {"id": "trl_yen", "name": "yen notes", "weight_g": 1, "volume_ml": 1, "length_mm": 0, "price": 1, "tags": ["money"]},
    {"id": "trl_ammo", "name": "ammo box", "weight_g": 120, "volume_ml": 70, "length_mm": 60, "price": 20, "tags": ["ammo"], "ammo": {"cal": "9mm", "kind": "fmj", "rounds": 12}},
    {"id": "trl_water", "name": "water", "weight_g": 1, "volume_ml": 1, "length_mm": 0, "price": 0, "tags": ["liquid"], "per_unit": True},
    {"id": "trl_ration", "name": "cyber ration bar", "weight_g": 90, "volume_ml": 80, "length_mm": 150, "price": 15, "tags": ["food"], "food": {"hp": 3, "stam": 6, "drink": False, "alcohol": False, "kcal": 500}},
    {"id": "trl_parcel", "name": "sealed parcel", "weight_g": 600, "volume_ml": 1500, "length_mm": 250, "price": 0, "tags": ["job"]},
    {"id": "trl_datacase", "name": "encrypted data case", "weight_g": 1800, "volume_ml": 6000, "length_mm": 420, "price": 400, "tags": ["job"]},
    {"id": "trl_medkit", "name": "trauma patch", "weight_g": 120, "volume_ml": 100, "length_mm": 120, "price": 40, "tags": ["medical"], "desc": "Heals 25 and mends your worst limb a little."},
    {"id": "trl_kit_repair", "name": "field repair kit", "desc": "Patch plates, hoses and wiring.  Restores 25 points to one vehicle part.", "weight_g": 1500, "volume_ml": 3000, "length_mm": 350, "price": 90, "tags": ["tool"], "repair": 25},
]

# vehicle engines: power = top speed in tiles a turn, drain = turns per battery point, hp = hit points of the engine part, fits = the vehicle kinds it can drive
ENGINES = [
    ("city", "Kuroda CE-120 city motor", 4, 4, 60, ["car", "truck"], 420, 38000),
    ("mini", "Hachiko 60 kW commuter motor", 3, 6, 40, ["car"], 180, 22000),
    ("sport", "Zaitsev ZS-300 sport motor", 6, 2, 55, ["car"], 1400, 46000),
    ("haul", "Uralmash HD-400 hauler", 3, 3, 120, ["truck", "car"], 900, 90000),
    ("rotor", "Mitsu T-700 turbine", 3, 3, 60, ["heli", "plane"], 2600, 70000),
    ("reactor", "Kawasaki KR-9 mech core", 2, 5, 90, ["mech"], 3800, 120000),
]
for eid, ename, power, drain, hp, fits, price, wt in ENGINES:
    items.append({"id": "trl_eng_" + eid, "name": ename, "desc": "Vehicle engine: top speed %d, %d hp, fits %s." % (power, hp, ", ".join(fits)), "weight_g": wt, "volume_ml": wt // 2, "length_mm": 900, "price": price,
                  "tags": ["engine"], "engine": {"power": power, "drain": drain, "hp": hp, "fits": fits}})
# ---- more armor: the paper doll shows each piece, and every one has its own icon (tools/content/pd_armor.py)
items += [
    {"id": "trl_balaclava", "name": "balaclava", "desc": "Armor 1 on the head.  Hides your face.", "weight_g": 150, "volume_ml": 300, "length_mm": 250, "price": 60, "tags": ["armor", "worn"], "armor": {"slot": "head", "phys": 1, "dur": 12}},
    {"id": "trl_helm_tac", "name": "tactical helmet", "desc": "Armor 4 on the head, with a night-vision mount.", "weight_g": 1500, "volume_ml": 3200, "length_mm": 310, "price": 650, "tags": ["armor", "worn"], "armor": {"slot": "head", "phys": 4, "dur": 50}},
    {"id": "trl_jacket", "name": "riot jacket", "desc": "Armor 2 on the chest.", "weight_g": 1800, "volume_ml": 3500, "length_mm": 600, "price": 220, "tags": ["armor", "worn"], "armor": {"slot": "chest", "phys": 2, "dur": 36}},
    {"id": "trl_vest_corp", "name": "corporate liner vest", "desc": "Armor 3 on the chest.  Slim enough to wear under a suit.", "weight_g": 2200, "volume_ml": 3500, "length_mm": 500, "price": 900, "tags": ["armor", "worn"], "armor": {"slot": "chest", "phys": 3, "dur": 55}},
    {"id": "trl_bracers_heavy", "name": "reinforced arm armor", "desc": "Armor 4 on both arms.", "weight_g": 2400, "volume_ml": 3000, "length_mm": 380, "price": 700, "tags": ["armor", "worn"], "armor": {"slot": "arms", "phys": 4, "dur": 60}},
    {"id": "trl_greaves_heavy", "name": "reinforced leg armor", "desc": "Armor 4 on both legs.", "weight_g": 3000, "volume_ml": 4000, "length_mm": 450, "price": 700, "tags": ["armor", "worn"], "armor": {"slot": "legs", "phys": 4, "dur": 60}},
    {"id": "trl_kneepads", "name": "knee pads", "desc": "Armor 1 on both legs.", "weight_g": 400, "volume_ml": 800, "length_mm": 200, "price": 70, "tags": ["armor", "worn"], "armor": {"slot": "legs", "phys": 1, "dur": 20}},
]

# ---- food and drink.  food = {hp: healed, stam: stamina restored, drink, alcohol}; each has its own icon in gfx/Trilobit64
FOODS = [
    # id, name, price, hp, stamina, kind (""/drink/alcohol)
    ("cup_ramen", "cup ramen", 18, 4, 6, ""), ("gyoza", "gyoza plate", 25, 5, 6, ""),
    ("onigiri", "onigiri", 12, 3, 4, ""), ("sashimi", "sashimi plate", 60, 8, 8, ""),
    ("yakitori", "yakitori skewers", 30, 6, 6, ""), ("katsu", "katsu bento", 55, 10, 10, ""),
    ("unagi", "unagi donburi", 90, 12, 12, ""), ("miso", "miso soup", 15, 3, 5, ""),
    ("okonomiyaki", "okonomiyaki", 35, 7, 8, ""), ("takoyaki", "takoyaki", 28, 5, 6, ""),
    ("pelmeni", "pelmeni", 28, 6, 8, ""), ("borscht", "borscht", 24, 6, 8, ""),
    ("blini", "blini", 20, 4, 5, ""), ("caviar_blini", "caviar blini", 75, 8, 8, ""),
    ("solyanka", "solyanka", 30, 7, 8, ""), ("piroshki", "piroshki", 14, 3, 4, ""),
    ("kotleta", "kotleta and kasha", 34, 8, 9, ""), ("chow_mein", "chow mein", 32, 7, 8, ""),
    ("fried_rice", "fried rice", 26, 6, 7, ""), ("hamburger", "hamburger", 30, 7, 8, ""),
    ("taco", "taco", 22, 5, 5, ""), ("fries", "fries", 14, 2, 4, ""), ("crepe", "crepe", 24, 4, 5, ""),
    ("sencha", "sencha tea", 8, 1, 6, "drink"), ("oolong", "oolong tea", 9, 1, 6, "drink"),
    ("kan_coffee", "canned coffee", 7, 0, 10, "drink"), ("kvass", "kvass", 8, 1, 5, "drink"),
    ("kompot", "kompot", 8, 1, 5, "drink"), ("cola", "cola", 7, 0, 6, "drink"),
    ("beer", "beer", 12, 1, 0, "alcohol"), ("vodka", "vodka shot", 15, 1, 0, "alcohol"), ("sake", "sake", 18, 1, 0, "alcohol"),
    # the grocery
    ("black_bread", "black bread", 10, 4, 6, ""), ("tushonka", "canned stew", 16, 6, 8, ""),
    ("herring", "salted herring", 14, 4, 5, ""), ("natto", "natto", 9, 3, 4, ""),
    ("mochi", "mochi", 10, 2, 4, ""), ("apple", "apple", 5, 2, 3, ""), ("orange", "orange", 5, 2, 3, ""),
    ("banana", "banana", 5, 2, 3, ""), ("milk", "milk", 8, 2, 4, "drink"), ("protein", "protein brick", 20, 5, 10, ""),
    ("glucose", "glucose cube", 9, 1, 14, ""), ("hydrogel", "hydration gel", 10, 1, 12, "drink"),
    ("chocolate", "chocolate bar", 7, 1, 8, ""), ("cheese", "cheese wedge", 12, 3, 4, ""),
]
# Energy and water.  kcal: every food and drink has one (2,500 kcal = 24 hours of not being hungry).  ml: a drink's millilitres (500 mL of water = 4 hours of not
# being thirsty); hydr: how much of that counts as water (1.0 for tea, soft drinks and milk; strong drink dehydrates).  Figures are typical servings.
KCAL = {"cup_ramen": 420, "gyoza": 320, "onigiri": 190, "sashimi": 280, "yakitori": 280, "katsu": 780, "unagi": 650, "miso": 60, "okonomiyaki": 450, "takoyaki": 330,
        "pelmeni": 520, "borscht": 220, "blini": 360, "caviar_blini": 410, "solyanka": 260, "piroshki": 310, "kotleta": 640, "chow_mein": 600, "fried_rice": 520,
        "hamburger": 550, "taco": 210, "fries": 365, "crepe": 260, "sencha": 5, "oolong": 5, "kan_coffee": 40, "kvass": 60, "kompot": 90, "cola": 140, "beer": 150,
        "vodka": 90, "sake": 190, "black_bread": 520, "tushonka": 590, "herring": 240, "natto": 100, "mochi": 130, "apple": 95, "orange": 62, "banana": 105,
        "milk": 150, "protein": 350, "glucose": 100, "hydrogel": 20, "chocolate": 230, "cheese": 200}
ML = {"sencha": 250, "oolong": 250, "kan_coffee": 190, "kvass": 330, "kompot": 330, "cola": 330, "beer": 350, "vodka": 40, "sake": 180, "milk": 250, "hydrogel": 200}
HYDR = {"beer": 0.5, "vodka": 0.0, "sake": 0.3}
for fid, nm, pr, hp, st, kind in FOODS:
    fd = {"hp": hp, "stam": st, "drink": kind != "", "alcohol": kind == "alcohol", "kcal": KCAL[fid]}
    if kind:
        fd["ml"] = ML[fid]
        fd["hydr"] = HYDR.get(fid, 1.0)
    items.append({"id": "trl_food_" + fid, "name": nm, "desc": "%s.  %d kcal%s.  Heals %d, restores %d stamina." % (nm.capitalize(), KCAL[fid], (", %d mL" % ML[fid]) if kind else "", hp, st), "weight_g": 250, "volume_ml": 300, "length_mm": 120,
                  "price": pr, "tags": ["food"] + (["drink"] if kind else []), "food": fd})

# ---- faith items (church and shrine shops); `use` is what they do when used
FAITH = [
    ("candle", "church candle", 20, {"bless": 20, "msg": "You light the candle and say a short prayer.  Things feel quieter."}),
    ("icon", "small icon", 120, {"bless": 480, "msg": "You hold the icon.  You feel watched over for a while."}),
    ("gospel", "pocket gospel", 60, {"bless": 40, "msg": "You read a few lines.  Your pulse slows."}),
    ("omamori", "omamori charm", 150, {"bless": 600, "msg": "The charm warms in your hand.  Luck is with you for a while."}),
    ("ofuda", "ofuda paper ward", 90, {"bless": 300, "msg": "You tuck the ward in your sleeve."}),
    ("ema", "ema plaque", 50, {"hp": 8, "msg": "You write a wish and hang it.  You feel lighter."}),
]
for fid, nm, pr, use in FAITH:
    items.append({"id": "trl_faith_" + fid, "name": nm, "desc": "A %s.  Use it for a small blessing." % nm, "weight_g": 80, "volume_ml": 100, "length_mm": 100, "price": pr, "tags": ["charm"], "use": use})

# ---- implants: every implant is a physical item (src/implants.gd holds what each one does; keep these in step, tests/run_inventory.gd checks it)
import gen_implants
PART_NAME = {"head": "head", "eyes": "eyes", "spine": "spine", "chest": "chest", "dermal": "dermal layer", "arms": "arms", "hands": "hands", "legs": "legs"}
TIER_NAME = {1: "Basic", 2: "Improved", 3: "Quality"}
for d in gen_implants.catalogue():
    bits = []
    for k, v in d.get("skills", {}).items():
        bits.append("%s %+d" % (k.capitalize(), v))
    bits.append("armor %d" % d["armor"])
    if "battery" in d:
        bits.append("stores %d kJ" % d["battery"])
    if "nano" in d:
        bits.append("%d nanohack slots" % d["nano"])
    text = "%s grade: %s, draws %g kJ/h." % (TIER_NAME[d["grade"]], ", ".join(bits), d["draw"])
    items.append({"id": "trl_imp_" + d["id"], "name": d["name"], "desc": text + "  Fits the %s." % PART_NAME[d["part"]], "weight_g": 0, "volume_ml": 0,
                  "length_mm": 0, "price": d["cost"], "tags": ["implant"], "implant": d["id"], "part": d["part"]})

# ---- nanohack chips (src/nanohacks.gd holds what each does): one chip, one Trilobit slot
NANOS = [("plating", "Plating", "Hardens the skin-weave: +1 armor on every body part for 10 minutes.", ["#4fd0ff", "#9fe8ff", "#2a7fd0"]),
         ("reflex", "Reflex", "Overclocks the nerves: +1 Dodge for 10 minutes.", ["#ffe14a", "#ffb02a", "#fff3a0"]),
         ("shock", "Shock", "Overloads a target in sight: 10 damage to a random implanted body part.", ["#ff3ec8", "#c23cff", "#ffd0f4"]),
         ("strike", "Strike", "Primes the muscles: +1 Unarmed and +1 Melee for 10 minutes.", ["#ff5a4a", "#ff9a3a", "#d02a2a"]),
         ("research", "Skill: Research", "A standing lookup routine: +1 Research while installed.", ["#6dff9a", "#2ad08a", "#c8ffd8"])]
for nid, nm, text, cols in NANOS:
    items.append({"id": "trl_nano_" + nid, "name": nm + " nanohack", "desc": text + "  A chip for a Trilobit slot; fit it on the Implants screen.", "weight_g": 0, "volume_ml": 0,
                  "length_mm": 0, "price": 400, "tags": ["nanohack"], "nano": nid, "nano_cols": cols})

# ---- trade goods of the businesses, flats and offices: no stats, no function (see tools/content/goods_list.py)
import goods_list
for gid, nm, cat, who, text, wg, vol, pr in goods_list.GOODS:
    items.append({"id": "trl_good_" + gid, "name": nm, "desc": text, "weight_g": wg, "volume_ml": vol, "length_mm": 0, "price": pr, "tags": ["good", cat]})

# ---- tiered armor: one piece per slot at +1..+5 base armor (see the Armor tab of the Weapons & Armor List).  price = implant reference x slot factor / divisor
_REF = {1: 5400, 2: 11000, 3: 24000, 4: 46000, 5: 92000}
_DIV = {1: 5.0, 2: 6.0, 3: 7.0, 4: 8.5, 5: 10.0}
_FAC = {"head": 0.75, "chest": 1.0, "arms": 0.5, "legs": 0.5}
_DUR = {1: 20, 2: 35, 3: 50, 4: 65, 5: 80}
_GRADE = {1: "Street", 2: "Patrol", 3: "Kevlar", 4: "Plasteel", 5: "Nanofab"}
_PART = {"head": ("Helm", [400, 800, 1200, 1600, 2000], 3000, 300), "chest": ("Vest", [1500, 2400, 3400, 4500, 5800], 5000, 500),
         "arms": ("Arm Guards", [500, 800, 1200, 1600, 2000], 2500, 450), "legs": ("Leg Guards", [600, 1000, 1400, 1900, 2400], 2800, 600)}
_COVER = {"head": "the head", "chest": "the chest", "arms": "both arms", "legs": "both legs"}
for _slot in ("head", "chest", "arms", "legs"):
    _word, _kg, _vol, _len = _PART[_slot]
    for _n in range(1, 6):
        items.append({"id": "trl_armor_%s_%d" % (_slot, _n), "name": "%s %s" % (_GRADE[_n], _word.lower()), "desc": "Armor %d on %s." % (_n, _COVER[_slot]),
                      "weight_g": _kg[_n - 1], "volume_ml": _vol, "length_mm": _len, "price": int(round(_REF[_n] * _FAC[_slot] / _DIV[_n] / 10.0)) * 10,
                      "tags": ["armor", "worn"], "armor": {"slot": _slot, "phys": _n, "dur": _DUR[_n]}})

# ---- every weapon is held in one hand or two (a pistol, revolver, SMG or reach-1 melee weapon: one; everything else: both)
for it in items:
    if "gun" in it:
        it["hands"] = 1 if any(t in it["tags"] for t in ("pistol", "revolver", "smg")) else 2
    elif "melee" in it:
        it["hands"] = 2 if int(it["melee"].get("reach", 1)) >= 2 else 1

json.dump(items, open(os.path.join(HERE, "../data/items.json"), "w"), indent=1)
print(len(items), "items exported")
