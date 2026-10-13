#!/usr/bin/env python3
"""Plasteel and kevlar-plasteel armor (design doc section M10).
Plasteel: a dense, transparent-cored steel-polymer.  Very hard to shoot or burn through (bullet, heat, acid and electric), a little less so
against blades, and still penetrable by the biggest rounds.  Heavy and bulky.  The kevlar-plasteel composites trade some protection for lightness.
usage: gen_armor.py <mod dir> -> <mod>/armor.json"""
import json, os, sys
MOD = sys.argv[1]
out = [
    {"type": "material", "id": "trl_plasteel", "copy-from": "steel", "name": "plasteel",
     "chip_resist": 40, "dmg_adj": ["scuffed", "dented", "cracked", "shattered"],
     "resist": {"bash": 8, "cut": 9, "acid": 12, "heat": 12, "bullet": 9, "electric": 8}},
    {"type": "material", "id": "trl_kp_composite", "copy-from": "kevlar_rigid", "name": "kevlar-plasteel",
     "chip_resist": 35, "resist": {"bash": 5, "cut": 6, "acid": 8, "heat": 8, "bullet": 8, "electric": 5}},
]


def armor_item(iid, name, desc, weight, volume, price, color, covers, flags, symbol="["):
    return {"type": "ITEM", "subtypes": ["ARMOR"], "id": iid, "category": "armor", "name": {"str": name, "str_pl": name}, "description": desc,
            "weight": weight, "volume": volume, "price": price, "price_postapoc": "300 USD", "symbol": symbol, "color": color,
            "warmth": 25, "flags": flags, "armor": covers}


def mat(m, cov, th):
    return {"type": m, "covered_by_mat": cov, "thickness": th}


out.append(armor_item(
    "trl_plasteel_armor", "plasteel armor",
    "A full suit of overlapping plasteel plates over a black underlayer: breastplate, pauldrons, bracers, cuisses and greaves, with a pale-cyan seam of light at every joint.  It stops bullets and energy bolts that would drop a person in a vest, and only the heaviest rounds get through, and then barely.  The price is bulk: it is very heavy, hard to move in, and you will not fit through a crowd.",
    "17 kg", "26 L", "90 kUSD", "light_cyan", [
        {"encumbrance": 32, "coverage": 95, "covers": ["torso"], "volume_encumber_modifier": 0.2, "material": [mat("trl_plasteel", 100, 6)]},
        {"encumbrance": 20, "coverage": 90, "covers": ["arm_l", "arm_r"], "material": [mat("trl_plasteel", 100, 5)]},
        {"encumbrance": 26, "coverage": 90, "covers": ["leg_l", "leg_r"], "material": [mat("trl_plasteel", 100, 5)]}],
    ["STURDY", "OUTER", "WATERPROOF", "BLOCK_WHILE_WORN", "VARSIZE"]))
out.append(armor_item(
    "trl_plasteel_helm", "plasteel helm",
    "A full plasteel helm with a rounded crown, a narrow glowing visor slit and a sealed gorget.  Heavy and bulky, and it narrows your view, but almost nothing gets through it.",
    "3600 g", "5 L", "30 kUSD", "light_cyan", [
        {"encumbrance": 18, "coverage": 100, "covers": ["head", "eyes", "mouth"], "material": [mat("trl_plasteel", 100, 6)]}],
    ["STURDY", "OUTER", "WATERPROOF", "VARSIZE"]))
out.append(armor_item(
    "trl_kp_vest", "kevlar-plasteel chest armor",
    "A chest rig of kevlar layers with plasteel plates sewn into the front, back and sides.  It protects almost as well as full plasteel against bullets and energy but weighs a fraction as much, and lets you move.",
    "5200 g", "9 L", "28 kUSD", "dark_gray", [
        {"encumbrance": 12, "coverage": 90, "covers": ["torso"], "material": [mat("trl_kp_composite", 100, 6)]}],
    ["STURDY", "OUTER", "WATERPROOF", "VARSIZE"]))
out.append(armor_item(
    "trl_kp_helmet", "kevlar-plasteel helmet",
    "An open-faced helmet of kevlar-plasteel composite: a rounded shell, cheek guards and a neck flare, with the face left clear so you can see and be seen.  Good protection against bullets and energy for its weight.",
    "1500 g", "3 L", "9 kUSD", "dark_gray", [
        {"encumbrance": 4, "coverage": 100, "covers": ["head"], "material": [mat("trl_kp_composite", 100, 6)]}],
    ["STURDY", "OUTER", "WATERPROOF", "VARSIZE"]))
out.append(armor_item(
    "trl_plasteel_boots", "plasteel boots",
    "Heavy plasteel greaves and sabatons over an insulated sole, with a cyan seam at the ankle.  Bullets and energy slide off them, but each step lands like a hammer and they are clumsy on stairs.",
    "3800 g", "6 L", "24 kUSD", "light_cyan", [
        {"encumbrance": 22, "coverage": 100, "covers": ["foot_l", "foot_r"], "material": [mat("trl_plasteel", 100, 5)]}],
    ["STURDY", "OUTER", "WATERPROOF", "VARSIZE"]))
out.append(armor_item(
    "trl_plasteel_gloves", "plasteel gauntlets",
    "Articulated plasteel gauntlets over a thin graphite-weave glove, finger plates with a pale-cyan seam at the knuckles.  Very hard to damage, and the plates make fine work with your hands clumsy.",
    "1400 g", "2 L", "16 kUSD", "light_cyan", [
        {"encumbrance": 16, "coverage": 100, "covers": ["hand_l", "hand_r"], "material": [mat("trl_plasteel", 100, 4)]}],
    ["STURDY", "OUTER", "WATERPROOF", "VARSIZE"]))
out.append({"type": "item_group", "id": "trl_loot_armor", "subtype": "distribution",
            "entries": [{"item": "trl_kp_vest", "prob": 40}, {"item": "trl_kp_helmet", "prob": 40}, {"item": "trl_plasteel_armor", "prob": 8}, {"item": "trl_plasteel_helm", "prob": 8}, {"item": "trl_plasteel_boots", "prob": 8}, {"item": "trl_plasteel_gloves", "prob": 8}]})
json.dump(out, open(os.path.join(MOD, "armor.json"), "w"), indent=1)
print("armor: 6 items, 2 materials")
