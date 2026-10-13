"""Load terrain and furniture definitions (stock 0.I-1 data plus the Trilobit mod), resolving copy-from, for the tileset generator."""
import json, glob, os, re

def load(stock_dir, mod_dir):
    raw = {"terrain": {}, "furniture": {}, "monster": {}, "field": {}, "vpart": {}, "item": {}}
    ITEM_TYPES = {"ARMOR", "GUN", "TOOL", "GENERIC", "AMMO", "COMESTIBLE", "TOOL_ARMOR", "MAGAZINE", "BOOK", "CONTAINER", "PET_ARMOR", "BIONIC_ITEM", "ITEM",
                  "GUNMOD", "BATTERY", "ENGINE", "WHEEL", "TOOLMOD"}
    files = glob.glob(os.path.join(stock_dir, "data/json/**/*.json"), recursive=True) + glob.glob(os.path.join(mod_dir, "**/*.json"), recursive=True)
    for f in files:
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
            key = {"terrain": "terrain", "furniture": "furniture", "MONSTER": "monster", "field_type": "field", "vehicle_part": "vpart"}.get(t)
            if t in ITEM_TYPES:
                key = "item"
            if not key:
                continue
            ids = o.get("id")
            if ids is None:
                ids = o.get("abstract")
            for i in (ids if isinstance(ids, list) else [ids]):
                if isinstance(i, str):
                    raw[key][i] = o
    out = {}
    for key, tab in raw.items():
        cache = {}
        def res(i, depth=0):
            if i in cache:
                return cache[i]
            o = tab.get(i)
            if o is None or depth > 12:
                return {}
            base = dict(res(o["copy-from"], depth + 1)) if "copy-from" in o else {}
            fl = set(base.get("flags") or [])
            base.update({k: v for k, v in o.items() if k not in ("flags", "copy-from")})
            fl |= set(o.get("flags") or [])
            if "extend" in o and isinstance(o["extend"], dict):
                fl |= set(o["extend"].get("flags") or [])
            if "delete" in o and isinstance(o["delete"], dict):
                fl -= set(o["delete"].get("flags") or [])
            base["flags"] = sorted(fl)
            cache[i] = base
            return base
        out[key] = {i: res(i) for i, o in tab.items() if "id" in o and not o.get("abstract")}
    return out

def nm(o):
    n = o.get("name")
    return (n.get("str") or n.get("str_sp") or "") if isinstance(n, dict) else (n or "")

def color(o):
    c = o.get("color")
    if isinstance(c, list):
        c = c[0] if c else "light_gray"
    c = str(c or "light_gray")
    c = re.sub(r"^(c_|i_|h_)", "", c)
    return {"ltgray": "light_gray", "dkgray": "dark_gray", "ltred": "light_red", "ltgreen": "light_green", "ltblue": "light_blue", "ltcyan": "light_cyan", "pink": "pink",
            "magenta": "magenta"}.get(c, c)
