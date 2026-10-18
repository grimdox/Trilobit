#!/usr/bin/env python3
"""Write a LibreOffice spreadsheet (.ods) of every melee weapon and its values for review.  usage: export_melee_ods.py [out.ods]  (run from godot-spike/, after export_items.py)"""
import json, sys
from odf.opendocument import OpenDocumentSpreadsheet
from odf.table import Table, TableRow, TableCell
from odf.text import P
from odf.style import Style, TextProperties

out = sys.argv[1] if len(sys.argv) > 1 else "Trilobit_melee_weapons.ods"
items = json.load(open("data/items.json"))
M = [i for i in items if "melee" in i["tags"]]
doc = OpenDocumentSpreadsheet()
bold = Style(name="b", family="table-cell"); bold.addElement(TextProperties(fontweight="bold")); doc.automaticstyles.addElement(bold)
t = Table(name="Melee")

def row(vals, style=None):
    r = TableRow()
    for v in vals:
        c = TableCell(valuetype="float", value=v) if isinstance(v, (int, float)) and not isinstance(v, bool) else TableCell(valuetype="string")
        if style: c.setAttribute("stylename", style)
        c.addElement(P(text=str(v))); r.addElement(c)
    t.addElement(r)

row(["Melee to-hit: hit if 2d10 + Melee skill (Unarmed skill for fists, kicks and implant blades) + Accuracy points (weapon Accuracy / 5, rounded) - (distance - 1, for reach weapons) - 2 if one arm is disabled + 1 if blessed - target Dodge points >= 11.  Target Dodge is 0 against someone unaware, returning, surrendered or stunned, and their misses become hits.  Natural 19-20, or a total >= 20 + target Grit = critical hit; natural 2 or less = critical miss (the enemy gets a free swing).  A swing costs 100 AP and 1 stamina per kg of weapon (minimum 1; fists and implant blades cost 0).  Location: torso 30%, head 10%, each arm 15%, each leg 15%."], "b")
row(["Melee damage: weapon damage roll (Damage Min-Max) + Melee/Unarmed skill (+2 with the Iron Fist discipline for unarmed).  A critical hit uses the weapon's maximum roll and doubles (maximum + skill).  Then: x Sneak multiplier from behind on someone unaware (default 4), x2 if unaware but facing you; x1.5 with a Brace weapon (reach) meeting a charge.  Then minus (target armor - Armor Pierce, not below 0) and minus the target's Grit.  Armor Pierce = the weapon's value, or 1 if its Damage Max is 14 or more, otherwise 0.  The damage is taken off the limb hit and off overall health; a destroyed head or chest kills."], "b")
row([])
row(["Name", "Class", "Culture", "Grade", "Damage Min", "Damage Max", "Reach (tiles)", "Accuracy", "Accuracy Points (Acc/5)", "Weight", "Length (mm)", "Price (yen)", "Stamina per Swing", "Armor Pierce",
     "Parry %", "Bleeds", "Stun Chance", "Trip Chance", "Entangle Chance", "Disarm Chance", "Knock-back Chance", "Sneak Multiplier", "Sweeps Others", "Brace (reach vs charge)", "Flail (ignores parry)", "Slow (two hands)", "Fast Chance (no longer used: every swing is 100 AP)", "Verb", "Code Name"], "b")
def pct(v): return "%d%%" % round(float(v) * 100) if v else ""
for i in sorted(M, key=lambda x: (x["tags"][1], x["name"], x["id"])):
    m = i["melee"]
    grade = "masterwork" if i["id"].endswith("_m") else ("forged" if i["id"].endswith("_f") else "plain")
    pen = m.get("pen", 1 if m["dmg"][1] >= 14 else 0)
    row([i["name"], i["tags"][1], i.get("culture", ""), grade, m["dmg"][0], m["dmg"][1], m["reach"], m.get("acc", 0), round(m.get("acc", 0) / 5.0), "%.2f kg" % (i["weight_g"] / 1000), i["length_mm"], i["price"],
         max(1, round(i["weight_g"] / 1000.0)), pen, m.get("parry", 0), "yes" if m.get("bleed") else "", pct(m.get("stun")), pct(m.get("trip")), pct(m.get("entangle")), pct(m.get("disarm")),
         pct(m.get("knock")), m.get("sneak", ""), "yes" if m.get("sweep") else "", "yes" if m.get("brace") else "", "yes" if m.get("flail") else "", "yes" if m.get("slow") else "", pct(m.get("fast")), m.get("verb", ""), i["id"]])
doc.spreadsheet.addElement(t)
doc.save(out)
print("wrote", out, len(M))
