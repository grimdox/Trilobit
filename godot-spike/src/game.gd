extends RefCounted
## The playable slice: one city, one player, roughly two thousand people, awareness-driven hostiles, theft, shooting, pockets and cars.
## All rules live here and run headless; main.gd and view.gd only draw it and feed it keys.
const CG = preload("res://src/citygen.gd")
const ISL = preload("res://src/island.gd")
const SIM = preload("res://src/npc_sim.gd")
const FF = preload("res://src/flowfield.gd")
const ItemScript = preload("res://src/item.gd")
const DB = preload("res://src/item_db.gd")
const FOV = preload("res://src/fov.gd")
const LV = preload("res://src/levels.gd")
const TR = preload("res://src/transit.gd")
const EC = preload("res://src/economy.gd")
const GP = preload("res://src/gunplay.gd")
const VS = preload("res://src/vehicles.gd")
const IMP = preload("res://src/implants.gd")
const BODY = preload("res://src/body.gd")
const SK = preload("res://src/skills.gd")

const UNAWARE := 0
const CRAWL := 0
const CROUCH := 1
const WALKING := 2
const RUNNING := 3
const STAMINA_MAX := 30
const DIR8 := [[0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1]]   # in a ring, so a turn is +-1
const FUEL_MAX := 24
const SUSPICIOUS := 1
const SEARCHING := 2
const HUNTING := 3
const RETURNING := 4
const FLEEING := 5
const SURRENDERED := 6
const CIV := 0
const BRATVA := 1
const NAP := 2
const NASIM := 3
const GANG := 4            # unaffiliated criminals (the harbor's north end)
const FAC_NAMES := ["resident", "Bratva thug", "NAP officer", "Nasim runner", "unaffiliated criminal"]
const FIRST := ["Hanako", "Ryo", "Mika", "Daichi", "Yuna", "Kenji", "Aiko", "Sora", "Natsu", "Taro", "Rin", "Haru", "Emi", "Jiro", "Saki", "Koji", "Ayumi", "Shin", "Noa", "Leo", "Mei", "Ivan", "Dasha", "Pavel", "Lena", "Misha", "Zhenya", "Tamsin"]
const SIZE_DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]
const DIR4 := [[0, -1], [1, 0], [0, 1], [-1, 0]]

var seed_value: int
var rng := RandomNumberGenerator.new()
var city
var sim
var db
var fov
var size: int
var s2: int = 0                      # cells per level
var rows: int = 0                    # rows of the stacked map
var total: int = 0                   # cells in all levels
var transit
var eco
var turn: int = 0
var game_over: bool = false
var log: Array = []
var sfx_queue: Array = []             # sound events for the front end ("shot", "step", ...); drained after each key

# the player
var pc: int = 0                      # cell index
var hp: int = 60
var hp_max: int = 60
var yen: int = 300
var heat: int = 0
var ammo_pool: Dictionary = {"9mm|fmj": 36}   # "caliber|kind" -> rounds carried loose
var want_kind: Dictionary = {}                 # caliber -> kind the next reload loads
var aim_turns: int = 0
var aim_target: int = -1
var moved: bool = false
var last_pc: int = -1
var tracers: Array = []                        # [from_cell, to_cell, hit] for the view; cleared on the next key
var crouch: bool = false                       # derived from stance: true when crouching or crawling
var stance: int = 2                            # CRAWL, CROUCH, WALKING, RUNNING
var stamina: int = 30
var ran_this_turn: bool = false
var run_dir := Vector2i(0, 0)
var run_streak: int = 0
var implants := {}                             # "legs": leg actuators, "jets": dorsal jump jets
var fuel: int = 24
var flying: bool = false
var followers: Array = []                      # hunters climbing after you
var step_noise: int = 0                        # how far this turn's footsteps carry
var attrs: Dictionary = SK.default_attrs()      # Strength, Perception, Agility, Cognition, Endurance (start at 10)
var skills: Dictionary = SK.default_skills()    # BASE levels, raised by skill XP (see skills.gd for the effective level)
var xp: Dictionary = SK.default_skills()        # skill-specific XP towards the next base level
var worn: Array = []
var wield = null
var in_vehicle: int = -1
var vs                                 # the vehicle system (vehicles.gd)
var facing := Vector2i(0, 1)

# the world
var items_at: Dictionary = {}        # cell -> Array of Item
var vehicles: Array = []
var veh_at: PackedInt32Array
var waypoints: PackedInt32Array
var way_fields: Array = []
var road_walk: PackedByteArray
var gun_ids: Dictionary = {}         # class tag -> Array of gun ids

# per-person data (parallel to sim arrays)
var hpn: PackedInt32Array
var hpmax: PackedInt32Array
var fac: PackedByteArray
var astate: PackedByteArray
var meter: PackedInt32Array
var timer: PackedInt32Array
var lastpos: PackedInt32Array
var postc: PackedInt32Array
var yenn: PackedInt32Array
var gunc: PackedByteArray            # 0 unarmed, 1 pistol, 2 SMG, 3 rifle
var cool: PackedByteArray
var stun: PackedByteArray             # turns a person is stunned, tangled or tripped
var bleed: PackedByteArray            # turns left bleeding (1 hp each)
var mdis: PackedByteArray             # 1 = their melee weapon has been knocked away
var melee_pool: Dictionary = {}       # faction -> melee weapon ids they carry
var melee_all: Array = []
var prev_wield = null
var things: Array = []                # loose props: {k, cell, hp, loot}
var thing_at: PackedInt32Array
var critters: Array = []              # dogs and cats: {k, cell, hp, mood, stun}
var crit_at: PackedInt32Array
var fly_units: Dictionary = {}        # agent -> {"fly": true, ...}: per-unit movement traits (none spawn yet)
var face: PackedByteArray              # which way each person looks: index into DIR8
var prevpos: PackedInt32Array
var _silent: bool = false
var fem: PackedByteArray
var nname: PackedStringArray
var noticed_you: PackedByteArray     # 1 once this person has been aware of you (for theft consequences)

# the player's flow field for hunters (4-neighbour BFS, local)
var pf: PackedInt32Array
var pf_touched: PackedInt32Array = PackedInt32Array()

func _init(seed: int = 1) -> void:
	seed_value = seed

func sfx(name: String) -> void:
	if sfx_queue.size() < 12:
		sfx_queue.append(name)

func say(msg: String) -> void:
	log.append(msg)
	if log.size() > 200:
		log = log.slice(100)

func setup(n_people: int = 1200, isl = null, zn: Vector2i = Vector2i(-1, -1)) -> void:
	rng.seed = seed_value
	db = DB.new()
	db.load_file("res://data/items.json")
	for k in db.defs:
		var d: Dictionary = db.defs[k]
		if "gun" in d.get("tags", []):
			for t in d["tags"]:
				if t != "gun":
					if not gun_ids.has(t):
						gun_ids[t] = []
					gun_ids[t].append(k)
	_melee_pools()
	if isl != null:
		island = isl
		zone = zn
		city = island.build_zone(zn.x, zn.y)
		if zn == island.CITY_ZONE:
			LV.build(city, island.seed_value)
			if zone == island.CITY_ZONE:
				island.rail_portal(city)
		else:
			LV.flat(city, seed_value)
	else:
		island = null
		zone = Vector2i(-1, -1)
		city = CG.new()
		city.generate(seed_value, Vector2(1, 0.2))
		LV.build(city, seed_value)
	size = city.size
	s2 = size * size
	total = city.tiles.size()
	rows = total / size
	sim = SIM.new()
	sim.perception_standin = false
	sim.setup(city, n_people, seed_value ^ 0x5eed)
	sim.tick = 7 * 60 - 20
	last_ate = sim.tick
	last_drank = sim.tick
	fov = FOV.new()
	fov.setup(size, sim.opaque)
	pf = PackedInt32Array(); pf.resize(total); pf.fill(FF.UNREACHED)
	veh_at = PackedInt32Array(); veh_at.resize(total); veh_at.fill(-1)
	things = []
	critters = []
	thing_at = PackedInt32Array(); thing_at.resize(total); thing_at.fill(-1)
	crit_at = PackedInt32Array(); crit_at.resize(total); crit_at.fill(-1)
	_people()
	if island != null and zone == Vector2i(0, 1):
		_port_people()
	_roads_and_cars()
	_loot()
	_vault_loot()
	_start_player()
	transit = TR.new()
	transit.setup(self)
	eco = EC.new()
	eco.setup(self)
	_compute_fov()
	if island == null or zone == island.CITY_ZONE:
		say("You step out onto the street.  Morning in the city.  [?] for keys.")

func _people() -> void:
	var n: int = sim.n
	hpn = PackedInt32Array(); hpn.resize(n)
	hpmax = PackedInt32Array(); hpmax.resize(n)
	fac = PackedByteArray(); fac.resize(n)
	astate = PackedByteArray(); astate.resize(n)
	meter = PackedInt32Array(); meter.resize(n)
	timer = PackedInt32Array(); timer.resize(n)
	lastpos = PackedInt32Array(); lastpos.resize(n)
	postc = PackedInt32Array(); postc.resize(n)
	yenn = PackedInt32Array(); yenn.resize(n)
	gunc = PackedByteArray(); gunc.resize(n)
	cool = PackedByteArray(); cool.resize(n)
	stun = PackedByteArray(); stun.resize(n)
	bleed = PackedByteArray(); bleed.resize(n)
	mdis = PackedByteArray(); mdis.resize(n)
	face = PackedByteArray(); face.resize(n)
	prevpos = PackedInt32Array(); prevpos.resize(n)
	for i in n:
		face[i] = (i * 5 + 3) & 7
	fem = PackedByteArray(); fem.resize(n)
	noticed_you = PackedByteArray(); noticed_you.resize(n)
	nname = PackedStringArray(); nname.resize(n)
	for i in n:
		var r := rng.randf()
		var f := CIV
		if r < 0.045:
			f = BRATVA
		elif r < 0.085:
			f = NAP
		elif r < 0.105:
			f = NASIM
		fac[i] = f
		hpmax[i] = [25, 40, 45, 30, 35][f]
		hpn[i] = hpmax[i]
		yenn[i] = rng.randi_range(5, 90) if f == CIV else rng.randi_range(40, 260)
		if f == CIV:
			yenn[i] = int(yenn[i] * [0.5, 1.0, 2.4][city.wealth_at(int(sim.home_cell[i]))])
		fem[i] = 1 if rng.randf() < 0.5 else 0
		nname[i] = FIRST[rng.randi() % FIRST.size()]
		if f == BRATVA:
			gunc[i] = 1 if rng.randf() < 0.45 else 0
		elif f == NAP:
			gunc[i] = 1 if rng.randf() < 0.8 else 2
		elif f == NASIM:
			gunc[i] = 1 if rng.randf() < 0.2 else 0

## the harbor's people: dock workers in the middle (they commute between their dorms and the quay and yard), unaffiliated criminals
## loitering about the warehouses in the north, the Bratva about the dormitories in the south
func _port_people() -> void:
	var o: Vector2i = island.zone_origin(zone.x, zone.y)
	var rx: int = int(island.west_x(island.PORT.y)) + 6 - o.x
	for i in sim.n:
		var roll: int = i % 20
		var band := 0
		if roll >= 11 and roll < 16:
			band = -1
		elif roll >= 16:
			band = 1
		var f := CIV
		if band == -1:
			f = GANG if rng.randf() < 0.75 else BRATVA
		elif band == 1:
			f = BRATVA if rng.randf() < 0.7 else GANG
		fac[i] = f
		hpmax[i] = [25, 40, 45, 30, 35][f]
		hpn[i] = hpmax[i]
		if f == CIV:
			yenn[i] = rng.randi_range(5, 60)
			gunc[i] = 0
			for _t in 30:                                   # on the job: at one of the quay and yard work spots
				var wc: int = city.works[rng.randi() % city.works.size()]
				if sim.walk[wc] == 1 and sim.at[wc] == -1 and city.tiles[wc] != CG.FLOOR:
					sim.place(i, wc)
					break
			continue
		yenn[i] = rng.randi_range(40, 260)
		gunc[i] = 1 if rng.randf() < 0.4 else 0
		var lo: int = island.PORT.y - 118 if band == -1 else island.PORT.y + 58
		var hi: int = island.PORT.y - 58 if band == -1 else island.PORT.y + 108
		for _t in 80:
			var cx: int = rx - 20 + rng.randi_range(0, 150)
			var cy: int = rng.randi_range(lo, hi) - o.y
			if cx < 0 or cx >= size or cy < 0 or cy >= size:
				continue
			var c: int = cy * size + cx
			var tt: int = city.tiles[c]
			if (tt == CG.GROUND or tt == CG.PARK or tt == CG.PLATFORM or tt == CG.FLOOR) and sim.walk[c] == 1 and sim.at[c] == -1:
				sim.place(i, c)
				sim.sticky[i] = 1
				break

func _roads_and_cars() -> void:
	road_walk = PackedByteArray(); road_walk.resize(size * size)
	var road_cells := PackedInt32Array()
	for i in size * size:
		if city.tiles[i] == CG.ROAD:
			road_walk[i] = 1
			road_cells.append(i)
	_spawn_vehicles()
	_spawn_things()
	_spawn_critters()

func _car_colors() -> Array:
	return [Color("#d94f70"), Color("#3fb6c9"), Color("#e8c03a"), Color("#8f8fa8"), Color("#4fd98a"), Color("#e8e8ee"), Color("#2a3140")]

## cars in the lanes of the street grid (they drive), parked cars in the yards, and the special vehicles near the start
func _spawn_vehicles() -> void:
	vs = VS.new(self)
	if island != null and zone != island.CITY_ZONE:
		_spawn_zone_vehicles()
		return
	var cols: Array = _car_colors()
	var placed := 0
	var tries := 0
	while placed < 46 and tries < 600:
		tries += 1
		var vertical: bool = rng.randf() < 0.5
		var lines: Array = city.xs if vertical else city.ys
		var e: int = lines[rng.randi() % lines.size()]
		var hi_lane: bool = rng.randf() < 0.5
		var along: int = rng.randi_range(city.grid_margin + 10, size - city.grid_margin - 10)
		var nl: int = city.line_w(e, not vertical) / city.LANE        # lanes across this road (2 for a street, 4 for an avenue, 6 for the highway)
		var lane_k: int = (nl / 2 if hi_lane else 0)
		if nl > 2:
			lane_k += rng.randi() % (nl / 2)                 # any lane of the carriageway
		var dir: int
		var cx2: int
		var cy2: int
		if vertical:
			dir = 0 if hi_lane else 2                      # northbound in the east lane, southbound in the west lane
			cx2 = VS.lane_k2(e, lane_k)
			cy2 = along * 2
		else:
			dir = 1 if hi_lane else 3                      # eastbound in the south lane, westbound in the north lane
			cy2 = VS.lane_k2(e, lane_k)
			cx2 = along * 2
		var kind := "car" if rng.randf() < 0.88 else "truck"
		var a: int = vs.anchor_for(kind, dir, cx2, cy2, 0)
		var vi: int = vs.spawn(kind, a, dir, cols[rng.randi() % cols.size()], true)
		if vi >= 0:
			var ok := true
			for c in vs.cells(vehicles[vi]):
				if city.tiles[c] != CG.ROAD:
					ok = false
			if not ok:
				vs.lift(vi)
				vehicles.pop_back()
				continue
			vehicles[vi]["charge"] = rng.randi_range(40, 100)
			placed += 1
	# parked cars: any free 4x6 patch of pavement, along the streets
	var parked := 0
	tries = 0
	while parked < 26 and tries < 400:
		tries += 1
		var c: int = rng.randi_range(0, s2 - 1)
		if city.tiles[c] != CG.GROUND:
			continue
		var dir2: int = rng.randi() % 4
		var vi2: int = vs.spawn("car", c, dir2, cols[rng.randi() % cols.size()], false)
		if vi2 >= 0:
			var ok2 := true
			for cc in vs.cells(vehicles[vi2]):
				if city.tiles[cc] != CG.GROUND:
					ok2 = false
			if not ok2:
				vs.lift(vi2)
				vehicles.pop_back()
				continue
			vehicles[vi2]["charge"] = rng.randi_range(30, 100)
			parked += 1
	_spawn_special_vehicles()

var special_dir := 0

## trucks driving up and down the harbor's quay road all day, hauling goods between the cranes and the yard
func _spawn_dock_trucks(cols: Array) -> void:
	var o: Vector2i = island.zone_origin(zone.x, zone.y)
	var e: int = int(island.west_x(island.PORT.y)) + 6 - o.x
	var py: int = island.PORT.y - o.y
	var placed := 0
	var tries := 0
	while placed < 7 and tries < 200:
		tries += 1
		var hi_lane: bool = placed % 2 == 0
		var dir: int = 0 if hi_lane else 2
		var cx2: int = VS.lane_hi2(e) if hi_lane else VS.lane_lo2(e)
		var cy2: int = (py + rng.randi_range(-46, 46)) * 2
		var kind := "truck" if rng.randf() < 0.75 else "car"
		var a: int = vs.anchor_for(kind, dir, cx2, cy2, 0)
		var vi: int = vs.spawn(kind, a, dir, cols[rng.randi() % cols.size()], true)
		if vi < 0:
			continue
		var ok := true
		for c in vs.cells(vehicles[vi]):
			if city.tiles[c] != CG.ROAD:
				ok = false
		if not ok:
			vs.lift(vi)
			vehicles.pop_back()
			continue
		vehicles[vi]["charge"] = 100
		placed += 1

## park something at the first free spot of the right ground near a local position
func _place(kind: String, near_x: int, near_y: int, minr: int, maxr: int, tiles: Array, dir: int, color: Color) -> void:
	var cell: int = vs.find_spot(kind, clampi(near_y, 0, size - 1) * size + clampi(near_x, 0, size - 1), minr, maxr, tiles, dir)
	special_dir = dir
	_add_special(kind, cell, color)

## the vehicles of the wild zones: trucks and a mech on the quay, cars in the town, a plane on the strip
func _spawn_zone_vehicles() -> void:
	var cols: Array = _car_colors()
	var o: Vector2i = island.zone_origin(zone.x, zone.y)
	if zone == Vector2i(0, 1):
		var qx: int = int(island.west_x(island.PORT.y)) + 6 - o.x
		var py: int = island.PORT.y - o.y
		for k in 2:
			_place("truck", qx + 30, py - 40 + k * 60, 0, 60, [CG.PLATFORM, CG.PARK, CG.SAND], 0, cols[rng.randi() % cols.size()])
		_spawn_dock_trucks(cols)
		_place("mech", qx + 4, py - 20, 0, 60, [CG.PLATFORM, CG.PARK, CG.SAND], 1, Color("#c0583a"))
		for k in 2:
			_place("car", qx + 24, py + 40 + k * 10, 0, 80, [CG.PLATFORM, CG.PARK], 1, cols[rng.randi() % cols.size()])
	elif zone == Vector2i(2, 1):
		var cx: int = island.TOWN.x - o.x
		var cy: int = island.TOWN.y - o.y
		for k in 5:
			_place("car", cx + rng.randi_range(-60, 60), cy + rng.randi_range(-50, 60), 0, 60, [CG.GROUND], rng.randi() % 2, cols[rng.randi() % cols.size()])
		_place("heli", cx + 40, cy - 100, 0, 100, [CG.GROUND, CG.PARK], 0, Color("#7fd6e8"))
	elif zone == Vector2i(3, 1):
		var x0: int = 1480 - o.x
		var y0: int = island.AIR_Y - o.y
		_place("plane", x0 + 20, y0 + 8, 0, 6, [CG.GROUND, CG.ROAD], 1, Color("#e8e8ee"))
		_place("car", x0 + 24, y0 + 23, 0, 12, [CG.GROUND], 0, cols[rng.randi() % cols.size()])
