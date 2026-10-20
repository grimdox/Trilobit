extends RefCounted
## The island as a set of zone games.  One Game is live at a time (`game`); leaving a zone stores its state and builds or restores the next.
## The player (and the vehicle being driven) is carried across.  Zones that are not live are kept as save dictionaries in `cache`.
const GameScript = preload("res://src/game.gd")
const ISL = preload("res://src/island.gd")
const MS = preload("res://src/missions.gd")
const ORIGIN := "mission_origin"        # cache key of the physical-world game while the player is inside a mission site
const CITY_PEOPLE := 2000             # the city is big and packed: two thousand people (the performance budget in the design notes)

var island
var game
var cache: Dictionary = {}          # "x,y" -> save_dict of a zone that has been visited
var seed_value: int = 0
var switches: int = 0
var line: Dictionary = {}           # the rail line (see transit.gd), shared by every zone game
var origin_game = null              # the physical-world game, kept whole while the player is inside a mission site (saved into `cache` only when the world is saved)
var visited: Dictionary = {}        # "x,y" -> true (for the map)

static func key(z: Vector2i) -> String:
	return "%d,%d" % [z.x, z.y]

func people_for(z: Vector2i) -> int:
	if z == ISL.CITY_ZONE:
		return CITY_PEOPLE
	match island.zone_kind(z):
		"port": return 220
		"town": return 90
		"industry": return 70
	return 0

func start(sd: int, people: int = -1) -> void:
	seed_value = sd
	island = ISL.new(sd)
	game = _make(ISL.CITY_ZONE, people)
	visited[key(ISL.CITY_ZONE)] = true

func _make(z: Vector2i, people: int = -1):
	var g = GameScript.new(seed_value ^ (z.x * 7919 + z.y * 104729))
	g.world = self
	g.setup(people_for(z) if people < 0 else (people if z == ISL.CITY_ZONE else mini(people, people_for(z))), island, z)
	return g

## revive a stored zone
func _restore(z: Vector2i):
	return _restore_dict(cache[key(z)])

func _restore_dict(d: Dictionary):
	var g = GameScript.new(0)
	g.world = self
	g.island = island
	g.load_dict(d)
	g.world = self
	return g

# ------------------------------------------------------------------ mission sites
func in_site() -> bool:
	return origin_game != null or cache.has(ORIGIN)

## the time spent in a site passes in the street too: people who were walking and would have arrived by now are there (their arrival ticks went by while the game was put away)
func _catch_up(g) -> void:
	var sim = g.sim
	for t in sim.buckets.keys():
		if int(t) < sim.tick:
			for i in sim.buckets[t]:
				if sim.arrive[i] == int(t) and sim.near[i] == 0 and sim.alive[i] == 1:
					sim.pos[i] = sim.dest[i]
					sim.arrive[i] = -1
			sim.buckets.erase(t)

## the player steps into an open portal: the physical world is put away whole, the site is generated from the offer's seed, and the player is carried in
func enter_mission() -> bool:
	var g = game
	if g.portal.is_empty() or not g.mission.is_empty():
		return false
	var offer: Dictionary = g.portal["offer"]
	var carry: Dictionary = g.player_dict()
	origin_game = g
	var ng = GameScript.new(int(offer["seed"]))
	ng.world = self
	ng.setup(0, null, Vector2i(-1, -1), MS.new_state(offer))
	ng.apply_player(carry)
	ng.last_pc = ng.pc
	ng.sim.retier(ng.pc)
	ng._compute_fov()
	game = ng
	switches += 1
	ng.say("You step through.  %s.  The exit portal is behind you; leaving closes it for good." % offer["title"])
	return true

## the player leaves the site (through the exit portal, or thrown out by a blast): the outcome is judged, the site is dropped, the physical world comes
## back as it was with the portal closed, and a won contract pays.  Returns the outcome dictionary.
func leave_mission(forced: String = "") -> Dictionary:
	var g = game
	if g.mission.is_empty() or not in_site():
		return {}
	var res: Dictionary = MS.outcome(g, forced)
	if res["outcome"] == "success" and res["type"] == "recover":
		var case = g.eco._find("trl_datacase")
		if case != null:
			g.eco._remove(case)
	if forced == "blast":
		for bl in ["l_arm", "r_arm", "l_leg", "r_leg"]:        # the blast takes the limbs, never the head or chest
			g._limb_hit(bl, 5)
	var carry: Dictionary = g.player_dict()
	var og = origin_game if origin_game != null else _restore_dict(cache[ORIGIN])
	origin_game = null
	cache.erase(ORIGIN)
	var job: Dictionary = og.eco.job.duplicate(true)
	og.apply_player(carry)
	og.eco.job = job
	_catch_up(og)
	og.portal_close()
	if res["outcome"] == "success":
		og.yen += int(res["reward"])
		og.done_contracts[String(g.mission["offer"]["id"])] = true
		og.sfx("pick")
	og.say(String(res["text"]))
	og.last_pc = og.pc
	og.sim.retier(og.pc)
	og._compute_fov()
	game = og
	switches += 1
	return res

