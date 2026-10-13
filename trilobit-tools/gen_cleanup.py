#!/usr/bin/env python3
"""Item cleanup (Milestone 23, section J): no 'makeshift' or 'broken' items or recipes.
usage: gen_cleanup.py <mod dir> <stock cdda dir>
Writes <mod>/cleanup_blacklist.json (ITEM_BLACKLIST, whose cascade also removes spawns and recipes)
and <mod>/cleanup_report.csv (what was removed and the review list of improvised/homemade/crude items).
"""
import json, glob, csv, os, re, sys

ITEM_TYPES = {"ARMOR", "GUN", "TOOL", "GENERIC", "AMMO", "COMESTIBLE", "TOOL_ARMOR", "MAGAZINE", "BOOK", "CONTAINER", "PET_ARMOR",
              "BIONIC_ITEM", "ITEM", "GUNMOD", "BATTERY", "ENGINE", "WHEEL", "TOOLMOD"}
BAD = re.compile(r"makeshift|broken", re.I)
REVIEW = re.compile(r"improvised|homemade|crude|jury", re.I)
# ids that match the words but are legitimate game content we must keep (checked by hand)
KEEP = set()


def nm(o):
    n = o.get("name")
    return (n.get("str") or n.get("str_sp") or "") if isinstance(n, dict) else (n or "")


def main(mod, stock):
    items = {}
    recipes = []
    for f in glob.glob(os.path.join(stock, "data/json/**/*.json"), recursive=True):
        try:
            d = json.load(open(f))
        except Exception:
            continue
        if not isinstance(d, list):
            continue
        for o in d:
            if not isinstance(o, dict):
                continue
            t = o.get("type")
            if (t in ITEM_TYPES or (o.get("subtypes") and t == "ITEM")) and isinstance(o.get("id"), str) and not o.get("abstract"):
                items[o["id"]] = (nm(o), f.split("data/json/")[1])
            if t == "recipe" and isinstance(o.get("result"), str):
                recipes.append((o["result"], o.get("id") or o.get("abstract") or "", f.split("data/json/")[1]))
    # basecamp recipe groups reference recipes by id and error if the recipe is gone: keep those items
    grouped = set()
    for f in glob.glob(os.path.join(stock, "data/json/**/*.json"), recursive=True):
        try:
            d = json.load(open(f))
        except Exception:
            continue
        for o in d if isinstance(d, list) else []:
            if isinstance(o, dict) and o.get("type") == "recipe_group":
                for k in ("recipes", "building_blocks"):
                    for e in o.get(k) or []:
                        if isinstance(e, dict) and e.get("id"):
                            grouped.add(e["id"])
    remove, review = [], []
    for i, (n, src) in sorted(items.items()):
        if i in KEEP or i in grouped:
            continue
        if BAD.search(i) or BAD.search(n):
            remove.append((i, n, src))
        elif REVIEW.search(i) or REVIEW.search(n):
            review.append((i, n, src))
    rset = {r[0] for r in remove}
    with open(os.path.join(mod, "cleanup_report.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["kind", "id", "name", "file"])
        for r in remove:
            w.writerow(["remove", *r])
        for r, rid, src in recipes:
            if r in rset:
                w.writerow(["recipe-removed-by-cascade", r, rid, src])
        for r in review:
            w.writerow(["review", *r])
    json.dump([{"type": "ITEM_BLACKLIST", "whitelist": False, "items": [r[0] for r in remove]}],
              open(os.path.join(mod, "cleanup_blacklist.json"), "w"), indent=1)
    print(len(items), "items;", len(remove), "removed;", sum(1 for r in recipes if r[0] in rset), "recipes cascade;", len(review), "to review")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
