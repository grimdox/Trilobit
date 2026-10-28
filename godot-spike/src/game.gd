extends RefCounted
## The playable slice: one city, one player, roughly two thousand people, awareness-driven hostiles, theft, shooting, pockets and cars.
## All rules live here and run headless; main.gd and view.gd only draw it and feed it keys.
const SPARSE = preload("res://src/sparse.gd")
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
const BT = preload("res://src/barter.gd")
const GP = preload("res://src/gunplay.gd")
const VS = preload("res://src/vehicles.gd")
const IMP = preload("res://src/implants.gd")
const INV = preload("res://src/inventory.gd")
const BODY = preload("res://src/body.gd")
const SK = preload("res://src/skills.gd")
const CR = preload("res://src/creation.gd")
const CLK = preload("res://src/clock.gd")
const MS = preload("res://src/missions.gd")
const PW = preload("res://src/power.gd")
const NANO = preload("res://src/nanohacks.gd")
const SITE = preload("res://src/mission_site.gd")
const LOOK = preload("res://src/look.gd")

const UNAWARE := 0
const CRAWL := 0
const CROUCH := 1
const WALKING := 2
const RUNNING := 3
const STAMINA_MAX := 100                       # stamina is a percentage
const AP_BASE := 100                           # action points everyone earns per turn, and what a move or a strike costs
const AP_MIN_RATE := 20                        # a worn-out body still earns this much, so nobody is ever frozen
const RUN_STAMINA := 5                         # stamina a running move costs; walking, crawling and crouching are free
const STAM_LEGACY := 100.0 / 30.0              # food, jumps: the old 30-point stamina scale, in percent
const CAT_AP := 110                            # cats are quick
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
static var street_start: bool = OS.get_environment("TRL_STREET") != ""   # tests: begin on a road instead of in a flat
var rows: int = 0                    # rows of the stacked map
var total: int = 0                   # cells in all levels
var transit
var eco
var barter = BT.new(self)            # merchants' shelves for the barter screen (barter.gd)
var turn: int = 0
var game_over: bool = false
var log: Array = []
var sfx_queue: Array = []             # sound events for the front end ("shot", "step", ...); drained after each key

# the player
var pc: int = 0                      # cell index
var yen: int = 0                                   # starting cash will come from the chosen start; none for now
var ammo_pool: Dictionary = {"9mm|fmj": 36}   # "caliber|kind" -> rounds carried loose
var want_kind: Dictionary = {}                 # caliber -> kind the next reload loads
var aim_turns: int = 0                         # banked aim points (negative after a long burst, never below max aim - 5)
var aim_dbt: float = 0.0                       # fractional aim loss carried between bullets
var aim_target: int = -1
var moved: bool = false
var last_pc: int = -1
var tracers: Array = []                        # [from_cell, to_cell, hit] for the view; cleared on the next key
var crouch: bool = false                       # derived from stance: true when crouching or crawling
var stance: int = 2                            # CRAWL, CROUCH, WALKING, RUNNING
var stamina: int = STAMINA_MAX
var ran_this_turn: bool = false
var run_dir := Vector2i(0, 0)
var run_streak: int = 0
var run_mode: bool = false                     # chosen on the movement prompt: every move is a run (Shift also runs)
var nanos: Array = []                         # the nanohack in each Trilobit slot ("" for an empty one)
var nano_fx := {}                             # active hack id -> turns left
var implants := {}                             # "legs": leg actuators, "jets": dorsal jump jets
var fuel: int = 24
var flying: bool = false
var followers: Array = []                      # hunters climbing after you
# missions (missions.gd): `mission` is set only inside a generated site; `portal` only in the physical world while an accepted mission's portal is open
var mission: Dictionary = {}
# implant power (power.gd): kJ in the store, -1 for a rig that has never been charged (it starts full the first time it is needed); at 0 every implant is off
var power: float = -1.0
var power_state: int = 0                       # 0 fine, 1 low (a quarter), 2 critical (a tenth), 3 dark: so each warning is said once
var elev_hit: int = -1                         # an elevator the player just stepped into the call of: the front end shows the floor list (see elevator_floors)
var clock_hit: int = -1                        # a station clock the player just used (the front end shows its readout and clears this)
var charger_hit: int = -1                      # a charging post the player just used (the front end opens its menu and clears this)
var energy: PackedInt32Array                   # kJ left in each person: -1 until it is first needed (then power.gd works it out from the clock); frozen when they die or are drained
var done_contracts: Dictionary = {}           # ids of the contracts the player has completed and been paid for: a posted contract pays once
var portal: Dictionary = {}                    # {cell, was (the tile it replaced), under, offer}
var terminal_hit: int = -1                     # a mission terminal the player just used (the front end opens its screen and clears this)
var ev_hit: int = -1                           # a vehicle charging bank the player just used: its north-west cell (the front end opens the menu and clears this)
var smith_hit: int = -1                        # a gunsmithing table the player just used (the front end opens the gun screen and clears this)
var player_name: String = ""                   # chosen on the creation screen, shown on the HUD, saved
var open_doors: Dictionary = {}                # cells of doors that have been opened (every door starts shut): cell -> true.  A shut door blocks sight; people walk through (and open) it
var mission_leave_request: String = ""         # "exit" (stepped through the exit portal) or "blast" (the charge went off): the front end hands over to the world
var mission_enter_request: bool = false        # the player stepped into an open portal
var step_noise: int = 0                        # how far this turn's footsteps carry
var app: Dictionary = {"sprite": 0, "skin": 0, "hair": 4, "style": 1, "eyes": 0, "bg": "none"}      # how the player looks (creation.gd); saved with the player
var attrs: Dictionary = SK.default_attrs()      # Strength, Perception, Agility, Cognition, Endurance (start at 10)
var skills: Dictionary = SK.default_skills()    # BASE levels, raised by skill XP (see skills.gd for the effective level)
var xp: Dictionary = SK.default_skills()        # skill-specific XP towards the next base level
var pc_level: int = 0                           # character level 0..10, raised by skills (skills.gd LEVEL_REQS); only the player has one
var attr_points: int = 0                        # attribute points earned by levelling and not yet spent
## what you carry: nine equipment slots and a grid of one-tile items (src/inventory.gd)
var inv = INV.new()
## the weapon in your Right Hand (a two-handed weapon sits there too)
var wield:
	get:
		return inv.equip.get("rhand")
	set(v):
		if v == null:
			inv.equip.erase("rhand")
		else:
			inv.equip["rhand"] = v
## pocket items you wear (coat, backpack, belt pouch, fanny pack)
var worn: Array:
	get:
		return inv.equipped_items().filter(func(x): return x.def.has("pocket"))
	set(v):
		_set_worn(v, true)
## armor you wear that is not also a pocket item (the coat's armor is counted with the pocket items)
var armor_worn: Array:
	get:
		return inv.equipped_items().filter(func(x): return x.def.has("armor") and not x.def.has("pocket"))
	set(v):
		_set_worn(v, false)
## replace what you wear (pocket items, or non-pocket armor): used by tests and scripted starts
func _set_worn(list: Array, pockets: bool) -> void:
	for x in inv.equipped_items():
		if x.def.has("pocket") == pockets and (pockets or x.def.has("armor")):
			inv.remove(x)
	for x in list:
		if inv.stow(x):
			inv.auto_equip(x)
var in_vehicle: int = -1
var vs                                 # the vehicle system (vehicles.gd)
var facing := Vector2i(0, 1)

# the world
var items_at: Dictionary = {}        # cell -> Array of Item
var vehicles: Array = []
var veh_at                                  # a Sparse map (sparse.gd): the vehicle on each cell, -1 if none
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
## weapon specials (stun, trip, bleed, knock-back, disarm, sweep, brace) and status effects like stun are shelved for now; the data stays
var specials_on := false
var stun: PackedByteArray             # turns a person is stunned, tangled or tripped
var bleed: PackedByteArray            # turns left bleeding (1 hp each)
var mdis: PackedByteArray             # 1 = their melee weapon has been knocked away
var melee_pool: Dictionary = {}       # faction -> melee weapon ids they carry
var melee_all: Array = []
var prev_wield = null
var things: Array = []                # loose props: {k, cell, hp, loot}
var thing_at                                # a Sparse map: the thing on each cell
## bodies left by the dead: {cell, name, fac, kj}; the energy in them can still be drawn
const CORPSE_CAP := 300
var corpses: Array = []
var critters: Array = []              # dogs and cats: {k, cell, hp, mood, stun}
var crit_at                                 # a Sparse map: the creature on each cell
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

func setup(n_people: int = 1200, isl = null, zn: Vector2i = Vector2i(-1, -1), msn: Dictionary = {}) -> void:
	rng.seed = seed_value
	mission = msn.duplicate(true)
	db = DB.new()
	db.load_file("res://data/items.json")
	GP.load_ammo(db.defs)
	for k in db.defs:
		var d: Dictionary = db.defs[k]
		if "gun" in d.get("tags", []):
			for t in d["tags"]:
				if t != "gun":
					if not gun_ids.has(t):
						gun_ids[t] = []
					gun_ids[t].append(k)
	_melee_pools()
	var _t0 := Time.get_ticks_msec()
	if not mission.is_empty():
		island = null
		zone = Vector2i(-1, -1)
		city = SITE.build(mission["offer"])
		n_people = city.get_meta("site")["agents"].size()
	elif isl != null:
		island = isl
		zone = zn
		city = island.build_zone_cached(zn.x, zn.y)
		_prof("build_zone", _t0)
		if zn == island.CITY_ZONE:
			LV.build(city, island.seed_value)
			_prof("levels", _t0)
			if zone == island.CITY_ZONE:
				island.rail_portal(city)
				_prof("rail_portal", _t0)
		else:
			LV.flat(city, seed_value)
	else:
		island = null
		zone = Vector2i(-1, -1)
		city = CG.new()
		city.generate(seed_value, Vector2(1, 0.2))
		city.signs = preload("res://src/signage.gd").make(city, seed_value)
		LV.build(city, seed_value)
	size = city.size
	s2 = size * size
	total = city.tiles.size()
	rows = total / size
	_shut_doors()
	if mission.is_empty():
		_add_windows()
	sim = SIM.new()
	sim.perception_standin = false
	sim.setup(city, n_people, seed_value ^ 0x5eed)
	_prof("sim.setup", _t0)
	sim.tick = CLK.START_TICK
	last_ate = sim.tick
	last_drank = sim.tick
	fov = FOV.new()
	fov.setup(size, sim.opaque)
	pf = PackedInt32Array(); pf.resize(total); pf.fill(FF.UNREACHED)
	veh_at = SPARSE.new(total)
	things = []
	critters = []
	corpses = []
	thing_at = SPARSE.new(total)
	crit_at = SPARSE.new(total)
	_people()
	if not mission.is_empty():
		_mission_people()
	if island != null and zone == island.PORT_ZONE:
		_port_people()
	_prof("people", _t0)
	_roads_and_cars()
	_prof("cars", _t0)
	_loot()
	_vault_loot()
	_prof("loot", _t0)
	_start_player()
	transit = TR.new()
	transit.setup(self)
	_place_station_clocks()
	_prof("transit", _t0)
	eco = EC.new()
	eco.setup(self)
	barter = BT.new(self)
	if not mission.is_empty():
		_mission_roles()
	_assign_jobs()
	_npc_energy_init()                                  # after the economy has settled everyone's faction
	_prof("eco", _t0)
	_compute_fov()
	_prof("fov", _t0)
	if island == null or zone == island.CITY_ZONE:
		say("You step out onto the street.  Morning in the city.  [?] for keys.")

## Everyone who is not nailed to a post gets one place to work.  The shops, offices, gyms and lobbies of the new buildings are staffed by ordinary
## people only (never the gangs), the keeper of a shop that trades is a merchant; whoever is left works at one of the old workplace markers,
## and the gangs hang about on the street.  Each job goes to the nearest of a few unemployed people, so the commute is short more often than not.
func _assign_jobs() -> void:
	if not mission.is_empty() or (island != null and zone != island.CITY_ZONE):
		return
	var com = sim.com
	com.wait_ready()
	var hcomp := {}                                       # the piece of ground each person's home belongs to (a job is only given to somebody who can walk to it)
	var comp_of_home := func(i: int) -> int:
		var h: int = sim.home_cell[i]
		if not hcomp.has(h):
			hcomp[h] = com.comp_of(h)
		return hcomp[h]
	var pool: Array = []
	for i in sim.n:
		if sim.sticky[i] == 0 and sim.alive[i] == 1 and fac[i] == CIV and eco.role[i] == eco.NONE:
			pool.append(i)
	var staffed: Dictionary = {}
	var jobs: Array = []                                   # [cell, merchant?]
	for b in city.businesses:
		if b.get("legacy", false):
			continue
		var st: Array = b["staff"]
		for k in st.size():
			jobs.append([int(st[k]), k == 0 and b["role"] == "vendor" and int(b["keeper"]) == int(st[k])])
			staffed[int(st[k])] = true
	for c in city.works_t:
		jobs.append([int(c), false])
		staffed[int(c)] = true
	var filled := 0
	for jb in jobs:
		if pool.is_empty():
			break
		var cell: int = jb[0]
		var jcomp: int = com.comp_of(cell)
		if jcomp == 0:
			continue
		var best := -1
		var bd := 1 << 30
		for _t in 24:
			var pk: int = rng.randi() % pool.size()
			if comp_of_home.call(pool[pk]) != jcomp:
				continue
			var d: int = com.manh(sim.home_cell[pool[pk]], cell)
			if d < bd:
				bd = d
				best = pk
		if best < 0:
			continue
		var who: int = pool[best]
		pool[best] = pool[pool.size() - 1]
		pool.pop_back()
		com.assign(who, cell)
		if jb[1]:
			eco.role[who] = eco.VENDOR
			eco.look[who] = ["backpack", "courier"]
		filled += 1
	# everyone else: an old workplace marker (the nearest of a dozen), or the street for the gangs
	var general: Array = []
	for c in city.works_g:
		if not staffed.has(int(c)):
			general.append(int(c))
	for i in sim.n:
		if sim.sticky[i] == 1 or sim.alive[i] == 0 or com.wc[i] >= 0:
			continue
		var cell2 := -1
		if fac[i] == CIV and not general.is_empty():
			var bd2 := 1 << 30
			var hc: int = comp_of_home.call(i)
			for _t in 12:
				var c2: int = general[rng.randi() % general.size()]
				var d2: int = com.manh(sim.home_cell[i], c2)
				if d2 < bd2 and com.comp_of(c2) == hc:
					bd2 = d2
					cell2 = c2
			if cell2 >= 0:
				cell2 = sim._scatter(cell2, 3)
				if com.comp_of(cell2) != hc:
					cell2 = -1
		if cell2 < 0:
			cell2 = _loiter_cell(int(sim.home_cell[i]), comp_of_home.call(i))
		if cell2 >= 0:
			com.assign(i, cell2)
	com.index()

## a bit of pavement or park near a cell (where the gangs stand about)
func _loiter_cell(home: int, comp: int = 0) -> int:
	var hx: int = home % size
	var hy: int = (home / size) % size
	for _t in 80:
		var x: int = clampi(hx + rng.randi_range(-40, 40), 1, size - 2)
		var y: int = clampi(hy + rng.randi_range(-40, 40), 1, size - 2)
		var c: int = y * size + x
		var tt: int = city.tiles[c]
		if (tt == CG.GROUND or tt == CG.PARK) and sim.walk[c] == 1 and (comp == 0 or sim.com.comp_of(c) == comp):
			return c
	return int(home)

## TRL_PROF=1 prints how long each stage of building a zone took (milliseconds since the start of setup)
func _prof(label: String, t0: int) -> void:
	if OS.get_environment("TRL_PROF") != "":
		print("PROF %s %d" % [label, Time.get_ticks_msec() - t0])

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
	apn = PackedInt32Array(); apn.resize(n)
	stamn = PackedByteArray(); stamn.resize(n); stamn.fill(STAMINA_MAX)
	stamt = PackedInt32Array(); stamt.resize(n)
	aimn = PackedByteArray(); aimn.resize(n)
	limbn = PackedInt32Array(); limbn.resize(n * 6); limbn.fill(-1)
	for i in n:
		face[i] = (i * 5 + 3) & 7
	fem = PackedByteArray(); fem.resize(n)
	noticed_you = PackedByteArray(); noticed_you.resize(n)
	nname = PackedStringArray(); nname.resize(n)
	var rolled := PackedByteArray()
	rolled.resize(n)
	for i in n:
		var r0 := rng.randf()
		rolled[i] = BRATVA if r0 < 0.045 else (NAP if r0 < 0.085 else (NASIM if r0 < 0.105 else CIV))
	_factions_out_of_flats(rolled)
	for i in n:
		var f: int = rolled[i]
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

## the gangs live in houses, not in the flats of the towers: a gang member whose home is up a tower swaps homes with an ordinary person who has a house
func _factions_out_of_flats(rolled: PackedByteArray) -> void:
	var civ_low: Array = []
	for i in sim.n:
		if rolled[i] == CIV and int(sim.home_cell[i]) < s2:
			civ_low.append(i)
	var k := 0
	for i in sim.n:
		if rolled[i] != CIV and int(sim.home_cell[i]) >= s2 and k < civ_low.size():
			var j: int = civ_low[k]
			k += 1
			var h: int = sim.home_cell[i]
			sim.home_cell[i] = sim.home_cell[j]
			sim.home_cell[j] = h
			sim.pos[i] = sim.home_cell[i]
			sim.dest[i] = sim.home_cell[i]
			sim.pos[j] = h
			sim.dest[j] = h

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
	if not mission.is_empty():
		vs = VS.new(self)
		_spawn_things()
		return
	_spawn_vehicles()
	_spawn_things()
	_spawn_critters()

## fill the bays of the parking lots and charging stations with parked cars (normal cars: you can get in and drive them).  Each lot has its own fullness, from
## completely empty (one lot in seven) up to about nine bays in ten; a station is quieter than a lot, and a car beside a charger has run lower on charge.
func _park_lots(cols: Array) -> void:
	for li in city.lots.size():
		var lot: Dictionary = city.lots[li]
		var fill: float = 0.0 if (rng.randi() % 7 == 0 or li % 6 == 3) else 0.25 + rng.randf() * 0.65
		if lot["kind"] == "station":
			fill *= 0.5
		for bay in lot["bays"]:
			if rng.randf() >= fill:
				continue
			park_in_bay(int(bay[0]), int(bay[1]), cols[rng.randi() % cols.size()], 10 if int(bay[2]) == 1 else 30, 60 if int(bay[2]) == 1 else 100)

## put a parked car (3 x 5) into the 4 x 6 bay whose top-left cell is (bx, by); -1 if it will not fit
func park_in_bay(bx: int, by: int, color: Color, charge_lo: int, charge_hi: int) -> int:
	var dir: int = 0 if rng.randi() % 2 == 0 else 2
	dir = VS.h("car", dir)
	var a: int = vs.anchor_for("car", dir, 2 * bx + 3, 2 * by + 5, 0)
	var vi: int = vs.spawn("car", a, dir, color, false)
	if vi < 0:
		return -1
	for c in vs.cells(vehicles[vi]):
		if c % size < bx or c % size > bx + 3 or (c / size) % size < by or (c / size) % size > by + 5:
			vs.lift(vi)
			vehicles.pop_back()
			return -1
	vehicles[vi]["charge"] = rng.randi_range(charge_lo, charge_hi)
	return vi

func _car_colors() -> Array:
	return [Color("#d94f70"), Color("#3fb6c9"), Color("#e8c03a"), Color("#8f8fa8"), Color("#4fd98a"), Color("#e8e8ee"), Color("#2a3140")]

