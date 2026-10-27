extends RefCounted
## Spike test 1: many NPCs with level-of-detail.
##  near the player (< near_radius): a full agent, one step per tick down a shared flow field, with an occupancy check and a
##  line-of-sight perception check against the player (a stand-in for real AI cost)
##  far: abstract.  Only a goal, a destination and an arrival tick; nothing is computed until it arrives or the player comes close,
##  when its position is reconstructed by walking the field for the elapsed time (capped).
## Struct-of-arrays storage, a bucketed arrival queue, and a rolling slice for tier checks keep the per-tick cost bounded.
const CLK = preload("res://src/clock.gd")
const FF = preload("res://src/flowfield.gd")
const COM = preload("res://src/commute.gd")
const HOME := 0
const WORK := 1
const SHOP := 2

var size: int
var rows: int = 0                  # rows of the (possibly stacked) map
var s2: int = 0                    # cells per level
var links: Dictionary = {}
var haslink: PackedByteArray = PackedByteArray()
var sticky: PackedByteArray        # 1 = never leaves its home (squatters)
var homes_g: PackedInt32Array
var homes_t: PackedInt32Array
var works_g: PackedInt32Array
var works_t: PackedInt32Array
var shops_g: PackedInt32Array
var shops_t: PackedInt32Array
var tiles: PackedByteArray
var floorish: PackedByteArray      # per tile id: a plain floor or one of the special floors (lobbies, flats, shops): where people may stand about
var walk: PackedByteArray
var opaque: PackedByteArray
var fields: Array = []
var homes: PackedInt32Array
var works: PackedInt32Array
var shops: PackedInt32Array
var n: int = 0
var near_radius: int = 45
var rng := RandomNumberGenerator.new()
var com                            # the daily commute (commute.gd)
var station_doors: PackedInt32Array = PackedInt32Array()
var road_id: int = 1

var pos: PackedInt32Array          # cell index
var dest: PackedInt32Array         # specific destination cell
var home_cell: PackedInt32Array
var goal: PackedByteArray
var near: PackedByteArray          # 1 if a full agent
var idle: PackedByteArray          # near agent that has arrived
var depart: PackedInt32Array
var arrive: PackedInt32Array       # tick of arrival for far agents in transit, -1 if none
var at: PackedInt32Array           # agent index standing on each cell (near agents only), -1 if none
var buckets: Dictionary = {}       # tick -> PackedInt32Array of agents
var near_list: PackedInt32Array
var near_slot: PackedInt32Array
var tick: int = 0
var player: int = 0
var promotions: int = 0
var demotions: int = 0
var churn_per_tick: int = 0        # stress option: this many random agents get a new random goal every tick (keeps everyone walking)
var perception_standin: bool = true   # the scale test's stand-in LOS check; the game turns it off and runs real awareness instead
var alive: PackedByteArray
var ctl: PackedByteArray           # 1 = an AI routine (awareness, combat, flight) drives this near agent instead of the routine
var seen_player: int = 0           # agents that currently see the player (output of the perception stand-in)

