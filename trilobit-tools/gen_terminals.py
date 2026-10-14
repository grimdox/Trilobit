#!/usr/bin/env python3
"""Generate the Mission Terminal and Shopping Terminal content.  usage: gen_terminals.py <mod dir>
Writes terminals.json and patches the testing mid-rise (trl_mid01_00z1) mapgen in city/mapgen.json."""
import json, os, sys
MOD = sys.argv[1]
out = []
def add(o): out.append(o)

# ------------------------------------------------------------------ furniture & items
def terminal(fid, name, desc, sym, color, eoc):
    return {"type": "furniture", "id": fid, "name": name, "description": desc, "symbol": sym, "color": color,
            "move_cost_mod": -1, "coverage": 40, "required_str": -1, "light_emitted": 8,
            "flags": ["TRANSPARENT", "FLAT_SURF", "CONTAINER", "NOITEM", "SEALED"],
            "examine_action": {"type": "effect_on_condition", "effect_on_conditions": [eoc]},
            "bash": {"str_min": 12, "str_max": 40, "sound": "smash!", "sound_fail": "thump."}}
add(terminal("f_trl_mission_terminal", "mission terminal",
             "A wall-bolted electric terminal with a cyan screen and a slot for credit chits.  Fixers post jobs here.  Examine it to browse contracts.",
             "M", "light_cyan", "trl_term_mission_examine"))
add(terminal("f_trl_shop_terminal", "shopping terminal",
             "A mains-powered vending terminal with a glowing price list.  Examine it to buy goods with yen.",
             "$", "yellow", "trl_term_shop_examine"))
add({"type": "ITEM", "subtypes": ["GENERIC"], "id": "trl_data_core", "name": {"str": "encrypted data core"},
     "description": "A fist-sized black core wrapped in a ribbon of warning tape.  Somebody paid a lot to get this back.",
     "weight": "300 g", "volume": "250 ml", "price": "0 USD", "price_postapoc": "0 USD", "color": "light_cyan", "symbol": ",",
     "material": ["steel"]})
for nid, nm, att, dth in (("trl_t_target", "trl_nc_mark", 10, True), ("trl_t_subject", "trl_nc_mark", 0, False)):
    o = {"type": "npc", "id": nid, "class": nm, "gender": "male", "attitude": att, "mission": 0, "chat": "TALK_DONE", "faction": "no_faction"}
    if dth: o["death_eocs"] = ["trl_t_target_death"]
    add(o)
add({"type": "effect_on_condition", "id": "trl_t_target_death", "eoc_type": "NPC_DEATH", "effect": [{"math": ["trl_t_dead", "=", "1"]}]})


# ------------------------------------------------------------------ bank: ATM furniture and account (world variable trl_bank)
add(terminal("f_trl_atm", "cash machine", "A steel cash machine with a green display and a worn keypad.  Examine it to use your bank account.", "A", "light_green", "trl_atm_examine"))
def atm_dep(n):
    return {"type": "effect_on_condition", "id": f"trl_atm_dep_{n}", "condition": {"math": ["u_item_count('trl_yen')", ">=", str(n)]},
            "effect": [{"u_consume_item": "trl_yen", "count": n}, {"math": ["trl_bank", "+=", str(n)]},
                       {"u_message": f"[Bank] {n:,} yen deposited.  Balance: <global_val:trl_bank> yen.", "type": "good"}]}
def atm_wd(n):
    return {"type": "effect_on_condition", "id": f"trl_atm_wd_{n}", "condition": {"math": ["trl_bank", ">=", str(n)]},
            "effect": [{"math": ["trl_bank", "-=", str(n)]}, {"u_spawn_item": "trl_yen", "count": n},
                       {"u_message": f"[Bank] {n:,} yen withdrawn.  Balance: <global_val:trl_bank> yen.", "type": "good"}]}