## has the player gone far enough into another zone's territory to hand over to it?  (three tiles of hysteresis)
func poll() -> bool:
	var g = game
	if g == null or g.island == null:
		return false
	var p: Vector2i = g.global_pos()
	var owner: Vector2i = ISL.zone_owner(p.x, p.y)
	if owner == g.zone:
		return false
	var o: Vector2i = ISL.zone_origin(g.zone.x, g.zone.y)
	var half: int = ISL.zone_size(g.zone.x, g.zone.y) / 2
	var centre := Vector2i(o.x + half, o.y + half)
	var back := Vector2i(p.x + signi(centre.x - p.x) * 3, p.y + signi(centre.y - p.y) * 3)
	if ISL.zone_owner(back.x, back.y) == g.zone:
		return false
	return enter(owner)

## hand over to zone `dest`, carrying the player and any vehicle they are driving; false if there is nowhere to arrive
func enter(dest: Vector2i) -> bool:
	var g = game
	var p: Vector2i = g.global_pos()
	var carry: Dictionary = g.player_dict()
	var veh: Dictionary = {}
	var seat_dx := 0
	if g.in_vehicle >= 0:
		veh = g.vs.export_vehicle(g.in_vehicle)
	var from_zone: Vector2i = g.zone
	g.in_vehicle = -1
	var saved: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var ng
	var dk := key(dest)
	if cache.has(dk):
		ng = _restore(dest)
	else:
		ng = _make(dest)
	var o: Vector2i = ISL.zone_origin(dest.x, dest.y)
	var lx: int = clampi(p.x - o.x, 1, ng.size - 2)
	var ly: int = clampi(p.y - o.y, 1, ng.size - 2)
	var cell: int = ly * ng.size + lx
	ng.apply_player(carry)
	ng.transit.adopt(g.transit)
	if not veh.is_empty():
		var vi: int = ng.vs.import_vehicle(veh, cell)
		if vi >= 0:
			ng.in_vehicle = vi
			ng.vehicles[vi]["driver"] = -2
			ng.pc = cell
			ng.sim.retier(ng.pc)
		else:
			veh = {}
	if veh.is_empty():
		var seat: int = ng.transit.seat_cell()
		if seat >= 0:
			cell = seat
		else:
			ng.transit.riding = -1
			cell = _free_cell(ng, cell)
		ng.pc = cell
		ng.in_vehicle = -1
	ng.last_pc = ng.pc
	ng.sim.retier(ng.pc)
	ng.fov.compute(ng.pc % ng.size, ng.pc / ng.size, ng.sight_radius())
	cache[key(from_zone)] = saved
	game = ng
	switches += 1
	visited[dk] = true
	ng.say("You cross into %s." % island.zone_name(dest))
	return true

## the nearest cell a person can stand on
func _free_cell(g, near: int) -> int:
	var nx: int = near % g.size
	var ny: int = near / g.size
	for r in 40:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x: int = nx + dx
				var y: int = ny + dy
				if not g.in_bounds(x, y):
					continue
				var c: int = y * g.size + x
				if g.sim.walk[c] == 1 and g.sim.at[c] == -1 and g.veh_at[c] == -1 and g.thing_at[c] == -1 and g.crit_at[c] == -1:
					return c
	return near

# ------------------------------------------------------------------ saving
func save_dict() -> Dictionary:
	var zones := {}
	for k in cache:
		zones[k] = cache[k]
	if origin_game != null:
		zones[ORIGIN] = JSON.parse_string(JSON.stringify(origin_game.save_dict()))
	return {"layout": ISL.LAYOUT_VER, "island": seed_value, "zone": [game.zone.x, game.zone.y], "game": game.save_dict(), "zones": zones, "visited": visited.keys(), "switches": switches}

func load_dict(d: Dictionary) -> void:
	if int(d.get("layout", 1)) != ISL.LAYOUT_VER:
		# the map was rebuilt since this save (a different city, a wider highway): its cell numbers mean nothing now, so start afresh on the same island
		start(int(d["island"]), CITY_PEOPLE)
		game.say("That save was made before the city was rebuilt; you start again on the same island.")
		return
	seed_value = int(d["island"])
	island = ISL.new(seed_value)
	cache = d.get("zones", {})
	visited = {}
	for k in d.get("visited", []):
		visited[String(k)] = true
	switches = int(d.get("switches", 0))
	var g = GameScript.new(0)
	g.world = self
	g.island = island
	g.load_dict(d["game"] if d.has("game") else d)
	g.world = self
	game = g
