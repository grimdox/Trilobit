extends RefCounted
## What the player carries: nine equipment slots and a grid of tiles.  Every object is one tile.
##  - The grid is a base of 15 tiles (5 x 3) plus the tiles of any pocket item worn (coat on the Chest, fanny pack or belt pouch on the Belt, backpack on the Back).
##  - A stack of identical items (rations, mods) is one tile.  Weapons, armor, pocket items, implants and bottles keep a tile each.
##  - A weapon takes one hand or two (def "hands"); a two-handed weapon sits in the Right Hand and shuts the Left.
## This file is only the bookkeeping: Game decides what an item does once it is held, worn or wielded.

const SLOTS := ["head", "eyes", "chest", "arms", "legs", "lhand", "rhand", "belt", "back"]
const NAMES := {"head": "Head", "eyes": "Eyes", "chest": "Chest", "arms": "Arms", "legs": "Legs", "lhand": "Left Hand", "rhand": "Right Hand", "belt": "Belt", "back": "Back"}
const BASE := 15
const BASE_COLS := 5
const POCKET_SLOTS := ["chest", "belt", "back"]        # the order extra tiles follow the base grid

var equip: Dictionary = {}                               # slot id -> item
var grid: Dictionary = {}                                # group id ("base", "chest", "belt", "back") -> Array of item or null
var last_err: String = ""                                # why the last refused operation was refused

func _init() -> void:
	grid["base"] = _blank(BASE)

func _blank(n: int) -> Array:
	var a: Array = []
	a.resize(n)
	return a

# ---------------------------------------------------------------- what an item may do
## equipment slots an item can go in, best first; empty when it is not equipment (food, medkits, mods, implants, ...)
static func slot_options(it) -> Array:
	var d: Dictionary = it.def
	if d.has("armor"):
		var s: String = String(d["armor"]["slot"])
		return ["eyes" if s == "optic" else s]
	if d.has("pocket"):
		return [String(d["pocket"]["slot"])]
	if d.has("gun") or d.has("melee"):
		return ["rhand"] if hands(it) == 2 else ["rhand", "lhand"]
	return []

static func hands(it) -> int:
	return int(it.def.get("hands", 1))

static func is_equipment(it) -> bool:
	return not slot_options(it).is_empty()

static func pocket_tiles(it) -> int:
	return int(it.def["pocket"]["tiles"]) if it.def.has("pocket") else 0

static func slot_label(slot: String) -> String:
	return NAMES.get(slot, slot)

## a short line for the item card: "Equip: Chest" or "Not equipment"
static func equip_text(it) -> String:
	if it.def.has("nano"):
		return "Install in Trilobit"
	var o: Array = slot_options(it)
	if o.is_empty():
		return "Not equipable"
	if it.def.has("gun") or it.def.has("melee"):
		return "Equips to: %s" % ("both hands" if hands(it) == 2 else "Right Hand or Left Hand")
	return "Equips to: %s" % NAMES[o[0]]

# ---------------------------------------------------------------- the grid's shape
func groups() -> Array:
	var out: Array = ["base"]
	for s in POCKET_SLOTS:
		if equip.has(s) and equip[s].def.has("pocket"):
			out.append(s)
	return out

func group_size(g: String) -> int:
	return BASE if g == "base" else pocket_tiles(equip[g])

func group_cols(g: String) -> int:
	return BASE_COLS if g == "base" else mini(group_size(g), 6)

func group_label(g: String) -> String:
	return "INVENTORY" if g == "base" else String(equip[g].def["name"]).to_upper()

func capacity() -> int:
	var n := 0
	for g in groups():
		n += group_size(g)
	return n

func used() -> int:
	return grid_items().size()

# ---------------------------------------------------------------- reading it
## every item in the grid, in group order
func grid_items() -> Array:
	var out: Array = []
	for g in groups():
		for it in grid[g]:
			if it != null:
				out.append(it)
	return out

func equipped_items() -> Array:
	var out: Array = []
	for s in SLOTS:
		if equip.has(s):
			out.append(equip[s])
	return out

## equipment first (in slot order), then the grid
func all_items() -> Array:
	return equipped_items() + grid_items()

