#!/usr/bin/env python3
"""Drugs and pharmaceuticals (design doc section M14).
  - Regen injector: a healing stimulant, NOT sold.  Over one hour it heals about half of the maximum HP of every organic body part, a little each
    minute (implants have their own integrity and are not healed by it).  Found in hospitals and police precincts.
  - Six street narcotics (Redeye, glass, drip, lotus, static, neon snuff), found in slum shacks and carried by gangsters; never sold in shops.
  - Four legal prescription medicines (anti-rejection, sleep, focus and pain tablets), found in hospitals and clinics.
usage: gen_drugs.py <mod dir>  -> <mod>/drugs.json; also patches hospital, precinct and slum mapgens with the loot (run after the building generators)."""
import json, os, re, sys
MOD = sys.argv[1]
PARTS = ["head", "torso", "arm_l", "arm_r", "leg_l", "leg_r"]
out = []

# ---------------------------------------------------------------- regen injector
HOURLY = 0.5                      # fraction of max HP restored over the duration
PER_MIN = HOURLY / 60
out.append({"type": "effect_type", "id": "effect_trl_regen", "name": ["Regen Stim"], "desc": ["Regenerative nanites knit your flesh back together, a little more each minute."],
            "apply_message": "A cool warmth spreads from the injection site.  Your wounds begin to itch as they knit.",
            "decay_messages": [["The regen stimulant has run its course.", "neutral"]], "rating": "good", "max_duration": 7200})
out.append({"type": "ITEM", "subtypes": ["GENERIC"], "id": "trl_inj_regen", "category": "drugs", "name": {"str": "regen stimulant injector"},
            "description": "A spring-loaded auto-injector of military-grade regenerative nanites.  Press it to your thigh: over the next hour it knits your own flesh "
                           "back together, restoring about half of your health a little at a time.  Not instant.  It cannot repair implants.  Issued to hospitals and police; never sold.",
            "weight": "30 g", "volume": "30 ml", "price": "900 USD", "price_postapoc": "900 USD", "symbol": "!", "color": "light_green",
            "material": ["plastic"], "flags": ["TRADER_AVOID"],
            "use_action": {"type": "effect_on_conditions", "menu_text": "Inject", "description": "Inject the regen stimulant.", "effect_on_conditions": ["trl_regen_inject"]}})
out.append({"type": "effect_on_condition", "id": "trl_regen_inject", "effect": [
    {"u_consume_item": "trl_inj_regen", "count": 1},
    {"u_add_effect": "effect_trl_regen", "duration": "1 hours"},
    {"run_eocs": ["trl_regen_reset"]},
    {"u_message": "You press the injector to your thigh.  It clicks, and a cool warmth spreads outward.", "type": "good"}]})
out.append({"type": "effect_on_condition", "id": "trl_regen_reset", "effect": [{"math": [f"u_trl_regen_acc_{p} = 0"]} for p in PARTS]})
# a tick every minute while the effect lasts; fractions of a hit point accumulate until they add up to whole points
tick = []
for p in PARTS:
    tick.append({"math": [f"u_trl_regen_acc_{p} += u_hp_max('{p}') * {PER_MIN:.6f}"]})
    tick.append({"math": [f"u_trl_regen_add = floor(u_trl_regen_acc_{p})"]})
    tick.append({"math": [f"u_trl_regen_acc_{p} -= u_trl_regen_add"]})
    tick.append({"math": [f"u_hp('{p}') = min(u_hp('{p}') + u_trl_regen_add, u_hp_max('{p}'))"]})
out.append({"type": "effect_on_condition", "id": "trl_regen_tick", "recurrence": "1 minutes", "global": True,
            "condition": {"u_has_effect": "effect_trl_regen"}, "effect": tick})

# ---------------------------------------------------------------- street narcotics
def fx(eid, names, descs, apply, base, scaling, dur_factor, decay=None):
    d = {"type": "effect_type", "id": eid, "name": names, "desc": descs, "apply_message": apply, "rating": "mixed", "max_intensity": 2,
         "int_dur_factor": dur_factor, "removes_effects": ["winded", "winded_leg_l", "winded_leg_r", "winded_arm_l", "winded_arm_r"],
         "base_mods": base, "scaling_mods": scaling}
    if decay:
        d["decay_messages"] = [[decay, "bad"]]
    return d


# Redeye, from the Cowboy Bebop episode: a combat stimulant that turns a man into a fast, strong, fearless thing for a short while, then drops him.
out.append(fx("trl_redeye", ["Redeye Crash", "Redeye Rush"],
              ["The Redeye is gone and everything weighs a ton.", "Your heart hammers.  The world slows down and nothing hurts."],
              "The Redeye hits like a train.  The world slows to a crawl and you feel nothing at all.",
              {"speed_mod": [-18], "str_mod": [-3], "dex_mod": [-2], "per_mod": [-1], "int_mod": [-1], "stamina_min": [-3]},
              {"speed_mod": [43], "str_mod": [5], "dex_mod": [4], "per_mod": [3], "int_mod": [-1], "stamina_min": [6], "stamina_max": [8]},
              "12 m", "The Redeye wears off.  You feel hollow and weak."))
