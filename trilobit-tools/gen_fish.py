#!/usr/bin/env python3
"""Fish, aquariums and pets for sale (design doc section M3 / M11).
  - 24 exotic fish of the West Pacific as live-fish items (flag TRL_FISH), sold by the pet store.
  - Portable tanks (bowl 1 fish, cube 2, long 3): CONTAINER pockets that accept only TRL_FISH items; use one to watch the fish.
  - Display aquariums as furniture: six 1-tile and six 2-tile (left and right halves) themed tanks, each with 1 to 3 fish;
    nested mapgens trl_tank_1 / trl_tank_2 pick a theme at random so each building gets a different tank.
  - Pet tickets (dog, cat, rabbit): use one and the animal appears beside you, tame.
usage: gen_fish.py <mod dir> -> <mod>/fish.json"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
MOD = sys.argv[1]

from gen_fish_data import *


def join(names):
    names = list(names)
    return names[0] if len(names) == 1 else ", ".join(names[:-1]) + " and " + names[-1]


out = [{"type": "json_flag", "id": "TRL_FISH", "info": "This is a live fish, kept in water.  Put it in an aquarium."}]
# ---------------------------------------------------------------- fish items
for fid, nm, latin, col, price, desc in FISH:
    out.append({"type": "ITEM", "subtypes": ["GENERIC"], "id": f"trl_fish_{fid}", "category": "other",
                "name": {"str": nm}, "description": f"{desc}  ({latin}, bagged in clean water.)  A live fish: put it in an aquarium.",
                "weight": "80 g", "volume": "250 ml", "price": f"{price} USD", "price_postapoc": f"{price} USD", "symbol": ";", "color": col,
                "material": ["water"], "flags": ["TRL_FISH", "TRADER_AVOID"]})
# ---------------------------------------------------------------- portable tanks
for tid, nm, cap, price, vol, desc in TANKS:
    out.append({"type": "ITEM", "subtypes": ["GENERIC"], "id": f"trl_tank_{tid}", "category": "tools", "name": {"str": nm},
                "description": desc + "  Use it to watch the fish for a while; it calms the mind.",
                "weight": f"{600 * cap} g", "volume": vol, "longest_side": "30 cm", "price": f"{price} USD", "price_postapoc": f"{price} USD",
                "symbol": "A", "color": "light_cyan", "material": ["glass"], "flags": ["TRADER_AVOID"],
                "pocket_data": [{"pocket_type": "CONTAINER", "description": "The water.", "max_contains_volume": f"{250 * cap} ml",
                                 "max_contains_weight": f"{100 * cap} g", "watertight": True, "flag_restriction": ["TRL_FISH"], "moves": 100}],
                "use_action": {"type": "effect_on_conditions", "menu_text": "Watch the fish", "description": "Watch the fish swim for a while.",
                               "effect_on_conditions": ["trl_tank_watch_item"]}})
out.append({"type": "effect_on_condition", "id": "trl_tank_watch_item", "effect": [
    {"u_message": "You settle down and watch the fish drift and turn.  The slow light on the water is calming.", "type": "good"},
    {"u_add_morale": "morale_feeling_good", "bonus": 3, "max_bonus": 6, "duration": "2 hours", "decay_start": "30 minutes"}]})

# ---------------------------------------------------------------- display aquariums (furniture)
def tank_eoc(eid, name, fish):
    names = join(NAME[f] for f in fish)
    return {"type": "effect_on_condition", "id": eid, "effect": [
        {"u_message": f"You stop at the {name}.  Inside: {names}.  You watch them drift through the glowing water for a while.", "type": "good"},
        {"u_add_morale": "morale_feeling_good", "bonus": 3, "max_bonus": 6, "duration": "2 hours", "decay_start": "30 minutes"}]}


def tank_furn(fid, name, desc, color, eoc, sym):
    return {"type": "furniture", "id": fid, "name": name, "description": desc, "symbol": sym, "color": color, "move_cost_mod": -1, "coverage": 40,
            "required_str": -1, "light_emitted": 9, "flags": ["TRANSPARENT"], "examine_action": {"type": "effect_on_condition", "effect_on_conditions": [eoc]},
            "bash": {"str_min": 6, "str_max": 30, "sound": "glass breaking!", "sound_fail": "whump."}}


for tid, nm, fish in SMALL:
    eoc = f"trl_tank_watch_s_{tid}"
    out.append(tank_eoc(eoc, nm, fish))
    out.append(tank_furn(f"f_trl_tank_s_{tid}", nm, f"A glowing glass tank on a lacquered stand.  Inside: {join(NAME[f] for f in fish)}.  Examine it to watch the fish.", "light_cyan", eoc, "A"))
for tid, nm, fish in WIDE:
    eoc = f"trl_tank_watch_w_{tid}"
    out.append(tank_eoc(eoc, nm, fish))
    for half in ("l", "r"):
        out.append(tank_furn(f"f_trl_tank_w_{tid}_{half}", nm, f"A long glass aquarium that spans two tiles, lit from above.  Inside: {join(NAME[f] for f in fish)}.  Examine it to watch the fish.",
                             "light_cyan" if half == "l" else "light_blue", eoc, "A" if half == "l" else "B"))
# nested mapgens: pick a theme at random.  The 2-tile tank is a 2x1 object, so both halves always match.
for tid, nm, fish in SMALL:
    out.append({"type": "mapgen", "nested_mapgen_id": f"trl_tank_s_{tid}",
                "object": {"mapgensize": [1, 1], "rows": ["A"], "furniture": {"A": f"f_trl_tank_s_{tid}"}}})
for tid, nm, fish in WIDE:
    out.append({"type": "mapgen", "nested_mapgen_id": f"trl_tank_w_{tid}",
                "object": {"mapgensize": [2, 2], "rows": ["AB", ".."], "furniture": {"A": f"f_trl_tank_w_{tid}_l", "B": f"f_trl_tank_w_{tid}_r"}}})
out.append({"type": "mapgen", "nested_mapgen_id": "trl_tank_1",
            "object": {"mapgensize": [1, 1], "rows": ["."], "place_nested": [{"chunks": [[f"trl_tank_s_{t[0]}", 10] for t in SMALL], "x": 0, "y": 0}]}})
out.append({"type": "mapgen", "nested_mapgen_id": "trl_tank_2",
            "object": {"mapgensize": [2, 2], "rows": ["..", ".."], "place_nested": [{"chunks": [[f"trl_tank_w_{t[0]}", 10] for t in WIDE], "x": 0, "y": 0}]}})

# ---------------------------------------------------------------- pets for sale: a tame animal appears beside you
out.append({"type": "MONSTER", "id": "mon_trl_rabbit", "copy-from": "mon_rabbit", "name": {"str": "house rabbit"},
            "description": "A soft, well-fed pet rabbit that nibbles at whatever you hold out and tolerates being patted.",
            "categories": ["TRILOBIT"], "aggression": -99, "morale": 40, "anger_triggers": ["HURT"], "fear_triggers": ["FRIEND_ATTACKED"],
            "placate_triggers": ["PLAYER_CLOSE", "PLAYER_WEAK"], "color": "white"})
for pid, mon, nm, price, desc, col in PETS:
    out.append({"type": "ITEM", "subtypes": ["GENERIC"], "id": f"trl_pet_{pid}", "category": "other",
                "name": {"str": f"adoption ticket ({nm})", "str_pl": f"adoption tickets ({nm})"},
                "description": desc + "  A sealed adoption ticket: use it where there is room and the animal is brought out to you.",
                "weight": "5 g", "volume": "5 ml", "symbol": "?", "color": col, "material": ["paper"], "price": f"{price} USD", "price_postapoc": f"{price} USD",
                "flags": ["TRADER_AVOID"],
                "use_action": {"type": "effect_on_conditions", "menu_text": f"Take the {nm} home", "description": f"The {nm} is brought out to you.",
                               "effect_on_conditions": [f"trl_pet_use_{pid}"]}})
    out.append({"type": "effect_on_condition", "id": f"trl_pet_use_{pid}", "effect": [
        {"u_spawn_monster": mon, "real_count": 1, "min_radius": 1, "max_radius": 2, "friendly": True,
         "spawn_message": f"A pet-shop attendant brings a {nm} out and sets it down beside you.  It sniffs at you, then settles in."}]})

json.dump(out, open(os.path.join(MOD, "fish.json"), "w"), indent=1)
print("fish:", len(FISH), "tanks:", len(TANKS), "display themes:", len(SMALL) + len(WIDE), "pets:", len(PETS))
