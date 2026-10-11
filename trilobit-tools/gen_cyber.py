#!/usr/bin/env python3
"""Generate cyber.json: implant armor patches, implant HP model, split HP bars, repair kit.
args: repo root, mod dir"""
import json, sys, os
SRC, MOD = sys.argv[1], sys.argv[2]
bs = {x["id"]: x for x in json.load(open(os.path.join(SRC, "data/json/bionics.json"))) if x.get("type") == "bionic"}
cf = os.path.join(MOD, "combat.json")
combat = json.load(open(cf))
own = {x["id"]: x for x in combat if x.get("type") == "bionic"}
bs.update(own)

PARTS = ["head", "torso", "arm_l", "arm_r", "leg_l", "leg_r"]
CAP = {"head": 18, "torso": 80, "arm_l": 20, "arm_r": 20, "leg_l": 30, "leg_r": 30}
MAIN = {"head": "head", "mouth": "head", "eyes": "head", "torso": "torso", "arm_l": "arm_l", "hand_l": "arm_l",
        "arm_r": "arm_r", "hand_r": "arm_r", "leg_l": "leg_l", "foot_l": "leg_l", "leg_r": "leg_r", "foot_r": "leg_r"}
LABEL = {"head": "HEAD", "torso": "TORSO", "arm_l": "L ARM", "arm_r": "R ARM", "leg_l": "L LEG", "leg_r": "R LEG"}
out = []

# 1. implant armor
def protec(b):
    res = []
    for part, n in b.get("occupied_bodyparts") or []:
        res.append([part, {"bash": min(16, 4 + n), "cut": min(16, 4 + n), "stab": min(16, 4 + n), "bullet": min(24, 6 + 2 * n)}])
    return res
for bid, b in sorted(bs.items()):
    p = protec(b)
    if not p: continue
    if bid in own:
        own[bid]["protec"] = p
    else:
        out.append({"type": "bionic", "id": bid, "copy-from": bid, "protec": p})
json.dump(combat, open(cf, "w"), indent=2)

# 2. recount: slots used per main part, implant max/current integrity
rc = []
for p in PARTS:
    rc.append({"math": [f"u_trl_used_{p}", "=", "0"]})
for bid, b in sorted(bs.items()):
    per = {}
    for part, n in b.get("occupied_bodyparts") or []:
        if part in MAIN: per[MAIN[part]] = per.get(MAIN[part], 0) + n
    for p, n in per.items():
        rc.append({"if": {"u_has_bionics": bid}, "then": [{"math": [f"u_trl_used_{p}", "+=", str(n)]}]})
for p in PARTS:
    rc += [
        {"math": [f"u_trl_s_{p}", "=", f"min(0.9, u_trl_used_{p} / {CAP[p]})"]},
        {"math": [f"u_trl_new_{p}", "=", f"u_hp_max('{p}') * u_trl_s_{p}"]},
        {"math": [f"u_trl_ihp_{p}", "=", f"clamp(u_trl_ihp_{p} + u_trl_new_{p} - u_trl_imax_{p}, 0, u_trl_new_{p})"]},
        {"math": [f"u_trl_imax_{p}", "=", f"u_trl_new_{p}"]},
    ]
rc.append({"run_eocs": ["trl_cyber_bars"]})
out.append({"type": "effect_on_condition", "id": "trl_cyber_recount", "effect": rc})
out.append({"type": "effect_on_condition", "id": "trl_cyber_recount_timer", "recurrence": "10 seconds", "global": True,
            "condition": {"math": ["1", "==", "1"]}, "effect": [{"run_eocs": ["trl_cyber_recount"]}]})
for ev, eid in (("installs_cbm", "trl_cyber_on_install"), ("removes_cbm", "trl_cyber_on_remove")):
    out.append({"type": "effect_on_condition", "id": eid, "eoc_type": "EVENT", "required_event": ev,
                "effect": [{"run_eocs": ["trl_cyber_recount"]}]})

# 3. damage routing
dm = []
for p in PARTS:
    dm.append({"if": {"compare_string": [p, {"context_val": "bodypart"}]}, "then": [
        {"math": ["_a", "=", f"min(u_trl_ihp_{p}, _damage * u_trl_s_{p})"]},
        {"math": [f"u_trl_ihp_{p}", "-=", "_a"]},
        {"math": [f"u_hp('{p}')", "=", f"min(u_hp('{p}') + _a, u_hp_max('{p}'))"]},
        {"if": {"math": [f"u_trl_ihp_{p}", "<=", "0"]},
         "then": [{"if": {"math": [f"u_trl_imax_{p}", ">", "0"]},
                   "then": [{"u_message": f"Your {LABEL[p].lower()} implants are wrecked and need repair.", "type": "bad"}]}]},
    ]})
