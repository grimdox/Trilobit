#!/usr/bin/env python3
"""Androids (Milestone 24, design doc section K): hackable synthetic workers, built from four parts.
   frame (body) x role (job) x firmware (behavior and security).  Add a row to a table to add content.
usage: gen_androids.py <mod dir>  -> <mod>/androids.json
Hacking nanohacks (Probe, Disrupt, Take Over) are declared in gen_nanohacks.py and call the EOCs defined here.
"""
import json, os, sys

# ---- frames: stat bonuses (npc_class), hit-point modifier (trait), description
FRAMES = {
    "civ":   dict(name="civilian frame", desc="A light, human-like frame for service work.", hp=0.0, bonus={"dex": 1, "per": 1}),
    "labor": dict(name="labor frame", desc="A strong, slow frame built for lifting and hauling.", hp=0.3, bonus={"str": 5, "dex": -1}),
    "sec":   dict(name="security frame", desc="An armored frame with reinforced limbs and fast reflexes.", hp=0.5, bonus={"str": 3, "dex": 2, "per": 2}),
}
# ---- roles: worn, carried, weapon groups (item, weight), routine kind, which frames fit, hours text
ROLES = {
    "porter": dict(name="porter", routine="roam", frames=["labor", "civ"], worn=["jumpsuit", "boots_combat", "gloves_light"],
                   carry=[("crowbar", 40)], weapon=[("pipe", 50), ("crowbar", 50)], chat="Cargo goes where the list says.  Please keep clear.",
                   skills={"melee": 3, "dodge": 2}),
    "clerk":  dict(name="shop attendant", routine="post", frames=["civ"], worn=["suit", "dress_shoes"], carry=[], weapon=[],
                   chat="Welcome.  How may I help you?", skills={"speech": 5}, shop=["food", "tool", "decor"]),
    "vendor": dict(name="food vendor", routine="post", frames=["civ"], worn=["tshirt", "jeans", "sneakers"], carry=[], weapon=[],
                   chat="Hot food, cheap.  What'll it be?", skills={"speech": 4, "cooking": 5}, shop=["food"]),
    "bartender": dict(name="bartender", routine="post", frames=["civ"], worn=["suit", "dress_shoes"], carry=[], weapon=[],
                   chat="What can I pour for you?", skills={"speech": 5}, shop=["drink"]),
    "techclerk": dict(name="electronics clerk", routine="post", frames=["civ"], worn=["suit", "dress_shoes"], carry=[], weapon=[],
                   chat="Parts, chips, nanohacks.  Take a look.", skills={"speech": 4, "computer": 6}, shop=["tech", "chips"]),
    "medclerk": dict(name="clinic attendant", routine="post", frames=["civ"], worn=["suit", "dress_shoes"], carry=[], weapon=[],
                   chat="Medical supplies.  What do you need?", skills={"speech": 4, "firstaid": 6}, shop=["med"]),
    "reception": dict(name="receptionist", routine="post", frames=["civ"], worn=["suit", "dress_shoes"], carry=[], weapon=[],
                   chat="Welcome.  Please state your business.", skills={"speech": 5}),
    "guard":  dict(name="guard", routine="post", frames=["sec", "civ"], worn=["ballistic_vest_light", "pants_cargo", "boots_combat", "gloves_light"],
                   carry=[], weapon=[("baton-extended", 50), ("trl_gun_vp9", 50)], chat="Move along.  This area is monitored.",
                   skills={"melee": 4, "pistol": 3, "dodge": 3}),
}
# ---- firmware: security level (hack difficulty), obeys, description
FIRMWARE = {
    "stock":    dict(name="stock firmware", sec=1, desc="Owner-locked work program with minimal security."),
    "hardened": dict(name="hardened firmware", sec=3, desc="Corporate-grade work program that counter-hacks and raises alarms."),
}

