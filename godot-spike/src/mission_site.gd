extends RefCounted
## The generated site a mission takes place in.  It is its own small map, 64 x 64, built from the offer's seed and nothing else: it has no place in the
## island, so it can never collide with the physical world, and it is thrown away when the player leaves it.
##   a walled compound; its south half is an entry hall (the exit door, then a wall with two doors), its north half is split into two rooms by a
##   wall with one door.  One north room holds the objective, the other is the guards' room.  Door positions, which room is which, the props and
##   where everybody stands all come from the seed.  The exit portal stands on the open ground south of the compound.
## build() returns a CG whose meta "site" holds {entry, exit, objective, rooms, agents:[{role, cell, fac, name}], floor cells}.
const CG = preload("res://src/citygen.gd")
const MS = preload("res://src/missions.gd")

const SIZE := 64
const X0 := 10
const X1 := 53
const Y0 := 12
const Y1 := 53
const MID_Y := 33          # the wall between the entry hall and the north rooms
const MID_X := 31          # the wall between the two north rooms

static func build(offer: Dictionary):
	var rng := RandomNumberGenerator.new()
	rng.seed = int(offer["seed"]) ^ 0x51e7
	var c = CG.new()
	c.size = SIZE
	var s2: int = SIZE * SIZE
	c.tiles = PackedByteArray(); c.tiles.resize(s2)
	c.tiles.fill(CG.PARK)
	c.marks = PackedByteArray(); c.marks.resize(s2)
	c.under = PackedByteArray(); c.under.resize(s2)
	for y in range(4, SIZE - 4):
		for x in range(4, SIZE - 4):
			c.tiles[y * SIZE + x] = CG.GROUND
	var steel: int = CG.TID["floor_steel"]
	var clean: int = CG.TID["floor_clean"]
	# shell
	for y in range(Y0, Y1 + 1):
		for x in range(X0, X1 + 1):
			var edge: bool = x == X0 or x == X1 or y == Y0 or y == Y1
			c.tiles[y * SIZE + x] = CG.WALL if edge else (steel if y > MID_Y else clean)
	for x in range(X0, X1 + 1):
		c.tiles[MID_Y * SIZE + x] = CG.WALL
	for y in range(Y0, MID_Y):
		c.tiles[y * SIZE + MID_X] = CG.WALL
	# doors: the exit in the south wall, two in the middle wall, one between the north rooms
	var ex: int = SIZE / 2
	c.tiles[Y1 * SIZE + ex] = CG.DOOR
	var da: int = rng.randi_range(X0 + 4, MID_X - 5)
	var db: int = rng.randi_range(MID_X + 5, X1 - 4)
	c.tiles[MID_Y * SIZE + da] = CG.DOOR
	c.tiles[MID_Y * SIZE + db] = CG.DOOR
	var dn: int = rng.randi_range(Y0 + 4, MID_Y - 4)
	c.tiles[dn * SIZE + MID_X] = CG.DOOR
	var exit_cell: int = (Y1 + 4) * SIZE + ex
	var entry: int = (Y1 + 2) * SIZE + ex
	c.tiles[exit_cell] = CG.TID["portal"]
	c.under[exit_cell] = CG.GROUND
	# the rooms
	var west := Rect2i(X0 + 1, Y0 + 1, MID_X - X0 - 1, MID_Y - Y0 - 1)
	var east := Rect2i(MID_X + 1, Y0 + 1, X1 - MID_X - 1, MID_Y - Y0 - 1)
	var hall := Rect2i(X0 + 1, MID_Y + 1, X1 - X0 - 1, Y1 - MID_Y - 1)
	var obj_room: Rect2i = west if rng.randi() % 2 == 0 else east
	var other_room: Rect2i = east if obj_room == west else west
	var used := {}
	used[entry] = true
	used[exit_cell] = true
	# keep every door and the cells beside it clear
	for d in [Vector2i(ex, Y1), Vector2i(da, MID_Y), Vector2i(db, MID_Y), Vector2i(MID_X, dn)]:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				used[(d.y + dy) * SIZE + d.x + dx] = true
	var mov: Array = []
	# furniture: crates and tables against nothing in particular, never closer than two cells to a wall so no corridor is ever sealed
	for rect in [west, east, hall]:
		var n: int = rng.randi_range(5, 9) if rect == hall else rng.randi_range(3, 6)
		for _k in n * 6:
			if n <= 0:
				break
			var x: int = rng.randi_range(rect.position.x + 2, rect.end.x - 3)
			var y: int = rng.randi_range(rect.position.y + 2, rect.end.y - 3)
			var cell: int = y * SIZE + x
			if _near_used(used, cell, 1):
				continue
			used[cell] = true
			mov.append([cell, ["crate", "crate", "table", "chair"][rng.randi() % 4]])
			n -= 1
	c.movables = mov
	var site := {"entry": entry, "exit": exit_cell, "doors": [ex, da, db, dn], "agents": [], "obj_room": [obj_room.position.x, obj_room.position.y, obj_room.size.x, obj_room.size.y]}
	# the objective
	var obj: int = _pick(rng, obj_room, used, 3)
	used[obj] = true
	site["objective"] = obj
	var t: String = offer["type"]
	var risk: int = int(offer["risk"])
	match t:
		"repair", "sabotage":
			c.tiles[obj] = CG.TID["mission_device"]
			c.under[obj] = clean
		"recover":
			site["case"] = obj
			# the case may lie in either north room
			if rng.randi() % 3 == 0:
				var o2: int = _pick(rng, other_room, used, 2)
				used[o2] = true
				site["case"] = o2
		"assassination":
			site["agents"].append({"role": "target", "cell": obj, "fac": 3, "name": offer["target"]})
			for k in 1 + (1 if risk >= 2 else 0):
				var gc: int = _near(rng, obj, used, 2, SIZE)
				if gc >= 0:
					used[gc] = true
					site["agents"].append({"role": "bodyguard", "cell": gc, "fac": 1, "name": ""})
		"rescue":
			site["agents"].append({"role": "hostage", "cell": obj, "fac": 0, "name": offer["target"]})
	# the guards: some in the other room, the rest in the entry hall and the objective room
	var want: int = MS.guard_count(risk) - (site["agents"].size() - 1 if t == "assassination" else 0)
	var rooms: Array = [other_room, hall, obj_room, hall, other_room]
	for k in want:
		var gc: int = _pick(rng, rooms[k % rooms.size()], used, 3)
		if gc < 0:
			continue
		if _dist(gc, entry) < 8:
			continue
		used[gc] = true
		site["agents"].append({"role": "guard", "cell": gc, "fac": 2 if k % 3 != 2 else 3, "name": ""})
	# markers the NPC simulation needs (it builds its flow fields from them): a few cells in each part of the compound
	var mk := PackedInt32Array()
	for r in [west, east, hall]:
		mk.append((r.position.y + 1) * SIZE + r.position.x + 1)
	c.homes = mk
	c.works = mk
	c.shops = mk
	c.homes_g = mk
	c.works_g = mk
	c.shops_g = mk
	c.homes_t = PackedInt32Array()
	c.works_t = PackedInt32Array()
	c.shops_t = PackedInt32Array()
	c.lairs = PackedInt32Array()
	c.subway = {"ring": PackedInt32Array(), "stops": []}
	c.tower_info = []
	c.vaults = []
	c.venues = []
	c.towers = []
	c.zmax = 0
	c.nlev = 3
	var rock := PackedByteArray()
	rock.resize(s2)
	rock.fill(CG.EARTH)
	var all: PackedByteArray = c.tiles.duplicate()
	all.append_array(rock)
	all.append_array(rock)
	c.tiles = all
	c.links = {}
	c.haslink = PackedByteArray()
	c.haslink.resize(all.size())
	c.set_meta("site", site)
	return c

