#!/usr/bin/env python3
"""Trilobit implant suite: pure data (no I/O).  Imported by gen_limbs, gen_cyber and gen_shops.

Space model (design doc, section L):  every body part has a fixed number of implant points.
  torso 24 (6 of them are the spine), head 8, each arm 6, each leg 10.
Limb implants come in four grades.  A better grade is more compact, so it leaves more room for add-ons:
  arm: medical 6, basic 5, advanced 4, elite 3 points;  leg: medical 10, basic 8, advanced 6, elite 5 points.
A part whose points are all used is fully cyberized.
Every implant has a quality q (how much of the damage the implant share absorbs) and its own condition
(the integrity pool in gen_cyber).  Prices are in yen.
"""

PARTS = ["head", "torso", "arm_l", "arm_r", "leg_l", "leg_r"]
CAP = {"head": 8, "torso": 24, "arm_l": 6, "arm_r": 6, "leg_l": 10, "leg_r": 10}
LABEL = {"head": "HEAD", "torso": "TORSO", "arm_l": "L ARM", "arm_r": "R ARM", "leg_l": "L LEG", "leg_r": "R LEG"}
PRETTY = {"head": "head", "torso": "torso", "arm_l": "left arm", "arm_r": "right arm", "leg_l": "left leg", "leg_r": "right leg"}
STAT = {"STRENGTH": "Strength", "DEXTERITY": "Dexterity", "INTELLIGENCE": "Intelligence", "PERCEPTION": "Perception"}

IMPL = {}    # bionic id -> dict
LINES = {}   # line id -> dict(name, ids)   (a line is what a shop stocks: a pair of limbs counts once)


def add(bid, name, desc, parts, price, q=0.7, ench=None, prot=None, group=None, line=None, frame=None, extra=None, bio_extra=None,
        copy_from=None):
    IMPL[bid] = dict(id=bid, name=name, desc=desc, parts=parts, price=price, q=q, ench=ench or {}, prot=prot or [], group=group,
                     frame=frame, extra=extra or {}, bio_extra=bio_extra or {}, copy_from=copy_from)
    if line:
        LINES.setdefault(line["id"], dict(name=line["name"], ids=[]))["ids"].append(bid)
    return bid


def stat_text(ench):
    return ", ".join(f"+{v} {STAT[k]}" for k, v in ench.items() if k in STAT)


def prot4(a):
    return {"bash": a[0], "cut": a[1], "stab": a[2], "bullet": a[3]}


# ---------------------------------------------------------------- limb frames
GRADE_NAME = {"med": "medical prosthetic", "basic": "basic cyber", "adv": "advanced cyber", "elite": "elite cyber"}
ARM = {  # grade: (points, ench, price, q, armor(b,c,s,bullet))
    "med":   (6, {}, 4000, 0.5, (1, 1, 1, 0)),
    "basic": (5, {"STRENGTH": 1}, 10000, 0.7, (2, 2, 2, 1)),
    "adv":   (4, {"STRENGTH": 1, "DEXTERITY": 1}, 55000, 0.85, (4, 4, 4, 3)),
    "elite": (3, {"STRENGTH": 2, "DEXTERITY": 1}, 220000, 1.0, (6, 6, 6, 5)),
}
LEG = {
    "med":   (10, {}, 6000, 0.5, (1, 1, 1, 0)),
    "basic": (8, {"DEXTERITY": 1}, 14000, 0.7, (2, 2, 2, 1)),
    "adv":   (6, {"DEXTERITY": 1, "STRENGTH": 1}, 80000, 0.85, (4, 4, 4, 3)),
    "elite": (5, {"DEXTERITY": 2, "STRENGTH": 1}, 350000, 1.0, (6, 6, 6, 5)),
}
for kind, tbl in (("arm", ARM), ("leg", LEG)):
    for g, (pts, ench, price, q, arm) in tbl.items():
        lid = f"{kind}_{g}"
        for side, sname in (("l", "left"), ("r", "right")):
            part = f"{kind}_{side}"
            nm = f"{GRADE_NAME[g].capitalize()} {kind} ({sname})"
            full = pts == CAP[part]
            txt = [f"{pts} of the {CAP[part]} points in the {sname} {kind}" + (" (a complete replacement: the limb is fully cyberized)" if full else ""),
                   stat_text(ench) or "no stat bonus", f"absorbs damage at quality {int(q * 100)}%"]
            add(f"trl_imp_{kind}_{side}_{g}", nm,
                f"A {GRADE_NAME[g]} {kind} replacing your {sname} {kind}.  Uses " + "; ".join(txt) + ".  Installing it rebuilds the limb.",
                [(part, pts)], price, q, ench, [[part, prot4(arm)]], group=f"frame_{part}", frame=part,
                line=dict(id=lid, name=f"{GRADE_NAME[g]} {kind}s"))

