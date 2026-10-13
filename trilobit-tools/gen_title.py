#!/usr/bin/env python3
"""Title screen art: the name TRILOBIT as hiragana (to-ri-ro-bi-tsu) in neon-colored block ASCII.  Writes data/title/en.title and en.alt1.
usage: gen_title.py <repo root>"""
import os, sys
ROOT = sys.argv[1]
G = {  # 7 wide x 9 tall bitmaps, drawn by hand
 "to": ["..#....",
        "..#....",
        "..#.##.",
        "..###..",
        "..#....",
        "..#....",
        "..#...#",
        "...#.#.",
        "....#.."],
 "ri": ["..#..#.",
        "..#..#.",
        "..#..#.",
        "..#..#.",
        "..#..#.",
        "..#..#.",
        "..#.#..",
        "...##..",
        "......."],
 "ro": [".#####.",
        "....#..",
        "...#...",
        "..###..",
        ".#...#.",
        ".....#.",
        ".....#.",
        "..#.#..",
        "...#..."],
 "bi": ["...#.##",
        "#..#.##",
        "#..###.",
        "#.#..#.",
        "#.#..#.",
        "#.#..#.",
        "#.#..#.",
        "#..##..",
        "......."],
 "tsu": ["#.....#",
         "..#..#.",
         ".......",
         "..###..",
         ".#...##",
         "......#",
         "......#",
         "..#..#.",
         "...##.."],
}
ORDER = ["to", "ri", "ro", "bi", "tsu"]
COL = ["light_red", "light_cyan", "light_blue", "light_red", "light_cyan"]
# neon: pink (light_red reads as pink on the title), cyan, violet
COL = ["pink", "light_cyan", "magenta", "pink", "light_cyan"]
lines = ["# TRILOBIT title art: hiragana to-ri-ro-bi-tsu in neon block letters (keep to 80 columns)"]
for r in range(9):
    segs = []
    for g, c in zip(ORDER, COL):
        row = "".join(("##" if ch == "#" else "  ") for ch in G[g][r])
        segs.append(f"<color_{c}>{row}</color>")
    lines.append("  ".join(segs).center(0))
lines.append("")
lines.append("<color_light_cyan>" + "T  R  I  L  O  B  I  T".center(74) + "</color>")
lines.append("<color_light_blue>" + "N E O N   /   S T E E L   /   Y E N".center(74) + "</color>")
open(os.path.join(ROOT, "data/title/en.title"), "w").write("\n".join(lines) + "\n")
open(os.path.join(ROOT, "data/title/en.alt1"), "w").write("\n".join(lines) + "\n")
for l in lines[1:10]:
    print(l.replace("<color_pink>", "").replace("<color_light_cyan>", "").replace("<color_magenta>", "").replace("</color>", ""))
