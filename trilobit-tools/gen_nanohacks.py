#!/usr/bin/env python3
"""Generate the Trilobit nanohack trees: 10 trees, 20 nanohacks, nanohack chips (items), loot groups.
usage: gen_nanos.py <mod dir>   (also renames the six original programs in combat.json)"""
import json, os, sys
MOD = sys.argv[1]
REQ = "  Requires a cyber brain."
TREES = {
 "Mend": "Repair the body.", "Shell": "Harden the body against damage.", "Reflex": "Speed and evasion.",
 "Strike": "Sharpen and extend your attacks.", "Ghost": "Hide from sight and sound.", "Sense": "See and detect more.",
 "Intrude": "Take over enemy systems.", "Fabricate": "Print gear from raw energy.",
 "Phase": "Move through space.", "Drain": "Take power from enemies."}
NOFLAGS = ["NO_LEGS", "NO_HANDS", "NO_FAIL", "SILENT", "NO_PROJECTILE"]
BASE = dict(type="SPELL", spell_class="NONE", difficulty=0, max_level=1, energy_source="BIONIC", base_casting_time=50,
            flags=NOFLAGS, min_damage=0, max_damage=0, damage_increment=0, condition={"u_has_flag": "MACHINE_BRAIN"})
def spell(id, tree, name, desc, **kw):
    s = dict(BASE); s.update(id=id, name=f"{tree}: {name}", description=desc + REQ); s.update(kw); return s
SELF = dict(shape="blast", valid_targets=["self"], min_range=0, max_range=0, min_aoe=0, max_aoe=0)
FOE = dict(shape="blast", valid_targets=["hostile"], min_range=10, max_range=10, min_aoe=0, max_aoe=0)
def sdur(sec): return dict(min_duration=sec * 100, max_duration=sec * 100)
def selfeff(eid, **kw): return dict(effect="attack", effect_str=eid, damage_type="biological", min_damage=1, max_damage=1, **SELF, **kw)

