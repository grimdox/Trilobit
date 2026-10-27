extends RefCounted
## Vehicles at human scale.  Every vehicle is a footprint of tiles taken from an ASCII template, rotated to one of four headings:
##   E engine bay   C cabin (the 2x2 seats)   K canopy glass   T trunk or cargo   B body panel   P wing or fin   H turret   W wheel   L leg   R rotor mast
## A car is 3 wide by 5 long: engine bay in front, a two-seat cabin in the middle, trunk behind, a wheel on each corner.  The lane of a road is
## six tiles (white edge, four black, yellow centre), so a car sits in a lane with a tile to spare.  The `cell` of a vehicle is its driver's seat (the front left
## cabin tile); `veh_at` and `sim.walk` mark every tile of the footprint.  Each vehicle has four parts with their own hit points: the engine
## (swappable, from an item), the body, the drive (wheels, rotor or legs) and the cabin.
const CG = preload("res://src/citygen.gd")
const DIR4 := [[0, -1], [1, 0], [0, 1], [-1, 0]]
## ground vehicles (car, truck) head in eight directions: dir 0..7 clockwise from north in 45 degree steps (0 N, 1 NE, 2 E ... 7 NW).  Every other kind keeps four (0..3).
const DIR8 := [[0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1]]
const GROUND8 := ["car", "truck"]
const KPH_PER_TILE := 15                               # a tile a turn is 15 km/h: the city car's 3 tiles is 45, a hauler's 6 is 90

static func is_g8(kind: String) -> bool:
	return kind in GROUND8

## a heading given as a quarter turn (0..3) in the units of that kind of vehicle
static func h(kind: String, d4: int) -> int:
	return d4 * 2 if kind in GROUND8 else d4
const GROUND_OK := [1, 0, 6, 31, 32]                  # road, pavement, grass, field, sand
const LAND_OK := [1, 0, 6, 31, 32, 11, 13, 30]        # ... plus roofs, platforms and rocks, for a helicopter's skids
const MECH_OK := [1, 0, 6, 31, 32, 30, 20, 23, 24, 25]
const PART_OF := {"E": "engine", "B": "body", "T": "body", "P": "body", "H": "body", "R": "drive", "W": "drive", "L": "drive", "C": "cabin", "K": "cabin"}

const KINDS := {
	"car": {"name": "car", "drive": "wheels", "move": "ground", "anchor": [2, 1], "engine": "trl_eng_city", "parts": {"engine": 50, "body": 90, "drive": 40, "cabin": 30},
		"rows": ["WEW", "BEB", "BCB", "BCB", "WTW"]},
	"truck": {"name": "truck", "drive": "wheels", "move": "ground", "anchor": [2, 1], "engine": "trl_eng_haul", "parts": {"engine": 90, "body": 160, "drive": 70, "cabin": 45},
		"rows": ["WEEEEW", "BEEEEB", "BCCCCB", "BCCCCB", "BBBBBB", "BTTTTB", "BTTTTB", "BTTTTB", "BTTTTB", "BTTTTB", "BTTTTB", "WTTTTW"]},
	"heli": {"name": "helicopter", "drive": "rotor", "move": "air", "anchor": [1, 2], "engine": "trl_eng_rotor", "parts": {"engine": 60, "body": 60, "drive": 35, "cabin": 25},
		"rows": [".KKKK.", ".KCCK.", ".KCCK.", "BBBBBB", ".BEEB.", ".BEEB.", "..BB..", "..BB..", "..RR.."]},
	"plane": {"name": "plane", "drive": "propeller", "move": "plane", "anchor": [1, 5], "engine": "trl_eng_rotor", "parts": {"engine": 70, "body": 80, "drive": 40, "cabin": 30},
		"rows": ["....KKKK....", "....KCCK....", "....KCCK....", "PPPPBBBBPPPP", "PPPPBEEBPPPP", "....BBBB....", "....BTTB....", "....BTTB....", ".....BB.....", ".PPPPBBPPPP."]},
	"mech": {"name": "mech", "drive": "legs", "move": "mech", "anchor": [1, 2], "engine": "trl_eng_reactor", "parts": {"engine": 90, "body": 160, "drive": 70, "cabin": 40},
		"rows": [".HHH.", "BBCBB", "BBBBB", "LL.LL", "LL.LL"]},
}

var g
var _off: Dictionary = {}

func _init(game) -> void:
	g = game

# ---------------------------------------------------------------- geometry
static func rot(u: int, f: int, dir: int) -> Array:
	match dir:
		0: return [u, -f]
		1: return [f, u]
		2: return [-u, f]
	return [-f, -u]

func offsets(kind: String, dir: int) -> Array:
	var key := kind + str(dir)
	if _off.has(key):
		return _off[key]
	var t: Dictionary = KINDS[kind]
	var rows: Array = t["rows"]
	var an: Array = t["anchor"]
	var out := []
	if is_g8(kind) and dir % 2 == 1:
		# a diagonal heading: every grid cell whose centre falls inside the turned body takes the template tile it lands on
		var ang: float = float(dir) * PI / 4.0
		var fx: float = sin(ang)
		var fy: float = -cos(ang)
		var rx: float = cos(ang)
		var ry: float = sin(ang)
		var hh: int = rows.size()
		var ww: int = String(rows[0]).length()
		var reach: int = maxi(hh, ww) + 1
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var f: float = dx * fx + dy * fy
				var u: float = dx * rx + dy * ry
				var col: int = int(round(u)) + int(an[1])
				var row_i: int = int(an[0]) - int(round(f))
				if col < 0 or row_i < 0 or col >= ww or row_i >= hh:
					continue
				var ch2: String = String(rows[row_i])[col]
				if ch2 != ".":
					out.append([dx, dy, ch2])
		_off[key] = out
		return out
	var qd: int = dir / 2 if is_g8(kind) else dir
	for r in rows.size():
		var row: String = rows[r]
		for c in row.length():
			var ch := row[c]
			if ch == ".":
				continue
			var d: Array = rot(c - int(an[1]), int(an[0]) - r, qd)
			out.append([d[0], d[1], ch])
	_off[key] = out
	return out

func cells(v: Dictionary) -> PackedInt32Array:
	return cells_at(v["kind"], int(v["cell"]), int(v["dir"]))