# ---------------------------------------------------------------- head: Intelligence and Perception
HEAD = [  # line, name, grade, points, ench, price
    ("head_int_1", "Cortical coprocessor", 1, 2, {"INTELLIGENCE": 1}, 10000),
    ("head_int_2", "Cortical coprocessor II", 2, 3, {"INTELLIGENCE": 2}, 48000),
    ("head_int_3", "Cortical coprocessor III", 3, 4, {"INTELLIGENCE": 3}, 190000),
    ("head_per_1", "Sensor array", 1, 2, {"PERCEPTION": 1}, 12000),
    ("head_per_2", "Sensor array II", 2, 3, {"PERCEPTION": 2}, 55000),
    ("head_per_3", "Sensor array III", 3, 4, {"PERCEPTION": 3}, 210000),
    ("head_lace", "Neural lace", 4, 5, {"INTELLIGENCE": 2, "PERCEPTION": 2}, 480000),
]
for lid, nm, g, pts, ench, price in HEAD:
    add(f"trl_imp_{lid}", nm, f"{nm}: a cranial implant that gives {stat_text(ench)}.  Uses {pts} of the 8 points in the head.",
        [("head", pts)], price, 0.7, ench, [], group=f"head_{lid[:-2] if lid != 'head_lace' else 'lace'}",
        line=dict(id=lid, name=nm.lower()))

# ---------------------------------------------------------------- torso: spine (6 points, one spine only)
SPINES = [("str", "Myomer spine", "STRENGTH"), ("dex", "Reflex spine", "DEXTERITY"), ("int", "Neural spine", "INTELLIGENCE")]
for key, nm, stat in SPINES:
    for g, (n, price) in enumerate(((1, 25000), (2, 120000), (3, 600000)), start=1):
        lid = f"spine_{key}_{g}"
        add(f"trl_imp_{lid}", f"{nm} {'I' * g}", f"{nm} {'I' * g}: a spinal implant that gives +{n} {STAT[stat]}.  Uses the 6 spine points of the torso; only one spine implant fits.",
            [("torso", 6)], price, 0.7, {stat: n}, [], group="spine", line=dict(id=lid, name=f"{nm.lower()} {'I' * g}"))
add("trl_imp_spine_all", "Master spine",
    "A full-stack spinal implant: +2 Strength, +2 Dexterity and +2 Intelligence.  Uses the 6 spine points of the torso; only one spine implant fits.",
    [("torso", 6)], 1000000, 0.7, {"STRENGTH": 2, "DEXTERITY": 2, "INTELLIGENCE": 2}, [], group="spine", line=dict(id="spine_all", name="master spine"))