out.append(fx("trl_glass", ["Glass Crash", "Glass Wired"], ["You are burned out and shaking.", "Wired, quick and brittle."],
              "The glass flash sharpens everything to a bright edge.",
              {"speed_mod": [-8], "int_mod": [-2], "per_mod": [-1]}, {"speed_mod": [18], "dex_mod": [2], "per_mod": [2], "int_mod": [1], "stamina_min": [4]},
              "8 m", "The glass burns out.  Your hands shake."))
out.append(fx("trl_neon", ["Neon Crash", "Neon Rush"], ["The glow has gone out of the world.", "Everything is bright and wonderful."],
              "The snuff burns up your nose and the city lights bloom.",
              {"speed_mod": [-6], "int_mod": [-1]}, {"speed_mod": [10], "dex_mod": [1], "per_mod": [1], "stamina_min": [3]},
              "6 m", "The neon fades.  The world goes grey."))
out.append(fx("trl_drip", ["Drip Sick", "Drip Haze"], ["You are sweating and sick.", "A warm, heavy calm.  Nothing matters."],
              "A warm wave takes your pain away.",
              {"speed_mod": [-8], "per_mod": [-1]}, {"speed_mod": [-10], "dex_mod": [-1], "per_mod": [-2], "int_mod": [-1]},
              "15 m", "The warmth drains away."))
out.append(fx("trl_lotus", ["Lotus Fog", "Lotus Calm"], ["You are slow and clumsy.", "Your thoughts float.  You are very calm."],
              "Your thoughts soften and the fear melts away.",
              {"speed_mod": [-5], "int_mod": [-1]}, {"speed_mod": [-8], "dex_mod": [-1], "int_mod": [-1], "per_mod": [-1]},
              "15 m", "The lotus fades."))
STREET = [
    ("redeye", "Redeye capsule", "A red-and-white capsule stamped with a single eye.  Redeye is a combat stimulant that cuts pain and slows the world around you for a while; "
                                "it makes you fast, strong and unafraid, then drops you hard.  Dangerously addictive.", "light_red", "capsule", 14, "amphetamine",
     [("trl_redeye", 2400), ("pkill2", 2400)], 18, 15, 400),
    ("glass", "glass shard", "A glittering crystal chip, crushed and smoked.  A cheap, jittery stimulant that burns out fast.", "light_cyan", "shard", 12, "amphetamine",
     [("trl_glass", 1500)], 16, 18, 150),
    ("neon", "neon snuff", "A pinch of glowing powder, snuffed up the nose.  A short bright rush, and a long grey comedown.", "pink", "pinch", 10, "cocaine",
     [("trl_neon", 900)], 14, 10, 120),
    ("drip", "drip injector", "A tiny pre-filled injector of milky opioid.  Warm, heavy, and a very fast road to addiction.", "light_gray", "injector", 18, "opiate",
     [("trl_drip", 2400), ("pkill3", 600), ("pkill2", 2400)], 20, -6, 200),
    ("lotus", "lotus tab", "A pale tab pressed with a lotus flower.  A sedative that melts fear and sharp edges away.", "white", "tab", 10, "diazepam",
     [("trl_lotus", 2400)], 12, -4, 100),
    ("static", "static blotter", "A scrap of paper printed with a shimmering grid.  A hallucinogen that fills the air with static and half-seen shapes.", "light_green",
     "blotter", 0, "", [("hallu", 1800)], 18, 0, 160),
]
for eid, nm, desc, col, shape, add, atype, effects, fun, stim, price in STREET:
    o = {"type": "ITEM", "subtypes": ["COMESTIBLE"], "id": f"trl_drug_{eid}", "comestible_type": "MED", "name": {"str": nm}, "description": desc,
         "material": ["drug_filler"], "weight": "1 g", "volume": "1 ml", "price": f"{price} USD", "price_postapoc": f"{price} USD",
         "symbol": "!", "color": col, "healthy": -2, "fun": fun, "stim": stim, "flags": ["NPC_SAFE", "IRREPLACEABLE_CONSUMABLE", "NO_TEMP", "TRADER_AVOID"],
         "use_action": {"type": "consume_drug", "activation_message": "You take the %s.",
                        "effects": [{"id": i, "duration": s} for i, s in effects]}}
    if add:
        o["addiction_potential"] = add
        o["addiction_type"] = atype
    # tile shape comes from the name: "capsule"/"tab" read as pills, "injector" as a syringe
    out.append(o)

