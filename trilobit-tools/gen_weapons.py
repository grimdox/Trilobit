#!/usr/bin/env python3
"""Melee weapons, throwing stars and bows (Milestone 22, sections I4 and I5).
usage: gen_weapons.py <mod dir>   -> <mod>/weapons.json
(kama, yari, nunchaku, kusarigama are new; katana, wakizashi, tanto, nodachi, naginata and bo already exist in stock and are kept.)
"""
import json, os, sys
MOD = sys.argv[1]
out = []

def melee(id, name, desc, copy, cut=0, stab=0, bash=0, weight=None, volume=None, price="150 USD", **kw):
    dmg = {}
    if bash: dmg["bash"] = bash
    if cut: dmg["cut"] = cut
    if stab: dmg["stab"] = stab
    o = {"type": "ITEM", "id": id, "copy-from": copy, "name": {"str": name}, "description": desc, "melee_damage": dmg, "price": price, "price_postapoc": "40 USD"}
    if copy in ("sickle",): o["subtypes"] = ["TOOL"]
    if weight: o["weight"] = weight
    if volume: o["volume"] = volume
    o.update(kw)
    return o

out.append(melee("trl_kama", "kama", "A short curved blade on a wooden handle, balanced for hooking and slashing.  Quick in close quarters.",
                 "sickle", cut=24, bash=3, weight="600 g", volume="800 ml", price="120 USD",
                 techniques=["WBLOCK_1", "RAPID"], to_hit={"grip": "weapon", "length": "short", "surface": "line", "balance": "good"},
                 qualities=[["CUT", 1], ["BUTCHER", 6]]))
out.append(melee("trl_yari", "yari", "A straight-bladed spear with a long wooden shaft.  Its reach lets you strike before a charging enemy closes in.",
                 "spear_steel", stab=34, bash=6, weight="1700 g", price="260 USD"))
out.append({"type": "ITEM", "id": "trl_nunchaku", "name": {"str": "nunchaku", "str_pl": "nunchaku"}, "symbol": "/", "color": "brown",
            "description": "Two hardwood bars joined by a short chain.  Fast, awkward strikes that are hard to block.",
            "material": ["wood", "steel"], "weight": "450 g", "volume": "700 ml", "longest_side": "70 cm", "price": "70 USD", "price_postapoc": "20 USD",
            "to_hit": {"grip": "weapon", "length": "short", "surface": "any", "balance": "good"}, "techniques": ["RAPID", "WBLOCK_1"],
            "flags": ["DURABLE_MELEE"], "melee_damage": {"bash": 20}})
out.append(melee("trl_kusarigama", "kusarigama", "A kama joined to a weighted chain.  Swing the weight to entangle and hit at range, then close with the sickle.",
                 "sickle", cut=22, bash=8, weight="1100 g", volume="1500 ml", price="240 USD",
                 techniques=["WBLOCK_1", "SWEEP"], to_hit={"grip": "weapon", "length": "long", "surface": "line", "balance": "neutral"},
                 flags=["DURABLE_MELEE", "REACH_ATTACK"], qualities=[["CUT", 1]]))
# throwing stars
for sid, name, pts, dmg in (("trl_shuriken_4", "four-point throwing star", 4, 9), ("trl_shuriken_8", "eight-point throwing star", 8, 11)):
    out.append({"type": "ITEM", "id": sid, "name": {"str": name, "str_pl": name + "s"}, "symbol": ";", "color": "light_gray",
                "description": f"A flat steel star with {pts} points, made for throwing.  Quiet, light and recoverable.",
                "material": ["steel"], "weight": "28 g", "volume": "20 ml", "longest_side": "10 cm", "price": "8 USD", "price_postapoc": "2 USD",
                "to_hit": {"grip": "none", "length": "hand", "surface": "point", "balance": "neutral"},
                "flags": ["ALLOWS_BODY_BLOCK"], "thrown_damage": [{"damage_type": "cut", "amount": dmg}], "melee_damage": {"cut": 4}})