NEW = [
 spell("trl_nh_purge", "Mend", "Purge", "Nanites scrub poison from your blood.", effect="remove_effect", effect_str="poison",
       base_energy_cost=15, **SELF),
 spell("trl_nh_reactive", "Shell", "Reactive Shell", "A hard reactive skin for fifteen seconds.", base_energy_cost=30, **selfeff("trl_nh_reactive"), **sdur(15)),
 spell("trl_nh_afterimage", "Reflex", "Afterimage", "Your outline lags behind your body for twenty seconds, spoiling aim.", base_energy_cost=25, **selfeff("trl_nh_afterimage"), **sdur(20)),
 spell("trl_nh_lock_on", "Strike", "Lock-On", "Nanites steady your hands and tighten your shots for a minute.", base_energy_cost=20, **selfeff("trl_nh_lock_on"), **sdur(60)),
 spell("trl_nh_shock_field", "Strike", "Shock Field", "A burst of current in a small radius around you.", effect="attack", damage_type="electric",
       shape="blast", valid_targets=["hostile"], min_range=0, max_range=0, min_aoe=3, max_aoe=3, min_damage=20, max_damage=20, base_energy_cost=35,
       flags=["NO_LEGS", "NO_HANDS", "NO_FAIL", "NO_PROJECTILE"]),
 spell("trl_nh_cloak", "Ghost", "Thermal Cloak", "Bends light and heat around you for thirty seconds.", base_energy_cost=30, **selfeff("trl_nh_cloak"), **sdur(30)),
 spell("trl_nh_dampener", "Ghost", "Noise Dampener", "Your steps and shots make far less noise for a minute.", base_energy_cost=15, **selfeff("trl_nh_dampener"), **sdur(60)),
 spell("trl_nh_pulse_scan", "Sense", "Pulse Scan", "A wide scan reveals the surrounding blocks on your map.", effect="map", base_energy_cost=20,
       shape="blast", valid_targets=["self"], min_range=0, max_range=0, min_aoe=6, max_aoe=6),
 spell("trl_nh_night_eye", "Sense", "Night Eye", "Your optics amplify light for twenty minutes.", base_energy_cost=10, **selfeff("trl_nh_night_eye"), **sdur(1200)),
 spell("trl_nh_print_ammo", "Fabricate", "Print Ammo", "Prints thirty rounds of 5.56 at your feet.", effect="spawn_item", effect_str="556",
       shape="blast", valid_targets=["self"], min_damage=30, max_damage=30, min_duration=1, max_duration=2, base_energy_cost=25),
 spell("trl_nh_print_kit", "Fabricate", "Print Bandages", "Prints three bandages at your feet.", effect="spawn_item", effect_str="bandages",
       shape="blast", valid_targets=["self"], min_damage=3, max_damage=3, min_duration=1, max_duration=2, base_energy_cost=15),
 spell("trl_nh_blink", "Phase", "Blink", "Teleports you up to eight tiles.", effect="short_range_teleport", shape="blast", valid_targets=["ground"],
       min_range=8, max_range=8, min_aoe=0, max_aoe=0, base_energy_cost=40, flags=["NO_LEGS", "NO_HANDS", "NO_FAIL", "SILENT", "TARGET_TELEPORT"]),
 spell("trl_nh_hop", "Phase", "Hop", "A short, cheap teleport of three tiles.", effect="short_range_teleport", shape="blast", valid_targets=["ground"],
       min_range=3, max_range=3, min_aoe=0, max_aoe=0, base_energy_cost=12, flags=["NO_LEGS", "NO_HANDS", "NO_FAIL", "SILENT", "TARGET_TELEPORT"]),
 spell("trl_nh_siphon", "Drain", "Siphon", "Burns an enemy's circuits and takes some of the power back.", effect="attack", damage_type="electric",
       min_damage=12, max_damage=12, base_energy_cost=10, extra_effects=[{"id": "trl_nh_siphon_gain", "hit_self": True}], **FOE,
       flags=["NO_LEGS", "NO_HANDS", "NO_FAIL", "NO_PROJECTILE"]),
 dict(BASE, id="trl_nh_siphon_gain", name="Siphon gain", description="Returns power from a Siphon.", effect="recover_energy", effect_str="BIONIC",
      energy_source="NONE", base_energy_cost=0, min_damage=22, max_damage=22, **SELF),
]
def eff(id, name, desc, vals):
    return {"type": "effect_type", "id": id, "name": [name], "desc": [desc], "rating": "good", "max_duration": "30 minutes",
            "apply_message": "", "remove_message": "The effect fades.", "enchantments": [{"values": vals}]}
EFFECTS = [
 eff("trl_nh_reactive", "Reactive Shell", "A hard reactive skin covers you.", [{"value": "ARMOR_ALL", "add": 14}]),
 eff("trl_nh_afterimage", "Afterimage", "Your outline lags behind your body.", [{"value": "RANGE_DODGE", "add": 0.4}, {"value": "BONUS_DODGE", "add": 2}]),
 eff("trl_nh_lock_on", "Locked On", "Your aim is steady and tight.", [{"value": "WEAPON_DISPERSION", "multiply": -0.5}, {"value": "RANGED_DAMAGE", "add": 4}]),
 eff("trl_nh_cloak", "Thermal Cloak", "Light and heat bend around you.", [{"value": "STEALTH_MODIFIER", "add": 55}]),
 eff("trl_nh_dampener", "Dampened", "Your steps and shots are muffled.", [{"value": "FOOTSTEP_NOISE", "multiply": -0.9}, {"value": "ATTACK_NOISE", "multiply": -0.5}]),
 eff("trl_nh_night_eye", "Night Eye", "Your optics amplify light.", [{"value": "NIGHT_VIS", "add": 6}]),
]
# all 20 programs: id -> (tree, display)
ALL = {
 "trl_nh_repair": "Mend", "trl_nh_purge": "Mend",
 "trl_nh_plating": "Shell", "trl_nh_reactive": "Shell",
 "trl_nh_overclock": "Reflex", "trl_nh_afterimage": "Reflex",
 "trl_nh_lock_on": "Strike", "trl_nh_shock_field": "Strike",
 "trl_nh_cloak": "Ghost", "trl_nh_dampener": "Ghost",
 "trl_nh_pulse_scan": "Sense", "trl_nh_night_eye": "Sense",
 "trl_nh_overload": "Intrude", "trl_nh_blind": "Intrude", "trl_nh_lock": "Intrude",
 "trl_nh_print_ammo": "Fabricate", "trl_nh_print_kit": "Fabricate",
 "trl_nh_blink": "Phase", "trl_nh_hop": "Phase",
 "trl_nh_siphon": "Drain",
}
assert len(ALL) == 20 and len(set(ALL.values())) == 10
RENAME = {"trl_nh_repair": "Mend: Repair", "trl_nh_plating": "Shell: Plating", "trl_nh_overclock": "Reflex: Overclock",
          "trl_nh_overload": "Intrude: Overload", "trl_nh_blind": "Intrude: Blind", "trl_nh_lock": "Intrude: Lockdown"}