var island = null                      # the Island (shared by every zone) or null for a stand-alone city
var zone := Vector2i(-1, -1)
var world = null                       # the World that owns this zone game (zone changes go through it)

func _add_special(kind: String, cell: int, color: Color) -> void:
	if cell < 0:
		return
	var vi: int = vs.spawn(kind, cell, special_dir, color, false)
	if vi >= 0:
		vehicles[vi]["charge"] = 100

## a helicopter and a mech within sight of the start, more helicopters on the two tallest roofs, more mechs around the centre
func _spawn_special_vehicles() -> void:
	var centre: int = (size / 2) * size + size / 2
	var start: int = centre
	for i in size * size:
		if city.tiles[i] == CG.ROAD and veh_at[i] == -1 and sim.at[i] == -1:
			var d := maxi(absi(i % size - size / 2), absi(i / size - size / 2))
			if d < 3:
				start = i
				break
	special_dir = 0
	var hs: int = vs.find_spot("heli", start, 8, 60, [CG.GROUND, CG.PARK, CG.ROAD], 0)
	_add_special("heli", hs, Color("#7fd6e8"))
	_add_special("mech", vs.find_spot("mech", start, 10, 160, [CG.GROUND, CG.PARK], 0), Color("#c0583a"))
	var towers: Array = city.tower_info.duplicate()
	towers.sort_custom(func(a, b): return int(a["h"]) > int(b["h"]))
	for k in mini(2, towers.size()):
		var t: Dictionary = towers[k]
		var roof: int = city.lvl_of_z(int(t["h"])) * s2 + ((int(t["y0"]) + int(t["y1"])) / 2) * size + (int(t["x0"]) + int(t["x1"])) / 2
		special_dir = 0
		_add_special("heli", vs.find_spot("heli", roof, 0, 14, [CG.ROOF], 0), Color("#7fd6e8"))
	for k in 2:
		var c2: int = rng.randi_range(size / 4, size * 3 / 4) * size + rng.randi_range(size / 4, size * 3 / 4)
		special_dir = 0
		_add_special("mech", vs.find_spot("mech", c2, 1, 160, [CG.GROUND, CG.PARK], 0), Color("#c0583a"))

func _weighted(table: Array) -> String:
	var total := 0
	for e in table:
		total += int(e[1])
	var r := rng.randi() % total
	for e in table:
		r -= int(e[1])
		if r < 0:
			return e[0]
	return table[0][0]

func _new_item(id: String, n: int = 1):
	var it = ItemScript.new(db.defs[id], n)
	if it.def.has("gun"):
		_load_full(it)
	return it

func _load_full(it) -> void:
	var gs: Dictionary = GP.stats(it)
	it.loaded = int(gs["mag"])
	it.kind = GP.default_kind(it.def["gun"]["cal"])

func _part_load(it) -> void:
	var gs: Dictionary = GP.stats(it)
	it.loaded = rng.randi_range(0, int(gs["mag"]))
	if it.loaded == 0:
		it.kind = ""

func _random_mod() -> String:
	var ids: Array = []
	for k in db.defs:
		if "mod" in db.defs[k].get("tags", []):
			ids.append(k)
	ids.sort()
	return ids[rng.randi() % ids.size()]

func _random_ammo() -> String:
	var ids: Array = []
	for k in db.defs:
		if "ammo" in db.defs[k].get("tags", []) and k != "trl_ammo":
			ids.append(k)
	ids.sort()
	return ids[rng.randi() % ids.size()]

func _random_gun() -> String:
	var tags := ["smg", "pistol", "revolver", "rifle", "shotgun", "sniper", "mg", "laser"]
	var t: String = tags[rng.randi() % tags.size()]
	var arr: Array = gun_ids[t]
	return arr[rng.randi() % arr.size()]

func _loot() -> void:
	var markers: Array = []
	markers.append_array(Array(city.homes))
	markers.append_array(Array(city.works))
	markers.append_array(Array(city.shops))
	for c in markers:
		if rng.randf() > 0.4:
			continue
		# no loose food, water or weapons: those are bought, in the shops and restaurants (and taken from people who carry them)
		var kind := _weighted([["trl_yen", 50], ["ammo", 16], ["mod", 3], ["trl_backpack", 3], ["trl_coat", 2], ["trl_pouch", 3], ["trl_duffel", 1], ["armor", 8], ["trl_medkit", 4]])
		var it
		match kind:
			"trl_yen": it = _new_item("trl_yen", rng.randi_range(20, 220))
			"ammo": it = _new_item(_random_ammo() if rng.randf() < 0.6 else "trl_ammo", rng.randi_range(1, 3))
			"mod": it = _new_item(_random_mod())
			"melee": it = _new_item(_random_melee())
			"armor": it = _new_item(["trl_helmet", "trl_vest", "trl_bracers", "trl_greaves", "trl_visor", "trl_vest_heavy", "trl_balaclava", "trl_jacket", "trl_kneepads"][rng.randi() % 9])
			"water":
				it = _new_item("trl_water_bottle")
				it.pockets[0].append(_new_item("trl_water", 450))
			"gun":
				it = _new_item(_random_gun())
				_part_load(it)
			_: it = _new_item(kind)
		_put(c, it)

func _vault_loot() -> void:
	for cells in city.vaults:
		var arr: PackedInt32Array = cells
		if arr.is_empty():
			continue
		_put(arr[rng.randi() % arr.size()], _new_item("trl_yen", rng.randi_range(500, 1400)))
		_put(arr[rng.randi() % arr.size()], _new_item(_random_ammo(), rng.randi_range(2, 4)))
		_put(arr[rng.randi() % arr.size()], _new_item(["trl_helm_tac", "trl_vest_corp", "trl_bracers_heavy", "trl_greaves_heavy"][rng.randi() % 4]))
		_put(arr[rng.randi() % arr.size()], _new_item(_random_mod()))
		if rng.randf() < 0.5:
			_put(arr[rng.randi() % arr.size()], _new_item(_random_mod()))
		if rng.randf() < 0.5:
			_put(arr[rng.randi() % arr.size()], _new_item("trl_backpack"))

func _put(cell: int, it) -> void:
	if z_of(cell) > 0 and city.tiles[cell] == CG.AIR:
		cell = land_cell(cell)[0]          # dropped over open air: it falls
	if not items_at.has(cell):
		items_at[cell] = []
	items_at[cell].append(it)

func _start_player() -> void:
	var centre: int = (size / 2) * size + size / 2
	var best := -1
	var bd := 1 << 30
	for i in size * size:
		if city.tiles[i] == CG.ROAD and veh_at[i] == -1:
			var d := maxi(absi(i % size - size / 2), absi(i / size - size / 2))
			if d < bd and sim.at[i] == -1:
				bd = d
				best = i
	pc = best
	var coat = _new_item("trl_coat")
	var pack = _new_item("trl_backpack")
	worn = [coat, pack]
	pack.insert(_new_item("trl_ration", 2))
	var bottle = _new_item("trl_water_bottle")
	bottle.pockets[0].append(_new_item("trl_water", 500))
	coat.insert_deep(bottle)
	coat.insert_deep(_new_item("trl_credstick"))
	wield = _new_item("trl_gun_zp9")
	_load_full(wield)

# ---------------------------------------------------------------- helpers
func cheb(a: int, b: int) -> int:
	return maxi(absi(a % size - b % size), absi(a / size - b / size))

## which level the player (or any cell) is on: 0 ground, 1.. above, negative below
func z_of(c: int) -> int:
	return city.z_of(c)

func lx(c: int) -> int:
	return c % size

func ly(c: int) -> int:
	return (c / size) % size

func zname(c: int) -> String:
	var z := z_of(c)
	var dist := ""
	if z >= 0 and zone == island_city_zone():
		dist = " (%s district)" % CG.DISTRICTS[city.wealth_at(c)]
	if z > 0:
		return "Floor %d%s" % [z, dist]
	match z:
		0: return "Street level" + dist
		-1: return "Subway & tunnels"
		_: return "Sewers"

func island_city_zone() -> Vector2i:
	return island.CITY_ZONE if island != null else Vector2i(-1, -1)

## the tower whose footprint contains the cell's x,y (any level), or {}
func tower_at(c: int) -> Dictionary:
	var x := lx(c)
	var y := ly(c)
	for t in city.tower_info:
		if x >= t["x0"] and x <= t["x1"] and y >= t["y0"] and y <= t["y1"]:
			return t
	return {}

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < rows

func hostile(i: int) -> bool:
	match fac[i]:
		BRATVA, GANG: return true
		NAP: return heat >= 30
		_: return false

func name_of(i: int) -> String:
	if eco != null and eco.role[i] != 0:
		return "%s (%s)" % [nname[i], eco.label(i)]
	return "%s the %s" % [nname[i], FAC_NAMES[fac[i]]]

func time_text() -> String:
	var m: int = sim.tick % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]

func sees_cell(c: int) -> bool:
	return fov.visible[c] == 1

## the effective level of one of your skills: base level plus the bonus from its governing attributes
func lvl(id: String) -> int:
	return SK.level(attrs, skills, id)

## an NPC's effective skill (attributes and skills come from faction and person index; see skills.gd)
func npc_lvl(i: int, id: String) -> int:
	return SK.npc_level(fac[i], seed_value, i, id)

func npc_attr_set(i: int) -> Dictionary:
	return SK.npc_attrs(fac[i], seed_value, i)

func discipline(id: String) -> bool:
	for s in SK.SKILLS:
		for d in s["disc"]:
			if d["id"] == id:
				return lvl(s["id"]) >= int(d["req"])
	return false

func skill_up(skill: String, difficulty: int) -> void:
	# gain comes from risk, not repetition: easy successes (difficulty below your level) teach nothing
	if not skills.has(skill) or skills[skill] >= SK.BASE_MAX:
		return
	if difficulty < skills[skill] - 1:
		return
	xp[skill] += 1 + maxi(0, difficulty - skills[skill])
	if xp[skill] >= SK.xp_needed(skills[skill]):
		xp[skill] = 0
		skills[skill] += 1
		say("Your %s skill rises to %d (level %d with attributes)." % [SK.skill(skill)["name"], skills[skill], lvl(skill)])

## which skill a strike uses: weapons use Melee; fists, kicks and implanted blades use Unarmed
func melee_skill_id() -> String:
	if body.arms_ok() > 0 and wield != null and wield.def.has("melee") and can_use_weapon(wield, false):
		return "melee"
	return "unarmed"

var _crit_n: int = 0
var crits: bool = true                         # tests that need exact damage switch critical hits off
## a critical hit is decided by the defender's Grit and rolled without touching the game's random stream (so it is the same on every replay of a seed)
func crit_roll(grit_lvl: int, a: int, b: int) -> bool:
	_crit_n += 1
	if not crits:
		return false
	return hash([seed_value, turn, a, b, _crit_n]) % 100 < SK.crit_chance(grit_lvl)

## damage a person takes from the player: their Grit cuts it (never below 1), and a crit adds half again
func npc_take(i: int, dmg: int) -> int:
	var g_l: int = npc_lvl(i, "grit")
	dmg = maxi(1, dmg - SK.grit_cut(g_l))
	if crit_roll(g_l, pc, i):
		dmg = dmg * 3 / 2
		say("Critical hit on %s!" % name_of(i))
	return dmg

# ---------------------------------------------------------------- inventory
func stow(it) -> bool:
	for c in worn:
		if c.insert_deep(it):
			return true
	return false

func inventory_list() -> Array:
	var out: Array = []
	if wield != null:
		out.append({"item": wield, "depth": 0, "where": "wielded", "parent": null})
	for a in armor_worn:
		out.append({"item": a, "depth": 0, "where": "worn armor", "parent": null})
	for c in worn:
		_walk_items(c, 0, "worn", null, out)
	return out

func _walk_items(it, depth: int, where: String, parent, out: Array) -> void:
	out.append({"item": it, "depth": depth, "where": where, "parent": parent})
	for p in it.pockets:
		for sub in p:
			_walk_items(sub, depth + 1, "in " + it.def["name"], it, out)

func item_label(it) -> String:
	var s: String = it.def["name"]
	if it.count > 1:
		s += " x%d" % it.count
	if it.def.has("melee"):
		s += " (%d-%d)" % [it.def["melee"]["dmg"][0], it.def["melee"]["dmg"][1]]
	if it.def.has("gun"):
		var gs: Dictionary = GP.stats(it)
		s += " (%d/%d%s)" % [it.loaded, gs["mag"], (" +%d mods" % it.mods.size()) if not it.mods.is_empty() else ""]
	if it.def.has("armor"):
		var left: int = item_armor_left(it)
		var mxd: int = int(it.def["armor"]["dur"])
		s += " [armor %d, %s]" % [int(it.def["armor"]["phys"]), "BROKEN" if left <= 0 else ("%d%%" % (100 * left / mxd))]
	return s

func total_weight_kg() -> float:
	var g := 0
	for c in worn:
		g += c.weight()
	if wield != null:
		g += wield.weight()
	return g / 1000.0

func act_pickup() -> bool:
	if in_vehicle >= 0 or not items_at.has(pc):
		say("Nothing here to pick up.")
		return false
	var left: Array = []
	var took := 0
	for it in items_at[pc]:
		if it.has_tag("money"):
			yen += it.count
			say("You take ¥%d." % it.count)
			took += 1
		elif it.has_tag("ammo"):
			var am: Dictionary = it.def["ammo"]
			var n: int = it.count * int(am["rounds"])
			pool_add(am["cal"], am["kind"], n)
			say("You take %d rounds of %s %s." % [n, am["cal"], GP.KIND[am["kind"]]["label"]])
			took += 1
		elif stow(it):
			say("You stow the %s." % item_label(it))
			took += 1
		elif wield == null and (it.has_tag("gun") or it.has_tag("melee")):
			wield = it
			say("You pick up the %s." % item_label(it))
			took += 1
		else:
			left.append(it)
			say("No room for the %s." % item_label(it))
	if left.is_empty():
		items_at.erase(pc)
	else:
		items_at[pc] = left
	if took > 0:
		sfx("pick")
		end_turn()
	return took > 0

func act_wield(it) -> bool:
	if it.def.has("armor") and not it.has_tag("container"):
		return act_wear(it)
	if it.has_tag("medical"):
		return act_use_medical(it)
	if it.has_tag("food"):
		return act_eat(it)
	if it.has_tag("charm"):
		return act_use_charm(it)
	if not (it.has_tag("gun") or it.has_tag("melee")):
		say("You can't wield that as a weapon.")
		return false
	var holder = null
	for c in worn:
		if c == it or c.contains_item(it):
			c.remove(it)
			holder = c
	var old = wield
	if wield != null:
		if not stow(wield):
			_put(pc, wield)
			say("You drop the %s." % item_label(wield))
			old = null
	prev_wield = old
	wield = it
	say("You wield the %s." % item_label(it))
	end_turn()
	return true

func act_drop_wield() -> void:
	if wield != null:
		_put(pc, wield)
		say("You drop the %s." % item_label(wield))
		wield = null
		end_turn()

# ---------------------------------------------------------------- acting
## broken legs: every step on foot costs extra time (one leg: double, none: triple), and no running
func act_move(dx: int, dy: int, run: bool = false) -> bool:
	var on_foot: bool = in_vehicle < 0 and transit.riding < 0 and not flying
	var legs: int = body.legs_ok()
	if on_foot and legs < 2:
		run = false
	var before := pc
	var ok: bool = _act_move_core(dx, dy, run)
	if ok and on_foot and legs < 2 and pc != before and not game_over:
		for _k in (1 if legs == 1 else 2):
			end_turn()
	if ok and on_foot and pc != before and not game_over:
		var sm: float = speed_mult()
		if sm < 1.0:
			move_debt += 1.0 / sm - 1.0
			while move_debt >= 1.0 and not game_over:
				move_debt -= 1.0
				end_turn()
		else:
			move_debt = 0.0
	return ok

func _act_move_core(dx: int, dy: int, run: bool = false) -> bool:
	if game_over:
		return false
	if in_vehicle >= 0:
		match veh_kind(in_vehicle):
			"heli", "plane": return vs.fly(dx, dy)
			"mech": return vs.mech_move(dx, dy, run)
		return vs.drive(dx, dy)
	if transit.riding >= 0:
		return transit.ride_move(dx, dy)
	if flying:
		return fly_move(dx, dy)
	var nx: int = pc % size + dx
	var ny: int = pc / size + dy
	if not in_bounds(nx, ny):
		return false
	if facing != Vector2i(dx, dy):
		facing = Vector2i(dx, dy)
		_compute_fov()
	var c := ny * size + nx
	var who: int = sim.at[c]
	if who >= 0:
		var mst: Dictionary = melee_stats()
		melee(who)
		_spend_ap(mst)
		return true
	if thing_at[c] != -1:
		return _bump_thing(c, dx, dy)
	if crit_at[c] != -1:
		return _bump_crit(c, dx, dy)
	var rt: int = _reach_target(dx, dy)
	if rt >= 0 and sim.at[c] == -1:
		return act_strike(dx, dy)
	if veh_at[c] != -1:
		say("A %s blocks the way.  [e] to get in." % vs.KINDS[vehicles[veh_at[c]]["kind"]]["name"])
		return false
	if city.tiles[c] == CG.LOCKED:
		return _pick_lock(c)
	if city.tiles[c] == CG.AIR:
		say("Open air.  [q] to leap across, or fly with jump jets.")
		return false
	if sim.walk[c] == 0:
		return false
	if transit.occupied(c):
		if transit.try_board(c):
			end_turn()
			return true
		return false
	pc = c
	var ran := false
	if run and stamina >= 2 and stance >= WALKING:
		ran = true
		stamina -= 2
		var c2: int = c + dy * size + dx
		var nx2: int = nx + dx
		var ny2: int = ny + dy
		if in_bounds(nx2, ny2) and z_of(c2) == z_of(c) and sim.walk[c2] == 1 and sim.at[c2] == -1 and veh_at[c2] == -1 and not items_at.has(c) \
				and city.tiles[c2] != CG.LOCKED and city.tiles[c2] != CG.TRACK:
			pc = c2
			stamina -= 2
	elif run and stamina < 2:
		say("You are winded.")
	ran_this_turn = ran
	if ran:
		run_streak = run_streak + 1 if run_dir == Vector2i(dx, dy) else 1
		run_dir = Vector2i(dx, dy)
		if stance == WALKING:
			stance = RUNNING
	else:
		run_streak = 0
		if stance == RUNNING:
			stance = WALKING
	step_noise = [0, 1, 4, 9][stance]
	if stance >= WALKING:
		sfx("step")
	if items_at.has(pc):
		var names := []
		for it in items_at[pc]:
			names.append(item_label(it))
		say("You see here: " + ", ".join(names) + ".")
	end_turn()
	if stance == CRAWL and not game_over:
		end_turn()                       # crawling is half speed
	return true