SHOP = {  # tag -> [(item or group, min, max)]
    "food": [("sake_filtered", 2, 6), ("tea_green", 2, 6), ("rice_cooked", 3, 8), ("sushi_fishroll", 2, 6), ("noodles_fast", 3, 8), ("cola", 3, 8), ("energy_drink", 2, 6), ("candy", 3, 9)],
    "drink": [("sake_filtered", 4, 10), ("beer", 4, 10), ("cola", 3, 8), ("tea_green", 3, 8), ("energy_drink", 3, 6), ("water_clean", 4, 10), ("cigar", 2, 6), ("lighter", 1, 3)],
    "tech": [("circuit", 2, 6), ("processor", 1, 4), ("RAM", 1, 4), ("cable", 3, 8), ("e_scrap", 3, 8), ("amplifier", 1, 3), ("small_lcd_screen", 1, 3), ("light_battery_cell", 2, 6), ("flashlight", 1, 3)],
    "med": [("bandages", 3, 8), ("aspirin", 2, 6), ("vitamins", 2, 6), ("water_clean", 3, 8), ("disinfectant", 1, 3)],
    "tool": [("wrench", 1, 2), ("screwdriver", 1, 3), ("hammer", 1, 2), ("crowbar", 1, 2), ("duct_tape", 1, 3), ("scrap", 3, 8), ("pipe", 1, 3), ("flashlight", 1, 3)],
    "decor": [("kimono", 1, 2), ("umbrella", 1, 3), ("candle", 2, 6), ("tshirt", 2, 5), ("jacket_light", 1, 3), ("cash_card", 1, 2)],
    "chips": [("trl_loot_chips", 2, 5)],
}

def cls(fr, ro, fw): return f"trl_nc_andr_{fr}_{ro}_{fw}"