# ---------------------------------------------------------------- dermal plating (bullet protection), per body part, two weights
PLATE = {  # part: [(weight, points, armor, price)]
    "torso": [("light", 4, (3, 3, 3, 6), 20000), ("heavy", 8, (5, 5, 5, 11), 90000)],
    "head": [("light", 2, (2, 2, 2, 4), 18000), ("heavy", 3, (4, 4, 4, 8), 85000)],
    "arm_l": [("light", 2, (2, 2, 2, 4), 12000), ("heavy", 3, (4, 4, 4, 8), 60000)],
    "arm_r": [("light", 2, (2, 2, 2, 4), 12000), ("heavy", 3, (4, 4, 4, 8), 60000)],
    "leg_l": [("light", 3, (2, 2, 2, 4), 15000), ("heavy", 5, (4, 4, 4, 8), 75000)],
    "leg_r": [("light", 3, (2, 2, 2, 4), 15000), ("heavy", 5, (4, 4, 4, 8), 75000)],
}
for part, rows in PLATE.items():
    for w, pts, arm, price in rows:
        grp = part[:3] if part.startswith(("arm", "leg")) else part
        lid = f"plate_{grp}_{w}"
        add(f"trl_imp_plate_{part}_{w}", f"{w.capitalize()} dermal plating ({PRETTY[part]})",
            f"Plates of ceramic and polymer under the skin of the {PRETTY[part]}: +{arm[3]} bullet armor and +{arm[0]} against blows and blades.  "
            f"Uses {pts} of the {CAP[part]} points in the {PRETTY[part]}; only one plating fits per body part.",
            [(part, pts)], price, 0.8, {}, [[part, prot4(arm)]], group=f"plate_{part}",
            line=dict(id=lid, name=f"{w} dermal plating ({'torso' if part == 'torso' else 'head' if part == 'head' else grp + 's'})"))

# ---------------------------------------------------------------- specialized implants
for side, sname in (("l", "left"), ("r", "right")):
    add(f"trl_imp_gun_{side}", f"Concealed arm gun ({sname})",
        f"A power-fed pistol folded inside the {sname} forearm.  Activate it to raise the gun; it fires bullets using bionic power.  Uses 3 of the 6 points in the arm.",
        [(f"arm_{side}", 3)], 95000, 0.7, group=f"gun_{side}", line=dict(id="gun", name="concealed arm guns"),
        bio_extra={"fake_weapon": "trl_fake_arm_gun", "flags": ["BIONIC_GUN", "BIONIC_NPC_USABLE"]})
add("trl_imp_blade_r", "Wrist blade (right)",
    "A monomolecular blade that slides out of the right wrist.  Uses 3 of the 6 points in the arm.",
    [("arm_r", 3)], 40000, 0.7, group="blade_r", line=dict(id="blade", name="wrist blades"), copy_from="bio_blade")
add("trl_imp_servos", "Silent servos",
    "Damped joint servos in both legs: your footsteps make far less noise.  Uses 3 points in each leg.",
    [("leg_l", 3), ("leg_r", 3)], 85000, 0.7, {}, [], group="servos", line=dict(id="servos", name="silent servos"),
    bio_extra={"enchantments_raw": [{"values": [{"value": "FOOTSTEP_NOISE", "multiply": -0.8}]}]})
add("trl_imp_stomach", "Cyberstomach",
    "A synthetic stomach that turns food into bionic power (toggle it on) and lets you eat cyber rations, which an ordinary stomach cannot digest.  Uses 4 of the 24 points in the torso.",
    [("torso", 4)], 30000, 0.7, group="stomach", line=dict(id="stomach", name="cyberstomach"), copy_from="bio_metabolics")

# the older Trilobit implants, so the point count includes them
EXISTING_Q = {"trl_bio_reflex": 0.7, "trl_bio_threat_sense": 0.7}

# ---------------------------------------------------------------- cyberbrains (sold by nanohack shops)
CYBERBRAINS = [("trl_bio_cyberbrain", "Cyberbrain Mk I", 4, 15000), ("trl_bio_cyberbrain_2", "Cyberbrain Mk II", 8, 40000),
               ("trl_bio_cyberbrain_3", "Cyberbrain Mk III", 14, 90000), ("trl_bio_cyberbrain_4", "Cyberbrain Mk IV", 22, 200000),
               ("trl_bio_cyberbrain_5", "Cyberbrain Mk V", 32, 450000)]
CYBERBRAIN_POINTS = 3

PRICE = {i["id"]: i["price"] for i in IMPL.values()}
PRICE.update({c[0]: c[3] for c in CYBERBRAINS})

# groups that may hold one implant only
def exclusive_with(bid):
    g = IMPL[bid]["group"]
    return [o for o in IMPL if o != bid and IMPL[o]["group"] == g and g]


