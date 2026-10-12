#!/usr/bin/env python3
"""Generates yen.json and quest.json (first NPC + mission chain) for the Trilobit mod."""
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
import re
def fix(o):
    if isinstance(o, str): return re.sub(r'([.!?:]) (?=[A-Z"])', r'\1  ', o)
    if isinstance(o, list): return [fix(x) for x in o]
    if isinstance(o, dict): return {k: fix(v) for k, v in o.items()}
    return o
json.dump(fix(J_yen), open(out + "/yen.json", "w"), indent=2)

# ---------------------------------------------------------------- NPC gear
def coll(i, items):
    return {"type": "item_group", "id": i, "subtype": "collection",
            "entries": [{"item": x, "prob": 100} for x in items]}
J += [coll("trl_fixer_worn", ["tshirt", "pants_cargo", "boots", "jacket_leather"]),
      coll("trl_fixer_carry", ["cash_card"]),
      coll("trl_mark_worn", ["tshirt", "pants_cargo", "boots", "jacket_leather"]),
      coll("trl_mark_weapon", ["knife_combat"])]
SK = lambda n, lv: {"skill": n, "level": lv}
J += [
 {"type": "npc_class", "id": "trl_nc_fixer", "name": {"str": "Fixer"},
  "job_description": "I know a guy who knows a guy. Sometimes that guy needs to stop breathing.",
  "common": False, "worn_override": "trl_fixer_worn", "carry_override": "trl_fixer_carry",
  "skills": [{"skill": "ALL", "level": {"constant": 2}}, {"skill": "speech", "bonus": {"rng": [3, 5]}}]},
 {"type": "npc_class", "id": "trl_nc_mark", "name": {"str": "Runner"},
  "job_description": "I owe the wrong people.",
  "common": False, "worn_override": "trl_mark_worn", "weapon_override": "trl_mark_weapon",
  "skills": [{"skill": "ALL", "level": {"constant": 2}}, {"skill": "melee", "bonus": {"rng": [1, 2]}},
             {"skill": "cutting", "bonus": {"rng": [1, 2]}}]},
 {"type": "npc", "id": "trl_fixer", "name_unique": "Sachiko Imai", "class": "trl_nc_fixer",
  "gender": "female", "attitude": 0, "mission": 7, "chat": "TRL_FIXER_HUB", "faction": "no_faction"},
 {"type": "npc", "id": "trl_mark", "name_unique": "Ryo Kurogane", "class": "trl_nc_mark",
  "gender": "male", "attitude": 10, "mission": 0, "chat": "TALK_DONE", "faction": "no_faction",
  "death_eocs": ["trl_mark_death"]},
 {"type": "effect_on_condition", "id": "trl_mark_death", "eoc_type": "NPC_DEATH",
  "effect": [{"math": ["trl_mark_dead", "=", "1"]}]},
]

# ---------------------------------------------------------------- missions
def mission(i, name, desc, goal, start=None, end=None, cond=None, difficulty=1):
    m = {"type": "mission_definition", "id": i, "name": {"str": name}, "description": desc,
         "goal": goal, "difficulty": difficulty, "value": 0, "urgent": False,
         "origins": ["ORIGIN_GAME_START"]}
    if cond: m["goal_condition"] = cond
    if start: m["start"] = start
    if end: m["end"] = end
    return m

J += [
 mission("TRL_M1_FIND", "Find Ryo Kurogane (1/3)",
         "Sachiko Imai wants Ryo Kurogane dead. Go to the building she described and find him. "
         "Step 1 of 3: find the target. Step 2: kill him. Step 3: report back to Sachiko.",
         "MGOAL_CONDITION", cond={"math": ["distance('u', trl_target_loc) <= " + ("100000" if TEST else "9")]},
         start={"assign_mission_target": {"var": {"global_val": "trl_target_loc"}, "reveal_radius": 1}},
         end={"effect": [{"assign_mission": "TRL_M2_KILL"},
                         {"u_message": "You are close. Ryo Kurogane should be somewhere in here.", "type": "mixed"}]}),
 mission("TRL_M2_KILL", "Kill Ryo Kurogane (2/3)",
         "Ryo Kurogane is in this building. Kill him. Step 2 of 3.",
         "MGOAL_CONDITION", cond={"math": ["trl_mark_dead == 1"]}, difficulty=2,
         start={"assign_mission_target": {"var": {"global_val": "trl_target_loc"}}},
         end={"effect": [{"assign_mission": "TRL_M3_REPORT"},
                         {"u_message": "Ryo Kurogane is dead. Go back and tell Sachiko.", "type": "good"}]}),
 mission("TRL_M3_REPORT", "Report to Sachiko Imai (3/3)",
         "Return to Sachiko Imai and tell her it is done. She will pay you 1000 yen. Step 3 of 3.",
         "MGOAL_TALK_TO_NPC",
         start={"assign_mission_target": {"var": {"global_val": "trl_giver_loc"}}},
         end={"effect": [{"u_message": "Job finished.", "type": "good"}]}),
]