def build():
    out = []
    probe_msg = [{"npc_message": "That is not an android; nothing answers the order.", "type": "info"}]
    # marker traits (hidden; "valid": false keeps them out of character creation)
    base = {"type": "mutation", "points": 0, "visibility": 0, "ugliness": 0, "valid": False, "purifiable": False, "player_display": False}
    out.append(dict(base, id="trl_android", name={"str": "Android"}, description="A synthetic body running a work program.  It carries a networked controller, so it can be probed and hacked."))
    for f, d in FRAMES.items():
        o = dict(base, id=f"trl_andr_frame_{f}", name={"str": d["name"].capitalize()}, description=d["desc"])
        if d["hp"]: o["enchantments"] = [{"values": [{"value": "MAX_HP", "multiply": d["hp"]}]}]
        out.append(o)
    for r, d in ROLES.items():
        out.append(dict(base, id=f"trl_andr_role_{r}", name={"str": d["name"].capitalize()}, description=f"Work program: {d['name']}."))
    for w, d in FIRMWARE.items():
        out.append(dict(base, id=f"trl_andr_fw_{w}", name={"str": d["name"].capitalize()}, description=d["desc"]))
    # shops: merchants use a faction that trades in yen
    out.append({"type": "faction", "id": "trl_merchants", "name": "Merchants", "description": "Shopkeepers and their staff.", "mon_faction": "human",
                "likes_u": 0, "respects_u": 0, "known_by_u": False, "size": 100, "power": 100,
                "fac_food_supply": [[0, {"calories": 0, "vitamins": {}}]], "wealth": 20000000, "currency": "trl_yen", "price_rules": [], "relations": {}})
    for tag, ents in SHOP.items():
        out.append({"type": "item_group", "id": f"trl_shop_{tag}", "subtype": "collection",
                    "entries": [({"group": i, "count": [a, b]} if i.startswith("trl_loot") else {"item": i, "count": [a, b]}) for i, a, b in ents]})
    # item groups, classes, templates
    for r, d in ROLES.items():
        out.append({"type": "item_group", "id": f"trl_andr_worn_{r}", "subtype": "collection", "entries": [{"item": i} for i in d["worn"]]})
        out.append({"type": "item_group", "id": f"trl_andr_weapon_{r}", "subtype": "distribution",
                    "entries": [{"item": i, "prob": p} for i, p in d["weapon"]]})
        out.append({"type": "item_group", "id": f"trl_andr_carry_{r}", "subtype": "distribution",
                    "entries": [{"item": i, "prob": p} for i, p in d["carry"]]})
    for fw, fd in FIRMWARE.items():
        for r, rd in ROLES.items():
            for f in rd["frames"]:
                fr = FRAMES[f]
                c = {"type": "npc_class", "id": cls(f, r, fw), "name": {"str": f"{rd['name'].capitalize()} android"},
                     "job_description": f"I'm a {rd['name']} android.", "common": False,
                     "worn_override": f"trl_andr_worn_{r}", "weapon_override": f"trl_andr_weapon_{r}", "carry_override": f"trl_andr_carry_{r}",
                     "traits": [{"trait": t} for t in ("trl_android", f"trl_andr_frame_{f}", f"trl_andr_role_{r}", f"trl_andr_fw_{fw}")],
                     "skills": [{"skill": "ALL", "level": {"constant": 2}}] + [{"skill": k, "level": {"constant": v}} for k, v in rd["skills"].items()]}
                if rd.get("shop"):
                    c["shopkeeper_item_group"] = [{"group": f"trl_shop_{t}", "rigid": True} for t in rd["shop"]]
                for k, v in fr["bonus"].items():
                    c["bonus_" + k] = {"constant": v}
                out.append(c)
                out.append({"type": "npc", "id": cls(f, r, fw), "class": cls(f, r, fw), "attitude": 0, "mission": 7, "faction": "trl_merchants" if rd.get("shop") else "no_faction",
                            "chat": "TRL_ANDROID_TALK_" + r, "temp_suffix": f"{rd['name']} android"})
    # ---- talk
    for r, rd in ROLES.items():
        resp = []
        if rd.get("shop"):
            resp.append({"text": "Let's trade.", "effect": "start_trade", "topic": "TALK_DONE"})
        resp.append({"text": "Never mind.", "topic": "TALK_DONE"})
        out.append({"type": "talk_topic", "id": "TRL_ANDROID_TALK_" + r, "dynamic_line": rd["chat"], "responses": resp})
    # ---- routine: battery, dock, roam or post
    out += [
        {"type": "effect_on_condition", "id": "trl_andr_tick", "recurrence": ["15 minutes", "20 minutes"], "global": True,
         "effect": [{"u_run_npc_eocs": ["trl_andr_step"], "overmap": True}]},
        {"type": "effect_on_condition", "id": "trl_andr_step",
         "condition": {"and": [{"u_has_trait": "trl_android"}, {"not": "u_following"}, {"math": ["u_trl_skip_until < time('now')"]}]},
         "effect": [
             {"run_eocs": ["trl_andr_init_once"]},
             {"run_eocs": ["trl_andr_hours"]},
             {"if": {"or": [{"math": ["u_npc_anger() > 0"]}, {"math": ["u_npc_fear() > 0"]}]},
              "then": [{"math": ["u_trl_skip_until = time('now') + time('10 m')"]}],
              "else": [{"run_eocs": ["trl_andr_battery"]},
                       {"if": {"math": ["u_andr_battery <= 0"]},
                        "then": [{"u_add_effect": "stunned", "duration": "20 minutes", "target": "bp"}] if False else [{"u_add_effect": "stunned", "duration": "20 minutes"}],
                        "else": [{"if": {"math": ["u_andr_charging == 1"]}, "then": [{"run_eocs": ["trl_andr_charge"]}],
                                  "else": [{"if": {"u_has_trait": "trl_andr_role_porter"}, "then": [{"run_eocs": ["trl_andr_roam"]}],
                                            "else": [{"run_eocs": ["trl_andr_post"]}]}]}]}]}]},
        {"type": "effect_on_condition", "id": "trl_andr_init_once", "condition": {"math": ["u_andr_inited == 0"]},
         "effect": [{"u_location_variable": {"u_val": "andr_dock"}}, {"math": ["u_andr_inited = 1"]}, {"math": ["u_andr_battery = 100"]},
                    {"math": ["u_andr_charging = 0"]}]},
        {"type": "effect_on_condition", "id": "trl_andr_battery",
         "effect": [{"if": {"math": ["u_andr_charging == 0"]}, "then": [{"math": ["u_andr_battery = max(0, u_andr_battery - 2)"]}]},
                    {"if": {"and": [{"math": ["u_andr_charging == 0"]}, {"math": ["u_andr_battery <= 15"]}]},
                     "then": [{"math": ["u_andr_charging = 1"]}, {"u_go_to_loc": {"u_val": "andr_dock"}}]}]},
        # charging: sit at the dock, +12 per tick, resume at 95
        {"type": "effect_on_condition", "id": "trl_andr_charge",
         "effect": [{"if": {"math": ["distance('u', u_andr_dock) > 2"]}, "then": [{"u_go_to_loc": {"u_val": "andr_dock"}}],
                     "else": [{"math": ["u_andr_battery = min(100, u_andr_battery + 12)"]}]},
                    {"if": {"math": ["u_andr_battery >= 95"]}, "then": [{"math": ["u_andr_charging = 0"]}]}]},
        # post: stay within 3 tiles of the dock
        {"type": "effect_on_condition", "id": "trl_andr_post",
         "effect": [{"if": {"math": ["distance('u', u_andr_dock) > 3"]}, "then": [{"u_go_to_loc": {"u_val": "andr_dock"}}]}]},
        # roam: wander within 8 tiles of the dock
        {"type": "effect_on_condition", "id": "trl_andr_goto_spot", "effect": [{"u_go_to_loc": {"u_val": "andr_spot"}}]},
        {"type": "effect_on_condition", "id": "trl_andr_roam",
         "effect": [{"if": {"or": [{"math": ["distance('u', u_andr_dock) > 12"]}, {"math": ["rand(4) == 0"]}]},
                     "then": [{"u_go_to_loc": {"u_val": "andr_dock"}}],
                     "else": [{"u_location_variable": {"u_val": "andr_spot"}, "max_radius": 8, "passable_only": True, "true_eocs": ["trl_andr_goto_spot"]}]}]},
    ]
    # ---- opening hours: attendants unlock their shop doors while open and seal them while closed
    hnow = "time_since('midnight','unit':'hours')"
    hrs = []
    for role, (a, b) in HOURS.items():
        if a < b:
            openc = {"and": [{"math": [f"{hnow} >= {a}"]}, {"math": [f"{hnow} < {b}"]}]}
        else:
            openc = {"or": [{"math": [f"{hnow} >= {a}"]}, {"math": [f"{hnow} < {b}"]}]}
        hrs.append({"if": {"u_has_trait": f"trl_andr_role_{role}"},
                    "then": [{"if": openc, "then": [{"u_transform_radius": 10, "ter_furn_transform": "trl_elock_unlock"}],
                              "else": [{"u_transform_radius": 10, "ter_furn_transform": "trl_elock_seal"}]}]})
    out.append({"type": "effect_on_condition", "id": "trl_andr_hours", "effect": hrs})
    # ---- Command: orders for an android you own (u = the android, npc = the caster)
    owned = {"math": ["u_andr_owned == 1"]}
    def order(oid, text, effect):
        out.append({"type": "effect_on_condition", "id": "trl_andr_ord_" + oid, "effect": effect + [{"npc_message": text, "type": "good"}]})
        return "trl_andr_ord_" + oid
    ords = [
        (order("follow", "It falls in behind you.", [{"u_recruit_npc": True}]), "Follow me"),
        (order("hold", "It stands its ground here.", [{"u_dismiss_npc": True, "faction": "your_followers"}]), "Hold this position"),
        (order("post", "It takes up a post here and goes back to its work.", [{"u_location_variable": {"u_val": "andr_dock"}}, {"math": ["u_andr_charging = 0"]},
                                                                              {"u_dismiss_npc": True, "faction": "no_faction"}]), "Work a post here"),
        (order("door", "It slides the nearby security doors open.", [{"u_transform_radius": 6, "ter_furn_transform": "trl_elock_override"}]), "Open the doors around you"),
        (order("seal", "It seals the nearby security doors.", [{"u_transform_radius": 6, "ter_furn_transform": "trl_elock_seal"}]), "Seal the doors around you"),
        (order("release", "It drops your orders and returns to its own routine.", [{"math": ["u_andr_owned = 0"]}, {"u_dismiss_npc": True, "faction": "no_faction"}]), "Release it"),
    ]
    out.append({"type": "effect_on_condition", "id": "trl_andr_hk_command",
                "effect": [{"if": {"u_has_trait": "trl_android"},
                            "then": [{"if": owned,
                                      "then": [{"run_eoc_selector": [e for e, _ in ords], "names": [n for _, n in ords], "keys": list("abcdef"),
                                                "allow_cancel": True, "title": "Command <u_name>"}],
                                      "else": [{"npc_message": "You do not own this android.  Take it over first.", "type": "bad"}]}],
                            "else": probe_msg}]})
    # ---- hacking effects (u = the target android, npc = the caster)
    def info():
        return "Android <u_name>: "
    probe = [{"npc_message": "That is not an android; nothing answers the probe.", "type": "info"}]
    out.append({"type": "effect_on_condition", "id": "trl_andr_hk_probe",
                "effect": [{"if": {"u_has_trait": "trl_android"},
                            "then": [{"npc_message": "Probe: <u_name>.  Battery <u_val:andr_battery>%.", "type": "info"}]
                                    + [{"if": {"u_has_trait": f"trl_andr_frame_{f}"}, "then": [{"npc_message": f"  Frame: {d['name']}.", "type": "info"}]} for f, d in FRAMES.items()]
                                    + [{"if": {"u_has_trait": f"trl_andr_role_{r}"}, "then": [{"npc_message": f"  Role: {d['name']}.", "type": "info"}]} for r, d in ROLES.items()]
                                    + [{"if": {"u_has_trait": f"trl_andr_fw_{w}"}, "then": [{"npc_message": f"  Firmware: {d['name']} (security {d['sec']}).", "type": "info"}]} for w, d in FIRMWARE.items()]
                                    + [{"if": "u_following", "then": [{"npc_message": "  Owner: you.", "type": "info"}], "else": [{"npc_message": "  Owner: someone else.", "type": "info"}]}],
                            "else": probe}]})
    out.append({"type": "effect_on_condition", "id": "trl_andr_hk_disrupt",
                "effect": [{"if": {"u_has_trait": "trl_android"},
                            "then": [{"if": {"u_has_trait": "trl_andr_fw_hardened"},
                                      "then": [{"npc_message": "The hardened firmware shrugs it off and raises an alarm.", "type": "bad"}, {"u_make_angry": True} if False else {"math": ["u_npc_anger() = max(u_npc_anger(), 5)"]}] ,
                                      "else": [{"u_add_effect": "stunned", "duration": "30 seconds"}, {"npc_message": "The android's routine crashes; it freezes for a moment.", "type": "good"}]}],
                            "else": probe}]})
    out.append({"type": "effect_on_condition", "id": "trl_andr_hk_takeover",
                "effect": [{"if": {"u_has_trait": "trl_android"},
                            "then": [{"if": {"u_has_trait": "trl_andr_fw_hardened"},
                                      "then": [{"npc_message": "Its firmware is hardened; the takeover fails and it turns on you.", "type": "bad"}, {"math": ["u_npc_anger() = max(u_npc_anger(), 5)"]}],
                                      "else": [{"u_recruit_npc": True}, {"math": ["u_andr_owned = 1"]}, {"npc_message": "You rewrite its ownership.  It falls in behind you.", "type": "good"}]}],
                            "else": probe}]})
    out.append({"type": "effect_on_condition", "id": "trl_andr_release",
                "effect": [{"u_dismiss_npc": True, "faction": "no_faction"}]})
    return out