# ---------------------------------------------------------------- which line goes where (by district tier p/m/r)
TIER_LINES = {
    "p": ["arm_med", "leg_med", "arm_basic", "leg_basic", "head_int_1", "head_per_1", "plate_torso_light", "plate_arm_light", "stomach"],
    "m": ["arm_basic", "leg_basic", "arm_adv", "leg_adv", "head_int_1", "head_int_2", "head_per_1", "head_per_2", "spine_str_1", "spine_dex_1",
          "spine_int_1", "plate_torso_light", "plate_torso_heavy", "plate_arm_light", "plate_leg_light", "plate_head_light", "stomach", "blade", "servos"],
    "r": ["arm_adv", "leg_adv", "arm_elite", "leg_elite", "head_int_2", "head_int_3", "head_per_2", "head_per_3", "head_lace", "spine_str_2",
          "spine_dex_2", "spine_int_2", "spine_str_3", "spine_dex_3", "spine_int_3", "spine_all", "plate_torso_heavy", "plate_arm_heavy",
          "plate_leg_heavy", "plate_head_heavy", "gun", "blade", "servos", "stomach"],
}
for t, ls in TIER_LINES.items():
    for l in ls:
        assert l in LINES, l
PRICE_MULT = {"p": 0.8, "m": 1.0, "r": 1.0}
REPAIR_CAP = {"p": 0.6, "m": 0.85, "r": 1.0}     # how much of full condition this tier's surgeon can restore
REPAIR_MULT = {"p": 0.7, "m": 1.0, "r": 1.4}
REPAIR_PER_POINT = 500

# ---------------------------------------------------------------- nanohack chips: prices (yen) and where they are sold
CHIP_PRICE = {  # trl_nh_<x>: yen
    "trl_nh_purge": 5000, "trl_nh_night_eye": 5000, "trl_nh_probe": 5500,
    "trl_nh_repair": 12000, "trl_nh_afterimage": 12000, "trl_nh_dampener": 9000, "trl_nh_pulse_scan": 8000, "trl_nh_print_kit": 8500,
    "trl_nh_blind": 9000, "trl_nh_disrupt": 11000, "trl_nh_override": 10000, "trl_nh_seal": 8000,
    "trl_nh_plating": 20000, "trl_nh_reactive": 22000, "trl_nh_lock_on": 18000, "trl_nh_overload": 15000, "trl_nh_lock": 17000,
    "trl_nh_print_ammo": 24000, "trl_nh_hop": 20000, "trl_nh_command": 20000,
    "trl_nh_overclock": 55000, "trl_nh_shock_field": 35000, "trl_nh_siphon": 38000, "trl_nh_takeover": 45000,
    "trl_nh_cloak": 90000, "trl_nh_blink": 100000,
}
OFFENSIVE = {"trl_nh_overload", "trl_nh_blind", "trl_nh_lock", "trl_nh_shock_field", "trl_nh_siphon", "trl_nh_disrupt", "trl_nh_takeover"}
_BASE = ["purge", "night_eye", "probe", "dampener", "pulse_scan", "afterimage", "repair", "print_kit", "override", "seal"]
_MID = _BASE + ["plating", "reactive", "lock_on", "hop", "print_ammo", "command", "overclock"]
NANO_TIER = {
    "p": ["trl_nh_" + x for x in _BASE + ["blind", "lock", "overload", "disrupt"]],      # back-street shops may sell cheap offensive hacks
    "m": ["trl_nh_" + x for x in _MID],
    "r": ["trl_nh_" + x for x in _MID + ["cloak", "blink"]],
}
for _t, _l in NANO_TIER.items():
    for _x in _l:
        assert _x in CHIP_PRICE, _x
        if _t in ("m", "r"):
            assert _x not in OFFENSIVE, _x
NANO_BRAINS = {"p": ["trl_bio_cyberbrain", "trl_bio_cyberbrain_2"], "m": ["trl_bio_cyberbrain_2", "trl_bio_cyberbrain_3"],
               "r": ["trl_bio_cyberbrain_3", "trl_bio_cyberbrain_4", "trl_bio_cyberbrain_5"]}
for _t, _l in NANO_TIER.items():
    for _x in _l:
        PRICE["trl_chip_nh_" + _x[len("trl_nh_"):]] = CHIP_PRICE[_x]