## cars in the lanes of the street grid (they drive), parked cars in the lots, and the special vehicles near the start
func _spawn_vehicles() -> void:
	vs = VS.new(self)
	if island != null and zone != island.CITY_ZONE:
		_spawn_zone_vehicles()
		return
	var cols: Array = _car_colors()
	var placed := 0
	var tries := 0
	var traffic: float = float(size * size) / 262144.0              # cars and parked cars scale with the map: the 512 city is the reference (46 and 26)
	var n_moving: int = int(round(46.0 * traffic))
	while placed < n_moving and tries < n_moving * 14:
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
		dir = VS.h(kind, dir)
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
	_park_lots(cols)
	# traffic on the riverside boulevards (they are curved, so they are not among the grid's lines): a few cars on each bank
	for key in ["blv_w", "blv_e"]:
		var band: PackedInt32Array = city.plan.get(key, PackedInt32Array())
		var rows: Array = []
		for y in band.size():
			if band[y] >= 0:
				rows.append(y)
		var made := 0
		tries = 0
		while made < 8 and tries < 120 and not rows.is_empty():
			tries += 1
			var row: int = rows[rng.randi() % rows.size()]
			var hi: bool = made % 2 == 0
			var vb: int = vs.anchor_for("car", 0 if hi else 4, VS.lane_k2(band[row], 1 if hi else 0), row * 2, 0)
			var vb_i: int = vs.spawn("car", vb, 0 if hi else 4, cols[rng.randi() % cols.size()], true)
			if vb_i < 0:
				continue
			var fits := true
			for c in vs.cells(vehicles[vb_i]):
				if city.tiles[c] != CG.ROAD:
					fits = false
			if not fits:
				vs.lift(vb_i)
				vehicles.pop_back()
				continue
			vehicles[vb_i]["charge"] = rng.randi_range(40, 100)
			made += 1
	# trucks parked on the south harbor's apron
	if island != null:
		for k in 5:
			_place("truck", 140 + k * 170 + rng.randi_range(-30, 30), island.harb_y - 40, 0, 50, [CG.PLATFORM], rng.randi() % 2, cols[rng.randi() % cols.size()])
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
		dir = VS.h(kind, dir)
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
	var cell: int = vs.find_spot(kind, clampi(near_y, 0, size - 1) * size + clampi(near_x, 0, size - 1), minr, maxr, tiles, VS.h(kind, dir))
	special_dir = VS.h(kind, dir)
	_add_special(kind, cell, color)

## the vehicles of the wild zones: trucks and a mech on the quay, cars in the town, a plane on the strip
func _spawn_zone_vehicles() -> void:
	var cols: Array = _car_colors()
	var o: Vector2i = island.zone_origin(zone.x, zone.y)
	if zone == island.PORT_ZONE:
		var qx: int = int(island.west_x(island.PORT.y)) + 6 - o.x
		var py: int = island.PORT.y - o.y
		for k in 2:
			_place("truck", qx + 30, py - 40 + k * 60, 0, 60, [CG.PLATFORM, CG.PARK, CG.SAND], 0, cols[rng.randi() % cols.size()])
		_spawn_dock_trucks(cols)
		_place("mech", qx + 4, py - 20, 0, 60, [CG.PLATFORM, CG.PARK, CG.SAND], 1, Color("#c0583a"))
		for k in 2:
			_place("car", qx + 24, py + 40 + k * 10, 0, 80, [CG.PLATFORM, CG.PARK], 1, cols[rng.randi() % cols.size()])
	elif zone == island.TOWN_ZONE:
		var cx: int = island.TOWN.x - o.x
		var cy: int = island.TOWN.y - o.y
		for k in 5:
			_place("car", cx + rng.randi_range(-60, 60), cy + rng.randi_range(-50, 60), 0, 60, [CG.GROUND], rng.randi() % 2, cols[rng.randi() % cols.size()])
		_place("heli", cx + 40, cy - 100, 0, 100, [CG.GROUND, CG.PARK], 0, Color("#7fd6e8"))
	elif island.zone_kind(zone) == "industry":
		for k in 6:
			var rx2: int = int(city.xs[rng.randi() % city.xs.size()]) + 6
			_place("truck" if k % 2 == 0 else "car", rx2, rng.randi_range(40, size - 40), 0, 30, [CG.ROAD], rng.randi() % 4, cols[rng.randi() % cols.size()])
	elif zone == island.AIR_ZONE:
		var x0: int = island.AIR_X0 - o.x
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
		if city.tiles[i] == CG.ROAD and veh_at.g(i) == -1 and sim.at[i] == -1:
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
	# nothing is left lying around: money, guns, ammo, armor and bags come from shops, people and jobs (only mission objects are placed)
	if not mission.is_empty():
		_mission_objects()

func _vault_loot() -> void:
	pass                                    # locked rooms hold no loose loot either

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
	for i in (0 if not mission.is_empty() else size * size):
		if city.tiles[i] == CG.ROAD and veh_at.g(i) == -1:
			var d := maxi(absi(i % size - size / 2), absi(i / size - size / 2))
			if d < bd and sim.at[i] == -1:
				bd = d
				best = i
	pc = best if mission.is_empty() else int(city.get_meta("site")["entry"])
	if street_start:
		pass
	elif mission.is_empty() and not city.apartments.is_empty() and (island == null or zone == island.CITY_ZONE):
		var flat: int = _start_flat()
		if flat >= 0:
			pc = flat
	inv = INV.new()
	inv.equip["chest"] = _new_item("trl_coat")
	inv.equip["back"] = _new_item("trl_backpack")
	inv.equip["rhand"] = _new_item("trl_gun_zp9")
	inv._ensure_group("chest")
	inv._ensure_group("back")
	_load_full(wield)
	inv.stow(_new_item("trl_ration", 2))
	inv.stow(new_bottle(500))
	implants = {"x101": true}                      # a Gutterline Trilobit comes fitted
	nanos = []
	nano_fx = {}
	for h in NANO.ALL:
		inv.stow(_new_item(NANO.chip_item(String(h["id"]))))

## a free floor cell in a flat chosen at random from every flat in every apartment building (who owns it is for later)
func _start_flat() -> int:
	var ap: Array = city.apartments
	var lived := {}                                  # every cell somebody calls home or stands on: a flat holding one of them is somebody's
	for i in sim.n:
		lived[int(sim.home_cell[i])] = true
		lived[int(sim.pos[i])] = true
	for _t in mini(ap.size(), 400):
		var a: Dictionary = ap[rng.randi() % ap.size()]
		var r: Rect2i = a["rect"]
		var base: int = (int(a["cell"]) / s2) * s2
		var cells: Array = []
		var empty := true
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c: int = base + y * size + x
				if lived.has(c):
					empty = false
				if sim.walk[c] == 1 and sim.at[c] == -1 and CG.is_floor(city.tiles[c]):
					cells.append(c)
		if empty and not cells.is_empty():
			return cells[rng.randi() % cells.size()]
	return -1

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
		NAP: return false                 # officers act only on what they see you do: a warning first, then they hunt
		_: return false

## how a person stands towards the player, for the facing arrow: 0 friendly (green), 1 neutral (blue), 2 hostile (red).
## Nobody is friendly yet: recruited allies will put their index in `allies`.
var allies: Dictionary = {}
## unaffiliated people (citizens, shopkeepers, ...) you have shot at, hit or robbed in view: they now count as marked, with a red arrow
var provoked: Dictionary = {}

## people with no faction show no indicator at all; a faction member, or anyone you have provoked, is marked (glow and arrow)
func marked(i: int) -> bool:
	return fac[i] != CIV or provoked.has(i) or allies.has(i)

func attitude(i: int) -> int:
	if allies.has(i):
		return 0
	if provoked.has(i) or hostile(i) or int(astate[i]) == HUNTING:
		return 2
	return 1

func name_of(i: int) -> String:
	if eco != null and eco.role[i] != 0:
		return "%s (%s)" % [nname[i], eco.label(i)]
	return "%s the %s" % [nname[i], FAC_NAMES[fac[i]]]

func time_text() -> String:
	return CLK.text(sim.tick)

func sees_cell(c: int) -> bool:
	return fov.visible[c] == 1

## the effective level of one of your skills: base level plus the bonus from its governing attributes
func lvl(id: String) -> int:
	if implants.is_empty():
		return SK.level(attrs, skills, id)
	return maxi(0, SK.level(attrs, skills, id) + IMP.skill_bonus(implants, id, _imp_active) + nano_bonus(id))

## a skill level without the implants (what fitting an implant asks for)
func base_lvl(id: String) -> int:
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
	xp[skill] += SK.XP_BASE * (1 + maxi(0, difficulty - skills[skill]))
	if xp[skill] >= SK.xp_needed(skills[skill]):
		xp[skill] -= SK.xp_needed(skills[skill])       # what is left over carries into the next level
		skills[skill] += 1
		say("Your %s skill rises to %d (level %d with attributes)." % [SK.skill(skill)["name"], skills[skill], lvl(skill)])
		check_level()

## raise the character level for as long as the skills qualify for the next one; each level earns an attribute point
func check_level() -> void:
	while pc_level < SK.LEVEL_MAX and SK.level_met(skills, pc_level + 1):
		pc_level += 1
		attr_points += 1
		say("You reach level %d!  An attribute point is waiting on the Attributes & Skills screen." % pc_level)
		sfx("pick")

## spend an earned point on an attribute
func spend_point(id: String) -> bool:
	if attr_points <= 0 or not attrs.has(id):
		return false
	attrs[id] = int(attrs[id]) + 1
	attr_points -= 1
	return true

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
	return inv.stow(it)

## a water bottle with `ml` of water in it
func new_bottle(ml: int):
	var b = _new_item("trl_water_bottle")
	b.fill = clampi(ml, 0, int(b.def["bottle"]["ml"]))
	return b

## every item you carry as [{item, depth, where, parent}]: equipment first, then the grid (kept in this shape for the menus that list things)
func inventory_list() -> Array:
	var out: Array = []
	for s in INV.SLOTS:
		if inv.equip.has(s):
			out.append({"item": inv.equip[s], "depth": 0, "where": "wielded" if s == "rhand" else ("in your left hand" if s == "lhand" else "worn"), "parent": null})
	for it in inv.grid_items():
		out.append({"item": it, "depth": 0, "where": "in your pack", "parent": null})
	return out

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
	if it.has_tag("medical"):
		return act_use_medical(it)
	if it.has_tag("food"):
		return act_eat(it)
	if it.has_tag("charm"):
		return act_use_charm(it)
	if it.def.has("armor") or it.def.has("pocket"):
		return act_wear(it)
	if not (it.has_tag("gun") or it.has_tag("melee")):
		say("You can't wield that as a weapon.")
		return false
	if it == wield:
		say("You already hold that.")
		return false
	var before: Dictionary = inv.find(it)
	var old = wield
	if not before.is_empty():
		inv.remove(it)
	if old != null:
		inv.equip.erase("rhand")
	var r: Dictionary = inv.put_equip("rhand", it)
	if not r["ok"]:
		if old != null:
			inv.equip["rhand"] = old
		if not before.is_empty():
			inv.stow(it)
		say(inv.last_err)
		return false
	if old != null:
		if not inv.stow(old):
			_put(pc, old)
			say("You drop the %s." % item_label(old))
			old = null
	prev_wield = old
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
func act_move(dx: int, dy: int, run: bool = false, turn: bool = true) -> bool:
	var on_foot: bool = in_vehicle < 0 and transit.riding < 0 and not flying
	var legs: int = body.legs_ok()
	if on_foot and legs < 2:
		run = false
	_no_turn = not turn
	var ok: bool = _act_move_core(dx, dy, run)
	_no_turn = false
	return ok

## walking into someone who means you no harm moves them aside instead of hitting them
func _bump_pushes(i: int) -> bool:
	return not hostile(i) and astate[i] != HUNTING and not provoked.has(i)

## shove a bystander one cell on, straight ahead or to either side of it; takes a turn only if they move
func _bump_push(who: int, dx: int, dy: int) -> bool:
	var tries: Array = [[dx, dy]]
	var k: int = DIR8.find([dx, dy])
	if k >= 0:
		for o in [1, 7]:
			tries.append(DIR8[(k + o) % 8])
	for t in tries:
		var before: int = sim.pos[who]
		var tx: int = before % size + int(t[0])
		var ty: int = before / size + int(t[1])
		if not in_bounds(tx, ty) or not _agent_open(ty * size + tx):
			continue
		if push_agent(who, int(t[0]), int(t[1])) and sim.pos[who] != before:
			say("You push %s aside." % name_of(who))
			end_turn()
			return true
	say("%s won't budge." % name_of(who))
	return false

var _no_turn := false        # a step that leaves the view where it was (strafing, backing up)

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
	if facing != Vector2i(dx, dy) and not _no_turn:
		facing = Vector2i(dx, dy)
		_compute_fov()
	var c := ny * size + nx
	var who: int = sim.at[c]
	if who >= 0:
		if _bump_pushes(who):
			return _bump_push(who, dx, dy)
		melee(who)
		end_turn()
		return true
	if thing_at.g(c) != -1:
		return _bump_thing(c, dx, dy)
	if crit_at.g(c) != -1:
		return _bump_crit(c, dx, dy)
	var rt: int = _reach_target(dx, dy)
	if rt >= 0 and sim.at[c] == -1:
		return act_strike(dx, dy)
	if veh_at.g(c) != -1:
		say("A %s blocks the way.  [e] to get in." % vs.KINDS[vehicles[veh_at.g(c)]["kind"]]["name"])
		return false
	if city.tiles[c] == CG.LOCKED:
		return _pick_lock(c)
	if city.tiles[c] == CG.TID["door_closed"]:
		return act_door(c)
	var hint: String = interact_hint(city.tiles[c])
	if hint != "":
		say(hint)
		return false
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
	if run and stamina >= RUN_STAMINA and stance >= WALKING:
		ran = true
		stamina -= RUN_STAMINA                 # one running move: two cells for 5 stamina
		var c2: int = c + dy * size + dx
		var nx2: int = nx + dx
		var ny2: int = ny + dy
		if in_bounds(nx2, ny2) and z_of(c2) == z_of(c) and sim.walk[c2] == 1 and sim.at[c2] == -1 and veh_at.g(c2) == -1 and not items_at.has(c) \
				and city.tiles[c2] != CG.LOCKED and city.tiles[c2] != CG.TRACK:
			pc = c2
	elif run and stamina < RUN_STAMINA:
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
	if city.tiles[pc] == CG.TID["portal"]:
		if not mission.is_empty():
			mission_leave_request = "exit"
		elif not portal.is_empty() and int(portal["cell"]) == pc:
			mission_enter_request = true
	# a step is one action (100 AP); crawling doubles it, and each dead leg adds a step's worth
	var legs_out: int = 2 - body.legs_ok()
	end_turn(AP_BASE * (1 + (1 if stance == CRAWL else 0) + legs_out))
	return true

## --- hunger and thirst (placeholder mechanics: two status effects that slow you down, to be built on later)
func hungry() -> bool:
	return sim.tick - last_ate >= HUNGER_AFTER

func thirsty() -> bool:
	return sim.tick - last_drank >= THIRST_AFTER

func speed_mult() -> float:
	return (NEED_SLOW if hungry() else 1.0) * (NEED_SLOW if thirsty() else 1.0)

## turns until the next need bites: [until hungry, until thirsty] (0 when already)
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
	_tick()

## --- waiting.  `wait_for(turns)` sets a wait going; wait_step() spends turns on it (a few at a time so the screen stays alive) and
## stops it early when you are hurt, a hostile you can see is on to you, or a need bites.  Tests and scripts use act_wait_turns().
var wait_left: int = 0
var wait_total: int = 0
var wait_why: String = ""
var wait_hp: int = 0

func wait_for(turns: int) -> bool:
	if turns <= 0 or game_over:
		return false
	if in_vehicle >= 0 and absi(int(vehicles[in_vehicle]["spd"])) > 0:
		say("You can't wait while the vehicle is moving.")
		return false
	wait_left = turns
	wait_total = turns
	wait_why = ""
	wait_hp = body.total()
	say("You wait %s." % CLK.span_text(turns))
	return true

func wait_until(hour: int) -> bool:
	var n: int = CLK.turns_until(sim.tick, hour)
	if not wait_for(n):
		return false
	say("(until %02d:00)" % hour)
	return true

func waiting() -> bool:
	return wait_left > 0

func wait_cancel(why: String = "You stop waiting.") -> void:
	if wait_left > 0:
		var done: int = wait_total - wait_left
		wait_left = 0
		wait_why = "stopped"
		say("%s  (%s passed)" % [why, CLK.span_text(done)])

func _wait_threat() -> String:
	for i in sim.near_list:
		if sim.alive[i] == 1 and hostile(i) and int(astate[i]) >= SEARCHING and fov.visible[sim.pos[i]] == 1:
			return "%s is on to you" % name_of(i)
	return ""

## run up to `max_turns` of the current wait; returns the turns spent
func wait_step(max_turns: int) -> int:
	var spent := 0
	while wait_left > 0 and spent < max_turns and not game_over:
		var hp0: int = wait_hp
		var h0: bool = hungry()
		var t0: bool = thirsty()
		wait_left -= 1
		_tick()
		spent += 1
		wait_hp = mini(wait_hp, body.total())
		var why := ""
		if body.total() < hp0 or body.total() < wait_hp:
			why = "You are hurt"
		elif hungry() and not h0:
			why = "You are hungry"
		elif thirsty() and not t0:
			why = "You are thirsty"
		else:
			why = _wait_threat()
		if why != "":
			wait_cancel("%s: you stop waiting." % why)
			break
	if wait_left == 0 and spent > 0 and wait_total > 0 and wait_why == "":
		wait_why = "done"
		say("You finish waiting.  It is %s." % time_text())
		wait_total = 0
	return spent

## the whole wait in one go (headless)
func act_wait_turns(turns: int) -> int:
	if not wait_for(turns):
		return 0
	var n := 0
	while wait_left > 0 and not game_over:
		n += wait_step(600)
	return n

## --- looking.  The look cursor moves over what you can see (or remember) up to your sight range; describe_at() says what is there.
func look_cell_ok(dx: int, dy: int) -> bool:
	var r: int = sight_radius()
	return maxi(absi(dx), absi(dy)) <= r

func describe_at(c: int) -> String:
	if c < 0 or c >= size * rows:
		return "Nothing there."
	var x: int = c % size
	var y: int = (c / size) % size
	var seen: bool = fov.visible[c] == 1
	if not seen and fov.explored[c] == 0:
		return "You can't see that far or that way."
	var bits: Array = []
	var t: int = city.tiles[c]
	bits.append(LOOK.terrain_name(t))
	if seen:
		if sim.at[c] >= 0:
			bits.append(name_of(sim.at[c]) + ((" (" + ["unaware", "suspicious", "searching", "hunting you"][int(astate[sim.at[c]])] + ")") if hostile(sim.at[c]) else "") + ((" - " + npc_wound_text(sim.at[c])) if npc_wound_text(sim.at[c]) != "" else ""))
		if c == pc:
			bits.append("you")
		if veh_at.g(c) >= 0:
			bits.append("a " + String(vs.KINDS[vehicles[veh_at.g(c)]["kind"]]["name"]))
		if thing_at.g(c) >= 0:
			bits.append("a " + String(things[thing_at.g(c)]["k"]))
		if crit_at.g(c) >= 0:
			bits.append("a " + String(critters[crit_at.g(c)]["k"]))
		if items_at.has(c):
			var names: Array = []
			for it in items_at[c]:
				names.append(item_label(it))
			bits.append("on the ground: " + ", ".join(names))
	else:
		bits.append("(remembered, out of sight)")
	var d: int = cheb(c, pc)
	return "%s, %d tile%s away." % [", ".join(bits), d, "" if d == 1 else "s"]

# ---------------------------------------------------------------- interacting
## what bumping into something you can use says (nothing happens: the interact key uses it)
func interact_hint(t: int) -> String:
	if t == CG.TID["terminal"]:
		return "A mission terminal.  Use the interact key."
	if t == CG.TID["charger"]:
		return "A charging post for cyberized people.  Use the interact key."
	if t >= CG.TID["ev_charger_nw"] and t <= CG.TID["ev_charger_se"]:
		return "A vehicle charging bank.  Park beside it and use the interact key."
	if t == CG.TID["gunsmith_table"]:
		return "A gunsmithing table.  Use the interact key."
	if t == CG.TID["mission_device"]:
		return "A machine.  Use the interact key."
	if t == CG.GLASS:
		return "A window.  Strike it to break it."
	return ""

