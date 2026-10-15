extends RefCounted
## The playable slice: one city, one player, roughly two thousand people, awareness-driven hostiles, theft, shooting, pockets and cars.
## All rules live here and run headless; main.gd and view.gd only draw it and feed it keys.
const CG = preload("res://src/citygen.gd")
const SIM = preload("res://src/npc_sim.gd")
const FF = preload("res://src/flowfield.gd")
const ItemScript = preload("res://src/item.gd")
const DB = preload("res://src/item_db.gd")
const FOV = preload("res://src/fov.gd")
const LV = preload("res://src/levels.gd")
const TR = preload("res://src/transit.gd")
const EC = preload("res://src/economy.gd")
const GP = preload("res://src/gunplay.gd")

const UNAWARE := 0
const CRAWL := 0
const CROUCH := 1
const WALKING := 2
const RUNNING := 3
const STAMINA_MAX := 30
const DIR8 := [[0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1]]   # in a ring, so a turn is +-1
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
const FAC_NAMES := ["resident", "Bratva thug", "NAP officer", "Nasim runner"]
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
var step_noise: int = 0                        # how far this turn's footsteps carry
var skills := {"melee": 2, "ranged": 2, "stealth": 2, "theft": 1}
var xp := {"melee": 0, "ranged": 0, "stealth": 0, "theft": 0}
var worn: Array = []
var wield = null
var in_vehicle: int = -1
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

func say(msg: String) -> void:
	log.append(msg)
	if log.size() > 200:
		log = log.slice(100)

func setup(n_people: int = 1200) -> void:
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
	fov = FOV.new()
	fov.setup(size, sim.opaque)
	pf = PackedInt32Array(); pf.resize(total); pf.fill(FF.UNREACHED)
	veh_at = PackedInt32Array(); veh_at.resize(total); veh_at.fill(-1)
	_people()
	_roads_and_cars()
	_loot()
	_vault_loot()
	_start_player()
	transit = TR.new()
	transit.setup(self)
	eco = EC.new()
	eco.setup(self)
	fov.compute(pc % size, pc / size, 18)
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
		hpmax[i] = [25, 40, 45, 30][f]
		hpn[i] = hpmax[i]
		yenn[i] = rng.randi_range(5, 90) if f == CIV else rng.randi_range(40, 260)
		fem[i] = 1 if rng.randf() < 0.5 else 0
		nname[i] = FIRST[rng.randi() % FIRST.size()]
		if f == BRATVA:
			gunc[i] = 1 if rng.randf() < 0.45 else 0
		elif f == NAP:
			gunc[i] = 1 if rng.randf() < 0.8 else 2
		elif f == NASIM:
			gunc[i] = 1 if rng.randf() < 0.2 else 0

func _roads_and_cars() -> void:
	road_walk = PackedByteArray(); road_walk.resize(size * size)
	var road_cells := PackedInt32Array()
	for i in size * size:
		if city.tiles[i] == CG.ROAD:
			road_walk[i] = 1
			road_cells.append(i)
	waypoints = PackedInt32Array()
	for k in 8:
		waypoints.append(road_cells[(road_cells.size() * (2 * k + 1)) / 16])
	for w in waypoints:
		way_fields.append(FF.build(city.tiles, size, road_walk, PackedInt32Array([w])))
	for k in 30:
		var c := road_cells[rng.randi() % road_cells.size()]
		if veh_at[c] != -1 or sim.at[c] != -1:
			continue
		var ai := k < 12
		vehicles.append({"cell": c, "dir": rng.randi() % 4, "spd": 0, "charge": rng.randi_range(40, 100), "hp": 60,
						 "ai": ai, "dest": rng.randi() % waypoints.size(), "color": [Color("#d94f70"), Color("#3fb6c9"), Color("#e8c03a"), Color("#8f8fa8"), Color("#4fd98a")][rng.randi() % 5],
						 "driver": -3 if ai else -1})
		veh_at[c] = vehicles.size() - 1
		sim.walk[c] = 0

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
		var kind := _weighted([["trl_ration", 28], ["trl_yen", 26], ["ammo", 16], ["water", 8], ["gun", 9], ["mod", 3], ["trl_backpack", 3], ["trl_coat", 2], ["trl_pouch", 3], ["trl_duffel", 1]])
		var it
		match kind:
			"trl_yen": it = _new_item("trl_yen", rng.randi_range(20, 220))
			"ammo": it = _new_item(_random_ammo() if rng.randf() < 0.6 else "trl_ammo", rng.randi_range(1, 3))
			"mod": it = _new_item(_random_mod())
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
		_put(arr[rng.randi() % arr.size()], _new_item(_random_gun()))
		_put(arr[rng.randi() % arr.size()], _new_item("trl_yen", rng.randi_range(300, 900)))
		_put(arr[rng.randi() % arr.size()], _new_item(_random_ammo(), rng.randi_range(2, 4)))
		_put(arr[rng.randi() % arr.size()], _new_item(_random_mod()))
		if rng.randf() < 0.5:
			_put(arr[rng.randi() % arr.size()], _new_item(_random_mod()))
		if rng.randf() < 0.5:
			_put(arr[rng.randi() % arr.size()], _new_item("trl_backpack"))

