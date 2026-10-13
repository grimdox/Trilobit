#!/usr/bin/env python3
"""Faction presence by district (design doc section E and L): adds faction NPCs to building mapgens with a spawn chance.
  poor districts (slum shacks):   Bratva (thugs, a few enforcers) and Nasim cyberterrorists
  middle districts (homes):       a few Bratva and Nasim, and some JSDF
  rich districts (estates):       JSDF patrols and tactical operators
  mid-rise and tower sections:    JSDF, more on the ground floor
usage: gen_presence.py <mod dir>   (run after the building generators: it edits their mapgen files)"""
import json, os, random, re, sys
MOD = sys.argv[1]
NPC = "trl_nc_"
BAD_TER = re.compile(r"wall|window|door|rock|air|sky|water|pavement|sidewalk|grass|dirt|road|open|roof|stair|ladder|pit|glass", re.I)


def floor_cells(obj):
    terr = obj.get("terrain", {})
    furn = {(f["x"], f["y"]) for f in obj.get("place_furniture", []) if isinstance(f.get("x"), int) and isinstance(f.get("y"), int)}
    taken = {(n["x"], n["y"]) for n in obj.get("place_npcs", []) if isinstance(n.get("x"), int)}
    cells = []
    for y, row in enumerate(obj.get("rows", [])):
        for x, ch in enumerate(row):
            t = terr.get(ch) or (obj.get("fill_ter") if ch == " " else None)
            if isinstance(t, list):
                t = t[0]
            if isinstance(t, dict):
                t = "x"
            if t and not BAD_TER.search(t) and (x, y) not in furn and (x, y) not in taken:
                cells.append((x, y))
    return cells


def ruleset(oid):
    """-> list of (class, chance percent) for this overmap terrain id, or []"""
    if re.match(r"^trl_slum_\d+_t\d+_z0$", oid):
        return [("bratva_thug", 12), ("bratva_enforcer", 4), ("nasim_hacker", 4)]
    if re.match(r"^trl_home_\d+_t\d+_z0$", oid):
        return [("bratva_thug", 3), ("nasim_hacker", 2), ("jsdf_patrol", 3)]
    if re.match(r"^trl_estate_\d+_t\d+_z0$", oid):
        return [("jsdf_patrol", 10), ("jsdf_tactical", 3)]
    if oid.startswith("trl_mid01_"):
        return []                     # the starting building stays calm
    if re.match(r"^trl_(sky\d+|mid\d+|mr\d+|fn\d+|mt\d+)_", oid):
        ground = bool(re.search(r"z0$", oid)) and not oid.startswith("trl_mt")
        return [("jsdf_patrol", 12 if ground else 5), ("jsdf_riot", 3 if ground else 2)]
    return []


total = 0
for sub in ("houses", "midrise", "midrise2", "towers", "city"):
    path = os.path.join(MOD, sub, "mapgen.json")
    if not os.path.exists(path):
        continue
    data = json.load(open(path))
    for m in data:
        if m.get("type") != "mapgen" or "om_terrain" not in m:
            continue
        obj = m.get("object", {})
        nest = []
        def _ours(n):
            c = n.get("class")
            return isinstance(c, dict) or (isinstance(c, str) and "chance" in n and c.startswith((NPC + "bratva_", NPC + "jsdf_", NPC + "nasim_")))
        npcs = [n for n in obj.get("place_npcs", []) if not _ours(n)]
        rules = ruleset(m["om_terrain"][0])
        if rules:
            r = random.Random("presence-" + m["om_terrain"][0])
            cells = floor_cells(obj)
            r.shuffle(cells)
            for (cls, chance), (x, y) in zip(rules, cells):
                nest.append({"chunks": [["trl_pres_" + cls, chance], ["null", 100 - chance]], "x": x, "y": y})
                total += 1
        keep = [n for n in obj.get("place_nested", []) if not str(n.get("chunks", [["", 0]])[0][0]).startswith("trl_pres_")]
        if keep + nest:
            obj["place_nested"] = keep + nest
        elif "place_nested" in obj:
            del obj["place_nested"]
        if npcs:
            obj["place_npcs"] = npcs
        elif "place_npcs" in obj:
            del obj["place_npcs"]
    data = [m for m in data if not str(m.get("nested_mapgen_id", "")).startswith("trl_pres_")]
    if sub == "city":
        for cls in ("bratva_thug", "bratva_enforcer", "nasim_hacker", "jsdf_patrol", "jsdf_tactical", "jsdf_riot"):
            data.append({"type": "mapgen", "nested_mapgen_id": "trl_pres_" + cls,
                         "object": {"mapgensize": [1, 1], "rows": ["."], "place_npcs": [{"class": NPC + cls, "x": 0, "y": 0}]}})
    json.dump(data, open(path, "w"), indent=1)
print("faction spawn entries:", total)
