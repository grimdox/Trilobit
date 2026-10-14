#!/usr/bin/env python3
"""Pets (design doc section M): tame house dogs and cats, coop chickens, and aquarium fish watching.
The stock animals are feral; these copies never attack unless hurt, are not scared of people, and are placed in homes by gen_presence.py.
usage: gen_pets.py <mod dir> -> <mod>/pets.json"""
import json, os, sys
MOD = sys.argv[1]
out = [
    {"type": "MONSTER", "id": "mon_trl_dog", "copy-from": "mon_dog", "name": {"str": "house dog"},
     "description": "A well-fed, collared dog that belongs to somebody.  It looks at you with friendly interest and waits to be patted.",
     "categories": ["TRILOBIT"], "aggression": -99, "morale": 40, "anger_triggers": ["HURT"], "fear_triggers": [],
     "placate_triggers": ["PLAYER_CLOSE", "PLAYER_WEAK"], "color": "brown", "death_drops": "mon_dog_death_drops"},
    {"type": "MONSTER", "id": "mon_trl_cat", "copy-from": "mon_cat", "name": {"str": "house cat"},
     "description": "A sleek, unbothered house cat.  It watches you with half-closed eyes and tolerates being fussed over.",
     "categories": ["TRILOBIT"], "aggression": -99, "morale": 40, "anger_triggers": ["HURT"], "fear_triggers": ["FRIEND_ATTACKED"],
     "placate_triggers": ["PLAYER_CLOSE", "PLAYER_WEAK"], "color": "light_gray"},
    {"type": "MONSTER", "id": "mon_trl_chicken", "copy-from": "mon_chicken", "name": {"str": "coop chicken"},
     "description": "A scruffy chicken that lives in the yard and scratches at the floor for scraps.",
     "categories": ["TRILOBIT"], "aggression": -99, "anger_triggers": [], "fear_triggers": ["FRIEND_ATTACKED"], "placate_triggers": ["PLAYER_CLOSE"],
     "color": "white"},
    {"type": "effect_on_condition", "id": "trl_fish_watch", "effect": [
        {"u_message": "You watch the fish drift through the glowing water: slow orange and blue shapes in endless, silent loops.  It is oddly calming.", "type": "good"},
        {"u_add_morale": "morale_feeling_good", "bonus": 3, "max_bonus": 6, "duration": "2 hours", "decay_start": "30 minutes"}]},
]
# nested one-tile mapgens that place a pet (gen_presence puts them in homes with a chance)
for kind, mon in (("dog", "mon_trl_dog"), ("cat", "mon_trl_cat"), ("chicken", "mon_trl_chicken")):
    out.append({"type": "mapgen", "nested_mapgen_id": f"trl_pres_pet_{kind}",
                "object": {"mapgensize": [1, 1], "rows": ["."], "place_monster": [{"monster": mon, "x": 0, "y": 0}]}})
json.dump(out, open(os.path.join(MOD, "pets.json"), "w"), indent=1)
print("pets: dog, cat, chicken; aquarium fish watching")