AMTS = [100, 1000, 10000]
for n in AMTS: add(atm_dep(n)); add(atm_wd(n))
add({"type": "effect_on_condition", "id": "trl_atm_dep_all", "condition": {"math": ["u_item_count('trl_yen')", ">", "0"]},
     "effect": [{"math": ["u_atm_tmp", "=", "u_item_count('trl_yen')"]}, {"u_consume_item": "trl_yen", "count": {"math": ["u_atm_tmp"]}},
                {"math": ["trl_bank", "+=", "u_atm_tmp"]}, {"u_message": "[Bank] <u_val:atm_tmp> yen deposited.  Balance: <global_val:trl_bank> yen.", "type": "good"}]})
add({"type": "effect_on_condition", "id": "trl_atm_wd_all", "condition": {"math": ["trl_bank", ">", "0"]},
     "effect": [{"math": ["u_atm_tmp", "=", "trl_bank"]}, {"math": ["trl_bank", "=", "0"]}, {"u_spawn_item": "trl_yen", "count": {"math": ["u_atm_tmp"]}},
                {"u_message": "[Bank] <u_val:atm_tmp> yen withdrawn.  Balance: 0 yen.", "type": "good"}]})
add({"type": "effect_on_condition", "id": "trl_atm_balance", "effect": [{"u_message": "[Bank] Balance: <global_val:trl_bank> yen.  Cash on hand: yen in your pack.", "type": "info"}]})
ATM_OPTS = [("trl_atm_balance", "Check balance")] + [(f"trl_atm_dep_{n}", f"Deposit {n:,} yen") for n in AMTS] + [("trl_atm_dep_all", "Deposit all cash")] + \
           [(f"trl_atm_wd_{n}", f"Withdraw {n:,} yen") for n in AMTS] + [("trl_atm_wd_all", "Withdraw everything")]
add({"type": "effect_on_condition", "id": "trl_atm_examine",
     "effect": [{"run_eoc_selector": [e for e, _ in ATM_OPTS], "names": [n for _, n in ATM_OPTS], "keys": list("abcdefghij")[:len(ATM_OPTS)],
                 "hide_failing": True, "allow_cancel": True, "title": "Bank - balance <global_val:trl_bank> yen"}]})

# ------------------------------------------------------------------ placement
def rnd_loc(var):
    return [{"u_location_variable": {"global_val": var}, "x_adjust": {"math": ["(rand(1) * 2 - 1) * (24 + rand(24))"]},
             "y_adjust": {"math": ["(rand(1) * 2 - 1) * (24 + rand(24))"]}}]
placed_ok = lambda eid: [{"id": eid, "effect": [
    {"math": ["trl_t_placed", "=", "1"]},
    {"u_run_npc_eocs": ["trl_t_record_loc"], "unique_ids": [{"global_val": "trl_t_uid"}]}]}]
add({"type": "effect_on_condition", "id": "trl_t_record_loc", "effect": [{"u_location_variable": {"global_val": "trl_t_loc"}}]})
tries = []
for k in range(12):
    indoor = k < 8
    tid = f"trl_t_try_{k}"; tries.append(tid)
    add({"type": "effect_on_condition", "id": tid, "condition": {"math": ["trl_t_placed == 0"]},
         "effect": rnd_loc("trl_t_loc") + [{"u_spawn_npc": {"global_val": "trl_t_npc"}, "real_count": 1, "unique_id": {"global_val": "trl_t_uid"},
                                            "target_var": {"global_val": "trl_t_loc"}, "min_radius": 0, "max_radius": 12, "indoor_only": indoor,
                                            "true_eocs": placed_ok(tid + "_ok")}]})
add({"type": "effect_on_condition", "id": "trl_t_place_npc",
     "effect": [{"math": ["trl_t_placed", "=", "0"]}, {"run_eocs": tries},
                {"if": {"math": ["trl_t_placed == 0"]}, "then": {"u_message": "[Trilobit] The terminal could not locate a safe site.  Try another contract.", "type": "bad"}}]})