static func _dist(a: int, b: int) -> int:
	return maxi(absi(a % SIZE - b % SIZE), absi(a / SIZE - b / SIZE))

static func _near_used(used: Dictionary, cell: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if used.has(cell + dy * SIZE + dx):
				return true
	return false

## a free cell in a room, at least `margin` from its walls (so it is never against one), not beside a prop or a door
static func _pick(rng: RandomNumberGenerator, rect: Rect2i, used: Dictionary, margin: int) -> int:
	for _k in 80:
		var x: int = rng.randi_range(rect.position.x + margin, maxi(rect.position.x + margin, rect.end.x - 1 - margin))
		var y: int = rng.randi_range(rect.position.y + margin, maxi(rect.position.y + margin, rect.end.y - 1 - margin))
		var cell: int = y * SIZE + x
		if not used.has(cell) and not _near_used(used, cell, 1):
			return cell
	return -1

## a free cell within r of another
static func _near(rng: RandomNumberGenerator, cell: int, used: Dictionary, r: int, size: int) -> int:
	for _k in 40:
		var x: int = cell % size + rng.randi_range(-r, r)
		var y: int = cell / size + rng.randi_range(-r, r)
		var c2: int = y * size + x
		if c2 != cell and not used.has(c2):
			return c2
	return -1