func _put(cell: int, it) -> void:
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
	if z > 0:
		return "Floor %d" % z
	match z:
		0: return "Street level"
		-1: return "Subway & tunnels"
		_: return "Sewers"

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
		BRATVA: return true
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

func skill_up(skill: String, difficulty: int) -> void:
	# gain comes from risk, not repetition: easy successes (difficulty below your level) teach nothing
	if difficulty < skills[skill] - 1:
		return
	xp[skill] += 1 + maxi(0, difficulty - skills[skill])
	if xp[skill] >= 6 + skills[skill] * 4:
		xp[skill] = 0
		skills[skill] += 1
		say("Your %s skill rises to %d." % [skill, skills[skill]])

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
	if it.def.has("gun"):
		var gs: Dictionary = GP.stats(it)
		s += " (%d/%d%s)" % [it.loaded, gs["mag"], (" +%d mods" % it.mods.size()) if not it.mods.is_empty() else ""]
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
		elif wield == null and it.has_tag("gun"):
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
		end_turn()
	return took > 0

func act_wield(it) -> bool:
	if not it.has_tag("gun"):
		say("You can't wield that as a weapon.")
		return false
	var holder = null
	for c in worn:
		if c == it or c.contains_item(it):
			c.remove(it)
			holder = c
	if wield != null:
		if not stow(wield):
			_put(pc, wield)
			say("You drop the %s." % item_label(wield))
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
func act_move(dx: int, dy: int, run: bool = false) -> bool:
	if game_over:
		return false
	if in_vehicle >= 0:
		return drive(dx, dy)
	if transit.riding >= 0:
		return transit.ride_move(dx, dy)
	var nx: int = pc % size + dx
	var ny: int = pc / size + dy
	if not in_bounds(nx, ny):
		return false
	facing = Vector2i(dx, dy)
	var c := ny * size + nx
	var who: int = sim.at[c]
	if who >= 0:
		melee(who)
		end_turn()
		return true
	if veh_at[c] != -1:
		say("A car blocks the way.  [e] to get in.")
		return false
	if city.tiles[c] == CG.LOCKED:
		return _pick_lock(c)
	if sim.walk[c] == 0:
		return false
	if city.tiles[c] == CG.TRACK and transit.try_board(c):
		end_turn()
		return true
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
	if items_at.has(pc):
		var names := []
		for it in items_at[pc]:
			names.append(item_label(it))
		say("You see here: " + ", ".join(names) + ".")
	end_turn()
	if stance == CRAWL and not game_over:
		end_turn()                       # crawling is half speed
	return true

func act_wait() -> void:
	end_turn()

## the lock on a door: theft skill against the floor's security
func _pick_lock(c: int) -> bool:
	var z := absi(z_of(c))
	var chance := clampi(28 + skills["theft"] * 9 - z * 2, 10, 90)
	if rng.randi() % 100 < chance:
		city.tiles[c] = CG.DOOR
		sim.tiles[c] = CG.DOOR
		say("You work the lock open.")
		skill_up("theft", 3 + z / 6)
		_noise(c, 5)
	else:
		say("The lock holds.  You fumble with it.")
		_noise(c, 8)
		_witness(c, 9, 6, -1)
	end_turn()
	return true