add({"type": "effect_on_condition", "id": "trl_t_place_item",
     "effect": rnd_loc("trl_t_loc") + [{"map_spawn_item": "trl_data_core", "loc": {"global_val": "trl_t_loc"}, "indoor_only": True,
                                        "max_radius": 12, "suppress_message": True, "count": 1}]})
cleanup = {"id": "trl_t_kill_one", "effect": [{"u_die": {"remove_corpse": True, "supress_message": True, "remove_from_creature_tracker": True}}]}
add({"type": "effect_on_condition", "id": "trl_t_cleanup",
     "effect": [{"u_run_npc_eocs": [cleanup], "unique_ids": ["trl_t_uid_target", "trl_t_uid_subject"]},
                {"math": ["trl_t_state", "=", "0"]}, {"math": ["trl_t_fac", "=", "0"]}, {"math": ["trl_spy_progress", "=", "0"]}]})
add({"type": "effect_on_condition", "id": "trl_t_reward",
     "effect": [{"if": {"math": ["trl_t_fac > 0"]},
                 "then": [{"u_spawn_item": "trl_yen", "count": 1500}, {"u_message": "[Trilobit] Contract complete.  1500 yen paid, and your standing improves.", "type": "good"},
                          {"if": {"math": ["trl_t_fac == 1"]}, "then": [{"math": ["trl_rank_bratva += 1"]}, {"math": ["trl_rank_nap -= 1"]}]},
                          {"if": {"math": ["trl_t_fac == 2"]}, "then": [{"math": ["trl_rank_nap += 1"]}, {"math": ["trl_rank_bratva -= 1"]}, {"math": ["trl_rank_nasim -= 1"]}]},
                          {"if": {"math": ["trl_t_fac == 3"]}, "then": [{"math": ["trl_rank_nasim += 1"]}, {"math": ["trl_rank_nap -= 1"]}]},
                          {"run_eocs": "trl_fac_sync"}],
                 "else": [{"u_spawn_item": "trl_yen", "count": 1000}, {"u_message": "[Trilobit] Contract complete.  1000 yen credited.", "type": "good"}]},
                {"run_eocs": "trl_t_cleanup"}]})

# ------------------------------------------------------------------ missions
def mission(mid, name, desc, cond, start_target=None, end=None):
    m = {"type": "mission_definition", "id": mid, "name": {"str": name}, "description": desc, "goal": "MGOAL_CONDITION",
         "difficulty": 1, "value": 0, "urgent": False, "origins": ["ORIGIN_GAME_START"], "goal_condition": cond}
    if start_target: m["start"] = {"assign_mission_target": {"var": {"global_val": start_target}, "reveal_radius": 1}}
    if end: m["end"] = {"effect": end}
    add(m)
NEAR = {"math": ["distance('u', trl_t_loc) <= 12"]}
# Return legs never complete on their own: the player must speak to the terminal ("Report" response),
# which finishes the mission and runs its end effect (the payout).
AT_TERM = {"math": ["0 == 1"]}
# retrieval
mission("TRL_T_R1", "Retrieval (1/2): recover the data core",
        "A data core has been hidden in a building in this district; the terminal's map marker shows the area.  Find it and pick it up.",
        {"u_has_item": "trl_data_core"}, "trl_t_loc",
        [{"assign_mission": "TRL_T_R2"}, {"u_message": "You have the core.  Return to the mission terminal.", "type": "good"}])
mission("TRL_T_R2", "Retrieval (2/2): return the core to the terminal",
        "Bring the data core back to whoever gave you the contract (the mission terminal or a faction contact).  Paid on delivery.",
        AT_TERM, "trl_t_term_loc",
        [{"u_consume_item": "trl_data_core", "count": 1}, {"run_eocs": "trl_t_reward"}])
# assassination
mission("TRL_T_A1", "Assassination (1/3): find the target",
        "A target is holed up in a building in this district.  Go there and identify him.",
        NEAR, "trl_t_loc", [{"assign_mission": "TRL_T_A2"}, {"u_message": "You are close.  The target should be in here.", "type": "mixed"}])
