#!/usr/bin/env python3
"""The Net (Milestone 17, section D), version 1: jack in at a terminal, arrive in a neon room at the reserved level z = -10
directly below you, hack data nodes for yen, leave through the exit.  Built with the portal-storm method (map update + teleport).
usage: gen_net.py <mod dir> -> <mod>/net.json
"""
import json, os, random, sys
MOD = sys.argv[1]
out = []
def add(o): out.append(o)

# ---- terrain & furniture (neon green, teal, pink)
def ter(id, name, desc, sym, color, light=0, flags=None, base="t_floor"):
    o = {"type": "terrain", "id": id, "name": name, "description": desc, "symbol": sym, "color": color, "move_cost": 2,
         "flags": flags or ["TRANSPARENT", "FLAT", "INDOORS", "NO_FLOOR"] if False else (flags or ["TRANSPARENT", "FLAT", "INDOORS"]), "copy-from": base}
    o["move_cost"] = 2
    if light: o["light_emitted"] = light
    return o
add(ter("t_trl_net_floor", "data plane", "A dark plane scored with thin green grid lines.", ".", "green", 2))
add(ter("t_trl_net_line", "grid line", "A glowing teal line running across the plane.", ".", "cyan", 5))
add(ter("t_trl_net_pink", "signal pad", "A pad of pulsing pink light.", ".", "pink", 6))
w = ter("t_trl_net_wall", "firewall", "A translucent wall of teal light that hums when you touch it.", "#", "light_cyan", 7, flags=["NOITEM", "WALL", "INDOORS"], base="t_concrete_wall")
w["move_cost"] = 0
add(w)
def fur(id, name, desc, sym, color, light, examine=None, flags=None):
    o = {"type": "furniture", "id": id, "name": name, "description": desc, "symbol": sym, "color": color, "move_cost_mod": -1,
         "coverage": 30, "required_str": -1, "light_emitted": light, "flags": flags or ["TRANSPARENT", "NOITEM"],
         "bash": {"str_min": 40, "str_max": 100, "sound": "crack.", "sound_fail": "thud."}}
    if examine: o["examine_action"] = {"type": "effect_on_condition", "effect_on_conditions": [examine]}
    return o
add(fur("f_trl_net_node", "data node", "A faceted green crystal of stored data, humming softly.  Examine it to crack it for yen.", "*", "light_green", 6, "trl_net_node_hack"))
add(fur("f_trl_net_exit", "exit gate", "A ring of pink light that leads back to your body.  Examine it to log out.", "O", "pink", 9, "trl_net_exit"))
add(fur("f_trl_jack", "net jack terminal", "A matte-black terminal with a neural jack on a coiled lead.  Examine it to log in to the Net (needs a cyberbrain).",
        "J", "light_green", 6, "trl_net_jack_in", ["TRANSPARENT", "FLAT_SURF", "CONTAINER", "NOITEM", "SEALED"]))

# ---- the room: 24x24 update mapgen on the reserved level
R = random.Random(17)
G = [["a"] * 24 for _ in range(24)]            # a: floor
for i in range(24):
    G[0][i] = G[23][i] = G[i][0] = G[i][23] = "W"
for k in (6, 12, 18):
    for i in range(1, 23):
        if G[k][i] == "a": G[k][i] = "l"
        if G[i][k] == "a": G[i][k] = "l"
for x, y in ((12, 12), (11, 12), (13, 12), (12, 11), (12, 13)):
    G[y][x] = "p"
nodes = [(3, 3), (20, 3), (3, 20), (20, 20), (9, 9), (15, 15), (9, 15), (15, 9)]
rows = ["".join(r) for r in G]
add({"type": "mapgen", "update_mapgen_id": "trl_net_room",
     "object": {"flags": ["ERASE_ALL_BEFORE_PLACING_TERRAIN", "NO_UNDERLYING_ROTATE", "AVOID_CREATURES"],
                "rows": rows,
                "terrain": {"a": "t_trl_net_floor", "l": "t_trl_net_line", "p": "t_trl_net_pink", "W": "t_trl_net_wall"},
                "place_furniture": [{"furn": "f_trl_net_node", "x": x, "y": y} for x, y in nodes] + [{"furn": "f_trl_net_exit", "x": 12, "y": 10}],
                "set": [{"point": "variable", "id": "trl_net_start", "x": 12, "y": 12}]}})

# ---- EOCs
add({"type": "effect_on_condition", "id": "trl_net_jack_in",
     "effect": [{"if": {"u_has_flag": "MACHINE_BRAIN"}, "then": [{"run_eocs": ["trl_net_jack_in2"]}],
                 "else": [{"u_message": "You need a cyberbrain to log in.", "type": "bad"}]}]})
add({"type": "effect_on_condition", "id": "trl_net_jack_in2",
     "effect": [{"u_location_variable": {"global_val": "trl_net_return"}},
                {"u_location_variable": {"global_val": "trl_net_loc"}, "z_adjust": -10, "z_override": True},
                {"mapgen_update": "trl_net_room", "target_var": {"global_val": "trl_net_loc"}},
                {"u_teleport": {"global_val": "trl_net_start"}, "fail_message": "The login fails; the Net is closed to you."},
                {"u_message": "[Net] Your senses wash out into green and teal light.  You are logged in.", "type": "good"}]})
add({"type": "effect_on_condition", "id": "trl_net_exit",
     "effect": [{"u_teleport": {"global_val": "trl_net_return"}, "fail_message": "The gate will not open."},
                {"u_message": "[Net] The light drains away and you are back in your body.", "type": "info"}]})
add({"type": "effect_on_condition", "id": "trl_net_node_hack",
     "effect": [{"if": {"math": ["time('now') >= trl_net_node_ready"]}, "then": [{"run_eocs": ["trl_net_node_hack2"]}],
                 "else": [{"u_message": "[Net] The node is still cooling down.", "type": "info"}]}]})
add({"type": "effect_on_condition", "id": "trl_net_node_hack2",
     "effect": [{"math": ["u_net_gain = 150 + (u_skill('computer') + 1) * (50 + rand(100))"]},
                {"math": ["trl_bank += u_net_gain"]},
                {"math": ["trl_net_node_ready = time('now') + time('10 m')"]},
                {"u_message": "[Net] You crack the node: <u_val:net_gain> yen credited.  Balance: <global_val:trl_bank> yen.", "type": "good"}]})
add({"type": "effect_on_condition", "id": "trl_net_init", "effect": [{"math": ["trl_net_node_ready = 0"]}]})
json.dump(out, open(os.path.join(MOD, "net.json"), "w"), indent=1)
print(len(out), "net entries")