# ---------------------------------------------------------------- dialogue
J += [
 {"type": "talk_topic", "id": "TRL_FIXER_HUB",
  "dynamic_line": {"math": ["trl_quest_state == 0"],
    "yes": "Good, you're awake. Don't make that face; the walls here are thin and the neighbours talk. "
           "You look like someone who needs money, and I happen to need someone who doesn't ask questions.",
    "no": {"math": ["trl_quest_state == 1"],
      "yes": "Back already? Tell me you have news.",
      "no": "We're square. If I need something else done, I'll find you."}},
  "responses": [
    {"text": "What kind of work?", "topic": "TRL_FIXER_OFFER", "condition": {"math": ["trl_quest_state == 0"]}},
    {"text": "Remind me where he is.", "topic": "TRL_FIXER_REMIND", "condition": {"math": ["trl_quest_state == 1"]}},
    {"text": "It's done. Ryo Kurogane is dead.", "topic": "TRL_FIXER_PAY",
     "condition": {"and": [{"math": ["trl_quest_state == 1"]}, {"math": ["trl_mark_dead == 1"]}]}},
    {"text": "I'll be going.", "topic": "TALK_DONE"}]},
 {"type": "talk_topic", "id": "TRL_FIXER_OFFER",
  "dynamic_line": "A runner called Ryo Kurogane skimmed from the wrong people and now it's my name on the debt. "
                  "He's gone to ground <global_val:trl_target_dir>. Ground floor, probably, he likes the exits. "
                  "Find him, kill him, come back and tell me. I pay a thousand yen, cash.",
  "responses": [
    {"text": "A thousand yen. I'll do it.", "topic": "TRL_FIXER_ACCEPTED",
     "effect": [{"math": ["trl_quest_state", "=", "1"]}, {"assign_mission": "TRL_M1_FIND"}]},
    {"text": "Let me think about it.", "topic": "TALK_DONE"}]},
 {"type": "talk_topic", "id": "TRL_FIXER_ACCEPTED",
  "dynamic_line": "Good. Check your mission log if you lose track: three steps, find him, kill him, tell me. "
                  "He carries a blade and he is not stupid. Don't die; I don't pay the dead.",
  "responses": [{"text": "I'll be back.", "topic": "TALK_DONE"}]},
 {"type": "talk_topic", "id": "TRL_FIXER_REMIND",
  "dynamic_line": "Ryo Kurogane. He's holed up <global_val:trl_target_dir>. Find him, kill him, come back.",
  "responses": [{"text": "Right.", "topic": "TALK_DONE"}]},
 {"type": "talk_topic", "id": "TRL_FIXER_PAY",
  "dynamic_line": "Then that's the end of it. Here: one thousand yen, as agreed. Nice and untraceable.",
  "responses": [{"text": "Pleasure doing business.", "topic": "TALK_DONE",
    "effect": [{"u_spawn_item": "trl_yen", "count": 1000},
               {"finish_mission": "TRL_M3_REPORT", "success": True},
               {"math": ["trl_quest_state", "=", "2"]}]}]},
]

# ---------------------------------------------------------------- start: spawn NPCs
def blocks(n):
    return {1: "a block", 2: "two blocks"}[n]
def phrase(dx, dy):
    parts = []
    if dx: parts.append(f"{blocks(abs(dx))} {'east' if dx > 0 else 'west'}")
    if dy: parts.append(f"{blocks(abs(dy))} {'south' if dy > 0 else 'north'}")
    return " and ".join(parts) if parts else "somewhere in this same block"