## the north-west cell of the vehicle charging bank that cell `c` belongs to (-1 if it is not part of one)
func ev_bank_of(c: int) -> int:
	var k: int = city.tiles[c] - CG.TID["ev_charger_nw"]
	if k < 0 or k > 3:
		return -1
	return c - (k / 2) * size - (k % 2)

## everything the player could use from here: [{kind, cell, label}].  On foot that is anything in the eight cells around you; in a vehicle, the charging banks within three
## tiles of it.  A door counts whether it is open, shut or locked.
func interactables() -> Array:
	var out: Array = []
	var seen := {}
	if in_vehicle >= 0:
		for c0 in vs.cells(vehicles[in_vehicle]):
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var x: int = c0 % size + dx
					var y: int = (c0 / size) % size + dy
					if not in_bounds(x, y):
						continue
					var cc: int = (c0 / s2) * s2 + y * size + x
					var nw: int = ev_bank_of(cc)
					if nw >= 0 and not seen.has(nw):
						seen[nw] = true
						out.append({"kind": "ev", "cell": nw, "label": "Vehicle charging bank"})
		return out
	var base: int = (pc / s2) * s2
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = pc % size + dx
			var ny: int = (pc / size) % size + dy
			if not in_bounds(nx, ny):
				continue
			var c: int = base + ny * size + nx
			var t: int = city.tiles[c]
			if t == CG.DOOR or t == CG.TID["door_closed"] or t == CG.LOCKED:
				out.append({"kind": "door", "cell": c, "label": ("Locked door" if t == CG.LOCKED else ("Door (shut)" if t == CG.TID["door_closed"] else "Door (open)"))})
			elif t == CG.TID["terminal"]:
				out.append({"kind": "terminal", "cell": c, "label": "Mission terminal"})
			elif t == CG.TID["station_clock"]:
				out.append({"kind": "clock", "cell": c, "label": "Station clock"})
			elif t == CG.TID["charger"]:
				out.append({"kind": "charger", "cell": c, "label": "Charging post (implants)"})
			elif t == CG.TID["gunsmith_table"]:
				out.append({"kind": "smith", "cell": c, "label": "Gunsmithing table"})
			elif t == CG.TID["mission_device"]:
				out.append({"kind": "device", "cell": c, "label": "Machine"})
			else:
				var nw: int = ev_bank_of(c)
				if nw >= 0 and not seen.has(nw):
					seen[nw] = true
					out.append({"kind": "ev", "cell": nw, "label": "Vehicle charging bank"})
	return out

## Two clocks on the platform of every station in this zone: wall units on the outer row (the tiles against the tunnel wall), the nearest ones to the middle of the train
## and at least six tiles apart.  They read the timetable (station_clock_info).
func _place_station_clocks() -> void:
	if transit == null or not transit.any_here:
		return
	for si in transit.stop_heads.size():
		var sc: int = transit.stop_cell(si)
		if sc < 0 or sc >= total:
			continue
		var lvl_base: int = (sc / s2) * s2
		var cx: int = sc % size
		var cy: int = (sc % s2) / size
		var cands: Array = []
		for dy in range(-12, 13):
			for dx in range(-14, 15):
				var x: int = cx + dx
				var y: int = cy + dy
				if not in_bounds(x, y):
					continue
				var c: int = lvl_base + y * size + x
				if city.tiles[c] != CG.PLATFORM:
					continue
				var against_wall := false
				for dd in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
					var nx: int = x + int(dd[0])
					var ny: int = y + int(dd[1])
					if in_bounds(nx, ny) and city.tiles[lvl_base + ny * size + nx] == CG.EARTH:
						against_wall = true
				if against_wall:
					cands.append([maxi(absi(dx), absi(dy)), c])
		cands.sort_custom(func(a, b): return a[0] < b[0])
		var placed: Array = []
		for e in cands:
			var ok := true
			for pcell in placed:
				if cheb(int(e[1]), int(pcell)) < 6:
					ok = false
			if not ok:
				continue
			city.tiles[int(e[1])] = CG.TID["station_clock"]
			sim.tiles[int(e[1])] = CG.TID["station_clock"]
			sim.walk[int(e[1])] = 0
			placed.append(int(e[1]))
			if placed.size() >= 2:
				break

## the readout of the station clock on cell c: {name, turns, dwelling}
func station_clock_info(c: int) -> Dictionary:
	var best := -1
	var bd := 1 << 30
	for si in transit.stop_heads.size():
		var sc: int = transit.stop_cell(si)
		if sc < 0:
			continue
		var d: int = cheb(sc, c) + (999 if (sc / s2) != (c / s2) else 0)
		if d < bd:
			bd = d
			best = si
	if best < 0:
		return {"name": "", "turns": 0, "dwelling": false}
	var t: int = transit.turns_to(best)
	return {"name": transit.stop_name(best), "turns": t, "dwelling": t == 0}

## use one thing from interactables().  True if it took a turn or opened something.
func act_interact_with(it: Dictionary) -> bool:
	var c: int = int(it["cell"])
	match String(it["kind"]):
		"door":
			return act_door(c)
		"terminal":
			terminal_hit = c
			say("The terminal's screen wakes.")
			sfx("blip")
			return true
		"clock":
			clock_hit = c
			say("The station clock counts down to the next train.")
			sfx("blip")
			return true
		"charger":
			charger_hit = c
			say("The charging post lights its panel.")
			sfx("blip")
			return true
		"ev":
			ev_hit = c
			say("The charging bank wakes: two cables and a screen.")
			sfx("blip")
			return true
		"smith":
			smith_hit = c
			say("You clear a space on the bench.")
			sfx("blip")
			return true
		"device":
			facing = Vector2i(signi(c % size - pc % size), signi((c / size) % size - (pc / size) % size))
			return MS.use_device(self)
	return false

## open a shut door; close an open one if nothing stands in it; a locked door is picked.  Takes a turn.
func act_door(c: int) -> bool:
	var t: int = city.tiles[c]
	if t == CG.LOCKED:
		return _pick_lock(c)
	if t == CG.TID["door_closed"]:
		_set_door(c, false)
		say("You open the door.")
		_noise(c, 2)
		end_turn()
		return true
	if t == CG.DOOR:
		if sim.at[c] >= 0 or veh_at.g(c) != -1 or items_at.has(c) or thing_at.g(c) != -1 or crit_at.g(c) != -1:
			say("Something is in the doorway.")
			return false
		_set_door(c, true)
		say("You close the door.")
		end_turn()
		return true
	return false

## every door starts shut (and so opaque, which npc_sim.gd reads from the tile): you open it by walking into it or with the interact key, and anyone walking in opens it
func _shut_doors() -> void:
	var closed: int = CG.TID["door_closed"]
	var c: int = city.tiles.find(CG.DOOR)
	while c >= 0:
		city.tiles[c] = closed
		c = city.tiles.find(CG.DOOR, c + 1)

## Windows along the outside of the ground floor: on every straight outer wall of at least five tiles, windows one to three tiles wide with two to five wall tiles between
## them (the gap is fixed for a stretch of wall, so one building looks regular and another does not), never in the corner tiles, so a window never touches a door.  A window is a
## GLASS tile like those on the towers: it blocks movement and not sight, and it can be broken (strike it).  No random numbers are drawn: a hash of the stretch decides.
func _add_windows() -> void:
	var T: PackedByteArray = city.tiles
	var kind := PackedByteArray()
	kind.resize(s2)
	var c: int = T.find(CG.WALL)
	while c >= 0 and c < s2:
		var x: int = c % size
		var y: int = c / size
		if x > 0 and y > 0 and x < size - 1 and y < size - 1:
			var n: int = T[c - size]
			var so: int = T[c + size]
			var w: int = T[c - 1]
			var e: int = T[c + 1]
			if (_outside_t(n) and _inside_t(so)) or (_inside_t(n) and _outside_t(so)):
				kind[c] = 1
			elif (_outside_t(w) and _inside_t(e)) or (_inside_t(w) and _outside_t(e)):
				kind[c] = 2
		c = T.find(CG.WALL, c + 1)
	for k in [1, 2]:
		var step: int = 1 if k == 1 else size
		var start: int = kind.find(k)
		while start >= 0:
			if start - step >= 0 and kind[start - step] == k:        # not the start of a stretch: it was handled with the first cell
				start = kind.find(k, start + 1)
				continue
			var run: Array = [start]
			var cur: int = start + step
			while cur < s2 and kind[cur] == k:
				run.append(cur)
				cur += step
			_window_run(run)
			start = kind.find(k, cur)

func _outside_t(t: int) -> bool:
	return t == CG.GROUND or t == CG.ROAD or t == CG.PARK or t == CG.SAND

func _inside_t(t: int) -> bool:
	return t == CG.FLOOR or (t >= CG.EXTRA0 and t < CG.EXTRA0 + 9) or CG.FLOOR_IDS.has(t)

func _window_run(run: Array) -> void:
	var n: int = run.size()
	if n < 5:
		return
	var key: int = hash([seed_value, run[0]]) & 0x7fffffff
	var gap: int = 2 + key % 4
	var p: int = 1 + (key >> 4) % gap
	var i := 0
	while true:
		var wd: int = 1 + (hash([key, i]) & 0x7fffffff) % 3
		if p + wd > n - 1:
			break
		for q in wd:
			city.tiles[run[p + q]] = CG.GLASS
		p += wd + gap
		i += 1

## a window struck from beside it breaks: the frame stays open (you can climb through), and the noise carries
func break_window(c: int) -> void:
	city.tiles[c] = CG.TID["window_broken"]
	sim.tiles[c] = CG.TID["window_broken"]
	sim.walk[c] = 1
	say("The window shatters.")
	sfx("hit")
	_noise(c, 9)
	_witness(c, 9, -1)

func _set_door(c: int, closed: bool, refresh: bool = true) -> void:
	var t: int = CG.TID["door_closed"] if closed else CG.DOOR
	city.tiles[c] = t
	sim.tiles[c] = t
	sim.opaque[c] = 1 if closed else 0
	if closed:
		open_doors.erase(c)
	else:
		open_doors[c] = true
	if refresh and fov != null:
		_compute_fov()

## a person (or a vehicle) reaching a shut door opens it
func _doors_tick() -> void:
	var shut: int = CG.TID["door_closed"]
	for k in sim.near_list.size():
		var c: int = sim.pos[sim.near_list[k]]
		if city.tiles[c] == shut:
			_set_door(c, false)
			say_if_seen(c, "A door swings open.")

## the lock on a door: theft skill against the floor's security
func _pick_lock(c: int) -> bool:
	var z := absi(z_of(c))
	var chance := clampi(28 + lvl("engineering") * 9 - z * 2, 10, 90)
	if rng.randi() % 100 < chance:
		city.tiles[c] = CG.DOOR
		sim.tiles[c] = CG.DOOR
		sim.opaque[c] = 0
		open_doors[c] = true
		say("You work the lock open.")
		skill_up("engineering", 3 + z / 6)
		_noise(c, 5)
	else:
		say("The lock holds.  You fumble with it.")
		_noise(c, 8)
		_witness(c, 9, -1)
	end_turn()
	return true

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
	if s <= CROUCH:
		run_mode = false
	crouch = s <= CROUCH
	aim_turns = 0

## the movement prompt: 0 crawl, 1 crouch, 2 walk, 3 run (no turn passes)
func set_movement(m: int) -> void:
	match m:
		0:
			_set_stance(CRAWL)
			run_mode = false
			say("You drop flat.  Slow, but hard to see or hear.")
		1:
			_set_stance(CROUCH)
			run_mode = false
			say("You crouch low.")
		2:
			_set_stance(WALKING)
			run_mode = false
			say("You walk.")
		_:
			_set_stance(WALKING)
			run_mode = true
			say("You run: every move costs stamina and makes noise.")

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
	var cost: int = int(round((2 if has_implant("legs") else 4) * STAM_LEGACY))
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
		if sim.walk[land] == 1 and sim.at[land] == -1 and veh_at.g(land) == -1 and city.tiles[land] != CG.LOCKED:
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
		if veh_at.g(c) != -1:
			v = 40 if crouched else 28
		elif (t in CG.LOW_COVER and t < CG.EXTRA0) or thing_at.g(c) != -1:
			v = 32 if crouched else 20           # street cover (crates, dumpsters, planters, railings, loose things): crouching behind it helps
		elif t == CG.WALL:
			v = 15
		best = maxi(best, v)
	return best

## furniture, doors and windows next to the target on the shooter's side each stop a shot at a flat chance, whatever the shooter's skill (to be refined):
## furniture and doors 25%, windows 50%.  Returns the best of the three neighbours, as a percent; 0 for none.
const SHIELD_FURNITURE := 25
const SHIELD_DOOR := 25
const SHIELD_WINDOW := 50
func shield_vs(from: int, to: int) -> Dictionary:
	var tx: int = to % size
	var ty: int = to / size
	var sx: int = signi(from % size - tx)
	var sy: int = signi(from / size - ty)
	var best := {"pct": 0, "what": ""}
	if sx == 0 and sy == 0:
		return best
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
		var what := ""
		if t == CG.GLASS:
			v = SHIELD_WINDOW
			what = "window"
		elif t == CG.DOOR or t == CG.TID["door_closed"] or t == CG.LOCKED:
			v = SHIELD_DOOR
			what = "door"
		elif t >= CG.EXTRA0 and t in CG.LOW_COVER:
			v = SHIELD_FURNITURE
			what = "furniture"
		if v > int(best["pct"]):
			best = {"pct": v, "what": what}
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

## how far you can see, in tiles.  Doubled from 18 to 36 (2026-10-18); implants and scopes will add to it later through sight_bonus().
const BASE_SIGHT := 30
func sight_bonus() -> int:
	return 0

func sight_radius() -> int:
	return BASE_SIGHT + sight_bonus()

## let go of everything that points back at this game, so a game that has been put away is freed (these helpers and the game hold each other, and a loop
## of references is never freed; a 1536 city is about 3 GB).  The game is not used afterwards.
func dispose() -> void:
	if sim != null and sim.get("com") != null:
		sim.com.wait_ready()                    # (its route grid may still be building on a thread)
		sim.com = null
	sim = null
	transit = null
	eco = null
	barter = null
	vs = null
	fov = null
	world = null

func _compute_fov() -> void:
	fov.compute(pc % size, pc / size, sight_radius(), vision_arc(), facing.x, facing.y)

## turn the view one step (+1 clockwise, -1 anticlockwise) of the eight directions; takes no time
func turn_step(dir: int) -> void:
	var k: int = DIR8.find([facing.x, facing.y])
	if k < 0:
		k = 4
	var d: Array = DIR8[(k + dir + 8) % 8]
	facing = Vector2i(d[0], d[1])
	_compute_fov()

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
var imp_dur: Dictionary = {}                   # implant id -> armor durability left (absent = as new)
var melee_arts: Array = []                     # learned melee arts: "parry", "riposte" (see _melee_arts_on_miss); empty until the player learns some
var bless_left: int = 0                        # turns of blessing left: a little luck (+6% to hit, +4% to dodge a blade)
const HUNGER_AFTER := 24 * CLK.HOUR             # turns (a turn is six seconds) without food before you are Hungry: a full stomach is 2,500 kcal = 24 hours
const THIRST_AFTER := 4 * CLK.HOUR              # ... without a drink before you are Thirsty: 500 mL of water = 4 hours
const KCAL_FULL := 2500
const ML_FULL := 500
const TURNS_PER_KCAL := float(HUNGER_AFTER) / float(KCAL_FULL)       # 5.76 turns (34.6 s) of not being hungry per kcal
const TURNS_PER_ML := float(THIRST_AFTER) / float(ML_FULL)           # 4.8 turns (28.8 s) of not being thirsty per mL of water
const NEED_SLOW := 0.8                          # each of Hungry / Thirsty cuts walking speed to 80% (they stack)
var last_ate: int = 0                           # sim.tick of the last meal and the last drink
var last_drank: int = 0
var ap: int = 2 * AP_BASE - 1                  # your action points banked: every action pays for itself, turns pass until you can afford the next
var _was_hungry: bool = false
var _was_thirsty: bool = false
var drunk_left: int = 0                        # turns of drink left: -8% to hit
var aim_last: int = -10
var aim_frac: float = 0.0                      # progress towards the next aim level
var _free_swing := false                       # a free counter-attack is in progress (so a fumble inside it cannot chain)
var apn: PackedInt32Array                      # every person's banked action points (only fighters use them)
var stamn: PackedByteArray                     # every person's stamina in percent, brought up to date when they fight (stamt = the turn it was last brought up)
var stamt: PackedInt32Array
var limbn: PackedInt32Array                    # six limb health values per person (BODY.LIMBS order), -1 = untouched and still full: filled in on the first wound
var aimn: PackedByteArray                      # every gunman's banked aim points (they aim for a turn, then fire for half a turn)
var last_roll: Dictionary = {}                 # the last melee roll, for the HUD line and the tests: {who, nat, total, outcome, loc, dmg}
const ARMOR_TYPES := ["phys"]

func limb_name(l: String) -> String:
	return BODY.NAME[l]

func _imp_active(d: Dictionary) -> bool:
	return power_left() > 0.0 and body.group_ok(body.group_of_part(String(d["part"]))) and int(imp_dur.get(d["id"], IMP.dur(d))) > 0

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
		if implants.get(d["id"], false) and power_left() > 0.0 and d.has("armor") and body.ok(limb) and (d["armor_group"] == grp or d["armor_group"] == "all"):
			out.append({"item": null, "id": d["id"], "name": d["name"], "phys": int(d["armor"]), "left": int(imp_dur.get(d["id"], int(d["dur"]))), "max": int(d["dur"])})
	if nano_armor() > 0:
		out.append({"item": null, "id": "", "name": "Plating hack", "phys": nano_armor(), "left": 1 << 20, "max": 1 << 20})
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
		if implants.get(d["id"], false) and power_left() > 0.0 and d.has("armor"):
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
			elif p["id"] != "":
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

func _limb_hit(l: String, n: int) -> void:
	var avail: int = int(body.hp[l])
	var r: Dictionary = body.damage(l, n)
	if n > avail:
		_implants_take(l, n - avail)
	if r["broke"]:
		if l == "head" or l == "chest":
			say("Your %s is destroyed." % limb_name(l))
		else:
			say("Your %s is DISABLED!  %s" % [limb_name(l), _limb_effect(l)])
	if r["dead"]:
		_die_check()

## damage that gets past a limb's own health lands on the implants fitted in it, each wearing down its durability until it is wrecked
func _implants_take(l: String, n: int) -> void:
	var grp: String = BODY.GROUP[l]
	for d in IMP.ALL:
		if n <= 0:
			break
		if not implants.get(d["id"], false) or body.group_of_part(String(d["part"])) != grp:
			continue
		var left: int = int(imp_dur.get(d["id"], IMP.dur(d)))
		if left <= 0:
			continue
		var take: int = mini(left, n)
		imp_dur[d["id"]] = left - take
		n -= take
		if left - take == 0:
			say("Your %s is wrecked!" % d["name"])

func _limb_effect(l: String) -> String:
	if BODY.GROUP[l] == "legs":
		return "You limp: every step costs extra time." if body.legs_ok() == 1 else "You can only drag yourself along."
	return "Two-handed weapons are out and your aim suffers." if body.arms_ok() == 1 else "You can't hold a weapon."

## the player takes a hit: pick a limb, armor takes its flat share, the limb and the pool take the rest
func player_hurt(dmg: int, msg: String, dtype: String = "phys", limb: String = "", pen: int = 0) -> void:
	if in_mech():
		var through: int = dmg / 5
		if through > 0:
			_limb_hit(body.pick(rng), through)
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
		skill_up("grit", 2 + through2 / 4)
		say("%s in the %s (-%d%s)." % [msg, limb_name(l), through2, (", armor soaks %d" % int(ab["absorbed"])) if int(ab["absorbed"]) > 0 else ""])
	else:
		say("%s in the %s, but your armor stops it (%d)." % [msg, limb_name(l), int(ab["absorbed"])])