cp = os.path.join(MOD, "combat.json")
combat = json.load(open(cp))
for x in combat:
    if x.get("type") == "SPELL" and x["id"] in RENAME: x["name"] = RENAME[x["id"]]
    if x.get("type") == "effect_type" and x["id"] == "trl_nh_plating": x["name"] = ["Shell Plating"]
json.dump(combat, open(cp, "w"), indent=2)
names = {s["id"]: s["name"] for s in NEW}; names.update(RENAME)
TREECOLOR = {"Mend": "light_green", "Shell": "light_gray", "Reflex": "yellow", "Strike": "light_red", "Ghost": "dark_gray",
             "Sense": "light_cyan", "Intrude": "light_blue", "Fabricate": "white", "Phase": "magenta", "Drain": "pink"}
COST = {"trl_nh_repair": 2, "trl_nh_purge": 1, "trl_nh_plating": 3, "trl_nh_reactive": 3, "trl_nh_overclock": 4, "trl_nh_afterimage": 2,
        "trl_nh_lock_on": 3, "trl_nh_shock_field": 4, "trl_nh_cloak": 5, "trl_nh_dampener": 2, "trl_nh_pulse_scan": 2, "trl_nh_night_eye": 1,
        "trl_nh_overload": 3, "trl_nh_blind": 2, "trl_nh_lock": 3, "trl_nh_print_ammo": 3, "trl_nh_print_kit": 2, "trl_nh_blink": 5,
        "trl_nh_hop": 3, "trl_nh_siphon": 4}
assert set(COST) == set(ALL)
GRADES = [("trl_bio_cyberbrain", "Cyberbrain Mk I", 4), ("trl_bio_cyberbrain_2", "Cyberbrain Mk II", 8), ("trl_bio_cyberbrain_3", "Cyberbrain Mk III", 14),
          ("trl_bio_cyberbrain_4", "Cyberbrain Mk IV", 22), ("trl_bio_cyberbrain_5", "Cyberbrain Mk V", 32)]
items = []
for sid, tree in ALL.items():
    items.append({"type": "ITEM", "subtypes": ["GENERIC"], "id": "trl_chip_" + sid.replace("trl_", ""), "name": {"str": f"nanohack chip ({names[sid]})", "str_pl": f"nanohack chips ({names[sid]})"},
                  "description": f"A data chip holding the {names[sid]} nanohack (Control Value cost {COST[sid]}).  Use it to install the nanohack in your cyberbrain; remove it again from a nanohack console to get the chip back.",
                  "weight": "5 g", "volume": "5 ml", "symbol": "=", "color": TREECOLOR[tree], "material": ["plastic"],
                  "price": "600 USD", "price_postapoc": "50 USD", "flags": ["TRADER_AVOID"],
                  "use_action": {"type": "effect_on_conditions", "menu_text": "Install nanohack", "description": "Install this nanohack in your cyberbrain.",
                                 "effect_on_conditions": ["trl_nh_inst_" + sid[len("trl_nh_"):]]}})
