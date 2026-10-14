#!/usr/bin/env python3
"""Run the Trilobit data generators in dependency order.

usage: build_all.py [--run] [--only name[,name...]] [--from name]
  (no flag)  print the commands, run nothing
  --run      run them
  --only     run just these steps
  --from     run this step and everything after it

Paths: REPO is the checkout; STOCK is a stock CDDA 0.I-1 tree (environment STOCK, default ~/stable/cdda-0.I-1).
Generators are idempotent unless noted.  Order matters: later steps patch the mapgen files earlier steps write.
"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
MOD = os.path.join(REPO, "data/mods/trilobit")
STOCK = os.environ.get("STOCK", os.environ.get("STOCK_DEFAULT", "/home/claude/stable/cdda-0.I-1"))
SJ = os.path.join(STOCK, "data/json")
RMS = os.path.join(SJ, "regional_map_settings.json")

# (step name, script, args).  Arguments: M = mod dir, S = stock tree, J = stock data/json, R = stock regional_map_settings.json
STEPS = [
    # world rules: what is removed or blocked
    ("no_aliens",   "gen_no_aliens.py",   ["M", "J"]),
    ("no_corpses",  "gen_no_corpses.py",  ["M", "J"]),
    ("no_wrecks",   "gen_no_wrecks.py",   ["M", "J"]),
    ("cleanup",     "gen_cleanup.py",     ["M", "S"]),
    ("guns_origin", "gen_guns.py",        ["M", "S"]),
    ("faith_clean", "gen_faith_cleanup.py", ["M", "S"]),
    # the city: layout, places, buildings (order matters), then everything that patches their mapgens
    ("city",        "gen_city.py",        ["M", "R"]),
    ("places",      "gen_places.py",      ["M"]),
    ("midrise",     "gen_midrise.py",     ["M"]),
    ("midrise2",    "gen_midrise2.py",    ["M"]),
    ("towers",      "gen_towers.py",      ["M"]),
    ("lots",        "gen_lots.py",        ["M"]),
    ("faith",       "gen_faith.py",       ["M"]),
    ("grid",        "gen_grid.py",        ["M"]),
    ("roofs",       "gen_roofs.py",       ["M"]),
    ("downtown",    "gen_downtown.py",    ["M"]),
    # people
    ("talk",        "gen_talk.py",        ["M"]),
    ("residents",   "gen_residents.py",   ["M"]),
    ("houses",      "gen_houses.py",      ["M", "R"]),
    ("apts",        "gen_apts.py",        ["M"]),
    ("androids",    "gen_androids.py",    ["M"]),
    ("factions",    "gen_factions.py",    ["M"]),
    ("pets",        "gen_pets.py",        ["M"]),
    ("fish",        "gen_fish.py",        ["M"]),
    ("presence",    "gen_presence.py",    ["M"]),       # after every building generator: converts residents, adds faction spawns
    ("tanks",       "gen_tanks.py",       ["M"]),       # after presence
    # items and systems
    ("quest",       "gen_quest.py",       ["M"]),
    ("terminals",   "gen_terminals.py",   ["M"]),
    ("doors",       "gen_doors.py",       ["M"]),
    ("net",         "gen_net.py",         ["M"]),
    ("food",        "gen_food.py",        ["M"]),
    ("drugs",       "gen_drugs.py",       ["M"]),
    ("flowers",     "gen_flowers.py",     ["M"]),
    ("power",       "gen_power.py",       ["M"]),
    ("armor",       "gen_armor.py",       ["M"]),
    ("weapons",     "gen_weapons.py",     ["M"]),
    ("gun_set",     "gen_gunset.py",      ["M"]),
    ("vehicles",    "gen_vehicles.py",    ["M"]),
    ("fleet",       "gen_fleet.py",       ["M"]),
    ("implants",    "gen_implants.py",    ["S", "M"]),
    ("limbs",       "gen_limbs.py",       ["M"]),
    ("nanohacks",   "gen_nanohacks.py",   ["M"]),
    ("cyber",       "gen_cyber.py",       ["REPO", "M"]),
    ("ghost",       "gen_ghost.py",       ["M"]),
    ("awareness",   "gen_awareness.py",   ["M"]),
    ("groupai",     "gen_groupai.py",     ["M"]),
]


def expand(a):
    return {"M": MOD, "S": STOCK, "J": SJ, "R": RMS, "REPO": REPO}.get(a, a)


def main():
    argv = sys.argv[1:]
    run = "--run" in argv
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else None
    start = argv[argv.index("--from") + 1] if "--from" in argv else None
    started = start is None
    for name, script, args in STEPS:
        if name == start:
            started = True
        if not started or (only and name not in only):
            continue
        path = os.path.join(HERE, script)
        if not os.path.exists(path):
            print(f"-- {name}: {script} is missing, skipped")
            continue
        cmd = [sys.executable, path] + [expand(a) for a in args]
        print(("RUN  " if run else "     ") + " ".join(cmd))
        if run:
            subprocess.run(cmd, check=True, cwd=HERE)


if __name__ == "__main__":
    main()