HOURS = {"clerk": (7, 22), "techclerk": (7, 22), "medclerk": (7, 22), "reception": (7, 22), "bartender": (12, 3)}  # role: (open hour, close hour)

PLACEMENT = {  # place id -> list of (frame, role, firmware)
    "trl_pl_convenience_store": [("civ", "clerk", "stock")],
    "trl_pl_electronics_bazaar": [("civ", "techclerk", "stock"), ("sec", "guard", "stock")],
    "trl_pl_implant_clinic": [("civ", "medclerk", "stock"), ("sec", "guard", "stock")],
    "trl_pl_corp_lobby": [("sec", "guard", "hardened"), ("sec", "guard", "hardened"), ("civ", "reception", "hardened")],
    "trl_pl_govt_office": [("sec", "guard", "hardened"), ("civ", "reception", "hardened")],
    "trl_pl_server_hall": [("sec", "guard", "hardened")],
    "trl_pl_transit_station": [("sec", "guard", "stock")],
    "trl_pl_cargo_warehouse": [("labor", "porter", "stock"), ("labor", "porter", "stock")],
    "trl_pl_canal_dock": [("labor", "porter", "stock")],
    "trl_pl_mech_garage": [("labor", "porter", "stock")],
    "trl_pl_izakaya": [("civ", "bartender", "stock")],
    "trl_pl_neon_lounge": [("civ", "bartender", "stock")],
    "trl_pl_tea_house": [("civ", "bartender", "stock")],
    "trl_pl_noodle_alley": [("civ", "vendor", "stock")],
    "trl_pl_night_market": [("civ", "vendor", "stock"), ("civ", "vendor", "stock")],
}
ATM_PLACES = ["trl_pl_convenience_store", "trl_pl_electronics_bazaar", "trl_pl_implant_clinic", "trl_pl_corp_lobby", "trl_pl_govt_office",
              "trl_pl_transit_station", "trl_pl_capsule_hotel", "trl_pl_arcade_hall"]

JACK_PLACES = ["trl_pl_server_hall", "trl_pl_arcade_hall", "trl_pl_electronics_bazaar", "trl_pl_corp_lobby", "trl_pl_transit_station", "trl_pl_capsule_hotel"]

def android_npcs(place_id):
    return [cls(*t) for t in PLACEMENT.get(place_id, [])]

if __name__ == "__main__":
    json.dump(build(), open(os.path.join(sys.argv[1], "androids.json"), "w"), indent=1)
    print("android classes:", sum(len(r["frames"]) for r in ROLES.values()) * len(FIRMWARE))
