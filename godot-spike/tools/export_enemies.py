#!/usr/bin/env python3
"""Builds data/enemy_roster.xlsx from the game's own roster (src/enemies.gd).  Usage: tools/export_enemies.py  (needs godot and openpyxl)"""
import json, subprocess, sys, os
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tmp = "/tmp/roster.json"
subprocess.run(["godot", "--headless", "--path", root, "-s", "tests/export_enemies.gd", "--", tmp], check=True, capture_output=True)
rows = json.load(open(tmp))
ITEM = {"trl_medkit": "Medkit", "trl_good_bandage_roll": "Bandage roll", "trl_vest": "Light vest", "trl_vest_heavy": "Heavy vest", "trl_vest_corp": "Corporate vest"}
for _s in ("head", "chest", "arms", "legs"):
    for _n, _g in enumerate(("Street", "Patrol", "Kevlar", "Plasteel", "Nanofab"), 1):
        ITEM["trl_armor_%s_%d" % (_s, _n)] = "%s %s (+%d)" % (_g, _s, _n)
SK = ["ranged", "melee", "unarmed", "dodge", "grit"]
wb = Workbook()
ws = wb.active
ws.title = "Roster"
hdr = ["Faction", "Level", "Title", "Total HP", "PC HP at level (100%)", "Head", "Chest", "Arm (each)", "Leg (each)", "Armour", "Top skill level", "Combat skills", "All skills",
       "Guns carried (odds)", "Items used", "Drops on death (chance %)", "Yen (min-max)", "Implants min", "Implants max", "Implant QL min", "Implant QL max",
       "Rounds to break chest (12-dmg shot, armour-reduced, min 3)", "Threat score"]
ws.append(hdr)
for r in rows:
    sk = r["skills"]
    combat = ", ".join("%s %d" % (k, sk[k]) for k in SK if sk.get(k))
    allsk = ", ".join("%s %d" % (k, v) for k, v in sorted(sk.items(), key=lambda kv: -kv[1]))
    used = [r["guns"]] if r["level"] > 1 else []
    used = ["Pistol (half of them) or fists"] if r["level"] == 2 else (["Gun: " + r["guns"]] if r["level"] > 2 else ["Fists / melee, no gun"])
    if r["level"] >= 4:
        used.append("Medkit")
    if r["vest"]:
        used.append(ITEM.get(r["vest"], r["vest"]))
    drops = "; ".join("%s (%d%%)" % (ITEM.get(d[0], d[0]), d[1]) for d in r["drops"] if d[1] > 0)
    hits = max(1, -(-(r["chest"]) // max(3, 12 - r["armor"])))
    top_combat = max([sk.get(k, 0) for k in SK])
    threat = round(r["hp_total"] / 100.0 + r["level"] * 1.5 + (3 if r["level"] >= 3 else 0) + r["implants_max"] * 0.4 + r["armor"] * 0.5, 1)
    ws.append([r["faction"], r["level"], r["title"], r["hp_total"], r["pc_health"], r["head"], r["chest"], r["arm"], r["leg"], r["armor"], r["top_skill"], combat, allsk,
               r["guns"], ", ".join(used), drops, "%d-%d" % (r["yen_lo"], r["yen_hi"]), r["implants_min"], r["implants_max"], r["ql_lo"] if r["implants_max"] else "-", r["ql_hi"] if r["implants_max"] else "-",
               hits, threat])
fill = PatternFill("solid", fgColor="1F2A44")
for c in ws[1]:
    c.font = Font(bold=True, color="FFFFFF")
    c.fill = fill
    c.alignment = Alignment(wrap_text=True, vertical="center")
widths = [14, 7, 26, 9, 12, 7, 7, 9, 9, 8, 9, 34, 60, 34, 36, 60, 12, 9, 9, 9, 9, 14, 9]
for i, w in enumerate(widths, 1):
    ws.column_dimensions[get_column_letter(i)].width = w
for row in ws.iter_rows(min_row=2):
    for c in row:
        c.alignment = Alignment(wrap_text=True, vertical="top")
ws.freeze_panes = "D2"
ws.auto_filter.ref = ws.dimensions
n = wb.create_sheet("Rules")
for line in [
    ["Enemy roster rules"], [],
    ["Health", "80% of a PC's health at that level; a PC has 164 HP (head 20, chest 40, arms 24x2, legs 28x2) plus a whole body of QL4 implants by level 10 (8 parts x 60 = 480)."],
    ["Guns", "Level 1: none. Level 2: a mix (pistol or unarmed). Level 3+: all armed. Pistols, then SMGs, then rifles with level; all rifles at level 10."],
    ["Skills", "No skill is above the enemy's level. From level 2 exactly one combat skill sits at the level; the rest are 1 or more below."],
    ["Implants", "Count and quality range rise with level. Nasim carry none; gangs at most 2 cheap ones. QL4 is one step above the catalogue's top grade."],
    ["NAP on the street", "Levels 4-6, averaging 5."],
    ["Threat score", "Rough index: HP/100 + 1.5 x level + 3 if armed + 0.4 x implants + 0.5 x armour."],
]:
    n.append(line)
n.column_dimensions["A"].width = 20
n.column_dimensions["B"].width = 120
n["A1"].font = Font(bold=True, size=13)
out = os.path.join(root, "data", "enemy_roster.xlsx")
wb.save(out)
print(out, len(rows), "rows")