## bullets can only be dodged with high-grade implants (grade 3 and up)
## your chance to twist away from a round, rolled and written out
func _twist_roll() -> bool:
	var chance: int = player_bullet_dodge()
	var r: int = rng.randi() % 100
	if chance > 0:
		_math("Twisting aside from the round: %d%% chance, rolled %d: %s" % [chance, r, "DODGED" if r < chance else "no"])
	return r < chance

func player_bullet_dodge() -> int:
	var d: float = imp_sum("dodge_bullet") + SK.bullet_dodge(lvl("dodge"))
	if body.legs_ok() < 2:
		d *= 0.5 if body.legs_ok() == 1 else 0.0
	return clampi(int(d), 0, 40)

## your Dodge in skill points for the melee roll: the skill, wired reflexes (10% of a blade dodged = 2 points), crouching and a blessing (1 each);
## a bad leg halves it and two take it away
func player_dodge_pts() -> int:
	var d: float = float(lvl("dodge")) + imp_sum("dodge_melee") / 5.0 + (1.0 if crouch else 0.0) + (1.0 if bless_left > 0 else 0.0)
	if body.legs_ok() < 2:
		d *= 0.5 if body.legs_ok() == 1 else 0.0
	return int(d)

## a melee blow lands on you: a place on the body (torso 30%, head 10%, limbs 15% each), your armor there takes its flat share, then your Grit,
## and the rest goes to that limb's health (and, once the limb is gone, to the implants in it).  A critical hit was already doubled by the caller.
func player_melee_hurt(dmg: int, msg: String, pen: int, crit: bool) -> void:
	if in_mech():
		player_hurt(dmg, msg, "phys", "", pen)
		return
	var l: String = body.pick_melee(rng)
	var ab: Dictionary = absorb(l, dmg, pen, "phys")
	var grit: int = lvl("grit")
	var through: int = maxi(0, int(ab["through"]) - grit)
	_math("The blow of %d on your %s: armor soaks %d, Grit %d soaks %d: %d goes through" % [dmg, limb_name(l), int(ab["absorbed"]), grit, mini(grit, int(ab["through"])), through])
	for b in ab["broke"]:
		say("Your %s breaks!" % b)
	last_roll["dmg"] = through
	last_roll["loc"] = l
	var tail: String = (" - a critical hit" if crit else "")
	if through > 0:
		sfx("hurt")
		_limb_hit(l, through)
		skill_up("grit", 2 + through / 4)
		var soaked: int = int(ab["absorbed"]) + mini(grit, int(ab["through"]))
		say("%s in the %s (-%d%s)%s." % [msg, limb_name(l), through, (", armor and grit soak %d" % soaked) if soaked > 0 else "", tail])
	else:
		say("%s in the %s, but armor and grit stop it%s." % [msg, limb_name(l), tail])

## NPCs: armor, and dodge.  Bratva carry little, the NAP wear vests, Nasim's killers are wired (and the only ones who can dodge bullets).
# ---- NPC body parts: the same six limbs as yours (src/body.gd), scaled to the person's health (a 60-point person has exactly your limbs)
## only the wounded are saved: {person: [six limb values]}
func _limbs_save() -> Dictionary:
	var out := {}
	for i in sim.n:
		if limbn[i * 6] != -1:
			out[str(i)] = [limbn[i * 6], limbn[i * 6 + 1], limbn[i * 6 + 2], limbn[i * 6 + 3], limbn[i * 6 + 4], limbn[i * 6 + 5]]
	return out

func npc_limb_max(i: int, l: String) -> int:
	return maxi(3, int(round(float(BODY.BASE[l]) * float(hpmax[i]) / 60.0)))

func _limb_slot(l: String) -> int:
	return BODY.LIMBS.find(l)

func _npc_limbs_init(i: int) -> void:
	if limbn[i * 6] != -1:
		return
	for k in 6:
		limbn[i * 6 + k] = npc_limb_max(i, BODY.LIMBS[k])

func npc_limb_hp(i: int, l: String) -> int:
	var v: int = limbn[i * 6 + _limb_slot(l)]
	return npc_limb_max(i, l) if (limbn[i * 6] == -1) else v

func npc_limb_ok(i: int, l: String) -> bool:
	return npc_limb_hp(i, l) > 0

func npc_arms_ok(i: int) -> int:
	return (1 if npc_limb_ok(i, "l_arm") else 0) + (1 if npc_limb_ok(i, "r_arm") else 0)

func npc_legs_ok(i: int) -> int:
	return (1 if npc_limb_ok(i, "l_leg") else 0) + (1 if npc_limb_ok(i, "r_leg") else 0)

## a hurt head costs accuracy, as it does for you (under half health)
func npc_head_hurt(i: int) -> bool:
	return limbn[i * 6] != -1 and npc_limb_hp(i, "head") * 2 < npc_limb_max(i, "head")

## a blow or bullet lands on one of their limbs.  A limb at 0 is disabled (their arms drop their grip, their legs slow them and halve their dodge);
## a head or chest at 0 kills.  Returns true if that killed them.  The caller still takes the damage off their overall health, as for you.
func npc_limb_hit(i: int, loc: String, dmg: int) -> bool:
	if loc == "" or dmg <= 0 or sim.alive[i] == 0:
		return false
	_npc_limbs_init(i)
	var k: int = _limb_slot(loc)
	var before: int = limbn[i * 6 + k]
	var after: int = maxi(0, before - dmg)
	limbn[i * 6 + k] = after
	if before > 0 and after == 0:
		if loc == "head" or loc == "chest":
			say_if_seen(sim.pos[i], "%s is killed by a blow to the %s." % [name_of(i), BODY.NAME[loc]])
			kill(i)
			return true
		say_if_seen(sim.pos[i], "%s's %s is disabled!  %s" % [name_of(i), BODY.NAME[loc], _npc_limb_effect(i, loc)])
	return false

func _npc_limb_effect(i: int, loc: String) -> String:
	if BODY.GROUP[loc] == "legs":
		return "They limp." if npc_legs_ok(i) == 1 else "They can only drag themselves."
	return "They fight one-handed." if npc_arms_ok(i) == 1 else "They cannot hold a weapon."

## their Dodge in skill points, halved on one good leg and gone on none (as yours)
func npc_dodge_pts(i: int) -> int:
	var d: int = npc_lvl(i, "dodge")
	var lg: int = npc_legs_ok(i)
	return d if lg == 2 else (d / 2 if lg == 1 else 0)

## the wounds worth seeing, for the look text
func npc_wound_text(i: int) -> String:
	if limbn[i * 6] == -1:
		return ""
	var bits: Array = []
	for l in BODY.LIMBS:
		var hp_l: int = npc_limb_hp(i, l)
		if hp_l <= 0:
			bits.append("%s disabled" % BODY.NAME[l])
		elif hp_l * 2 < npc_limb_max(i, l):
			bits.append("%s hurt" % BODY.NAME[l])
	return ", ".join(bits)

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
	return SK.bullet_dodge(npc_dodge_pts(i))

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

# ---- melee speed: every strike costs 100 action points whatever is in the hand (a turn earns ap_rate(), see end_turn), and tires you
## by one stamina point per kilogram of weapon (bare hands and implanted blades weigh nothing)
func swing_stamina(ms: Dictionary) -> int:
	if wield == null or not wield.def.has("melee") or ms.get("mantis", false) or ms.get("verb", "") == "kick":
		return 0
	return maxi(1, int(round(float(wield.def.get("weight_g", 1000)) / 1000.0)))

func _roll_2d10() -> int:
	return rng.randi_range(1, 10) + rng.randi_range(1, 10)

## combat maths shown in the message lines (for now, so the numbers can be understood and tuned): every roll and every damage step is written out
const SHOW_MATH := true

func _math(msg: String) -> void:
	if SHOW_MATH:
		say("[color=#8fb0cc]  " + msg + "[/color]")

## "+4 Melee -2 Dodge": the parts of a roll that are not 0, signed
func _terms(parts: Array) -> String:
	var out: Array = []
	for p in parts:
		var v: int = int(p[1])
		if v != 0:
			out.append("%+d %s" % [v, p[0]])
	return " ".join(out) if not out.is_empty() else "+0"

func _outcome_word(out: String) -> String:
	return {"cmiss": "FUMBLE", "crit": "CRITICAL HIT", "hit": "HIT", "miss": "MISS"}.get(out, out)

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
		var dmg: int = rng.randi_range(int(ms["dmg"][0]), int(ms["dmg"][1])) + lvl(melee_skill_id())
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
	_consume_one(it)
	var l: String = body.worst()
	body.heal(l, maxi(8, int(body.mx[l]) / 3))
	var spread: int = heal_body(25)
	say("You slap on a trauma patch: your %s mended and %d more points of wounds closed." % [limb_name(l), spread])
	end_turn()
	return true

## take one of a stack out of whatever holds it
func _consume_one(it) -> void:
	if it.count > 1:
		it.count -= 1
		return
	if not inv.remove(it) and items_at.has(pc) and items_at[pc].has(it):
		items_at[pc].erase(it)

## --- food and drink.  A meal's kcal and a drink's millilitres are turned into time: 2,500 kcal = 24 hours before you are Hungry, 500 mL of water = 4 hours before you are Thirsty.
## A full stomach holds exactly that much, so eating more than you have room for is wasted.
func food_left() -> int:
	return clampi(HUNGER_AFTER - (sim.tick - last_ate), 0, HUNGER_AFTER)

func drink_left() -> int:
	return clampi(THIRST_AFTER - (sim.tick - last_drank), 0, THIRST_AFTER)

## a need's "time of last fill" after adding `gain` turns of supply, never past full
func _filled(span: int, left: int, gain: int) -> int:
	return sim.tick - (span - mini(span, left + gain))

func kcal_turns(kcal: int) -> int:
	return int(round(float(kcal) * TURNS_PER_KCAL))

func ml_turns(ml: int, hydr: float = 1.0) -> int:
	return int(round(float(ml) * hydr * TURNS_PER_ML))

## the effect of a meal or drink: hunger and thirst clocks, health, stamina; strong drink dulls the aim for a while.  Returns the turns of food and drink it added.
var last_healed: int = 0                       # health points the last meal actually restored (food cannot heal what is not hurt, or a disabled limb)
var last_stam: int = 0

func eat_now(it) -> Array:
	var f: Dictionary = it.def.get("food", {})
	var got_food: int = 0
	var got_drink: int = 0
	var kcal: int = int(f.get("kcal", 0))
	if kcal > 0:
		got_food = kcal_turns(kcal)
		last_ate = _filled(HUNGER_AFTER, food_left(), got_food)
	if f.get("drink", false):
		got_drink = ml_turns(int(f.get("ml", 0)), float(f.get("hydr", 1.0)))
		last_drank = _filled(THIRST_AFTER, drink_left(), got_drink)
	last_healed = 0
	if int(f.get("hp", 0)) > 0:
		last_healed = heal_body(int(f["hp"]))
	var stam0: int = stamina
	stamina = mini(STAMINA_MAX, stamina + int(round(float(f.get("stam", 0)) * STAM_LEGACY)))
	last_stam = stamina - stam0
	if f.get("alcohol", false):
		drunk_left = mini(240 * CLK.MIN, drunk_left + 60 * CLK.MIN)
	return [got_food, got_drink]

func _eat_report(it, before_food: int, before_drink: int) -> String:
	var f: Dictionary = it.def.get("food", {})
	var parts: Array = []
	if int(f.get("kcal", 0)) > 0:
		parts.append("%d kcal, food for %s more" % [int(f["kcal"]), CLK.span_text(food_left() - before_food)] if food_left() > before_food else "%d kcal wasted: you are full" % int(f["kcal"]))
	if f.get("drink", false) and int(f.get("ml", 0)) > 0:
		parts.append("%d mL, water for %s more" % [int(f["ml"]), CLK.span_text(drink_left() - before_drink)] if drink_left() > before_drink else "%d mL wasted: you are not thirsty" % int(f["ml"]))
	if int(f.get("hp", 0)) > 0:
		parts.append("health +%d" % last_healed if last_healed >= int(f["hp"]) else "health +%d of %d (%s)" % [last_healed, int(f["hp"]), "the rest of your damage is in disabled limbs: food cannot mend those, a doctor can" if _disabled_hurt() else "all that was hurt"])
	if int(f.get("stam", 0)) > 0:
		var offered: int = int(round(float(f["stam"]) * STAM_LEGACY))
		parts.append("stamina +%d" % last_stam if last_stam >= offered else "stamina +%d of %d (you were rested)" % [last_stam, offered])
	return ", ".join(parts)

func act_eat(it) -> bool:
	var f: Dictionary = it.def.get("food", {})
	if f.is_empty():
		say("You can't eat that.")
		return false
	var bf: int = food_left()
	var bd: int = drink_left()
	_consume_one(it)
	eat_now(it)
	say("You %s the %s.  (%s)" % ["drink" if f.get("drink", false) else "eat", it.def["name"], _eat_report(it, bf, bd)])
	sfx("pick")
	end_turn()
	return true

## --- the consume menu: food, drink and bottled water in your pack, or within one tile of you (the ground around you)
## [{item, parent, cell, label, kind}] kind: "food" | "drink" | "water"
func consumables() -> Array:
	var out: Array = []
	for e in inventory_list():
		_add_consumable(out, e["item"], e["parent"], -1, "in your pack" if e["depth"] > 0 or e["where"] == "worn" else e["where"])
	var cx: int = pc % size
	var cy: int = (pc / size) % size
	var base: int = (pc / (size * size)) * size * size
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x: int = cx + dx
			var y: int = cy + dy
			if x < 0 or y < 0 or x >= size or y >= size:
				continue
			var c: int = base + y * size + x
			if not items_at.has(c) or (dx != 0 or dy != 0) and not fov.visible[c] == 1:
				continue
			for it in items_at[c]:
				_collect_ground(out, it, null, c, "here" if (dx == 0 and dy == 0) else "next to you")
	return out

func _collect_ground(out: Array, it, parent, cell: int, where: String) -> void:
	_add_consumable(out, it, parent, cell, where)

func _add_consumable(out: Array, it, parent, cell: int, where: String) -> void:
	if it.has_tag("food"):
		out.append({"item": it, "parent": parent, "cell": cell, "kind": "drink" if it.def.get("food", {}).get("drink", false) else "food", "where": where})
	elif it.def.has("bottle") and it.fill > 0:
		out.append({"item": it, "parent": parent, "cell": cell, "kind": "water", "where": where})

func consumable_label(e: Dictionary) -> String:
	var it = e["item"]
	var f: Dictionary = it.def.get("food", {})
	match e["kind"]:
		"water":
			return "water bottle, %d mL  (%s of thirst)" % [it.fill, CLK.span_text(ml_turns(it.fill))]
		"drink":
			return "%s%s  (%d mL, %d kcal)" % [it.def["name"], " x%d" % it.count if it.count > 1 else "", int(f.get("ml", 0)), int(f.get("kcal", 0))]
	return "%s%s  (%d kcal)" % [it.def["name"], " x%d" % it.count if it.count > 1 else "", int(f.get("kcal", 0))]

## remove one of an item from wherever it is (your pack, or the ground)
func _take_one(e: Dictionary) -> void:
	var it = e["item"]
	if it.count > 1:
		it.count -= 1
		return
	if e["cell"] >= 0:
		if items_at.has(e["cell"]):
			items_at[e["cell"]].erase(it)
			if items_at[e["cell"]].is_empty():
				items_at.erase(e["cell"])
	else:
		_consume_one(it)

func act_consume(e: Dictionary) -> bool:
	var it = e["item"]
	if e["kind"] == "water":
		var room: int = int(ceil(float(THIRST_AFTER - drink_left()) / TURNS_PER_ML))
		if room < 25:
			say("You are not thirsty: you are carrying all the water you can hold (%s)." % CLK.span_text(drink_left()))
			return false
		var ml: int = mini(it.fill, room)
		it.fill -= ml
		last_drank = _filled(THIRST_AFTER, drink_left(), ml_turns(ml))
		say("You drink %d mL of water.  (water for %s more; %s in all)" % [ml, CLK.span_text(ml_turns(ml)), CLK.span_text(drink_left())])
		sfx("pick")
		end_turn()
		return true
	var f: Dictionary = it.def.get("food", {})
	if f.is_empty():
		say("You can't consume that.")
		return false
	var bf: int = food_left()
	var bd: int = drink_left()
	_take_one(e)
	eat_now(it)
	say("You %s the %s.  (%s)" % ["drink" if e["kind"] == "drink" else "eat", it.def["name"], _eat_report(it, bf, bd)])
	sfx("pick")
	end_turn()
	return true

func act_use_charm(it) -> bool:
	var u: Dictionary = it.def.get("use", {})
	if u.is_empty():
		return false
	_consume_one(it)
	if u.has("hp"):
		heal_body(int(u["hp"]))
	if u.has("bless"):
		bless_left = maxi(bless_left, int(u["bless"]) * CLK.MIN)       # data gives minutes
	say(String(u.get("msg", "You use it.")))
	end_turn()
	return true

## put armor or a pocket item on: it takes its slot, and whatever was there goes into your pack (or the floor)
func act_wear(it) -> bool:
	var ref: Dictionary = inv.find(it)
	if not ref.is_empty() and ref["t"] == "eq":
		say("You are already wearing that.")
		return false
	if ref.is_empty():
		if not inv.stow(it):
			say("No room for the %s." % item_label(it))
			return false
	if not inv.auto_equip(it):
		say(inv.last_err)
		return false
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
	for k in (["parry", "stun", "sneak"] if specials_on else []):
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
		if t == CG.WALL or t == CG.EARTH or t == CG.LOCKED or t == CG.GLASS or t == CG.TID["door_closed"]:
			return false
	return true