# bows
def bow(id, base, name, desc, rng, dmg, minstr, price):
    return {"type": "ITEM", "subtypes": ["ARMOR", "GUN"], "id": id, "copy-from": base, "name": {"str": name}, "description": desc, "range": rng,
            "ranged_damage": {"damage_type": "stab", "amount": dmg}, "min_strength": minstr, "price": price, "looks_like": base}
out.append(bow("trl_yumi", "longbow", "yumi", "A tall asymmetric bow, gripped below the middle.  Long range and a smooth draw, traditional and quiet.", 20, 7, 8, "700 USD"))
out.append(bow("trl_hankyu", "shortbow", "hankyu", "A short bow used from horseback or in tight streets.  Light and fast to draw.", 12, 5, 6, "220 USD"))
out.append({"type": "ITEM", "subtypes": ["AMMO"], "id": "trl_arrow_ap", "copy-from": "arrow_metal", "name": {"str": "armor-piercing arrow"},
            "description": "A narrow steel arrowhead made to punch through plating.", "price": "35 USD",
            "damage": {"damage_type": "stab", "armor_penetration": 9, "constant_damage_multiplier": 1.3}})
out.append({"type": "ITEM", "subtypes": ["AMMO"], "id": "trl_arrow_emp", "copy-from": "arrow_metal", "name": {"str": "EMP arrow"},
            "description": "A hollow arrowhead holding a one-shot pulse coil.  Disables drones and android electronics on impact.", "price": "120 USD",
            "damage": {"damage_type": "stab", "constant_damage_multiplier": 1.0}, "effects": ["EMP"]})

