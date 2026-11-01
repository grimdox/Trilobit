#!/usr/bin/env python3
"""Write a LibreOffice spreadsheet (.ods) of every nanohack and all its values, for editing.  usage: export_nanohacks_ods.py [out.ods]
Run from godot-spike/.  It reads src/nanohacks.gd through Godot (writes /tmp/nano.json first: see the dump script in the commit message of this tool) or an existing /tmp/nano.json."""
import json, sys
from odf.opendocument import OpenDocumentSpreadsheet
from odf.table import Table, TableRow, TableCell
from odf.text import P
from odf.style import Style, TextProperties

out = sys.argv[1] if len(sys.argv) > 1 else "Trilobit Nanohacks.ods"
D = json.load(open("/tmp/nano.json"))
SKILLS = ["unarmed", "melee", "ranged", "dodge", "grit", "networking", "analysis", "implementation", "manual", "engineering", "artisan", "research", "streetwise", "etiquette", "diplomacy", "negotiation"]
doc = OpenDocumentSpreadsheet()
bold = Style(name="b", family="table-cell"); bold.addElement(TextProperties(fontweight="bold")); doc.automaticstyles.addElement(bold)

def sheet(name):
    t = Table(name=name)
    doc.spreadsheet.addElement(t)
    def row(vals, style=None):
        r = TableRow()
        for v in vals:
            c = TableCell(valuetype="float", value=v) if isinstance(v, (int, float)) and not isinstance(v, bool) else TableCell(valuetype="string")
            if style: c.setAttribute("stylename", style)
            c.addElement(P(text=str(v))); r.addElement(c)
        t.addElement(r)
    return row

row = sheet("Nanohacks")
row(["How a nanohack works: a chip fits one Trilobit slot (fit it on the Implants screen).  Passive = always on while installed and the Trilobit is powered, no cost.  Active = switched on from the N menu: costs the Activation Cost (kJ) once, then runs for Duration (minutes) drawing Upkeep (kJ/h) extra.  Instant = a single act (healing, or damage through the network).  1 turn = 6 seconds, 10 turns = 1 minute.  Offensive hacks only run through the network (B, Scan the Network, then Network to the target); their damage is Base x (1 + your Implementation/10 - target Analysis/10), rounded, minimum 0, to a random implanted body part (people with no implants take nothing).  Skill and attribute bonuses are added to your effective level while the hack runs."], "b")
row(["Edit or add rows below the header; leave a cell empty if it does not apply.  Columns to the right of Description are for new effects: movement, buffs, area, range and so on."], "b")
row([])
head = ["Name", "Code Name", "Kind (passive / active / instant)", "Offensive (needs network)", "Target (self / network target / area)", "Activation Cost (kJ)", "Duration (minutes)", "Upkeep (kJ/h)", "Cooldown (minutes)", "Range (tiles)",
       "Damage (base)", "Damage Type", "Healing (bio health)", "Armor Bonus (all parts)", "Movement Speed Bonus (%)", "Stamina Bonus", "Sight / Detection Bonus"]
head += ["%s Bonus" % s.capitalize() for s in SKILLS]
head += ["Other Effects", "Chip Price (yen)", "Slots Used", "Chip Colour 1", "Chip Colour 2", "Chip Colour 3", "Description"]
row(head, "b")
for n in D["all"]:
    kind = n["kind"]
    sk = n.get("skills", {})
    dur = n["turns"] / 10.0 if kind == "active" else ""
    r = [n["name"], "trl_nano_" + n["id"], kind, "yes" if n["id"] == "shock" else "", "network target" if n["id"] == "shock" else "self",
         D["use_kj"] if kind != "passive" else 0, dur, n.get("draw", 0) if kind == "active" else 0, "", "network link range" if n["id"] == "shock" else "",
         n.get("damage", ""), "electric (random implanted part)" if n["id"] == "shock" else "", n.get("heal", ""), n.get("armor", ""), "", "", ""]
    r += [sk.get(s, "") for s in SKILLS]
    r += ["", 400, 1] + n["cols"] + [n["text"]]
    row(r)
ref = sheet("Reference")
ref(["Kinds"], "b"); ref(["passive", "always on while installed"]); ref(["active", "switched on from the N menu, runs for a duration"]); ref(["instant", "one act"])
ref([]); ref(["Skills you can give a bonus"], "b")
for s in SKILLS: ref([s])
ref([]); ref(["Numbers now in use"], "b"); ref(["Activation cost (kJ)", D["use_kj"]]); ref(["Default active duration (minutes)", D["turns"] / 10]); ref(["Default upkeep (kJ/h)", D["draw"]]); ref(["Chip price (yen)", 400])
doc.save(out)
print("wrote", out, len(D["all"]))