## one strike at person i from where you stand, with whatever you hold.  dist is how far away they are (reach weapons).
## The hit roll is 2d10 + your Melee (or Unarmed) skill - their Dodge: 11 or more hits; a natural 19-20, or a total of 20 + their Grit, is a critical
## hit; a natural 2 is a fumble that hands them a free counter-attack.  Someone unaware, surrendered or stunned cannot dodge and is always hit.
## A hit lands on a random place (torso 30%, head 10%, each limb 15%); damage is the weapon roll + your skill - their armor - their Grit.
func melee(i: int, dist: int = 1) -> void:
	if sim.alive[i] == 0:
		return
	var ms: Dictionary = melee_stats()
	var msk: String = melee_skill_id()
	var sneak := astate[i] == UNAWARE or astate[i] == RETURNING
	var helpless: bool = sneak or astate[i] == SURRENDERED or stun[i] > 0
	var atk: int = lvl(msk) + int(round(float(ms.get("acc", 0)) / 5.0)) - (dist - 1) - (2 if body.arms_ok() < 2 else 0) + (1 if bless_left > 0 else 0)
	var dodge: int = 0 if helpless else npc_dodge_pts(i)
	var grit_t: int = npc_lvl(i, "grit")
	var nat: int = _roll_2d10()
	var total: int = nat + atk - dodge
	var out: String = SK.melee_outcome(nat, total, grit_t)
	if helpless and out == "miss":
		out = "hit"
	var loc: String = body.pick_melee(rng)
	_math("You attack %s: dice %d %s = %d.  Hits at %d, critical at 19+ or %d (their Grit %d), fumble on 2.  %s%s" % [name_of(i), nat,
		_terms([[msk.capitalize(), lvl(msk)], ["weapon", int(round(float(ms.get("acc", 0)) / 5.0))], ["reach", -(dist - 1)], ["one arm", -2 if body.arms_ok() < 2 else 0],
		["blessing", 1 if bless_left > 0 else 0], ["their Dodge", -dodge]]), total, SK.HIT_AT, 20 + grit_t, grit_t, _outcome_word(out), " (they cannot dodge)" if helpless else ""])
	last_roll = {"who": "you", "target": i, "nat": nat, "total": total, "outcome": out, "loc": loc, "dmg": 0}
	stamina = maxi(0, stamina - swing_stamina(ms))
	if out == "cmiss":
		say("You fumble your %s at %s!" % [String(ms.get("verb", "blow")), name_of(i)])
		_alert(i)
		_free_npc_swing(i)
		return
	if out == "miss":
		if dodge > 0 and total + dodge >= SK.HIT_AT:
			say("%s dodges your %s." % [name_of(i), String(ms.get("verb", "blow"))])
		else:
			say("You miss %s." % name_of(i))
		_alert(i)
		return
	var crit: bool = out == "crit"
	var wmax: int = int(ms["dmg"][1])
	var skill_bonus: int = lvl(msk) + (2 if msk == "unarmed" and discipline("iron_fist") else 0)
	var wroll: int = rng.randi_range(int(ms["dmg"][0]), wmax)
	var dmg: int = SK.melee_base(wroll, wmax, skill_bonus, crit)
	_math("Damage: %s = %d" % [("weapon maximum %d (critical) + skill %d, doubled" % [wmax, skill_bonus]) if crit else ("weapon roll %d (%d-%d) + skill %d" % [wroll, int(ms["dmg"][0]), wmax, skill_bonus]), dmg])
	var behind: bool = sneak and cone_factor(i, pc) == 0.0
	if behind:
		dmg *= int(ms.get("sneak", 4))
		_math("From behind: x%d = %d" % [int(ms.get("sneak", 4)), dmg])
		say("You strike %s from behind!" % name_of(i))
	elif sneak:
		dmg *= 2
		_math("Unready: x2 = %d" % dmg)
		say("You catch %s unready." % name_of(i))
	if specials_on and dist > 1 and ms.get("brace", false) and astate[i] == HUNTING:
		dmg = dmg * 3 / 2
		say("You meet the charge on the point.")
	_silent = behind
	_melee_damage(i, dmg, ms, crit, loc)
	_silent = false
	if sim.alive[i] == 1:
		_melee_effects(i, ms)
		if specials_on and msk == "unarmed" and discipline("pressure_points") and rng.randf() < 0.2:
			stun[i] = 3
			sim.ctl[i] = 1
			say("%s is staggered by a nerve strike." % name_of(i))
	skill_up(msk, 3 if hpmax[i] >= 40 else 1)
	if specials_on and ms.get("sweep", false):
		_sweep_others(i, ms)

## damage to a person from a melee blow: their armor (less the weapon's piercing), then their Grit, both flat
func _melee_damage(i: int, dmg: int, ms: Dictionary, crit: bool = false, loc: String = "") -> void:
	var pen: int = int(ms.get("pen", 1 if int(ms["dmg"][1]) >= 14 else 0))
	var cut: int = mini(dmg, maxi(0, npc_armor(i) - pen))
	if cut > 0 and cut >= dmg:
		say("Your %s glances off %s's armor." % [String(ms.get("verb", "blow")), name_of(i)])
		_alert(i)
		return
	var ngrit: int = npc_lvl(i, "grit")
	_math("%s: armor %d (the weapon pierces %d) takes %d, Grit %d takes %d: %d goes through" % [name_of(i), npc_armor(i), pen, cut, ngrit, mini(ngrit, maxi(0, dmg - cut)), maxi(0, dmg - cut - ngrit)])
	dmg = maxi(0, dmg - cut - ngrit)
	if dmg <= 0:
		say("%s shrugs off your %s." % [name_of(i), String(ms.get("verb", "blow"))])
		_alert(i)
		return
	last_roll["dmg"] = dmg
	if npc_limb_hit(i, loc, dmg):
		return
	hpn[i] -= dmg
	if hpn[i] <= 0:
		kill(i)
		return
	var where: String = (" in the " + BODY.NAME[loc]) if loc != "" else ""
	say("You %s %s%s (%d)%s." % [ms.get("verb", "hit"), name_of(i), where, dmg, " - a critical hit" if crit else ""])
	_alert(i)

## the fumbled side's opponent gets one free strike (no action points): the player's fumble gives the target a swing at you
func _free_npc_swing(i: int) -> void:
	if _free_swing or sim.alive[i] == 0 or game_over or cheb(sim.pos[i], pc) > 1:
		return
	_free_swing = true
	say("%s hits back while you recover!" % name_of(i))
	_npc_melee_attack(i)
	_free_swing = false

func _free_player_swing(i: int) -> void:
	if _free_swing or sim.alive[i] == 0 or game_over or cheb(sim.pos[i], pc) > 1:
		return
	_free_swing = true
	say("You seize the opening!")
	melee(i)
	_free_swing = false

## the weapon an NPC fights with, as a melee-stats dictionary, and the skill it uses
func _npc_swing_stats(i: int) -> Dictionary:
	var nm: Dictionary = npc_melee_stats(i)
	if nm.is_empty():
		return {"dmg": [3, 6], "acc": 0, "verb": "hit", "skill": "unarmed", "kg": 0}
	var out: Dictionary = nm.duplicate()
	out["skill"] = "melee"
	out["kg"] = maxi(1, int(round(float(db.defs[npc_melee_id(i)].get("weight_g", 1000)) / 1000.0)))
	return out

## an NPC strikes the player.  Same rules as yours: 2d10 + their skill - your Dodge, a locational hit, weapon roll + skill - your armor - your Grit.
func _npc_melee_attack(i: int) -> void:
	if npc_arms_ok(i) == 0:
		say_if_seen(sim.pos[i], "%s flails with no good arm." % name_of(i))
		return
	var nm: Dictionary = _npc_swing_stats(i)
	var atk: int = npc_lvl(i, String(nm["skill"])) + int(round(float(nm.get("acc", 0)) / 5.0)) - (2 if npc_arms_ok(i) < 2 else 0) - (1 if npc_head_hurt(i) else 0)
	var dodge: int = player_dodge_pts()
	var nat: int = _roll_2d10()
	var total: int = nat + atk - dodge
	var out: String = SK.melee_outcome(nat, total, lvl("grit"))
	_math("%s attacks you: dice %d %s = %d.  Hits at %d, critical at 19+ or %d (your Grit %d), fumble on 2.  %s" % [name_of(i), nat,
		_terms([[String(nm["skill"]).capitalize(), npc_lvl(i, String(nm["skill"]))], ["weapon", int(round(float(nm.get("acc", 0)) / 5.0))], ["one arm", -2 if npc_arms_ok(i) < 2 else 0],
		["head wound", -1 if npc_head_hurt(i) else 0], ["your Dodge", -dodge]]), total, SK.HIT_AT, 20 + lvl("grit"), lvl("grit"), _outcome_word(out)])
	last_roll = {"who": name_of(i), "target": -1, "nat": nat, "total": total, "outcome": out, "loc": "", "dmg": 0}
	npc_stamina_spend(i, int(nm["kg"]))
	if out == "cmiss":
		say("%s fumbles the swing!" % name_of(i))
		_free_player_swing(i)
		return
	if out == "miss":
		if dodge > 0 and total + dodge >= SK.HIT_AT:
			say("You slip %s's blow." % name_of(i))
			skill_up("dodge", 2 + npc_lvl(i, "melee") / 2)
			_melee_arts_on_miss(i, "dodge")
		else:
			say("%s swings and misses." % name_of(i))
		return
	var parry: int = parry_chance(npc_melee_stats(i))
	var parry_roll: int = rng.randi() % 100
	if parry > 0:
		_math("Your parry: %d%% chance, rolled %d: %s" % [parry, parry_roll, "PARRIED" if parry_roll < parry else "no parry"])
	if parry_roll < parry:
		say("You turn %s's blow aside." % name_of(i))
		_melee_arts_on_miss(i, "parry")
		return
	var crit: bool = out == "crit"
	var wmax: int = int(nm["dmg"][1])
	var nroll: int = rng.randi_range(int(nm["dmg"][0]), wmax)
	var dmg: int = SK.melee_base(nroll, wmax, npc_lvl(i, String(nm["skill"])), crit)
	_math("Their damage: %s = %d" % [("weapon maximum %d (critical) + skill %d, doubled" % [wmax, npc_lvl(i, String(nm["skill"]))]) if crit else ("weapon roll %d (%d-%d) + skill %d" % [nroll, int(nm["dmg"][0]), wmax, npc_lvl(i, String(nm["skill"]))]), dmg])
	var vb: String = String(nm.get("verb", "hit"))
	var what: String = "%s%s you" % [vb, "es" if vb.ends_with("s") or vb.ends_with("sh") or vb.ends_with("ch") or vb.ends_with("x") else "s"]
	player_melee_hurt(dmg, "%s %s" % [name_of(i), what], int(nm.get("pen", 1 if wmax >= 14 else 0)), crit)

func _melee_effects(i: int, ms: Dictionary) -> void:
	if not specials_on:
		return
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
			end_turn()
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
		if crit_at.g(c2) != -1:
			facing = Vector2i(dx, dy)
			crit_hit(crit_at.g(c2), dmg)
			end_turn()
			return true
		if thing_at.g(c2) != -1:
			facing = Vector2i(dx, dy)
			thing_hit(thing_at.g(c2), dmg)
			end_turn()
			return true
		if dist == 1 and city.tiles[c2] == CG.GLASS and c2 < s2:
			facing = Vector2i(dx, dy)
			break_window(c2)
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
	if f == CIV:
		provoked[i] = 1
	if f == CIV:
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
	energy[i] = npc_energy(i)                    # what was left in them when they died stays with the body
	provoked.erase(i)
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
	_leave_corpse(i)
	stun[i] = 0
	bleed[i] = 0
	sim.remove_agent(i)
	astate[i] = UNAWARE
	_witness(c, 4 if _silent else 14, i)

func _leave_corpse(i: int) -> void:
	corpses.append({"cell": sim.pos[i], "name": name_of(i), "fac": int(fac[i]), "kj": int(energy[i]), "who": i})
	if corpses.size() > CORPSE_CAP:
		corpses.remove_at(0)

## what is left in a body; the person's own record wins while they are still the one lying there
func corpse_kj(b: Dictionary) -> int:
	var wi: int = int(b.get("who", -1))
	if wi >= 0 and wi < energy.size() and sim.alive[wi] == 0 and sim.pos[wi] == int(b["cell"]) and int(energy[wi]) >= 0:
		b["kj"] = int(energy[wi])
	return int(b["kj"])

func corpse_at(c: int) -> int:
	for k in corpses.size():
		if int(corpses[k]["cell"]) == c:
			return k
	return -1

## people who see violence react: civilians panic
func _witness(cell: int, radius: int, except: int) -> void:
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
		if fac[j] == CIV and astate[j] != FLEEING:
			_flee(j, 20)

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
			_witness(sim.pos[target], 8, target)
		end_turn()
		return true
	say("%s catches your hand!" % name_of(target))
	skill_up("deception", 3)
	_alert(target)
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
	return cheb(sim.pos[j], pc) <= int(st["range_hi"]) + 8 and sim._sees(pc, sim.pos[j], 40)

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

## everything on the 2d10 roll that comes from you rather than the gun: implants (5 percentage points = 1), a blessing, a drink, a hurt arm, long-range gear
func _ranged_extra(d: int) -> int:
	var x: float = imp_sum("acc")
	if d >= 5:
		x += imp_sum("acc_far")
		if discipline("marksman"):
			x += 6.0
	x -= float(_arm_acc_pen())
	if bless_left > 0:
		x += 6.0
	if drunk_left > 0:
		x -= 8.0
	return int(round(x / 5.0))

## percent to hit on the target for the shot_index'th bullet (the 2d10 model, averaged over the gun's natural-range roll), cover included
func _shot_chance(st: Dictionary, t: int, aimed: int, shot_index: int) -> int:
	var d: int = cheb(sim.pos[t], pc)
	var base: int = GP.hit_chance(st, d, aimed, moved, crouch, lvl("ranged"), 0, shot_index, stance == CRAWL, _ranged_extra(d), cover_vs(pc, sim.pos[t], false))
	return int(round(float(base) * float(100 - int(shield_vs(pc, sim.pos[t])["pct"])) / 100.0))

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
	s += "  range %d-%d  aim %d/%d" % [st["range_lo"], st["range_hi"], aim_turns, st["max_aim"]]
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
	if aim_turns <= 0 and turn > aim_last + 1:
		aim_frac = 0.0
	aim_last = turn
	var mx: int = int(st["max_aim"])
	aim_frac += aim_rate()
	while aim_frac >= 0.999 and aim_turns < mx:
		aim_turns += 1
		aim_frac = maxf(0.0, aim_frac - 1.0)
	if aim_turns >= mx:
		aim_frac = 0.0
	aim_target = t
	stamina = maxi(0, stamina - GP.STAM_AIM)
	say("You steady the %s on %s (aim %d/%d, %.2f a turn): %d%% to hit." % [wield.def["name"], name_of(t), aim_turns, mx, aim_rate(), hit_chance_on(t)])
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
		var vi: int = veh_at.g(c)
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
	var crit_by: Dictionary = {}
	var where_by: Dictionary = {}
	var loc_by: Dictionary = {}                  # agent -> {limb: damage}
	var aimed: int = aim_turns
	var skill: int = lvl("ranged")
	var fumbled := false
	for s in shots:
		var blocked: Array = _vehicle_in_line(t)
		if not blocked.is_empty() and st["blast"] == 0:
			var vdmg: int = rng.randi_range(int(st["dmg"][0]), int(st["dmg"][1]))
			tracers.append([pc, blocked[1], true])
			sfx("shot")
			vs.damage_cell(int(blocked[0]), int(blocked[1]), vdmg, "gunfire")
			if s == 0:
				say("Your shots slam into the %s." % vs.KINDS[vehicles[int(blocked[0])]["kind"]]["name"])
			_spend_aim_on_bullet(st)
			continue
		var victim: int = _victim_in_line(t)
		var vd: int = d if victim == t else cheb(sim.pos[victim], pc)
		var nat: int = _roll_2d10()
		var rr: int = rng.randi_range(int(st["range_lo"]), int(st["range_hi"]))
		var bonus: int = GP.bonus_points(st, aim_turns, moved, crouch, skill, 0, stance == CRAWL, _ranged_extra(vd))
		var total: int = GP.shot_total(nat, bonus, GP.range_penalty(st, vd, rr), cover_vs(pc, sim.pos[victim], false))
		var out: String = SK.melee_outcome(nat, total, npc_lvl(victim, "grit"))
		var shield: Dictionary = shield_vs(pc, sim.pos[victim])
		if (out == "hit" or out == "crit") and rng.randi() % 100 < int(shield["pct"]):
			out = "miss"
			say_if_seen(sim.pos[victim], "Your shot is stopped by the %s." % String(shield["what"]))
		var loc: String = body.pick_melee(rng)
		var rpen_shown: int = GP.range_penalty(st, vd, rr)
		var cov_shown: int = cover_vs(pc, sim.pos[victim], false)
		_math("Shot %d at %s, %d tiles: dice %d + bonus %d (%s) - range %d (the gun's natural range rolled %d, off by %d) = %d%s.  Hits at %d, critical at 19+ or %d.  %s" % [s + 1, name_of(victim), vd, nat, bonus,
			_terms([["Ranged", skill], ["gun", GP.acc_points(st)], ["implants and state", _ranged_extra(vd)], ["aim", aim_turns], ["moving", -2 if moved else 0], ["crouching", 1 if crouch else 0], ["prone", 1 if stance == CRAWL else 0]]),
			rpen_shown, rr, absi(vd - rr), nat + bonus - rpen_shown, (", then cover hides %d%% = %d" % [cov_shown, total]) if cov_shown > 0 else "", SK.HIT_AT, 20 + npc_lvl(victim, "grit"), _outcome_word(out)])
		last_roll = {"who": "you", "target": victim, "nat": nat, "total": total, "outcome": out, "loc": loc, "dmg": 0, "range_roll": rr, "aim": aim_turns}
		_spend_aim_on_bullet(st)
		var landed := false
		var dmg: int = 0
		var crit: bool = out == "crit"
		if out == "cmiss":
			fumbled = true
			aim_turns = 0
			aim_dbt = 0.0
			aim_frac = 0.0
		elif out != "miss":
			if st["blast"] == 0 and rng.randi() % 100 < npc_bullet_dodge(victim):
				say_if_seen(sim.pos[victim], "%s blurs aside and the round misses." % name_of(victim))
			else:
				landed = true
				var wmax: int = int(st["dmg"][1])
				var bwroll: int = rng.randi_range(int(st["dmg"][0]), wmax)
				var base: int = SK.melee_base(bwroll, wmax, skill, crit)
				_math("Damage: %s = %d" % [("bullet maximum %d (critical) + Ranged %d, doubled" % [wmax, skill]) if crit else ("bullet roll %d (%d-%d) + Ranged %d" % [bwroll, int(st["dmg"][0]), wmax, skill]), base])
				var fall: float = GP.falloff(int(st["eff_range"]), vd)
				if fall < 1.0:
					base = int(round(float(base) * fall))
					if s == 0:
						say("The round is spent: %d%% of its damage left at %d tiles." % [int(round(fall * 100.0)), vd])
				if st["blast"] > 0:
					dmg = base
				else:
					var arm_eff: int = maxi(0, npc_armor(victim) - int(st.get("pen", 0)))
					dmg = maxi(0, base - arm_eff - npc_lvl(victim, "grit"))
					_math("%s: armor %d (the round pierces %d) takes %d, Grit %d: %d goes through" % [name_of(victim), npc_armor(victim), int(st.get("pen", 0)), arm_eff, npc_lvl(victim, "grit"), dmg])
					if dmg == 0:
						say("The round pings off %s's armor." % name_of(victim))
						landed = false
		tracers.append([pc, sim.pos[victim] if landed or st["blast"] > 0 else sim.pos[t], landed])
		sfx("shot" if int(st["noise"]) < 14 else "shot_big")
		last_roll["dmg"] = dmg
		if st["blast"] > 0:
			_explode(sim.pos[t] if landed else _scatter_cell(sim.pos[t]), int(st["blast"]), dmg)
			hits_by[t] = int(hits_by.get(t, 0)) + (1 if landed else 0)
			continue
		if landed:
			dmg_by[victim] = int(dmg_by.get(victim, 0)) + dmg
			hits_by[victim] = int(hits_by.get(victim, 0)) + 1
			if crit:
				crit_by[victim] = true
			where_by[victim] = loc
			var lm: Dictionary = loc_by.get(victim, {})
			lm[loc] = int(lm.get(loc, 0)) + dmg
			loc_by[victim] = lm
	wield.loaded -= shots
	stamina = maxi(0, stamina - GP.STAM_FIRE)
	var msg := "You fire the %s [%s]" % [wield.def["name"], GP.mode_name(wield)]
	if aimed > 0:
		msg += " (aim %d)" % aimed
	if st["blast"] > 0:
		msg += ": the grenade bursts."
	else:
		var parts: Array = []
		for v in dmg_by:
			parts.append("%s: %d hit%s for %d in the %s%s" % [name_of(v), hits_by[v], "" if hits_by[v] == 1 else "s", dmg_by[v], BODY.NAME[where_by[v]], " - a critical hit" if crit_by.has(v) else ""])
		msg += (": " + ", ".join(parts)) if not parts.is_empty() else ": miss"
	say(msg)
	if fumbled:
		say("The shot goes wild and you lose your aim!")
	_noise(pc, int(st["noise"]))
	for v in dmg_by:
		var dead := false
		for lc in loc_by.get(v, {}):
			if npc_limb_hit(v, String(lc), int(loc_by[v][lc])):
				dead = true
				break
		if not dead:
			_damage_npc(v, int(dmg_by[v]), true)
		skill_up("ranged", 2 + d / 5)
	if dmg_by.is_empty() and st["blast"] == 0:
		_alert(t)
	if rng.randf() * 100.0 < float(st["jam"]) * float(shots) * maxf(0.5, 1.0 - 0.04 * float(lvl("engineering"))) and wield.loaded > 0:
		wield.jammed = true
		say("The %s jams." % wield.def["name"])
	end_turn(GP.AP_FIRE)
	return true

