#!/usr/bin/env python3
"""Generate the Implant Status menu, the monitor item and the random-CBM item groups."""
import json, sys, os
SRC, MOD = sys.argv[1], sys.argv[2]
items = json.load(open(os.path.join(SRC, "data/json/items/bionics.json")))
bs = {x["id"]: x for x in json.load(open(os.path.join(SRC, "data/json/bionics.json"))) if x.get("type") == "bionic"}

_cf = os.path.join(MOD, "combat.json")
if os.path.exists(_cf):
    for x in json.load(open(_cf)):
        if x.get("type") == "bionic":
            bs[x["id"]] = x

def nm(x):
    n = x["name"]; return n["str"] if isinstance(n, dict) else n

def kind(b):
    f = b.get("flags", [])
    if "BIONIC_TOGGLED" in f: return "toggled"
    if "act_cost" in b or "activated_eocs" in b or "spell_on_activation" in b or "fake_weapon" in b: return "activated"
    return "passive"

def details(b):
    parts = [f"{nm(b)} - {kind(b)} implant."]
    for k, lab in (("act_cost", "activation cost"), ("react_cost", "running cost"), ("trigger_cost", "trigger cost")):
        if k in b: parts.append(f"Power: {lab} {b[k]}.")
    if "capacity" in b: parts.append(f"Adds {b['capacity']} of power capacity.")
    occ = b.get("occupied_bodyparts")
    if occ: parts.append("Uses slots: " + ", ".join(f"{p} {n}" for p, n in occ) + ".")
    parts.append(b["description"])
    return "  ".join(parts)

out = []
ids, names, descs = [], [], []
for bid, b in sorted(bs.items(), key=lambda kv: nm(kv[1]).lower()):
    eid = f"trl_status_{bid}"
    text = details(b)
    out.append({"type": "effect_on_condition", "id": eid,
                "condition": {"u_has_bionics": bid},
                "effect": [{"u_message": text + "  Status: installed.  Use the bionics screen (})  to switch it on or off.", "type": "neutral"}]})
    ids.append(eid); names.append(nm(b)); descs.append(text)
# body overview: implants per body part (an implant counts once for every part it occupies)
parts = ["head", "eyes", "mouth", "torso", "arm_l", "arm_r", "hand_l", "hand_r", "leg_l", "leg_r", "foot_l", "foot_r"]
pretty = {"head": "Head", "eyes": "Eyes", "mouth": "Mouth", "torso": "Torso", "arm_l": "Left arm", "arm_r": "Right arm",
          "hand_l": "Left hand", "hand_r": "Right hand", "leg_l": "Left leg", "leg_r": "Right leg",
          "foot_l": "Left foot", "foot_r": "Right foot"}
eff = []
for part in parts:
    eff.append({"math": [f"u_trl_cnt_{part}", "=", "0"]})
for bid, b in sorted(bs.items()):
    if not any(pt in parts for pt, _ in (b.get("occupied_bodyparts") or [])):
        eff.append({"if": {"u_has_bionics": bid}, "then": [{"math": ["u_trl_cnt_torso", "+=", "1"]}]})
    for part, n in (b.get("occupied_bodyparts") or []):
        if part in parts:
            eff.append({"if": {"u_has_bionics": bid}, "then": [{"math": [f"u_trl_cnt_{part}", "+=", "1"]}]})
lines = "  ".join(f"{pretty[p]}: <u_val:trl_cnt_{p}>." for p in parts)
eff.append({"u_message": "Implants per body part.  " + lines, "type": "neutral"})
out.append({"type": "effect_on_condition", "id": "trl_body_overview", "effect": eff})
sel_ids = ["trl_body_overview"] + ids
sel_names = ["Body overview (implants per body part)"] + names
sel_desc = ["How many installed implants occupy each part of your body."] + descs
out.append({"type": "effect_on_condition", "id": "trl_implant_status",
            "effect": [{"if": {"u_has_bionics": "ANY"},
                        "then": [{"run_eoc_selector": sel_ids, "names": sel_names, "descriptions": sel_desc,
                                  "title": "Implant Status", "hide_failing": True, "allow_cancel": True}],
                        "else": [{"u_message": "You have no implants installed.", "type": "neutral"}]}]})
out.append({"type": "ITEM", "subtypes": ["TOOL"], "id": "trl_implant_monitor",
            "name": {"str": "implant status display"},
            "description": "A wrist display wired to your implants.  Use it to list every implant you have installed, with its type, power cost, body slots and effects.",
            "weight": "100 g", "volume": "100 ml", "symbol": ";", "color": "light_cyan",
            "material": ["plastic"], "flags": ["TRADER_AVOID"],
            "use_action": {"type": "effect_on_conditions", "description": "Open implant status",
                           "effect_on_conditions": ["trl_implant_status"]}})
# random pool: every non-faulty CBM
faulty = {x["id"] for x in items if x.get("copy-from") == "bionic_general_faulty"}
pool = sorted(i["id"] for i in items if "id" in i and i["id"] in bs and i["id"] not in faulty
              and not i["id"].startswith("bio_power_storage"))
out.append({"type": "item_group", "id": "trl_random_cbm", "subtype": "distribution",
            "entries": [{"item": i} for i in pool]})
out.append({"type": "item_group", "id": "trl_five_random_cbms", "subtype": "collection",
            "entries": [{"group": "trl_random_cbm"} for _ in range(5)]})
json.dump(out, open(os.path.join(MOD, "implants.json"), "w"), indent=1)
print(len(bs), "implants;", len(pool), "in random pool;", len(faulty), "faulty excluded")
