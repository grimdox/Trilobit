#!/usr/bin/env python3
"""Write a LibreOffice spreadsheet (.ods) of every gun, bullet and armor value for review (tabs: Guns, Bullets, Armor).  usage: export_weapons_ods.py [out.ods]  (run from godot-spike/, after export_items.py)"""
import json, re, sys
from odf.opendocument import OpenDocumentSpreadsheet
from odf.table import Table, TableRow, TableCell
from odf.text import P
from odf.style import Style, TextProperties

out = sys.argv[1] if len(sys.argv) > 1 else "Trilobit Weapons & Armor List.ods"
src = open("src/gunplay.gd").read()
KIND = {}
for m in re.finditer(r'"(\w+)": \{"pen": (\d+), "label": "([^"]+)"([^}]*)\}', src):
    pel = re.search(r'"pellets": (\d+)', m.group(4)); bl = re.search(r'"blast": (\d+)', m.group(4))
    KIND[m.group(1)] = (int(m.group(2)), m.group(3), int(pel.group(1)) if pel else "", int(bl.group(1)) if bl else 0)
items = json.load(open("data/items.json"))
G = [i for i in items if "gun" in i["tags"]]
A = [i for i in items if "ammo" in i.get("tags", []) and "dmg" in i.get("ammo", {})]
doc = OpenDocumentSpreadsheet()
bold = Style(name="b", family="table-cell"); bold.addElement(TextProperties(fontweight="bold")); doc.automaticstyles.addElement(bold)

def sheet(name):
    t = Table(name=name)
    def row(vals, style=None):
        r = TableRow()
        for v in vals:
            c = TableCell(valuetype="float", value=v) if isinstance(v, (int, float)) and not isinstance(v, bool) else TableCell(valuetype="string")
            if style: c.setAttribute("stylename", style)
            c.addElement(P(text=str(v))); r.addElement(c)
        t.addElement(r)
    return t, row

t, row = sheet("Guns")
row(["Ranged hit formula (each bullet): hit if floor( (2d10 + Ranged skill + aim + Gun acc (-2..+2) + mod acc points + implant/stance mods - |distance - R|) x (1 - cover%) ) >= 11, where R = a fresh roll between Natural Range min and max, aim = banked aim points (0..Max Aim, minus Aim Loss per bullet fired, floor Max Aim - 5), and the range term is scaled down by sight mods (range precision).  Natural 19-20 or total >= 20 + target Grit = crit (damage doubled, max roll); natural 2 or less = critical miss (aim resets to 0).  Damage = bullet roll (see the Bullets sheet) + skill, x (1 - 1/Effective Range per tile past it), - armor - Grit.  Shot = 50 AP + 2 stamina; aim = 100 AP + 1 stamina.  Guns have no damage of their own."], "b")
row([])
row(["In-Game Name", "Weapon Class", "Natural Range", "Max Aim", "Aim Loss / Bullet", "Mod Slots (count)", "Mod Slot Types", "Caliber", "Clip Size", "Weight", "Gun acc (-2..+2)", "Fire Modes (shots)", "Report (tiles heard)", "Reload (turns)", "Pellets", "Jam %", "Maker", "Price (yen)", "Rare", "Length (mm)", "Code Name"], "b")
for g in sorted(G, key=lambda x: (x["tags"][1], x["name"])):
    b = g["gun"]; lo, hi = b["range"]
    row([g["name"], g["tags"][1].replace("_", " "), "%d-%d" % (lo, hi), b["max_aim"], b["aim_loss"], len(b["slots"]), ", ".join(b["slots"]), b["cal"], b["mag"], "%.2f kg" % (g["weight_g"] / 1000), b["acc"], ", ".join("%s %d" % (m[0], m[1]) for m in b["modes"]), b["noise"], b["reload"], b["pellets"], b["jam"], g.get("maker", ""), g["price"], "yes" if g.get("rare") else "no", g["length_mm"], g["id"]])