# ---------------------------------------------------------------- the 25 new guns (section I2); original designs, stats borrowed from a stock base gun
GUNS = [
 # id, name, maker, base, class text, weight, extra
 ("hs12", "HS-12 Kirin", "Hoshikawa Arms", "remington_870", "A reliable pump-action police shotgun.", "3300 g", {}),
 ("vz12", "VZ-12 Medved", "Volkov Works", "saiga_12", "A heavy semi-automatic shotgun fed from a high-capacity magazine.", "4100 g", {}),
 ("gr8", "GR-8 Breacher", "Granite Arms", "remington_870_breacher", "A short pump shotgun made to blow doors off their hinges.", "2600 g", {}),
 ("va7", "VA-7", "Volkov Works", "ak47", "A rugged, hard-hitting rifle that keeps working in mud and rain.", "3500 g", {}),
 ("lh95", "LH-95", "Longhai Ordnance", "modular_m4_carbine", "A compact bullpup rifle, accurate and easy to handle in corridors.", "3300 g", {"longest_side": "700 mm"}),
 ("ha20", "HA-20", "Hoshikawa Arms", "modular_m16a4", "A light rifle with a very high rate of fire.", "3000 g", {}),
 ("ga5", "GA-5", "Granite Arms", "modular_ar15", "A modular rifle with rails for almost any attachment.", "3200 g", {}),
 ("hp9", "HP-9", "Hoshikawa Arms", "glock_19", "A flat, concealable 9mm pistol.", "580 g", {}),
 ("gp45", "GP-45", "Granite Arms", "m1911", "A heavy .45 pistol that hits hard.", "1150 g", {}),
 ("vp9", "VP-9", "Volkov Works", "usp_9mm", "A cheap, rugged 9mm pistol found all over the lower districts.", "800 g", {}),
 ("lp5", "LP-5", "Longhai Ordnance", "ruger_57", "A high-capacity pistol firing a small armor-piercing round.", "700 g", {}),
 ("gr44", "GR-44", "Granite Arms", "sw629", "A slow, heavy revolver with enormous stopping power.", "1300 g", {}),
 ("hr357", "HR-357", "Hoshikawa Arms", "sw_619", "A snub-nosed revolver, a good backup gun.", "900 g", {}),
 ("vr7", "VR-7", "Volkov Works", "LAW", "A single-shot shoulder rocket launcher for armor.", "7500 g", {}),
 ("lr80", "LR-80", "Longhai Ordnance", "m202_flash", "A four-tube launcher for area fire.", "6500 g", {}),
 ("hs7", "HS-7 Tsuru", "Hoshikawa Arms", "M24", "A precise bolt-action sniper rifle.", "5000 g", {}),
 ("gs300", "GS-300", "Granite Arms", "m14ebr", "A semi-automatic sniper rifle with fast follow-up shots.", "5200 g", {}),
 ("gam50", "GAM-50 Anvil", "Granite Arms", "m107a1", "An anti-materiel rifle: a huge round that goes through cover, doors and light armor.  Deafening and brutal to the shooter.", "14000 g",
  {"relative": {"range": 30}, "loudness": 40, "price": "30 kUSD"}),
 ("vm6", "VM-6", "Volkov Works", "m60", "A belt-fed general-purpose machine gun.", "9800 g", {}),
 ("lm95", "LM-95", "Longhai Ordnance", "m249", "A light squad machine gun with a large magazine.", "6800 g", {}),
 ("gm4", "GM-4", "Granite Arms", "m249", "A light box-magazine machine gun, heavy but controllable.", "7200 g", {}),
 ("hl1", "HL-1", "Hoshikawa Arms", "laser_rifle", "A silent laser pistol with low heat.", "900 g", {"longest_side": "220 mm", "range": 18}),
 ("gl9", "GL-9", "Granite Arms", "laser_rifle", "A general-purpose laser carbine.", "2400 g", {"range": 28}),
 ("ll3", "LL-3", "Longhai Ordnance", "laser_rifle", "A long-range beam rifle with a sniper-class focus.", "3800 g", {"range": 48, "longest_side": "1100 mm"}),
 ("vlx", "VL-X", "Volkov Works", "laser_rifle", "A heavy cutting laser with a short range that slices through cover.", "6000 g", {"range": 10, "longest_side": "900 mm"}),
]
for gid, name, maker, base, text, weight, extra in GUNS:
    o = {"type": "ITEM", "subtypes": ["GUN"], "id": "trl_gun_" + gid, "copy-from": base, "name": {"str": name}, "looks_like": base,
         "description": f"{text}  Made by {maker}.", "weight": weight, "price": "4 kUSD", "price_postapoc": "200 USD"}
    o.update(extra)
    out.append(o)
out.append({"type": "item_group", "id": "trl_loot_guns", "subtype": "distribution",
            "entries": [{"item": "trl_gun_" + g[0], "prob": (1 if g[0] in ("gam50", "vlx", "ll3", "vr7", "lr80") else 8)} for g in GUNS]})
out.append({"type": "item_group", "id": "trl_loot_melee", "subtype": "distribution",
            "entries": [{"item": i, "prob": p} for i, p in (("trl_kama", 20), ("trl_yari", 10), ("trl_nunchaku", 15), ("trl_kusarigama", 5), ("katana", 5),
                                                         ("wakizashi", 8), ("tanto", 20), ("nodachi", 3), ("naginata", 4), ("bo", 15))]})
out.append({"type": "item_group", "id": "trl_loot_thrown", "subtype": "distribution",
            "entries": [{"item": "trl_shuriken_4", "prob": 60}, {"item": "trl_shuriken_8", "prob": 40}]})
out.append({"type": "item_group", "id": "trl_loot_bows", "subtype": "collection",
            "entries": [{"item": "trl_yumi", "prob": 50}, {"item": "trl_hankyu", "prob": 50},
                        {"item": "trl_arrow_ap", "prob": 80, "count": [10, 20]}]})
json.dump(out, open(os.path.join(MOD, "weapons.json"), "w"), indent=1)
print(len(out), "entries")