func cells_at(kind: String, anchor: int, dir: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var base: int = (anchor / g.s2) * g.s2
	var ax: int = anchor % g.size
	var ay: int = (anchor % g.s2) / g.size
	for o in offsets(kind, dir):
		var x: int = ax + o[0]
		var y: int = ay + o[1]
		if x >= 0 and y >= 0 and x < g.size and y < g.size:
			out.append(base + y * g.size + x)
	return out

## the part a footprint tile belongs to ("" if the cell is not part of the vehicle)
func part_at(v: Dictionary, cell: int) -> String:
	var a: int = int(v["cell"])
	var dx: int = cell % g.size - a % g.size
	var dy: int = (cell % g.s2) / g.size - (a % g.s2) / g.size
	for o in offsets(v["kind"], int(v["dir"])):
		if o[0] == dx and o[1] == dy:
			return PART_OF.get(String(o[2]), "body")
	return ""

## twice the centre of the footprint's bounding box (so a 4x6 body has an integer centre); x, y
func center2(kind: String, anchor: int, dir: int) -> Vector2i:
	var x0 := 1 << 20
	var x1 := -(1 << 20)
	var y0 := 1 << 20
	var y1 := -(1 << 20)
	for o in offsets(kind, dir):
		x0 = mini(x0, o[0])
		x1 = maxi(x1, o[0])
		y0 = mini(y0, o[1])
		y1 = maxi(y1, o[1])
	var ax: int = anchor % g.size
	var ay: int = (anchor % g.s2) / g.size
	return Vector2i(2 * ax + x0 + x1 + 1, 2 * ay + y0 + y1 + 1)

## the middle of the whole body in tile coordinates (a cell (x, y) spans x..x+1), at any heading: the point the painted sprite is turned about
func true_center(kind: String, anchor: int, dir: int) -> Vector2:
	var t: Dictionary = KINDS[kind]
	var rows: Array = t["rows"]
	var an: Array = t["anchor"]
	var cu: float = (float(String(rows[0]).length()) - 1.0) * 0.5 - float(an[1])
	var cf: float = float(an[0]) - (float(rows.size()) - 1.0) * 0.5
	var ax: float = float(anchor % g.size) + 0.5
	var ay: float = float((anchor % g.s2) / g.size) + 0.5
	var ang: float = (float(dir) * PI / 4.0) if is_g8(kind) else (float(dir) * PI / 2.0)
	return Vector2(ax + cu * cos(ang) + cf * sin(ang), ay + cu * sin(ang) - cf * cos(ang))

## the unit step a heading takes (dx, dy)
func fwd(kind: String, dir: int) -> Vector2i:
	if is_g8(kind):
		return Vector2i(DIR8[dir][0], DIR8[dir][1])
	return Vector2i(DIR4[dir][0], DIR4[dir][1])

## the anchor that puts the footprint's centre at (cx2, cy2) (twice the coordinates), on the level of `base_cell`
func anchor_for(kind: String, dir: int, cx2: int, cy2: int, base_cell: int) -> int:
	var x0 := 1 << 20
	var x1 := -(1 << 20)
	var y0 := 1 << 20
	var y1 := -(1 << 20)
	for o in offsets(kind, dir):
		x0 = mini(x0, o[0])
		x1 = maxi(x1, o[0])
		y0 = mini(y0, o[1])
		y1 = maxi(y1, o[1])
	var ax: int = (cx2 - 1 - x0 - x1) / 2
	var ay: int = (cy2 - 1 - y0 - y1) / 2
	var base: int = (base_cell / g.s2) * g.s2
	return base + ay * g.size + ax

# ---------------------------------------------------------------- what is in the way
func _tile_ok(kind: String, airborne: bool, t: int) -> bool:
	var mv: String = KINDS[kind]["move"]
	if airborne:
		return t == CG.AIR
	match mv:
		"mech": return t in MECH_OK
		"air", "plane": return t in LAND_OK
	return t in GROUND_OK

## the first thing that stops this vehicle standing at `anchor` heading `dir`: {} if nothing, else {t: person|player|critter|vehicle|thing|solid|edge, cell, idx}
func probe(vi: int, anchor: int, dir: int, airborne: bool = false) -> Dictionary:
	var v: Dictionary = g.vehicles[vi]
	var kind: String = v["kind"]
	var base: int = (anchor / g.s2) * g.s2
	var ax: int = anchor % g.size
	var ay: int = (anchor % g.s2) / g.size
	var best := {}
	var rank := -1
	for o in offsets(kind, dir):
		var x: int = ax + o[0]
		var y: int = ay + o[1]
		if x < 0 or y < 0 or x >= g.size or y >= g.size:
			if rank < 0:
				best = {"t": "edge", "cell": -1, "idx": -1}
				rank = 0
			continue
		var c: int = base + y * g.size + x
		var hit := {}
		var r := -1
		if g.sim.at[c] != -1:
			hit = {"t": "person", "cell": c, "idx": g.sim.at[c]}
			r = 6
		elif g.pc == c and vi != g.in_vehicle and not g.flying:
			hit = {"t": "player", "cell": c, "idx": -1}
			r = 6
		elif g.crit_at.g(c) != -1:
			hit = {"t": "critter", "cell": c, "idx": g.crit_at.g(c)}
			r = 5
		elif g.veh_at.g(c) != -1 and g.veh_at.g(c) != vi:
			hit = {"t": "vehicle", "cell": c, "idx": g.veh_at.g(c)}
			r = 4
		elif g.thing_at.g(c) != -1:
			hit = {"t": "thing", "cell": c, "idx": g.thing_at.g(c)}
			r = 3
		elif not _tile_ok(kind, airborne, g.city.tiles[c]):
			hit = {"t": "solid", "cell": c, "idx": -1}
			r = 2
		if r > rank:
			rank = r
			best = hit
	return best

func fits(vi: int, anchor: int, dir: int, airborne: bool = false) -> bool:
	return probe(vi, anchor, dir, airborne).is_empty()

func _restore_walk(c: int) -> void:
	g.sim.walk[c] = 1 if (g.city.walkable(g.city.tiles[c]) and g.thing_at.g(c) == -1 and g.crit_at.g(c) == -1 and g.veh_at.g(c) == -1) else 0

func lift(vi: int) -> void:
	var v: Dictionary = g.vehicles[vi]
	for c in cells(v):
		if g.veh_at.g(c) == vi:
			g.veh_at.s(c, -1)
		_restore_walk(c)

func put(vi: int, anchor: int, dir: int) -> void:
	var v: Dictionary = g.vehicles[vi]
	lift(vi)
	v["cell"] = anchor
	v["dir"] = dir
	for c in cells(v):
		g.veh_at.s(c, vi)
		g.sim.walk[c] = 0
	if g.in_vehicle == vi:
		g.pc = anchor

# ---------------------------------------------------------------- making vehicles
func engine_def(id: String) -> Dictionary:
	return g.db.defs[id].get("engine", {}) if g.db.defs.has(id) else {}

func new_record(kind: String, anchor: int, dir: int, color: Color, engine_id: String = "") -> Dictionary:
	var t: Dictionary = KINDS[kind]
	var eid: String = engine_id if engine_id != "" else String(t["engine"])
	var parts: Dictionary = (t["parts"] as Dictionary).duplicate()
	var ed: Dictionary = engine_def(eid)
	if not ed.is_empty():
		parts["engine"] = int(ed["hp"])
	return {"kind": kind, "cell": anchor, "dir": dir, "spd": 0, "charge": 100, "parts": parts, "pmax": parts.duplicate(), "eng": {"id": eid, "hp": int(parts["engine"])},
			"color": color, "d8": true, "driver": -1, "ai": false, "dest": 0, "air": false, "stuck": 0, "wreck": false, "hp": int(parts["body"]), "turn_at": -1}

func spawn(kind: String, anchor: int, dir: int, color: Color, ai: bool = false, engine_id: String = "") -> int:
	var v := new_record(kind, anchor, dir, color, engine_id)
	g.vehicles.append(v)
	var vi: int = g.vehicles.size() - 1
	if not fits(vi, anchor, dir):
		g.vehicles.pop_back()
		return -1
	v["ai"] = ai
	v["driver"] = -3 if ai else -1
	if ai:
		v["charge"] = 100
	put(vi, anchor, dir)
	return vi

## a free spot for a vehicle: ring search outwards from `near` over anchors whose whole footprint stands on one of `tiles`
func find_spot(kind: String, near: int, minr: int, maxr: int, tiles: Array, dir: int = 0) -> int:
	var probe_v := new_record(kind, near, dir, Color.WHITE)
	g.vehicles.append(probe_v)
	var vi: int = g.vehicles.size() - 1
	var out := -1
	for r in range(minr, maxr):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var nx: int = near % g.size + dx
				var ny: int = (near % g.s2) / g.size + dy
				if not g.in_bounds(nx, ny):
					continue
				var a: int = (near / g.s2) * g.s2 + ny * g.size + nx
				if not (int(g.city.tiles[a]) in tiles):
					continue
				if not fits(vi, a, dir):
					continue
				var ok := true
				for c in cells_at(kind, a, dir):
					if not (int(g.city.tiles[c]) in tiles):
						ok = false
						break
				if ok:
					out = a
					break
			if out >= 0:
				break
		if out >= 0:
			break
	g.vehicles.pop_back()
	return out

# ---------------------------------------------------------------- engines and damage
func eng_def(v: Dictionary) -> Dictionary:
	return engine_def(String(v["eng"]["id"]))

func part_pct(v: Dictionary, part: String) -> int:
	var mx: int = maxi(1, int(v["pmax"].get(part, 1)))
	return clampi(int(100.0 * float(v["parts"].get(part, 0)) / float(mx)), 0, 100)

## top speed in tiles a turn: the engine's power, cut by a wounded engine or drive
func max_speed(v: Dictionary) -> int:
	var power: int = int(eng_def(v).get("power", 3))
	var f: float = minf(float(part_pct(v, "engine")), float(part_pct(v, "drive")) + 30.0) / 100.0
	if v["parts"]["engine"] <= 0 or v["parts"]["drive"] <= 0 or v["wreck"]:
		return 0
	return maxi(1, int(round(float(power) * clampf(f, 0.34, 1.0))))

func status_text(vi: int) -> String:
	var v: Dictionary = g.vehicles[vi]
	return "eng %d%%  body %d%%  %s %d%%  cabin %d%%" % [part_pct(v, "engine"), part_pct(v, "body"), KINDS[v["kind"]]["drive"], part_pct(v, "drive"), part_pct(v, "cabin")]

func body_hp(v: Dictionary) -> int:
	return int(v["parts"]["body"])

## damage one part.  Returns true if the vehicle was wrecked by it.
func damage(vi: int, part: String, amount: int, how: String = "") -> bool:
	var v: Dictionary = g.vehicles[vi]
	if v["wreck"] or amount <= 0:
		return false
	var before: int = v["parts"][part]
	v["parts"][part] = maxi(0, before - amount)
	v["hp"] = int(v["parts"]["body"])
	if part == "engine":
		v["eng"]["hp"] = v["parts"]["engine"]
	var name: String = KINDS[v["kind"]]["name"]
	var seen: bool = g.sees_cell(v["cell"]) or g.in_vehicle == vi
	if before > 0 and v["parts"][part] <= 0 and seen:
		match part:
			"engine": g.say("The %s's engine dies%s." % [name, (" (" + how + ")") if how != "" else ""])
			"drive": g.say("The %s's %s are wrecked." % [name, KINDS[v["kind"]]["drive"]])
			"cabin": g.say("The %s's cabin caves in." % name)
	if part == "cabin" and g.in_vehicle == vi:
		g._raw_hurt(maxi(1, amount / 4), "chest")
	if part == "drive" and before > 0 and v["parts"]["drive"] <= 0 and v.get("air", false) and v["kind"] != "plane":
		if seen:
			g.say("The rotor fails and the %s falls!" % name)
		_fall(vi)
	if part == "engine" and v["parts"]["engine"] <= 0:
		v["spd"] = 0
	if v["parts"]["body"] <= 0:
		_wreck(vi)
		return true
	return false

func damage_cell(vi: int, cell: int, amount: int, how: String = "") -> void:
	var v: Dictionary = g.vehicles[vi]
	var p: String = part_at(v, cell)
	if p == "":
		p = "body"
	# the body takes a share of whatever hits any panel
	damage(vi, p, amount, how)
	if p != "body" and not v["wreck"]:
		damage(vi, "body", amount / 3, how)

func _wreck(vi: int) -> void:
	var v: Dictionary = g.vehicles[vi]
	v["wreck"] = true
	v["spd"] = 0
	v["ai"] = false
	v["driver"] = -1
	v["color"] = (v["color"] as Color).darkened(0.65)
	var name: String = KINDS[v["kind"]]["name"]
	if g.sees_cell(v["cell"]) or g.in_vehicle == vi:
		g.say("The %s is wrecked." % name)
	var ctr: int = int(v["cell"])
	var was_air: bool = bool(v.get("air", false))
	if g.in_vehicle == vi:
		g.in_vehicle = -1
		g.say("You are thrown clear.")
		_exit_cell(vi)
		g._raw_hurt(3, "chest")
	if was_air:
		_fall(vi)
	if int(v["charge"]) >= 30 and g.rng.randf() < 0.35 and v["kind"] != "mech":
		v["charge"] = 0
		g.say_if_seen(ctr, "The battery ruptures and the %s burns." % name)
		g._explode(ctr, 3, 22)

func repair(vi: int, part: String, amount: int) -> void:
	var v: Dictionary = g.vehicles[vi]
	v["parts"][part] = mini(int(v["pmax"][part]), int(v["parts"][part]) + amount)
	if part == "engine":
		v["eng"]["hp"] = v["parts"]["engine"]
	if part == "body":
		v["hp"] = v["parts"]["body"]
		if v["wreck"] and v["parts"]["body"] > int(v["pmax"]["body"]) / 4:
			v["wreck"] = false
			v["color"] = (v["color"] as Color).lightened(0.5)

## swap the engine for an engine item you carry.  Returns the old engine as an Item (its wear kept in `cond`), or null if it will not fit.
func swap_engine(vi: int, new_item):
	var v: Dictionary = g.vehicles[vi]
	var nd: Dictionary = new_item.def.get("engine", {})
	if nd.is_empty() or not (v["kind"] in nd.get("fits", [])):
		return null
	var old = g._new_item(String(v["eng"]["id"]))
	old.cond = int(v["parts"]["engine"])
	var hp: int = int(new_item.cond) if int(new_item.cond) >= 0 else int(nd["hp"])
	v["eng"] = {"id": new_item.id(), "hp": hp}
	v["pmax"]["engine"] = int(nd["hp"])
	v["parts"]["engine"] = mini(hp, int(nd["hp"]))
	v["spd"] = 0
	return old

# ---------------------------------------------------------------- getting in and out
func near_vehicle() -> int:
	var px: int = g.pc % g.size
	var py: int = (g.pc % g.s2) / g.size
	var base: int = (g.pc / g.s2) * g.s2
	for r in [0, 1, 2]:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var nx: int = px + dx
				var ny: int = py + dy
				if g.in_bounds(nx, ny) and g.veh_at.g(base + ny * g.size + nx) != -1:
					return g.veh_at.g(base + ny * g.size + nx)
		if r == 1:
			break
	return -1

func _exit_cell(vi: int) -> void:
	var v: Dictionary = g.vehicles[vi]
	var fp := {}
	for c in cells(v):
		fp[c] = 1
	var best := -1
	var bd := 1 << 20
	var a: int = int(v["cell"])
	for c in fp:
		for d in g.SIZE_DIRS:
			var nx: int = c % g.size + d[0]
			var ny: int = (c % g.s2) / g.size + d[1]
			if not g.in_bounds(nx, ny):
				continue
			var nc: int = (c / g.s2) * g.s2 + ny * g.size + nx
			if fp.has(nc) or not g._free_for_player(nc) or g.z_of(nc) != g.z_of(c):
				continue
			var dd: int = maxi(absi(nx - a % g.size), absi(ny - (a % g.s2) / g.size))
			var left: Array = DIR8[(int(v["dir"]) + 6) % 8] if is_g8(String(v["kind"])) else rot(-1, 0, int(v["dir"]))
			var lx: int = left[0]
			var ly: int = left[1]
			var side: int = (nx - a % g.size) * lx + (ny - (a % g.s2) / g.size) * ly
			var score: int = dd * 4 - (3 if side > 0 else 0)
			if score < bd:
				bd = score
				best = nc
	if best >= 0:
		g.pc = best

func interact() -> bool:
	if g.flying:
		g.say("You cut the jets and drop.")
		g._fall_player("You let go.")
		g.end_turn()
		return true
	if g.in_vehicle >= 0:
		return leave()
	var vi := near_vehicle()
	if vi < 0:
		g.say("No vehicle within reach.")
		return false
	var v: Dictionary = g.vehicles[vi]
	var name: String = KINDS[v["kind"]]["name"]
	if v["wreck"]:
		g.say("The %s is a burnt-out wreck." % name)
		return false
	if v["driver"] == -3:
		g.say("You haul the driver out of the %s and take the wheel." % name)
		g._witness(v["cell"], 14, -1)
		v["ai"] = false
		v["driver"] = -1
	if v["charge"] <= 0 or v["parts"]["engine"] <= 0:
		g.say("The %s is dead.  [Shift+E] opens the engine bay." % name)
		return false
	g.in_vehicle = vi
	v["driver"] = -2
	g.pc = v["cell"]
	g.flying = false
	match v["kind"]:
		"heli": g.say("You strap into the helicopter.  [<] lifts off, arrows fly, [>] descends, [e] exits when landed.  Cells %d%%." % v["charge"])
		"mech": g.say("You climb into the mech.  It steps over cover, crushes crates, jumps (q) and takes the hits.  Cells %d%%." % v["charge"])
		"plane": g.say("You strap into the plane.  It needs speed to fly: arrows accelerate, [<] pulls up.  [e] exits when stopped.")
		_:
			g.say("You get into the %s.  Up speeds up, Down brakes then reverses, Left and Right turn it (relative to the way it faces), [space] stops, [e] exits.  Battery %d%%." % [name, v["charge"]])
			g.facing = fwd(String(v["kind"]), int(v["dir"]))
	g.end_turn()
	return true

func leave() -> bool:
	var vi: int = g.in_vehicle
	var v: Dictionary = g.vehicles[vi]
	var name: String = KINDS[v["kind"]]["name"]
	if v.get("air", false) and g.z_of(v["cell"]) > 0 and v["kind"] != "mech":
		g.say("You bail out of the %s!" % name)
		v["air"] = false
		v["driver"] = -1
		v["spd"] = 0
		g.in_vehicle = -1
		var lc: Array = g.land_cell(v["cell"])
		damage(vi, "body", 10 * int(lc[1]))
		_fall(vi)
		g._fall_player("The %s tumbles away." % name)
		g.end_turn()
		return true
	v["driver"] = -1
	v["spd"] = 0
	g.in_vehicle = -1
	g.say("You step out of the %s." % name)
	_exit_cell(vi)
	g.end_turn()
	return true

## an airborne vehicle with no pilot or no lift drops to the floor below
func _fall(vi: int) -> void:
	var v: Dictionary = g.vehicles[vi]
	var drop := 0
	var a: int = int(v["cell"])
	var cur: int = a
	while g.z_of(cur) > 0:
		var below: int = cur - g.s2
		if probe(vi, below, int(v["dir"]), true).is_empty() or _landable(vi, below, int(v["dir"])):
			cur = below
			drop += 1
			if _landable(vi, cur, int(v["dir"])):
				break
		else:
			break
	v["air"] = false
	if cur != a:
		var pr := probe(vi, cur, int(v["dir"]))
		if pr.is_empty():
			put(vi, cur, int(v["dir"]))
		else:
			put(vi, a, int(v["dir"]))
	damage(vi, "body", 12 * drop)
	damage(vi, "drive", 8 * drop)
	g._noise(v["cell"], 8 + drop)

func _landable(vi: int, anchor: int, dir: int) -> bool:
	return probe(vi, anchor, dir, false).is_empty()

# ---------------------------------------------------------------- driving on the ground
func heading_of(dx: int, dy: int) -> int:
	if dx != 0 and dy == 0:
		return 1 if dx > 0 else 3
	if dy != 0 and dx == 0:
		return 2 if dy > 0 else 0
	return -1

func _drain(v: Dictionary, per: float) -> void:
	var dr: int = maxi(1, int(eng_def(v).get("drain", 4)))
	if (g.turn * 7 + int(per * 3.0)) % dr == 0:
		v["charge"] = maxi(0, int(v["charge"]) - 1)

## one tile of travel for a ground vehicle (heading `dir`, stepping toward `step_dir`, both 0..7).  Returns false if it stopped.
func _step_ground(vi: int, dir: int, step_dir: int) -> bool:
	var v: Dictionary = g.vehicles[vi]
	var d: Array = DIR8[step_dir]
	var a: int = int(v["cell"]) + d[1] * g.size + d[0]
	var ax: int = int(v["cell"]) % g.size + d[0]
	var ay: int = (int(v["cell"]) % g.s2) / g.size + d[1]
	if not g.in_bounds(ax, ay):
		if g.zone_cross(d[0], d[1]):
			return false
		_crash(vi, {"t": "edge"})
		return false
	var spd: int = int(v["spd"])
	var pr := probe(vi, a, dir)
	if pr.is_empty():
		put(vi, a, dir)
		return true
	match String(pr["t"]):
		"person", "player":
			run_down(vi, String(pr["t"]), int(pr["idx"]), int(pr["cell"]))
			v["spd"] = maxi(1, spd - 2) if spd > 0 else 0
			damage(vi, "body", 4)
			return false
		"critter":
			g._kill_crit(int(pr["idx"]), "is run over")
			damage(vi, "body", 2)
			return true if probe(vi, a, dir).is_empty() and _put_ok(vi, a, dir) else false
		"thing":
			g.smash_thing(int(pr["idx"]), "is flattened")
			damage(vi, "body", 3 + absi(spd))
			if probe(vi, a, dir).is_empty():
				put(vi, a, dir)
				return true
			return false
		_:
			_crash(vi, pr)
			return false
	return false

## how fast a vehicle is going in km/h (a driven car's speed in tiles a turn; traffic runs at two)
func kph(v: Dictionary) -> int:
	return absi(int(v["spd"])) * KPH_PER_TILE

## a person struck by a car takes one point of damage for every km/h, split over the body: half to the legs (a quarter to each), the rest over chest 25%, arms 10% each and head 5%.
const HIT_SPLIT := [["l_leg", 25], ["r_leg", 25], ["chest", 25], ["l_arm", 10], ["r_arm", 10], ["head", 5]]

func hit_split(total: int) -> Dictionary:
	var out := {}
	var used := 0
	for k in HIT_SPLIT.size():
		var part: int = total * int(HIT_SPLIT[k][1]) / 100
		out[HIT_SPLIT[k][0]] = part
		used += part
	out["chest"] = int(out["chest"]) + (total - used)      # the rounding crumbs land on the chest
	return out

## the car at vi hits `who`: kind "person" (idx = the NPC) or "player"
func run_down(vi: int, kind: String, idx: int, cell: int) -> void:
	var v: Dictionary = g.vehicles[vi]
	var total: int = kph(v)
	var name: String = String(KINDS[v["kind"]]["name"])
	if total <= 0:
		return
	var parts: Dictionary = hit_split(total)
	if kind == "player":
		g.say("A %s hits you at %d km/h!  -%d: legs %d and %d, chest %d, arms %d and %d, head %d." % [name, total, total, parts["l_leg"], parts["r_leg"], parts["chest"], parts["l_arm"], parts["r_arm"], parts["head"]])
		g.sfx("hurt")
		for l in parts:
			if int(parts[l]) > 0:
				g._limb_hit(l, int(parts[l]))
		return
	g.say("You run down %s at %d km/h!  -%d: legs %d and %d, chest %d, arms %d and %d, head %d." % [g.name_of(idx), total, total, parts["l_leg"], parts["r_leg"], parts["chest"], parts["l_arm"], parts["r_arm"], parts["head"]]) if v["driver"] == -2 else g.say_if_seen(cell, "A %s hits %s at %d km/h!" % [name, g.name_of(idx), total])
	g.hpn[idx] -= total
	g._witness(cell, 14, idx)
	var dead := false
	for l in parts:
		if not dead and int(parts[l]) > 0:
			dead = g.npc_limb_hit(idx, l, int(parts[l]))
	if dead or g.hpn[idx] <= 0:
		if g.sim.alive[idx] == 1:
			g.kill(idx)
	else:
		g._alert(idx)

func _put_ok(vi: int, a: int, dir: int) -> bool:
	put(vi, a, dir)
	return true

func _crash(vi: int, pr: Dictionary) -> void:
	var v: Dictionary = g.vehicles[vi]
	var spd: int = int(v["spd"])
	if spd >= 2 or String(pr.get("t", "")) == "vehicle":
		var imp: int = 5 * spd * spd / 2 + 3
		var cell: int = int(pr.get("cell", v["cell"]))
		var name: String = KINDS[v["kind"]]["name"]
		g.say_if_seen(v["cell"], "The %s crashes!" % name)
		g.sfx("boom") if v["driver"] == -2 else null
		damage(vi, "body", imp)
		damage(vi, "engine", imp / 3, "the crash")
		if v["driver"] == -2:
			g._raw_hurt(maxi(1, spd - 1), "chest")
		if String(pr.get("t", "")) == "vehicle" and int(pr["idx"]) >= 0:
			var other: int = int(pr["idx"])
			damage_cell(other, cell, imp, "rammed")
		g._noise(v["cell"], 6 + spd)
	v["spd"] = 0

## turn the whole body to a new heading: a quarter turn between two cardinal headings goes about its centre (so a lane keeps it), a 45 degree turn about the driver's seat
func _rotate_pose(vi: int, new_dir: int) -> bool:
	var v: Dictionary = g.vehicles[vi]
	var kind: String = v["kind"]
	var old: int = int(v["dir"])
	if is_g8(kind) and (old % 2 == 1 or new_dir % 2 == 1):
		if probe(vi, int(v["cell"]), new_dir).is_empty():
			put(vi, int(v["cell"]), new_dir)
			return true
		return false
	var ctr: Vector2i = center2(kind, int(v["cell"]), old)
	var a: int = anchor_for(kind, new_dir, ctr.x, ctr.y, int(v["cell"]))
	if probe(vi, a, new_dir).is_empty():
		put(vi, a, new_dir)
		return true
	return false

## the speed from which steering scrubs speed (tiles a turn)
const SCRUB_SPEED := 4

## Tank controls for cars and trucks: Up speeds up, Down brakes and then reverses, Left and Right turn the vehicle 45 degrees to its own left or right (not the screen's).
## The diagonals do both at once.  Standing still a turn pivots on the spot; at speed the vehicle keeps moving as it turns, so the faster it goes the wider the arc.
func drive(dx: int, dy: int) -> bool:
	var vi: int = g.in_vehicle
	var v: Dictionary = g.vehicles[vi]
	if dx == 0 and dy == 0:
		v["spd"] = 0
		g.end_turn()
		return true
	if int(v["charge"]) <= 0:
		g.say("The battery is dead.")
		return false
	var top := max_speed(v)
	if top <= 0:
		g.say("It will not move: %s." % status_text(vi))
		return false
	var throttle: int = -dy
	var steer: int = dx
	var kind: String = v["kind"]
	var dir: int = int(v["dir"])
	var spd: int = int(v["spd"])
	if throttle > 0:
		if spd < 0:
			spd = mini(0, spd + 2)
		else:
			spd = mini(maxi(spd + 1, 1), top)
	elif throttle < 0:
		if spd > 0:
			spd = maxi(0, spd - 2)
			if spd == 0:
				g.say("You brake to a halt.")
		else:
			spd = -1                                    # reverse
	if steer != 0:
		if spd >= SCRUB_SPEED:
			spd -= 1
			g.say("You scrub speed in the turn.")
		var nd: int = (dir + steer + 8) % 8
		if _rotate_pose(vi, nd):
			dir = nd
		else:
			g.say("No room to turn here.")
	v["spd"] = spd
	var steps: int = absi(spd)
	for s in steps:
		var sd: int = dir if spd > 0 else (dir + 4) % 8
		if not _step_ground(vi, dir, sd):
			break
	g.facing = fwd(kind, int(v["dir"]))
	dir = int(v["dir"])
	if int(v["parts"]["drive"]) * 2 < int(v["pmax"]["drive"]) and spd != 0 and g.rng.randf() < 0.3:
		var side: int = (dir + (2 if g.rng.randf() < 0.5 else 6)) % 8
		var sd2: Array = DIR8[side]
		var a: int = int(v["cell"]) + sd2[1] * g.size + sd2[0]
		if probe(vi, a, dir).is_empty():
			put(vi, a, dir)
			g.say("The damaged %s pulls to one side." % KINDS[v["kind"]]["drive"])
	if steps > 0 and g.rng.randf() < 0.5:
		g.sfx("engine")
	_drain(v, float(steps))
	g.step_noise = 3 + steps
	g.end_turn()
	return true

# ---------------------------------------------------------------- flying
func _level_ok(anchor: int) -> bool:
	return g.z_of(anchor) >= 0

func vertical(dir: int) -> bool:
	var vi: int = g.in_vehicle
	var v: Dictionary = g.vehicles[vi]
	if v["kind"] == "mech" or v["kind"] == "car" or v["kind"] == "truck":
		return false
	if int(v["charge"]) <= 0 or v["parts"]["engine"] <= 0:
		g.say("The engine is dead.")
		return false
	var a: int = int(v["cell"])
	var d: int = int(v["dir"])
	if v["kind"] == "plane":
		return plane_pitch(dir)
	if dir > 0:
		var up: int = a + g.s2
		if g.z_of(a) < 0 or g.z_of(a) >= g.city.zmax or not probe(vi, up, d, true).is_empty():
			g.say("Blocked overhead." if g.z_of(a) < g.city.zmax else "You can't climb higher.")
			return false
		if not v.get("air", false):
			g.say("The rotors spin up and the helicopter lifts.")
			v["air"] = true
		put(vi, up, d)
		v["spd"] = 0
		g.sim.retier(g.pc)
		g.end_turn()
		return true
	if not v.get("air", false):
		return false
	var dn: int = a - g.s2
	if g.z_of(dn) < 0:
		return false
	var pr_land := probe(vi, dn, d, false)
	if pr_land.is_empty():
		put(vi, dn, d)
		v["air"] = false
		v["spd"] = 0
		g.say("The helicopter settles onto %s." % g.zname(g.pc))
		g.sim.retier(g.pc)
		g.end_turn()
		return true
	if g.z_of(dn) > 0 and probe(vi, dn, d, true).is_empty():
		put(vi, dn, d)
		v["spd"] = 0
		g.sim.retier(g.pc)
		g.end_turn()
		return true
	g.say("There is no safe place to set down: %s." % String(pr_land.get("t", "solid")))
	return false

func fly(dx: int, dy: int) -> bool:
	var vi: int = g.in_vehicle
	var v: Dictionary = g.vehicles[vi]
	if v["kind"] == "plane":
		return plane_steer(dx, dy)
	if dx == 0 and dy == 0:
		v["spd"] = 0
		g.end_turn()
		return true
	if not v.get("air", false):
		g.say("Lift off first: [<] climbs.")
		return false
	if int(v["charge"]) <= 0 or v["parts"]["engine"] <= 0:
		_down_hard(vi, "The engine cuts out.")
		return true
	var top: int = max_speed(v)
	var spd: int = 1 if int(v["spd"]) == 0 else mini(int(v["spd"]) + 1, maxi(1, top))
	v["spd"] = spd
	var want: int = heading_of(dx, 0) if dx != 0 else heading_of(0, dy)
	var dir: int = int(v["dir"])
	for s in spd:
		var a: int = int(v["cell"]) + dy * g.size + dx
		var nx: int = int(v["cell"]) % g.size + dx
		var ny: int = (int(v["cell"]) % g.s2) / g.size + dy
		if not g.in_bounds(nx, ny):
			if g.zone_cross(dx, dy):
				return true
			v["spd"] = 0
			break
		var pr := probe(vi, a, want, true)
		if pr.is_empty():
			put(vi, a, want)
			dir = want
		else:
			pr = probe(vi, a, dir, true)
			if pr.is_empty():
				put(vi, a, dir)
			else:
				if spd >= 2:
					g.say("The helicopter clips something solid!")
					damage(vi, "body", 5 * spd)
					damage(vi, "drive", 6 * spd)
					g._raw_hurt(1, "chest")
				v["spd"] = 0
				break
	if g.turn % 2 == 0:
		v["charge"] = maxi(0, int(v["charge"]) - 1)
	if v["wreck"]:
		g.end_turn()
		return true
	if int(v["parts"]["drive"]) <= 0:
		_down_hard(vi, "The rotor tears itself apart!")
		return true
	g.end_turn()
	return true

func _down_hard(vi: int, reason: String) -> void:
	var v: Dictionary = g.vehicles[vi]
	g.say("%s" % reason)
	var before: int = g.z_of(v["cell"])
	_fall(vi)
	if g.in_vehicle == vi:
		g.pc = v["cell"]
		var dmg: int = g.fall_damage(before) / 2 + (g.rng.randi_range(0, 3) if before > 0 else 0)
		if dmg > 0:
			g.player_hurt(dmg, "The crash jars you")
	g.sim.retier(g.pc)
	g.end_turn()

# ---------------------------------------------------------------- planes: they need speed and a clear run
func plane_steer(dx: int, dy: int) -> bool:
	var vi: int = g.in_vehicle
	var v: Dictionary = g.vehicles[vi]
	if int(v["charge"]) <= 0 or v["parts"]["engine"] <= 0:
		g.say("The engine is dead.")
		return false
	var want := heading_of(dx, dy)
	if dx == 0 and dy == 0:
		v["spd"] = maxi(0, int(v["spd"]) - 2)
		if v.get("air", false) and int(v["spd"]) < 2:
			_down_hard(vi, "The plane stalls!")
			return true
		g.end_turn()
		return true
	if want < 0:
		g.say("A plane turns in four directions.")
		return false
	var dir: int = int(v["dir"])
	var spd: int = int(v["spd"])
	if want == dir:
		spd = mini(spd + 1, 6)
	elif want == (dir + 2) % 4:
		spd = maxi(0, spd - 2)
	else:
		if spd >= 3 and v.get("air", false) or spd == 0 or not v.get("air", false):
			if _rotate_pose(vi, want):
				dir = want
				g.say("You bank the plane." if v.get("air", false) else "You swing the plane round.")
			else:
				g.say("No room to turn.")
	v["spd"] = spd
	if v.get("air", false) and spd < 2:
		_down_hard(vi, "The plane stalls!")
		return true
	for s in spd:
		var d: Array = DIR4[dir]
		var a: int = int(v["cell"]) + d[1] * g.size + d[0]
		var nx: int = int(v["cell"]) % g.size + d[0]
		var ny: int = (int(v["cell"]) % g.s2) / g.size + d[1]
		if not g.in_bounds(nx, ny):
			if g.zone_cross(d[0], d[1]):
				return true
			v["spd"] = 0
			break
		var pr := probe(vi, a, dir, v.get("air", false))
		if pr.is_empty():
			put(vi, a, dir)
		else:
			if String(pr["t"]) == "person":
				g.hpn[int(pr["idx"])] -= 30
				g.kill(int(pr["idx"])) if g.hpn[int(pr["idx"])] <= 0 else null
			else:
				_crash(vi, pr)
				damage(vi, "body", 20)
			v["spd"] = 0
			break
	if g.turn % 2 == 0:
		v["charge"] = maxi(0, int(v["charge"]) - 1)
	g.step_noise = 9
	g.end_turn()
	return true

func plane_pitch(dir: int) -> bool:
	var vi: int = g.in_vehicle
	var v: Dictionary = g.vehicles[vi]
	var a: int = int(v["cell"])
	var d: int = int(v["dir"])
	if dir > 0:
		if int(v["spd"]) < 4:
			g.say("Not enough speed to climb (%d; need 4)." % v["spd"])
			return false
		var up: int = a + g.s2
		if g.z_of(a) >= g.city.zmax or not probe(vi, up, d, true).is_empty():
			g.say("Blocked overhead.")
			return false
		v["air"] = true
		put(vi, up, d)
		g.sim.retier(g.pc)
		g.end_turn()
		return true
	if not v.get("air", false):
		return false
	var dn: int = a - g.s2
	if probe(vi, dn, d, true).is_empty():
		put(vi, dn, d)
		g.sim.retier(g.pc)
		g.end_turn()
		return true
	if probe(vi, dn, d, false).is_empty():
		put(vi, dn, d)
		v["air"] = false
		g.say("The plane touches down.")
		g.sim.retier(g.pc)
		g.end_turn()
		return true
	g.say("Nowhere to land.")
	return false

# ---------------------------------------------------------------- the mech
func mech_move(dx: int, dy: int, run: bool) -> bool:
	var vi: int = g.in_vehicle
	var v: Dictionary = g.vehicles[vi]
	if int(v["charge"]) <= 0 or v["parts"]["engine"] <= 0:
		g.say("The mech is dead.  [e] to climb out.")
		return false
	if v["parts"]["drive"] <= 0:
		g.say("The legs are gone.")
		return false
	g.facing = Vector2i(dx, dy)
	var dir: int = heading_of(dx, 0) if dx != 0 else heading_of(0, dy)
	if dx != 0 and dy != 0:
		dir = heading_of(dx, 0)
	var steps := 2 if run else 1
	var moved_any := false
	for s in steps:
		var nx: int = int(v["cell"]) % g.size + dx
		var ny: int = (int(v["cell"]) % g.s2) / g.size + dy
		if not g.in_bounds(nx, ny):
			if g.zone_cross(dx, dy):
				return true
			break
		var a: int = int(v["cell"]) + dy * g.size + dx
		# every obstacle on the new footprint: people are slammed, things crushed, animals pushed
		var pr := probe(vi, a, dir)
		var guard := 0
		while not pr.is_empty() and guard < 40:
			guard += 1
			var t: String = String(pr["t"])
			if t == "person":
				var who: int = int(pr["idx"])
				var dmg: int = g.rng.randi_range(14, 22)
				g.say("The mech slams %s." % g.name_of(who))
				g._witness(pr["cell"], 12, who)
				g._silent = false
				g.hpn[who] -= dmg
				if g.hpn[who] <= 0:
					g.kill(who)
				else:
					g._alert(who)
					g._knock_back(who)
				moved_any = true
				pr = {"t": "stop"}
				break
			elif t == "thing":
				g.smash_thing(int(pr["idx"]), "is crushed underfoot")
			elif t == "critter":
				g.push_crit(int(pr["idx"]), dx, dy)
				if g.crit_at.g(int(pr["cell"])) != -1:
					g._kill_crit(g.crit_at.g(int(pr["cell"])), "is crushed")
			elif t == "solid":
				var c: int = int(pr["cell"])
				var tt: int = g.city.tiles[c]
				if tt == CG.LOCKED:
					g.city.tiles[c] = CG.DOOR
					g.sim.tiles[c] = CG.DOOR
					g.say("The mech bursts the door.")
					g._noise(c, 12)
				elif tt in CG.LOW_COVER and tt != CG.RAILING:
					var flat: int = CG.GROUND if g.z_of(c) == 0 else CG.FLOOR
					g.city.tiles[c] = flat
					g.sim.tiles[c] = flat
				else:
					break
			else:
				break
			pr = probe(vi, a, dir)
		if pr.is_empty():
			put(vi, a, dir)
			moved_any = true
		else:
			break
	if not moved_any:
		return false
	g.step_noise = 10
	g.ran_this_turn = run
	g.sfx("step")
	if g.turn % 4 == 0:
		v["charge"] = maxi(0, int(v["charge"]) - 1)
	g.end_turn()
	return true

func mech_jump(dx: int, dy: int, run_up: bool) -> bool:
	var vi: int = g.in_vehicle
	var v: Dictionary = g.vehicles[vi]
	if v["parts"]["drive"] <= 0:
		g.say("The legs are gone.")
		return false
	var dir: int = heading_of(dx, 0) if dx != 0 else heading_of(0, dy)
	var maxd: int = 5 + (1 if run_up else 0)
	for dist in range(maxd, 1, -1):
		var nx: int = int(v["cell"]) % g.size + dx * dist
		var ny: int = (int(v["cell"]) % g.s2) / g.size + dy * dist
		if not g.in_bounds(nx, ny):
			continue
		var a: int = int(v["cell"]) + dy * dist * g.size + dx * dist
		if probe(vi, a, dir).is_empty():
			put(vi, a, dir)
			g.say("The mech leaps %d tiles." % dist)
			g._noise(g.pc, 12)
			g.facing = Vector2i(dx, dy)
			g.end_turn()
			return true
	g.say("There is nowhere to land that way.")
	return false

# ---------------------------------------------------------------- NPC pilots: cars follow the lanes of the street grid
func ai_turn() -> void:
	for vi in g.vehicles.size():
		var v: Dictionary = g.vehicles[vi]
		if not v["ai"] or v["driver"] != -3 or v["wreck"]:
			continue
		if g.cheb(v["cell"], g.pc) > 80 or g.z_of(v["cell"]) != g.z_of(g.pc):
			continue
		match String(v["kind"]):
			"car", "truck":
				_ai_car(vi)
			_:
				pass

## the lane centres of a road whose left edge is `e` (doubled coordinates): the low lane and the high lane
static func lane_lo2(e: int) -> int:
	return 2 * e + 6

static func lane_hi2(e: int) -> int:
	return 2 * e + 18

## lane k (0 = the lowest) of a road of width w, in doubled coordinates: lanes are six tiles, the low half runs one way and the high half the other
static func lane_k2(e: int, k: int) -> int:
	return 2 * e + 6 + 12 * k

## the lane a car turns right from / left from on a road (left edge e, width w) it crosses: the kerb lane on its right, the median lane on its left
static func turn_lanes(e: int, w: int, hi_first: bool) -> Vector2i:
	var outer_hi: int = 2 * (e + w) - 6
	var inner_hi: int = 2 * (e + w / 2) + 6
	var outer_lo: int = 2 * e + 6
	var inner_lo: int = 2 * (e + w / 2) - 6
	return Vector2i(outer_hi, inner_lo) if hi_first else Vector2i(outer_lo, inner_hi)

func _ai_car(vi: int) -> void:
	var v: Dictionary = g.vehicles[vi]
	if int(v["dir"]) % 2 == 1:
		v["dir"] = (int(v["dir"]) + 1) % 8                  # traffic only drives the four straight headings
	var q: int = int(v["dir"]) / 2                         # the quarter-turn heading (0 N, 1 E, 2 S, 3 W)
	# a person (or you) in the lane ahead within four tiles makes traffic slow to one tile a turn; it never speeds up at anyone, and it only gets a chance to hit
	# someone who is in its way while it is still moving (below)
	var came_in_at: int = int(v["spd"])
	var moving: bool = came_in_at > 0
	var warned := false
	var qd: Array = DIR4[q]
	for k in range(1, 5):
		var pk := probe(vi, int(v["cell"]) + qd[1] * g.size * k + qd[0] * k, q * 2)
		if not pk.is_empty() and (String(pk["t"]) == "person" or String(pk["t"]) == "player"):
			warned = true
			break
	var cruise: int = 1 if (warned or not moving) else 2
	v["spd"] = cruise
	var travelled := 0
	for s in cruise:
		var dir: int = q * 2
		var d: Array = DIR4[q]
		var a: int = int(v["cell"]) + d[1] * g.size + d[0]
		# decide a turn when the body's centre reaches the centre of a cross lane
		var ctr := center2(v["kind"], int(v["cell"]), dir)
		var fwd2: int = ctr.y if q % 2 == 0 else ctr.x
		var key: int = fwd2 * 4 + q
		if int(v["turn_at"]) != key:
			var cross: Array = g.city.ys if q % 2 == 0 else g.city.xs
			var turn := 0
			for e in cross:
				# traffic keeps to the right: the first cross lane met is the one a right turn joins
				var hi_first: bool = q == 0 or q == 3
				var tl := turn_lanes(int(e), g.city.line_w(int(e), q % 2 == 0), hi_first)
				var right_c: int = tl.x
				var left_c: int = tl.y
				if (fwd2 == right_c or (fwd2 - right_c) % 2 != 0 and fwd2 == right_c + 1) and g.rng.randf() < 0.28:
					turn = 1
					break
				if (fwd2 == left_c or (fwd2 - left_c) % 2 != 0 and fwd2 == left_c + 1) and g.rng.randf() < 0.2:
					turn = 3
					break
			if turn != 0:
				v["turn_at"] = key
				var nq: int = (q + turn) % 4
				if _rotate_pose(vi, nq * 2):
					q = nq
					v["stuck"] = 0
					continue
		var pr := probe(vi, a, dir)
		var road_ok := pr.is_empty()
		if road_ok:
			for c in cells_at(v["kind"], a, dir):
				if g.city.tiles[c] != CG.ROAD:
					road_ok = false
					break
		if road_ok:
			put(vi, a, dir)
			v["stuck"] = 0
			travelled += 1
		elif not pr.is_empty() and (String(pr["t"]) == "person" or String(pr["t"]) == "player") and moving:
			# somebody is in the way and the car was moving: it brakes, but may not stop in time (more likely the faster it was going)
			moving = false
			if g.rng.randf() < (0.4 if came_in_at >= 2 else 0.12):
				v["spd"] = came_in_at                  # it hits at the speed it came in at
				run_down(vi, String(pr["t"]), int(pr["idx"]), int(pr["cell"]))
				damage(vi, "body", 2)
			v["spd"] = 0
			v["stuck"] = int(v["stuck"]) + 1
			break
		elif pr.is_empty() and _ai_slide(vi, dir, a):
			v["stuck"] = 0                              # the road bends here (a riverside boulevard): followed one column sideways
			continue
		else:
			v["stuck"] = int(v["stuck"]) + 1
			var t: String = String(pr.get("t", "road_end"))
			if (t == "solid" or t == "edge" or t == "road_end") and int(v["stuck"]) >= 2:
				_ai_uturn(vi)
			elif int(v["stuck"]) > 30:
				_ai_uturn(vi)
				v["stuck"] = 0
			break
	if travelled == 0 and int(v["spd"]) > 0:
		v["spd"] = 0                                   # it did not get anywhere this turn (waiting, or turning round)
	if g.cheb(v["cell"], g.pc) < 30 and g.rng.randf() < 0.05:
		g._noise_gentle(v["cell"], 5)

## the way ahead is open but for the edge of the road: step forward and one column across to whichever side is still road (a bend of a curved street)
func _ai_slide(vi: int, dir: int, ahead: int) -> bool:
	var v: Dictionary = g.vehicles[vi]
	var q: int = dir / 2
	for sh in [1, -1] if g.rng.randf() < 0.5 else [-1, 1]:
		var a2: int = ahead + (sh if q % 2 == 0 else sh * g.size)
		if (a2 % g.size) - (ahead % g.size) != (sh if q % 2 == 0 else 0):
			continue                                      # the step wrapped round the edge of the map
		if not probe(vi, a2, dir).is_empty():
			continue
		var ok := true
		for c in cells_at(v["kind"], a2, dir):
			if g.city.tiles[c] != CG.ROAD:
				ok = false
				break
		if ok:
			put(vi, a2, dir)
			return true
	return false

func _ai_uturn(vi: int) -> void:
	var v: Dictionary = g.vehicles[vi]
	var q: int = int(v["dir"]) / 2
	var dir: int = q * 2
	var nd: int = (q + 2) % 4 * 2
	var ctr := center2(v["kind"], int(v["cell"]), dir)
	var lat2: int = ctr.x if q % 2 == 0 else ctr.y
	var lines: Array = g.city.xs if q % 2 == 0 else g.city.ys
	var mirrored := lat2
	for e in lines:
		var lw: int = g.city.line_w(int(e), q % 2 != 0)
		if lat2 >= 2 * int(e) and lat2 <= 2 * int(e) + 2 * lw:
			mirrored = 2 * (2 * int(e) + lw) - lat2
			break
	if mirrored == lat2 and q % 2 == 0 and not g.city.plan.is_empty():
		# on a riverside boulevard: its left edge at this row, twelve wide
		var row: int = clampi(ctr.y / 2, 0, g.size - 1)
		for key in ["blv_w", "blv_e"]:
			var bx: int = (g.city.plan[key] as PackedInt32Array)[row]
			if bx >= 0 and lat2 >= 2 * bx and lat2 <= 2 * (bx + g.city.rw):
				mirrored = 2 * (2 * bx + g.city.rw) - lat2
				break
	var nx2: int = mirrored if q % 2 == 0 else ctr.x
	var ny2: int = ctr.y if q % 2 == 0 else mirrored
	var a: int = anchor_for(v["kind"], nd, nx2, ny2, int(v["cell"]))
	if probe(vi, a, nd).is_empty():
		put(vi, a, nd)
		v["stuck"] = 0
		v["turn_at"] = -1

# ---------------------------------------------------------------- saving
## take a vehicle out of this zone (to carry it to the next): returns its saved record
func export_vehicle(vi: int) -> Dictionary:
	var d: Dictionary = to_dict(g.vehicles[vi])
	for k in g.vehicles.size():
		lift(k)
	g.vehicles.remove_at(vi)
	g.veh_at.clear()
	for k in g.vehicles.size():
		for c in cells(g.vehicles[k]):
			g.veh_at.s(c, k)
			g.sim.walk[c] = 0
	if g.in_vehicle == vi:
		g.in_vehicle = -1
	elif g.in_vehicle > vi:
		g.in_vehicle -= 1
	return d

## put an exported vehicle down with its seat at `anchor`; returns its index or -1
func import_vehicle(d: Dictionary, anchor: int) -> int:
	var o: Dictionary = from_dict(d)
	o["cell"] = anchor
	g.vehicles.append(o)
	var vi: int = g.vehicles.size() - 1
	for c in cells(o):
		if c < 0 or c >= g.veh_at.n:
			g.vehicles.pop_back()
			return -1
	for c in cells(o):
		g.veh_at.s(c, vi)
		g.sim.walk[c] = 0
	return vi

func to_dict(v: Dictionary) -> Dictionary:
	var o: Dictionary = v.duplicate(true)
	o["color"] = (v["color"] as Color).to_html()
	return o

func from_dict(d: Dictionary) -> Dictionary:
	var o: Dictionary = d.duplicate(true)
	o["color"] = Color(d["color"])
	for k in ["cell", "dir", "spd", "charge", "hp", "dest", "driver", "stuck", "turn_at"]:
		o[k] = int(o.get(k, 0))
	if is_g8(String(o.get("kind", ""))) and not bool(o.get("d8", false)):
		o["dir"] = int(o["dir"]) * 2                      # saved before ground vehicles had eight headings
		o["turn_at"] = -1
	o["d8"] = true
	for k in ["parts", "pmax"]:
		var pd: Dictionary = o[k]
		for p in pd:
			pd[p] = int(pd[p])
	o["eng"]["hp"] = int(o["eng"]["hp"])
	o["ai"] = bool(o.get("ai", false))
	o["air"] = bool(o.get("air", false))
	o["wreck"] = bool(o.get("wreck", false))
	return o