mission("TRL_T_A2", "Assassination (2/3): kill the target",
        "The target is somewhere in this building.  Kill him.", {"math": ["trl_t_dead == 1"]}, "trl_t_loc",
        [{"assign_mission": "TRL_T_A3"}, {"u_message": "The target is dead.  Return to the mission terminal.", "type": "good"}])
mission("TRL_T_A3", "Assassination (3/3): report to the terminal",
        "Return to whoever gave you the contract (the mission terminal or a faction contact).  Paid on completion.", AT_TERM, "trl_t_term_loc",
        [{"run_eocs": "trl_t_reward"}])
# spying
mission("TRL_T_S1", "Spying (1/2): observe the subject",
        "Watch the subject from at least 10 tiles away for 10 turns without being seen by them.  Staying out of their line of sight and moving behind them helps.",
        {"math": ["trl_spy_progress >= 10"]}, "trl_t_loc",
        [{"assign_mission": "TRL_T_S2"}, {"u_message": "Observation complete.  Return to the mission terminal.", "type": "good"}])
mission("TRL_T_S2", "Spying (2/2): return to the terminal",
        "Return to whoever gave you the contract (the mission terminal or a faction contact).  Paid on completion.", AT_TERM, "trl_t_term_loc",
        [{"run_eocs": "trl_t_reward"}])

# spying tick: runs every turn while a spying contract is open
add({"type": "effect_on_condition", "id": "trl_spy_probe",
     "effect": [{"u_location_variable": {"global_val": "trl_spy_sloc"}},
                {"if": "player_see_u", "then": {"math": ["trl_spy_see", "=", "1"]}},
                {"if": {"u_can_see_location": {"global_val": "trl_spy_ploc"}}, "then": {"math": ["trl_spy_spotted", "=", "1"]}}]})
add({"type": "effect_on_condition", "id": "trl_spy_tick", "eoc_type": "RECURRING", "recurrence": "1 seconds", "global": True,
     "condition": {"and": [{"math": ["trl_t_state == 3"]}, {"math": ["trl_spy_progress < 10"]}]},
     "effect": [{"math": ["trl_spy_see", "=", "0"]}, {"math": ["trl_spy_spotted", "=", "0"]},
                {"u_location_variable": {"global_val": "trl_spy_ploc"}},
                {"u_run_npc_eocs": ["trl_spy_probe"], "unique_ids": ["trl_t_uid_subject"]},
                {"if": {"and": [{"math": ["trl_spy_spotted == 1"]}, {"math": ["trl_spy_progress > 0"]}]},
                 "then": [{"math": ["trl_spy_progress", "=", "0"]}, {"u_message": "[Trilobit] The subject spotted you.  Observation reset.", "type": "bad"}]},
                {"if": {"and": [{"math": ["trl_spy_see == 1"]}, {"math": ["trl_spy_spotted == 0"]}, {"math": ["distance('u', trl_spy_sloc) >= 10"]}]},
                 "then": [{"math": ["trl_spy_progress", "+=", "1"]}, {"u_message": "[Trilobit] Observing the subject: <global_val:trl_spy_progress>/10", "type": "neutral"}]}]})

# ------------------------------------------------------------------ mission terminal dialogue
add({"type": "effect_on_condition", "id": "trl_term_mission_examine", "global": True,
     "effect": [{"open_dialogue": {"topic": "TRL_TERM_MAIN"}}]})
def accept(kind_text, state, mid, npc_cls, uid, place):
    eff = [{"math": ["trl_t_fac", "=", "0"]}, {"math": ["trl_t_state", "=", str(state)]}, {"math": ["trl_t_dead", "=", "0"]}, {"math": ["trl_spy_progress", "=", "0"]},
           {"u_location_variable": {"global_val": "trl_t_term_loc"}}]
    if npc_cls:
        eff += [{"set_string_var": npc_cls, "target_var": {"global_val": "trl_t_npc"}}, {"set_string_var": uid, "target_var": {"global_val": "trl_t_uid"}}]
    eff += [{"run_eocs": place}, {"assign_mission": mid}]
    return eff
