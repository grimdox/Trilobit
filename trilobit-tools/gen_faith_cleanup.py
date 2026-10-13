#!/usr/bin/env python3
"""Neutrality cleanup (user request 2026-10-13): remove religious artifacts of non-Christian or eastern religions, and items tied to
explicit political or social-justice groups, from the stock item set.  Christian items (Bibles, catechisms, Orthodox and Anglican
books, nun habit, wimple...) stay.  The new Shinto shrines (gen_faith.py) carry their own purpose-made items and are unaffected.
usage: gen_faith_cleanup.py <mod dir> <stock cdda dir> -> <mod>/faith_blacklist.json"""
import json, glob, os, re, sys
MOD, STOCK = sys.argv[1], sys.argv[2]
# Christian holy books (and Christian-adjacent historic texts) that are kept
KEEP_BOOKS = {"holybook_bible1", "holybook_bible2", "holybook_bible3", "holybook_bible4", "holybook_bible5", "holybook_bible6", "holybook_bible7",
              "holybook_bible8", "holybook_biblechild_c", "holybook_biblechild_p", "holybook_catechism", "holybook_catechism1", "holybook_catechism2",
              "holybook_catechism3", "holybook_catechism5", "holybook_catechism6", "holybook_catechism7", "holybook_catechism8", "holybook_dort",
              "holybook_confession", "holybook_orthodox", "holybook_didascalia", "holybook_ladder", "holybook_anglican", "holybook_mormon",
              "holybook_kells", "holybook_helliand", "holybook_nag_hammadi", "holybook_kebra"}
EXTRA_RELIGIOUS = ["mycenacean_hymns", "kippah", "hijab", "turban", "menorah", "incense", "ouija", "holy_symbol", "holy_symbol_wood",
                   "occult_bobliographon", "occult_economicon", "occult_glimpses", "boots_bone", "jacket_leather_bone"]
POLITICAL = ["pride_flag", "book_anthology_bk", "book_anthology_cw", "recipe_fauxfur", "novel_satire"]
ITEM_TYPES = {"ARMOR", "GUN", "TOOL", "GENERIC", "AMMO", "COMESTIBLE", "TOOL_ARMOR", "MAGAZINE", "BOOK", "CONTAINER", "PET_ARMOR", "BIONIC_ITEM", "ITEM",
              "GUNMOD", "BATTERY", "ENGINE", "WHEEL", "TOOLMOD"}
ids = set(EXTRA_RELIGIOUS) | set(POLITICAL)
for f in glob.glob(os.path.join(STOCK, "data/json/**/*.json"), recursive=True):
    try:
        d = json.load(open(f))
    except Exception:
        continue
    for o in d if isinstance(d, list) else []:
        if isinstance(o, dict) and isinstance(o.get("id"), str) and (o.get("type") in ITEM_TYPES or o.get("subtypes")) and "obsoletion" not in f:
            i = o["id"]
            if i.startswith("holybook_") and i not in KEEP_BOOKS:
                ids.add(i)
            if re.search(r"_turban$|^(xs_|xl_)?[a-z]{2}_helmet_turban$", i):
                ids.add(i)
ids = sorted(ids)
json.dump([{"type": "ITEM_BLACKLIST", "whitelist": False, "items": ids}], open(os.path.join(MOD, "faith_blacklist.json"), "w"), indent=1)
print("faith/political blacklist:", len(ids), "items")