## climb or descend where the cell links to another level.  dir +1 up, -1 down.  An elevator carries you up to three floors.
func act_vertical(dir: int) -> bool:
	if in_vehicle >= 0 or transit.riding >= 0:
		return false
	if not city.haslink[pc] == 1:
		say("There is no way %s here." % ("up" if dir > 0 else "down"))
		return false
	var here_lvl := pc / s2
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
	pc = cur
	var kind: String = "The elevator whirs" if elevator else ("You climb the stairs" if city.tiles[pc] == CG.STAIRS else "You climb the ladder")
	say("%s %s to %s." % [kind, "up" if dir > 0 else "down", zname(pc)])
	var tw := tower_at(pc)
	if z_of(pc) > 0 and not tw.is_empty():
		say("(%d of %d floors)" % [z_of(pc), tw["h"]])
	sim.retier(pc)
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

## a standing jump over low obstacles, railings, gaps and people-sized trouble.  Two cells; three after a running start.
func act_jump(dx: int, dy: int) -> bool:
	if in_vehicle >= 0 or transit.riding >= 0:
		say("Not from here.")
		return false
	if stance == CRAWL:
		say("You can't jump from the floor.")
		return false
	if stamina < 4:
		say("You are too winded to jump.")
		return false
	if dx == 0 and dy == 0:
		return false
	var run_up: bool = run_streak >= 1 and run_dir == Vector2i(dx, dy)
	var maxd := 3 if run_up else 2
	for dist in range(maxd, 1, -1):
		var nx: int = pc % size + dx * dist
		var ny: int = pc / size + dy * dist
		if not in_bounds(nx, ny):
			continue
		var land: int = ny * size + nx
		if z_of(land) != z_of(pc) or sim.walk[land] == 0 or sim.at[land] != -1 or veh_at[land] != -1 or city.tiles[land] == CG.LOCKED:
			continue
		var clear := true
		for k in range(1, dist):
			var mid: int = (pc / size + dy * k) * size + pc % size + dx * k
			var mt: int = city.tiles[mid]
			if mt == CG.WALL or mt == CG.EARTH or mt == CG.LOCKED or sim.at[mid] != -1:
				clear = false
		if not clear:
			continue
		facing = Vector2i(dx, dy)
		pc = land
		stamina -= 4
		run_streak = 0
		ran_this_turn = true
		step_noise = 7
		say("You leap%s." % (" from a running start" if run_up else ""))
		if items_at.has(pc):
			var names := []
			for it in items_at[pc]:
				names.append(item_label(it))
			say("You see here: " + ", ".join(names) + ".")
		end_turn()
		return true
	say("There is nowhere to land that way.")
	return false

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
		if t in CG.LOW_COVER or veh_at[c] != -1:
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

func _face_toward(i: int, cell: int) -> void:
	var c: int = sim.pos[i]
	var dx: int = signi(cell % size - c % size)
	var dy: int = signi(cell / size - c / size)
	if dx == 0 and dy == 0:
		return
	face[i] = DIR8.find([dx, dy])


func melee(i: int) -> void:
	var sneak := astate[i] == UNAWARE or astate[i] == RETURNING
	var chance: int = 72 + skills["melee"] * 3 - (0 if sneak else 12)
	if astate[i] == SURRENDERED:
		chance = 100
	if rng.randi() % 100 >= chance:
		say("You miss %s." % name_of(i))
		_alert(i)
		return
	var dmg: int = rng.randi_range(3, 6) + skills["melee"] / 2
	var behind: bool = sneak and cone_factor(i, pc) == 0.0
	if behind:
		dmg *= 4
		say("You strike %s from behind!" % name_of(i))
	elif sneak:
		dmg *= 2
		say("You catch %s unready." % name_of(i))
	_silent = behind
	hurt(i, dmg, true)
	_silent = false
	skill_up("melee", 3 if hpmax[i] >= 40 else 1)

func hurt(i: int, dmg: int, by_player: bool) -> void:
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
	var chance: int = 38 + skills["theft"] * 7 + skills["stealth"] * 3 + (12 if crouch else 0)
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
		skill_up("theft", 4 if not aware else 6)
		if fac[target] == NAP:
			_witness(sim.pos[target], 8, 6, target)
		end_turn()
		return true
	say("%s catches your hand!" % name_of(target))
	skill_up("theft", 3)
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
	var c: int = GP.hit_chance(st, cheb(sim.pos[t], pc), aimed, moved, crouch, skills["ranged"], eco.aim_penalty(), shot_index, stance == CRAWL)
	return clampi(c - cover_vs(pc, sim.pos[t], false), 5, 95)