## where an item is: {t: "eq", slot} or {t: "grid", g, i} or {} when it is not carried
func find(it) -> Dictionary:
	for s in SLOTS:
		if equip.get(s) == it:
			return {"t": "eq", "slot": s}
	for g in groups():
		var a: Array = grid[g]
		for i in a.size():
			if a[i] == it:
				return {"t": "grid", "g": g, "i": i}
	return {}

func at(ref: Dictionary):
	if ref.is_empty():
		return null
	if ref["t"] == "eq":
		return equip.get(ref["slot"])
	if not grid.has(ref["g"]):
		return null
	return grid[ref["g"]][ref["i"]]

func _free_in(g: String) -> int:
	var a: Array = grid[g]
	for i in a.size():
		if a[i] == null:
			return i
	return -1

func free_tiles(skip_group: String = "") -> int:
	var n := 0
	for g in groups():
		if g == skip_group:
			continue
		for it in grid[g]:
			if it == null:
				n += 1
	return n

# ---------------------------------------------------------------- putting things away
## a tile for it: join an identical stack, else the first free tile
func stow(it) -> bool:
	if it.stackable():
		for g in groups():
			for other in grid[g]:
				if other != null and other != it and other.id() == it.id() and other.stackable():
					other.count += it.count
					return true
	for g in groups():
		var i: int = _free_in(g)
		if i >= 0:
			grid[g][i] = it
			return true
	return false

## take an item out of wherever it is (the grid or a slot); false if it is not carried or cannot leave (a pocket item whose tiles hold things that have nowhere to go)
func remove(it) -> bool:
	var ref: Dictionary = find(it)
	if ref.is_empty():
		return false
	if ref["t"] == "grid":
		grid[ref["g"]][ref["i"]] = null
		return true
	return _unseat(ref["slot"])

## take a pocket item off its slot: its tiles go with it and what is in them stays in them (the item keeps them as its `stash`)
func _clear_group(slot: String) -> bool:
	if grid.has(slot) and equip.has(slot):
		equip[slot].stash = grid[slot]
	grid.erase(slot)
	equip.erase(slot)
	return true

func _unseat(slot: String) -> bool:
	var it = equip.get(slot)
	if it == null:
		return false
	if it.def.has("pocket") and not _clear_group(slot):
		return false
	equip.erase(slot)
	return true

# ---------------------------------------------------------------- equipping
## why `it` cannot go in `slot` right now, or "" if it can
func why_not(slot: String, it) -> String:
	if not (slot in slot_options(it)):
		return "The %s does not go there." % it.def["name"]
	if slot == "lhand" and equip.has("rhand") and hands(equip["rhand"]) == 2 and equip["rhand"] != it:
		return "Your hands are full with the %s." % equip["rhand"].def["name"]
	if slot == "rhand" and hands(it) == 2 and equip.has("lhand") and equip["lhand"] != it and free_tiles() < 1:
		return "No room to put your left-hand item away."
	return ""

## put `it` (already out of the grid) in a slot.  Returns the item it displaced (or null); sets last_err and returns false-like {} on refusal.
## The result is {"ok": bool, "back": displaced item or null}
func put_equip(slot: String, it) -> Dictionary:
	last_err = why_not(slot, it)
	if last_err != "":
		return {"ok": false, "back": null}
	var old = equip.get(slot)
	if old != null:
		if not _unseat(slot):
			return {"ok": false, "back": null}
	if slot == "rhand" and hands(it) == 2 and equip.has("lhand"):
		var off = equip["lhand"]
		equip.erase("lhand")
		if not stow(off):
			equip["lhand"] = off
			if old != null:
				equip[slot] = old
				if old.def.has("pocket"):
					_ensure_group(slot)
			last_err = "No room to put your left-hand item away."
			return {"ok": false, "back": null}
	equip[slot] = it
	_ensure_group(slot)
	return {"ok": true, "back": old}

func _ensure_group(slot: String) -> void:
	var it = equip.get(slot)
	if it != null and it.def.has("pocket"):
		if it.stash.size() != pocket_tiles(it):
			it.stash.resize(pocket_tiles(it))
		grid[slot] = it.stash                    # one array: the worn pocket's tiles and the item's own contents