groups = [
 {"type": "item_group", "id": "trl_loot_chips", "subtype": "distribution", "entries": [{"item": i["id"]} for i in items]},
 {"type": "item_group", "id": "trl_new_chips", "subtype": "collection",
  "entries": [{"item": i["id"]} for i in items if i["id"].replace("trl_chip_", "trl_") not in
              ("trl_nh_repair", "trl_nh_plating", "trl_nh_overclock", "trl_nh_overload", "trl_nh_blind", "trl_nh_lock")]},
]

# ---------------------------------------------------------------- Control Value system (Milestone 21)
def short(sid): return sid[len("trl_nh_"):]
def eoc(id, effect, **kw):
    o = {"type": "effect_on_condition", "id": id, "effect": effect}; o.update(kw); return o
def has(sid): return {"u_has_trait": sid}
def hasq(sid): return {"u_has_trait": "trl_nhq_" + short(sid)}
sids = list(ALL)
cvx = []
for sid in sids:
    nm = names[sid]
    base = {"type": "mutation", "points": 0, "visibility": 0, "ugliness": 0, "valid": False, "purifiable": False, "player_display": True}
    cvx.append(dict(base, id=sid, name={"str": f"{nm} (nanohack)"}, description=f"Installed nanohack, Control Value cost {COST[sid]}.  Active.", spells_learned=[[sid, 1]]))
    cvx.append(dict(base, id="trl_nhq_" + short(sid), name={"str": f"{nm} (suspended)"}, description=f"Installed nanohack, Control Value cost {COST[sid]}.  Suspended: your Control Value limit is too low.  It wakes when there is room."))
for gid, gname, lim in GRADES:
    if gid == "trl_bio_cyberbrain": continue
    cvx.append({"type": "bionic", "id": gid, "name": {"str": gname}, "description": f"{gname}: a machine brain with a Control Value limit of {lim}.  Required to run nanohacks.  Do not install more than one cyberbrain.",
                "occupied_bodyparts": [["head", 12]], "flags": ["MACHINE_BRAIN", "BIONIC_NPC_USABLE"],
                "protec": [["head", {"bash": 12, "cut": 12, "stab": 12, "bullet": 22}]]})
    cvx.append({"id": gid, "copy-from": "bionic_general_npc_usable", "type": "ITEM", "subtypes": ["BIONIC_ITEM"], "name": {"str": f"{gname} CBM"}, "looks_like": "bio_int_enhancer",
                "description": f"{gname}: Control Value limit {lim}.  Required to run nanohacks.", "price": f"{[0,0,60,150,400,1000][int(gid[-1])]} kUSD",
                "price_postapoc": "100 USD", "weight": "500 g", "difficulty": 12 + int(gid[-1])})
cvx.append({"type": "ITEM", "subtypes": ["GENERIC"], "id": "trl_nh_console", "name": {"str": "nanohack console"}, "symbol": ",", "color": "light_cyan",
            "description": "A thin interface card tied to your cyberbrain.  Use it to see your Control Value and remove installed nanohacks (the chip comes back).",
            "weight": "20 g", "volume": "10 ml", "material": ["plastic"], "price": "50 USD", "price_postapoc": "5 USD",
            "use_action": {"type": "effect_on_conditions", "menu_text": "Open nanohack console", "description": "Review and remove installed nanohacks.",
                           "effect_on_conditions": ["trl_nh_menu"]}})
# recalc
rc = [{"math": ["u_nh_limit", "=", "0"]}]
for gid, gname, lim in GRADES:
    rc.append({"if": {"u_has_bionics": gid}, "then": [{"math": ["u_nh_limit", "=", f"max(u_nh_limit, {lim})"]}]})