## one-line description of the wielded gun and what it is aimed at
func gun_line() -> String:
	if wield == null or not wield.has_tag("gun"):
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
	if aim_turns < GP.MAX_AIM:
		aim_turns += 1
	aim_target = t
	say("You steady the %s on %s: %d%% to hit." % [wield.def["name"], name_of(t), hit_chance_on(t)])
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
	if in_vehicle >= 0:
		say("Not while driving.")
		return false
	if wield.jammed:
		wield.jammed = false
		say("You clear the jam.")
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

func _victim_in_line(t: int) -> int:
	for c in GP.line_cells(pc, sim.pos[t], size):
		var who: int = sim.at[c]
		if who >= 0 and who != t and sim.alive[who] == 1 and rng.randf() < 0.55:
			return who
	return t

func act_fire(any: bool = false) -> bool:
	if in_vehicle >= 0:
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
		var victim: int = _victim_in_line(t)
		var vd: int = d if victim == t else cheb(sim.pos[victim], pc)
		var pellets: int = int(st["pellets"])
		var landed := 0
		var dmg_total := 0
		if st["blast"] > 0:
			landed = 1 if rng.randi() % 100 < chance else 0
			dmg_total = rng.randi_range(int(st["dmg"][0]), int(st["dmg"][1]))
		elif pellets > 1:
			var pc_chance: int = clampi(chance - int(float(vd) * 3.0 * float(st["spread"])), 4, 95)
			var fall: float = 1.0 if vd <= int(st["range"]) else 0.5
			for _p in pellets:
				if rng.randi() % 100 < pc_chance:
					landed += 1
					dmg_total += int(float(rng.randi_range(int(st["dmg"][0]), int(st["dmg"][1]))) / float(pellets) * 1.25 * fall)
		else:
			if rng.randi() % 100 < chance:
				landed = 1
				dmg_total = rng.randi_range(int(st["dmg"][0]), int(st["dmg"][1]))
		tracers.append([pc, sim.pos[victim] if landed > 0 or st["blast"] > 0 else sim.pos[t], landed > 0])
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
	if rng.randf() * 100.0 < float(st["jam"]) * float(shots) and wield.loaded > 0:
		wield.jammed = true
		say("The %s jams." % wield.def["name"])
	end_turn()
	return true

func _damage_npc(v: int, dmg: int) -> void:
	if sim.alive[v] == 0:
		return
	var st: Dictionary = gun_stats()
	_silent = (not st.is_empty() and st["suppressed"]) and (astate[v] == UNAWARE or astate[v] == RETURNING)
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
	var victims: Array = []
	for k in sim.near_list.size():
		var j: int = sim.near_list[k]
		if sim.alive[j] == 1 and cheb(sim.pos[j], c) <= radius:
			victims.append(j)
	for j in victims:
		var f: float = 1.0 - 0.3 * float(cheb(sim.pos[j], c))
		_damage_npc(j, int(float(dmg) * f))
	if cheb(pc, c) <= radius:
		player_hurt(int(float(dmg) * (1.0 - 0.3 * float(cheb(pc, c)))), "The blast catches you")
	heat = mini(100, heat + 12)
	_noise(c, 26)

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
	_vehicles()
	eco.step()
	step_noise = 0
	ran_this_turn = false
	if turn % 20 == 0 and heat > 0:
		heat -= 1
	if turn % 12 == 0 and hp < hp_max and in_vehicle < 0:
		hp += 1
	fov.compute(pc % size, pc / size, 18)
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
		# who is worth watching: armed or hostile factions, or anyone already worked up
		var capable := fac[i] == BRATVA or fac[i] == NAP or (fac[i] == NASIM and noticed_you[i] == 1)
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
	var los: bool = d <= 16 and fov.visible[c] == 1 and sim._sees(c, pc, 16)
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
	var sees: bool = d <= 18 and fov.visible[c] == 1 and sim._sees(c, pc, 20)
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
		var chance := clampi(62 - 4 * maxi(0, d - 2) - stance_pen - (15 if in_vehicle >= 0 else 0) - cover_vs(c, pc, crouch), 8, 85)
		if rng.randi() % 100 < chance:
			var dmg := rng.randi_range(5, 9) if g == 1 else rng.randi_range(6, 11)
			player_hurt(dmg, "%s shoots you" % name_of(i))
		else:
			say_if_seen(c, "%s shoots at you and misses." % name_of(i))
		_noise(c, 14)
		return
	if d <= 1:
		if rng.randi() % 100 < 60:
			player_hurt(rng.randi_range(3, 7), "%s hits you" % name_of(i))
		else:
			say("%s swings and misses." % name_of(i))
		return
	if not _step_field(i):
		_step_to(i, pc)