offsets = [(dx, dy) for dx in range(-2, 3) for dy in range(-2, 3) if max(abs(dx), abs(dy)) in (1, 2)]
placed = {"math": ["trl_target_placed == 0"]}
eocs = []
names = []
def place_eoc(i, dx, dy, rnd):
    eid = f"trl_place_target_{'r' if rnd else 'f'}{i}"
    cond = {"and": [placed, {"math": ["rand(2) == 0"]}]} if rnd else placed
    eocs.append({
      "type": "effect_on_condition", "id": eid, "condition": cond,
      "effect": [
        {"u_location_variable": {"global_val": "trl_target_loc"},
         "target_params": {"offset_x": dx, "offset_y": dy, "z": 0},
         "x_adjust": 12, "y_adjust": 12, "z_adjust": 0, "z_override": True},
        {"u_spawn_npc": "trl_mark", "real_count": 1, "unique_id": "mission_target",
         "target_var": {"global_val": "trl_target_loc"},
         "min_radius": 0, "max_radius": 6, "indoor_only": True,
         "true_eocs": [{"id": eid + "_ok", "effect": [
             {"math": ["trl_target_placed", "=", "1"]},
             {"u_message": "[Trilobit] Mission target placed " + phrase(dx, dy) + ".", "type": "good"},
             {"set_string_var": phrase(dx, dy), "target_var": {"global_val": "trl_target_dir"}}]}]}]})
    names.append(eid)
for i, (dx, dy) in enumerate(offsets): place_eoc(i, dx, dy, True)
for i, (dx, dy) in enumerate(offsets): place_eoc(i, dx, dy, False)
J += eocs
# The quest giver must start inside the PC's own building. Each mid-rise is one overmap tile (24x24) per floor, so we pick
# tiles inside the PC's own overmap tile only: first close to the PC, then anywhere in the tile, indoors and on the PC's floor.
PX = "(u_val('pos_x') - 24 * floor(u_val('pos_x') / 24))"
PY = "(u_val('pos_y') - 24 * floor(u_val('pos_y') / 24))"
def giver(name, nxt, near):
    xa = {"math": [f"clamp({PX} + rand(12) - 6, 0, 23)"]} if near else {"math": ["rand(23)"]}
    ya = {"math": [f"clamp({PY} + rand(12) - 6, 0, 23)"]} if near else {"math": ["rand(23)"]}
    sp = {"u_spawn_npc": "trl_fixer", "real_count": 1, "unique_id": "quest_giver", "target_var": {"global_val": "trl_giver_spawn_loc"},
          "min_radius": 0, "max_radius": 0, "indoor_only": True}
    sp["true_eocs"] = ["trl_giver_ok"]
    sp["spawn_message"] = "Sachiko Imai is somewhere nearby in this building."
    sp["false_eocs"] = [nxt] if nxt else ["trl_giver_failed"]
    return {"type": "effect_on_condition", "id": name,
            "effect": [{"u_location_variable": {"global_val": "trl_giver_spawn_loc"}, "target_params": {"offset_x": 0, "offset_y": 0},
                        "x_adjust": xa, "y_adjust": ya}, sp]}
J += [{"type": "effect_on_condition", "id": "trl_giver_ok",
       "effect": [{"math": ["trl_giver_spawned", "=", "1"]},
                  {"u_message": "[Trilobit] Quest giver Sachiko Imai placed in your building.", "type": "good"}]},
      {"type": "effect_on_condition", "id": "trl_giver_failed",
       "effect": [{"u_message": "[Trilobit] Could not place quest giver Sachiko Imai (no free indoor tile found).", "type": "bad"}]}]
chain = [(f"trl_spawn_giver_near_{i}", True) for i in range(1, 9)] + [(f"trl_spawn_giver_any_{i}", False) for i in range(1, 25)]
for i, (n, near) in enumerate(chain):
    J.append(giver(n, chain[i + 1][0] if i + 1 < len(chain) else None, near))
J += [{
  "type": "effect_on_condition", "id": "trl_city_intro",
  "effect": [
    {"u_message": "[Trilobit] Start event running.", "type": "neutral"},
    {"math": ["trl_quest_state", "=", "0"]}, {"math": ["trl_mark_dead", "=", "1" if TEST else "0"]},
    {"math": ["trl_target_placed", "=", "0"]}, {"math": ["trl_giver_spawned", "=", "0"]},
    {"set_string_var": "somewhere in this district", "target_var": {"global_val": "trl_target_dir"}},
    {"u_location_variable": {"global_val": "trl_giver_loc"}},
    {"run_eocs": "trl_spawn_giver_near_1"},
    {"run_eocs": names},
    {"if": {"math": ["trl_target_placed == 0"]},
     "then": {"u_message": "[Trilobit] Could not place the mission target anywhere.", "type": "bad"}}
  ]}]
json.dump(fix(J), open(out + "/quest.json", "w"), indent=2)
print(len(J), "objects,", len(names), "placement eocs")
