"""Small helpers shared by the generators (new code uses these; older scripts keep their local copies)."""
import json, os, re


def nm(o):
    """display name of a CDDA json object as plain text"""
    n = o.get("name")
    return (n.get("str") or n.get("str_sp") or "") if isinstance(n, dict) else (n or "")


def dump(obj, path, indent=1):
    with open(path, "w") as fh:
        json.dump(obj, fh, indent=indent)


def two_space(o):
    """CDDA text style: two spaces after a sentence end"""
    if isinstance(o, str):
        return re.sub(r'([.!?:]) (?=[A-Z"])', r'\1  ', o)
    if isinstance(o, list):
        return [two_space(x) for x in o]
    if isinstance(o, dict):
        return {k: two_space(v) for k, v in o.items()}
    return o


def eoc(eid, effect, **kw):
    o = {"type": "effect_on_condition", "id": eid, "effect": effect}
    o.update(kw)
    return o