func say_if_seen(cell: int, msg: String) -> void:
	if sees_cell(cell):
		say(msg)

func player_hurt(dmg: int, msg: String) -> void:
	hp -= dmg
	say("%s (-%d)." % [msg, dmg])

# ---------------------------------------------------------------- vehicles
func vehicle_near() -> int:
	for d in SIZE_DIRS + [[0, 0]]:
		var nx: int = pc % size + d[0]
		var ny: int = pc / size + d[1]
		if in_bounds(nx, ny) and veh_at[ny * size + nx] != -1:
			return veh_at[ny * size + nx]
	return -1

func act_vehicle() -> bool:
	if in_vehicle >= 0:
		var v: Dictionary = vehicles[in_vehicle]
		v["driver"] = -1
		v["spd"] = 0
		say("You step out of the car.")
		# stand on a free neighbouring cell
		for d in SIZE_DIRS:
			var nx: int = v["cell"] % size + d[0]
			var ny: int = v["cell"] / size + d[1]
			if in_bounds(nx, ny):
				var nc := ny * size + nx
				if sim.walk[nc] == 1 and sim.at[nc] == -1 and veh_at[nc] == -1:
					pc = nc
					break
		in_vehicle = -1
		end_turn()
		return true
	var vi := vehicle_near()
	if vi < 0:
		say("No car within reach.")
		return false
	var v2: Dictionary = vehicles[vi]
	if v2["driver"] == -3:
		say("The driver glares at you and pulls away.")
		return false
	if v2["charge"] <= 0:
		say("The battery is dead.")
		return false
	in_vehicle = vi
	v2["driver"] = -2
	pc = v2["cell"]
	say("You get into the car.  Arrow keys drive, [space] brakes, [e] exits.  Battery %d%%." % v2["charge"])
	end_turn()
	return true

func _veh_free(c: int) -> bool:
	return city.tiles[c] == CG.ROAD or city.tiles[c] == CG.GROUND or city.tiles[c] == CG.PARK

func _move_vehicle(vi: int, to: int) -> void:
	var v: Dictionary = vehicles[vi]
	veh_at[v["cell"]] = -1
	sim.walk[v["cell"]] = 1 if city.walkable(city.tiles[v["cell"]]) else 0
	v["cell"] = to
	veh_at[to] = vi
	sim.walk[to] = 0

func drive(dx: int, dy: int) -> bool:
	var vi := in_vehicle
	var v: Dictionary = vehicles[vi]
	if dx == 0 and dy == 0:
		v["spd"] = 0
		end_turn()
		return true
	if v["charge"] <= 0:
		say("The battery is dead.")
		return false
	var dir := 0
	if dx != 0:
		dir = 1 if dx > 0 else 3
	else:
		dir = 2 if dy > 0 else 0
	if v["spd"] == 0 or dir != v["dir"]:
		v["spd"] = 1 if v["spd"] == 0 else 1
	else:
		v["spd"] = mini(v["spd"] + 1, 4)
	v["dir"] = dir
	var dv: Array = DIR4[dir]
	for s in v["spd"]:
		var cx: int = v["cell"] % size + dv[0]
		var cy: int = v["cell"] / size + dv[1]
		if not in_bounds(cx, cy):
			v["spd"] = 0
			break
		var nc := cy * size + cx
		var who: int = sim.at[nc]
		if who >= 0:
			var dmg: int = 12 + v["spd"] * 8
			say("You run down %s!" % name_of(who))
			hpn[who] -= dmg
			_witness(nc, 14, 18, who)
			if hpn[who] <= 0:
				kill(who)
			else:
				_alert(who)
			v["spd"] = maxi(1, v["spd"] - 2)
			v["hp"] -= 4
			break
		if veh_at[nc] != -1 or not _veh_free(nc):
			if v["spd"] >= 2:
				say("You crash!")
				v["hp"] -= 6 * v["spd"]
				hp -= v["spd"]
			v["spd"] = 0
			break
		_move_vehicle(vi, nc)
		pc = nc
		if (turn + s) % 4 == 0:
			v["charge"] = maxi(0, v["charge"] - 1)
	if v["hp"] <= 0:
		say("The car is wrecked.  You climb out.")
		act_vehicle()
		return true
	end_turn()
	return true

