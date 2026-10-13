#!/usr/bin/env python3
"""Generate cyber.json: implant armor patches, implant HP model, split HP bars, repair kit.
args: repo root, mod dir"""
import json, sys, os
import limbdata as LD
SRC, MOD = sys.argv[1], sys.argv[2]
bs = {x["id"]: x for x in json.load(open(os.path.join(SRC, "data/json/bionics.json"))) if x.get("type") == "bionic"}
STOCK = set(bs)
cf = os.path.join(MOD, "combat.json")
combat = json.load(open(cf))
own = {x["id"]: x for x in combat if x.get("type") == "bionic"}
bs.update(own)
# the other Trilobit bionics (cyberbrain grades 2 to 5) and the implant suite
_nf = os.path.join(MOD, "nanohacks.json")
if os.path.exists(_nf):
    for x in json.load(open(_nf)):
        if x.get("type") == "bionic":
            if x["id"].startswith("trl_bio_cyberbrain"):
                x["occupied_bodyparts"] = [["head", LD.CYBERBRAIN_POINTS]]
            bs[x["id"]] = x
for _i in LD.IMPL.values():
    bs[_i["id"]] = {"id": _i["id"], "occupied_bodyparts": [[p, n] for p, n in _i["parts"]]}
Q = {k: v["q"] for k, v in LD.IMPL.items()}
Q.update(LD.EXISTING_Q)

PARTS = ["head", "torso", "arm_l", "arm_r", "leg_l", "leg_r"]
CAP = LD.CAP
MAIN = {"head": "head", "mouth": "head", "eyes": "head", "torso": "torso", "arm_l": "arm_l", "hand_l": "arm_l",
        "arm_r": "arm_r", "hand_r": "arm_r", "leg_l": "leg_l", "foot_l": "leg_l", "leg_r": "leg_r", "foot_r": "leg_r"}
LABEL = {"head": "HEAD", "torso": "TORSO", "arm_l": "L ARM", "arm_r": "R ARM", "leg_l": "L LEG", "leg_r": "R LEG"}
out = []

# 1. implant armor: stock implants get armor from their size (as before); the Trilobit implants carry their own values
def protec(b):
    res = []
    for part, n in b.get("occupied_bodyparts") or []:
        res.append([part, {"bash": min(16, 4 + n), "cut": min(16, 4 + n), "stab": min(16, 4 + n), "bullet": min(24, 6 + 2 * n)}])
    return res
for bid in sorted(STOCK):
    if bid in own or bid in LD.IMPL:
        continue
    p = protec(bs[bid])
    if p:
        out.append({"type": "bionic", "id": bid, "copy-from": bid, "protec": p})

# 2. recount: points used per main part, quality, implant max/current integrity
rc = []
for p in PARTS:
    rc += [{"math": [f"u_trl_used_{p}", "=", "0"]}, {"math": [f"u_trl_qw_{p}", "=", "0"]}]
for bid, b in sorted(bs.items()):
    per = {}
    for part, n in b.get("occupied_bodyparts") or []:
        if part in MAIN:
            per[MAIN[part]] = per.get(MAIN[part], 0) + n
    q = Q.get(bid, 0.7)
    for p, n in per.items():
        rc.append({"if": {"u_has_bionics": bid}, "then": [{"math": [f"u_trl_used_{p}", "+=", str(n)]}, {"math": [f"u_trl_qw_{p}", "+=", str(round(n * q, 3))]}]})
