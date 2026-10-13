#!/usr/bin/env python3
"""Implant suite (design doc section L): limb implants in four grades, head, spine, plating, specialized implants,
cyberstomach, and the surgery bay (autodoc) menus: install, remove, repair, body check.
usage: gen_limbs.py <mod dir>   -> <mod>/limbs.json (also patches cyberbrain space in combat.json)
Run before gen_cyber.py.  Data tables live in limbdata.py."""
import json, os, sys
import limbdata as L
MOD = sys.argv[1]
KEYS = list("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
MAIN = {"head": "head", "mouth": "head", "eyes": "head", "torso": "torso", "arm_l": "arm_l", "hand_l": "arm_l",
        "arm_r": "arm_r", "hand_r": "arm_r", "leg_l": "leg_l", "foot_l": "leg_l", "leg_r": "leg_r", "foot_r": "leg_r"}
out = []


def short(bid):
    return bid.replace("trl_imp_", "").replace("trl_bio_", "")


# ---------------------------------------------------------------- bionic and item definitions
def cond_for(part):
    return {"math": [f"u_trl_ihp_{part}", ">", "0"]}


for i in L.IMPL.values():
    b = {"type": "bionic", "id": i["id"], "name": {"str": i["name"]}, "description": i["desc"],
         "occupied_bodyparts": [[p, n] for p, n in i["parts"]]}
    if i["copy_from"]:
        b["copy-from"] = i["copy_from"]
    else:
        b["flags"] = ["BIONIC_NPC_USABLE"]
    if i["ench"]:
        b["enchantments"] = [{"condition": cond_for(i["parts"][0][0]),
                              "values": [{"value": k, "add": v} for k, v in i["ench"].items()]}]
    if i["prot"]:
        b["protec"] = i["prot"]
    for k, v in i["bio_extra"].items():
        if k == "enchantments_raw":
            b["enchantments"] = v
        else:
            b[k] = v
    out.append(b)
    pts = sum(n for _, n in i["parts"])
    out.append({"id": i["id"], "copy-from": "bionic_general_npc_usable", "type": "ITEM", "subtypes": ["BIONIC_ITEM"],
                "name": {"str": i["name"] + " CBM"}, "looks_like": "bio_int_enhancer", "description": i["desc"],
                "price": f"{i['price']} USD", "price_postapoc": f"{i['price']} USD", "weight": f"{300 + 250 * pts} g", "difficulty": 6})

# the pseudo-item the concealed arm gun fires
out.append({"type": "ITEM", "subtypes": ["GUN"], "id": "trl_fake_arm_gun", "name": {"str": "concealed arm gun"},
            "description": {"str": "this a pseudo item", "//~": "NO_I18N"}, "volume": "1 L", "price": "0 cent", "material": ["steel", "plastic"],
            "symbol": "(", "looks_like": "usp_9mm", "color": "dark_gray", "skill": "pistol", "range": 18,
            "ranged_damage": {"damage_type": "bullet", "amount": 14, "armor_penetration": 2}, "energy_drain": "25 kJ", "dispersion": 90, "durability": 10,
            "loudness": 14, "modes": [["DEFAULT", "semi-auto", 1]],
            "flags": ["NEVER_JAMS", "TRADER_AVOID", "BIONIC_WEAPON", "ZERO_WEIGHT", "USES_BIONIC_POWER"]})

# ---------------------------------------------------------------- surgery bay furniture
BAYS = {}  # (kind, tier) -> id


def bay(kind, tier):
    fid = f"f_trl_autodoc_{kind}_{tier}"
    BAYS[(kind, tier)] = fid
    name = {"imp": "surgery bay", "nano": "cyberbrain bay"}[kind]
    return {"type": "furniture", "id": fid, "name": name,
            "description": ("An autodoc: a surgical couch under a robotic arm.  Examine it to install, remove or repair implants (the price is paid when you buy the implant; repairs cost yen)."
                            if kind == "imp" else
                            "A cradle with a headrest and a neural interface arm.  Examine it to install or remove a cyberbrain."
                            + (" Repairs available." if tier == "r" else "")),
            "symbol": "&", "color": "white", "move_cost_mod": -1, "coverage": 40, "required_str": -1, "light_emitted": 9,
            "flags": ["TRANSPARENT", "FLAT_SURF", "CONTAINER", "NOITEM", "SEALED", "AUTODOC_COUCH"] if False else ["TRANSPARENT", "FLAT_SURF", "CONTAINER", "NOITEM", "SEALED"],
            "examine_action": {"type": "effect_on_condition", "effect_on_conditions": [f"trl_ad_menu_{kind}_{tier}"]},
            "bash": {"str_min": 12, "str_max": 40, "sound": "smash!", "sound_fail": "thump."}}


for kind in ("imp", "nano"):
    for tier in ("p", "m", "r"):
        out.append(bay(kind, tier))

# ---------------------------------------------------------------- install / remove
CB = [(c[0], c[1]) for c in L.CYBERBRAINS]
exc = {}   # id -> exclusive ids
for i in L.IMPL:
    exc[i] = L.exclusive_with(i)
for a, _ in CB:
    exc[a] = [b for b, _ in CB if b != a]
names = {i["id"]: i["name"] for i in L.IMPL.values()}
names.update({a: n for a, n in CB})
parts_of = {i["id"]: i["parts"] for i in L.IMPL.values()}
parts_of.update({a: [("head", L.CYBERBRAIN_POINTS)] for a, _ in CB})
frame_of = {i["id"]: i["frame"] for i in L.IMPL.values() if i["frame"]}


def ad_install(bid):
    nm = names[bid]
    checks = []
    fail = []
    for p, n in parts_of[bid]:
        checks.append({"math": [f"u_trl_free_{p}", ">=", str(n)]})
    eff_ok = [{"u_consume_item": bid, "count": 1}, {"u_add_bionic": bid}]
    if bid in frame_of:
        p = frame_of[bid]
        eff_ok.append({"math": [f"u_hp('{p}')", "=", f"u_hp_max('{p}')"]})
    eff_ok += [{"run_eocs": ["trl_cyber_recount"]}]
    if bid.startswith("trl_bio_cyberbrain"):
        eff_ok += [{"run_eocs": ["trl_nh_recalc"]}]
    eff_ok += [{"u_message": f"The surgery bay installs {nm}.  Condition 100%.", "type": "good"}]
    # failure messages, one per reason
    chain = eff_ok
    for p, n in reversed(parts_of[bid]):
        chain = [{"if": {"math": [f"u_trl_free_{p}", ">=", str(n)]}, "then": chain,
                  "else": [{"u_message": f"Not enough space in your {L.PRETTY[p]} for {nm}: it needs {n} points and you have <u_val:trl_free_{p}> free.  Remove something first.", "type": "bad"}]}]
    for o in exc[bid]:
        chain = [{"if": {"u_has_bionics": o}, "then": [{"u_message": f"You already have {names[o]}; only one of this kind fits.  Remove it first.", "type": "bad"}],
                  "else": chain}]
    return {"type": "effect_on_condition", "id": f"trl_ad_i_{short(bid)}",
            "condition": {"and": [{"u_has_item": bid}, {"not": {"u_has_bionics": bid}}]},
            "effect": [{"run_eocs": ["trl_cyber_recount"]}] + chain}


def ad_remove(bid):
    nm = names[bid]
    eff = [{"u_lose_bionic": bid}, {"u_spawn_item": bid}, {"run_eocs": ["trl_cyber_recount"]}]
    if bid.startswith("trl_bio_cyberbrain"):
        eff += [{"run_eocs": ["trl_nh_recalc"]}]
    eff += [{"u_message": f"{nm} removed; the implant is in your pack.", "type": "info"}]
    return {"type": "effect_on_condition", "id": f"trl_ad_r_{short(bid)}", "condition": {"u_has_bionics": bid}, "effect": eff}


all_ids = list(L.IMPL) + [a for a, _ in CB]
for bid in all_ids:
    out.append(ad_install(bid))
    out.append(ad_remove(bid))


def selector(eid, ids, prefix, title, verb):
    out.append({"type": "effect_on_condition", "id": eid,
                "effect": [{"run_eoc_selector": [f"{prefix}{short(b)}" for b in ids], "names": [f"{verb} {names[b]}" for b in ids],
                            "keys": KEYS[:len(ids)], "hide_failing": True, "allow_cancel": True, "title": title}]})


selector("trl_ad_install_imp", list(L.IMPL), "trl_ad_i_", "Install an implant (only what you carry is listed)", "Install")
selector("trl_ad_install_nano", [a for a, _ in CB], "trl_ad_i_", "Install a cyberbrain (only what you carry is listed)", "Install")
selector("trl_ad_remove_imp", all_ids, "trl_ad_r_", "Remove an installed implant", "Remove")
selector("trl_ad_remove_nano", [a for a, _ in CB], "trl_ad_r_", "Remove your cyberbrain", "Remove")

# ---------------------------------------------------------------- repair
def fix_math(p, c, mult):
    return [
        {"math": ["_ti", "=", f"max(u_trl_ihp_{p}, u_trl_imax_{p} * {c})"]},
        {"math": ["_th", "=", f"u_hp('{p}') + (max(u_hp('{p}'), u_hp_max('{p}') * {c}) - u_hp('{p}')) * u_trl_s_{p}"]},
        {"math": ["_cost", "=", f"ceil(((_ti - u_trl_ihp_{p}) + (_th - u_hp('{p}'))) / max(u_hp_max('{p}'), 1) * u_trl_used_{p} * {L.REPAIR_PER_POINT} * {mult})"]},
    ]


for t in ("p", "m", "r"):
    c, mult = L.REPAIR_CAP[t], L.REPAIR_MULT[t]
    pct = int(c * 100)
    quote, fixall = [{"run_eocs": ["trl_cyber_recount"]}], [{"run_eocs": ["trl_cyber_recount"]}, {"math": ["_total", "=", "0"]}]
    for p in L.PARTS:
        quote += fix_math(p, c, mult) + [{"if": {"math": [f"u_trl_used_{p}", ">", "0"]},
                                           "then": [{"math": [f"u_trl_quote_{p}", "=", "_cost"]},
                                                    {"u_message": f"  {L.PRETTY[p].capitalize()}: <u_val:trl_quote_{p}> yen.", "type": "neutral"}]}]
        fixall += fix_math(p, c, mult) + [{"math": ["_total", "+=", "_cost"]}]
        one = [{"run_eocs": ["trl_cyber_recount"]}] + fix_math(p, c, mult) + [
            {"if": {"math": [f"u_trl_used_{p}", "<=", "0"]}, "then": [{"u_message": f"You have no implants in your {L.PRETTY[p]}.", "type": "info"}],
             "else": [{"if": {"math": ["_cost", "<=", "0"]}, "then": [{"u_message": f"Your {L.PRETTY[p]} needs no repair here.", "type": "info"}],
                       "else": [{"if": {"math": ["u_item_count('trl_yen')", "<", "_cost"]},
                                 "then": [{"u_message": f"Repairing your {L.PRETTY[p]} costs <context_val:cost> yen.", "type": "bad"}],
                                 "else": [{"u_consume_item": "trl_yen", "count": {"math": ["_cost"]}},
                                          {"math": [f"u_trl_ihp_{p}", "=", "_ti"]}, {"math": [f"u_hp('{p}')", "=", "_th"]},
                                          {"math": [f"u_trl_last_{p}", "=", f"u_hp('{p}')"]},
                                          {"run_eocs": ["trl_cyber_bars"]},
                                          {"u_message": f"Your {L.PRETTY[p]} is repaired to {pct}% condition.", "type": "good"}]}]}]}]
        out.append({"type": "effect_on_condition", "id": f"trl_ad_fix_{t}_{p}", "effect": one})
    quote.insert(1, {"u_message": f"Repair quote (this shop restores up to {pct}% condition):", "type": "info"})
    out.append({"type": "effect_on_condition", "id": f"trl_ad_quote_{t}", "effect": quote})
    # repair everything: sequentially run each part's repair
    out.append({"type": "effect_on_condition", "id": f"trl_ad_fixall_{t}",
                "effect": [{"run_eocs": [f"trl_ad_fix_{t}_{p}" for p in L.PARTS]}]})

# ---------------------------------------------------------------- body check
chk = [{"run_eocs": ["trl_cyber_recount"]}]
for p in L.PARTS:
    chk.append({"math": [f"u_trl_cond_{p}", "=", f"round(100 * u_trl_ihp_{p} / max(u_trl_imax_{p}, 1))"]})
    chk.append({"if": {"math": [f"u_trl_used_{p}", ">", "0"]},
                "then": [{"u_message": f"{L.PRETTY[p].capitalize()}: <u_val:trl_used_{p}> of {L.CAP[p]} points used, implant condition <u_val:trl_cond_{p}>%.", "type": "neutral"}],
                "else": [{"u_message": f"{L.PRETTY[p].capitalize()}: natural, {L.CAP[p]} points free.", "type": "neutral"}]})
out.append({"type": "effect_on_condition", "id": "trl_body_check", "effect": chk})

# ---------------------------------------------------------------- the bay menus
for kind in ("imp", "nano"):
    for t in ("p", "m", "r"):
        ent = [("trl_ad_install_" + kind, "Install an implant from your pack" if kind == "imp" else "Install a cyberbrain from your pack"),
               ("trl_ad_remove_" + kind, "Remove an installed implant" if kind == "imp" else "Remove your cyberbrain"),
               ("trl_body_check", "Check your body (implant points and condition)")]
        if kind == "imp" or t == "r":
            ent += [(f"trl_ad_quote_{t}", "Get a repair quote"), (f"trl_ad_fixall_{t}", "Repair all implants and limbs")]
        out.append({"type": "effect_on_condition", "id": f"trl_ad_menu_{kind}_{t}",
                    "effect": [{"run_eoc_selector": [e for e, _ in ent], "names": [n for _, n in ent], "keys": KEYS[:len(ent)],
                                "allow_cancel": True, "title": {"imp": "Surgery bay", "nano": "Cyberbrain bay"}[kind] +
                                {"p": " (back-street)", "m": "", "r": " (premium)"}[t]}]})

json.dump(out, open(os.path.join(MOD, "limbs.json"), "w"), indent=1)

# ---------------------------------------------------------------- patch the older cyberbrain definitions
cp = os.path.join(MOD, "combat.json")
combat = json.load(open(cp))
for x in combat:
    if x.get("type") == "bionic" and x.get("id") == "trl_bio_cyberbrain":
        x["occupied_bodyparts"] = [["head", L.CYBERBRAIN_POINTS]]
    if x.get("type") == "ITEM" and x.get("id") == "trl_bio_cyberbrain":
        x["price"] = f"{L.PRICE['trl_bio_cyberbrain']} USD"; x["price_postapoc"] = x["price"]
json.dump(combat, open(cp, "w"), indent=2)
# starting kits no longer include the field repair kit
pp = os.path.join(MOD, "professions.json")
if os.path.exists(pp):
    prof = json.load(open(pp)); changed = 0
    def strip(o):
        global changed
        if isinstance(o, list):
            n = [strip(e) for e in o if not (e == "trl_implant_kit" or (isinstance(e, dict) and e.get("item") == "trl_implant_kit") or (isinstance(e, list) and e and e[0] == "trl_implant_kit"))]
            if len(n) != len(o): changed += 1
            return n
        if isinstance(o, dict):
            return {k: strip(v) for k, v in o.items()}
        return o
    prof = strip(prof)
    json.dump(prof, open(pp, "w"), indent=2)
    print("professions: kit references removed from", changed, "lists")
print(len(L.IMPL), "implants,", len(L.LINES), "stock lines,", len(out), "objects")
