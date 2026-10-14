#!/usr/bin/env python3
"""Group AI data (Milestone 23, AI steps F3, F8, F9, F12, F13).  The behaviour is C++ (src/trl_aware.cpp):
  F3  group alarms     - a creature that starts hunting shouts; same-faction aware monsters within 14 tiles come to look
  F12 morale / retreat - an aware monster under 25% hp breaks and runs
  F8  disguise         - wearing a faction uniform (flags below) slows that faction's guards to notice you beyond two tiles
This file supplies the data: the disguise flags and uniform items, the hostile hacker and its drone, and the summon spell.
usage: gen_groupai.py <mod dir> -> <mod>/groupai.json"""
import json, os, sys
MOD = sys.argv[1]
out = []
for fac in ("BRATVA", "NAP", "NASIM"):
    out.append({"type": "json_flag", "id": "TRL_DISGUISE_" + fac, "//": f"Worn: {fac.title()} guards take you for one of their own."})
UNI = [("trl_bratva_coat", "trenchcoat_leather", "Bratva long coat", "A black leather long coat with a small red stitched mark inside the collar.  Bratva guards will not look twice at you from a distance.", "BRATVA", 600),
       ("trl_nap_jacket", "leather_police_jacket", "NAP patrol jacket", "A navy patrol jacket with the NAP badge.  Their guards take you for staff unless you stand close.", "NAP", 900),
       ("trl_nasim_hoodie", "hoodie", "Nasim signal hoodie", "A grey hoodie with a faint blue thread in the seams.  Nasim lookouts wave you through.", "NASIM", 400)]
for i, base, name, desc, fac, price in UNI:
    out.append({"type": "ITEM", "subtypes": ["ARMOR"], "id": i, "copy-from": base, "looks_like": base, "name": {"str": name}, "description": desc,
                "price": f"{price} USD", "extend": {"flags": ["TRL_DISGUISE_" + fac]}})
# F9/F13: the enemy hacker and its drone
out.append({"type": "MONSTER", "id": "mon_trl_drone", "copy-from": "mon_manhack", "name": {"str": "hunter drone"},
            "description": "A small armed quadcopter that darts in, cuts and backs off.  It belongs to whoever launched it.",
            "categories": ["TRILOBIT"], "hp": 22, "color": "light_cyan", "default_faction": "mech_bot"})
out.append({"type": "SPELL", "id": "trl_deploy_drones", "name": {"str": "Deploy drones"}, "description": {"str": "Launches two hunter drones."},
            "flags": ["HOSTILE_SUMMON", "PERMANENT", "NO_EXPLOSION_SFX"], "valid_targets": ["ground", "self"], "max_level": 1,
            "min_damage": 2, "max_damage": 2, "min_range": 0, "max_range": 0, "min_aoe": 2, "max_aoe": 2, "base_casting_time": 3,
            "shape": "blast", "effect": "summon", "effect_str": "mon_trl_drone"})
out.append({"type": "MONSTER", "id": "mon_trl_hacker", "copy-from": "mon_trl_thug", "name": {"str": "hostile script-hacker"},
            "description": "A hunched figure with a deck on their forearm and a drone case on their back.  They stay behind cover, launch drones, and run when hurt.",
            "color": "light_cyan", "diff": 7, "hp": 45, "speed": 100, "melee_damage": [{"damage_type": "bash", "amount": 3}],
            "extend": {"flags": ["TRL_ALERT_AWARE"]},
            "special_attacks": [{"type": "spell", "spell_data": {"id": "trl_deploy_drones", "hit_self": True}, "cooldown": 40,
                                 "monster_message": "The %s taps a command and launches drones!"}]})
json.dump(out, open(os.path.join(MOD, "groupai.json"), "w"), indent=1)
print(len(out), "objects")
