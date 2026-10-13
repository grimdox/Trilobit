#!/usr/bin/env python3
"""Generate Trilobit factions: Bratva, JSDF, Nasim.  usage: gen_factions.py <mod dir>
Writes <mod>/factions.json.  Imported by gen_places.py for BAR_NPCS."""
import json, os, sys

FAC = {
    "trl_bratva": ("Bratva", "A criminal syndicate that taxes the poor districts."),
    "trl_jsdf":   ("JSDF", "City police and military.  Placeholder name."),
    "trl_nasim":  ("Nasim", "Cyberterrorists who hate implanted people.  Placeholder name."),
}
SHORT = {"trl_bratva": "bratva", "trl_jsdf": "jsdf", "trl_nasim": "nasim"}
ENEMIES = {"trl_bratva": ["trl_jsdf", "trl_nasim"], "trl_jsdf": ["trl_bratva", "trl_nasim"], "trl_nasim": ["trl_jsdf", "trl_bratva"]}
# (class id suffix, title, worn[], weapons[(item, prob)], carry extras, skills)
MEMBERS = {
    "trl_bratva": [
        ("thug", "Street thug", ["jacket_leather", "jeans", "boots_hiking", "tshirt"], [("pipe", 30), ("trl_kama", 15), ("knife_combat", 25), ("trl_gun_vp9", 30)], {"melee": 3, "pistol": 2}),
        ("enforcer", "Enforcer", ["trenchcoat_leather", "ballistic_vest_light", "pants_cargo", "boots_combat", "gloves_light"], [("trl_gun_va7", 40), ("tec9", 40), ("machete", 20)], {"smg": 4, "melee": 3}),
        ("fixer", "Fixer", ["suit", "tie_necktie", "dress_shoes", "trenchcoat"], [("trl_gun_gr44", 40)], {"speech": 6, "pistol": 3}),
    ],
    "trl_jsdf": [
        ("patrol", "Patrol officer", ["leather_police_jacket", "pants_cargo", "boots_combat", "ballistic_vest_light"], [("trl_gun_hp9", 60), ("baton-extended", 40)], {"pistol": 3, "melee": 2}),
        ("riot", "Riot trooper", ["armor_riot", "helmet_riot", "boots_combat", "gloves_light"], [("trl_gun_hs12", 60), ("baton-extended", 40)], {"shotgun": 4, "melee": 3}),
        ("tactical", "Tactical operator", ["trl_kp_vest", "trl_kp_helmet", "pants_army", "boots_combat", "gloves_light"], [("trl_gun_ga5", 50), ("trl_gun_gs300", 30), ("katana", 20), ("trl_gun_w2011", 4)], {"smg": 6, "rifle": 5, "melee": 4}),
    ],
    "trl_nasim": [
        ("hacker", "Script-hacker", ["hoodie", "jeans", "sneakers", "gloves_light"], [("trl_gun_lp5", 30), ("knife_folding", 30)], {"computer": 7, "electronics": 5, "pistol": 2}),
        ("saboteur", "Saboteur", ["jacket_windbreaker", "pants_cargo", "boots_rubber", "mask_dust"], [("grenade", 40), ("mac_10", 40)], {"traps": 5, "launcher": 2, "pistol": 3}),
        ("zealot", "Zealot", ["jumpsuit", "trenchcoat", "boots_combat"], [("katana", 40), ("tanto", 20), ("machete", 20), ("trl_kusarigama", 20)], {"melee": 7, "cutting": 6, "dodge": 4}),
    ],
}
NH = {"hacker": ["trl_nh_overload", "trl_nh_blind"], "zealot": ["trl_nh_shock_field", "trl_nh_siphon"], "tactical": ["trl_nh_lock_on"]}
CYBER = {"zealot": 100, "tactical": 60, "hacker": 70, "enforcer": 30}
# bar npcs: place id -> faction, [(class suffix or 'contact', x, y)]
BARS = {
    "trl_pl_izakaya":     ("trl_jsdf",   [("contact", 9, 11), ("patrol", 14, 11), ("patrol", 4, 17)]),
    "trl_pl_neon_lounge": ("trl_bratva", [("contact", 8, 12), ("thug", 14, 12), ("enforcer", 8, 16)]),
    "trl_pl_tea_house":   ("trl_nasim",  [("contact", 8, 11), ("hacker", 14, 11), ("zealot", 9, 16)]),
}


def bar_npcs(place_id):
    """[(npc template id, x, y)] for a place, or []"""
    if place_id not in BARS:
        return []
    fac, lst = BARS[place_id]
    s = SHORT[fac]
    return [((f"trl_nc_{s}_contact" if kind == "contact" else f"trl_nc_{s}_{kind}"), x, y) for kind, x, y in lst]


