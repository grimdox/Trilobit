extends RefCounted
## The island as a set of zone games.  One Game is live at a time (`game`); leaving a zone stores its state and builds or restores the next.
## The player (and the vehicle being driven) is carried across.  Zones that are not live are kept as save dictionaries in `cache`.
const GameScript = preload("res://src/game.gd")
const ISL = preload("res://src/island.gd")

var island
var game
var cache: Dictionary = {}          # "x,y" -> save_dict of a zone that has been visited
var seed_value: int = 0
var switches: int = 0
var line: Dictionary = {}           # the rail line (see transit.gd), shared by every zone game
var visited: Dictionary = {}        # "x,y" -> true (for the map)

static func key(z: Vector2i) -> String:
	return "%d,%d" % [z.x, z.y]

func people_for(z: Vector2i) -> int:
	if z == ISL.CITY_ZONE:
		return 1500
	if z == Vector2i(0, 1):
		return 220
	if z == Vector2i(2, 1):
		return 90
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
	var g = GameScript.new(0)
	g.world = self
	g.island = island
	g.load_dict(cache[key(z)])
	g.world = self
	return g

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
	ng.fov.compute(ng.pc % ng.size, ng.pc / ng.size, 18)
	cache[key(from_zone)] = saved
	game = ng
	switches += 1
	visited[dk] = true
	ng.say("You cross into %s." % ISL.zone_name(dest))
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
	return {"layout": ISL.LAYOUT_VER, "island": seed_value, "zone": [game.zone.x, game.zone.y], "game": game.save_dict(), "zones": zones, "visited": visited.keys(), "switches": switches}

func load_dict(d: Dictionary) -> void:
	if int(d.get("layout", 1)) != ISL.LAYOUT_VER:
		# the map was rebuilt since this save (a different city, a wider highway): its cell numbers mean nothing now, so start afresh on the same island
		start(int(d["island"]), 1500)
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
