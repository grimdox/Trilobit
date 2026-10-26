#!/usr/bin/env python3
"""Write docs/goods_list.md from tools/content/goods_list.py (run from godot-spike/)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "content"))
import goods_list as G

out = ["# Trilobit trade goods (new)", "",
       "Scenery stock for the new businesses, flats and offices: none of these has stats or a function (not eaten, worn, wielded or used), and none lies around the world.",
       "Weight, volume and price are the properties every item has.  Item id = `trl_good_<id>`; icons are placeholders (a coloured box with initials) until the real ones are drawn.", ""]
for cat, (title, _c) in G.CATS.items():
    rows = [g for g in G.GOODS if g[2] == cat]
    if not rows:
        continue
    out += ["## " + title, "", "| id | name | sold or kept in | weight g | volume mL | price |", "|---|---|---|---|---|---|"]
    for gid, nm, _cat, who, text, wg, vol, pr in rows:
        out.append("| %s | %s | %s | %d | %d | %d |" % (gid, nm, ", ".join(who), wg, vol, pr))
    out.append("")
out.append("Total: %d goods." % len(G.GOODS))
open(os.path.join(HERE, "../docs/goods_list.md"), "w").write("\n".join(out) + "\n")
print(len(G.GOODS), "goods written to docs/goods_list.md")
