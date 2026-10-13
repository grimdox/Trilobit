#!/usr/bin/env python3
"""Enemy awareness data: flags, the Alert-Aware trait, and the stealth enemy types.
The behaviour itself is C++ (src/trl_aware.cpp); this file only names things.
Usage: gen_awareness.py <mod dir>"""
import json, sys

mod = sys.argv[1] if len(sys.argv) > 1 else "data/mods/trilobit"

out = [
    {"type": "monster_flag", "id": "TRL_ALERT_AWARE",
     "//": "Notices the player gradually (meter), can lose track, searches the last known position, returns to post."},
    {"type": "json_flag", "id": "TRL_ALERT_AWARE", "//": "Same, for NPCs (via the trait trl_alert_aware)."},
    {"type": "json_flag", "id": "TRL_NONCOMBATANT", "//": "NPC runs from trouble instead of fighting."},
    {"type": "mutation", "id": "trl_alert_aware", "name": {"str": "Alert-Aware"}, "points": 0, "visibility": 0, "ugliness": 0,
     "description": "Hidden marker: this person notices you gradually, can lose track of you and goes looking.",
     "valid": False, "purifiable": False, "flags": ["TRL_ALERT_AWARE"]},
    {"type": "mutation", "id": "trl_noncombatant", "name": {"str": "Noncombatant"}, "points": 0, "visibility": 0, "ugliness": 0,
     "description": "Hidden marker: this person runs from trouble instead of fighting.",
     "valid": False, "purifiable": False, "flags": ["TRL_NONCOMBATANT"]},
    # --- stealth enemy types (step 5)
    {"type": "MONSTER", "id": "mon_trl_assassin", "copy-from": "mon_trl_thug",
     "name": {"str": "shade assassin"},
     "description": "A lean figure in a light-bending coat.  It lurks in the dark, does not shout, and does not miss twice.  Nearly invisible unless it is lit or next to you.",
     "color": "dark_gray", "diff": 7, "hp": 55, "speed": 125, "dodge": 6, "melee_skill": 7,
     "vision_day": 50, "vision_night": 40,
     "melee_damage": [{"damage_type": "cut", "amount": 14}],
     "extend": {"flags": ["TRL_ALERT_AWARE", "NIGHT_INVISIBILITY"]}},
    {"type": "MONSTER", "id": "mon_trl_sniper", "copy-from": "mon_trl_soldier",
     "name": {"str": "overwatch sniper"},
     "description": "A marksman in a ghillie-weave poncho, prone behind a long rifle.  Never moves from the nest; sees a long way and shoots once the aim is true.",
     "color": "brown", "diff": 8, "hp": 65, "speed": 100,
     "vision_day": 45, "vision_night": 18,
     "extend": {"flags": ["IMMOBILE", "TRL_ALERT_AWARE"]},
     "special_attacks": [
         {"type": "gun", "cooldown": 9, "move_cost": 100, "gun_type": "trl_soldier_rifle", "ammo_type": "556",
          "fake_skills": [["gun", 6], ["rifle", 8]], "fake_dex": 12, "fake_per": 15,
          "ranges": [[3, 40, "DEFAULT"]], "require_targeting_player": False,
          "description": "The sniper squeezes off a single, careful shot."}]},
]
with open(f"{mod}/awareness.json", "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
print("awareness.json:", len(out), "objects")