def build():
    out = []
    for fid, (nm, desc) in FAC.items():
        rel = {}
        for other in FAC:
            if other == fid:
                rel[other] = {"kill on sight": False, "watch your back": True, "share my stuff": True, "guard your stuff": True,
                              "lets you in": True, "defends your space": True, "knows your voice": True}
            else:
                hostile = other in ENEMIES[fid]
                rel[other] = {"kill on sight": hostile, "watch your back": False, "share my stuff": False,
                              "guard your stuff": False, "lets you in": False, "defends your space": False, "knows your voice": False}
        out.append({"type": "faction", "id": fid, "name": nm, "description": desc, "likes_u": 0, "respects_u": 0, "trusts_u": 0,
                    "known_by_u": True, "size": 100, "power": 100,
                    "fac_food_supply": [[0, {"calories": 0, "vitamins": {}}]], "wealth": 5000000, "currency": "trl_yen",
                    "price_rules": [], "relations": rel})
    # alignment traits and hobbies
    for key, nm in (("jsdf", "JSDF-aligned"), ("bratva", "Bratva-aligned")):
        out.append({"type": "mutation", "id": f"trl_align_{key}", "name": {"str": nm}, "points": 0, "visibility": 0, "ugliness": 0,
                    "description": "Starting faction alignment.", "valid": False, "purifiable": False})
        out.append({"type": "profession", "subtype": "hobby", "id": f"trl_hobby_{key}", "name": nm,
                    "description": {"JSDF-aligned": "You have friends in the JSDF.  Bratva wants you dead; the JSDF will deal with you.",
                                    "Bratva-aligned": "You have friends in the Bratva.  The JSDF hunts you."}[nm],
                    "points": 0, "traits": [f"trl_align_{key}"]})
    # member groups, classes, templates
    for fid, mem in MEMBERS.items():
        s = SHORT[fid]
        for suf, title, worn, weapons, skills in mem:
            cid = f"trl_nc_{s}_{suf}"
            out.append({"type": "item_group", "id": cid + "_worn", "subtype": "collection", "entries": [{"item": i} for i in worn]})
            out.append({"type": "item_group", "id": cid + "_weapon", "subtype": "distribution",
                        "entries": [{"item": i, "prob": p} for i, p in weapons]})
            out.append({"type": "item_group", "id": cid + "_carry", "subtype": "collection",
                        "entries": [{"item": "trl_yen", "count": [50, 600]}]})
            cl = {"type": "npc_class", "id": cid, "name": {"str": title}, "job_description": f"I'm {title.lower()} for {FAC[fid][0]}.",
                  "common": False, "worn_override": cid + "_worn", "weapon_override": cid + "_weapon", "carry_override": cid + "_carry",
                  "traits": [{"trait": "trl_resident", "prob": 0}],
                  "skills": [{"skill": "ALL", "level": {"constant": 2}}] + [{"skill": k, "level": {"constant": v}} for k, v in skills.items()]}
            cl["traits"] = [{"trait": "trl_alert_aware"}]
            cl["bonus_aggression"] = {"constant": 8}
            cl["bonus_bravery"] = {"constant": 10}
            if suf in CYBER:
                cl["bionics"] = [{"id": "trl_bio_cyberbrain", "chance": CYBER[suf]}, {"id": "bio_power_storage_mkII", "chance": CYBER[suf]}]
            if suf in NH:
                cl["spells"] = [{"id": sp, "level": 1} for sp in NH[suf]]
            out.append(cl)
            out.append({"type": "npc", "id": cid, "class": cid, "attitude": 0, "mission": 7, "faction": fid,
                        "chat": "TRL_FACTION_MEMBER", "temp_suffix": title})
        # contact (civil, unarmed-looking)
        cid = f"trl_nc_{s}_contact"
        out.append({"type": "item_group", "id": cid + "_worn", "subtype": "collection",
                    "entries": [{"item": i} for i in ("jacket_leather", "jeans", "boots_hiking", "tshirt")]})
        out.append({"type": "npc_class", "id": cid, "name": {"str": f"{FAC[fid][0]} contact"},
                    "job_description": "I know who needs what done.", "common": False, "worn_override": cid + "_worn",
                    "skills": [{"skill": "ALL", "level": {"constant": 2}}, {"skill": "speech", "level": {"constant": 6}}]})
        out.append({"type": "npc", "id": cid, "class": cid, "attitude": 0, "mission": 7, "faction": fid,
                    "chat": f"TRL_CONTACT_{s.upper()}", "temp_suffix": f"{FAC[fid][0]} contact"})
        # contact dialogue
        r = f"trl_rank_{s}"
        out.append({"type": "talk_topic", "id": f"TRL_CONTACT_{s.upper()}",
                    "dynamic_line": {"math": [f"{r} <= -4"],
                                     "yes": "I don't talk to you.  Leave before somebody gets hurt.",
                                     "no": {"math": [f"{r} <= 0"], "yes": "A stranger.  Buy a drink or move along.",
                                            "no": {"math": [f"{r} <= 3"], "yes": "You again.  You keep your head down, which I like.",
                                                   "no": "Good to see you.  Sit.  What do you need?"}}},
                    "responses": [
                        {"text": "I'm looking for work.", "topic": f"TRL_CONTACT_{s.upper()}_WORK",
                         "condition": {"math": [f"{r} > -4"]}},
                        {"text": "Where do I stand with you?", "topic": f"TRL_CONTACT_{s.upper()}_STAND"},
                        {"text": "Never mind.", "topic": "TALK_DONE"}]})
        facn = {"bratva": 1, "jsdf": 2, "nasim": 3}[s]
        def acc(state, mid, npc_cls, uid, place):
            eff = [{"math": ["trl_t_fac", "=", str(facn)]}, {"math": ["trl_t_state", "=", str(state)]}, {"math": ["trl_t_dead", "=", "0"]},
                   {"math": ["trl_spy_progress", "=", "0"]}, {"u_location_variable": {"global_val": "trl_t_term_loc"}}]
            if npc_cls:
                eff += [{"set_string_var": npc_cls, "target_var": {"global_val": "trl_t_npc"}}, {"set_string_var": uid, "target_var": {"global_val": "trl_t_uid"}}]
            return eff + [{"run_eocs": place}, {"assign_mission": mid}]
        def rep(label, mid, extra=None):
            c = {"u_has_mission": mid}
            if extra: c = {"and": [c, extra]}
            return {"text": label, "topic": f"TRL_CONTACT_{s.upper()}_PAID", "condition": c, "effect": [{"finish_mission": mid, "success": True}]}
        idle = {"math": ["trl_t_state == 0"]}
        out.append({"type": "talk_topic", "id": f"TRL_CONTACT_{s.upper()}_WORK",
                    "dynamic_line": {"math": [f"{r} <= 0"], "yes": "Nothing for strangers.  Do something useful first.",
                                     "no": {"math": ["trl_t_state == 0"], "yes": "I have a few things that need doing.  Pays 1500 yen and a good word.",
                                            "no": "You are already carrying a job.  Finish it or drop it first."}},
                    "responses": [
                        rep("[Report] Here is the data core.", "TRL_T_R2", {"u_has_item": "trl_data_core"}),
                        rep("[Report] The target is dead.", "TRL_T_A3"),
                        rep("[Report] I watched the subject, as asked.", "TRL_T_S2"),
                        {"text": "[Retrieval] Recover a package and bring it back.", "topic": "TALK_DONE", "condition": {"and": [{"math": [f"{r} > 0"]}, idle]},
                         "effect": acc(1, "TRL_T_R1", None, None, "trl_t_place_item")},
                        {"text": "[Removal] Find a target and deal with him.", "topic": "TALK_DONE", "condition": {"and": [{"math": [f"{r} > 0"]}, idle]},
                         "effect": acc(2, "TRL_T_A1", "trl_t_target", "trl_t_uid_target", "trl_t_place_npc")},
                        {"text": "[Surveillance] Watch somebody for me.", "topic": "TALK_DONE", "condition": {"and": [{"math": [f"{r} > 0"]}, idle]},
                         "effect": acc(3, "TRL_T_S1", "trl_t_subject", "trl_t_uid_subject", "trl_t_place_npc")},
                        {"text": "Drop the job I am carrying.", "topic": "TALK_DONE", "condition": {"math": ["trl_t_state > 0"]},
                         "effect": [{"if": {"u_has_mission": m}, "then": {"finish_mission": m, "success": False}} for m in
                                    ("TRL_T_R1", "TRL_T_R2", "TRL_T_A1", "TRL_T_A2", "TRL_T_A3", "TRL_T_S1", "TRL_T_S2")] + [{"run_eocs": "trl_t_cleanup"}]},
                        {"text": "Alright.", "topic": "TALK_DONE"}]})
        out.append({"type": "talk_topic", "id": f"TRL_CONTACT_{s.upper()}_PAID", "dynamic_line": "Good.  That is how this works.  Your pay is in your hand.",
                    "responses": [{"text": "Anything else?", "topic": f"TRL_CONTACT_{s.upper()}_WORK"}, {"text": "Later.", "topic": "TALK_DONE"}]})
        out.append({"type": "talk_topic", "id": f"TRL_CONTACT_{s.upper()}_STAND",
                    "dynamic_line": {"math": [f"{r} <= -7"], "yes": "Enemy.",
                        "no": {"math": [f"{r} <= -4"], "yes": "Hostile.  Don't push it.",
                        "no": {"math": [f"{r} <= -1"], "yes": "Unfriendly.  I wouldn't trust you with a coat.",
                        "no": {"math": [f"{r} == 0"], "yes": "Neutral.  You are nobody to me.",
                        "no": {"math": [f"{r} <= 3"], "yes": "Tolerated.  You can trade here.",
                        "no": {"math": [f"{r} <= 6"], "yes": "Friendly.  People here like you.",
                        "no": {"math": [f"{r} <= 9"], "yes": "Trusted.  You're one of ours, almost.", "no": "Inner circle."}}}}}}},
                    "responses": [{"text": "Fair enough.", "topic": "TALK_DONE"}]})
    # ----- ranks
    # rank -> faction likes_u/respects_u/trusts_u: 3 * rank (enemy when likes_u < -10, i.e. rank <= -4)
    sync = []
    for fid in FAC:
        s = SHORT[fid]
        if fid == "trl_nasim":
            sync.append({"if": {"and": [{"u_has_bionics": "ANY"}, {"math": ["trl_rank_nasim < 7"]}]},
                         "then": [{"math": ["trl_eff_nasim = min(trl_rank_nasim, -6)"]}],
                         "else": [{"math": ["trl_eff_nasim = trl_rank_nasim"]}]})
        else:
            sync.append({"math": [f"trl_eff_{s} = trl_rank_{s}"]})
        sync.append({"math": [f"trl_rank_{s} = max(-10, min(10, trl_rank_{s}))"]})
        sync.append({"math": [f"faction_like('{fid}') = 3 * trl_eff_{s}"]})
        sync.append({"math": [f"faction_respect('{fid}') = 3 * trl_eff_{s}"]})
    out += [
        {"type": "effect_on_condition", "id": "trl_fac_start",
         "effect": [
             {"set_string_var": "none", "target_var": {"global_val": "trl_victim_faction"}},
             {"math": ["trl_rank_bratva = -6"]}, {"math": ["trl_rank_jsdf = 0"]}, {"math": ["trl_rank_nasim = 0"]},
             {"if": {"u_has_trait": "trl_align_jsdf"}, "then": [{"math": ["trl_rank_bratva = -8"]}, {"math": ["trl_rank_jsdf = 4"]}]},
             {"if": {"u_has_trait": "trl_align_bratva"}, "then": [{"math": ["trl_rank_bratva = 4"]}, {"math": ["trl_rank_jsdf = -8"]}]},
             {"run_eocs": ["trl_fac_sync"]}]},
        {"type": "effect_on_condition", "id": "trl_fac_sync", "recurrence": ["30 seconds", "30 seconds"], "global": True,
         "effect": sync},
        # kills: the C++ hook stores the victim's faction in trl_victim_faction
        {"type": "effect_on_condition", "id": "trl_fac_kill", "eoc_type": "EVENT", "required_event": "character_kills_character",
         "effect": [
             {"if": {"compare_string": ["trl_bratva", {"global_val": "trl_victim_faction"}]},
              "then": [{"math": ["trl_rank_bratva = trl_rank_bratva - 2"]}, {"math": ["trl_rank_jsdf = trl_rank_jsdf + 1"]},
                       {"math": ["trl_rank_nasim = trl_rank_nasim + 1"]}]},
             {"if": {"compare_string": ["trl_jsdf", {"global_val": "trl_victim_faction"}]},
              "then": [{"math": ["trl_rank_jsdf = trl_rank_jsdf - 2"]}, {"math": ["trl_rank_bratva = trl_rank_bratva + 1"]},
                       {"math": ["trl_rank_nasim = trl_rank_nasim + 1"]}]},
             {"if": {"compare_string": ["trl_nasim", {"global_val": "trl_victim_faction"}]},
              "then": [{"math": ["trl_rank_nasim = trl_rank_nasim - 2"]}, {"math": ["trl_rank_jsdf = trl_rank_jsdf + 1"]},
                       {"math": ["trl_rank_bratva = trl_rank_bratva + 1"]}]},
             {"set_string_var": "none", "target_var": {"global_val": "trl_victim_faction"}},
             {"run_eocs": ["trl_fac_sync"]}]},
    ]
    return out


if __name__ == "__main__":
    json.dump(build(), open(os.path.join(sys.argv[1], "factions.json"), "w"), indent=1)
    print("factions ok")