rc.append({"math": ["u_nh_used", "=", "0"]})
for sid in sids:
    rc.append({"if": has(sid), "then": [{"math": ["u_nh_used", "+=", str(COST[sid])]}]})
rc += [{"run_eocs": ["trl_nh_shed"]}, {"run_eocs": ["trl_nh_wake"]}]
cvx.append(eoc("trl_nh_recalc", rc))
cvx.append(eoc("trl_nh_tick", [{"run_eocs": ["trl_nh_recalc"]}], recurrence=["30 seconds", "30 seconds"], global_=None) if False else
           {"type": "effect_on_condition", "id": "trl_nh_tick", "recurrence": ["30 seconds", "30 seconds"], "global": True, "effect": [{"run_eocs": ["trl_nh_recalc"]}]})
# shed: suspend the newest active nanohack while over the limit
sh = [{"math": ["u_nh_m", "=", "0"]}]
for sid in sids:
    sh.append({"if": has(sid), "then": [{"math": ["u_nh_m", "=", f"max(u_nh_m, u_nh_ord_{short(sid)} + 1)"]}]})
for sid in sids:
    sh.append({"if": {"and": [has(sid), {"math": [f"u_nh_ord_{short(sid)} + 1", "==", "u_nh_m"]}]},
               "then": [{"u_lose_trait": sid}, {"u_add_trait": "trl_nhq_" + short(sid)}, {"math": ["u_nh_used", "-=", str(COST[sid])]}, {"math": ["u_nh_m", "=", "-1"]},
                        {"u_message": f"Over your Control Value limit: {names[sid]} is suspended.", "type": "bad"}]})
sh.append({"if": {"math": ["u_nh_used", ">", "u_nh_limit"]}, "then": [{"run_eocs": ["trl_nh_shed2"]}]})
cvx.append(eoc("trl_nh_shed", sh, condition={"math": ["u_nh_used", ">", "u_nh_limit"]}))
cvx.append(eoc("trl_nh_shed2", [{"run_eocs": ["trl_nh_shed"]}]))
# wake: reactivate the oldest suspended nanohack that fits
wk = [{"math": ["u_nh_m", "=", "1000000"]}, {"math": ["u_nh_woke", "=", "0"]}]
for sid in sids:
    wk.append({"if": hasq(sid), "then": [{"math": ["u_nh_m", "=", f"min(u_nh_m, u_nh_ord_{short(sid)})"]}]})
for sid in sids:
    wk.append({"if": {"and": [hasq(sid), {"math": [f"u_nh_ord_{short(sid)}", "==", "u_nh_m"]}, {"math": [f"u_nh_used + {COST[sid]}", "<=", "u_nh_limit"]}]},
               "then": [{"u_lose_trait": "trl_nhq_" + short(sid)}, {"u_add_trait": sid}, {"math": ["u_nh_used", "+=", str(COST[sid])]}, {"math": ["u_nh_m", "=", "1000000"]},
                        {"math": ["u_nh_woke", "=", "1"]}, {"u_message": f"{names[sid]} is active again.", "type": "good"}]})