## each bullet costs the shooter aim: `aim_loss` points a bullet (fractions carry over), never below max aim - 5
func _spend_aim_on_bullet(st: Dictionary) -> void:
	aim_dbt += float(st["aim_loss"])
	var floor_aim: int = int(st["max_aim"]) - GP.AIM_FLOOR_DROP
	while aim_dbt >= 0.999:
		aim_dbt -= 1.0
		aim_turns = maxi(floor_aim, aim_turns - 1)

func _damage_npc(v: int, dmg: int, final: bool = false) -> void:
	if sim.alive[v] == 0:
		return
	var st: Dictionary = gun_stats()
	_silent = (not st.is_empty() and st["suppressed"]) and (astate[v] == UNAWARE or astate[v] == RETURNING)
	if not final:
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
	if c < s2:
		for wy in range(-radius, radius + 1):
			for wx in range(-radius, radius + 1):
				var wc: int = c + wy * size + wx
				if wc >= 0 and wc < s2 and c % size + wx >= 0 and c % size + wx < size and city.tiles[wc] == CG.GLASS:
					city.tiles[wc] = CG.TID["window_broken"]
					sim.tiles[wc] = CG.TID["window_broken"]
					sim.walk[wc] = 1
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
	else:
		inv.remove(it)

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
	inv.remove(it)

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
			# a door, a lock or a clamp is not a scare: only a real noise sends people running, and a shopkeeper or fixer only stirs at gunfire and the like (radius 9+)
			var keeper: bool = eco != null and int(eco.role[j]) != 0
			if radius >= (9 if keeper else 5):
				_flee(j, 15)
		elif astate[j] == UNAWARE or astate[j] == RETURNING:
			astate[j] = SUSPICIOUS
			meter[j] = maxi(meter[j], 55)
			lastpos[j] = cell
			postc[j] = sim.pos[j]
			sim.ctl[j] = 1
			_face_toward(j, cell)

# ---------------------------------------------------------------- turns
## action points per turn: 100, plus fast-reflex implants, times how well fed you are (speed_mult) and your stamina percentage.
## In a vehicle, on a train or under jets the machine sets the pace, so it is a flat 100.
func ap_rate() -> int:
	if (in_vehicle >= 0 and not in_mech()) or transit.riding >= 0 or flying:
		return AP_BASE
	var r: float = (float(AP_BASE) + imp_sum("atk_speed")) * speed_mult() * float(stamina) / float(STAMINA_MAX)
	return maxi(AP_MIN_RATE, int(r))

## stamina back per turn: 1, plus 1 for every 2 points of Grit, plus implants
func stamina_regen() -> int:
	return 1 + lvl("grit") / 2 + int(imp_sum("stamina"))

## You spend `cost` action points (a move, a strike, any ordinary action: 100).  If that leaves you unable to afford another, turns go by
## (each earns ap_rate()) until you can.  At full strength that is one turn per action; tired or hungry it is more; a fast body sometimes gets a free one.
func end_turn(cost: int = AP_BASE) -> void:
	ap -= cost
	while ap < AP_BASE and not game_over:
		_tick()

## one turn of the world, with no action of yours attached: waiting, or the turns an action takes to pay off
func _tick() -> void:
	var rate: int = ap_rate()
	ap = mini(ap + rate, AP_BASE + rate - 1)
	turn += 1
	moved = pc != last_pc and last_pc >= 0
	if moved:
		aim_turns = 0
	last_pc = pc
	stamina = mini(STAMINA_MAX, stamina + stamina_regen())
	if not ran_this_turn:
		if stance == RUNNING:
			stance = WALKING
			run_streak = 0
	sim.step(pc)
	_doors_tick()
	transit.step()
	_ai()
	MS.step(self)
	_bleed_tick()
	_power_tick()
	_nano_tick()
	_critters_turn()
	_vehicles()
	eco.step()
	step_noise = 0
	ran_this_turn = false
	_jet_tick()
	_process_followers()
	if bless_left > 0:
		bless_left -= 1
	if drunk_left > 0:
		drunk_left -= 1
	_needs_tick()
	if turn % (40 * CLK.MIN) == 0:
		for l in BODY.LIMBS:                      # hurt limbs knit slowly; a disabled one needs a ripperdoc or a trauma patch
			if body.ok(l) and int(body.hp[l]) < int(body.mx[l]):
				body.heal(l, 1)
	_compute_fov()
	_die_check()

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
	# every action (a shot, a swing, a step) costs 100 action points; a fighter earns ap_rate per turn, scaled by their stamina
	var rate: int = npc_ap_rate(i)
	apn[i] = mini(apn[i] + rate, AP_BASE + rate - 1)
	while apn[i] >= AP_BASE and sim.alive[i] == 1 and astate[i] == HUNTING and not game_over:
		apn[i] -= AP_BASE
		_hunt_act(i, cheb(sim.pos[i], pc), sees)

## one action by a hunter: shoot, strike or close in
func _hunt_act(i: int, d: int, sees: bool) -> void:
	var c: int = sim.pos[i]
	var g := gunc[i]
	if g > 0 and sees and d >= 2 and d <= int(GP.NPC_GUN[g]["range"][1]) + 3 and npc_arms_ok(i) > 0:
		var ng: Dictionary = GP.NPC_GUN[g]
		if int(aimn[i]) < int(ng["want"]):          # the tell: a gunman spends a whole action raising the gun before the first shot
			aimn[i] += 1
			npc_stamina_spend(i, GP.STAM_AIM)
			say_if_seen(c, "%s raises a %s and takes aim at you." % [name_of(i), String(ng["name"])])
			return
		apn[i] = mini(apn[i] + AP_BASE - GP.AP_FIRE, AP_BASE + npc_ap_rate(i) - 1)     # a shot costs only 50 of the 100 points
		npc_stamina_spend(i, GP.STAM_FIRE)
		var nat: int = _roll_2d10()
		var rr: int = rng.randi_range(int(ng["range"][0]), int(ng["range"][1]))
		var skill: int = npc_lvl(i, "ranged")
		var bonus: int = skill + int(aimn[i]) + [-3, -2, 0, -1][stance] - (3 if in_vehicle >= 0 else 0) - (3 if npc_arms_ok(i) < 2 else 0) - (1 if npc_head_hurt(i) else 0)
		var total: int = GP.shot_total(nat, bonus, absi(d - rr), cover_vs(c, pc, crouch))
		var out: String = SK.melee_outcome(nat, total, lvl("grit"))
		var pshield: Dictionary = shield_vs(c, pc)
		if (out == "hit" or out == "crit") and rng.randi() % 100 < int(pshield["pct"]):
			out = "miss"
			say_if_seen(c, "%s's shot is stopped by the %s." % [name_of(i), String(pshield["what"])])
		var ncov: int = cover_vs(c, pc, crouch)
		_math("%s fires at you from %d tiles: dice %d + bonus %d (%s) - range %d (their gun's natural range rolled %d, off by %d) = %d%s.  Hits at %d, critical at 19+ or %d.  %s" % [name_of(i), d, nat, bonus,
			_terms([["Ranged", skill], ["aim", int(aimn[i])], ["stance", [-3, -2, 0, -1][stance]], ["you in a vehicle", -3 if in_vehicle >= 0 else 0], ["one arm", -3 if npc_arms_ok(i) < 2 else 0], ["head wound", -1 if npc_head_hurt(i) else 0]]),
			absi(d - rr), rr, absi(d - rr), nat + bonus - absi(d - rr), (", then your cover hides %d%% = %d" % [ncov, total]) if ncov > 0 else "", SK.HIT_AT, 20 + lvl("grit"), _outcome_word(out)])
		last_roll = {"who": name_of(i), "target": -1, "nat": nat, "total": total, "outcome": out, "loc": "", "dmg": 0, "range_roll": rr, "aim": int(aimn[i])}
		aimn[i] = maxi(0, int(aimn[i]) - 1)
		_noise(c, int(ng["noise"]))
		if out == "cmiss":
			aimn[i] = 0
			say_if_seen(c, "%s's shot goes wild." % name_of(i))
		elif out == "miss":
			say_if_seen(c, "%s shoots at you and misses." % name_of(i))
		elif _twist_roll():
			say("You twist aside and the round cracks past!")
			skill_up("dodge", 5)
		else:
			var crit: bool = out == "crit"
			var nb: Dictionary = GP.bullet(String(ng["cal"]), "fmj")
			var wmax: int = int(nb["dmg"][1])
			var nbroll: int = rng.randi_range(int(nb["dmg"][0]), wmax)
			var dmg: int = SK.melee_base(nbroll, wmax, skill, crit)
			var nfall: float = GP.falloff(int(nb["eff_range"]), d)
			dmg = int(round(float(dmg) * nfall))
			_math("Their damage: %s, range falloff x%.2f = %d" % [("bullet maximum %d (critical) + skill %d, doubled" % [wmax, skill]) if crit else ("bullet roll %d (%d-%d) + skill %d" % [nbroll, int(nb["dmg"][0]), wmax, skill]), nfall, dmg])
			player_melee_hurt(dmg, "%s shoots you" % name_of(i), 1 if fac[i] == NAP else 0, crit)
		return
	if d <= 1:
		_npc_melee_attack(i)
		return
	var wcell: int = _window_toward(i)
	if wcell >= 0 and (not sees or d <= 3):
		# a hunter with no gun and a window between them and you smashes through it rather than standing at the glass
		say_if_seen(c, "%s smashes the window." % name_of(i))
		break_window(wcell)
		apn[i] -= AP_BASE
		return
	if not _step_field(i):
		_step_to(i, pc)
	apn[i] -= AP_BASE * (2 - npc_legs_ok(i))          # a bad leg doubles the cost of a step, two make them crawl

## a window tile next to person i that lies towards the player (so closer to you than they are), or -1
func _window_toward(i: int) -> int:
	var c: int = sim.pos[i]
	if c >= s2:
		return -1
	var best := -1
	var bd: int = cheb(c, pc)
	for dd in DIR8:
		var nx: int = c % size + int(dd[0])
		var ny: int = c / size + int(dd[1])
		if not in_bounds(nx, ny):
			continue
		var nc: int = ny * size + nx
		if city.tiles[nc] == CG.GLASS and cheb(nc, pc) < bd:
			bd = cheb(nc, pc)
			best = nc
	return best

## a fighter's stamina in percent, brought up to date: 1 back per turn, plus 1 per 2 points of their Grit
func npc_stamina(i: int) -> int:
	var dt: int = turn - stamt[i]
	if dt > 0:
		stamt[i] = turn
		if stamn[i] < STAMINA_MAX:
			stamn[i] = mini(STAMINA_MAX, stamn[i] + dt * (1 + npc_lvl(i, "grit") / 2))
	return stamn[i]

func npc_stamina_spend(i: int, n: int) -> void:
	if n > 0:
		stamn[i] = maxi(0, npc_stamina(i) - n)

## people earn 100 action points a turn times their stamina percentage (never below the minimum)
func npc_ap_rate(i: int) -> int:
	return maxi(AP_MIN_RATE, AP_BASE * npc_stamina(i) / STAMINA_MAX)

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
		if thing_at.g(cell) != -1 or sim.at[cell] != -1 or veh_at.g(cell) != -1 or sim.walk[cell] == 0:
			continue
		_add_thing(String(m[1]), cell, rng.randf() < 0.5)

func _add_thing(kind: String, cell: int, loot: bool) -> int:
	things.append({"k": kind, "cell": cell, "hp": THING_HP[kind], "loot": loot and kind == "crate"})
	thing_at.s(cell, things.size() - 1)
	sim.walk[cell] = 0
	return things.size() - 1

func _remove_thing(ti: int) -> void:
	var t: Dictionary = things[ti]
	var cell: int = t["cell"]
	if thing_at.g(cell) == ti:
		thing_at.s(cell, -1)
		sim.walk[cell] = 1 if city.walkable(city.tiles[cell]) and veh_at.g(cell) == -1 else 0
	t["k"] = ""

## a thing is wrecked: crates spill what they held
func smash_thing(ti: int, why: String) -> void:
	var t: Dictionary = things[ti]
	var cell: int = t["cell"]
	var kind: String = t["k"]
	if kind == "":
		return
	say_if_seen(cell, "The %s %s." % [kind, why])
	_remove_thing(ti)
	_noise_gentle(cell, 7)

func _thing_open(c: int) -> bool:
	return sim.walk[c] == 1 and sim.at[c] == -1 and veh_at.g(c) == -1 and thing_at.g(c) == -1 and crit_at.g(c) == -1 and c != pc

func _move_thing(ti: int, to: int) -> void:
	var t: Dictionary = things[ti]
	var from: int = t["cell"]
	thing_at.s(from, -1)
	sim.walk[from] = 1 if city.walkable(city.tiles[from]) and veh_at.g(from) == -1 and crit_at.g(from) == -1 else 0
	t["cell"] = to
	thing_at.s(to, ti)
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
	if (city.tiles[n1] in CG.LOW_COVER) and w <= 2 and thing_at.g(n1) == -1:
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
	var ti: int = thing_at.g(c)
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
		if sim.walk[c] == 0 or sim.at[c] != -1 or veh_at.g(c) != -1 or thing_at.g(c) != -1 or crit_at.g(c) != -1:
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
				if CG.is_floor(city.tiles[c2]) and sim.walk[c2] == 1 and sim.at[c2] == -1 and thing_at.g(c2) == -1 and crit_at.g(c2) == -1:
					_add_critter("cat", c2)
					break

func _add_critter(kind: String, cell: int) -> int:
	critters.append({"k": kind, "cell": cell, "hp": 18 if kind == "dog" else 8, "mood": 0, "stun": 0, "face": 0, "ap": AP_BASE, "stam": STAMINA_MAX})
	crit_at.s(cell, critters.size() - 1)
	sim.walk[cell] = 0
	return critters.size() - 1

func _crit_free(c: int) -> bool:
	return sim.walk[c] == 1 and sim.at[c] == -1 and veh_at.g(c) == -1 and thing_at.g(c) == -1 and crit_at.g(c) == -1 and c != pc

func _move_crit(ki: int, to: int) -> void:
	var k: Dictionary = critters[ki]
	var from: int = k["cell"]
	crit_at.s(from, -1)
	sim.walk[from] = 1 if city.walkable(city.tiles[from]) and veh_at.g(from) == -1 and thing_at.g(from) == -1 else 0
	k["cell"] = to
	var fi: int = DIR8.find([signi(to % size - from % size), signi(to / size - from / size)])
	if fi >= 0:
		k["face"] = fi
	crit_at.s(to, ki)
	sim.walk[to] = 0

func _kill_crit(ki: int, why: String) -> void:
	var k: Dictionary = critters[ki]
	if k["k"] == "":
		return
	say_if_seen(k["cell"], "The %s %s." % [k["k"], why])
	var cell: int = k["cell"]
	if crit_at.g(cell) == ki:
		crit_at.s(cell, -1)
		sim.walk[cell] = 1 if city.walkable(city.tiles[cell]) and veh_at.g(cell) == -1 and thing_at.g(cell) == -1 else 0
	k["k"] = ""

func fall_crit(ki: int, over: int) -> void:
	var k: Dictionary = critters[ki]
	var kind: String = k["k"]
	var lc: Array = land_cell(over)
	var levels: int = lc[1]
	var cell: int = k["cell"]
	if crit_at.g(cell) == ki:
		crit_at.s(cell, -1)
		sim.walk[cell] = 1 if city.walkable(city.tiles[cell]) and veh_at.g(cell) == -1 and thing_at.g(cell) == -1 else 0
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
	crit_at.s(lc[0], ki)
	sim.walk[lc[0]] = 0
	k["stun"] = 3 if specials_on else 0
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
	if (city.tiles[n1] in CG.LOW_COVER) and thing_at.g(n1) == -1:
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
	var ki: int = crit_at.g(c)
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
	_witness(k["cell"], 8, -1)
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
		# animals have action points and stamina like people: 100 a turn (cats 110) times their stamina; a chase (running) costs 5 stamina a step, a bite 2 (a claw 1)
		var rate: int = maxi(AP_MIN_RATE, int((CAT_AP if not dog else AP_BASE) * int(k.get("stam", STAMINA_MAX)) / STAMINA_MAX))
		k["ap"] = mini(int(k.get("ap", AP_BASE)) + rate, AP_BASE + rate - 1)
		k["stam"] = mini(STAMINA_MAX, int(k.get("stam", STAMINA_MAX)) + 1)
		if mood == 1 and dog:                 # angry dog: closes and bites
			while int(k["ap"]) >= AP_BASE and k["k"] != "":
				k["ap"] = int(k["ap"]) - AP_BASE
				d = cheb(k["cell"], pc)
				if d <= 1:
					k["stam"] = maxi(0, int(k["stam"]) - 2)
					if rng.randf() < 0.6:
						player_hurt(rng.randi_range(2, 5), "The dog bites you")
					if rng.randf() < 0.03:
						k["mood"] = 0
				else:
					k["stam"] = maxi(0, int(k["stam"]) - RUN_STAMINA)
					_crit_step_toward(ki, pc)
			continue
		if mood == 2 or (not dog and d <= 3 and stance >= WALKING):
			if d <= 8:
				while int(k["ap"]) >= AP_BASE:
					k["ap"] = int(k["ap"]) - AP_BASE
					k["stam"] = maxi(0, int(k["stam"]) - RUN_STAMINA)
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
## is there one of this item id in the grid or a slot?
func carries_id(item_id: String) -> bool:
	for it in inv.all_items():
		if it.id() == item_id:
			return true
	return false

## fit an implant item from your pack: it leaves the grid and goes into the body
func act_install_implant(it) -> bool:
	if not it.def.has("implant"):
		say("That is not an implant.")
		return false
	var id: String = String(it.def["implant"])
	if implants.get(id, false):
		say("You already have the %s fitted." % it.def["name"])
		return false
	var need: Array = IMP.missing(IMP.get_def(id), base_lvl)
	if not need.is_empty():
		var bits: Array = []
		for m in need:
			bits.append("%s %d (you have %d)" % [IMP.skill_name(String(m["skill"])), int(m["need"]), int(m["have"])])
		say("You can't fit the %s yet.  It needs %s." % [it.def["name"], ", ".join(bits)])
		return false
	if inv.find(it).is_empty() or not inv.remove(it):
		return false
	implants[id] = true
	power_install(id)
	say("You fit the %s." % it.def["name"])
	if power_cap() <= 0.0:
		say("Nothing in you stores power yet: fit a chest battery or a Trilobit, or the implants stay off.")
	sfx("select")
	return true

## take a fitted implant out: it comes back as an item in your pack (or at your feet when the pack is full)
func act_remove_implant(id: String) -> bool:
	if not implants.get(id, false):
		return false
	var item = _new_item("trl_imp_" + id)
	if inv.free_tiles() < 1:
		say("No room in your pockets: make a tile free first.")
		return false
	var after: int = nano_slots() - int(IMP.get_def(id).get("nano", 0))
	if nano_chips_over(after) + 1 > inv.free_tiles():
		say("No room in your pockets for the nanohack chips that come out with it.")
		return false
	implants.erase(id)
	power_uninstall(id)
	nano_trim()
	inv.stow(item)
	say("You take out the %s." % item.def["name"])
	sfx("select")
	return true

# ---------------------------------------------------------------- nanohacks
## slots the fitted Trilobits open (each Trilobit's `nano`)
func nano_slots() -> int:
	var n := 0
	for id in implants:
		if implants.get(id, false):
			n += int(IMP.get_def(String(id)).get("nano", 0))
	return n

## the hack in slot i ("" if empty or out of range)
func nano_at(i: int) -> String:
	return String(nanos[i]) if i >= 0 and i < nanos.size() else ""

func nano_installed() -> Array:
	var out: Array = []
	for i in nano_slots():
		if nano_at(i) != "":
			out.append(nano_at(i))
	return out

func nano_has(id: String) -> bool:
	return id in nano_installed()

## a Trilobit that is fitted, powered and whole: the hacks only run while one does
func nano_ok() -> bool:
	for id in implants:
		var d: Dictionary = IMP.get_def(String(id))
		if implants.get(id, false) and d.has("nano") and _imp_active(d):
			return true
	return false