def report(label, mid, extra=None):
    cond = {"u_has_mission": mid}
    if extra: cond = {"and": [cond, extra]}
    return {"text": label, "topic": "TRL_TERM_REPORTED", "condition": cond,
            "effect": [{"finish_mission": mid, "success": True}]}
resp_main = [
 report("[Report] Hand over the data core.", "TRL_T_R2", {"u_has_item": "trl_data_core"}),
 report("[Report] The target is dead.", "TRL_T_A3"),
 report("[Report] Observation of the subject complete.", "TRL_T_S2"),
 {"text": "[Retrieval] Recover a data core and bring it back.", "topic": "TRL_TERM_ACCEPTED", "condition": {"math": ["trl_t_state == 0"]},
  "effect": accept("", 1, "TRL_T_R1", None, None, "trl_t_place_item")},
 {"text": "[Assassination] Find a target, kill him, report back.", "topic": "TRL_TERM_ACCEPTED", "condition": {"math": ["trl_t_state == 0"]},
  "effect": accept("", 2, "TRL_T_A1", "trl_t_target", "trl_t_uid_target", "trl_t_place_npc")},
 {"text": "[Spying] Watch a subject from 10+ tiles for 10 turns unseen.", "topic": "TRL_TERM_ACCEPTED", "condition": {"math": ["trl_t_state == 0"]},
  "effect": accept("", 3, "TRL_T_S1", "trl_t_subject", "trl_t_uid_subject", "trl_t_place_npc")},
 {"text": "Abandon the current contract.", "topic": "TRL_TERM_ABANDONED", "condition": {"math": ["trl_t_state > 0"]},
  "effect": [{"if": {"u_has_mission": mid}, "then": {"finish_mission": mid, "success": False}} for mid in
             ("TRL_T_R1", "TRL_T_R2", "TRL_T_A1", "TRL_T_A2", "TRL_T_A3", "TRL_T_S1", "TRL_T_S2")] + [{"run_eocs": "trl_t_cleanup"}]},
 {"text": "Step away from the terminal.", "topic": "TALK_DONE"}]
add({"type": "talk_topic", "id": "TRL_TERM_MAIN", "dynamic_line": {"math": ["trl_t_state == 0"],
     "yes": "&MISSION TERMINAL.  Three contracts are open.  Choose one.  Payment on completion: 1000 yen.",
     "no": "&MISSION TERMINAL.  You already hold an open contract.  Check your mission log, report a finished one, or abandon it here."}, "responses": resp_main})
add({"type": "talk_topic", "id": "TRL_TERM_ACCEPTED", "dynamic_line": "&CONTRACT ACCEPTED.  Details are in your mission log.  When the objective is done, return and speak to this terminal to report and be paid.",
     "responses": [{"text": "Understood.", "topic": "TALK_DONE"}]})
add({"type": "talk_topic", "id": "TRL_TERM_REPORTED", "dynamic_line": "&REPORT RECEIVED.  Verified.  Payment credited.",
     "responses": [{"text": "Back to the list.", "topic": "TRL_TERM_MAIN"}, {"text": "Step away.", "topic": "TALK_DONE"}]})
add({"type": "talk_topic", "id": "TRL_TERM_ABANDONED", "dynamic_line": "&CONTRACT ABANDONED.  No payment.  The terminal accepts new contracts.",
     "responses": [{"text": "Back to the list.", "topic": "TRL_TERM_MAIN"}, {"text": "Step away.", "topic": "TALK_DONE"}]})

# ------------------------------------------------------------------ shopping terminal (CDDA barter screen)
# Examining the terminal opens the standard trade window against a temporary shopkeeper of class
# trl_nc_shop (C++ effect "open_shop").  Prices are pinned (no speech/int markup) via price rules.
# Item prices are per default stack, so the 9mm round (stack_size 50) is priced as 50 rounds.
add({"type": "effect_on_condition", "id": "trl_term_shop_examine", "global": True,
     "effect": [{"open_shop": "trl_nc_shop"}]})
