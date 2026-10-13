#!/usr/bin/env python3
"""Food (design doc section L): 50 Japanese, Russian and Chinese dishes and drinks, and cyber rations that only a cyberstomach can use.
usage: gen_food.py <mod dir>  -> <mod>/food.json"""
import json, os, sys
import fooddata as FD
MOD = sys.argv[1]
out = []
for fid, name, cul, kind, kcal, quench, fun, wt, vol, price, tier, spoils, hot, desc, color in FD.F:
    o = {"type": "ITEM", "subtypes": ["COMESTIBLE"], "id": f"trl_f_{fid}", "name": {"str_sp": name}, "weight": f"{wt} g", "volume": f"{vol} ml",
         "color": color, "comestible_type": kind, "symbol": "~" if kind == "DRINK" else "%", "calories": kcal, "quench": quench, "fun": fun,
         "description": desc, "price": f"{price} USD", "price_postapoc": f"{price} USD", "spoils_in": spoils, "material": ["veggy"],
         "flags": (["EATEN_HOT"] if hot else ["EATEN_COLD"]) + (["NO_AUTO_CONSUME"] if kind == "DRINK" else []), "healthy": 1 if tier == 2 else 0}
    if kind == "DRINK":
        o.update({"phase": "liquid", "charges": 1, "container": "bottle_plastic"})
        o["material"] = ["water"]
    out.append(o)

# ---- cyber rations (tool items; using one needs a cyberstomach)
for cid, name, kcal, quench, morale, power, stam, price, desc in FD.CYBER:
    eid = f"trl_cf_eat_{cid}"
    out.append({"type": "ITEM", "subtypes": ["GENERIC"], "id": f"trl_cf_{cid}", "name": {"str": name}, "weight": "200 g", "volume": "200 ml",
                "color": "light_cyan", "symbol": "%", "material": ["plastic"],
                "description": desc + f"  Needs a cyberstomach: it gives {kcal} kcal" + (f", quenches {quench}" if quench else "") + f" and charges {power} kJ of bionic power.",
                "price": f"{price} USD", "price_postapoc": f"{price} USD",
                "use_action": {"type": "effect_on_conditions", "menu_text": "Eat", "description": "Eat this cyber ration.", "effect_on_conditions": [eid]}})
    eff = [{"u_message": f"You swallow the {name}.  It is rich, complete and very, very good.", "type": "good"},
           {"math": ["u_calories()", "=", f"u_calories() + {kcal}"]}]
    if quench:
        eff.append({"math": ["u_val('thirst')", "=", f"max(u_val('thirst') - {quench}, -60)"]})
    if morale:
        eff.append({"u_add_morale": "morale_food_good", "bonus": morale, "max_bonus": morale * 2, "duration": "3 hours", "decay_start": "1 hours"})
    if power:
        eff.append({"math": ["u_val('power')", "=", f"min(u_val('power') + {power * 1000000}, u_val('power_max'))"]})
    if stam:
        eff.append({"math": ["u_val('stamina')", "=", f"min(u_val('stamina') + {stam * 10}, 10000)"]})
    out.append({"type": "effect_on_condition", "id": eid,
                "effect": [{"if": {"u_has_bionics": "trl_imp_stomach"}, "then": eff,
                            "else": [{"u_message": f"Your stomach cannot digest {name}: you need a cyberstomach.  It is back in your pack.", "type": "bad"},
                                     {"u_spawn_item": f"trl_cf_{cid}"}]}]})
json.dump(out, open(os.path.join(MOD, "food.json"), "w"), indent=1)
print(len(FD.F), "foods,", len(FD.CYBER), "cyber rations")
