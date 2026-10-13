#!/usr/bin/env python3
"""Generate Trilobit house residents: traits, gear, classes, templates, routine EOCs, names.

usage: gen_residents.py <mod dir>
Writes <mod>/residents.json and <mod>/names.json.
Imported by gen_houses.py for JOBS / job_for().
"""
import json, os, sys, hashlib

# tier -> job -> (title, workplace overmap prefix, extra worn, weapons[(item,prob)], skills, cash(min,max))
JOBS = {
    "poor": {
        "day_laborer":   ("Day laborer", "trl_pl_cargo_warehouse", ["gloves_work", "jacket_light"], [("crowbar", 10), ("hammer", 10)], {"melee": 1}),
        "street_vendor": ("Street vendor", "trl_pl_night_market", ["apron_cotton"], [("knife_folding", 15)], {"speech": 2}),
        "scrapper":      ("Scrapper", "trl_lot_scrapyard", ["gloves_work", "mask_dust", "boots_rubber"], [("crowbar", 40), ("pipe", 20)], {"melee": 2, "mechanics": 1}),
        "courier":       ("Courier", "trl_fn07_transit_hub", ["jacket_windbreaker", "sneakers"], [("knife_folding", 15)], {"dodge": 2}),
        "dishwasher":    ("Dishwasher", "trl_fn14_food_court", ["apron_cotton"], [("knife_cleaver", 10)], {"cooking": 1}),
        "janitor":       ("Janitor", "trl_fn08_corp_office", ["technician_coveralls", "gloves_work"], [("pipe", 10)], {"mechanics": 1}),
    },
    "mid": {
        "clerk":          ("Clerk", "trl_fn12_department_store", ["tie_necktie", "buttonshirt"], [], {"speech": 2}),
        "technician":     ("Technician", "trl_fn09_telecom", ["technician_shirt_gray", "technician_pants_gray"], [], {"electronics": 3, "computer": 2}),
        "nurse":          ("Nurse", "trl_fn24_hospital", ["coat_lab"], [], {"firstaid": 4}),
        "teacher":        ("Teacher", "trl_fn19_library_school", ["sweater"], [], {"speech": 3}),
        "shop_assistant": ("Shop assistant", "trl_fn13_supermarket", ["apron_cotton"], [], {"speech": 1}),
        "police_clerk":   ("Police clerk", "trl_fn02_precinct", ["leather_police_jacket"], [("baton", 25)], {"computer": 2, "pistol": 1}),
        "driver":         ("Driver", "trl_fn07_transit_hub", ["jacket_windbreaker"], [], {"driving": 4}),
        "engineer":       ("Engineer", "trl_fn08_corp_office", ["polo_shirt"], [], {"electronics": 4, "mechanics": 3, "computer": 3}),
    },
    "rich": {
        "executive": ("Executive", None, ["suit", "tie_necktie"], [], {"speech": 5}),
        "owner":     ("Business owner", None, ["blazer", "dress_shirt"], [], {"speech": 4}),
        "investor":  ("Investor", None, ["suit"], [], {"speech": 4, "computer": 2}),
        "surgeon":   ("Surgeon", None, ["coat_lab", "dress_shirt"], [], {"firstaid": 7}),
        "official":  ("Retired official", None, ["suit", "tie_necktie"], [], {"speech": 5}),
    },
}
RICH_WORK = {"executive": "trl_fn08_corp_office", "owner": "trl_fn10_hotel", "investor": "trl_fn06_bank",
             "surgeon": "trl_fn24_hospital", "official": "trl_fn01_district_office"}
BASE_WORN = {
    "poor": [("tshirt", 60), ("tank_top", 40), ("jeans", 50), ("pants_cargo", 50), ("socks", 100), ("sneakers", 60), ("boots_rubber", 40), ("hoodie", 40)],
    "mid": [("dress_shirt", 40), ("polo_shirt", 30), ("buttonshirt", 30), ("jeans", 40), ("pants_checkered", 20), ("socks", 100), ("dress_shoes", 60), ("sneakers", 40)],
    "rich": [("dress_shirt", 100), ("socks", 100), ("dress_shoes", 100)],
}
CASH = {"poor": (0, 300), "mid": (200, 2000), "rich": (3000, 12000)}
TIER_CB = {"poor": 0, "mid": 20, "rich": 100}


