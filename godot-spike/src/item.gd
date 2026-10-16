extends RefCounted
## An item instance with CDDA-style pockets.
##  - rigid pocket: its capacity lives inside the item's own volume (the item does not grow)
##  - flexible pocket: the item grows by the volume of what it holds (a bag collapses when empty)
##  - a pocket can restrict by tag, require watertight for liquids, and cap item length
## Items nest (pouch in backpack in coat); volume and weight roll up.
const ItemScript = preload("res://src/item.gd")

var def: Dictionary
var count: int = 1                         # stack size, or millilitres for per-unit liquids
var pockets: Array = []                    # Array of Array[Item], parallel to def.pockets
# gun state (only used when def has a "gun" block)
var loaded: int = 0                        # rounds in the magazine
var kind: String = ""                      # ammunition kind loaded ("" when empty)
var mods: Array = []                       # installed mod items
var jammed: bool = false
var mode: int = 0                          # index into gun.modes
var cond: int = -1                         # wear: hit points left on an engine (-1 = as new)

func _init(d: Dictionary, n: int = 1) -> void:
	def = d
	count = n
	for _p in d.get("pockets", []):
		pockets.append([])

func id() -> String:
	return def["id"]

func has_tag(t: String) -> bool:
	return t in def.get("tags", [])

func is_liquid() -> bool:
	return has_tag("liquid")

func unit_volume() -> int:
	return int(def.get("volume_ml", 0))

func contents_volume(pi: int) -> int:
	var v := 0
	for it in pockets[pi]:
		v += it.volume()
	return v

func contents_weight(pi: int) -> int:
	var w := 0
	for it in pockets[pi]:
		w += it.weight()
	return w

## total volume in ml: own volume (x count) plus the contents of flexible pockets
func volume() -> int:
	var v: int = unit_volume() * count
	var defs: Array = def.get("pockets", [])
	for i in defs.size():
		if defs[i].get("flexible", false):
			v += contents_volume(i)
		else:
			v += maxi(0, contents_volume(i) - int(defs[i]["max_volume_ml"]))   # cannot happen via insert, kept as a guard
	return v

func weight() -> int:
	var w: int = int(def.get("weight_g", 0)) * count
	for m in mods:
		w += m.weight()
	for i in pockets.size():
		w += contents_weight(i)
	return w

func contains_item(other) -> bool:
	for p in pockets:
		for it in p:
			if it == other or it.contains_item(other):
				return true
	return false

## would `it` go into pocket pi of this item? returns "" if yes, otherwise the reason
func why_not(pi: int, it) -> String:
	if it == self or it.contains_item(self):
		return "cycle"
	var pd: Dictionary = def["pockets"][pi]
	var allow: Array = pd.get("allow_tags", [])
	if not allow.is_empty():
		var ok := false
		for t in allow:
			if it.has_tag(t):
				ok = true
		if not ok:
			return "restricted"
	if it.is_liquid() and not pd.get("watertight", false):
		return "not watertight"
	if it.is_liquid() and not allow.has("liquid") and not allow.is_empty():
		return "restricted"
	var maxlen: int = int(pd.get("max_item_length_mm", 0))
	if maxlen > 0 and int(it.def.get("length_mm", 0)) > maxlen:
		return "too long"
	if contents_volume(pi) + it.volume() > int(pd["max_volume_ml"]):
		return "too big"
	if contents_weight(pi) + it.weight() > int(pd["max_weight_g"]):
		return "too heavy"
	return ""

## put `it` into the best-fitting pocket of this item (smallest free volume that still fits, like CDDA's best-fit rule); false if none
func insert(it) -> bool:
	var best := -1
	var best_free := 1 << 60
	for i in pockets.size():
		if why_not(i, it) == "":
			var free: int = int(def["pockets"][i]["max_volume_ml"]) - contents_volume(i)
			if free < best_free:
				best_free = free
				best = i
	if best < 0:
		return false
	# stack identical items and per-unit liquids
	for other in pockets[best]:
		if other.id() == it.id() and other.pockets.is_empty():
			other.count += it.count
			return true
	pockets[best].append(it)
	return true

## depth-first: try our own pockets, then those of items inside us
func insert_deep(it) -> bool:
	if insert(it):
		return true
	for p in pockets:
		for sub in p:
			if sub.insert_deep(it):
				return true
	return false

func remove(it) -> bool:
	for p in pockets:
		if p.has(it):
			p.erase(it)
			return true
		for sub in p:
			if sub.remove(it):
				return true
	return false

func to_dict() -> Dictionary:
	var out := {"id": id(), "count": count}
	var cs := []
	for p in pockets:
		var arr := []
		for it in p:
			arr.append(it.to_dict())
		cs.append(arr)
	if not def.get("pockets", []).is_empty():
		out["contents"] = cs
	if cond >= 0:
		out["cond"] = cond
	if def.has("gun"):
		out["gun"] = {"loaded": loaded, "kind": kind, "jammed": jammed, "mode": mode, "mods": mods.map(func(m): return m.to_dict())}
	return out

static func from_dict(d: Dictionary, db):
	var it = ItemScript.new(db.defs[d["id"]], int(d.get("count", 1)))
	if d.has("contents"):
		for i in d["contents"].size():
			for sub in d["contents"][i]:
				it.pockets[i].append(from_dict(sub, db))
	it.cond = int(d.get("cond", -1))
	if d.has("gun"):
		var gd: Dictionary = d["gun"]
		it.loaded = int(gd["loaded"])
		it.kind = String(gd["kind"])
		it.jammed = bool(gd["jammed"])
		it.mode = int(gd["mode"])
		for m in gd["mods"]:
			it.mods.append(from_dict(m, db))
	return it