doc.spreadsheet.addElement(t)
t2, row2 = sheet("Bullets")
row2(["Bullet damage: the gun fires the loaded bullet; damage roll = a random value in the bullet's Damage range (a crit takes the maximum and doubles (max + skill)), + Ranged skill.  Past the Effective Range, every tile removes 1/Effective Range of that damage (spent at twice the range); armor and Grit then subtract.  Armor Pierce is subtracted from the target's armor first."], "b")
row2([])
row2(["Name", "Caliber", "Kind", "Damage Min", "Damage Max", "Effective Range (tiles)", "Armor Pierce", "Blast Radius", "Pellets Override", "Rounds per Box", "Box Weight", "Box Price (yen)", "Code Name"], "b")
for a in A:
    am = a["ammo"]; pen, label, pel, blast = KIND[am["kind"]]
    row2(["%s %s" % (am["cal"], label), am["cal"], label, am["dmg"][0], am["dmg"][1], am["eff_range"], pen, blast, pel, am["rounds"], "%.2f kg" % (a["weight_g"] / 1000), a["price"], a["id"]])
doc.spreadsheet.addElement(t2)

# ---- Armor: one piece per slot per +1..+5 base armor.  Not in the game yet: the prices follow the implant economy (implant_catalogue.xlsx, Example Implants).
# price = round( implant reference price for that armor value x slot factor / divisor , to 10 yen )
IMPLANT_REF = {1: 5400, 2: 11000, 3: 24000, 4: 46000, 5: 92000}   # what an implant giving that much armor costs (grade 1 arm/leg part, grade 1-2 dermal and chest parts, grade 3 and 4 dermal)
DIVISOR = {1: 5.0, 2: 6.0, 3: 7.0, 4: 8.5, 5: 10.0}                # armor is 1/5 of an implant's price at +1, 1/10 at +5
SLOT_F = {"head": 0.75, "chest": 1.0, "arms": 0.5, "legs": 0.5}    # an implant for the head costs about 3/4 of a chest one; an arm or leg part about half
DUR = {1: 20, 2: 35, 3: 50, 4: 65, 5: 80}
GRADE = {1: "Street", 2: "Patrol", 3: "Kevlar", 4: "Plasteel", 5: "Nanofab"}
PART = {"head": ("Helm", [400, 800, 1200, 1600, 2000]), "chest": ("Vest", [1500, 2400, 3400, 4500, 5800]),
        "arms": ("Arm Guards", [500, 800, 1200, 1600, 2000]), "legs": ("Leg Guards", [600, 1000, 1400, 1900, 2400])}
COVER = {"head": "head", "chest": "chest", "arms": "both arms", "legs": "both legs"}
t3, row3 = sheet("Armor")
row3(["Armor: each worn piece takes a flat amount off every hit that lands on its body part (Phys = base armor, +1 to +5), and wears down as it soaks damage (Durability); a broken piece gives nothing.  Arm and leg pieces cover both limbs.  Pieces are listed for design review and are not in the game yet.  Price = Implant reference x Slot factor / Divisor, rounded to 10 yen: implant references come from the implant economy (an implant giving that armor), the divisor runs from 5 at +1 to 10 at +5 so armor costs 1/5 to 1/10 of the implant."], "b")
row3([])
row3(["Name", "Slot", "Covers", "Base Armor (Phys)", "Durability", "Weight", "Price (yen)", "Implant reference (yen)", "Slot factor", "Divisor", "Implant equivalent (yen)", "Code Name"], "b")
for slot in ("head", "chest", "arms", "legs"):
    word, kg = PART[slot]
    for n in range(1, 6):
        ref = IMPLANT_REF[n]
        price = int(round(ref * SLOT_F[slot] / DIVISOR[n] / 10.0)) * 10
        row3(["%s %s" % (GRADE[n], word), slot, COVER[slot], n, DUR[n], "%.2f kg" % (kg[n - 1] / 1000), price, ref, SLOT_F[slot], DIVISOR[n], int(round(ref * SLOT_F[slot])), "trl_armor_%s_%d" % (slot, n)])
doc.spreadsheet.addElement(t3)
doc.save(out)
print("wrote", out)