dm.append({"run_eocs": ["trl_cyber_bars"]})
out.append({"type": "effect_on_condition", "id": "trl_cyber_on_damage", "eoc_type": "EVENT",
            "required_event": "character_takes_damage", "effect": dm})

# 4. bars
bars = []
def bar(p, g0, fg, fk):
    k0 = 6 - g0
    s = ("<color_light_green>" + "|" * fg + "</color><color_dark_gray>" + "." * (g0 - fg) + "</color>"
         "<color_light_gray>" + "|" * fk + "</color><color_dark_gray>" + "." * (k0 - fk) + "</color>")
    return {"set_string_var": s, "target_var": {"u_val": f"trl_bar_{p}"}}
for p in PARTS:
    bars += [
        {"math": [f"u_trl_g0_{p}", "=", f"round(6 * (1 - u_trl_s_{p}))"]},
        {"math": [f"u_trl_fg_{p}", "=", f"ceil(u_trl_g0_{p} * max(u_hp('{p}'), 0) / max(u_hp_max('{p}'), 1) - 0.001)"]},
        {"math": [f"u_trl_fk_{p}", "=",
                  f"ceil((6 - u_trl_g0_{p}) * u_trl_ihp_{p} / max(u_trl_imax_{p}, 1) - 0.001)"]},
    ]
    for g0 in range(7):
        inner = []
        for fg in range(g0 + 1):
            inner.append({"if": {"math": [f"u_trl_fg_{p}", ">=", str(fg)]}, "then": [], "else": []})  # placeholder
        # exact-match chains
        gl = []
        for fg in range(g0 + 1):
            kl = []
            for fk in range(6 - g0 + 1):
                kl.append({"if": {"and": [{"math": [f"u_trl_fk_{p}", "==", str(fk)]}]}, "then": [bar(p, g0, fg, fk)]})
            gl.append({"if": {"math": [f"u_trl_fg_{p}", "==", str(fg)]}, "then": kl})
        bars.append({"if": {"math": [f"u_trl_g0_{p}", "==", str(g0)]}, "then": gl})
out.append({"type": "effect_on_condition", "id": "trl_cyber_bars", "effect": bars})
out.append({"type": "effect_on_condition", "id": "trl_cyber_bars_timer", "recurrence": "1 seconds", "global": True,
            "condition": {"math": ["1", "==", "1"]}, "effect": [{"run_eocs": ["trl_cyber_bars"]}]})

# 5. repair kit
fix = []
for p in PARTS:
    fix.append({"math": [f"u_trl_ihp_{p}", "=", f"u_trl_imax_{p}"]})
fix += [{"run_eocs": ["trl_cyber_recount"]}, {"u_message": "You service your implants and restore their integrity.", "type": "good"}]
out.append({"type": "effect_on_condition", "id": "trl_cyber_repair", "effect": fix})
out.append({"type": "ITEM", "subtypes": ["TOOL"], "id": "trl_implant_kit", "name": {"str": "implant maintenance kit"},
            "description": "Replacement actuators, micro-solder and cabling.  Using it restores the integrity of all your implants.",
            "weight": "600 g", "volume": "500 ml", "symbol": ",", "color": "light_gray", "material": ["steel", "plastic"],
            "max_charges": 10, "initial_charges": 10, "charges_per_use": 1,
            "use_action": {"type": "effect_on_conditions", "description": "Service implants", "effect_on_conditions": ["trl_cyber_repair"]}})

# 6. widgets overriding the stock HP bars
for wid, p in (("head", "head"), ("torso", "torso"), ("left_arm", "arm_l"), ("right_arm", "arm_r"), ("left_leg", "leg_l"), ("right_leg", "leg_r")):
    for suffix, flags in (("", []), ("_no_label", ["W_LABEL_NONE", "W_NO_PADDING"])):
        w = {"id": f"hp_{wid}_graph{suffix}", "type": "widget", "style": "text", "label": LABEL[p],
             "clauses": [{"id": "bar", "text": f"<u_val:trl_bar_{p}>", "parse_tags": True}]}
        if flags: w["flags"] = flags
        out.append(w)
json.dump(out, open(os.path.join(MOD, "cyber.json"), "w"), indent=1)
print(len(out), "entries")