## --- hunger and thirst (placeholder mechanics: two status effects that slow you down, to be built on later)
func hungry() -> bool:
	return sim.tick - last_ate >= HUNGER_AFTER

func thirsty() -> bool:
	return sim.tick - last_drank >= THIRST_AFTER

func speed_mult() -> float:
	return (NEED_SLOW if hungry() else 1.0) * (NEED_SLOW if thirsty() else 1.0)

## minutes until the next need bites: [until hungry, until thirsty] (0 when already)
func need_timers() -> Array:
	return [maxi(0, HUNGER_AFTER - (sim.tick - last_ate)), maxi(0, THIRST_AFTER - (sim.tick - last_drank))]

func status_effects() -> Array:
	var out: Array = []
	if hungry():
		out.append("Hungry")
	if thirsty():
		out.append("Thirsty")
	return out

func _needs_tick() -> void:
	var h: bool = hungry()
	var t: bool = thirsty()
	if h and not _was_hungry:
		say("Your stomach growls.  You are hungry: -20% movement speed.")
	if t and not _was_thirsty:
		say("Your mouth is dry.  You are thirsty: -20% movement speed.")
	if _was_hungry and not h:
		say("You are no longer hungry.")
	if _was_thirsty and not t:
		say("You are no longer thirsty.")
	_was_hungry = h
	_was_thirsty = t

func act_wait() -> void:
	end_turn()

## the lock on a door: theft skill against the floor's security
func _pick_lock(c: int) -> bool:
	var z := absi(z_of(c))
	var chance := clampi(28 + lvl("engineering") * 9 - z * 2, 10, 90)
	if rng.randi() % 100 < chance:
		city.tiles[c] = CG.DOOR
		sim.tiles[c] = CG.DOOR
		say("You work the lock open.")
		skill_up("engineering", 3 + z / 6)
		_noise(c, 5)
	else:
		say("The lock holds.  You fumble with it.")
		_noise(c, 8)
		_witness(c, 9, 6, -1)
	end_turn()
	return true

func act_pay(amount: int) -> bool:
	return eco.pay(amount)

## the nearest person within reach who is not trying to kill you
func talk_target() -> int:
	var best := -1
	var bd := 3
	for k in sim.near_list.size():
		var i: int = sim.near_list[k]
		if sim.alive[i] == 0 or astate[i] == HUNTING or astate[i] == FLEEING:
			continue
		var d := cheb(sim.pos[i], pc)
		if d < bd:
			bd = d
			best = i
	return best

func _set_stance(s: int) -> void:
	stance = s
	crouch = s <= CROUCH
	aim_turns = 0

func act_crouch() -> void:
	if stance == CROUCH:
		_set_stance(WALKING)
		say("You stand.")
	else:
		_set_stance(CROUCH)
		say("You crouch low.")

func act_crawl() -> void:
	if stance == CRAWL:
		_set_stance(CROUCH)
		say("You come up onto your knees.")
	else:
		_set_stance(CRAWL)
		say("You drop flat.  Slow, but hard to see or hear.")

func stance_name() -> String:
	return ["crawling", "crouching", "walking", "running"][stance]

## the farthest anything hears your steps this turn if you move: by stance
func footstep_radius() -> int:
	return [0, 1, 4, 9][stance]

## a jump over low obstacles, railings, gaps: two cells, three after a running start; leg actuators make it four and five, a mech six.
## If no walkable landing exists but the far side is open air, you leap into the void and fall.
func act_jump(dx: int, dy: int) -> bool:
	if in_vehicle < 0 and body.legs_ok() == 0:
		say("You can't jump without legs.")
		return false
	if transit.riding >= 0 or (in_vehicle >= 0 and not in_mech()) or flying:
		say("Not from here.")
		return false
	if stance == CRAWL:
		say("You can't jump from the floor.")
		return false
	var cost: int = 2 if has_implant("legs") else 4
	if in_mech():
		cost = 0
	if stamina < cost:
		say("You are too winded to jump.")
		return false
	if dx == 0 and dy == 0:
		return false
	if in_mech():
		return vs.mech_jump(dx, dy, run_streak >= 1 and run_dir == Vector2i(dx, dy))
	var run_up: bool = run_streak >= 1 and run_dir == Vector2i(dx, dy)
	var base_d := 2
	if has_implant("legs"):
		base_d = 4
	if in_mech():
		base_d = 5
	var maxd: int = base_d + (1 if run_up else 0)
	var void_cell := -1
	var landed := false
	for dist in range(maxd, 1, -1):
		var nx: int = pc % size + dx * dist
		var ny: int = pc / size + dy * dist
		if not in_bounds(nx, ny):
			continue
		var land: int = ny * size + nx
		if z_of(land) != z_of(pc):
			continue
		var clear := true
		for k in range(1, dist):
			var mid: int = (pc / size + dy * k) * size + pc % size + dx * k
			var mt: int = city.tiles[mid]
			if mt == CG.WALL or mt == CG.EARTH or mt == CG.LOCKED or sim.at[mid] != -1:
				clear = false
		if not clear:
			continue
		if sim.walk[land] == 1 and sim.at[land] == -1 and veh_at[land] == -1 and city.tiles[land] != CG.LOCKED:
			pc = land
			landed = true
			break
		if void_cell < 0 and city.tiles[land] == CG.AIR and z_of(land) > 0:
			void_cell = land
	if not landed and void_cell >= 0:
		pc = void_cell
		landed = true
		say("You leap into the void!")
		if has_implant("jets") and fuel >= 4:
			flying = true
			say("Your jets catch you.")
	if not landed:
		say("There is nowhere to land that way.")
		return false
	facing = Vector2i(dx, dy)
	stamina -= cost
	run_streak = 0
	ran_this_turn = true
	step_noise = 7
	if in_mech():
		_move_vehicle(in_vehicle, pc)
	if city.tiles[pc] == CG.AIR and not flying:
		_fall_player("There is nothing under you.")
	elif not flying:
		say("You leap%s." % (" from a running start" if run_up else ""))
	if items_at.has(pc):
		var names := []
		for it in items_at[pc]:
			names.append(item_label(it))
		say("You see here: " + ", ".join(names) + ".")
	end_turn()
	return true

## squares between a shooter and a target that give the target cover: low props (halved by crouching behind them), walls at the corner, cars
func cover_vs(from: int, to: int, crouched: bool = false) -> int:
	var tx: int = to % size
	var ty: int = to / size
	var sx: int = signi(from % size - tx)
	var sy: int = signi(from / size - ty)
	if sx == 0 and sy == 0:
		return 0
	var best := 0
	for off in [[sx, sy], [sx, 0], [0, sy]]:
		if off[0] == 0 and off[1] == 0:
			continue
		var nx: int = tx + off[0]
		var ny: int = ty + off[1]
		if not in_bounds(nx, ny):
			continue
		var c: int = ny * size + nx
		if z_of(c) != z_of(to):
			continue
		var t: int = city.tiles[c]
		var v := 0
		if veh_at[c] != -1:
			v = 40 if crouched else 28
		elif t in CG.LOW_COVER or thing_at[c] != -1:
			v = 32 if crouched else 20
		elif t == CG.WALL:
			v = 15
		best = maxi(best, v)
	return best

## how well person i sees toward a cell given where they face: 1 in front (about 120 degrees), less at the sides, none behind.  Alerted people look wider.
func cone_factor(i: int, cell: int, wide: bool = false) -> float:
	var f: Array = DIR8[face[i]]
	var c: int = sim.pos[i]
	var dx: int = cell % size - c % size
	var dy: int = cell / size - c / size
	if dx == 0 and dy == 0:
		return 1.0
	var cs: float = (float(f[0] * dx + f[1] * dy)) / (sqrt(float(f[0] * f[0] + f[1] * f[1])) * sqrt(float(dx * dx + dy * dy)))
	if cs >= 0.5:
		return 1.0
	if cs >= -0.2:
		return 0.8 if wide else 0.4
	return 0.35 if wide else 0.0

## The player sees through a half circle in front of them; implants with an `arc` field widen it ("eyes in the back of your head").
const BASE_ARC := 180.0
func vision_arc() -> float:
	return minf(360.0, BASE_ARC + IMP.sum(implants, "arc", func(d): return body.group_ok(body.group_of_part(String(d.get("part", "head"))))))

func _compute_fov() -> void:
	fov.compute(pc % size, pc / size, 18, vision_arc(), facing.x, facing.y)