func _vehicles() -> void:
	for vi in vehicles.size():
		var v: Dictionary = vehicles[vi]
		if not v["ai"] or v["driver"] != -3:
			continue
		if cheb(v["cell"], pc) > 60:
			continue
		var f: PackedInt32Array = way_fields[v["dest"]]
		for s in 2:
			var c: int = v["cell"]
			var cur: int = f[c]
			if cur == 0:
				v["dest"] = rng.randi() % waypoints.size()
				break
			var best := -1
			var bv := cur
			for nb in [c - 1, c + 1, c - size, c + size]:
				if nb >= 0 and nb < s2 and f[nb] < bv and veh_at[nb] == -1 and sim.at[nb] == -1 and nb != pc:
					bv = f[nb]
					best = nb
			if best < 0:
				break
			_move_vehicle(vi, best)

# ---------------------------------------------------------------- save / load
func save_dict() -> Dictionary:
	var it_at := {}
	for c in items_at:
		var arr := []
		for it in items_at[c]:
			arr.append(it.to_dict())
		it_at[str(c)] = arr
	var vs := []
	for v in vehicles:
		var o: Dictionary = v.duplicate()
		o["color"] = v["color"].to_html()
		vs.append(o)
	return {"seed": seed_value, "turn": turn, "pc": pc, "hp": hp, "yen": yen, "heat": heat, "ammo": ammo_pool, "want_kind": want_kind, "skills": skills, "xp": xp, "in_vehicle": in_vehicle,
			"rng_state": str(rng.state), "transit": transit.save(), "eco": eco.save(), "worn": worn.map(func(x): return x.to_dict()), "wield": (wield.to_dict() if wield != null else null),
			"items_at": it_at, "vehicles": vs, "tick": sim.tick, "log": log.slice(-30),
			"npc": {"pos": Array(sim.pos), "dest": Array(sim.dest), "goal": Array(sim.goal), "near": Array(sim.near), "alive": Array(sim.alive), "depart": Array(sim.depart), "arrive": Array(sim.arrive),
					"hp": Array(hpn), "state": Array(astate), "meter": Array(meter), "timer": Array(timer), "last": Array(lastpos), "post": Array(postc), "yen": Array(yenn), "gun": Array(gunc),
					"noticed": Array(noticed_you), "ctl": Array(sim.ctl), "idle": Array(sim.idle)}}

func load_dict(d: Dictionary) -> void:
	seed_value = int(d["seed"])
	setup(sim.n if sim != null else 2000)             # regenerates the deterministic parts (map, markers, names, factions)
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
	skills = d["skills"]
	for k in skills:
		skills[k] = int(skills[k])
	xp = d["xp"]
	in_vehicle = int(d["in_vehicle"])
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
	for c in s2:
		if veh_at[c] != -1:
			sim.walk[c] = 1 if city.walkable(city.tiles[c]) else 0
	veh_at.fill(-1)
	vehicles = []
	for v in d["vehicles"]:
		var o: Dictionary = v.duplicate()
		o["color"] = Color(v["color"])
		for k in ["cell", "dir", "spd", "charge", "hp", "dest", "driver"]:
			o[k] = int(o[k])
		vehicles.append(o)
		veh_at[o["cell"]] = vehicles.size() - 1
		sim.walk[o["cell"]] = 0
	sim.tick = int(d["tick"])
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
	fov.compute(pc % size, pc / size, 18)