## put `it` inside a pocket item `box` (worn or not): joins a stack or takes the first free tile.  Containers do not nest.
func put_in(box, it) -> bool:
	if box == null or not box.def.has("pocket"):
		last_err = "That is not a container."
		return false
	if it == box or it.def.has("pocket"):
		last_err = "A container will not fit inside another."
		return false
	var n: int = pocket_tiles(box)
	if box.stash.size() != n:
		box.stash.resize(n)
	if it.stackable():
		for other in box.stash:
			if other != null and other.id() == it.id() and other.stackable():
				other.count += it.count
				return true
	for i in n:
		if box.stash[i] == null:
			box.stash[i] = it
			return true
	last_err = "The %s is full." % box.def["name"]
	return false

## drop an item in a grid tile; an item already there is handed back (it swaps), identical stacks merge
func put_grid(g: String, i: int, it) -> Dictionary:
	if not grid.has(g) or i < 0 or i >= grid[g].size():
		last_err = "No such tile."
		return {"ok": false, "back": null}
	var cur = grid[g][i]
	if cur != null and cur.stackable() and it.stackable() and cur.id() == it.id():
		cur.count += it.count
		return {"ok": true, "back": null}
	grid[g][i] = it
	return {"ok": true, "back": cur}

## auto-equip a carried item: the first free fitting slot, else swap with the first fitting slot (the old piece takes its tile).  True when done.
func auto_equip(it) -> bool:
	var opts: Array = slot_options(it)
	if opts.is_empty():
		last_err = "The %s is not equipment." % it.def["name"]
		return false
	var ref: Dictionary = find(it)
	if ref.is_empty() or ref["t"] != "grid":
		last_err = "It is already equipped."
		return false
	var pick: String = ""
	for s in opts:
		if not equip.has(s) and why_not(s, it) == "":
			pick = s
			break
	if pick == "":
		for s in opts:
			if why_not(s, it) == "":
				pick = s
				break
	if pick == "":
		last_err = why_not(opts[0], it)
		return false
	var g: String = ref["g"]
	var i: int = ref["i"]
	grid[g][i] = null
	var r: Dictionary = put_equip(pick, it)
	if not r["ok"]:
		grid[g][i] = it
		return false
	var back = r["back"]
	if back != null:
		if not stow(back):
			# no tile for the old piece: undo
			equip[pick] = back
			_ensure_group(pick)
			grid[g][i] = it
			last_err = "No room for the %s." % back.def["name"]
			return false
	return true

## take off whatever is in a slot and put it in the grid
func auto_unequip(slot: String) -> bool:
	var it = equip.get(slot)
	if it == null:
		return false
	if it.def.has("pocket"):
		# its own tiles go away with it: check there is a tile for the item itself after they are emptied
		if not _clear_group(slot):
			return false
		equip.erase(slot)
		if not stow(it):
			equip[slot] = it
			_ensure_group(slot)
			last_err = "No room in your pockets for the %s." % it.def["name"]
			return false
		return true
	equip.erase(slot)
	if not stow(it):
		equip[slot] = it
		last_err = "No room in your pockets for the %s." % it.def["name"]
		return false
	return true

# ---------------------------------------------------------------- saving
func to_dict() -> Dictionary:
	var eq := {}
	for s in equip:
		eq[s] = equip[s].to_dict()
	var gr := {}
	for g in groups():
		gr[g] = (grid[g] as Array).map(func(x): return null if x == null else x.to_dict())
	return {"equip": eq, "grid": gr}

func load_dict(d: Dictionary, db) -> void:
	const ItemScript = preload("res://src/item.gd")
	equip = {}
	grid = {"base": _blank(BASE)}
	for s in d.get("equip", {}):
		if db.defs.has(String(d["equip"][s]["id"])):                # an item that no longer exists (a credstick, say) is left out of an old save
			equip[s] = ItemScript.from_dict(d["equip"][s], db)
	for g in groups():
		grid[g] = _blank(group_size(g))
	for g in d.get("grid", {}):
		if not grid.has(g):
			continue
		var src: Array = d["grid"][g]
		for i in mini(src.size(), (grid[g] as Array).size()):
			if src[i] != null and db.defs.has(String(src[i]["id"])):
				grid[g][i] = ItemScript.from_dict(src[i], db)
	for g in groups():
		if g != "base":
			equip[g].stash = grid[g]                  # worn pockets: the item's own tiles are these tiles