wk.append({"if": {"math": ["u_nh_woke", "==", "1"]}, "then": [{"run_eocs": ["trl_nh_wake2"]}]})
cvx.append(eoc("trl_nh_wake", wk, condition={"math": ["u_nh_m", "!=", "-7"]}))
cvx.append(eoc("trl_nh_wake2", [{"run_eocs": ["trl_nh_wake"]}]))
# install / remove per nanohack
for sid in sids:
    chip = "trl_chip_nh_" + short(sid)
    c = COST[sid]
    both = {"or": [has(sid), hasq(sid)]}
    cvx.append(eoc("trl_nh_inst_" + short(sid), [
        {"run_eocs": ["trl_nh_recalc"]},
        {"if": both, "then": [{"u_message": f"{names[sid]} is already installed.", "type": "info"}, {"u_spawn_item": chip}],
         "else": [{"if": {"not": {"u_has_flag": "MACHINE_BRAIN"}},
                   "then": [{"u_message": "You need a cyberbrain to install a nanohack.", "type": "bad"}, {"u_spawn_item": chip}],
                   "else": [{"if": {"math": [f"u_nh_used + {c}", ">", "u_nh_limit"]},
                             "then": [{"u_message": f"Not enough Control Value: {names[sid]} needs {c}; you have <u_val:nh_used> of <u_val:nh_limit> in use.  Remove a nanohack first.", "type": "bad"},
                                      {"u_spawn_item": chip}],
                             "else": [{"u_add_trait": sid}, {"math": [f"u_nh_ord_{short(sid)}", "=", "u_nh_seq"]}, {"math": ["u_nh_seq", "+=", "1"]},
                                      {"math": ["u_nh_used", "+=", str(c)]},
                                      {"u_message": f"{names[sid]} installed.  Control Value in use: <u_val:nh_used> of <u_val:nh_limit>.", "type": "good"}]}]}]}]))
    cvx.append(eoc("trl_nh_rem_" + short(sid), [
        {"u_lose_trait": sid}, {"u_lose_trait": "trl_nhq_" + short(sid)}, {"u_spawn_item": chip},
        {"run_eocs": ["trl_nh_recalc"]},
        {"u_message": f"{names[sid]} removed; the chip is back in your inventory.  Control Value in use: <u_val:nh_used> of <u_val:nh_limit>.", "type": "info"}],
        condition=both))
keys = "abcdefghijklmnopqrst"
menu = [{"run_eocs": ["trl_nh_recalc"]}]
for sid in sids:
    menu.append({"if": has(sid), "then": [{"u_message": f"  {names[sid]} (CV {COST[sid]}): active", "type": "neutral"}]})
    menu.append({"if": hasq(sid), "then": [{"u_message": f"  {names[sid]} (CV {COST[sid]}): SUSPENDED", "type": "bad"}]})
menu.append({"run_eoc_selector": ["trl_nh_rem_" + short(s) for s in sids], "names": [f"Remove {names[s]} (CV {COST[s]})" for s in sids],
             "keys": list(keys), "hide_failing": True, "allow_cancel": True, "title": "Nanohacks: Control Value <u_val:nh_used> of <u_val:nh_limit> in use"})
cvx.append(eoc("trl_nh_menu", menu))
cvx.append(eoc("trl_nh_start", [{"math": ["u_nh_seq", "=", "1"]}, {"u_spawn_item": "trl_nh_console"}, {"run_eocs": ["trl_nh_recalc"]}]))

trees = [{"tree": t, "blurb": b, "programs": [names[k] for k, v in ALL.items() if v == t]} for t, b in TREES.items()]
json.dump(NEW + EFFECTS + items + groups + cvx, open(os.path.join(MOD, "nanohacks.json"), "w"), indent=1)
json.dump(trees, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "nanohack_trees.json"), "w"), indent=1)
# give the Combat Test start one of every new chip
pp = os.path.join(MOD, "professions.json")
p = json.load(open(pp))
for x in p:
    if x.get("id") == "trl_test_combat":
        ents = x["items"]["both"]["entries"]
        if not any(e.get("group") == "trl_new_chips" for e in ents): ents.append({"group": "trl_new_chips"})
        x["traits"] = [t for t in x.get("traits", []) if t != "trl_nh_suite"] + [t for t in ("trl_nh_repair", "trl_nh_plating", "trl_nh_overclock", "trl_nh_overload", "trl_nh_blind", "trl_nh_lock") if t not in x.get("traits", [])]
        x["CBMs"] = ["trl_bio_cyberbrain_5" if c == "trl_bio_cyberbrain" else c for c in x.get("CBMs", [])]
json.dump(p, open(pp, "w"), indent=2)
print(len(NEW), "new spells,", len(items), "chips")
for t in trees: print(t["tree"], "-", ", ".join(t["programs"]))