## the chip goes into a slot (the first empty one unless `slot` says): false and a message when there is no room
func act_nano_install(it, slot: int = -1) -> bool:
	var hid: String = NANO.of_item(String(it.id()))
	if hid == "" or NANO.get_def(hid).is_empty():
		say("That is not a nanohack.")
		return false
	var n: int = nano_slots()
	if n <= 0:
		say("You need a Trilobit fitted to run nanohacks.")
		return false
	if nano_has(hid):
		say("%s is already installed." % NANO.get_def(hid)["name"])
		return false
	if slot < 0 or slot >= n or nano_at(slot) != "":
		slot = -1
		for i in n:
			if nano_at(i) == "":
				slot = i
				break
	if slot < 0:
		say("Your Trilobit has no free nanohack slot (%d of %d used)." % [nano_installed().size(), n])
		return false
	if inv.find(it).is_empty() or not inv.remove(it):
		return false
	while nanos.size() <= slot:
		nanos.append("")
	nanos[slot] = hid
	say("You load %s into slot %d." % [NANO.get_def(hid)["name"], slot + 1])
	sfx("select")
	return true

## take the hack in slot i out; its chip goes back to your pack
func act_nano_remove(slot: int) -> bool:
	var hid: String = nano_at(slot)
	if hid == "":
		return false
	if inv.free_tiles() < 1:
		say("No room in your pockets: make a tile free first.")
		return false
	nanos[slot] = ""
	nano_fx.erase(hid)
	inv.stow(_new_item(NANO.chip_item(hid)))
	say("You eject the %s chip." % NANO.get_def(hid)["name"])
	sfx("select")
	return true

## after a Trilobit comes out the slots shrink: chips beyond the new count go back to the pack (false if there is no room for them)
func nano_chips_over(new_slots: int) -> int:
	var n := 0
	for i in range(new_slots, nanos.size()):
		if nano_at(i) != "":
			n += 1
	return n

func nano_trim() -> void:
	var n: int = nano_slots()
	for i in range(n, nanos.size()):
		if nano_at(i) != "":
			act_nano_remove(i)
	if nanos.size() > n:
		nanos.resize(n)

func nano_running(id: String) -> bool:
	return int(nano_fx.get(id, 0)) > 0 and nano_has(id) and nano_ok()

## skill points the running and standing hacks give
func nano_bonus(id: String) -> int:
	if nanos.is_empty() or not nano_ok():
		return 0
	var t := 0
	for hid in nano_installed():
		var d: Dictionary = NANO.get_def(hid)
		if not d.has("skills") or not (d["skills"] as Dictionary).has(id):
			continue
		if String(d["kind"]) == "passive" or nano_running(hid):
			t += int(d["skills"][id])
	return t

func nano_armor() -> int:
	var t := 0
	for hid in nano_installed():
		var d: Dictionary = NANO.get_def(hid)
		if d.has("armor") and nano_running(hid):
			t += int(d["armor"])
	return t

## extra kJ/h the running hacks draw
func nano_draw() -> float:
	var t := 0.0
	for hid in nano_installed():
		if nano_running(hid):
			t += float(NANO.get_def(hid).get("draw", 0.0))
	return t

func _nano_tick() -> void:
	if nano_fx.is_empty():
		return
	for hid in nano_fx.keys():
		nano_fx[hid] = int(nano_fx[hid]) - 1
		if int(nano_fx[hid]) <= 0:
			nano_fx.erase(hid)
			say("%s wears off." % NANO.get_def(String(hid))["name"])

## what the N menu lists: [{slot, id, name, kind, left, text}] for every installed hack
func nano_menu() -> Array:
	var out: Array = []
	for i in nano_slots():
		var hid: String = nano_at(i)
		if hid == "":
			continue
		var d: Dictionary = NANO.get_def(hid)
		out.append({"slot": i, "id": hid, "name": d["name"], "kind": d["kind"], "left": int(nano_fx.get(hid, 0)), "text": d["text"]})
	return out

## people in sight that Shock can pick
func nano_targets() -> Array:
	var out: Array = []
	for k in sim.near_list.size():
		var j: int = sim.near_list[k]
		if j >= 0 and j < sim.n and sim.alive[j] == 1 and sim.near[j] == 1 and sees_cell(sim.pos[j]) and sim._sees(pc, sim.pos[j], 40):
			out.append(j)
	out.sort_custom(func(a, b): return cheb(sim.pos[a], pc) < cheb(sim.pos[b], pc))
	return out

## run a hack.  Costs USE_KJ of the battery and a turn.  `target` is the person for Shock.
func act_nano_use(hid: String, target: int = -1) -> bool:
	var d: Dictionary = NANO.get_def(hid)
	if d.is_empty() or not nano_has(hid):
		return false
	if String(d["kind"]) == "passive":
		say("%s is always on while it is installed." % d["name"])
		return false
	if not nano_ok():
		say("Your Trilobit is off: the hacks cannot run.")
		return false
	if power_left() < NANO.USE_KJ:
		say("Not enough power: %s needs %d kJ and you have %d." % [d["name"], int(NANO.USE_KJ), int(power_left())])
		return false
	if String(d["kind"]) == "active" and nano_running(hid):
		say("%s is already running." % d["name"])
		return false
	if hid == "shock":
		if target < 0 or not (target in nano_targets()):
			say("Shock needs a target in sight.")
			return false
	power = power_left() - NANO.USE_KJ
	if String(d["kind"]) == "active":
		nano_fx[hid] = int(d["turns"])
		say("%s runs for 10 minutes." % d["name"])
	else:
		_shock(target, int(d["damage"]))
	sfx("blip")
	end_turn()
	return true

## 10 damage to a random implanted body part of the target; people with no implants take nothing
func _shock(i: int, dmg: int) -> void:
	var rig: Array = IMP.NPC_RIGS.get(fac[i], [])
	if rig.is_empty():
		say("The jolt crackles over %s and finds nothing to bite: they are not wired." % name_of(i))
		_alert(i)
		return
	var part: String = String(IMP.get_def(String(rig[rng.randi() % rig.size()])).get("part", "chest"))
	var grp: String = BODY.PART_GROUP.get(part, "chest")
	var limbs: Array = []
	for l in BODY.LIMBS:
		if BODY.GROUP[l] == grp:
			limbs.append(l)
	var loc: String = String(limbs[rng.randi() % limbs.size()])
	say("Shock arcs into %s's %s (%d)." % [name_of(i), BODY.NAME[loc], dmg])
	if npc_limb_hit(i, loc, dmg):
		return
	hpn[i] -= dmg
	if hpn[i] <= 0:
		kill(i)
		return
	_alert(i)

func has_implant(id: String) -> bool:
	if not implants.get(id, false) or power_left() <= 0.0:
		return false
	return body.group_ok(body.group_of_part(String(IMP.get_def(id).get("part", "chest"))))

func airborne() -> bool:
	return flying or (in_vehicle >= 0 and bool(vehicles[in_vehicle].get("air", false)))

func _free_for_player(c: int) -> bool:
	return sim.walk[c] == 1 and sim.at[c] == -1 and veh_at.g(c) == -1 and thing_at.g(c) == -1 and crit_at.g(c) == -1 and c != pc

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
		sfx("hurt")
		say("You hit the ground hard (-%d)." % dmg)
		_noise(pc, 6 + levels)
	sim.retier(pc)
	aim_turns = 0

## ---- jump jets
func _fly_ok_target(c: int) -> bool:
	return city.tiles[c] == CG.AIR and sim.at[c] == -1 and veh_at.g(c) == -1

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
	if veh_at.g(c) != -1:
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
						if z_of(nc) == z_of(cell) and sim.walk[nc] == 1 and sim.at[nc] == -1 and nc != pc and veh_at.g(nc) == -1:
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
	if elevator:
		elev_hit = pc                         # the elevator always works: pick the floor from a list
		return false
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

## the floors an elevator at this cell reaches: {z, cell} from the lowest to the highest, following the shaft's links through every level
func elevator_floors(cell: int) -> Array:
	var col: int = cell % s2
	var out: Array = []
	var seen := {}
	var stack: Array = [cell]
	while not stack.is_empty():
		var c: int = stack.pop_back()
		if seen.has(c):
			continue
		seen[c] = true
		out.append({"z": z_of(c), "cell": c})
		if city.links.has(c):
			for nb in city.links[c]:
				if nb % s2 == col and city.tiles[nb] == CG.ELEVATOR:
					stack.append(nb)
	out.sort_custom(func(a, b): return int(a["z"]) < int(b["z"]))
	return out

## the text on an elevator button
func floor_button(z: int) -> String:
	if z > 0:
		return str(z)
	return "G" if z == 0 else "B%d" % (-z)

func floor_label(z: int) -> String:
	if z > 0:
		return "Floor %d" % z
	return "Ground floor" if z == 0 else "Basement %d" % (-z)

## ride the elevator to the floor with this z.  It is always available to the player: whoever stands in the way is moved aside.
func act_elevator_to(z: int) -> bool:
	if not city.tiles[pc] == CG.ELEVATOR:
		return false
	var dest := -1
	for f in elevator_floors(pc):
		if int(f["z"]) == z:
			dest = int(f["cell"])
	if dest < 0 or dest == pc:
		return false
	if sim.at[dest] >= 0:
		var who: int = sim.at[dest]
		var spot := -1
		for r in range(1, 6):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if spot >= 0 or maxi(absi(dx), absi(dy)) != r:
						continue
					var nc: int = dest + dy * size + dx
					if z_of(nc) == z_of(dest) and sim.walk[nc] == 1 and sim.at[nc] == -1 and veh_at.g(nc) == -1 and thing_at.g(nc) == -1 and nc != pc and city.tiles[nc] != CG.ELEVATOR and city.tiles[nc] != CG.STAIRS:
						spot = nc
		if spot < 0:
			return false
		sim.place(who, spot)
		say("%s steps out of the way." % name_of(who))
	var steps: int = absi(z_of(dest) - z_of(pc))
	_vertical_cost_and_move(dest, steps, true, "The elevator whirs")
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
	if sim.at[dn] >= 0 or veh_at.g(dn) != -1:
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
	return sim.walk[c] == 1 and sim.at[c] == -1 and veh_at.g(c) == -1 and thing_at.g(c) == -1 and crit_at.g(c) == -1 and c != pc

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
	stun[i] = 4 if specials_on else 0
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
	if who < 0 and crit_at.g(c) != -1:
		facing = Vector2i(dx, dy)
		var kc: Dictionary = critters[crit_at.g(c)]
		say("You shove the %s." % kc["k"])
		push_crit(crit_at.g(c), dx, dy)
		if kc["k"] != "":
			kc["mood"] = 2 if kc["k"] == "cat" else (1 if rng.randf() < 0.4 else 2)
		end_turn()
		return true
	if who < 0 and thing_at.g(c) != -1:
		facing = Vector2i(dx, dy)
		var tn: String = things[thing_at.g(c)]["k"]
		if push_thing(thing_at.g(c), dx, dy):
			say("You shove the %s." % tn)
		else:
			say("The %s won't budge." % tn)
		end_turn()
		return true
	if who < 0:
		say("There is nobody there to shove.")
		return false
	facing = Vector2i(dx, dy)
	_witness(pc, 10, who)
	if rng.randi() % 100 < 88 - (10 if astate[who] == HUNTING else 0):
		say("You shove %s." % name_of(who))
		push_agent(who, dx, dy)
		if sim.alive[who] == 1:
			stun[who] = maxi(int(stun[who]), 1) if specials_on else 0
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
	return {"done": done_contracts.duplicate(), "power": power, "power_state": power_state, "yen": yen, "implants": implants.duplicate(), "nanos": nanos.duplicate(), "nano_fx": nano_fx.duplicate(), "fuel": fuel, "ammo": ammo_pool.duplicate(), "want_kind": want_kind.duplicate(),
		"name": player_name, "attrs": attrs.duplicate(), "app": app.duplicate(), "skills": skills.duplicate(), "xp": xp.duplicate(), "lvl": pc_level, "pts": attr_points, "inv": inv.to_dict(),
		"stamina": stamina, "stam_v": 2, "ap": ap, "stance": stance, "run_mode": run_mode, "turn": turn, "tv": CLK.SAVE_VERSION, "tick": sim.tick, "bless": bless_left, "drunk": drunk_left, "ate": last_ate, "drank": last_drank, "eco": eco.save(), "barter": barter.to_dict(), "flying": flying,
		"body": body.to_dict(), "imp_dur": imp_dur.duplicate(), "arts": melee_arts.duplicate()}

## attributes, skills and XP from a save; saves from before the attribute system (or with the old skill names) keep what still exists and start the rest at the defaults
func _load_skills(d: Dictionary) -> void:
	player_name = CR.clean_name(String(d.get("name", "")))
	app = CR.sanitize(d.get("app", {}))          # saves from before character creation get the figure the game always drew
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
	pc_level = int(d.get("lvl", 0))
	attr_points = int(d.get("pts", 0))
	if not d.has("lvl"):                         # a save from before levels: the level the skills already earn, with its points
		check_level()

func _load_body(d: Dictionary) -> void:
	body = BODY.new()
	if d.has("body"):
		body.from_dict(d["body"])
	imp_dur = {}
	for k in d.get("imp_dur", {}):
		imp_dur[k] = int(d["imp_dur"][k])
	melee_arts = []
	for a in d.get("arts", []):
		melee_arts.append(String(a))
	aim_frac = 0.0

## the inventory from a save: the new format, or a save from before the grid (nested pockets, worn armor, a wielded weapon) flattened into it
func _load_inventory(d: Dictionary) -> void:
	inv = INV.new()
	if d.has("inv"):
		inv.load_dict(d["inv"], db)
		return
	var loose: Array = []
	var gear: Array = []
	for x in d.get("worn", []):
		_legacy_item(x, loose, gear)
	for x in d.get("armor_worn", []):
		_legacy_item(x, loose, gear)
	var hand = null
	if d.get("wield") != null:
		hand = _legacy_item(d["wield"], loose, gear, true)
	# gear first: a pocket item or armor goes in its slot when that slot is free, otherwise it is just carried
	if hand != null:
		inv.equip["rhand"] = hand
	for it in gear:
		var opts: Array = INV.slot_options(it)
		if not opts.is_empty() and opts[0] != "rhand" and not inv.equip.has(opts[0]):
			inv.equip[opts[0]] = it
			inv._ensure_group(opts[0])
		else:
			loose.append(it)
	for it in loose:
		if not inv.stow(it):
			_put(pc, it)

## one item from a save made before the grid: its contents are flattened into `loose`; armor and pocket items are returned in `gear` (and as the result);
## things that no longer exist (duffel, holster) or are no longer carried (loose water, vehicle engines) are dropped, a bottle's water becomes its fill
func _legacy_item(x: Dictionary, loose: Array, gear: Array, is_hand: bool = false):
	var it = null
	var id: String = String(x["id"])
	if db.defs.has(id) and not (db.defs[id].has("engine") or id == "trl_water"):
		it = ItemScript.from_dict(x, db)
	for arr in x.get("contents", []):
		for sub in arr:
			if String(sub["id"]) == "trl_water":
				if it != null and it.def.has("bottle"):
					it.fill = mini(int(it.def["bottle"]["ml"]), it.fill + int(sub.get("count", 0)))
				continue
			_legacy_item(sub, loose, gear)
	if it == null:
		return null
	if is_hand:
		return it
	if it.def.has("armor") or it.def.has("pocket"):
		gear.append(it)
	else:
		loose.append(it)
	return it

func apply_player(d: Dictionary) -> void:
	done_contracts = d.get("done", {})
	power = float(d.get("power", -1.0))
	power_state = int(d.get("power_state", 0))
	yen = int(d["yen"])
	implants = d["implants"]
	nanos = d.get("nanos", [])
	nano_fx = d.get("nano_fx", {})
	fuel = int(d["fuel"])
	ammo_pool = d["ammo"]
	want_kind = d["want_kind"]
	_load_skills(d)
	_load_inventory(d)
	stamina = int(d["stamina"])
	if int(d.get("stam_v", 1)) < 2:          # old saves counted stamina out of 30
		stamina = clampi(int(round(float(stamina) * STAM_LEGACY)), 0, STAMINA_MAX)
	ap = int(d.get("ap", 2 * AP_BASE - 1))
	var tk: int = time_scale(d)          # saves from before the six-second turn count in minutes
	bless_left = int(d.get("bless", 0)) * tk
	drunk_left = int(d.get("drunk", 0)) * tk
	last_ate = int(d.get("ate", int(d.get("tick", 0)))) * tk
	last_drank = int(d.get("drank", int(d.get("tick", 0)))) * tk
	stance = int(d["stance"])
	run_mode = bool(d.get("run_mode", false))
	turn = int(d["turn"]) * tk
	sim.tick = int(d["tick"]) * tk
	_was_hungry = hungry()
	_was_thirsty = thirsty()
	eco.load_from(JSON.parse_string(JSON.stringify(d["eco"])))
	barter.load_dict(JSON.parse_string(JSON.stringify(d.get("barter", {}))))
	eco.job = {}
	flying = bool(d.get("flying", false))
	followers = []
	_load_body(d)

## the player has walked or driven off the edge of the zone (a stub until zones exist)
func zone_cross(_dx: int, _dy: int) -> bool:
	return false

# ---------------------------------------------------------------- save / load
## 1 for a save made with six-second turns, 10 for an older one (its turns were minutes)
func time_scale(d: Dictionary) -> int:
	return 1 if int(d.get("tv", 1)) >= CLK.SAVE_VERSION else CLK.OLD_TO_NEW

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
	return {"seed": seed_value, "island": (island.seed_value if island != null else -1), "zone": [zone.x, zone.y], "people": sim.n, "turn": turn, "pc": pc, "done": done_contracts, "power": power, "power_state": power_state, "yen": yen, "things": things.filter(func(t): return t["k"] != ""), "corpses": corpses, "critters": critters.filter(func(k): return k["k"] != ""), "implants": implants, "nanos": nanos, "nano_fx": nano_fx, "fuel": fuel, "flying": flying, "ammo": ammo_pool, "want_kind": want_kind, "skills": skills, "name": player_name, "attrs": attrs, "app": app, "xp": xp, "lvl": pc_level, "pts": attr_points, "in_vehicle": in_vehicle,
			"body": body.to_dict(), "imp_dur": imp_dur.duplicate(), "stamina": stamina, "stam_v": 2, "ap": ap, "arts": melee_arts.duplicate(),
			"mission": mission, "portal": portal, "rng_state": str(rng.state), "transit": transit.save(), "eco": eco.save(), "barter": barter.to_dict(), "inv": inv.to_dict(),
			"items_at": it_at, "open_doors": open_doors.keys(), "vehicles": vlist, "tv": CLK.SAVE_VERSION, "tick": sim.tick, "ate": last_ate, "drank": last_drank, "log": log.slice(-30),
			"npc": {"pos": Array(sim.pos), "dest": Array(sim.dest), "goal": Array(sim.goal), "near": Array(sim.near), "alive": Array(sim.alive), "depart": Array(sim.depart), "arrive": Array(sim.arrive),
					"hp": Array(hpn), "state": Array(astate), "meter": Array(meter), "timer": Array(timer), "last": Array(lastpos), "post": Array(postc), "yen": Array(yenn), "gun": Array(gunc), "energy": Array(energy),
					"prov": provoked.keys(), "apn": Array(apn), "stamn": Array(stamn), "stamt": Array(stamt), "aimn": Array(aimn), "limbs": _limbs_save(), "mdis": Array(mdis), "noticed": Array(noticed_you), "ctl": Array(sim.ctl), "idle": Array(sim.idle), "home": Array(sim.home_cell), "com": sim.com.to_dict()}}

