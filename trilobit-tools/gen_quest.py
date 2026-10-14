#!/usr/bin/env python3
"""Generates yen.json and quest.json (the Runner NPC class used by the terminal jobs) for the Trilobit mod.
The Sachiko/Ryo starter quest chain was removed."""
import json, sys, os
TEST = os.environ.get("TRL_TEST") == "1"   # test build: chain completes immediately
out = sys.argv[1]
J = []

# ---------------------------------------------------------------- currency
J_yen = [{
    "type": "ITEM", "subtypes": ["GENERIC"], "id": "trl_yen",
    "category": "currency",
    "name": {"str_sp": "yen"},
    "description": "A single aluminium one-yen coin: the smallest physical unit of the city's currency. "
                   "Cash is still used for street vendors, back-alley deals and anywhere that does not want a record.",
    "price": "1 USD", "price_postapoc": "1 USD",
    "//": "Placeholder price. Real trade values will be set when the economy (Milestone 8) is built.",
    "weight": "1 g", "volume": "1 ml", "color": "light_gray", "symbol": "$",
    "material": ["aluminum"]
}]
from common import two_space as fix
json.dump(fix(J_yen), open(out + "/yen.json", "w"), indent=2)

# ---------------------------------------------------------------- NPC gear (Runner class, used by the terminal jobs)
def coll(i, items):
    return {"type": "item_group", "id": i, "subtype": "collection",
            "entries": [{"item": x, "prob": 100} for x in items]}
J += [coll("trl_mark_worn", ["tshirt", "pants_cargo", "boots", "jacket_leather"]),
      coll("trl_mark_weapon", ["knife_combat"]),
      {"type": "npc_class", "id": "trl_nc_mark", "name": {"str": "Runner"},
       "job_description": "I owe the wrong people.",
       "common": False, "worn_override": "trl_mark_worn", "weapon_override": "trl_mark_weapon",
       "skills": [{"skill": "ALL", "level": {"constant": 2}}, {"skill": "melee", "bonus": {"rng": [1, 2]}},
                  {"skill": "cutting", "bonus": {"rng": [1, 2]}}]}]
json.dump(fix(J), open(out + "/quest.json", "w"), indent=2)
print(len(J), "objects")