add({"type": "faction", "id": "trl_terminal", "name": "Vending Terminal", "description": "Automated vending terminals.", "mon_faction": "human",
     "likes_u": 0, "respects_u": 0, "known_by_u": False, "size": 100, "power": 100,
     "fac_food_supply": [[0, {"calories": 0, "vitamins": {}}]],
     "wealth": 20000000, "currency": "trl_yen", "price_rules": [], "relations": {}})
NEWSTOCK = [("trl_gun_hp9", 3, 900), ("trl_gun_vp9", 3, 450), ("trl_gun_hs12", 2, 1200), ("trl_gun_va7", 2, 1800), ("trl_kama", 4, 120),
            ("trl_yari", 2, 260), ("trl_nunchaku", 3, 70), ("katana", 2, 1500), ("trl_shuriken_4", 20, 8), ("trl_yumi", 2, 700), ("trl_arrow_ap", 30, 35),
            ("trl_gun_zp9", 4, 380), ("trl_gun_vr38", 3, 450), ("trl_gun_lp22", 3, 300), ("trl_gun_hx9", 2, 2600), ("trl_gun_sp45", 2, 2400),
            ("trl_gun_vs44", 2, 700), ("trl_gun_vk74", 2, 1400), ("trl_gun_gs12", 2, 1100), ("trl_gun_hd308", 1, 1800), ("trl_gun_gl40", 1, 2400)]
add({"type": "item_group", "id": "trl_shop_stock", "subtype": "collection",
     "entries": [{"item": "9mm", "charges": 500}, {"item": "hat_hard", "count": 10}, {"item": "m1911", "count": 5}] + [{"item": i, "count": n} for i, n, _ in NEWSTOCK]})
add({"type": "item_group", "id": "trl_shop_none", "subtype": "collection", "entries": []})
add({"type": "npc_class", "id": "trl_nc_shop", "worn_override": "trl_shop_none", "weapon_override": "trl_shop_none", "name": {"str": "Terminal"}, "job_description": "A vending terminal.",
     "common": False,
     "shopkeeper_item_group": [{"group": "trl_shop_stock", "rigid": True}],
     "shopkeeper_price_rules": [{"item": "9mm", "price": 10 * 100 * 50, "fixed_adj": 0},
                                {"item": "hat_hard", "price": 100 * 100, "fixed_adj": 0},
                                {"item": "m1911", "price": 500 * 100, "fixed_adj": 0}] + [{"item": i, "price": pr * 100, "fixed_adj": 0} for i, _, pr in NEWSTOCK] + [
                                {"item": "trl_yen", "fixed_adj": 0}]})

json.dump(out, open(os.path.join(MOD, "terminals.json"), "w"), indent=2)

# ------------------------------------------------------------------ place the terminals in the testing mid-rise
p = os.path.join(MOD, "city", "mapgen.json")
d = json.load(open(p))
n = 0
for o in d:
    if o.get("type") == "mapgen" and "trl_mid01_00z1" in json.dumps(o.get("om_terrain")):
        o["object"]["place_furniture"] = [f for f in o["object"].get("place_furniture", []) if not f["furn"].startswith("f_trl_m")
                                          and not f["furn"].startswith("f_trl_shop") and f["furn"] not in ("f_trl_atm", "f_trl_jack")]
        o["object"]["place_furniture"] += [{"furn": "f_trl_mission_terminal", "x": 14, "y": 19}, {"furn": "f_trl_shop_terminal", "x": 16, "y": 19},
                                                 {"furn": "f_trl_atm", "x": 12, "y": 19}, {"furn": "f_trl_jack", "x": 18, "y": 19}]
        n += 1
json.dump(d, open(p, "w"), indent=1)
print("terminals.json written;", n, "mapgen patched;", len(out), "objects")
