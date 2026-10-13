#!/usr/bin/env python3
"""Ghost transfer (section D): when a character with a cyberbrain dies and has a follower (an owned android is the usual shell),
offer to move the ghost into that body.  Carries over half of each skill (rounded down), installed nanohacks (suspended until
they fit the new Control Value limit), bank and faction ranks (world variables).  Replaces the stock EOC_DEATH_SWITCH.
usage: gen_ghost.py <mod dir>
"""
import json, os, sys
MOD = sys.argv[1]
SKILLS = ["speech", "computer", "firstaid", "mechanics", "traps", "driving", "swimming", "fabrication", "cooking", "tailor", "survival", "electronics",
          "archery", "gun", "launcher", "pistol", "rifle", "shotgun", "smg", "throw", "melee", "bashing", "cutting", "dodge", "stabbing", "unarmed",
          "chemistry", "weapon"]
nh = json.load(open(os.path.join(MOD, "nanohacks.json")))
SIDS = [o["id"][len("trl_nh_"):] for o in nh if o.get("type") == "mutation" and o["id"].startswith("trl_nh_") and "spells_learned" in o]
out = [{"type": "mutation", "id": "trl_ghost_left", "name": {"str": "Abandoned shell"}, "description": "This body was left behind when its ghost jumped.",
        "points": 0, "visibility": 0, "ugliness": 0, "valid": False, "purifiable": False, "player_display": False}]
save = [{"math": [f"trl_gh_s_{s}", "=", f"floor(u_skill('{s}') / 2)"]} for s in SKILLS]
for x in SIDS:
    save.append({"math": [f"trl_gh_n_{x}", "=", "0"]})
    save.append({"if": {"or": [{"u_has_trait": "trl_nh_" + x}, {"u_has_trait": "trl_nhq_" + x}]}, "then": [{"math": [f"trl_gh_n_{x}", "=", "1"]}]})
out.append({"type": "effect_on_condition", "id": "EOC_DEATH_SWITCH", "eoc_type": "AVATAR_DEATH",
            "condition": {"and": [{"u_has_flag": "MACHINE_BRAIN"}, {"npc_allies_global": 1},
                                  {"u_query": "Your body has died.  Jump your ghost into one of your shells?", "default": True}]},
            "effect": save + [{"u_add_trait": "trl_ghost_left"}, {"math": ["trl_gh_pending", "=", "1"]}, "take_control_menu"]})
apply = [{"math": ["trl_gh_pending", "=", "0"]}]
apply += [{"math": [f"u_skill('{s}')", "=", f"max(u_skill('{s}'), trl_gh_s_{s})"]} for s in SKILLS]
apply += [{"if": {"not": {"u_has_flag": "MACHINE_BRAIN"}}, "then": [{"u_add_bionic": "trl_bio_cyberbrain"}]},
          {"math": ["u_nh_seq", "=", "1"]}, {"u_spawn_item": "trl_nh_console"}]
for x in SIDS:
    apply.append({"if": {"math": [f"trl_gh_n_{x} == 1"]},
                  "then": [{"u_add_trait": "trl_nhq_" + x}, {"math": [f"u_nh_ord_{x}", "=", "u_nh_seq"]}, {"math": ["u_nh_seq", "+=", "1"]}]})
apply += [{"run_eocs": ["trl_nh_recalc"]},
          {"u_message": "[Trilobit] Your ghost settles into the new shell.  Skills are halved, installed nanohacks wake as far as this cyberbrain allows.", "type": "good"}]
out.append({"type": "effect_on_condition", "id": "trl_gh_apply", "eoc_type": "RECURRING", "recurrence": ["1 seconds", "1 seconds"], "global": True,
            "condition": {"and": [{"math": ["trl_gh_pending == 1"]}, {"not": {"u_has_trait": "trl_ghost_left"}}]}, "effect": apply})
json.dump(out, open(os.path.join(MOD, "ghost.json"), "w"), indent=1)
print("ghost ok", len(SIDS), "nanohacks")
