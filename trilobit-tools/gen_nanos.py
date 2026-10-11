#!/usr/bin/env python3
"""Generate the Trilobit nano trees: 10 trees, 20 nano-programs, nano chips (items), loot groups.
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
 spell("trl_nano_purge", "Mend", "Purge", "Nanites scrub poison from your blood.", effect="remove_effect", effect_str="poison",
       base_energy_cost=15, **SELF),
 spell("trl_nano_reactive", "Shell", "Reactive Shell", "A hard reactive skin for fifteen seconds.", base_energy_cost=30, **selfeff("trl_nano_reactive"), **sdur(15)),
 spell("trl_nano_afterimage", "Reflex", "Afterimage", "Your outline lags behind your body for twenty seconds, spoiling aim.", base_energy_cost=25, **selfeff("trl_nano_afterimage"), **sdur(20)),
 spell("trl_nano_lock_on", "Strike", "Lock-On", "Nanites steady your hands and tighten your shots for a minute.", base_energy_cost=20, **selfeff("trl_nano_lock_on"), **sdur(60)),
 spell("trl_nano_shock_field", "Strike", "Shock Field", "A burst of current in a small radius around you.", effect="attack", damage_type="electric",
       shape="blast", valid_targets=["hostile"], min_range=0, max_range=0, min_aoe=3, max_aoe=3, min_damage=20, max_damage=20, base_energy_cost=35,
       flags=["NO_LEGS", "NO_HANDS", "NO_FAIL", "NO_PROJECTILE"]),
 spell("trl_nano_cloak", "Ghost", "Thermal Cloak", "Bends light and heat around you for thirty seconds.", base_energy_cost=30, **selfeff("trl_nano_cloak"), **sdur(30)),
 spell("trl_nano_dampener", "Ghost", "Noise Dampener", "Your steps and shots make far less noise for a minute.", base_energy_cost=15, **selfeff("trl_nano_dampener"), **sdur(60)),
 spell("trl_nano_pulse_scan", "Sense", "Pulse Scan", "A wide scan reveals the surrounding blocks on your map.", effect="map", base_energy_cost=20,
       shape="blast", valid_targets=["self"], min_range=0, max_range=0, min_aoe=6, max_aoe=6),
 spell("trl_nano_night_eye", "Sense", "Night Eye", "Your optics amplify light for twenty minutes.", base_energy_cost=10, **selfeff("trl_nano_night_eye"), **sdur(1200)),
 spell("trl_nano_print_ammo", "Fabricate", "Print Ammo", "Prints thirty rounds of 5.56 at your feet.", effect="spawn_item", effect_str="556",
       shape="blast", valid_targets=["self"], min_damage=30, max_damage=30, min_duration=1, max_duration=2, base_energy_cost=25),
 spell("trl_nano_print_kit", "Fabricate", "Print Bandages", "Prints three bandages at your feet.", effect="spawn_item", effect_str="bandages",
       shape="blast", valid_targets=["self"], min_damage=3, max_damage=3, min_duration=1, max_duration=2, base_energy_cost=15),
 spell("trl_nano_blink", "Phase", "Blink", "Teleports you up to eight tiles.", effect="short_range_teleport", shape="blast", valid_targets=["ground"],
       min_range=8, max_range=8, min_aoe=0, max_aoe=0, base_energy_cost=40, flags=["NO_LEGS", "NO_HANDS", "NO_FAIL", "SILENT", "TARGET_TELEPORT"]),
 spell("trl_nano_hop", "Phase", "Hop", "A short, cheap teleport of three tiles.", effect="short_range_teleport", shape="blast", valid_targets=["ground"],
       min_range=3, max_range=3, min_aoe=0, max_aoe=0, base_energy_cost=12, flags=["NO_LEGS", "NO_HANDS", "NO_FAIL", "SILENT", "TARGET_TELEPORT"]),
 spell("trl_nano_siphon", "Drain", "Siphon", "Burns an enemy's circuits and takes some of the power back.", effect="attack", damage_type="electric",
       min_damage=12, max_damage=12, base_energy_cost=10, extra_effects=[{"id": "trl_nano_siphon_gain", "hit_self": True}], **FOE,
       flags=["NO_LEGS", "NO_HANDS", "NO_FAIL", "NO_PROJECTILE"]),
 dict(BASE, id="trl_nano_siphon_gain", name="Siphon gain", description="Returns power from a Siphon.", effect="recover_energy", effect_str="BIONIC",
      energy_source="NONE", base_energy_cost=0, min_damage=22, max_damage=22, **SELF),
]
def eff(id, name, desc, vals):
    return {"type": "effect_type", "id": id, "name": [name], "desc": [desc], "rating": "good", "max_duration": "30 minutes",
            "apply_message": "", "remove_message": "The effect fades.", "enchantments": [{"values": vals}]}
EFFECTS = [
 eff("trl_nano_reactive", "Reactive Shell", "A hard reactive skin covers you.", [{"value": "ARMOR_ALL", "add": 14}]),
 eff("trl_nano_afterimage", "Afterimage", "Your outline lags behind your body.", [{"value": "RANGE_DODGE", "add": 0.4}, {"value": "BONUS_DODGE", "add": 2}]),
 eff("trl_nano_lock_on", "Locked On", "Your aim is steady and tight.", [{"value": "WEAPON_DISPERSION", "multiply": -0.5}, {"value": "RANGED_DAMAGE", "add": 4}]),
 eff("trl_nano_cloak", "Thermal Cloak", "Light and heat bend around you.", [{"value": "STEALTH_MODIFIER", "add": 55}]),
 eff("trl_nano_dampener", "Dampened", "Your steps and shots are muffled.", [{"value": "FOOTSTEP_NOISE", "multiply": -0.9}, {"value": "ATTACK_NOISE", "multiply": -0.5}]),
 eff("trl_nano_night_eye", "Night Eye", "Your optics amplify light.", [{"value": "NIGHT_VIS", "add": 6}]),
]
# all 20 programs: id -> (tree, display)
ALL = {
 "trl_nano_repair": "Mend", "trl_nano_purge": "Mend",
 "trl_nano_plating": "Shell", "trl_nano_reactive": "Shell",
 "trl_nano_overclock": "Reflex", "trl_nano_afterimage": "Reflex",
 "trl_nano_lock_on": "Strike", "trl_nano_shock_field": "Strike",
 "trl_nano_cloak": "Ghost", "trl_nano_dampener": "Ghost",
 "trl_nano_pulse_scan": "Sense", "trl_nano_night_eye": "Sense",
 "trl_hack_overload": "Intrude", "trl_hack_blind": "Intrude", "trl_hack_lock": "Intrude",
 "trl_nano_print_ammo": "Fabricate", "trl_nano_print_kit": "Fabricate",
 "trl_nano_blink": "Phase", "trl_nano_hop": "Phase",
 "trl_nano_siphon": "Drain",
}
assert len(ALL) == 20 and len(set(ALL.values())) == 10
RENAME = {"trl_nano_repair": "Mend: Repair", "trl_nano_plating": "Shell: Plating", "trl_nano_overclock": "Reflex: Overclock",
          "trl_hack_overload": "Intrude: Overload", "trl_hack_blind": "Intrude: Blind", "trl_hack_lock": "Intrude: Lockdown"}
cp = os.path.join(MOD, "combat.json")
combat = json.load(open(cp))
for x in combat:
    if x.get("type") == "SPELL" and x["id"] in RENAME: x["name"] = RENAME[x["id"]]
    if x.get("type") == "effect_type" and x["id"] == "trl_nano_plating": x["name"] = ["Shell Plating"]
json.dump(combat, open(cp, "w"), indent=2)
names = {s["id"]: s["name"] for s in NEW}; names.update(RENAME)
TREECOLOR = {"Mend": "light_green", "Shell": "light_gray", "Reflex": "yellow", "Strike": "light_red", "Ghost": "dark_gray",
             "Sense": "light_cyan", "Intrude": "light_blue", "Fabricate": "white", "Phase": "magenta", "Drain": "pink"}
items = []
for sid, tree in ALL.items():
    items.append({"type": "ITEM", "subtypes": ["GENERIC"], "id": "trl_chip_" + sid.replace("trl_", ""), "name": {"str": f"nano chip ({names[sid]})", "str_pl": f"nano chips ({names[sid]})"},
                  "description": f"A data chip holding the {names[sid]} program.  Study it to learn the program.  Needs a cyber brain to run.",
                  "weight": "5 g", "volume": "5 ml", "symbol": "=", "color": TREECOLOR[tree], "material": ["plastic"],
                  "price": "600 USD", "price_postapoc": "50 USD", "flags": ["TRADER_AVOID"],
                  "use_action": {"type": "learn_spell", "spells": [sid]}})
groups = [
 {"type": "item_group", "id": "trl_loot_chips", "subtype": "distribution", "entries": [{"item": i["id"]} for i in items]},
 {"type": "item_group", "id": "trl_new_chips", "subtype": "collection",
  "entries": [{"item": i["id"]} for i in items if i["id"].replace("trl_chip_", "trl_") not in
              ("trl_nano_repair", "trl_nano_plating", "trl_nano_overclock", "trl_hack_overload", "trl_hack_blind", "trl_hack_lock")]},
]
trees = [{"tree": t, "blurb": b, "programs": [names[k] for k, v in ALL.items() if v == t]} for t, b in TREES.items()]
json.dump(NEW + EFFECTS + items + groups, open(os.path.join(MOD, "nanos.json"), "w"), indent=1)
json.dump(trees, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "nano_trees.json"), "w"), indent=1)
# give the Combat Test start one of every new chip
pp = os.path.join(MOD, "professions.json")
p = json.load(open(pp))
for x in p:
    if x.get("id") == "trl_test_combat":
        ents = x["items"]["both"]["entries"]
        if not any(e.get("group") == "trl_new_chips" for e in ents): ents.append({"group": "trl_new_chips"})
json.dump(p, open(pp, "w"), indent=2)
print(len(NEW), "new spells,", len(items), "chips")
for t in trees: print(t["tree"], "-", ", ".join(t["programs"]))
