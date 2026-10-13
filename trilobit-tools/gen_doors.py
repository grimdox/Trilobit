#!/usr/bin/env python3
"""Electronic security doors: terrain transforms, release panel, nanohack targets.  usage: gen_doors.py <mod dir> -> doors.json
Terrain (t_trl_elock_l sealed, _c unlocked, _o open) is defined in gen_places.py.
Door Override (open from range) and Door Seal (lock from range) are nanohacks in gen_nanohacks.py; android attendants lock and unlock
their shop by the hour (gen_androids.py)."""
import json, os, sys
MOD = sys.argv[1]
L, C, O = "t_trl_elock_l", "t_trl_elock_c", "t_trl_elock_o"
out = [
    {"type": "ter_furn_transform", "id": "trl_elock_override", "terrain": [{"result": O, "valid_terrain": [L, C]}]},
    {"type": "ter_furn_transform", "id": "trl_elock_unlock", "terrain": [{"result": C, "valid_terrain": [L]}]},
    {"type": "ter_furn_transform", "id": "trl_elock_seal", "terrain": [{"result": L, "valid_terrain": [C, O]}]},
    {"type": "furniture", "id": "f_trl_door_panel", "name": "door release panel",
     "description": "A wall panel with a red button and a status light.  It lets anyone inside open the security doors nearby.  Examine it to release the doors.",
     "symbol": "e", "color": "light_red", "move_cost_mod": -1, "coverage": 30, "required_str": -1, "light_emitted": 3,
     "flags": ["TRANSPARENT", "NOITEM", "SEALED"],
     "examine_action": {"type": "effect_on_condition", "effect_on_conditions": ["trl_panel_examine"]},
     "bash": {"str_min": 12, "str_max": 40, "sound": "smash!", "sound_fail": "thump."}},
    {"type": "effect_on_condition", "id": "trl_panel_examine",
     "effect": [{"u_transform_radius": 5, "ter_furn_transform": "trl_elock_override"},
                {"u_message": "[Trilobit] The panel chirps.  The security doors nearby slide open.", "type": "good"}]},
]
json.dump(out, open(os.path.join(MOD, "doors.json"), "w"), indent=1)
print("doors ok")