def distribution_for(tier, job):
    return f"trl_res_{tier}_{job}"


def all_jobs():
    for tier, d in JOBS.items():
        for job in d:
            yield tier, job


def job_for(house_id, slot=0):
    """Deterministic job for resident 'slot' of the house; returns (tier, job) or None."""
    kind = "poor" if "slum" in house_id else "rich" if "estate" in house_id else "mid"
    jobs = list(JOBS[kind])
    h = int(hashlib.md5(f"{house_id}/{slot}".encode()).hexdigest()[:8], 16)
    return kind, jobs[h % len(jobs)]


def template_id(tier, job):
    return f"trl_nc_res_{tier}_{job}"


def build():
    out = []
    for tid, nm, d in (("trl_resident", "Resident", "A resident of the city: has a home and a job."),
                       ("trl_res_poor", "Poor", "Wealth tier: poor."), ("trl_res_mid", "Middle class", "Wealth tier: middle."),
                       ("trl_res_rich", "Rich", "Wealth tier: rich.")):
        out.append({"type": "mutation", "id": tid, "name": {"str": nm}, "points": 0, "visibility": 0, "ugliness": 0,
                    "description": d + "  Hidden marker used by the resident routine.", "valid": False, "purifiable": False})
    eocs_init = []
    for tier, job in all_jobs():
        title, work, extra, weapons, skills = JOBS[tier][job]
        wid = distribution_for(tier, job)
        entries = [{"item": i, "prob": p} for i, p in BASE_WORN[tier]] + [{"item": i} for i in extra]
        out.append({"type": "item_group", "id": wid + "_worn", "subtype": "collection", "entries": entries})
        lo, hi = CASH[tier]
        carry = [{"item": "wallet", "prob": 60}]
        if hi:
            carry.append({"item": "trl_yen", "count": [lo, hi]})
        out.append({"type": "item_group", "id": wid + "_carry", "subtype": "collection", "entries": carry})
        out.append({"type": "item_group", "id": wid + "_weapon", "subtype": "collection",
                    "entries": [{"item": i, "prob": p} for i, p in weapons] or [{"item": "wallet", "prob": 1}]})
        cl = {"type": "npc_class", "id": template_id(tier, job), "name": {"str": title},
              "job_description": f"I work as a {title.lower()}.", "common": False,
              "worn_override": wid + "_worn", "carry_override": wid + "_carry", "weapon_override": wid + "_weapon",
              "traits": [{"trait": "trl_resident"}, {"trait": f"trl_res_{tier}"}],
              "skills": [{"skill": "ALL", "level": {"constant": 1}}] +
                        [{"skill": s, "level": {"constant": v}} for s, v in skills.items()]}
        if TIER_CB[tier]:
            cl["bionics"] = [{"id": "trl_bio_cyberbrain", "chance": TIER_CB[tier]}]
        out.append(cl)
        out.append({"type": "npc", "id": template_id(tier, job), "class": template_id(tier, job),
                    "attitude": 0, "mission": 7, "chat": "TRL_RESIDENT_TALK", "faction": "no_faction",
                    "temp_suffix": title})
        wp = work or RICH_WORK[job]
        eocs_init.append(f"trl_res_init_{tier}_{job}")
        init = {"type": "effect_on_condition", "id": f"trl_res_init_{tier}_{job}",
                "condition": {"u_has_class": template_id(tier, job)}, "effect": []}
        if tier != "rich" or True:
            init["effect"].append({"u_location_variable": {"u_val": "trl_work"},
                                   "target_params": {"om_terrain": wp, "om_terrain_match_type": "PREFIX", "random": True,
                                                     "search_range": 15, "z": 0},
                                   "x_adjust": 12, "y_adjust": 12,
                                   "false_eocs": ["trl_res_nowork"], "true_eocs": ["trl_res_haswork"]})
        out.append(init)
    # ---- routine
    out += [
        {"type": "effect_on_condition", "id": "trl_res_nowork", "effect": [{"math": ["u_trl_has_work = 0"]}]},
        {"type": "effect_on_condition", "id": "trl_res_haswork", "effect": [{"math": ["u_trl_has_work = 1"]}]},
        {"type": "effect_on_condition", "id": "trl_res_goto_spot", "effect": [{"u_go_to_loc": {"u_val": "trl_spot"}}]},
        {"type": "effect_on_condition", "id": "trl_res_tick", "recurrence": ["15 minutes", "20 minutes"], "global": True,
         "effect": [{"u_run_npc_eocs": ["trl_res_step"], "overmap": True}]},
        {"type": "effect_on_condition", "id": "trl_res_step",
         "condition": {"and": [{"u_has_trait": "trl_resident"}, {"not": "u_following"},
                               {"math": ["u_trl_skip_until < time('now')"]}]},
         "effect": [
             {"if": {"or": [{"math": ["u_npc_anger() > 0"]}, {"math": ["u_npc_fear() > 0"]}]},
              "then": [{"math": ["u_trl_skip_until = time('now') + time('10 m')"]}],
              "else": [{"run_eocs": ["trl_res_init_once"]},
                       {"if": {"u_has_trait": "trl_res_rich"}, "then": [{"run_eocs": ["trl_res_do_rich"]}],
                        "else": [{"run_eocs": ["trl_res_do_commuter"]}]}]}]},
        {"type": "effect_on_condition", "id": "trl_res_init_once",
         "condition": {"math": ["u_trl_inited == 0"]},
         "effect": [{"u_location_variable": {"u_val": "trl_home"}},
                    {"math": ["u_trl_inited = 1"]},
                    {"math": ["u_trl_at = 0"]},
                    {"run_eocs": eocs_init}]},
        # commuters: work 07:00-17:00
        {"type": "effect_on_condition", "id": "trl_res_do_commuter",
         "condition": {"math": ["u_trl_has_work == 1"]},
         "effect": [{"if": {"and": [{"math": ["time_since('midnight','unit':'hours') >= 7"]}, {"math": ["time_since('midnight','unit':'hours') < 17"]}]},
                     "then": [{"if": {"math": ["u_trl_at != 1"]},
                               "then": [{"u_go_to_loc": {"u_val": "trl_work"}}, {"math": ["u_trl_at = 1"]}]}],
                     "else": [{"if": {"math": ["u_trl_at != 0"]},
                               "then": [{"u_go_to_loc": {"u_val": "trl_home"}}, {"math": ["u_trl_at = 0"]}]}]}]},
        # rich: stay around home by day, bedroom (home point) by night
        {"type": "effect_on_condition", "id": "trl_res_do_rich",
         "effect": [{"if": {"and": [{"math": ["time_since('midnight','unit':'hours') >= 8"]}, {"math": ["time_since('midnight','unit':'hours') < 22"]}]},
                     "then": [{"if": {"or": [{"math": ["distance('u', u_trl_home) > 12"]}, {"math": ["rand(3) == 0"]}]},
                               "then": [{"u_go_to_loc": {"u_val": "trl_home"}}],
                               "else": [{"u_location_variable": {"u_val": "trl_spot"}, "max_radius": 6, "passable_only": True,
                                         "true_eocs": ["trl_res_goto_spot"]}]},
                              {"math": ["u_trl_at = 2"]}],
                     "else": [{"if": {"math": ["u_trl_at != 0"]},
                               "then": [{"u_go_to_loc": {"u_val": "trl_home"}}, {"math": ["u_trl_at = 0"]}]}]}]},
        {"type": "talk_topic", "id": "TRL_RESIDENT_TALK", "dynamic_line": "Hm?  Can I help you?",
         "responses": [{"text": "Just passing through.", "topic": "TALK_DONE"}]},
    ]
    return out


def names():
    src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "names", "npc_names_10000.json")
    data = json.load(open(src))
    res = []
    for cat, g in (("<male_full_name>", "M"), ("<female_full_name>", "F")):
        res.append({"type": "snippet", "category": cat,
                    "text": [{"text": e["name"], "weight": 5} for e in data if e["gender"] == g]})
    return res


if __name__ == "__main__":
    mod = sys.argv[1]
    json.dump(build(), open(os.path.join(mod, "residents.json"), "w"), indent=1)
    json.dump(names(), open(os.path.join(mod, "names.json"), "w"), indent=0)
    print("residents:", sum(len(v) for v in JOBS.values()), "jobs")