func load_dict(d: Dictionary) -> void:
	seed_value = int(d["seed"])
	var isl_seed: int = int(d.get("island", -1))
	var saved_mission: Dictionary = d.get("mission", {})
	if not saved_mission.is_empty():
		setup(int(d.get("people", 0)), null, Vector2i(-1, -1), JSON.parse_string(JSON.stringify(saved_mission)))
		_restore_mission_state(saved_mission)
	elif isl_seed >= 0:
		var isl = island if (island != null and island.seed_value == isl_seed) else ISL.new(isl_seed)
		setup(int(d.get("people", 0)), isl, Vector2i(int(d["zone"][0]), int(d["zone"][1])))
	else:
		setup(int(d.get("people", sim.n if sim != null else 1500)))             # regenerates the deterministic parts (map, markers, names, factions)
	turn = int(d["turn"]) * time_scale(d)
	pc = int(d["pc"])
	open_doors = {}
	for dc in d.get("open_doors", []):
		_set_door(int(dc), false, false)
	done_contracts = d.get("done", {})
	power = float(d.get("power", -1.0))
	power_state = int(d.get("power_state", 0))
	yen = int(d["yen"])
	ammo_pool = {}
	for k in d["ammo"]:
		ammo_pool[k] = int(d["ammo"][k])
	want_kind = d.get("want_kind", {})
	aim_turns = 0
	aim_target = -1
	_set_stance(WALKING)
	stamina = int(d.get("stamina", STAMINA_MAX))
	if int(d.get("stam_v", 1)) < 2:          # old saves counted stamina out of 30
		stamina = clampi(int(round(float(stamina) * STAM_LEGACY)), 0, STAMINA_MAX)
	ap = int(d.get("ap", 2 * AP_BASE - 1))
	implants = d.get("implants", {})
	nanos = d.get("nanos", [])
	nano_fx = d.get("nano_fx", {})
	fuel = int(d.get("fuel", FUEL_MAX))
	flying = bool(d.get("flying", false))
	followers = []
	_load_skills(d)
	in_vehicle = int(d["in_vehicle"])
	_load_body(d)
	rng.state = int(d["rng_state"])
	_load_inventory(d)
	items_at = {}
	for k in d["items_at"]:
		var arr := []
		for x in d["items_at"][k]:
			arr.append(ItemScript.from_dict(x, db))
		items_at[int(k)] = arr
	# vehicles: undo the freshly generated ones, then restore
	for vi0 in vehicles.size():
		vs.lift(vi0)
	veh_at.clear()
	vehicles = []
	for v in d["vehicles"]:
		var o: Dictionary = vs.from_dict(v)
		vehicles.append(o)
		for c in vs.cells(o):
			veh_at.s(c, vehicles.size() - 1)
			sim.walk[c] = 0
	# things and animals: undo the fresh ones, restore the saved
	for t0 in things:
		if t0["k"] != "":
			sim.walk[t0["cell"]] = 1 if city.walkable(city.tiles[t0["cell"]]) else 0
	for k0 in critters:
		if k0["k"] != "":
			sim.walk[k0["cell"]] = 1 if city.walkable(city.tiles[k0["cell"]]) else 0
	thing_at.clear()
	crit_at.clear()
	things = []
	critters = []
	corpses = []
	for cp in d.get("corpses", []):
		corpses.append({"cell": int(cp["cell"]), "name": String(cp["name"]), "fac": int(cp["fac"]), "kj": int(cp["kj"]), "who": int(cp.get("who", -1))})
	for t in d.get("things", []):
		var ti: int = _add_thing(String(t["k"]), int(t["cell"]), bool(t["loot"]))
		things[ti]["hp"] = int(t["hp"])
	for k in d.get("critters", []):
		var ki: int = _add_critter(String(k["k"]), int(k["cell"]))
		for f in ["hp", "mood", "stun"]:
			critters[ki][f] = int(k[f])
	var tk2: int = time_scale(d)
	bless_left = int(d.get("bless", 0)) * tk2
	drunk_left = int(d.get("drunk", 0)) * tk2
	sim.tick = int(d["tick"]) * tk2
	last_ate = int(d.get("ate", int(d["tick"]))) * tk2
	last_drank = int(d.get("drank", int(d["tick"]))) * tk2
	_was_hungry = hungry()
	_was_thirsty = thirsty()
	transit.load_from(d["transit"])
	eco.load_from(d["eco"])
	barter.load_dict(d.get("barter", {}))
	var nn: Dictionary = d["npc"]
	provoked = {}
	for k in nn.get("prov", []):
		provoked[int(k)] = 1
	apn.fill(AP_BASE)
	stamn.fill(STAMINA_MAX)
	stamt.fill(0)
	aimn.fill(0)
	limbn.fill(-1)
	var ls: Dictionary = nn.get("limbs", {})
	for k in ls:
		var ji: int = int(k)
		if ji >= 0 and ji < sim.n:
			for q in 6:
				limbn[ji * 6 + q] = int(ls[k][q])
	for j in mini(aimn.size(), nn.get("aimn", []).size()):
		aimn[j] = int(nn["aimn"][j])
	for j in mini(apn.size(), nn.get("apn", []).size()):
		apn[j] = int(nn["apn"][j])
		stamn[j] = int(nn["stamn"][j])
		stamt[j] = int(nn["stamt"][j])
	# rebuild the agent structures from the saved arrays
	sim.near_list = PackedInt32Array()
	sim.at.fill(-1)
	sim.buckets.clear()
	for i in sim.n:
		sim.pos[i] = int(nn["pos"][i])
		sim.dest[i] = int(nn["dest"][i])
		sim.goal[i] = int(nn["goal"][i])
		sim.alive[i] = int(nn["alive"][i])
		sim.depart[i] = int(nn["depart"][i]) * tk2
		sim.arrive[i] = int(nn["arrive"][i]) * tk2 if int(nn["arrive"][i]) >= 0 else -1
		sim.ctl[i] = int(nn["ctl"][i])
		sim.idle[i] = int(nn["idle"][i])
		if nn.has("home"):
			sim.home_cell[i] = int(nn["home"][i])
		sim.near[i] = int(nn["near"][i])
		sim.near_slot[i] = -1
		hpn[i] = int(nn["hp"][i])
		astate[i] = int(nn["state"][i])
		meter[i] = int(nn["meter"][i])
		timer[i] = int(nn["timer"][i])
		lastpos[i] = int(nn["last"][i])
		postc[i] = int(nn["post"][i])
		yenn[i] = int(nn["yen"][i])
		if nn.has("energy"):
			energy[i] = int(nn["energy"][i])
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
	if nn.has("com"):
		sim.com.from_dict(nn["com"], tk2)
	log = []
	for l in d["log"]:
		log.append(str(l))
	portal = {}
	var pd: Dictionary = d.get("portal", {})
	if not pd.is_empty():
		_portal_set(int(pd["cell"]), int(pd["was"]), int(pd["under"]), JSON.parse_string(JSON.stringify(pd["offer"])))
	_compute_fov()


# ---------------------------------------------------------------- missions: people, objects, the portal
## the people of a generated site (mission_site.gd lists them): factions, health, weapons and stations; sticky, so the guards stand their posts until they notice you
func _mission_people() -> void:
	var site: Dictionary = city.get_meta("site")
	var agents: Dictionary = {}
	var risk: int = int(mission["offer"]["risk"])
	for k in site["agents"].size():
		var a: Dictionary = site["agents"][k]
		var f: int = int(a["fac"])
		fac[k] = f
		hpmax[k] = [25, 40, 45, 30, 35][f] + (6 if a["role"] == "target" else 0)
		hpn[k] = hpmax[k]
		gunc[k] = 0 if f == CIV else (1 if (a["role"] != "target" or risk >= 2) else 0)
		yenn[k] = 0 if f == CIV else rng.randi_range(30, 160)
		if a["name"] != "":
			nname[k] = a["name"]
		var cell: int = int(a["cell"])
		sim.pos[k] = cell
		sim.home_cell[k] = cell
		sim.dest[k] = cell
		sim.goal[k] = sim.HOME
		sim.arrive[k] = -1
		sim.sticky[k] = 1
		agents[str(k)] = a["role"]
	mission["agents"] = agents

## after the economy has handed out its roles: nobody on a site is a vendor or a fixer, and the hostage can be talked to
func _mission_roles() -> void:
	for i in sim.n:
		eco.role[i] = EC.NONE
	var h: int = MS.agent_with_role(self, "hostage")
	if h >= 0:
		eco.role[h] = EC.HOSTAGE
	sim.retier(pc)

func _mission_objects() -> void:
	var site: Dictionary = city.get_meta("site")
	if site.has("case"):
		_put(int(site["case"]), _new_item("trl_datacase"))

## a site loaded from a save: the progress it had (the layout and the people come back from the seed)
func _restore_mission_state(saved: Dictionary) -> void:
	for k in ["progress", "need", "fuse"]:
		mission[k] = int(saved.get(k, mission.get(k, 0)))
	for k in ["done", "planted", "freed"]:
		mission[k] = bool(saved.get(k, false))
	if mission["freed"]:
		var h: int = MS.agent_with_role(self, "hostage")
		if h >= 0:
			sim.sticky[h] = 0

## open a portal on the cell beside a terminal for an accepted offer; false if there is no room
func portal_open(offer: Dictionary, term_cell: int) -> bool:
	if not portal.is_empty() or not mission.is_empty() or done_contracts.has(String(offer["id"])):
		return false
	var tx: int = term_cell % size
	var ty: int = term_cell / size
	var order: Array = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	for d in order:
		var x: int = tx + d.x
		var y: int = ty + d.y
		if not in_bounds(x, y):
			continue
		var n: int = y * size + x
		var t: int = city.tiles[n]
		if sim.walk[n] == 0 or sim.at[n] != -1 or veh_at.g(n) != -1 or thing_at.g(n) != -1 or crit_at.g(n) != -1 or n == pc or items_at.has(n):
			continue
		if t in [CG.DOOR, CG.LOCKED, CG.STAIRS, CG.ELEVATOR, CG.LADDER, CG.MANHOLE, CG.TRACK, CG.PLATFORM] or n >= s2:
			continue
		_portal_set(n, t, city.under[n] if n < city.under.size() else 0, offer)
		say("A portal tears open beside the terminal: %s.  Step in to begin; leaving the site closes it." % offer["title"])
		sfx("select")
		return true
	return false

func _portal_set(cell: int, was: int, under_was: int, offer: Dictionary) -> void:
	portal = {"cell": cell, "was": was, "under": under_was, "offer": offer}
	city.tiles[cell] = CG.TID["portal"]
	if cell < city.under.size():
		city.under[cell] = was if was < CG.EXTRA0 else under_was

## close the portal (the mission is over, or was scrapped at the terminal): the street comes back as it was
func portal_close() -> void:
	if portal.is_empty():
		return
	var cell: int = int(portal["cell"])
	city.tiles[cell] = int(portal["was"])
	if cell < city.under.size():
		city.under[cell] = int(portal["under"])
	portal = {}


# ---------------------------------------------------------------- implant power (power.gd)
## the kJ in the store; a rig that has never been charged counts as full
var infinite_power: bool = false                  # tests and debugging: the store never runs down (and implants need no battery)

func power_left() -> float:
	if infinite_power:
		return 1.0e9
	return power if power >= 0.0 else float(PW.loadout(implants)["cap"])

func power_cap() -> float:
	return float(PW.loadout(implants)["cap"])

## hours of life the store has at the rig's draw (0 with no implants)
func power_hours() -> float:
	return PW.hours_left(implants, power_left())

func _power_tick() -> void:
	var L: Dictionary = PW.loadout(implants)
	if int(L["count"]) == 0:
		return
	var cap: float = float(L["cap"])
	if power < 0.0:
		power = cap
	if power <= 0.0:
		return
	power = maxf(0.0, minf(power, cap) - (float(L["draw"]) + nano_draw()) / float(PW.HOUR_TURNS))
	_power_notice(cap)

## say each warning once as the store runs down; recharging clears them
func _power_notice(cap: float) -> void:
	var f: float = power / maxf(1.0, cap)
	if power <= 0.0:
		if power_state != 3:
			power_state = 3
			say("Your implants go dark.  No power: you are a plain human until you recharge at a government post.")
			sfx("hurt")
	elif f <= 0.10:
		if power_state < 2:
			power_state = 2
			say("Implant power critical: about %d hours left.  Find a charging post." % int(ceil(power_hours())))
			sfx("blip")
	elif f <= 0.25:
		if power_state < 1:
			power_state = 1
			say("Implant power low: about %d hours left." % int(ceil(power_hours())))
			sfx("blip")

## deliver kJ into the store (a charging post, or a person drained); returns what went in
func power_add(kj: float) -> float:
	var cap: float = power_cap()
	if cap <= 0.0:
		return 0.0
	var before: float = power_left()
	power = minf(cap, before + kj)
	var f: float = power / cap
	power_state = 0 if f > 0.25 else (1 if f > 0.10 else 2)
	return power - before

## a freshly fitted implant comes charged: its share of a full charge goes into the store
func power_install(id: String) -> void:
	var d: Dictionary = IMP.get_def(id)
	if d.is_empty():
		return
	var cap: float = power_cap()
	power = minf(cap, power_left() + PW.battery_of(d)) if power >= 0.0 else -1.0       # (a battery comes charged)
	power_state = 0

## taking an implant out takes its share of the charge with it
func power_uninstall(id: String) -> void:
	var d: Dictionary = IMP.get_def(id)
	if d.is_empty():
		return
	var cap: float = power_cap()
	if power >= 0.0:
		power = clampf(power_left() - PW.battery_of(d), 0.0, cap)
	power_state = 0

## the district of a cell, 0 lower .. 2 upper (the price of power follows it)
func district_of(cell: int) -> int:
	return city.wealth_at(cell % s2)

## what the post at `cell` asks for delivering `kj`
func charge_quote(cell: int, kj: float) -> Dictionary:
	return PW.quote(implants, district_of(cell), kj)

## pay for and take `kj` at a post: false (and nothing happens) if the yen is short or the rig is already full
func recharge(cell: int, kj: float) -> bool:
	var room: float = power_cap() - power_left()
	kj = minf(kj, room)
	if kj < 1.0:
		say("The cells are already full.")
		return false
	var q: Dictionary = charge_quote(cell, kj)
	if yen < int(q["total"]):
		say("You can't afford that charge (¥%d)." % int(q["total"]))
		return false
	yen -= int(q["total"])
	var got: float = power_add(kj)
	say("The post hums.  +%d kJ for ¥%d (fee %d, implant tax %d, power %d, power tax %d).  Implants good for about %d hours." % [int(got), int(q["total"]), int(q["fee"]), int(q["tax"]), int(q["energy"]), int(q["ptax"]), int(power_hours())])
	sfx("pick")
	return true

## the vehicles a charging bank (its north-west cell `bank`) can reach: the one you are in, and any vehicle with a tile within two of the bank
func vehicles_at_bank(bank: int) -> Array:
	var out: Array = []
	var bx: int = bank % size
	var by: int = (bank / size) % size
	var base: int = (bank / s2) * s2
	for vi in vehicles.size():
		var v: Dictionary = vehicles[vi]
		if v.get("wreck", false) or int(v["cell"]) / s2 != bank / s2:
			continue
		var near := false
		for c in vs.cells(v):
			var cx: int = c % size
			var cy: int = (c / size) % size
			if cx >= bx - 3 and cx <= bx + 4 and cy >= by - 3 and cy <= by + 4:
				near = true
				break
		if near:
			out.append(vi)
	return out

## pay for and take `pct` percent of charge into vehicle `vi` at the bank: false (nothing happens) if the pack is full or the yen is short
func recharge_vehicle(bank: int, vi: int, pct: int) -> bool:
	var v: Dictionary = vehicles[vi]
	pct = mini(pct, 100 - int(v["charge"]))
	if pct <= 0:
		say("The pack is already full.")
		return false
	var cost: int = PW.vehicle_quote(pct, district_of(bank))
	if yen < cost:
		say("You can't afford that charge (¥%d)." % cost)
		return false
	yen -= cost
	v["charge"] = int(v["charge"]) + pct
	say("The cables thrum.  The %s takes +%d%% for ¥%d.  Battery %d%%." % [vs.KINDS[v["kind"]]["name"], pct, cost, int(v["charge"])])
	sfx("pick")
	return true

func _siphon_corpse(k: int) -> bool:
	var b: Dictionary = corpses[k]
	var left_in: int = corpse_kj(b)
	var room: float = power_cap() - power_left()
	if room < 1.0:
		say("Your own cells are full.")
		return false
	var take: int = mini(PW.siphon_take(left_in), int(room))
	b["kj"] = left_in - take
	var wi: int = int(b.get("who", -1))
	if wi >= 0 and wi < energy.size() and sim.alive[wi] == 0 and sim.pos[wi] == int(b["cell"]):
		energy[wi] = int(b["kj"])
	power_add(float(take))
	skill_up("engineering", 3)
	_noise(pc, 3)
	say("You clamp a lead to the body of %s and draw %d kJ (%d left).  Implants good for about %d hours." % [b["name"], take, int(b["kj"]), int(power_hours())])
	sfx("select")
	end_turn()
	return true

## energy of one person (kJ)
func npc_energy(i: int) -> int:
	if int(energy[i]) >= 0:
		return int(energy[i])
	return PW.npc_remaining(int(fac[i]), i, seed_value, sim.tick)

## draw power from a person who is down (dead or stunned) and next to you; needs an implant interface of your own
func act_siphon() -> bool:
	if implants.is_empty() or int(PW.loadout(implants)["count"]) == 0:
		say("You have no implants to draw power into.")
		return false
	var best := -1
	for k in sim.near_list.size():
		var i: int = sim.near_list[k]
		if cheb(sim.pos[i], pc) <= 1 and (sim.alive[i] == 0 or stun[i] > 0 or astate[i] == SURRENDERED) and npc_energy(i) > 0:
			best = i
			break
	var body := -1
	if best < 0:
		for k in corpses.size():
			var cc: int = int(corpses[k]["cell"])
			if cheb(cc, pc) <= 1 and corpse_kj(corpses[k]) > 0 and z_of(cc) == z_of(pc):
				body = k
				break
	if best < 0 and body >= 0:
		return _siphon_corpse(body)
	if best < 0:
		say("Nobody here to draw from: they must be down or helpless, next to you, and still carry a charge.")
		return false
	var left_in: int = npc_energy(best)
	var take: int = PW.siphon_take(left_in)
	var room: float = power_cap() - power_left()
	if room < 1.0:
		say("Your own cells are full.")
		return false
	take = mini(take, int(room))
	energy[best] = left_in - take
	power_add(float(take))
	skill_up("engineering", 3)
	_noise(pc, 3)
	say("You clamp a lead to %s and draw %d kJ (%d left in them).  Implants good for about %d hours." % [name_of(best), take, int(energy[best]), int(power_hours())])
	sfx("select")
	end_turn()
	return true

## the energy cells of a fresh population: by faction
func _npc_energy_init() -> void:
	energy = PackedInt32Array()
	energy.resize(sim.n)
	energy.fill(-1)


# ---------------------------------------------------------------- health is per limb
## wounds not yet closed, in limb points (the doctor's bill is scaled from it)
func body_missing() -> int:
	var m := 0
	for l in BODY.LIMBS:
		m += int(body.mx[l]) - int(body.hp[l])
	return m

## close up to n points of wounds, one at a time on the most hurt working limb (the head and chest first on a tie); a disabled limb is not touched.  Returns the points healed.
## true when some limb is disabled (at 0): meals and ordinary healing skip it
func _disabled_hurt() -> bool:
	for l in BODY.LIMBS:
		if not body.ok(l):
			return true
	return false

func heal_body(n: int) -> int:
	var done := 0
	while done < n:
		var best := ""
		var bf := 2.0
		for l in BODY.LIMBS:
			if body.ok(l) and int(body.hp[l]) < int(body.mx[l]) and body.frac(l) < bf:
				bf = body.frac(l)
				best = l
		if best == "":
			break
		body.heal(best, 1)
		done += 1
	return done

## the head or the chest at 0 ends the run
func _die_check() -> void:
	if body.vital_dead() and not game_over:
		game_over = true
		say("You are dead.  Press [n] for a new life.")
