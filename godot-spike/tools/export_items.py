#!/usr/bin/env python3
"""Export Trilobit's CDDA-side content tables into the Godot spike's item schema (data/items.json).
Shows that the generated content transfers: the 50 new guns (gunset.json) become engine-neutral records, plus a few containers
that exercise the pocket model.  usage: export_items.py  (run from godot-spike/)"""
import json, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.join(HERE, "../../data/mods/trilobit")
LEN = {"SMG": 450, "Pistol": 200, "Revolver": 220, "Rifle": 900, "Shotgun": 950, "Sniper": 1100, "MG": 1000, "Heavy MG": 1300, "Launcher": 800, "Laser": 700}


def grams(s):
    m = re.match(r"([\d.]+)\s*(kg|g)", s)
    return int(float(m.group(1)) * (1000 if m.group(2) == "kg" else 1))


names = {}
src = open(os.path.join(HERE, "../../trilobit-tools/gen_gunset.py")).read()
ns = {"__file__": os.path.join(HERE, "../../trilobit-tools/gen_gunset.py")}
import sys
sys.argv = ["x", "/tmp"]
exec(src.split("out = []")[0], ns)
cls = {g[0]: g[4] for g in ns["GUNS"]}
base = {g[0]: g[3] for g in ns["GUNS"]}
# class table: damage range, effective range in tiles, base accuracy (percent), caliber, magazine, fire modes [name, shots], recoil per extra shot,
# report radius (how far a shot is heard, in tiles), reload turns, pellets per shot, mod slots, jam chance (percent per trigger pull)
SL = ["optic", "muzzle", "barrel", "mag", "under", "stock"]
GUN = {"SMG": {"dmg": [7, 11], "range": 12, "acc": 62, "cal": "9mm", "mag": 25, "modes": [["single", 1], ["burst", 3], ["auto", 6]], "recoil": 4, "noise": 16, "reload": 1, "pellets": 1, "slots": ["optic", "muzzle", "mag", "under", "stock"], "jam": 1.0},
       "Pistol": {"dmg": [10, 16], "range": 10, "acc": 70, "cal": "9mm", "mag": 12, "modes": [["single", 1]], "recoil": 3, "noise": 14, "reload": 1, "pellets": 1, "slots": ["optic", "muzzle", "mag", "under"], "jam": 0.6},
       "Revolver": {"dmg": [14, 22], "range": 10, "acc": 72, "cal": ".357", "mag": 6, "modes": [["single", 1]], "recoil": 5, "noise": 18, "reload": 3, "pellets": 1, "slots": ["optic", "muzzle", "under"], "jam": 0.1},
       "Rifle": {"dmg": [16, 24], "range": 18, "acc": 74, "cal": "5.56", "mag": 30, "modes": [["single", 1], ["burst", 3]], "recoil": 4, "noise": 20, "reload": 2, "pellets": 1, "slots": ["optic", "muzzle", "barrel", "mag", "under", "stock"], "jam": 0.8},
       "Shotgun": {"dmg": [20, 34], "range": 6, "acc": 80, "cal": "12ga", "mag": 6, "modes": [["single", 1]], "recoil": 6, "noise": 22, "reload": 3, "pellets": 8, "slots": ["optic", "barrel", "under", "stock"], "jam": 0.8},
       "Sniper": {"dmg": [30, 48], "range": 30, "acc": 82, "cal": ".338", "mag": 5, "modes": [["single", 1]], "recoil": 6, "noise": 24, "reload": 2, "pellets": 1, "slots": ["optic", "muzzle", "barrel", "under", "stock"], "jam": 0.5},
       "MG": {"dmg": [12, 18], "range": 16, "acc": 55, "cal": "7.62", "mag": 50, "modes": [["burst", 4], ["auto", 8]], "recoil": 3, "noise": 22, "reload": 4, "pellets": 1, "slots": ["optic", "muzzle", "under", "stock"], "jam": 1.5},
       "Heavy MG": {"dmg": [16, 24], "range": 20, "acc": 55, "cal": "12.7", "mag": 60, "modes": [["burst", 5], ["auto", 10]], "recoil": 3, "noise": 26, "reload": 5, "pellets": 1, "slots": ["optic", "muzzle"], "jam": 1.5},
       "Launcher": {"dmg": [40, 70], "range": 14, "acc": 65, "cal": "40mm", "mag": 1, "modes": [["single", 1]], "recoil": 0, "noise": 24, "reload": 2, "pellets": 1, "slots": ["optic", "under"], "jam": 0.5},
       "Laser": {"dmg": [14, 22], "range": 15, "acc": 78, "cal": "cell", "mag": 12, "modes": [["single", 1], ["burst", 2]], "recoil": 1, "noise": 8, "reload": 1, "pellets": 1, "slots": ["optic", "under"], "jam": 0.0}}