# ---------------------------------------------------------------- legal prescriptions
out.append({"type": "effect_type", "id": "trl_rx_focus", "name": ["Focused"], "desc": ["Your thoughts are crisp and orderly."], "rating": "good", "max_duration": 14400,
            "base_mods": {"int_mod": [2], "per_mod": [1], "speed_mod": [0]}})
RX = [
    ("antirej", "anti-rejection tablets", "Prescription tablets that calm the immune system so the body accepts implants.  Taken daily by the heavily augmented.", "white", 0, 0,
     [], 8, -1, 30),
    ("sleep", "sleep tablets", "Prescription tablets for a short, deep, dreamless sleep.", "light_blue", 2, 0, [("trl_lotus", 600)], 4, -4, 20),
    ("focus", "focus tablets", "Prescription tablets that sharpen concentration for a few hours.  Mildly habit-forming.", "yellow", 6, 8, [("trl_rx_focus", 10800)], 6, 6, 25),
    ("pain", "pain tablets", "Prescription analgesic tablets for sore muscles and healing wounds.", "light_red", 0, 0, [("pkill2", 7200)], 4, 0, 18),
]
for eid, nm, desc, col, add, stim_ok, effects, fun, stim, price in RX:
    o = {"type": "ITEM", "subtypes": ["COMESTIBLE"], "id": f"trl_rx_{eid}", "comestible_type": "MED", "name": {"str": nm, "str_pl": nm}, "description": desc,
         "material": ["drug_filler"], "weight": "1 g", "volume": "1 ml", "price": f"{price} USD", "price_postapoc": f"{price} USD",
         "symbol": "!", "color": col, "fun": 0, "stim": stim, "flags": ["NPC_SAFE", "NO_TEMP", "TRADER_AVOID"],
         "use_action": {"type": "consume_drug", "activation_message": "You take some %s.", "effects": [{"id": i, "duration": s} for i, s in effects]}}
    if add:
        o["addiction_potential"] = add
        o["addiction_type"] = "amphetamine" if eid == "focus" else "sleeping pill"
    out.append(o)

# ---------------------------------------------------------------- item groups
out.append({"type": "item_group", "id": "trl_loot_injector", "subtype": "collection", "entries": [{"item": "trl_inj_regen", "prob": 100, "count": [1, 2]}]})
out.append({"type": "item_group", "id": "trl_loot_rx", "subtype": "distribution", "entries": [{"item": f"trl_rx_{r[0]}", "prob": 25, "count": [1, 4]} for r in RX]})
out.append({"type": "item_group", "id": "trl_loot_street_drugs", "subtype": "distribution",
            "entries": [{"item": "trl_drug_redeye", "prob": 14, "count": [1, 2]}, {"item": "trl_drug_glass", "prob": 24}, {"item": "trl_drug_neon", "prob": 20},
                        {"item": "trl_drug_drip", "prob": 18}, {"item": "trl_drug_lotus", "prob": 18}, {"item": "trl_drug_static", "prob": 12}]})
json.dump(out, open(os.path.join(MOD, "drugs.json"), "w"), indent=1)

# ---------------------------------------------------------------- loot placement: patch the mapgens (idempotent)
OURS = {"trl_loot_injector", "trl_loot_rx", "trl_loot_street_drugs"}
rules = [  # (regex on the overmap terrain id, [(group, chance, repeat)])
    (re.compile(r"hospital"), [("trl_loot_injector", 80, 1), ("trl_loot_rx", 70, 2)]),
    (re.compile(r"precinct"), [("trl_loot_injector", 35, 1)]),
    (re.compile(r"clinic"), [("trl_loot_rx", 60, 1)]),
    (re.compile(r"^trl_slum_\d+_t\d+_z0$"), [("trl_loot_street_drugs", 8, 1)]),
]
patched = {"injector": 0, "rx": 0, "street": 0}
for root, _, files in os.walk(MOD):
    for fn in files:
        if not fn.endswith("mapgen.json"):
            continue
        path = os.path.join(root, fn)
        data = json.load(open(path))
        dirty = False
        for m in data:
            if m.get("type") != "mapgen" or "om_terrain" not in m:
                continue
            oid = m["om_terrain"][0] if isinstance(m["om_terrain"], list) else m["om_terrain"]
            obj = m.get("object", {})
            items = [it for it in obj.get("place_items", []) if it.get("item") not in OURS]
            for rx, groups in rules:
                if rx.search(oid):
                    for grp, ch, rep in groups:
                        items.append({"item": grp, "x": [3, 20], "y": [4, 19], "chance": ch, "repeat": rep})
                        patched["injector" if "injector" in grp else "rx" if grp.endswith("rx") else "street"] += 1
            if items != obj.get("place_items", []):
                obj["place_items"] = items
                dirty = True
        if dirty:
            json.dump(data, open(path, "w"), indent=1)
print("drugs:", len(STREET), "street,", len(RX), "rx, injector; patched mapgens:", patched)
