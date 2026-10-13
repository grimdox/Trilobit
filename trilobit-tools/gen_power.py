#!/usr/bin/env python3
"""Power charging posts (design doc section M): pay yen to refill bionic power.  One post stands outside every hospital and every
service shop, in three price tiers (poor, middle, rich).  usage: gen_power.py <mod dir> -> <mod>/power.json"""
import json, os, sys
MOD = sys.argv[1]
MULT = {"p": 0.8, "m": 1.0, "r": 1.5}
STEPS = [(25, 200), (50, 380), (100, 700)]      # percent of full charge, base yen
out = []
for t, mult in MULT.items():
    for pct, base in STEPS:
        cost = int(round(base * mult, -1))
        eid = f"trl_rc_{t}_{pct}"
        out.append({"type": "effect_on_condition", "id": eid, "effect": [
            {"if": {"math": ["u_val('power_max')", "<=", "0"]},
             "then": [{"u_message": "You have no bionic power storage to charge.", "type": "info"}],
             "else": [{"if": {"math": ["u_item_count('trl_yen')", "<", str(cost)]},
                       "then": [{"u_message": f"The post wants {cost} yen.", "type": "bad"}],
                       "else": [{"u_consume_item": "trl_yen", "count": cost},
                                {"math": ["u_val('power')", "=", f"min(u_val('power') + u_val('power_max') * {pct} / 100, u_val('power_max'))"]},
                                {"u_message": "The post hums.  Your implants drink the charge." if pct < 100 else "The post hums, rises to a whine, and your power is full.",
                                 "type": "good"}]}]}]})
    sel = {"type": "effect_on_condition", "id": f"trl_rc_menu_{t}",
           "effect": [{"run_eoc_selector": [f"trl_rc_{t}_{p}" for p, _ in STEPS] + ["trl_rc_gauge"],
                       "names": [("Full charge" if p == 100 else f"Charge +{p}%") + f" ({int(round(b * mult, -1))} yen)" for p, b in STEPS] + ["Check your charge"],
                       "keys": ["a", "b", "c", "d"], "title": "Power charging post (yen)", "hide_failing": False}]}
    out.append(sel)
    out.append({"type": "furniture", "id": f"f_trl_recharge_{t}", "name": "power charging post",
                "description": "A sealed post with a glowing coin slot and a thick, shielded cable.  Examine it to pay yen and refill your bionic power.",
                "symbol": "P", "color": {"p": "brown", "m": "light_cyan", "r": "light_green"}[t], "move_cost_mod": -1, "coverage": 40,
                "required_str": -1, "light_emitted": 10, "flags": ["TRANSPARENT", "NOITEM", "SEALED"],
                "examine_action": {"type": "effect_on_condition", "effect_on_conditions": [f"trl_rc_menu_{t}"]},
                "bash": {"str_min": 12, "str_max": 40, "sound": "smash!", "sound_fail": "thump."}})
out.append({"type": "effect_on_condition", "id": "trl_rc_gauge", "effect": [
    {"math": ["_pct", "=", "round(100 * u_val('power') / max(u_val('power_max'), 1))"]},
    {"u_message": "Your bionic power is at <context_val:pct>%.", "type": "info"}]})
json.dump(out, open(os.path.join(MOD, "power.json"), "w"), indent=1)
print("charging posts:", len(MULT))