func turn_to(dx: int, dy: int) -> void:
	if dx == 0 and dy == 0:
		return
	facing = Vector2i(dx, dy)
	_compute_fov()
	say("You turn to face %s." % ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"][DIR8.find([signi(dx), signi(dy)])])

func _face_toward(i: int, cell: int) -> void:
	var c: int = sim.pos[i]
	var dx: int = signi(cell % size - c % size)
	var dy: int = signi(cell / size - c / size)
	if dx == 0 and dy == 0:
		return
	face[i] = DIR8.find([dx, dy])


# ---------------------------------------------------------------- body, armor, dodge
## Every hit lands on a limb.  Armor is a flat deduction from the damage (worn armor and implants both count) and wears out as it soaks damage.
## Damage types: only "phys" for now; armor entries can later carry their own numbers per type ("fire", "acid", "elec", "pierce", "blunt", "slash").
var body = BODY.new()
var armor_worn: Array = []                     # armor items worn over the body (helmet, vest, arm guards, shin guards)
var imp_dur: Dictionary = {}                   # implant id -> armor durability left (absent = as new)
var melee_arts: Array = []                     # learned melee arts: "parry", "riposte" (see _melee_arts_on_miss); empty until the player learns some
var bless_left: int = 0                        # turns of blessing left: a little luck (+6% to hit, +4% to dodge a blade)
const HUNGER_AFTER := 24 * 60                   # turns (a turn is a minute) without food before you are Hungry
const THIRST_AFTER := 4 * 60                    # ... without a drink before you are Thirsty
const NEED_SLOW := 0.8                          # each of Hungry / Thirsty cuts walking speed to 80% (they stack)
var last_ate: int = 0                           # sim.tick of the last meal and the last drink
var last_drank: int = 0
var move_debt: float = 0.0                      # fractions of a turn owed for walking slowly
var _was_hungry: bool = false
var _was_thirsty: bool = false
var drunk_left: int = 0                        # turns of drink left: -8% to hit
var atk_debt: int = 0                          # action cost of strikes not yet paid for in turns
var aim_last: int = -10
var aim_frac: float = 0.0                      # progress towards the next aim level
var _in_ap := false
const ARMOR_TYPES := ["phys"]

func limb_name(l: String) -> String:
	return BODY.NAME[l]

func _imp_active(d: Dictionary) -> bool:
	return body.group_ok(body.group_of_part(String(d["part"])))

func imp_sum(field: String) -> float:
	return IMP.sum(implants, field, _imp_active)

func _armor_items() -> Array:
	var out: Array = armor_worn.duplicate()
	for c in worn:
		if c.def.has("armor"):
			out.append(c)
	return out

func item_armor_left(it) -> int:
	var a: Dictionary = it.def["armor"]
	return int(a["dur"]) if it.cond < 0 else it.cond

## [{item, id, name, phys, left, max}] covering a limb: worn armor first (it takes the hit first), then implants
func armor_pieces(limb: String) -> Array:
	var grp: String = BODY.GROUP[limb]
	var out: Array = []
	for it in _armor_items():
		var a: Dictionary = it.def["armor"]
		if a["slot"] == grp or a["slot"] == "all":
			out.append({"item": it, "id": "", "name": it.def["name"], "phys": int(a["phys"]), "left": item_armor_left(it), "max": int(a["dur"])})
	for d in IMP.ALL:
		if implants.get(d["id"], false) and d.has("armor") and body.ok(limb) and (d["armor_group"] == grp or d["armor_group"] == "all"):
			out.append({"item": null, "id": d["id"], "name": d["name"], "phys": int(d["armor"]), "left": int(imp_dur.get(d["id"], int(d["dur"]))), "max": int(d["dur"])})
	return out

## the flat armor value on a limb against a damage type (broken pieces give nothing)
func armor_value(limb: String, _dtype: String = "phys") -> int:
	var t := 0
	for p in armor_pieces(limb):
		if int(p["left"]) > 0:
			t += int(p["phys"])
	return t

## overall armor for the HUD: durability left and total, plus the chest's value
func armor_status() -> Dictionary:
	var left := 0
	var mx := 0
	for it in _armor_items():
		left += item_armor_left(it)
		mx += int(it.def["armor"]["dur"])
	for d in IMP.ALL:
		if implants.get(d["id"], false) and d.has("armor"):
			left += int(imp_dur.get(d["id"], int(d["dur"])))
			mx += int(d["dur"])
	return {"left": left, "max": mx, "value": armor_value("chest")}

## flat deduction.  pen reduces the armor (armor-piercing rounds).  Returns {absorbed, through, broke: [names]}
func absorb(limb: String, dmg: int, pen: int = 0, dtype: String = "phys") -> Dictionary:
	var pieces: Array = armor_pieces(limb).filter(func(p): return int(p["left"]) > 0)
	var total := 0
	for p in pieces:
		total += int(p["phys"])
	var eff: int = maxi(0, total - pen)
	var absorbed: int = mini(dmg, eff)
	var broke: Array = []
	if absorbed > 0:
		var remaining: int = absorbed
		for p in pieces:
			var share: int = int(ceil(float(absorbed) * float(p["phys"]) / maxf(1.0, float(total))))
			share = mini(mini(share, remaining), int(p["left"]))
			if share <= 0:
				continue
			remaining -= share
			var left_now: int = int(p["left"]) - share
			if p["item"] != null:
				p["item"].cond = left_now
			else:
				imp_dur[p["id"]] = left_now
			if left_now <= 0:
				broke.append(p["name"])
	return {"absorbed": absorbed, "through": dmg - absorbed, "broke": broke, "dtype": dtype}

## damage to a limb and the pool, no armor: falls, crashes, seizures
func _raw_hurt(n: int, limb: String = "") -> void:
	if n <= 0:
		return
	var l: String = limb if limb != "" else body.pick(rng)
	_limb_hit(l, n)
	hp -= n

func _limb_hit(l: String, n: int) -> void:
	var r: Dictionary = body.damage(l, n)
	if r["broke"]:
		if l == "head" or l == "chest":
			say("Your %s is destroyed." % limb_name(l))
		else:
			say("Your %s is DISABLED!  %s" % [limb_name(l), _limb_effect(l)])
	if r["dead"]:
		hp = mini(hp, 0)

func _limb_effect(l: String) -> String:
	if BODY.GROUP[l] == "legs":
		return "You limp: every step costs extra time." if body.legs_ok() == 1 else "You can only drag yourself along."
	return "Two-handed weapons are out and your aim suffers." if body.arms_ok() == 1 else "You can't hold a weapon."

## the player takes a hit: pick a limb, armor takes its flat share, the limb and the pool take the rest
func player_hurt(dmg: int, msg: String, dtype: String = "phys", limb: String = "", pen: int = 0) -> void:
	if in_mech():
		var through: int = dmg / 5
		hp -= through
		say("%s: the mech's armour takes it (-%d frame, -%d you)." % [msg, dmg, through])
		vs.damage(in_vehicle, "body", dmg)
		return
	var l: String = limb if limb != "" else body.pick(rng)
	var my_grit: int = lvl("grit")
	dmg = maxi(1, dmg - SK.grit_cut(my_grit))
	if crit_roll(my_grit, -1, l.hash()):
		dmg = dmg * 3 / 2
		say("A critical hit!")
	var ab: Dictionary = absorb(l, dmg, pen, dtype)
	var through2: int = int(ab["through"])
	for b in ab["broke"]:
		say("Your %s breaks!" % b)
	if through2 > 0:
		sfx("hurt")
		_limb_hit(l, through2)
		hp -= through2
		skill_up("grit", 2 + through2 / 4)
		say("%s in the %s (-%d%s)." % [msg, limb_name(l), through2, (", armor soaks %d" % int(ab["absorbed"])) if int(ab["absorbed"]) > 0 else ""])
	else:
		say("%s in the %s, but your armor stops it (%d)." % [msg, limb_name(l), int(ab["absorbed"])])

## bullets can only be dodged with high-grade implants (grade 3 and up)
func player_bullet_dodge() -> int:
	var d: float = imp_sum("dodge_bullet") + SK.bullet_dodge(lvl("dodge"))
	if body.legs_ok() < 2:
		d *= 0.5 if body.legs_ok() == 1 else 0.0
	return clampi(int(d), 0, 40)

func player_melee_dodge() -> int:
	var d: float = float(SK.melee_dodge(lvl("dodge"))) + imp_sum("dodge_melee") + (3.0 if crouch else 0.0) + (4.0 if bless_left > 0 else 0.0)
	if body.legs_ok() < 2:
		d *= 0.5 if body.legs_ok() == 1 else 0.0
	return clampi(int(d), 0, 45)

## NPCs: armor, and dodge.  Bratva carry little, the NAP wear vests, Nasim's killers are wired (and the only ones who can dodge bullets).
func npc_armor(i: int) -> int:
	match fac[i]:
		BRATVA: return 1
		GANG: return 1
		NAP: return 3
		NASIM: return 2
	return 0

func npc_melee_dodge(i: int) -> int:
	return SK.melee_dodge(npc_lvl(i, "dodge"))

func npc_bullet_dodge(i: int) -> int:
	return SK.bullet_dodge(npc_lvl(i, "dodge"))

# ---- hands, aim speed and what broken limbs do
func weapon_hands(it) -> int:
	if it == null:
		return 0
	if it.def.has("gun"):
		return int(GP.stats(it).get("hands", 2))
	if it.def.has("melee"):
		var m: Dictionary = it.def["melee"]
		return 2 if (int(m["reach"]) >= 2 or m.get("slow", false)) else 1
	return 0

func can_use_weapon(it, why: bool = true) -> bool:
	var need: int = weapon_hands(it)
	if need == 0:
		return true
	var arms: int = body.arms_ok()
	if arms == 0:
		if why:
			say("You have no working arms.")
		return false
	if need > arms:
		if why:
			say("You can't handle the %s with one arm." % it.def["name"])
		return false
	return true

func _arm_acc_pen() -> int:
	var p := 0
	if body.arms_ok() < 2:
		p += 15
	for l in ["l_arm", "r_arm"]:
		if body.ok(l) and body.frac(l) < 0.5:
			p += 5
	if body.frac("head") < 0.5:
		p += 5
	return p

## aim levels gained per aim action: skill, the gun's class and optic, implants; broken arms and a hurt head slow it
func aim_rate() -> float:
	var st: Dictionary = gun_stats()
	var r: float = 1.0 + 0.08 * float(lvl("ranged")) + (0.25 if discipline("steady_aim") else 0.0)
	r += float(st.get("aim_rate", 0.0))
	r += imp_sum("aim")
	if body.arms_ok() < 2:
		r -= 0.5
	if body.frac("head") < 0.5:
		r -= 0.15
	return clampf(r, 0.25, 4.0)

# ---- melee speed: each strike costs action points; a turn pays 100
func melee_cost(ms: Dictionary) -> int:
	var c := float(ms.get("cost", 100))
	if ms.has("fast"):
		c = 100.0 - 60.0 * float(ms["fast"])
	if ms.get("slow", false):
		c = 180.0
	c -= float(lvl(melee_skill_id())) * 2.0 + imp_sum("atk_speed")
	if body.arms_ok() < 2:
		c += 25.0
	return clampi(int(c), 40, 260)

func _spend_ap(ms: Dictionary) -> void:
	atk_debt += melee_cost(ms)
	_in_ap = true
	while atk_debt >= 100 and not game_over:
		atk_debt -= 100
		end_turn()
	_in_ap = false

## melee arts are skills the player can learn later (parry, riposte).  The hooks are here and working; nothing grants them yet.
func has_art(id: String) -> bool:
	return id in melee_arts or discipline(id)

func learn_art(id: String) -> void:
	if not (id in melee_arts):
		melee_arts.append(id)

## a blow aimed at the player did not land.  how = "dodge" or "parry".  Returns true if the player got a free counter-strike.
func _melee_arts_on_miss(i: int, how: String) -> bool:
	if how == "parry" and has_art("riposte") and sim.alive[i] == 1 and cheb(sim.pos[i], pc) <= 1 and rng.randf() < 0.5 + 0.05 * float(lvl("melee")):
		say("Riposte!  You turn the parry into a strike.")
		var ms: Dictionary = melee_stats()
		var dmg: int = rng.randi_range(int(ms["dmg"][0]), int(ms["dmg"][1]))
		_melee_damage(i, dmg, ms)
		return true
	return false

func parry_chance(nm: Dictionary) -> int:
	if wield == null or not wield.has_tag("melee") or nm.get("flail", false) or not can_use_weapon(wield, false):
		return 0
	var p: int = int(melee_stats().get("parry", 0))
	if has_art("parry"):
		p += 12 + 2 * lvl("melee")
	return p

## trauma patch: 25 health and the worst limb mended a little (a disabled limb comes back)
func act_use_medical(it) -> bool:
	var holder = null
	for c in worn:
		if c == it or c.contains_item(it):
			holder = c
	if holder != null and holder != it:
		holder.remove(it)
	elif holder == it:
		worn.erase(it)
	hp = mini(hp_max, hp + 25)
	var l: String = body.worst()
	body.heal(l, maxi(8, int(body.mx[l]) / 3))
	say("You slap on a trauma patch: health up, your %s mended a little." % limb_name(l))
	end_turn()
	return true

## take one of a stack out of whatever holds it
func _consume_one(it) -> void:
	if it.count > 1:
		it.count -= 1
		return
	var holder = null
	for c in worn:
		if c == it or c.contains_item(it):
			holder = c
	if holder != null and holder != it:
		holder.remove(it)
	elif holder == it:
		worn.erase(it)
	elif items_at.has(pc) and items_at[pc].has(it):
		items_at[pc].erase(it)

## the effect of a meal or drink: health, stamina; strong drink dulls the aim for a while
func eat_now(it) -> void:
	var f: Dictionary = it.def.get("food", {})
	if f.get("drink", false):
		last_drank = sim.tick
	else:
		last_ate = sim.tick
	hp = mini(hp_max, hp + int(f.get("hp", 0)))
	stamina = mini(STAMINA_MAX, stamina + int(f.get("stam", 0)))
	if f.get("alcohol", false):
		drunk_left = mini(240, drunk_left + 60)

func act_eat(it) -> bool:
	var f: Dictionary = it.def.get("food", {})
	if f.is_empty():
		say("You can't eat that.")
		return false
	_consume_one(it)
	eat_now(it)
	say("You %s the %s.  (health +%d, stamina +%d)" % ["drink" if f.get("drink", false) else "eat", it.def["name"], int(f.get("hp", 0)), int(f.get("stam", 0))])
	end_turn()
	return true

func act_use_charm(it) -> bool:
	var u: Dictionary = it.def.get("use", {})
	if u.is_empty():
		return false
	_consume_one(it)
	if u.has("heat"):
		heat = maxi(0, heat + int(u["heat"]))
	if u.has("hp"):
		hp = mini(hp_max, hp + int(u["hp"]))
	if u.has("bless"):
		bless_left = maxi(bless_left, int(u["bless"]))
	say(String(u.get("msg", "You use it.")))
	end_turn()
	return true

## put armor on: it goes over the body in its slot; whatever was there goes into your pack (or the floor)
func act_wear(it) -> bool:
	var slot: String = it.def["armor"]["slot"]
	for c in worn:
		if c == it:
			say("You are already wearing that.")
			return false
	for c in worn:
		if c.contains_item(it):
			c.remove(it)
	var old = null
	for a in armor_worn:
		if a.def["armor"]["slot"] == slot:
			old = a
	if old != null:
		armor_worn.erase(old)
		if not stow(old):
			_put(pc, old)
	armor_worn.append(it)
	say("You put on the %s." % item_label(it))
	end_turn()
	return true

# ---------------------------------------------------------------- melee
## the stats of whatever is in your hands for close work: a melee weapon, a gun used as a club, or bare hands
func melee_stats() -> Dictionary:
	if body.arms_ok() == 0:
		return {"dmg": [2, 4], "reach": 1, "acc": -15, "verb": "kick"}
	var usable: bool = wield == null or can_use_weapon(wield, false)
	if wield != null and usable and wield.def.has("melee"):
		return wield.def["melee"]
	if wield != null and usable and wield.def.has("gun"):
		return {"dmg": [2, 4], "reach": 1, "acc": -5, "verb": "club"}
	if wield == null and has_implant("mantis"):
		return {"dmg": [8, 13], "reach": 1, "acc": 6, "verb": "slash", "fast": 0.3, "bleed": true, "mantis": true}
	return {"dmg": [3, 6], "reach": 1, "acc": 0, "verb": "hit"}

func melee_line() -> String:
	var m: Dictionary = melee_stats()
	var bits: Array = ["dmg %d-%d" % [m["dmg"][0], m["dmg"][1]]]
	if int(m["reach"]) > 1:
		bits.append("reach %d" % m["reach"])
	for k in ["parry", "stun", "sneak"]:
		if m.has(k):
			bits.append("%s %s" % [k, str(m[k])])
	if m.get("slow", false):
		bits.append("slow")
	return ", ".join(bits)

## which weapon person i carries into a fight (a def id), or "" if none: Bratva carry Russian blades, the NAP and Nasim Japanese ones.  Deterministic per person.
func npc_melee_id(i: int) -> String:
	if fac[i] == CIV or gunc[i] > 0 or mdis[i] == 1 or (i * 40503 + 17) % 100 >= 55:
		return ""
	var pool: Array = melee_pool.get(fac[i], [])
	if pool.is_empty():
		return ""
	var id: String = pool[(i * 7 + 3) % pool.size()]
	return id + ("_f" if (i * 31) % 10 == 0 else "")

func npc_melee_stats(i: int) -> Dictionary:
	var id := npc_melee_id(i)
	if id == "":
		return {}
	return db.defs[id]["melee"]

func _melee_pools() -> void:
	melee_pool = {BRATVA: [], NAP: [], NASIM: [], GANG: []}
	var ids: Array = []
	for k in db.defs:
		if "melee" in db.defs[k].get("tags", []) and not (k.ends_with("_f") or k.ends_with("_m")):
			ids.append(k)
	ids.sort()
	for k in ids:
		var name: String = k.substr(8)
		var ru: bool = db.defs[k]["culture"] == "Russian"
		if ru:
			melee_pool[BRATVA].append(k)
			melee_pool[GANG].append(k)
		elif name in ["wakizashi", "tanto", "katana", "tonfa", "bo", "jitte"]:
			melee_pool[NAP].append(k)
		elif name in ["kama", "nunchaku", "sai", "kunai", "jo", "tessen"]:
			melee_pool[NASIM].append(k)
	melee_all = ids

func _random_melee(grade: String = "") -> String:
	return melee_all[rng.randi() % melee_all.size()] + grade

func _line_clear(a: int, b: int) -> bool:
	for c in GP.line_cells(a, b, size):
		var t: int = city.tiles[c]
		if t == CG.WALL or t == CG.EARTH or t == CG.LOCKED or t == CG.GLASS:
			return false
	return true

## one strike at person i from where you stand, with whatever you hold.  dist is how far away they are (reach weapons).
## accuracy: skill + weapon - a missing arm; then the target's dodge; attack speed is paid for afterwards in action points (_spend_ap).
func melee(i: int, dist: int = 1) -> void:
	var ms: Dictionary = melee_stats()
	var msk: String = melee_skill_id()
	var sneak := astate[i] == UNAWARE or astate[i] == RETURNING
	var chance: int = 72 + lvl(msk) * 3 + int(ms.get("acc", 0)) - (0 if sneak else 12) - 4 * (dist - 1) - (10 if body.arms_ok() < 2 else 0)
	if astate[i] == SURRENDERED:
		chance = 100
	if sim.alive[i] == 0:
		return
	if rng.randi() % 100 >= chance:
		say("You miss %s." % name_of(i))
		_alert(i)
		return
	var dodge: int = 0 if (sneak or astate[i] == SURRENDERED or stun[i] > 0) else npc_melee_dodge(i)
	if rng.randi() % 100 < dodge:
		say("%s dodges your %s." % [name_of(i), String(ms.get("verb", "blow"))])
		_alert(i)
		return
	var dmg: int = rng.randi_range(int(ms["dmg"][0]), int(ms["dmg"][1])) + lvl(msk) / 2 + (2 if msk == "unarmed" and discipline("iron_fist") else 0)
	var behind: bool = sneak and cone_factor(i, pc) == 0.0
	if behind:
		dmg *= int(ms.get("sneak", 4))
		say("You strike %s from behind!" % name_of(i))
	elif sneak:
		dmg *= 2
		say("You catch %s unready." % name_of(i))
	if dist > 1 and ms.get("brace", false) and astate[i] == HUNTING:
		dmg = dmg * 3 / 2
		say("You meet the charge on the point.")
	_silent = behind
	_melee_damage(i, dmg, ms)
	_silent = false
	if sim.alive[i] == 1:
		_melee_effects(i, ms)
		if msk == "unarmed" and discipline("pressure_points") and rng.randf() < 0.2:
			stun[i] = 3
			sim.ctl[i] = 1
			say("%s is staggered by a nerve strike." % name_of(i))
	skill_up(msk, 3 if hpmax[i] >= 40 else 1)
	if ms.get("sweep", false):
		_sweep_others(i, ms)

func _melee_damage(i: int, dmg: int, ms: Dictionary) -> void:
	var pen: int = int(ms.get("pen", 1 if int(ms["dmg"][1]) >= 14 else 0))
	var cut: int = mini(dmg, maxi(0, npc_armor(i) - pen))
	if cut > 0 and cut >= dmg:
		say("Your %s glances off %s's armor." % [String(ms.get("verb", "blow")), name_of(i)])
		_alert(i)
		return
	dmg -= cut
	dmg = npc_take(i, dmg)
	hpn[i] -= dmg
	if hpn[i] <= 0:
		kill(i)
		return
	say("You %s %s (%d)." % [ms.get("verb", "hit"), name_of(i), dmg])
	_alert(i)

func _melee_effects(i: int, ms: Dictionary) -> void:
	if ms.get("bleed", false) and bleed[i] < 6:
		bleed[i] = 5
		say_if_seen(sim.pos[i], "%s is bleeding." % name_of(i))
	if rng.randf() < float(ms.get("stun", 0.0)):
		stun[i] = 3
		sim.ctl[i] = 1
		say("%s reels." % name_of(i))
	elif rng.randf() < float(ms.get("trip", 0.0)):
		stun[i] = 1
		sim.ctl[i] = 1
		say("The hook takes %s's feet from under them." % name_of(i))
	elif rng.randf() < float(ms.get("entangle", 0.0)):
		stun[i] = 3
		sim.ctl[i] = 1
		say("The chain wraps %s and pulls them up short." % name_of(i))
	if rng.randf() < float(ms.get("knock", 0.0)):
		_knock_back(i)
		if sim.alive[i] == 0:
			return
	if rng.randf() < float(ms.get("disarm", 0.0)):
		var c: int = sim.pos[i]
		if gunc[i] > 0:
			var tag: String = ["", "pistol", "smg", "rifle"][gunc[i]]
			var arr: Array = gun_ids[tag]
			var gn = _new_item(arr[rng.randi() % arr.size()])
			_part_load(gn)
			_put(c, gn)
			gunc[i] = 0
			say("You knock the gun from %s's hand." % name_of(i))
		elif npc_melee_id(i) != "":
			_put(c, _new_item(npc_melee_id(i)))
			mdis[i] = 1
			say("You send %s's weapon spinning away." % name_of(i))

## a long weapon's arc takes in other enemies beside the one you hit
func _sweep_others(i: int, ms: Dictionary) -> void:
	var hit := 0
	for k in sim.near_list.size():
		var j: int = sim.near_list[k]
		if j == i or sim.alive[j] == 0 or hit >= 2:
			continue
		if cheb(sim.pos[j], pc) <= 1 and (astate[j] == HUNTING or hostile(j)):
			var dmg: int = rng.randi_range(int(ms["dmg"][0]), int(ms["dmg"][1])) * 6 / 10
			say("The sweep catches %s." % name_of(j))
			_melee_damage(j, dmg, ms)
			hit += 1

## strike in a direction as far as the weapon reaches
func act_strike(dx: int, dy: int) -> bool:
	if in_vehicle >= 0 and not in_mech():
		return false
	var ms: Dictionary = melee_stats()
	var reach: int = int(ms["reach"])
	for dist in range(1, reach + 1):
		var nx: int = pc % size + dx * dist
		var ny: int = pc / size + dy * dist
		if not in_bounds(nx, ny):
			return false
		var c: int = ny * size + nx
		if z_of(c) != z_of(pc):
			return false
		var who: int = sim.at[c]
		if who >= 0:
			if dist > 1 and not _line_clear(pc, c):
				return false
			facing = Vector2i(dx, dy)
			melee(who, dist)
			_spend_ap(ms)
			return true
	for dist in range(1, reach + 1):
		var nx2: int = pc % size + dx * dist
		var ny2: int = pc / size + dy * dist
		if not in_bounds(nx2, ny2):
			break
		var c2: int = ny2 * size + nx2
		if z_of(c2) != z_of(pc):
			break
		var dmg: int = rng.randi_range(int(ms["dmg"][0]), int(ms["dmg"][1])) + lvl(melee_skill_id()) / 2
		if crit_at[c2] != -1:
			facing = Vector2i(dx, dy)
			crit_hit(crit_at[c2], dmg)
			end_turn()
			return true
		if thing_at[c2] != -1:
			facing = Vector2i(dx, dy)
			thing_hit(thing_at[c2], dmg)
			end_turn()
			return true
	say("Nothing within reach of your %s." % (wield.def["name"] if wield != null else "fists"))
	return false

## a hunter two cells away in a straight line: a reach weapon strikes instead of stepping
func _reach_target(dx: int, dy: int) -> int:
	var ms: Dictionary = melee_stats()
	if int(ms["reach"]) < 2:
		return -1
	var nx: int = pc % size + dx * 2
	var ny: int = pc / size + dy * 2
	if not in_bounds(nx, ny):
		return -1
	var c: int = ny * size + nx
	var who: int = sim.at[c]
	if who >= 0 and astate[who] == HUNTING and fac[who] != CIV and z_of(c) == z_of(pc) and _line_clear(pc, c):
		return who
	return -1

func act_swap() -> bool:
	if prev_wield == null:
		say("Nothing to swap to.")
		return false
	var carried := false
	for e in inventory_list():
		if e["item"] == prev_wield:
			carried = true
	if not carried:
		prev_wield = null
		say("Nothing to swap to.")
		return false
	return act_wield(prev_wield)

func _bleed_tick() -> void:
	for k in sim.near_list.size():
		var j: int = sim.near_list[k]
		if sim.alive[j] == 1 and bleed[j] > 0:
			bleed[j] -= 1
			hpn[j] -= 1
			if hpn[j] <= 0:
				say_if_seen(sim.pos[j], "%s bleeds out." % name_of(j))
				kill(j)

func hurt(i: int, dmg: int, by_player: bool) -> void:
	if by_player:
		sfx("hit")
	hpn[i] -= dmg
	if hpn[i] <= 0:
		kill(i)
		return
	if by_player:
		say("You hit %s (%d)." % [name_of(i), dmg])
		_alert(i)

func _alert(i: int) -> void:
	noticed_you[i] = 1
	var f := fac[i]
	if f == CIV or (f == NAP and heat < 30 and false):
		_flee(i, 25)
		return
	if astate[i] != HUNTING:
		_set_state(i, HUNTING)
		sim.ctl[i] = 1
		lastpos[i] = pc
		meter[i] = 100
		_alarm(i)

func _flee(i: int, turns: int) -> void:
	if astate[i] != FLEEING:
		say("%s flees!" % name_of(i))
	astate[i] = FLEEING
	timer[i] = turns
	sim.ctl[i] = 1

func _set_state(i: int, s: int) -> void:
	astate[i] = s

func kill(i: int) -> void:
	say("%s goes down." % name_of(i))
	var c: int = sim.pos[i]
	var carried: int = yenn[i]
	if carried > 0:
		_put(c, _new_item("trl_yen", carried))
	if gunc[i] > 0 and rng.randf() < 0.6:
		var tag: String = ["", "pistol", "smg", "rifle"][gunc[i]]
		var arr: Array = gun_ids[tag]
		var dropped = _new_item(arr[rng.randi() % arr.size()])
		_part_load(dropped)
		_put(c, dropped)
		if rng.randf() < 0.1:
			_put(c, _new_item(_random_mod()))
	var mw: String = npc_melee_id(i)
	if mw != "" and rng.randf() < 0.5:
		_put(c, _new_item(mw))
	stun[i] = 0
	bleed[i] = 0
	sim.remove_agent(i)
	astate[i] = UNAWARE
	_witness(c, 4 if _silent else 14, 3 if _silent else 14, i)

## people who see violence react: civilians panic, officers add heat
func _witness(cell: int, radius: int, add_heat: int, except: int) -> void:
	var seen_by := 0
	for k in sim.near_list.size():
		var j: int = sim.near_list[k]
		if j == except or sim.alive[j] == 0:
			continue
		if cheb(sim.pos[j], cell) > radius:
			continue
		if not sim._sees(sim.pos[j], cell, radius):
			continue
		if astate[j] != HUNTING and cone_factor(j, cell, true) == 0.0:
			continue                       # they had their back turned
		if fac[j] == CIV or fac[j] == NAP:
			seen_by += 1
			if fac[j] == CIV and astate[j] != FLEEING:
				_flee(j, 20)
	if seen_by > 0:
		heat = mini(100, heat + mini(add_heat, 4 + seen_by * 3))

func _alarm(i: int) -> void:
	var told := 0
	for k in sim.near_list.size():
		var j: int = sim.near_list[k]
		if j == i or fac[j] != fac[i] or astate[j] == HUNTING or astate[j] >= FLEEING or sim.alive[j] == 0:
			continue
		if cheb(sim.pos[j], sim.pos[i]) > 14:
			continue
		astate[j] = SUSPICIOUS
		meter[j] = maxi(meter[j], 70)
		lastpos[j] = pc
		postc[j] = sim.pos[j]
		sim.ctl[j] = 1
		told += 1
	if told > 0 and sees_cell(sim.pos[i]):
		say("%s shouts an alarm!" % name_of(i))

func act_steal() -> bool:
	var target := -1
	for d in SIZE_DIRS:
		var nx: int = pc % size + d[0]
		var ny: int = pc / size + d[1]
		if in_bounds(nx, ny) and sim.at[ny * size + nx] >= 0:
			target = sim.at[ny * size + nx]
			break
	if target < 0:
		say("There is no one next to you to rob.")
		return false
	var aware := astate[target] != UNAWARE and astate[target] != RETURNING
	var chance: int = 46 + lvl("deception") * 7 + (12 if crouch else 0)
	if aware:
		chance -= 40
	if astate[target] == SURRENDERED:
		chance = 100
	if yenn[target] == 0:
		say("%s has nothing worth taking." % name_of(target))
		return false
	if rng.randi() % 100 < chance:
		var take: int = yenn[target]
		yenn[target] = 0
		yen += take
		say("You lift ¥%d from %s without a sound." % [take, name_of(target)])
		skill_up("deception", 4 if not aware else 6)
		if fac[target] == NAP:
			_witness(sim.pos[target], 8, 6, target)
		end_turn()
		return true
	say("%s catches your hand!" % name_of(target))
	skill_up("deception", 3)
	_alert(target)
	heat = mini(100, heat + 4)
	end_turn()
	return false

# ---------------------------------------------------------------- guns
func pool_key(cal: String, kind: String) -> String:
	return cal + "|" + kind

func pool_get(cal: String, kind: String) -> int:
	return int(ammo_pool.get(pool_key(cal, kind), 0))

func pool_add(cal: String, kind: String, n: int) -> void:
	var k := pool_key(cal, kind)
	ammo_pool[k] = int(ammo_pool.get(k, 0)) + n
	if ammo_pool[k] <= 0:
		ammo_pool.erase(k)

## loose rounds of one caliber, all kinds
func reserve(cal: String) -> int:
	var t := 0
	for kind in GP.KINDS_BY_CAL.get(cal, []):
		t += pool_get(cal, kind)
	return t

func ammo_total() -> int:
	var t := 0
	for k in ammo_pool:
		t += int(ammo_pool[k])
	return t

func gun_stats() -> Dictionary:
	if wield == null or not wield.has_tag("gun"):
		return {}
	return GP.stats(wield)

func _target_ok(j: int, any: bool, st: Dictionary) -> bool:
	if j < 0 or j >= sim.n or sim.alive[j] == 0 or sim.near[j] == 0 or not sees_cell(sim.pos[j]):
		return false
	if not any and not (hostile(j) or astate[j] == HUNTING):
		return false
	return cheb(sim.pos[j], pc) <= int(st["range"]) + 4 and sim._sees(pc, sim.pos[j], 40)

## visible targets, nearest first
func target_list(any: bool = false) -> Array:
	var st: Dictionary = gun_stats()
	var out: Array = []
	if st.is_empty():
		return out
	for k in sim.near_list.size():
		var j: int = sim.near_list[k]
		if _target_ok(j, any, st):
			out.append(j)
	out.sort_custom(func(a, b): return cheb(sim.pos[a], pc) < cheb(sim.pos[b], pc))
	return out

func nearest_target(any: bool = false) -> int:
	var l: Array = target_list(any)
	return l[0] if not l.is_empty() else -1

## the target a shot would go at: the chosen one if still valid, otherwise the nearest
func current_target(any: bool = false) -> int:
	var st: Dictionary = gun_stats()
	if st.is_empty():
		return -1
	if aim_target >= 0 and _target_ok(aim_target, any, st):
		return aim_target
	aim_target = -1
	return nearest_target(any)

func hit_chance_on(t: int, shot_index: int = 0) -> int:
	var st: Dictionary = gun_stats()
	if st.is_empty() or t < 0:
		return 0
	return _shot_chance(st, t, aim_turns, shot_index)

## model + stance + cover on the target
func _shot_chance(st: Dictionary, t: int, aimed: int, shot_index: int) -> int:
	var d: int = cheb(sim.pos[t], pc)
	var c: int = GP.hit_chance(st, d, aimed, moved, crouch, lvl("ranged"), eco.aim_penalty(), shot_index, stance == CRAWL)
	c += int(imp_sum("acc"))                         # brain and eye implants, the palm link
	if d >= 5:
		c += int(imp_sum("acc_far"))
		if discipline("marksman"):
			c += 6
	c -= _arm_acc_pen()
	if bless_left > 0:
		c += 6
	if drunk_left > 0:
		c -= 8
	return clampi(c - cover_vs(pc, sim.pos[t], false), 5, 95)

## one-line description of the wielded gun and what it is aimed at
func gun_line() -> String:
	if wield == null:
		return "bare hands"
	if wield.has_tag("melee"):
		return "%s [%s]" % [wield.def["name"], melee_line()]
	if not wield.has_tag("gun"):
		return "bare hands"
	var st: Dictionary = gun_stats()
	var s := "%s [%s] %d/%d %s  res %d" % [wield.def["name"], GP.mode_name(wield), wield.loaded, st["mag"], st["label"] if wield.loaded > 0 else "empty", reserve(st["cal"])]
	if wield.jammed:
		s += "  JAMMED"
	if aim_turns > 0:
		s += "  aim %d" % aim_turns
	return s

func act_cycle_target(any: bool = false) -> bool:
	var l: Array = target_list(any)
	if gun_stats().is_empty():
		say("You have no gun wielded.")
		return false
	if l.is_empty():
		say("Nothing to target.")
		return false
	var idx: int = l.find(aim_target)
	aim_target = l[(idx + 1) % l.size()]
	aim_turns = 0
	say("Target: %s, %d tiles, %d%% to hit." % [name_of(aim_target), cheb(sim.pos[aim_target], pc), hit_chance_on(aim_target)])
	return true

func act_aim(any: bool = false) -> bool:
	var st: Dictionary = gun_stats()
	if st.is_empty():
		say("You have no gun wielded.")
		return false
	var t := current_target(any)
	if t < 0:
		say("Nothing to aim at.")
		return false
	if not can_use_weapon(wield):
		return false
	if aim_turns == 0 and turn > aim_last + 1:
		aim_frac = 0.0
	aim_last = turn
	aim_frac += aim_rate()
	while aim_frac >= 0.999 and aim_turns < GP.MAX_AIM:
		aim_turns += 1
		aim_frac = maxf(0.0, aim_frac - 1.0)
	if aim_turns >= GP.MAX_AIM:
		aim_frac = 0.0
	aim_target = t
	say("You steady the %s on %s (aim %d, %.2f a turn): %d%% to hit." % [wield.def["name"], name_of(t), aim_turns, aim_rate(), hit_chance_on(t)])
	end_turn()
	return true

func act_fire_mode() -> bool:
	if gun_stats().is_empty():
		return false
	var m: Array = wield.def["gun"]["modes"]
	wield.mode = (wield.mode + 1) % m.size()
	say("Fire mode: %s (%d shot%s)." % [GP.mode_name(wield), GP.mode_shots(wield), "" if GP.mode_shots(wield) == 1 else "s"])
	return true

## choose which kind the next reload takes
func act_cycle_kind() -> bool:
	var st: Dictionary = gun_stats()
	if st.is_empty():
		return false
	var cal: String = st["cal"]
	var kinds: Array = GP.KINDS_BY_CAL[cal]
	var cur: String = want_kind.get(cal, wield.kind if wield.kind != "" else kinds[0])
	var i: int = kinds.find(cur)
	for step in kinds.size():
		var k: String = kinds[(i + 1 + step) % kinds.size()]
		if pool_get(cal, k) > 0 or k == wield.kind:
			want_kind[cal] = k
			say("Next reload: %s %s (%d rounds loose)." % [cal, GP.KIND[k]["label"], pool_get(cal, k)])
			return true
	say("You carry no other %s ammunition." % cal)
	return false

func act_reload() -> bool:
	var st: Dictionary = gun_stats()
	if st.is_empty():
		say("You have no gun wielded.")
		return false
	if in_vehicle >= 0 and not in_mech():
		say("Not while driving.")
		return false
	if wield.jammed:
		wield.jammed = false
		say("You clear the jam.")
		skill_up("engineering", 2)
		end_turn()
		return true
	var cal: String = st["cal"]
	var kind: String = want_kind.get(cal, "")
	if kind == "" or (pool_get(cal, kind) == 0 and wield.kind != kind):
		kind = wield.kind if wield.loaded > 0 else ""
		if kind == "" or pool_get(cal, kind) == 0:
			for k in GP.KINDS_BY_CAL[cal]:
				if pool_get(cal, k) > 0:
					kind = k
					break
	if kind == "":
		say("You have no %s ammunition." % cal)
		return false
	if wield.loaded > 0 and wield.kind != kind:
		pool_add(cal, wield.kind, wield.loaded)
		wield.loaded = 0
	var need: int = int(st["mag"]) - wield.loaded
	if need <= 0:
		say("The %s is already full." % wield.def["name"])
		return false
	var take: int = mini(need, pool_get(cal, kind))
	if take <= 0:
		say("You have no %s %s rounds." % [cal, GP.KIND[kind]["label"]])
		return false
	pool_add(cal, kind, -take)
	wield.loaded += take
	wield.kind = kind
	say("You load %d %s rounds (%d/%d)." % [take, GP.KIND[kind]["label"], wield.loaded, st["mag"]])
	aim_turns = 0
	for _t in int(st["reload"]):
		if game_over:
			break
		end_turn()
	return true

## a vehicle standing in the line of fire stops the bullet: [vehicle index, cell] or []
func _vehicle_in_line(t: int) -> Array:
	for c in GP.line_cells(pc, sim.pos[t], size):
		var vi: int = veh_at[c]
		if vi != -1 and vi != in_vehicle and not vehicles[vi]["wreck"] and sim.at[c] != t:
			return [vi, c]
	return []

func _victim_in_line(t: int) -> int:
	for c in GP.line_cells(pc, sim.pos[t], size):
		var who: int = sim.at[c]
		if who >= 0 and who != t and sim.alive[who] == 1 and rng.randf() < 0.55:
			return who
	return t

func act_fire(any: bool = false) -> bool:
	if in_vehicle >= 0 and not in_mech():
		say("You can't aim from the driver's seat.")
		return false
	var st: Dictionary = gun_stats()
	if st.is_empty():
		say("You have no gun wielded.  [i] to wield one.")
		return false
	if wield.jammed:
		say("The %s is jammed.  [r] clears it." % wield.def["name"])
		return false
	if wield.loaded <= 0:
		say("Click.  The %s is empty.  [r] reloads." % wield.def["name"])
		return false
	if not can_use_weapon(wield):
		return false
	var t := current_target(any)
	if t < 0:
		say("No hostile target in sight.  (Shift+F fires at anyone.)")
		return false
	aim_target = t
	var shots: int = mini(GP.mode_shots(wield), wield.loaded)
	var d: int = cheb(sim.pos[t], pc)
	var dmg_by: Dictionary = {}                  # agent -> damage
	var hits_by: Dictionary = {}
	var aimed: int = aim_turns
	for s in shots:
		var chance: int = _shot_chance(st, t, aimed, s)
		var blocked: Array = _vehicle_in_line(t)
		if not blocked.is_empty() and st["blast"] == 0:
			var vdmg: int = rng.randi_range(int(st["dmg"][0]), int(st["dmg"][1]))
			tracers.append([pc, blocked[1], true])
			sfx("shot")
			vs.damage_cell(int(blocked[0]), int(blocked[1]), vdmg, "gunfire")
			if s == 0:
				say("Your shots slam into the %s." % vs.KINDS[vehicles[int(blocked[0])]["kind"]]["name"])
			continue
		var victim: int = _victim_in_line(t)
		var vd: int = d if victim == t else cheb(sim.pos[victim], pc)
		var pellets: int = int(st["pellets"])
		var landed := 0
		var dmg_total := 0
		var arm_eff: int = maxi(0, npc_armor(victim) - int(st.get("pen", 0)))
		if st["blast"] > 0:
			landed = 1 if rng.randi() % 100 < chance else 0
			dmg_total = rng.randi_range(int(st["dmg"][0]), int(st["dmg"][1]))
		elif pellets > 1:
			var pc_chance: int = clampi(chance - int(float(vd) * 3.0 * float(st["spread"])), 4, 95)
			var fall: float = 1.0 if vd <= int(st["range"]) else 0.5
			for _p in pellets:
				if rng.randi() % 100 < pc_chance:
					landed += 1
					dmg_total += maxi(0, int(float(rng.randi_range(int(st["dmg"][0]), int(st["dmg"][1]))) / float(pellets) * 1.25 * fall) - arm_eff)
		else:
			if rng.randi() % 100 < chance:
				if rng.randi() % 100 < npc_bullet_dodge(victim):
					say_if_seen(sim.pos[victim], "%s blurs aside and the round misses." % name_of(victim))
				else:
					landed = 1
					dmg_total = maxi(0, rng.randi_range(int(st["dmg"][0]), int(st["dmg"][1])) - arm_eff)
					if dmg_total == 0:
						say("The round pings off %s's armor." % name_of(victim))
		tracers.append([pc, sim.pos[victim] if landed > 0 or st["blast"] > 0 else sim.pos[t], landed > 0])
		sfx("shot" if int(st["noise"]) < 14 else "shot_big")
		if st["blast"] > 0:
			_explode(sim.pos[t] if landed > 0 else _scatter_cell(sim.pos[t]), int(st["blast"]), dmg_total)
			hits_by[t] = hits_by.get(t, 0) + landed
			continue
		if landed > 0:
			dmg_by[victim] = int(dmg_by.get(victim, 0)) + dmg_total
			hits_by[victim] = int(hits_by.get(victim, 0)) + landed
	wield.loaded -= shots
	var msg := "You fire the %s [%s]" % [wield.def["name"], GP.mode_name(wield)]
	if aimed > 0:
		msg += " (aimed)"
	if st["blast"] > 0:
		msg += ": the grenade bursts."
	else:
		var parts: Array = []
		for v in dmg_by:
			parts.append("%s: %d hit%s for %d" % [name_of(v), hits_by[v], "" if hits_by[v] == 1 else "s", dmg_by[v]])
		msg += (": " + ", ".join(parts)) if not parts.is_empty() else ": miss"
	say(msg)
	aim_turns = 0
	_noise(pc, int(st["noise"]))
	for v in dmg_by:
		_damage_npc(v, int(dmg_by[v]))
		skill_up("ranged", 2 + d / 5)
	if dmg_by.is_empty() and st["blast"] == 0:
		_alert(t)
	if rng.randf() * 100.0 < float(st["jam"]) * float(shots) * maxf(0.5, 1.0 - 0.04 * float(lvl("engineering"))) and wield.loaded > 0:
		wield.jammed = true
		say("The %s jams." % wield.def["name"])
	end_turn()
	return true

func _damage_npc(v: int, dmg: int) -> void:
	if sim.alive[v] == 0:
		return
	var st: Dictionary = gun_stats()
	_silent = (not st.is_empty() and st["suppressed"]) and (astate[v] == UNAWARE or astate[v] == RETURNING)
	dmg = npc_take(v, dmg)
	hpn[v] -= dmg
	if hpn[v] <= 0:
		kill(v)
	else:
		_alert(v)
	_silent = false

func _scatter_cell(c: int) -> int:
	var nx: int = c % size + rng.randi_range(-2, 2)
	var ny: int = c / size + rng.randi_range(-2, 2)
	if not in_bounds(nx, ny) or z_of(ny * size + nx) != z_of(c) or not city.walkable(city.tiles[ny * size + nx]):
		return c
	return ny * size + nx

## a blast: everyone within `radius` on the same level takes damage that falls off with distance, you included
func _explode(c: int, radius: int, dmg: int) -> void:
	say_if_seen(c, "BOOM.")
	sfx("boom")
	var victims: Array = []
	for k in sim.near_list.size():
		var j: int = sim.near_list[k]
		if sim.alive[j] == 1 and cheb(sim.pos[j], c) <= radius:
			victims.append(j)
	for ti in things.size():
		if things[ti]["k"] != "" and things[ti]["cell"] / s2 == c / s2 and cheb(things[ti]["cell"], c) <= radius:
			smash_thing(ti, "is blown apart")
	for ki in critters.size():
		if critters[ki]["k"] != "" and critters[ki]["cell"] / s2 == c / s2 and cheb(critters[ki]["cell"], c) <= radius:
			_kill_crit(ki, "is killed by the blast")
	for vi in vehicles.size():
		var vv: Dictionary = vehicles[vi]
		if vv["wreck"] or z_of(vv["cell"]) != z_of(c):
			continue
		var best_d: int = 99
		var best_c: int = vv["cell"]
		for vc in vs.cells(vv):
			var dd: int = cheb(vc, c)
			if dd < best_d:
				best_d = dd
				best_c = vc
		if best_d <= radius:
			vs.damage_cell(vi, best_c, int(float(dmg) * (1.0 - 0.2 * float(best_d))), "blast")
			vs.damage(vi, "engine", dmg / 4, "blast")
	for j in victims:
		var f: float = 1.0 - 0.3 * float(cheb(sim.pos[j], c))
		_damage_npc(j, int(float(dmg) * f))
	if cheb(pc, c) <= radius:
		player_hurt(int(float(dmg) * (1.0 - 0.3 * float(cheb(pc, c)))), "The blast catches you")
	heat = mini(100, heat + 12)
	_noise(c, 26)

# ---- vehicle service: engines and repairs
## engine items you carry or that lie at your feet: [{item, ground}]
func engines_available() -> Array:
	var out: Array = []
	for e in inventory_list():
		if e["item"].has_tag("engine"):
			out.append({"item": e["item"], "ground": false})
	if items_at.has(pc):
		for it in items_at[pc]:
			if it.has_tag("engine"):
				out.append({"item": it, "ground": true})
	return out

func repair_kits() -> Array:
	var out: Array = []
	for e in inventory_list():
		if e["item"].def.has("repair"):
			out.append(e["item"])
	return out

func _take_item(it, ground: bool) -> void:
	if ground:
		items_at[pc].erase(it)
		if items_at[pc].is_empty():
			items_at.erase(pc)
	elif wield == it:
		wield = null
	else:
		_holder_remove(it)

func act_fit_engine(vi: int, it, ground: bool) -> bool:
	if in_vehicle >= 0 or vs.near_vehicle() != vi:
		say("Stand next to the vehicle.")
		return false
	var old = vs.swap_engine(vi, it)
	if old == null:
		say("The %s does not fit a %s." % [it.def["name"], vs.KINDS[vehicles[vi]["kind"]]["name"]])
		return false
	_take_item(it, ground)
	_put(pc, old)
	say("You swing the old engine out and bolt in the %s (%d%%)." % [it.def["name"], vs.part_pct(vehicles[vi], "engine")])
	end_turn()
	end_turn()
	end_turn()
	return true

func act_repair(vi: int, part: String) -> bool:
	var kits: Array = repair_kits()
	if kits.is_empty():
		say("You need a field repair kit.")
		return false
	if vs.near_vehicle() != vi or in_vehicle >= 0:
		say("Stand next to the vehicle.")
		return false
	var v: Dictionary = vehicles[vi]
	if int(v["parts"][part]) >= int(v["pmax"][part]):
		say("That part is as good as it gets.")
		return false
	vs.repair(vi, part, int(kits[0].def["repair"]))
	var kit = kits[0]
	if kit.count > 1:
		kit.count -= 1
	else:
		_take_item(kit, false)
	say("You patch up the %s (%d%%)." % [part, vs.part_pct(v, part)])
	end_turn()
	return true

# ---- mods
## carried mods that could go on the wielded gun
func mods_carried() -> Array:
	var out: Array = []
	for e in inventory_list():
		if e["item"].has_tag("mod"):
			out.append(e["item"])
	return out

func mod_fits(modit) -> bool:
	var st: Dictionary = gun_stats()
	return not st.is_empty() and GP.mod_slot(modit) in st["slots"]

func _clamp_mag() -> void:
	var st: Dictionary = gun_stats()
	if wield.loaded > int(st["mag"]):
		var extra: int = wield.loaded - int(st["mag"])
		pool_add(st["cal"], wield.kind, extra)
		wield.loaded = int(st["mag"])

func _holder_remove(it) -> void:
	for c in worn:
		if c == it:
			worn.erase(c)
			return
		if c.remove(it):
			return

func act_mod_install(modit) -> bool:
	if gun_stats().is_empty():
		say("Wield a gun first.")
		return false
	if not modit.has_tag("mod") or not mod_fits(modit):
		say("The %s does not fit the %s." % [modit.def["name"], wield.def["name"]])
		return false
	var slot: String = GP.mod_slot(modit)
	_holder_remove(modit)
	for old in wield.mods.duplicate():
		if GP.mod_slot(old) == slot:
			wield.mods.erase(old)
			if not stow(old):
				_put(pc, old)
			say("You take off the %s." % old.def["name"])
	wield.mods.append(modit)
	say("You fit the %s to the %s." % [modit.def["name"], wield.def["name"]])
	_clamp_mag()
	end_turn()
	end_turn()
	return true

func act_mod_remove(slot: String) -> bool:
	if gun_stats().is_empty():
		return false
	for old in wield.mods.duplicate():
		if GP.mod_slot(old) == slot:
			wield.mods.erase(old)
			if not stow(old):
				_put(pc, old)
				say("No room; it falls at your feet.")
			say("You remove the %s." % old.def["name"])
			_clamp_mag()
			end_turn()
			return true
	return false

## a loud noise: hostiles come to look, civilians flee
func _noise(cell: int, radius: int) -> void:
	for k in sim.near_list.size():
		var j: int = sim.near_list[k]
		if sim.alive[j] == 0 or astate[j] >= FLEEING:
			continue
		if cheb(sim.pos[j], cell) > radius:
			continue
		if fac[j] == CIV:
			_flee(j, 15)
		elif astate[j] == UNAWARE or astate[j] == RETURNING:
			astate[j] = SUSPICIOUS
			meter[j] = maxi(meter[j], 55)
			lastpos[j] = cell
			postc[j] = sim.pos[j]
			sim.ctl[j] = 1
			_face_toward(j, cell)

# ---------------------------------------------------------------- turns
func end_turn() -> void:
	turn += 1
	if not _in_ap:
		atk_debt = maxi(0, atk_debt - 100)
	moved = pc != last_pc and last_pc >= 0
	if moved:
		aim_turns = 0
	last_pc = pc
	if not ran_this_turn:
		stamina = mini(STAMINA_MAX, stamina + (1 if moved else 2))
		if stance == RUNNING:
			stance = WALKING
			run_streak = 0
	sim.step(pc)
	transit.step()
	_ai()
	_bleed_tick()
	_critters_turn()
	_vehicles()
	eco.step()
	step_noise = 0
	ran_this_turn = false
	_jet_tick()
	_process_followers()
	if turn % 20 == 0 and heat > 0:
		heat -= 1
	if bless_left > 0:
		bless_left -= 1
	if drunk_left > 0:
		drunk_left -= 1
	_needs_tick()
	if turn % 12 == 0 and hp < hp_max and in_vehicle < 0:
		hp += 1
	if turn % 40 == 0:
		for l in BODY.LIMBS:                      # hurt limbs knit slowly; a disabled one needs a ripperdoc or a trauma patch
			if body.ok(l) and int(body.hp[l]) < int(body.mx[l]):
				body.heal(l, 1)
	_compute_fov()
	if hp <= 0 and not game_over:
		game_over = true
		say("You are dead.  Press [n] for a new life.")

func _build_pf() -> void:
	for c in pf_touched:
		pf[c] = FF.UNREACHED
	pf_touched.clear()
	var q := PackedInt32Array([pc])
	pf[pc] = 0
	pf_touched.append(pc)
	var head := 0
	while head < q.size():
		var cur := q[head]
		head += 1
		var dd: int = pf[cur] + 1
		if dd > 40:
			continue
		var cx := cur % size
		for nb in [cur - 1 if cx > 0 else -1, cur + 1 if cx < size - 1 else -1, cur - size, cur + size if cur + size < total else -1]:
			if nb >= 0 and pf[nb] > dd and (sim.walk[nb] == 1 or nb == pc):
				pf[nb] = dd
				pf_touched.append(nb)
				q.append(nb)

func _step_to(i: int, target: int) -> bool:
	var c: int = sim.pos[i]
	var bx := target % size
	var by := target / size
	var best := -1
	var bv: float = Vector2(c % size - bx, c / size - by).length() + 0.01
	for d in SIZE_DIRS:
		var nx: int = c % size + d[0]
		var ny: int = c / size + d[1]
		if not in_bounds(nx, ny):
			continue
		var nc := ny * size + nx
		if sim.walk[nc] == 0 or sim.at[nc] != -1 or nc == pc:
			continue
		var v := Vector2(nx - bx, ny - by).length()
		if v < bv:
			bv = v
			best = nc
	if best >= 0:
		_move_agent(i, best)
		return true
	return false

func _move_agent(i: int, to: int) -> void:
	sim.at[sim.pos[i]] = -1
	sim.at[to] = i
	sim.pos[i] = to

func _step_field(i: int) -> bool:
	var c: int = sim.pos[i]
	var best := -1
	var bv: int = pf[c]
	for nb in [c - 1, c + 1, c - size, c + size]:
		if nb < 0 or nb >= total:
			continue
		if pf[nb] < bv and sim.walk[nb] == 1 and sim.at[nb] == -1 and nb != pc:
			bv = pf[nb]
			best = nb
	if best >= 0:
		_move_agent(i, best)
		return true
	return false

func _step_away(i: int) -> bool:
	var c: int = sim.pos[i]
	var best := -1
	var bv := cheb(c, pc)
	for d in SIZE_DIRS:
		var nx: int = c % size + d[0]
		var ny: int = c / size + d[1]
		if not in_bounds(nx, ny):
			continue
		var nc := ny * size + nx
		if sim.walk[nc] == 0 or sim.at[nc] != -1 or nc == pc:
			continue
		var v := cheb(nc, pc)
		if v > bv:
			bv = v
			best = nc
	if best >= 0:
		_move_agent(i, best)
		return true
	return false

func _stance_mult() -> float:
	var m := 1.0
	if stance == CRAWL:
		m = 0.4
	elif stance == CROUCH:
		m = 0.65
	elif stance == RUNNING:
		m = 1.5
	if in_vehicle >= 0:
		m = 1.3
	return m

func _ai() -> void:
	var any_hunter := false
	var list: Array = Array(sim.near_list)
	for i in list:
		if sim.alive[i] == 0:
			continue
		var st := astate[i]
		var d := cheb(sim.pos[i], pc)
		if cool[i] > 0:
			cool[i] -= 1
		# which way they look: where they last walked; the unaware idle ones glance around now and then
		var cp: int = sim.pos[i]
		if cp != prevpos[i]:
			var mdx: int = signi(cp % size - prevpos[i] % size)
			var mdy: int = signi(cp / size - prevpos[i] / size)
			if absi(cp - prevpos[i]) < 4 * size and (mdx != 0 or mdy != 0):
				face[i] = DIR8.find([mdx, mdy])
			prevpos[i] = cp
		elif st == UNAWARE and (turn + i) % 7 == 0:
			face[i] = (int(face[i]) + (1 if rng.randf() < 0.5 else 7) + (0 if rng.randf() < 0.6 else (1 if rng.randf() < 0.5 else 7))) % 8
		if stun[i] > 0:
			stun[i] -= 1
			sim.ctl[i] = 1
			continue
		# who is worth watching: armed or hostile factions, or anyone already worked up
		var capable := fac[i] == BRATVA or fac[i] == GANG or fac[i] == NAP or (fac[i] == NASIM and noticed_you[i] == 1)
		if st == UNAWARE and (not capable or d > 24 or not hostile(i)):
			continue
		if st == UNAWARE or st == SUSPICIOUS or st == SEARCHING or st == RETURNING:
			_notice(i, d)
			st = astate[i]
		match st:
			SUSPICIOUS:
				if not _step_to(i, lastpos[i]) or cheb(sim.pos[i], lastpos[i]) <= 1:
					astate[i] = SEARCHING
					timer[i] = 25
			SEARCHING:
				timer[i] -= 1
				var dir: Array = SIZE_DIRS[rng.randi() % 8]
				var nx: int = sim.pos[i] % size + dir[0]
				var ny: int = sim.pos[i] / size + dir[1]
				if in_bounds(nx, ny):
					var nc := ny * size + nx
					if sim.walk[nc] == 1 and sim.at[nc] == -1 and nc != pc:
						_move_agent(i, nc)
				if timer[i] <= 0:
					astate[i] = RETURNING
					timer[i] = 40
			RETURNING:
				timer[i] -= 1
				if cheb(sim.pos[i], postc[i]) <= 2 or timer[i] <= 0 or not _step_to(i, postc[i]):
					astate[i] = UNAWARE
					meter[i] = 0
					sim.ctl[i] = 0
			HUNTING:
				any_hunter = true
				_hunt(i, d)
			FLEEING:
				timer[i] -= 1
				if not _step_away(i) and hpn[i] * 4 < hpmax[i] and fac[i] != CIV:
					astate[i] = SURRENDERED
					say("%s drops their weapon and raises their hands." % name_of(i))
					gunc[i] = 0
				if timer[i] <= 0 and astate[i] == FLEEING:
					astate[i] = UNAWARE
					sim.ctl[i] = 0
			SURRENDERED:
				pass
	if any_hunter:
		pass

func _notice(i: int, d: int) -> void:
	var c: int = sim.pos[i]
	var st := astate[i]
	var los: bool = d <= 16 and fov.around[c] == 1 and sim._sees(c, pc, 16)
	var cf: float = cone_factor(i, pc, st != UNAWARE) if los else 0.0
	var sees: bool = cf > 0.0
	var heard: bool = step_noise > 0 and d <= step_noise and z_of(c) == z_of(pc)
	if sees:
		var gain := 45.0 / (1.0 + d / 6.0) * _stance_mult() * cf
		if st != UNAWARE:
			gain *= 1.5
		if d <= 1:
			gain = 100.0 * cf
		meter[i] = mini(100, meter[i] + maxi(1, int(gain)))
		lastpos[i] = pc
		if st == UNAWARE or st == RETURNING:
			postc[i] = c if st == UNAWARE else postc[i]
		if meter[i] >= 100 and fac[i] == NAP and not hostile(i):
			if st != HUNTING:
				heat = mini(100, heat + 10)
				meter[i] = 60
				astate[i] = SUSPICIOUS
				say_if_seen(c, "%s: \"Weapons down, citizen!\"" % name_of(i))
		elif meter[i] >= 100:
			if st != HUNTING:
				astate[i] = HUNTING
				sim.ctl[i] = 1
				noticed_you[i] = 1
				if sees_cell(c):
					say("%s spots you!" % name_of(i))
				_alarm(i)
		elif st == UNAWARE and meter[i] >= 25:
			astate[i] = SUSPICIOUS
			sim.ctl[i] = 1
			postc[i] = c
			if sees_cell(c):
				say("%s notices something." % name_of(i))
	elif heard:
		meter[i] = mini(99, meter[i] + (16 if stance == RUNNING else 9))
		lastpos[i] = pc
		_face_toward(i, pc)
		if st == UNAWARE and meter[i] >= 25:
			astate[i] = SUSPICIOUS
			sim.ctl[i] = 1
			postc[i] = c
			if sees_cell(c):
				say("%s hears something and turns." % name_of(i))
	else:
		if st == UNAWARE:
			meter[i] = maxi(0, meter[i] - 6)
		elif st == SUSPICIOUS:
			meter[i] -= 3
			if meter[i] <= 5:
				astate[i] = RETURNING
				timer[i] = 40
		elif st == RETURNING:
			pass

func _hunt(i: int, d: int) -> void:
	var c: int = sim.pos[i]
	var sees: bool = d <= 18 and fov.around[c] == 1 and sim._sees(c, pc, 20)
	if hpn[i] * 4 < hpmax[i]:
		if rng.randf() < 0.6:
			_flee(i, 30)
			return
	if not sees:
		meter[i] -= 4
		if meter[i] < 40:
			astate[i] = SEARCHING
			timer[i] = 30
			say_if_seen(c, "%s loses sight of you." % name_of(i))
			return
	else:
		lastpos[i] = pc
		meter[i] = 100
	var g := gunc[i]
	if g > 0 and sees and cool[i] == 0 and d >= 2 and d <= (8 if g == 1 else 14):
		cool[i] = 2
		var stance_pen: int = [18, 10, 0, 6][stance]
		var chance := clampi(62 + 2 * (npc_lvl(i, "ranged") - 3) - 4 * maxi(0, d - 2) - stance_pen - (15 if in_vehicle >= 0 else 0) - cover_vs(c, pc, crouch), 8, 85)
		if rng.randi() % 100 < chance:
			if rng.randi() % 100 < player_bullet_dodge():
				say("You twist aside and the round cracks past!")
				skill_up("dodge", 5)
			else:
				var dmg := rng.randi_range(5, 9) if g == 1 else rng.randi_range(6, 11)
				player_hurt(dmg, "%s shoots you" % name_of(i), "phys", "", 1 if fac[i] == NAP else 0)
		else:
			say_if_seen(c, "%s shoots at you and misses." % name_of(i))
		_noise(c, 14)
		return
	if d <= 1:
		var nm: Dictionary = npc_melee_stats(i)
		var hit_c: int = 60 + int(nm.get("acc", 0)) / 2 + 3 * (npc_lvl(i, "melee" if not nm.is_empty() else "unarmed") - 3)
		if rng.randi() % 100 < hit_c:
			if rng.randi() % 100 < player_melee_dodge():
				say("You slip %s's blow." % name_of(i))
				skill_up("dodge", 2 + npc_lvl(i, "melee") / 2)
				_melee_arts_on_miss(i, "dodge")
			elif rng.randi() % 100 < parry_chance(nm):
				say("You turn %s's blow aside." % name_of(i))
				_melee_arts_on_miss(i, "parry")
			else:
				var dm: int = rng.randi_range(3, 7)
				var what := "hits you"
				if not nm.is_empty():
					dm = rng.randi_range(int(nm["dmg"][0]), int(nm["dmg"][1])) * 7 / 10
					what = "%ss you" % nm.get("verb", "hit")
				player_hurt(dm, "%s %s" % [name_of(i), what], "phys", "", int(nm.get("pen", 1 if int(nm.get("dmg", [0, 0])[1]) >= 14 else 0)))
		else:
			say("%s swings and misses." % name_of(i))
		return
	if not _step_field(i):
		_step_to(i, pc)

func say_if_seen(cell: int, msg: String) -> void:
	if sees_cell(cell):
		say(msg)

# ---------------------------------------------------------------- things and animals: whatever the floor acts on
## Loose props (crates, tables, chairs) can be pushed; animals (dogs, cats) wander, flee, bark and bite.  Anything shoved off an edge falls.
const THING_WEIGHT := {"chair": 1, "crate": 2, "table": 3}
const THING_HP := {"chair": 6, "crate": 12, "table": 20}

func thing_name(ti: int) -> String:
	return things[ti]["k"]

func _spawn_things() -> void:
	for m in city.movables:
		var cell: int = m[0]
		if thing_at[cell] != -1 or sim.at[cell] != -1 or veh_at[cell] != -1 or sim.walk[cell] == 0:
			continue
		_add_thing(String(m[1]), cell, rng.randf() < 0.5)

func _add_thing(kind: String, cell: int, loot: bool) -> int:
	things.append({"k": kind, "cell": cell, "hp": THING_HP[kind], "loot": loot and kind == "crate"})
	thing_at[cell] = things.size() - 1
	sim.walk[cell] = 0
	return things.size() - 1

func _remove_thing(ti: int) -> void:
	var t: Dictionary = things[ti]
	var cell: int = t["cell"]
	if thing_at[cell] == ti:
		thing_at[cell] = -1
		sim.walk[cell] = 1 if city.walkable(city.tiles[cell]) and veh_at[cell] == -1 else 0
	t["k"] = ""

## a thing is wrecked: crates spill what they held
func smash_thing(ti: int, why: String) -> void:
	var t: Dictionary = things[ti]
	var cell: int = t["cell"]
	var kind: String = t["k"]
	if kind == "":
		return
	say_if_seen(cell, "The %s %s." % [kind, why])
	if t["loot"]:
		var roll := rng.randf()
		if roll < 0.35:
			_put(cell, _new_item("trl_yen", rng.randi_range(30, 200)))
		elif roll < 0.6:
			_put(cell, _new_item(_random_ammo(), 1))
		elif roll < 0.8:
			_put(cell, _new_item("trl_yen", rng.randi_range(10, 80)))
		else:
			_put(cell, _new_item(_random_mod()))
	_remove_thing(ti)
	_noise_gentle(cell, 7)

func _thing_open(c: int) -> bool:
	return sim.walk[c] == 1 and sim.at[c] == -1 and veh_at[c] == -1 and thing_at[c] == -1 and crit_at[c] == -1 and c != pc

func _move_thing(ti: int, to: int) -> void:
	var t: Dictionary = things[ti]
	var from: int = t["cell"]
	thing_at[from] = -1
	sim.walk[from] = 1 if city.walkable(city.tiles[from]) and veh_at[from] == -1 and crit_at[from] == -1 else 0
	t["cell"] = to
	thing_at[to] = ti
	sim.walk[to] = 0

## it goes into open air and drops: smashed from two floors up (a chair from one)
func fall_thing(ti: int, over: int) -> void:
	var t: Dictionary = things[ti]
	var kind: String = t["k"]
	var lc: Array = land_cell(over)
	var levels: int = lc[1]
	_remove_thing(ti)
	say_if_seen(over, "The %s tumbles over the edge." % kind)
	var new_ti: int = _add_thing(kind, lc[0], t["loot"])
	things[new_ti]["hp"] = t["hp"]
	if levels >= 2 or (kind == "chair" and levels >= 1):
		smash_thing(new_ti, "smashes on landing")
	else:
		_noise_gentle(lc[0], 6)

## push the thing at c one cell along (dx, dy).  Light things go over low rails.  true if it moved.
func push_thing(ti: int, dx: int, dy: int) -> bool:
	var t: Dictionary = things[ti]
	var c: int = t["cell"]
	var nx: int = c % size + dx
	var ny: int = c / size + dy
	if not in_bounds(nx, ny):
		return false
	var n1: int = ny * size + nx
	if z_of(n1) != z_of(c):
		return false
	var w: int = THING_WEIGHT[t["k"]]
	if city.tiles[n1] == CG.AIR and z_of(c) > 0:
		fall_thing(ti, n1)
		return true
	if _thing_open(n1):
		_move_thing(ti, n1)
		return true
	if (city.tiles[n1] in CG.LOW_COVER) and w <= 2 and thing_at[n1] == -1:
		var n2x: int = nx + dx
		var n2y: int = ny + dy
		if in_bounds(n2x, n2y):
			var n2: int = n2y * size + n2x
			if z_of(n2) == z_of(c):
				if city.tiles[n2] == CG.AIR and z_of(c) > 0:
					fall_thing(ti, n2)
					return true
				if _thing_open(n2):
					_move_thing(ti, n2)
					return true
	return false

## the player walks into a thing: push it, or it won't budge
func _bump_thing(c: int, dx: int, dy: int) -> bool:
	var ti: int = thing_at[c]
	var kind: String = things[ti]["k"]
	if not push_thing(ti, dx, dy):
		say("The %s won't budge." % kind)
		return false
	facing = Vector2i(dx, dy)
	pc = c
	step_noise = maxi(step_noise, 4)
	ran_this_turn = false
	end_turn()
	skill_up("manual", THING_WEIGHT.get(kind, 1))
	if THING_WEIGHT.get(kind, 1) >= 3 and not game_over and lvl("manual") < 3:
		end_turn()                       # a table takes a heave (a practised hauler does not need the extra turn)
	return true

func thing_hit(ti: int, dmg: int) -> void:
	var t: Dictionary = things[ti]
	t["hp"] -= dmg
	if t["hp"] <= 0:
		smash_thing(ti, "splinters")
	else:
		say("You batter the %s." % t["k"])
		_noise_gentle(t["cell"], 5)

## a soft noise: only the armed and the hostile come to look; nobody panics
func _noise_gentle(cell: int, radius: int) -> void:
	for k in sim.near_list.size():
		var j: int = sim.near_list[k]
		if sim.alive[j] == 0 or fac[j] == CIV or astate[j] != UNAWARE:
			continue
		if cheb(sim.pos[j], cell) > radius:
			continue
		meter[j] = maxi(meter[j], 30)
		astate[j] = SUSPICIOUS
		lastpos[j] = cell
		postc[j] = sim.pos[j]
		sim.ctl[j] = 1
		_face_toward(j, cell)

# ---- animals
func _spawn_critters() -> void:
	var tries := 0
	var want := 70 if (island == null or zone == island.CITY_ZONE) else 24
	while critters.size() < want and tries < 4000:
		tries += 1
		var c: int = rng.randi() % s2
		var k: String = "dog" if rng.randf() < 0.45 else "cat"
		var t: int = city.tiles[c]
		if t != CG.GROUND and t != CG.PARK and t != CG.FLOOR and t != CG.ROAD:
			continue
		if sim.walk[c] == 0 or sim.at[c] != -1 or veh_at[c] != -1 or thing_at[c] != -1 or crit_at[c] != -1:
			continue
		if t == CG.ROAD and rng.randf() < 0.7:
			continue
		_add_critter(k, c)
	# some cats up in the towers' shops and offices
	for t in city.tower_info:
		if rng.randf() < 0.5:
			var base: int = city.lvl_of_z(1 + rng.randi() % 2) * s2
			for _n in 20:
				var c2: int = base + rng.randi_range(int(t["y0"]) + 2, int(t["y1"]) - 2) * size + rng.randi_range(int(t["x0"]) + 2, int(t["x1"]) - 2)
				if city.tiles[c2] == CG.FLOOR and sim.walk[c2] == 1 and sim.at[c2] == -1 and thing_at[c2] == -1 and crit_at[c2] == -1:
					_add_critter("cat", c2)
					break

func _add_critter(kind: String, cell: int) -> int:
	critters.append({"k": kind, "cell": cell, "hp": 18 if kind == "dog" else 8, "mood": 0, "stun": 0, "face": 0})
	crit_at[cell] = critters.size() - 1
	sim.walk[cell] = 0
	return critters.size() - 1

func _crit_free(c: int) -> bool:
	return sim.walk[c] == 1 and sim.at[c] == -1 and veh_at[c] == -1 and thing_at[c] == -1 and crit_at[c] == -1 and c != pc

func _move_crit(ki: int, to: int) -> void:
	var k: Dictionary = critters[ki]
	var from: int = k["cell"]
	crit_at[from] = -1
	sim.walk[from] = 1 if city.walkable(city.tiles[from]) and veh_at[from] == -1 and thing_at[from] == -1 else 0
	k["cell"] = to
	var fi: int = DIR8.find([signi(to % size - from % size), signi(to / size - from / size)])
	if fi >= 0:
		k["face"] = fi
	crit_at[to] = ki
	sim.walk[to] = 0

func _kill_crit(ki: int, why: String) -> void:
	var k: Dictionary = critters[ki]
	if k["k"] == "":
		return
	say_if_seen(k["cell"], "The %s %s." % [k["k"], why])
	var cell: int = k["cell"]
	if crit_at[cell] == ki:
		crit_at[cell] = -1
		sim.walk[cell] = 1 if city.walkable(city.tiles[cell]) and veh_at[cell] == -1 and thing_at[cell] == -1 else 0
	k["k"] = ""

func fall_crit(ki: int, over: int) -> void:
	var k: Dictionary = critters[ki]
	var kind: String = k["k"]
	var lc: Array = land_cell(over)
	var levels: int = lc[1]
	var cell: int = k["cell"]
	if crit_at[cell] == ki:
		crit_at[cell] = -1
		sim.walk[cell] = 1 if city.walkable(city.tiles[cell]) and veh_at[cell] == -1 and thing_at[cell] == -1 else 0
	var dmg: int = levels * 5
	if kind == "cat":
		dmg = dmg / 4                    # cats land on their feet
	if levels > 0:
		say_if_seen(over, "The %s falls %d floor%s." % [kind, levels, "" if levels == 1 else "s"])
	k["hp"] -= dmg
	k["cell"] = lc[0]
	if k["hp"] <= 0:
		_kill_crit(ki, "does not survive the fall")
		return
	crit_at[lc[0]] = ki
	sim.walk[lc[0]] = 0
	k["stun"] = 3
	k["mood"] = 2 if kind == "cat" else 1

## push an animal one cell (it scrambles over rails too); over an edge it falls
func push_crit(ki: int, dx: int, dy: int) -> bool:
	var k: Dictionary = critters[ki]
	var c: int = k["cell"]
	var nx: int = c % size + dx
	var ny: int = c / size + dy
	if not in_bounds(nx, ny):
		return false
	var n1: int = ny * size + nx
	if z_of(n1) != z_of(c):
		return false
	if city.tiles[n1] == CG.AIR and z_of(c) > 0:
		fall_crit(ki, n1)
		return true
	if _crit_free(n1):
		_move_crit(ki, n1)
		return true
	if (city.tiles[n1] in CG.LOW_COVER) and thing_at[n1] == -1:
		var n2x: int = nx + dx
		var n2y: int = ny + dy
		if in_bounds(n2x, n2y):
			var n2: int = n2y * size + n2x
			if z_of(n2) == z_of(c):
				if city.tiles[n2] == CG.AIR and z_of(c) > 0:
					fall_crit(ki, n2)
					return true
				if _crit_free(n2):
					_move_crit(ki, n2)
					return true
	return false

func _bump_crit(c: int, dx: int, dy: int) -> bool:
	var ki: int = crit_at[c]
	var k: Dictionary = critters[ki]
	facing = Vector2i(dx, dy)
	if push_crit(ki, dx, dy):
		say("You nudge the %s along." % k["k"])
		pc = c
	else:
		# swap places
		var old: int = pc
		_move_crit(ki, old)
		pc = c
		say("You squeeze past the %s." % k["k"])
	k["stun"] = 0
	if k["mood"] == 0 and rng.randf() < (0.25 if k["k"] == "dog" else 0.5):
		k["mood"] = 2
	end_turn()
	return true

## hit an animal: a dog that survives turns on you, a cat bolts
func crit_hit(ki: int, dmg: int) -> void:
	var k: Dictionary = critters[ki]
	k["hp"] -= dmg
	_witness(k["cell"], 8, 3, -1)
	if k["hp"] <= 0:
		_kill_crit(ki, "dies")
		return
	say("You hit the %s (%d)." % [k["k"], dmg])
	k["mood"] = 1 if k["k"] == "dog" else 2
	k["stun"] = 0

## one turn of animal life, for those near the player on the same level
func _critters_turn() -> void:
	var lvl_base: int = (pc / s2) * s2
	for ki in critters.size():
		var k: Dictionary = critters[ki]
		if k["k"] == "":
			continue
		var c: int = k["cell"]
		if c / s2 != pc / s2 or cheb(c, pc) > 30:
			continue
		if k["stun"] > 0:
			k["stun"] -= 1
			continue
		var d: int = cheb(c, pc)
		var dog: bool = k["k"] == "dog"
		var mood: int = k["mood"]
		if mood == 1 and dog:                 # angry dog: closes and bites
			if d <= 1:
				if rng.randf() < 0.6:
					player_hurt(rng.randi_range(2, 5), "The dog bites you")
				if rng.randf() < 0.03:
					k["mood"] = 0
			else:
				_crit_step_toward(ki, pc)
			continue
		if mood == 2 or (not dog and d <= 3 and stance >= WALKING):
			if d <= 8:
				_crit_step_away(ki)
			if mood == 2 and rng.randf() < 0.08:
				k["mood"] = 0
			continue
		# calm: mooch about; dogs bark at a player who is not being careful
		if dog and d <= 7 and stance >= WALKING and rng.randf() < 0.05:
			say_if_seen(c, "A dog barks.")
			_noise_gentle(c, 10)
		if rng.randf() < 0.35:
			var dir: Array = SIZE_DIRS[rng.randi() % 8]
			var nx: int = c % size + dir[0]
			var ny: int = c / size + dir[1]
			if in_bounds(nx, ny) and z_of(ny * size + nx) == z_of(c) and _crit_free(ny * size + nx):
				_move_crit(ki, ny * size + nx)

func _crit_step_toward(ki: int, target: int) -> void:
	var c: int = critters[ki]["cell"]
	var best := -1
	var bd: int = cheb(c, target)
	for dir in SIZE_DIRS:
		var nx: int = c % size + dir[0]
		var ny: int = c / size + dir[1]
		if in_bounds(nx, ny) and z_of(ny * size + nx) == z_of(c):
			var nc: int = ny * size + nx
			if _crit_free(nc) and cheb(nc, target) < bd:
				bd = cheb(nc, target)
				best = nc
	if best >= 0:
		_move_crit(ki, best)

func _crit_step_away(ki: int) -> void:
	var c: int = critters[ki]["cell"]
	var best := -1
	var bd: int = cheb(c, pc)
	for dir in SIZE_DIRS:
		var nx: int = c % size + dir[0]
		var ny: int = c / size + dir[1]
		if in_bounds(nx, ny) and z_of(ny * size + nx) == z_of(c):
			var nc: int = ny * size + nx
			if _crit_free(nc) and cheb(nc, pc) > bd:
				bd = cheb(nc, pc)
				best = nc
	if best >= 0:
		_move_crit(ki, best)

# ---------------------------------------------------------------- moving between levels
## Falling, jump jets, leg actuators, stairs with pursuers, gyros and mechs.
func veh_kind(vi: int) -> String:
	return String(vehicles[vi].get("kind", "car"))

func in_mech() -> bool:
	return in_vehicle >= 0 and veh_kind(in_vehicle) == "mech"

func in_heli() -> bool:
	return in_vehicle >= 0 and veh_kind(in_vehicle) == "heli"

## fitted AND its limbs work (a disabled limb gives no bonuses)
func has_implant(id: String) -> bool:
	if not implants.get(id, false):
		return false
	return body.group_ok(body.group_of_part(String(IMP.get_def(id).get("part", "chest"))))

func airborne() -> bool:
	return flying or (in_vehicle >= 0 and bool(vehicles[in_vehicle].get("air", false)))

func _free_for_player(c: int) -> bool:
	return sim.walk[c] == 1 and sim.at[c] == -1 and veh_at[c] == -1 and thing_at[c] == -1 and crit_at[c] == -1 and c != pc

## where something dropped from `cell` ends up: [landing cell, levels fallen].  Air columns open above ground, roofs and floors; a landing spot that is solid or taken
## is replaced by the nearest free walkable cell on that level.
func land_cell(cell: int) -> Array:
	var cur: int = cell
	var levels := 0
	while z_of(cur) > 0 and city.tiles[cur] == CG.AIR:
		cur -= s2
		levels += 1
	if _free_for_player(cur):
		return [cur, levels]
	for r in range(1, 7):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var nx: int = cur % size + dx
				var ny: int = cur / size + dy
				if in_bounds(nx, ny) and z_of(ny * size + nx) == z_of(cur) and _free_for_player(ny * size + nx):
					return [ny * size + nx, levels]
	return [cur, levels]

## damage of a fall: 5 a floor (plus a little), halved by leg actuators, absent with jets that still have fuel, a third in water or sludge
func fall_damage(levels: int, soft: bool = false) -> int:
	if levels <= 0:
		return 0
	var d: int = levels * 5
	if has_implant("legs"):
		d /= 2
	if has_implant("jets") and fuel >= 3:
		d = 0
	if soft:
		d /= 3
	return d

func _fall_player(reason: String) -> void:
	var lc: Array = land_cell(pc)
	var levels: int = lc[1]
	var dmg := fall_damage(levels, city.tiles[lc[0]] == CG.WATER or city.tiles[lc[0]] == CG.SLUDGE)
	if dmg > 0:
		dmg += rng.randi_range(0, 3)
	flying = false
	pc = lc[0]
	if levels > 0:
		sfx("fall")
	if in_vehicle >= 0:
		_move_vehicle(in_vehicle, pc)
	say("%s  You fall %d floor%s." % [reason, levels, "" if levels == 1 else "s"])
	if has_implant("jets") and fuel >= 3 and levels > 0:
		say("Your jets flare and slow the drop.")
		fuel = maxi(0, fuel - 3)
	if dmg > 0:
		_limb_hit("l_leg", dmg * 3 / 4)           # landing is mostly legs, no armor helps
		_limb_hit("r_leg", dmg * 3 / 4)
		_limb_hit("chest", dmg / 4)
		hp -= dmg
		sfx("hurt")
		say("You hit the ground hard (-%d)." % dmg)
		_noise(pc, 6 + levels)
	sim.retier(pc)
	aim_turns = 0

## ---- jump jets
func _fly_ok_target(c: int) -> bool:
	return city.tiles[c] == CG.AIR and sim.at[c] == -1 and veh_at[c] == -1

func act_takeoff_or_climb() -> bool:
	return act_vertical(1)

## move one cell in the air (jets).  Anything that is not open air blocks you; a walkable cell at your own level lets you land.
func fly_move(dx: int, dy: int) -> bool:
	var nx: int = pc % size + dx
	var ny: int = pc / size + dy
	if not in_bounds(nx, ny):
		return false
	facing = Vector2i(dx, dy)
	var c: int = ny * size + nx
	if sim.at[c] >= 0:
		say("Someone is in the way.")
		return false
	if veh_at[c] != -1:
		return false
	if city.tiles[c] == CG.AIR or city.tiles[c] in CG.LOW_COVER:
		pc = c
		fuel -= 1
		step_noise = 6
		ran_this_turn = true
		end_turn()
		return true
	if sim.walk[c] == 1:
		pc = c
		flying = false
		say("You touch down.")
		end_turn()
		return true
	say("Something solid is in the way.")
	return false

## ---- stairs, ladders, elevators, jets, gyros: the vertical action
func _collect_followers(old_pc: int, new_pc: int) -> void:
	for k in sim.near_list.size():
		var i: int = sim.near_list[k]
		if followers.size() >= 4:
			break
		if sim.alive[i] == 0 or astate[i] != HUNTING or fac[i] == CIV:
			continue
		var d := cheb(sim.pos[i], old_pc)
		if d <= 5:
			followers.append({"i": i, "t": turn + 2 + d / 2, "cell": new_pc})

func _process_followers() -> void:
	var keep: Array = []
	for f in followers:
		var i: int = f["i"]
		if sim.alive[i] == 0 or astate[i] != HUNTING:
			continue
		if turn < int(f["t"]):
			keep.append(f)
			continue
		var cell: int = f["cell"]
		var best := -1
		for r in range(1, 5):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if best >= 0 or maxi(absi(dx), absi(dy)) != r:
						continue
					var nx: int = cell % size + dx
					var ny: int = cell / size + dy
					if in_bounds(nx, ny):
						var nc: int = ny * size + nx
						if z_of(nc) == z_of(cell) and sim.walk[nc] == 1 and sim.at[nc] == -1 and nc != pc and veh_at[nc] == -1:
							best = nc
		if best >= 0:
			sim.place(i, best)
			astate[i] = HUNTING
			sim.ctl[i] = 1
			meter[i] = 100
			lastpos[i] = pc
			say_if_seen(best, "%s comes after you." % name_of(i))
	followers = keep

func _vertical_cost_and_move(dest: int, steps: int, elevator: bool, kind_msg: String) -> void:
	var old: int = pc
	_collect_followers(old, dest)
	pc = dest
	if in_mech():
		_move_vehicle(in_vehicle, pc)
	say("%s %s to %s." % [kind_msg, "up" if z_of(dest) > z_of(old) else "down", zname(pc)])
	var tw := tower_at(pc)
	if z_of(pc) > 0 and not tw.is_empty():
		say("(%d of %d floors)" % [z_of(pc), tw["h"]])
	sim.retier(pc)
	end_turn()
	# stairs and ladders are slower than a step; an elevator costs a turn per two floors
	var extra: int = (steps / 2) if elevator else 1
	for _k in extra:
		if not game_over:
			end_turn()

func act_vertical(dir: int) -> bool:
	if transit.riding >= 0:
		return false
	if flying:
		return _jet_vertical(dir)
	if in_vehicle >= 0:
		if veh_kind(in_vehicle) in ["heli", "plane"]:
			return vs.vertical(dir)
		say("A %s is too big for stairs." % vs.KINDS[veh_kind(in_vehicle)]["name"])
		return false
	if not city.haslink[pc] == 1:
		if has_implant("jets") and z_of(pc) >= 0 and not in_mech():
			return _jet_vertical(dir)
		say("There is no way %s here." % ("up" if dir > 0 else "down"))
		return false
	var best := -1
	for nb in city.links[pc]:
		var z_to := z_of(nb)
		if (dir > 0 and z_to > z_of(pc)) or (dir < 0 and z_to < z_of(pc)):
			best = nb
	if best < 0:
		say("There is no way %s from here." % ("up" if dir > 0 else "down"))
		return false
	var elevator: bool = city.tiles[pc] == CG.ELEVATOR
	if sim.at[best] >= 0:
		say("Someone is in the way.")
		return false
	var steps := 1
	var cur := best
	if elevator:
		while steps < 3:
			var nxt := -1
			for nb in city.links[cur]:
				if (dir > 0 and z_of(nb) > z_of(cur)) or (dir < 0 and z_of(nb) < z_of(cur)):
					nxt = nb
			if nxt < 0 or sim.at[nxt] >= 0:
				break
			cur = nxt
			steps += 1
	var kind: String = "The elevator whirs" if elevator else ("You climb the stairs" if city.tiles[cur] == CG.STAIRS else "You climb the ladder")
	if not elevator and dir < 0:
		kind = kind.replace("climb", "descend") if "stairs" in kind else kind
	_vertical_cost_and_move(cur, steps, elevator, kind)
	return true

func _jet_vertical(dir: int) -> bool:
	if not has_implant("jets"):
		return false
	if dir > 0:
		var up: int = pc + s2
		if z_of(pc) < 0 or z_of(pc) >= city.zmax or not _fly_ok_target(up):
			say("Something solid is overhead." if z_of(pc) < city.zmax else "You can't climb higher.")
			return false
		if not flying and fuel < 4:
			say("The jets sputter; not enough fuel (%d)." % fuel)
			return false
		if fuel < 2:
			say("Out of fuel.")
			return false
		if not flying:
			say("The jets ignite and lift you.")
			flying = true
		pc = up
		fuel -= 2
		step_noise = 9
		ran_this_turn = true
		sim.retier(pc)
		end_turn()
		return true
	if not flying:
		say("You are on the ground.")
		return false
	var dn: int = pc - s2
	if z_of(pc) <= 0:
		flying = false
		return false
	if sim.at[dn] >= 0 or veh_at[dn] != -1:
		say("Someone is below you.")
		return false
	if city.tiles[dn] == CG.AIR:
		pc = dn
		sim.retier(pc)
		end_turn()
		return true
	if sim.walk[dn] == 1:
		pc = dn
		flying = false
		say("You touch down on %s." % zname(pc))
		sim.retier(pc)
		end_turn()
		return true
	say("Something solid is below you.")
	return false

func _jet_tick() -> void:
	if flying:
		fuel -= 1
		if fuel <= 0:
			fuel = 0
			_fall_player("The jets cough and die.")
	else:
		fuel = mini(FUEL_MAX, fuel + (2 if not moved else 1)) if has_implant("jets") else 0

# ---------------------------------------------------------------- people falling, shoved, knocked back
## extension point for per-unit abilities: a unit that can fly or leap overrides this (e.g. {"fly": true}); fly_units is set by whatever spawns such units
func unit_traits(i: int) -> Dictionary:
	return fly_units.get(i, {})

func _agent_open(c: int) -> bool:
	return sim.walk[c] == 1 and sim.at[c] == -1 and veh_at[c] == -1 and thing_at[c] == -1 and crit_at[c] == -1 and c != pc

## person i has gone over an edge into the air cell `over`: they fall to the floor below.  Damage is 5 a floor (plus 0-3); a long fall kills.
func fall_agent(i: int, over: int) -> void:
	if sim.alive[i] == 0:
		return
	var origin: int = sim.pos[i]
	var seen_origin: bool = sees_cell(origin) or cheb(origin, pc) < 14
	if unit_traits(i).get("fly", false):
		_move_agent(i, over)
		say_if_seen(over, "%s hovers over the drop." % name_of(i))
		return
	var lc: Array = land_cell(over)
	var levels: int = lc[1]
	var dmg: int = levels * 5 + (rng.randi_range(0, 3) if levels > 0 else 0)
	if city.tiles[lc[0]] == CG.WATER or city.tiles[lc[0]] == CG.SLUDGE:
		dmg /= 3
	if seen_origin:
		say("%s plunges %d floor%s." % [name_of(i), levels, "" if levels == 1 else "s"])
	sim.place(i, lc[0])
	hpn[i] -= dmg
	stun[i] = 4
	bleed[i] = 0
	if hpn[i] <= 0:
		kill(i)
		return
	if sim.near[i] == 1:
		sim.ctl[i] = 1
		_noise(lc[0], 5 + levels)
		if astate[i] == UNAWARE or astate[i] == RETURNING:
			astate[i] = SUSPICIOUS
			meter[i] = 60
			lastpos[i] = pc
			postc[i] = lc[0]
		say_if_seen(lc[0], "%s hits the ground hard (-%d)." % [name_of(i), dmg])
	else:
		# landed somewhere the abstract simulation looks after
		astate[i] = UNAWARE
		meter[i] = 0
		sim.ctl[i] = 0

## move person i one cell in a direction (or two, over a low rail or crate).  True if they went anywhere.  Walls hurt a little.
func push_agent(i: int, dx: int, dy: int) -> bool:
	var c: int = sim.pos[i]
	var nx: int = c % size + dx
	var ny: int = c / size + dy
	if not in_bounds(nx, ny):
		return false
	var n1: int = ny * size + nx
	if z_of(n1) != z_of(c):
		return false
	var t1: int = city.tiles[n1]
	if t1 == CG.AIR and z_of(c) > 0:
		fall_agent(i, n1)
		return true
	if _agent_open(n1):
		_move_agent(i, n1)
		face[i] = DIR8.find([dx, dy]) if DIR8.find([dx, dy]) >= 0 else face[i]
		return true
	if (t1 in CG.LOW_COVER) and sim.at[n1] == -1:
		var n2x: int = nx + dx
		var n2y: int = ny + dy
		if in_bounds(n2x, n2y):
			var n2: int = n2y * size + n2x
			if z_of(n2) == z_of(c):
				if city.tiles[n2] == CG.AIR and z_of(c) > 0:
					say_if_seen(c, "%s goes over the %s." % [name_of(i), "rail" if t1 == CG.RAILING else "barrier"])
					fall_agent(i, n2)
					return true
				if _agent_open(n2):
					_move_agent(i, n2)
					return true
	if t1 == CG.WALL or t1 == CG.EARTH:
		hpn[i] -= 3
		say_if_seen(c, "%s slams into the wall (-3)." % name_of(i))
		if hpn[i] <= 0:
			kill(i)
	return false

## shove whoever stands next to you in a direction
func act_shove(dx: int, dy: int) -> bool:
	if in_vehicle >= 0 and not in_mech():
		return false
	var nx: int = pc % size + dx
	var ny: int = pc / size + dy
	if not in_bounds(nx, ny):
		return false
	var c: int = ny * size + nx
	var who: int = sim.at[c]
	if who < 0 and crit_at[c] != -1:
		facing = Vector2i(dx, dy)
		var kc: Dictionary = critters[crit_at[c]]
		say("You shove the %s." % kc["k"])
		push_crit(crit_at[c], dx, dy)
		if kc["k"] != "":
			kc["mood"] = 2 if kc["k"] == "cat" else (1 if rng.randf() < 0.4 else 2)
		end_turn()
		return true
	if who < 0 and thing_at[c] != -1:
		facing = Vector2i(dx, dy)
		var tn: String = things[thing_at[c]]["k"]
		if push_thing(thing_at[c], dx, dy):
			say("You shove the %s." % tn)
		else:
			say("The %s won't budge." % tn)
		end_turn()
		return true
	if who < 0:
		say("There is nobody there to shove.")
		return false
	facing = Vector2i(dx, dy)
	_witness(pc, 10, 10, who)
	if rng.randi() % 100 < 88 - (10 if astate[who] == HUNTING else 0):
		say("You shove %s." % name_of(who))
		push_agent(who, dx, dy)
		if sim.alive[who] == 1:
			stun[who] = maxi(int(stun[who]), 1)
			sim.ctl[who] = 1
			_alert(who)
	else:
		say("%s braces against your shove." % name_of(who))
		_alert(who)
	end_turn()
	return true

## a hit that knocks the target back one cell, directly away from you
func _knock_back(i: int) -> void:
	var c: int = sim.pos[i]
	var dx: int = signi(c % size - pc % size)
	var dy: int = signi(c / size - pc / size)
	if dx == 0 and dy == 0:
		return
	if push_agent(i, dx, dy) and sim.alive[i] == 1:
		say_if_seen(sim.pos[i], "%s is thrown back." % name_of(i))

# ---------------------------------------------------------------- vehicles (the work is in vehicles.gd)
func vehicle_near() -> int:
	return vs.near_vehicle()

func act_vehicle() -> bool:
	return vs.interact()

## put a vehicle's seat on `to`, keeping its heading (used when something else moves it, e.g. a fall)
func _move_vehicle(vi: int, to: int) -> void:
	vs.put(vi, to, int(vehicles[vi]["dir"]))

func _vehicles() -> void:
	vs.ai_turn()

## where the player is on the whole island
func global_pos(cell: int = -1) -> Vector2i:
	var c: int = pc if cell < 0 else cell
	var o: Vector2i = island.zone_origin(zone.x, zone.y) if island != null else Vector2i.ZERO
	return Vector2i(o.x + c % size, o.y + (c % s2) / size)

## the terrain beyond the edge of this zone's map (for drawing), or -1 on a stand-alone city
func outside_tile(x: int, y: int) -> int:
	if island == null:
		return -1
	var o: Vector2i = island.zone_origin(zone.x, zone.y)
	return island.terrain(o.x + x, o.y + y)

## everything about the player that travels between zones
func player_dict() -> Dictionary:
	return {"hp": hp, "hp_max": hp_max, "yen": yen, "heat": heat, "implants": implants.duplicate(), "fuel": fuel, "ammo": ammo_pool.duplicate(), "want_kind": want_kind.duplicate(),
		"attrs": attrs.duplicate(), "skills": skills.duplicate(), "xp": xp.duplicate(), "worn": worn.map(func(x): return x.to_dict()), "wield": (wield.to_dict() if wield != null else null),
		"stamina": stamina, "stance": stance, "turn": turn, "tick": sim.tick, "bless": bless_left, "drunk": drunk_left, "ate": last_ate, "drank": last_drank, "eco": eco.save(), "flying": flying,
		"body": body.to_dict(), "armor_worn": armor_worn.map(func(x): return x.to_dict()), "imp_dur": imp_dur.duplicate(), "arts": melee_arts.duplicate()}

## attributes, skills and XP from a save; saves from before the attribute system (or with the old skill names) keep what still exists and start the rest at the defaults
func _load_skills(d: Dictionary) -> void:
	attrs = SK.default_attrs()
	skills = SK.default_skills()
	xp = SK.default_skills()
	for k in d.get("attrs", {}):
		if attrs.has(k):
			attrs[k] = int(d["attrs"][k])
	for k in d.get("skills", {}):
		if skills.has(k):
			skills[k] = int(d["skills"][k])
	for k in d.get("xp", {}):
		if xp.has(k):
			xp[k] = int(d["xp"][k])

func _load_body(d: Dictionary) -> void:
	body = BODY.new()
	if d.has("body"):
		body.from_dict(d["body"])
	armor_worn = []
	for x in d.get("armor_worn", []):
		armor_worn.append(ItemScript.from_dict(x, db))
	imp_dur = {}
	for k in d.get("imp_dur", {}):
		imp_dur[k] = int(d["imp_dur"][k])
	melee_arts = []
	for a in d.get("arts", []):
		melee_arts.append(String(a))
	atk_debt = 0
	aim_frac = 0.0

func apply_player(d: Dictionary) -> void:
	hp = int(d["hp"])
	hp_max = int(d["hp_max"])
	yen = int(d["yen"])
	heat = int(d["heat"])
	implants = d["implants"]
	fuel = int(d["fuel"])
	ammo_pool = d["ammo"]
	want_kind = d["want_kind"]
	_load_skills(d)
	worn = []
	for x in d["worn"]:
		worn.append(ItemScript.from_dict(x, db))
	wield = ItemScript.from_dict(d["wield"], db) if d["wield"] != null else null
	stamina = int(d["stamina"])
	bless_left = int(d.get("bless", 0))
	drunk_left = int(d.get("drunk", 0))
	last_ate = int(d.get("ate", int(d.get("tick", 0))))
	last_drank = int(d.get("drank", int(d.get("tick", 0))))
	stance = int(d["stance"])
	turn = int(d["turn"])
	sim.tick = int(d["tick"])
	_was_hungry = hungry()
	_was_thirsty = thirsty()
	eco.load_from(JSON.parse_string(JSON.stringify(d["eco"])))
	eco.job = {}
	flying = bool(d.get("flying", false))
	followers = []
	_load_body(d)

## the player has walked or driven off the edge of the zone (a stub until zones exist)
func zone_cross(_dx: int, _dy: int) -> bool:
	return false

# ---------------------------------------------------------------- save / load
func save_dict() -> Dictionary:
	var it_at := {}
	for c in items_at:
		var arr := []
		for it in items_at[c]:
			arr.append(it.to_dict())
		it_at[str(c)] = arr
	var vlist := []
	for v in vehicles:
		vlist.append(vs.to_dict(v))
	return {"seed": seed_value, "island": (island.seed_value if island != null else -1), "zone": [zone.x, zone.y], "people": sim.n, "turn": turn, "pc": pc, "hp": hp, "yen": yen, "heat": heat, "things": things.filter(func(t): return t["k"] != ""), "critters": critters.filter(func(k): return k["k"] != ""), "implants": implants, "fuel": fuel, "flying": flying, "ammo": ammo_pool, "want_kind": want_kind, "skills": skills, "attrs": attrs, "xp": xp, "in_vehicle": in_vehicle,
			"body": body.to_dict(), "armor_worn": armor_worn.map(func(x): return x.to_dict()), "imp_dur": imp_dur.duplicate(), "arts": melee_arts.duplicate(),
			"rng_state": str(rng.state), "transit": transit.save(), "eco": eco.save(), "worn": worn.map(func(x): return x.to_dict()), "wield": (wield.to_dict() if wield != null else null),
			"items_at": it_at, "vehicles": vlist, "tick": sim.tick, "ate": last_ate, "drank": last_drank, "log": log.slice(-30),
			"npc": {"pos": Array(sim.pos), "dest": Array(sim.dest), "goal": Array(sim.goal), "near": Array(sim.near), "alive": Array(sim.alive), "depart": Array(sim.depart), "arrive": Array(sim.arrive),
					"hp": Array(hpn), "state": Array(astate), "meter": Array(meter), "timer": Array(timer), "last": Array(lastpos), "post": Array(postc), "yen": Array(yenn), "gun": Array(gunc),
					"mdis": Array(mdis), "noticed": Array(noticed_you), "ctl": Array(sim.ctl), "idle": Array(sim.idle)}}

func load_dict(d: Dictionary) -> void:
	seed_value = int(d["seed"])
	var isl_seed: int = int(d.get("island", -1))
	if isl_seed >= 0:
		var isl = island if (island != null and island.seed_value == isl_seed) else ISL.new(isl_seed)
		setup(int(d.get("people", 0)), isl, Vector2i(int(d["zone"][0]), int(d["zone"][1])))
	else:
		setup(int(d.get("people", sim.n if sim != null else 1500)))             # regenerates the deterministic parts (map, markers, names, factions)
	turn = int(d["turn"])
	pc = int(d["pc"])
	hp = int(d["hp"])
	yen = int(d["yen"])
	heat = int(d["heat"])
	ammo_pool = {}
	for k in d["ammo"]:
		ammo_pool[k] = int(d["ammo"][k])
	want_kind = d.get("want_kind", {})
	aim_turns = 0
	aim_target = -1
	_set_stance(WALKING)
	stamina = STAMINA_MAX
	implants = d.get("implants", {})
	fuel = int(d.get("fuel", FUEL_MAX))
	flying = bool(d.get("flying", false))
	followers = []
	_load_skills(d)
	in_vehicle = int(d["in_vehicle"])
	_load_body(d)
	rng.state = int(d["rng_state"])
	worn = []
	for x in d["worn"]:
		worn.append(ItemScript.from_dict(x, db))
	wield = ItemScript.from_dict(d["wield"], db) if d["wield"] != null else null
	items_at = {}
	for k in d["items_at"]:
		var arr := []
		for x in d["items_at"][k]:
			arr.append(ItemScript.from_dict(x, db))
		items_at[int(k)] = arr
	# vehicles: undo the freshly generated ones, then restore
	for vi0 in vehicles.size():
		vs.lift(vi0)
	veh_at.fill(-1)
	vehicles = []
	for v in d["vehicles"]:
		var o: Dictionary = vs.from_dict(v)
		vehicles.append(o)
		for c in vs.cells(o):
			veh_at[c] = vehicles.size() - 1
			sim.walk[c] = 0
	# things and animals: undo the fresh ones, restore the saved
	for t0 in things:
		if t0["k"] != "":
			sim.walk[t0["cell"]] = 1 if city.walkable(city.tiles[t0["cell"]]) else 0
	for k0 in critters:
		if k0["k"] != "":
			sim.walk[k0["cell"]] = 1 if city.walkable(city.tiles[k0["cell"]]) else 0
	thing_at.fill(-1)
	crit_at.fill(-1)
	things = []
	critters = []
	for t in d.get("things", []):
		var ti: int = _add_thing(String(t["k"]), int(t["cell"]), bool(t["loot"]))
		things[ti]["hp"] = int(t["hp"])
	for k in d.get("critters", []):
		var ki: int = _add_critter(String(k["k"]), int(k["cell"]))
		for f in ["hp", "mood", "stun"]:
			critters[ki][f] = int(k[f])
	sim.tick = int(d["tick"])
	last_ate = int(d.get("ate", sim.tick))
	last_drank = int(d.get("drank", sim.tick))
	_was_hungry = hungry()
	_was_thirsty = thirsty()
	transit.load_from(d["transit"])
	eco.load_from(d["eco"])
	var nn: Dictionary = d["npc"]
	# rebuild the agent structures from the saved arrays
	sim.near_list = PackedInt32Array()
	sim.at.fill(-1)
	sim.buckets.clear()
	for i in sim.n:
		sim.pos[i] = int(nn["pos"][i])
		sim.dest[i] = int(nn["dest"][i])
		sim.goal[i] = int(nn["goal"][i])
		sim.alive[i] = int(nn["alive"][i])
		sim.depart[i] = int(nn["depart"][i])
		sim.arrive[i] = int(nn["arrive"][i])
		sim.ctl[i] = int(nn["ctl"][i])
		sim.idle[i] = int(nn["idle"][i])
		sim.near[i] = int(nn["near"][i])
		sim.near_slot[i] = -1
		hpn[i] = int(nn["hp"][i])
		astate[i] = int(nn["state"][i])
		meter[i] = int(nn["meter"][i])
		timer[i] = int(nn["timer"][i])
		lastpos[i] = int(nn["last"][i])
		postc[i] = int(nn["post"][i])
		yenn[i] = int(nn["yen"][i])
		gunc[i] = int(nn["gun"][i])
		noticed_you[i] = int(nn["noticed"][i])
		mdis[i] = int(nn["mdis"][i]) if nn.has("mdis") else 0
		if sim.alive[i] == 1:
			if sim.near[i] == 1:
				sim.near_slot[i] = sim.near_list.size()
				sim.near_list.append(i)
				sim.at[sim.pos[i]] = i
			elif sim.arrive[i] >= 0:
				sim._bucket(sim.arrive[i], i)
	log = []
	for l in d["log"]:
		log.append(str(l))
	_compute_fov()