import zlib
items = []
for o in json.load(open(os.path.join(MOD, "gunset.json"))):
    if o.get("type") != "ITEM":
        continue
    code = o["id"][len("trl_gun_"):]
    gun = json.loads(json.dumps(GUN[cls[code]]))
    h = zlib.crc32(code.encode())
    gun["acc"] += (h % 9) - 4                       # every model handles a little differently
    gun["dmg"] = [gun["dmg"][0] + (h >> 4) % 3 - 1, gun["dmg"][1] + (h >> 6) % 3 - 1]
    if gun["mag"] > 1:
        gun["mag"] += ((h >> 8) % 5 - 2) * max(1, gun["mag"] // 12)
    items.append({"id": o["id"], "name": o["name"]["str"], "desc": o["description"], "weight_g": grams(o["weight"]),
                  "volume_ml": grams(o["weight"]) // 2, "length_mm": LEN.get(cls[code], 600), "price": int(o["price"].split()[0]),
                  "tags": ["gun", cls[code].lower().replace(" ", "_")], "looks_like": base[code], "gun": gun})
# ammunition: one item per caliber and kind; a box holds `rounds`.  kind modifiers live in the game (gunplay.gd).
AMMO = [("9mm", ["fmj", "ap", "hp"], 18, 14), (".357", ["fmj", "ap", "hp"], 12, 18), ("5.56", ["fmj", "ap", "hp"], 20, 24), ("12ga", ["shot", "slug"], 10, 20),
        (".338", ["fmj", "ap"], 10, 40), ("7.62", ["fmj", "ap"], 30, 30), ("12.7", ["fmj", "ap"], 20, 50), ("40mm", ["he"], 3, 45), ("cell", ["cell"], 20, 30)]
KINDN = {"fmj": "ball", "ap": "armor-piercing", "hp": "hollow-point", "shot": "buckshot", "slug": "slug", "he": "HE grenade", "cell": "charge pack"}
for cal, kinds, rounds, price in AMMO:
    for k in kinds:
        items.append({"id": "trl_ammo_%s_%s" % (cal.replace(".", ""), k), "name": "%s %s box" % (cal, KINDN[k]), "weight_g": rounds * 10, "volume_ml": rounds * 6, "length_mm": 80,
                      "price": price * (2 if k == "ap" else 1), "tags": ["ammo"], "looks_like": "9mm", "ammo": {"cal": cal, "kind": k, "rounds": rounds}})
# gun mods.  effects: acc (flat, percentage points), aim (extra bonus per aiming turn), hip (bonus when not aiming), range_pct, rangepen_pct (less accuracy lost per tile),
# close_pen (penalty inside 4 tiles), recoil_pct, noise_cap (shots are heard no further than this), dmg_pct, mag_pct, jam (percentage points), reload (turns), spread_pct
MODS = [
    ("redot", "red-dot sight", "optic", {"acc": 5, "aim": 1}, 90, 120, "Fast, forgiving.  A little steadier on the first aimed turn."),
    ("holo", "holographic sight", "optic", {"acc": 7, "aim": 2, "rangepen_pct": 15}, 150, 220, "Wide window, bright reticle."),
    ("scope4", "4x scope", "optic", {"acc": 8, "aim": 3, "range_pct": 30, "rangepen_pct": 40, "close_pen": 8}, 300, 400, "Reaches out; clumsy up close."),
    ("scope8", "8x sniper scope", "optic", {"acc": 10, "aim": 5, "range_pct": 70, "rangepen_pct": 65, "close_pen": 18}, 700, 900, "For long streets and rooftops.  Useless at arm's length."),
    ("smartlink", "smartlink sight", "optic", {"acc": 12, "aim": 3, "hip": 6, "rangepen_pct": 30}, 600, 1100, "Reads your optic nerve.  The gun knows where you are looking."),
    ("laser", "laser sight", "under", {"hip": 10, "close_pen": -4}, 70, 80, "A red dot on the target.  Helps most when you are not taking time to aim."),
    ("foregrip", "foregrip", "under", {"recoil_pct": -25, "acc": 2}, 40, 150, "Hold it down in bursts."),
    ("bipod", "folding bipod", "under", {"recoil_pct": -15, "aim": 2, "acc": 3}, 80, 500, "Steadies a long gun if you are not walking."),
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
    ("cheekrest", "cheek rest and padded stock", "stock", {"recoil_pct": -30, "aim": 2, "acc": 2}, 160, 700, "Built for precision."),
]
for mid, name, slot, eff, price, wt, desc in MODS:
    items.append({"id": "trl_mod_" + mid, "name": name, "desc": desc, "weight_g": wt, "volume_ml": max(40, wt // 2), "length_mm": 150, "price": price,
                  "tags": ["mod"], "looks_like": "scope", "mod": {"slot": slot, "fx": eff}})
# melee weapons: strictly Japanese or Russian.  Three grades each (plain, forged, masterwork).  fields: dmg, reach, acc, fast (chance of a second strike),
# slow (attack takes two turns), parry (percent off enemy melee hit chance), stun/trip/entangle/disarm (chances), bleed, sneak (backstab multiplier),
# sweep (also hits others beside you), brace (reach strike on a charger does more), flail (ignores the target's parry), verb
JP = "Japanese"
RU = "Russian"
MELEE = [
    # id, name, culture, class tag, dmg, reach, weight g, length mm, price, looks_like, extras
    ("kama", "kama", JP, "blade", [6, 11], 1, 600, 400, 60, "trl_kama", {"fast": 0.4, "trip": 0.2, "bleed": True, "verb": "hook"}),
    ("wakizashi", "wakizashi", JP, "blade", [9, 15], 1, 900, 650, 220, "wakizashi", {"parry": 10, "fast": 0.15, "bleed": True, "verb": "cut"}),
    ("katana", "katana", JP, "blade", [12, 20], 1, 1200, 1000, 450, "katana", {"parry": 15, "bleed": True, "verb": "cut"}),
    ("tanto", "tanto", JP, "blade", [6, 10], 1, 300, 300, 90, "tanto", {"sneak": 5, "fast": 0.3, "bleed": True, "verb": "stab"}),
    ("nodachi", "nodachi", JP, "blade", [16, 28], 2, 2800, 1600, 700, "nodachi", {"slow": True, "parry": 10, "bleed": True, "knock": 0.35, "verb": "cleave"}),
    ("naginata", "naginata", JP, "polearm", [11, 18], 2, 2200, 2100, 380, "naginata", {"sweep": True, "parry": 10, "bleed": True, "verb": "slash"}),
    ("yari", "yari", JP, "polearm", [10, 16], 2, 1800, 2000, 200, "trl_yari", {"brace": True, "verb": "thrust"}),
    ("bo", "bo staff", JP, "staff", [5, 9], 2, 1000, 1800, 40, "bokken", {"stun": 0.25, "parry": 20, "knock": 0.4, "verb": "crack"}),
    ("jo", "jo staff", JP, "staff", [4, 8], 1, 500, 1300, 30, "bokken", {"stun": 0.2, "parry": 15, "verb": "rap"}),
    ("nunchaku", "nunchaku", JP, "blunt", [6, 11], 1, 450, 350, 50, "trl_nunchaku", {"fast": 0.4, "stun": 0.1, "verb": "whip"}),
    ("kusarigama", "kusarigama", JP, "chain", [7, 12], 2, 1100, 1500, 260, "trl_kusarigama", {"entangle": 0.35, "bleed": True, "verb": "lash"}),
    ("sai", "sai", JP, "blunt", [5, 9], 1, 600, 400, 140, "punch_dagger", {"parry": 20, "disarm": 0.3, "fast": 0.2, "verb": "jab"}),
    ("jitte", "jitte", JP, "blunt", [6, 10], 1, 700, 450, 170, "baton", {"parry": 20, "disarm": 0.45, "stun": 0.1, "verb": "strike"}),
    ("tessen", "tessen (iron fan)", JP, "blunt", [3, 6], 1, 400, 300, 160, "baton", {"parry": 20, "sneak": 3, "fast": 0.3, "verb": "rap"}),
    ("kunai", "kunai", JP, "blade", [4, 8], 1, 200, 220, 45, "tanto", {"sneak": 5, "fast": 0.25, "verb": "stab"}),
    ("ono", "ono (axe)", JP, "axe", [14, 22], 1, 3500, 1100, 300, "hatchet", {"slow": True, "bleed": True, "knock": 0.5, "verb": "chop"}),
    ("tonfa", "tonfa", JP, "blunt", [5, 9], 1, 600, 450, 70, "tonfa", {"parry": 15, "stun": 0.2, "verb": "strike"}),
    ("shashka", "shashka", RU, "blade", [11, 18], 1, 1100, 900, 320, "cavalry_sabre", {"parry": 15, "fast": 0.15, "bleed": True, "verb": "slash"}),
    ("kinzhal", "kinzhal", RU, "blade", [7, 12], 1, 500, 450, 130, "tanto", {"sneak": 5, "fast": 0.25, "bleed": True, "verb": "stab"}),
    ("finka", "Finka knife", RU, "blade", [6, 10], 1, 250, 280, 70, "tanto", {"sneak": 5, "fast": 0.25, "bleed": True, "verb": "stab"}),
    ("lopata", "MPL-50 sapper shovel", RU, "axe", [9, 15], 1, 1300, 500, 55, "shovel", {"stun": 0.15, "knock": 0.3, "verb": "chop"}),
    ("kistien", "kistien flail", RU, "chain", [8, 16], 1, 900, 500, 90, "2h_flail_wood", {"stun": 0.2, "flail": True, "knock": 0.4, "verb": "smash"}),
    ("chekan", "chekan axe-hammer", RU, "axe", [10, 17], 1, 900, 650, 150, "hatchet", {"bleed": True, "stun": 0.1, "verb": "hack"}),
    ("topor", "topor axe", RU, "axe", [12, 20], 1, 1600, 700, 100, "hatchet", {"bleed": True, "knock": 0.3, "verb": "chop"}),
    ("kastet", "kastet knuckles", RU, "blunt", [4, 8], 1, 250, 100, 40, "knuckle_brass", {"fast": 0.45, "stun": 0.15, "verb": "punch"}),
]
GRADES = [("", "", 1.0, 0, 1.0, 0), ("_f", "forged ", 1.2, 4, 3.5, 0), ("_m", "masterwork ", 1.45, 8, 9.0, 5)]
for mid, name, culture, klass, dmg, reach, wt, ln, price, looks, extra in MELEE:
    for suf, pre, dm, acc, pm, parry_bonus in GRADES:
        m = {"dmg": [max(1, round(dmg[0] * dm)), max(1, round(dmg[1] * dm))], "reach": reach, "acc": acc}
        m.update(extra)
        if "parry" in m or parry_bonus:
            m["parry"] = m.get("parry", 0) + parry_bonus
        items.append({"id": "trl_mel_" + mid + suf, "name": pre + name, "desc": "A %s weapon (%s)." % (culture, klass), "weight_g": wt, "volume_ml": max(60, wt // 3),
                      "length_mm": ln, "price": int(price * pm), "tags": ["melee", klass, culture.lower()], "looks_like": looks, "melee": m, "culture": culture})
# containers: the pocket model
P = lambda i, vol, wt, flex=False, tags=None, water=False, length=0: {"id": i, "max_volume_ml": vol, "max_weight_g": wt, "flexible": flex,
                                                                    "allow_tags": tags or [], "watertight": water, "max_item_length_mm": length}
items += [
    {"id": "trl_backpack", "name": "commuter backpack", "weight_g": 700, "volume_ml": 1500, "length_mm": 450, "price": 120, "tags": ["container", "worn"], "looks_like": "backpack",
     "pockets": [P("main", 22000, 15000, True), P("side", 1500, 3000, False, ["bottle"], False, 300)]},
    {"id": "trl_holster", "name": "thigh holster", "weight_g": 250, "volume_ml": 400, "length_mm": 300, "price": 60, "tags": ["container", "worn"], "looks_like": "holster",
     "pockets": [P("holster", 600, 2500, False, ["pistol", "revolver"], False, 260)]},
    {"id": "trl_coat", "name": "long coat", "weight_g": 1400, "volume_ml": 3000, "length_mm": 800, "price": 300, "tags": ["container", "worn"], "looks_like": "trenchcoat", "armor": {"slot": "chest", "phys": 1, "dur": 20},
     "pockets": [P("inner", 2500, 4000, True), P("left", 600, 1000, True), P("right", 600, 1000, True)]},
    {"id": "trl_helmet", "name": "ballistic helmet", "desc": "Armor 3 on the head.", "weight_g": 1200, "volume_ml": 3000, "length_mm": 300, "price": 350, "tags": ["armor", "worn"], "looks_like": "helmet_ball", "armor": {"slot": "head", "phys": 3, "dur": 40}},
    {"id": "trl_visor", "name": "riot visor helmet", "desc": "Armor 5 on the head.", "weight_g": 1900, "volume_ml": 4000, "length_mm": 320, "price": 800, "tags": ["armor", "worn"], "looks_like": "helmet_riot", "armor": {"slot": "head", "phys": 5, "dur": 60}},
    {"id": "trl_vest", "name": "ballistic vest", "desc": "Armor 4 on the chest.", "weight_g": 3200, "volume_ml": 5000, "length_mm": 500, "price": 500, "tags": ["armor", "worn"], "looks_like": "vest_ballistic", "armor": {"slot": "chest", "phys": 4, "dur": 60}},
    {"id": "trl_vest_heavy", "name": "plate carrier", "desc": "Armor 7 on the chest.", "weight_g": 6800, "volume_ml": 8000, "length_mm": 520, "price": 1400, "tags": ["armor", "worn"], "looks_like": "vest_plate", "armor": {"slot": "chest", "phys": 7, "dur": 90}},
    {"id": "trl_bracers", "name": "composite arm guards", "desc": "Armor 2 on both arms.", "weight_g": 1100, "volume_ml": 2000, "length_mm": 350, "price": 300, "tags": ["armor", "worn"], "looks_like": "armguard", "armor": {"slot": "arms", "phys": 2, "dur": 40}},
    {"id": "trl_greaves", "name": "shin guards", "desc": "Armor 2 on both legs.", "weight_g": 1500, "volume_ml": 2500, "length_mm": 400, "price": 300, "tags": ["armor", "worn"], "looks_like": "legguard", "armor": {"slot": "legs", "phys": 2, "dur": 40}},
    {"id": "trl_pouch", "name": "belt pouch", "weight_g": 120, "volume_ml": 250, "length_mm": 180, "price": 20, "tags": ["container"], "looks_like": "chestpouch",
     "pockets": [P("main", 1200, 2000, True)]},
    {"id": "trl_duffel", "name": "duffel bag", "weight_g": 900, "volume_ml": 1800, "length_mm": 700, "price": 80, "tags": ["container"], "looks_like": "duffelbag",
     "pockets": [P("main", 55000, 30000, True)]},
    {"id": "trl_water_bottle", "name": "water bottle", "weight_g": 80, "volume_ml": 600, "length_mm": 230, "price": 5, "tags": ["container", "bottle"], "looks_like": "bottle_plastic",
     "pockets": [P("liquid", 500, 600, False, ["liquid"], True, 0)]},
    {"id": "trl_yen", "name": "yen notes", "weight_g": 1, "volume_ml": 1, "length_mm": 0, "price": 1, "tags": ["money"], "looks_like": "money_bundle_hundred"},
    {"id": "trl_ammo", "name": "ammo box", "weight_g": 120, "volume_ml": 70, "length_mm": 60, "price": 20, "tags": ["ammo"], "looks_like": "9mm", "ammo": {"cal": "9mm", "kind": "fmj", "rounds": 12}},
    {"id": "trl_water", "name": "water", "weight_g": 1, "volume_ml": 1, "length_mm": 0, "price": 0, "tags": ["liquid"], "per_unit": True},
    {"id": "trl_ration", "name": "cyber ration bar", "weight_g": 90, "volume_ml": 80, "length_mm": 150, "price": 15, "tags": ["food"], "looks_like": "granola"},
    {"id": "trl_parcel", "name": "sealed parcel", "weight_g": 600, "volume_ml": 1500, "length_mm": 250, "price": 0, "tags": ["job"], "looks_like": "box_small"},
    {"id": "trl_datacase", "name": "encrypted data case", "weight_g": 1800, "volume_ml": 6000, "length_mm": 420, "price": 400, "tags": ["job"], "looks_like": "briefcase"},
    {"id": "trl_medkit", "name": "trauma patch", "weight_g": 120, "volume_ml": 100, "length_mm": 120, "price": 40, "tags": ["medical"], "looks_like": "bandages", "desc": "Heals 25 and mends your worst limb a little."},
    {"id": "trl_kit_repair", "name": "field repair kit", "desc": "Patch plates, hoses and wiring.  Restores 25 points to one vehicle part.", "weight_g": 1500, "volume_ml": 3000, "length_mm": 350, "price": 90, "tags": ["tool"], "looks_like": "toolbox", "repair": 25},
    {"id": "trl_credstick", "name": "credstick", "weight_g": 10, "volume_ml": 4, "length_mm": 80, "price": 0, "tags": ["card"], "looks_like": "cash_card"},
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
                  "tags": ["engine"], "looks_like": "engine_block", "engine": {"power": power, "drain": drain, "hp": hp, "fits": fits}})
json.dump(items, open(os.path.join(HERE, "../data/items.json"), "w"), indent=1)
print(len(items), "items exported")