for p in PARTS:
    rc += [
        {"math": [f"u_trl_free_{p}", "=", f"max(0, {CAP[p]} - u_trl_used_{p})"]},
        {"math": [f"u_trl_s_{p}", "=", f"min(1, u_trl_used_{p} / {CAP[p]})"]},
        {"math": [f"u_trl_q_{p}", "=", f"u_trl_qw_{p} / max(u_trl_used_{p}, 1)"]},
        {"math": [f"u_trl_eff_{p}", "=", f"u_trl_s_{p} * u_trl_q_{p}"]},
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

# 3. damage routing: the implant share (points used / space, times quality) of each hit goes to the implants' integrity
dm = []
for p in PARTS:
    dm.append({"if": {"compare_string": [p, {"context_val": "bodypart"}]}, "then": [
        {"math": ["_a", "=", f"min(u_trl_ihp_{p}, _damage * u_trl_eff_{p})"]},
        {"math": [f"u_trl_ihp_{p}", "-=", "_a"]},
        {"math": [f"u_hp('{p}')", "=", f"min(u_hp('{p}') + _a, u_hp_max('{p}'))"]},
        {"if": {"math": [f"u_trl_ihp_{p}", "<=", "0"]},
         "then": [{"if": {"math": [f"u_trl_imax_{p}", ">", "0"]},
                   "then": [{"u_message": f"Your {LABEL[p].lower()} implants are wrecked and need repair.", "type": "bad"}]}]},
    ]})
dm.append({"run_eocs": ["trl_cyber_bars"]})
out.append({"type": "effect_on_condition", "id": "trl_cyber_on_damage", "eoc_type": "EVENT",
            "required_event": "character_takes_damage", "effect": dm})

# 4. bars: at most six |, colour by how much of the part is implant (green natural -> grey fully cyberized)
COLORS = ["light_green", "light_cyan", "cyan", "light_blue", "light_gray"]
bars = []
for p in PARTS:
    bars += [
        {"math": [f"u_trl_f_{p}", "=", f"(u_hp('{p}') + u_trl_ihp_{p}) / max(u_hp_max('{p}') + u_trl_imax_{p}, 1)"]},
        {"math": [f"u_trl_bn_{p}", "=", f"clamp(ceil(6 * u_trl_f_{p} - 0.001), 0, 6)"]},
    ]
    for k in range(7):
        bars.append({"if": {"math": [f"u_trl_bn_{p}", "==", str(k)]},
                     "then": [{"set_string_var": "|" * k if k else " ", "target_var": {"u_val": f"trl_barn_{p}"}}]})
    conds = [f"u_trl_s_{p} <= 0", f"u_trl_s_{p} < 0.34", f"u_trl_s_{p} < 0.67", f"u_trl_s_{p} < 0.999", f"u_trl_s_{p} >= 0.999"]
    for c, col in zip(conds, COLORS):
        bars.append({"if": {"math": [c]}, "then": [{"set_string_var": f"<color_{col}>", "target_var": {"u_val": f"trl_barc_{p}"}}]})
out.append({"type": "effect_on_condition", "id": "trl_cyber_bars", "effect": bars})

# 5. a fully cyberized part (every point used) never heals by itself: only an implant shop can repair it
lock = []
for p in PARTS:
    lock.append({"if": {"math": [f"u_trl_s_{p} >= 0.999"]},
                 "then": [{"if": {"math": [f"u_trl_lock_{p} == 0"]},
                           "then": [{"math": [f"u_trl_lock_{p}", "=", "1"]}, {"math": [f"u_trl_last_{p}", "=", f"u_hp('{p}')"]},
                                    {"u_message": f"Your {LABEL[p].lower()} is fully cyberized: it no longer heals on its own.  Only an implant shop can repair it.", "type": "info"}],
                           "else": [{"if": {"math": [f"u_hp('{p}') > u_trl_last_{p}"]}, "then": [{"math": [f"u_hp('{p}')", "=", f"u_trl_last_{p}"]}],
                                     "else": [{"math": [f"u_trl_last_{p}", "=", f"u_hp('{p}')"]}]}]}],
                 "else": [{"math": [f"u_trl_lock_{p}", "=", "0"]}]})
lock.append({"run_eocs": ["trl_cyber_bars"]})
out.append({"type": "effect_on_condition", "id": "trl_cyber_tick", "recurrence": "1 seconds", "global": True,
            "condition": {"math": ["1", "==", "1"]}, "effect": lock})

# 6. widgets overriding the stock HP bars
for wid, p in (("head", "head"), ("torso", "torso"), ("left_arm", "arm_l"), ("right_arm", "arm_r"), ("left_leg", "leg_l"), ("right_leg", "leg_r")):
    for suffix, flags in (("", []), ("_no_label", ["W_LABEL_NONE", "W_NO_PADDING"])):
        w = {"id": f"hp_{wid}_graph{suffix}", "type": "widget", "style": "text", "label": LABEL[p],
             "clauses": [{"id": "bar", "text": f"<u_val:trl_barc_{p}><u_val:trl_barn_{p}></color>", "parse_tags": True}]}
        if flags: w["flags"] = flags
        out.append(w)
json.dump(out, open(os.path.join(MOD, "cyber.json"), "w"), indent=1)
print(len(out), "entries")
