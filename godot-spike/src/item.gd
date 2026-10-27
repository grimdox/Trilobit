extends RefCounted
## An item instance.  Every item is one tile in the inventory grid (src/game.gd); a stack of identical items is still one tile.
##  - `count` is the stack size
##  - a water bottle keeps its water in `fill` (millilitres, like rounds in a magazine)
##  - guns keep their magazine, ammunition kind and fitted mods
const ItemScript = preload("res://src/item.gd")

var def: Dictionary
var count: int = 1                         # stack size
var fill: int = 0                          # water in a bottle, mL
# gun state (only used when def has a "gun" block)
var loaded: int = 0                        # rounds in the magazine
var kind: String = ""                      # ammunition kind loaded ("" when empty)
var mods: Array = []                       # installed mod items
var jammed: bool = false
var mode: int = 0                          # index into gun.modes
var cond: int = -1                         # wear: hit points left on armor or an engine (-1 = as new)

func _init(d: Dictionary, n: int = 1) -> void:
	def = d
	count = n

func id() -> String:
	return def["id"]

func has_tag(t: String) -> bool:
	return t in def.get("tags", [])

## can another copy of this item share its tile?  Weapons, armor, pocket items, implants and bottles keep their own tile each.
func stackable() -> bool:
	return not (def.has("gun") or def.has("melee") or def.has("armor") or def.has("pocket") or def.has("implant") or def.has("nano") or def.has("bottle"))

func weight() -> int:
	return int(def.get("weight_g", 0)) * count

## grams of weapon, for the rules that use it (a heavy weapon knocks harder); the inventory itself has no weight
func weapon_grams() -> int:
	return int(def.get("weight_g", 0))

func to_dict() -> Dictionary:
	var out := {"id": id(), "count": count}
	if def.has("bottle"):
		out["fill"] = fill
	if cond >= 0:
		out["cond"] = cond
	if def.has("gun"):
		out["gun"] = {"loaded": loaded, "kind": kind, "jammed": jammed, "mode": mode, "mods": mods.map(func(m): return m.to_dict())}
	return out

static func from_dict(d: Dictionary, db):
	var it = ItemScript.new(db.defs[d["id"]], int(d.get("count", 1)))
	it.fill = int(d.get("fill", 0))
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