func setup(city, count: int, seed: int) -> void:
	rng.seed = seed
	size = city.size
	tiles = city.tiles
	homes = city.homes
	works = city.works
	shops = city.shops
	s2 = size * size
	station_doors = city.station_doors
	road_id = city.ROAD
	rows = tiles.size() / size
	links = city.links
	haslink = city.haslink
	if haslink.size() != tiles.size():
		haslink = PackedByteArray()
		haslink.resize(tiles.size())
	if city.homes_g.size() > 0:
		homes_g = city.homes_g; homes_t = city.homes_t
		works_g = city.works_g; works_t = city.works_t
		shops_g = city.shops_g; shops_t = city.shops_t
	else:
		homes_g = homes; homes_t = PackedInt32Array()
		works_g = works; works_t = PackedInt32Array()
		shops_g = shops; shops_t = PackedInt32Array()
	walk = PackedByteArray()
	opaque = PackedByteArray()
	walk.resize(tiles.size())
	opaque.resize(tiles.size())
	var lut := PackedByteArray()
	floorish = PackedByteArray()
	for t in 256:
		lut.append(1 if (t < city.WALK.size() and city.WALK[t] == 1) else 0)
		floorish.append(1 if city.is_floor(t) else 0)
	# walkable / opaque per cell.  The upper levels are open air nearly everywhere (walk 0, opaque 0, which is what the arrays start as), so a
	# run of 64 air cells is skipped by one comparison instead of 64 steps.
	var shut_id: int = city.TID["door_closed"]          # a shut door and a locked door cannot be seen through
	var seg := 64
	var air_seg := PackedByteArray()
	air_seg.resize(seg)
	air_seg.fill(7)
	var nlev: int = tiles.size() / s2
	for lvl in nlev:
		var upper: bool = lvl >= 1 and lvl <= city.zmax and size % seg == 0
		for row in size:
			var rb: int = lvl * s2 + row * size
			if not upper:
				for i in range(rb, rb + size):
					var t := tiles[i]
					walk[i] = lut[t]
					opaque[i] = 1 if (t == 2 or t == 17 or t == 27 or t == 28 or t == 29 or t == 22 or t == shut_id) else 0
				continue
			for x0 in range(0, size, seg):
				var a: int = rb + x0
				if tiles.slice(a, a + seg) == air_seg:
					continue
				for i in range(a, a + seg):
					var t := tiles[i]
					walk[i] = lut[t]
					opaque[i] = 1 if (t == 2 or t == 17 or t == 27 or t == 28 or t == 29 or t == 22 or t == shut_id) else 0
	n = count
	com = COM.new()
	com.setup(self)
	if not city.houses.is_empty() or not city.apartments.is_empty():
		com.prepare()                                      # the walking grid is built on its own thread while the distance fields are
	# the three distance fields (to home, work, shop) are independent: one thread each
	var srcs := [homes, works, shops]
	var made := [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	var ths: Array = []
	for k in 3:
		var th := Thread.new()
		th.start(func(): made[k] = FF.build(tiles, size, walk, srcs[k], links, haslink))
		ths.append(th)
	for th in ths:
		th.wait_to_finish()
	fields = made
	pos = PackedInt32Array(); pos.resize(n)
	dest = PackedInt32Array(); dest.resize(n)
	home_cell = PackedInt32Array(); home_cell.resize(n)
	goal = PackedByteArray(); goal.resize(n)
	near = PackedByteArray(); near.resize(n)
	idle = PackedByteArray(); idle.resize(n)
	depart = PackedInt32Array(); depart.resize(n)
	arrive = PackedInt32Array(); arrive.resize(n); arrive.fill(-1)
	near_slot = PackedInt32Array(); near_slot.resize(n); near_slot.fill(-1)
	at = PackedInt32Array(); at.resize(tiles.size()); at.fill(-1)
	sticky = PackedByteArray(); sticky.resize(n)
	alive = PackedByteArray(); alive.resize(n); alive.fill(1)
	ctl = PackedByteArray(); ctl.resize(n)
	var dw: PackedInt32Array = _dwellings(city, n)
	for i in n:
		var h: int = dw[i] if dw.size() == n else _scatter(_pick(homes_g, homes_t), 9)
		home_cell[i] = h
		pos[i] = h
		dest[i] = h
		goal[i] = HOME

## One home cell per person.  Houses first (one to four people each, fewer in the rich districts, more in the poor), then the flats of the
## towers (one to three), then the old home markers as households of one to three, until everyone has a roof.  Every person gets a cell of
## their own inside the dwelling.  Returns an empty array for a map with no houses or flats (a harbour, a mission site).
func _dwellings(city, count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if city.houses.is_empty() and city.apartments.is_empty():
		return out
	var taken: Dictionary = {}
	var hs: Array = city.houses.duplicate()
	var fl: Array = city.apartments.duplicate()
	_shuffle(hs)
	_shuffle(fl)
	var covered := PackedByteArray()                      # ground cells that belong to a house: the old home markers do not put their people in there
	covered.resize(s2)
	var skip: Dictionary = {}
	for h in city.houses:
		skip[int(h["cell"])] = true
		for y in range(int(h["y0"]), int(h["y1"]) + 1):
			for x in range(int(h["x0"]), int(h["x1"]) + 1):
				covered[y * size + x] = 1
	var legacy: Array = []                                # the old markers: generic ground-level homes (the flats are the apartment units)
	for c in homes_g:
		if not skip.has(c) and c < s2 and covered[c] == 0:
			legacy.append(c)
	_shuffle(legacy)
	var odds: Array = [[0.20, 0.30, 0.30, 0.20], [0.15, 0.35, 0.30, 0.20], [0.30, 0.40, 0.20, 0.10]]     # 1..4 people: poor, middle, rich
	for h in hs:
		if out.size() >= count:
			break
		var k: int = _roll(odds[city.wealth_at(int(h["cell"]))]) + 1
		for _p in k:
			if out.size() < count:
				out.append(_room(int(h["x0"]), int(h["y0"]), int(h["x1"]), int(h["y1"]), 0, int(h["cell"]), taken))
	for a in fl:
		if out.size() >= count:
			break
		var k2: int = _roll([0.4, 0.4, 0.2]) + 1
		var r: Rect2i = a["rect"]
		var base: int = (int(a["cell"]) / s2) * s2
		for _p in k2:
			if out.size() < count:
				out.append(_room(r.position.x, r.position.y, r.end.x - 1, r.end.y - 1, base, int(a["cell"]), taken))
	for m in legacy:
		if out.size() >= count:
			break
		var k3: int = _roll([0.4, 0.4, 0.2]) + 1
		for _p in k3:
			if out.size() < count:
				var cell: int = _scatter(m, 9)
				for _r in 6:
					if not taken.has(cell) and covered[cell % s2] == 0 and cell < s2:
						break
					cell = _scatter(m, 9)
				if taken.has(cell) or covered[cell % s2] == 1:
					cell = m
				taken[cell] = true
				out.append(cell)
	var lap := 0
	while out.size() < count and not legacy.is_empty() and lap < 12:          # more people than roofs: the old markers take another household each
		for m in legacy:
			if out.size() >= count:
				break
			var cell: int = _scatter(m, 9 + lap)
			if taken.has(cell) or covered[cell % s2] == 1 or cell >= s2:
				cell = m
			taken[cell] = true
			out.append(cell)
		lap += 1
	while out.size() < count:
		out.append(_scatter(_pick(homes_g, homes_t), 9))
	return out

func _roll(p: Array) -> int:
	var r: float = rng.randf()
	for k in p.size():
		r -= float(p[k])
		if r < 0.0:
			return k
	return p.size() - 1

func _shuffle(a: Array) -> void:
	for k in range(a.size() - 1, 0, -1):
		var j: int = rng.randi() % (k + 1)
		var t = a[k]
		a[k] = a[j]
		a[j] = t

## a free standing cell of its own inside a rectangle of one level
func _room(x0: int, y0: int, x1: int, y1: int, base: int, fallback: int, taken: Dictionary) -> int:
	for _t in 30:
		var c: int = base + rng.randi_range(y0, y1) * size + rng.randi_range(x0, x1)
		if c < tiles.size() and not taken.has(c) and floorish[tiles[c]] == 1 and walk[c] == 1:
			taken[c] = true
			return c
	return fallback

func _dist_to(cell_a: int, cell_b: int) -> int:
	return maxi(absi(cell_a % size - cell_b % size), absi(cell_a / size - cell_b / size))

## a random walkable floor cell within r of a marker, so that people sharing a building do not share a cell
func _pick(g: PackedInt32Array, t: PackedInt32Array) -> int:
	if t.is_empty() or (not g.is_empty() and rng.randf() < 0.55):
		return g[rng.randi() % g.size()]
	return t[rng.randi() % t.size()]

func _scatter(c: int, r: int) -> int:
	for _t in 24:
		var nx := c % size + rng.randi_range(-r, r)
		var ny := c / size + rng.randi_range(-r, r)
		if nx < 0 or ny < 0 or nx >= size or ny >= size:
			continue
		var nc := ny * size + nx
		if floorish[tiles[nc]] == 1 and walk[nc] == 1:
			return nc
	return c

func _pick_dest(g: int, i: int) -> int:
	match g:
		WORK: return _scatter(_pick(works_g, works_t), 4)
		SHOP: return _scatter(_pick(shops_g, shops_t), 4)
		_: return home_cell[i]

## a new goal for agent i
func set_goal(i: int, g: int) -> void:
	if alive[i] == 0 or sticky[i] == 1:
		return
	if com.leg[i] != 0:
		return
	goal[i] = g
	dest[i] = _pick_dest(g, i)
	if near[i] == 1:
		idle[i] = 0
	else:
		var d: int = fields[g][pos[i]]
		if d >= FF.UNREACHED:
			return
		depart[i] = tick
		arrive[i] = tick + d
		_bucket(arrive[i], i)

func _bucket(t: int, i: int) -> void:
	if not buckets.has(t):
		buckets[t] = PackedInt32Array()
	buckets[t].append(i)

func _schedule() -> void:
	var hour := (tick / CLK.HOUR) % 24
	for i in n:
		var r := rng.randf()
		var g := int(goal[i])
		if com.leg[i] != 0:
			continue
		if com.wc[i] >= 0 and sticky[i] == 0:
			# people with a job: the commute (commute.gd) takes them to work and home; the hour here only adds the lunch break and sends stragglers home
			if hour == 12 and r < 0.25 and g == WORK:
				set_goal(i, SHOP)
			elif hour == 13 and g == SHOP:
				com.start(i, WORK)
			elif hour == 21 and g != HOME:
				com.start(i, HOME)
			continue
		if hour == 7 and r < 0.6 and g == HOME:
			set_goal(i, WORK)
		elif hour == 12 and r < 0.25 and g == WORK:
			set_goal(i, SHOP)
		elif hour == 13 and g == SHOP:
			set_goal(i, WORK)
		elif hour == 17 and g != HOME and r < 0.9:
			set_goal(i, SHOP if r < 0.15 else HOME)
		elif hour == 19 and g == SHOP:
			set_goal(i, HOME)
		elif hour == 21 and g != HOME:
			set_goal(i, HOME)

func _promote(i: int) -> void:
	# reconstruct the position of an agent that was in transit
	if com.leg[i] == 1 or com.leg[i] == 3:
		com.reconstruct(i)
		arrive[i] = -1
	elif arrive[i] >= 0:
		var elapsed := mini(tick - depart[i], 400)
		var f: PackedInt32Array = fields[goal[i]]
		var c := pos[i]
		for _s in elapsed:
			var best := c
			var bv: int = f[c]
			for nb in [c - 1, c + 1, c - size, c + size]:
				if nb >= 0 and nb < f.size() and f[nb] < bv and walk[nb] == 1:
					bv = f[nb]
					best = nb
			if best == c:
				break
			c = best
		pos[i] = c
		arrive[i] = -1
	near[i] = 1
	idle[i] = 0
	near_slot[i] = near_list.size()
	near_list.append(i)
	pos[i] = _free_near(pos[i])
	at[pos[i]] = i
	promotions += 1

## nearest walkable cell without an agent (several agents share a home cell when they are stored far away)
func _free_near(c: int) -> int:
	if walk[c] == 1 and at[c] == -1:
		return c
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var nx := c % size + dx
				var ny := c / size + dy
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var nc := ny * size + nx
				if walk[nc] == 1 and at[nc] == -1:
					return nc
	return c

func _demote(i: int) -> void:
	var s := near_slot[i]
	var last := near_list[near_list.size() - 1]
	near_list[s] = last
	near_slot[last] = s
	near_list.resize(near_list.size() - 1)
	near_slot[i] = -1
	near[i] = 0
	ctl[i] = 0
	if at[pos[i]] == i:
		at[pos[i]] = -1
	if com.leg[i] == 1 or com.leg[i] == 3:
		com.on_demote(i)
	elif idle[i] == 0 and sticky[i] == 0:
		var d: int = fields[goal[i]][pos[i]]
		if d < FF.UNREACHED:
			depart[i] = tick
			arrive[i] = tick + d
			_bucket(arrive[i], i)
	demotions += 1

## line of sight on the tile grid (integer Bresenham), up to `limit` tiles
func _sees(a: int, b: int, limit: int) -> bool:
	var x0 := a % size
	var y0 := a / size
	var x1 := b % size
	var y1 := b / size
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	if maxi(dx, dy) > limit:
		return false
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while x0 != x1 or y0 != y1:
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
		if opaque[y0 * size + x0] == 1 and (x0 != x1 or y0 != y1):
			return false
	return true

## promote or demote one agent according to its distance to the player (a different level is always far)
func _tier(i: int) -> void:
	if alive[i] == 0 or com.leg[i] == 2:
		return
	var d := _dist_to(pos[i], player)
	if near[i] == 0:
		if arrive[i] >= 0:
			# in transit: its true position is only known roughly; use a straight-line estimate, on the level it is leaving for the
			# first half of the trip and the level it is heading for in the second half
			var total := maxi(1, arrive[i] - depart[i])
			var frac := clampf(float(tick - depart[i]) / total, 0.0, 1.0)
			var o: int = pos[i]
			var de: int = dest[i]
			var lvl: int = (o / s2) if frac < 0.5 else (de / s2)
			var tx: int = int(lerpf(o % size, de % size, frac))
			var ty: int = int(lerpf((o / size) % size, (de / size) % size, frac))
			d = _dist_to(lvl * s2 + ty * size + tx, player)
		if d < near_radius:
			_promote(i)
	else:
		if d > near_radius + 12:
			_demote(i)

## examine everyone now (after the player changes level, or on load) instead of waiting for the rolling slice
func retier(player_cell: int) -> void:
	player = player_cell
	com.budget = 60
	for i in n:
		_tier(i)

func step(player_cell: int) -> void:
	player = player_cell
	com.step()
	if tick % CLK.HOUR == 0:
		_schedule()
	for _c in churn_per_tick:
		set_goal(rng.randi() % n, rng.randi() % 3)
	# arrivals of far agents
	if buckets.has(tick):
		for i in buckets[tick]:
			if arrive[i] == tick and near[i] == 0 and alive[i] == 1:
				pos[i] = dest[i]
				arrive[i] = -1
				if com.leg[i] != 0:
					com.arrived(i)
		buckets.erase(tick)
	# tier checks on a rolling slice (each agent is examined once every 8 ticks)
	var slice := n / 8 + 1
	var start := (tick % 8) * slice
	for i in range(start, mini(start + slice, n)):
		_tier(i)
	# full agents
	seen_player = 0
	var plx := player % size
	var ply := player / size
	for k in near_list.size():
		var i := near_list[k]
		var c := pos[i]
		if perception_standin and absi(c % size - plx) <= 25 and absi(c / size - ply) <= 25:
			if _sees(c, player, 25):
				seen_player += 1
		if ctl[i] == 1 or sticky[i] == 1:
			continue
		if com.leg[i] != 0:
			com.follow(i)
			continue
		if idle[i] == 1:
			continue
		var f: PackedInt32Array = fields[goal[i]]
		var cur: int = f[c]
		if cur == 0 or cur >= FF.UNREACHED:
			idle[i] = 1
			# last mile: step into the exact destination if it is free and close (a small A* window replaces this later)
			if _dist_to(c, dest[i]) < 14 and at[dest[i]] == -1:
				at[c] = -1
				at[dest[i]] = i
				pos[i] = dest[i]
			continue
		var best := c
		var bv := cur
		var rot := (i + tick) & 3
		for t in 4:
			var nb := c
			match (t + rot) & 3:
				0: nb = c - 1
				1: nb = c + 1
				2: nb = c - size
				_: nb = c + size
			if nb < 0 or nb >= f.size() or walk[nb] == 0:
				continue
			if f[nb] < bv and at[nb] == -1:
				bv = f[nb]
				best = nb
		if best == c and haslink[c] == 1:
			for nb in links[c]:
				if f[nb] < bv and at[nb] == -1:
					bv = f[nb]
					best = nb
		if best != c:
			at[c] = -1
			at[best] = i
			pos[i] = best
	if not com.boarding.is_empty():
		for i in com.boarding:
			if near[i] == 1:
				_vanish(i)
		com.boarding.clear()
	if not com.demoting.is_empty():
		for i in com.demoting:
			if near[i] == 1:
				_demote(i)
		com.demoting.clear()
	tick += 1


## put agent i on a cell now (the game moves people around: collectors arriving, a squatter being stationed)
func place(i: int, cell: int) -> void:
	if alive[i] == 0:
		return
	com.forget(i)
	if near[i] == 1:
		idle[i] = 1
		_demote(i)
	arrive[i] = -1
	pos[i] = cell
	dest[i] = cell
	idle[i] = 1
	if _dist_to(cell, player) < near_radius:
		_promote(i)

## the game kills an agent: take it out of every structure
func remove_agent(i: int) -> void:
	if near[i] == 1:
		if at[pos[i]] == i:
			at[pos[i]] = -1
		var sl := near_slot[i]
		var last := near_list[near_list.size() - 1]
		near_list[sl] = last
		near_slot[last] = sl
		near_list.resize(near_list.size() - 1)
		near_slot[i] = -1
		near[i] = 0
	alive[i] = 0
	arrive[i] = -1
	ctl[i] = 0
	com.forget(i)

## a near agent goes out of sight on a ride (it is not on the map until it steps out the other end)
func _vanish(i: int) -> void:
	var sl := near_slot[i]
	var last := near_list[near_list.size() - 1]
	near_list[sl] = last
	near_slot[last] = sl
	near_list.resize(near_list.size() - 1)
	near_slot[i] = -1
	near[i] = 0
	ctl[i] = 0
	if at[pos[i]] == i:
		at[pos[i]] = -1
