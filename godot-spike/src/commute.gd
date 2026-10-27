extends RefCounted
## The daily commute.  Every person who has a job leaves home in the morning, goes to the one place they work (on foot, down into the subway
## at the nearest station and out of the one nearest the job, or in a car from the kerb nearest home) and comes back in the evening.
##
## A trip is up to three legs:  1 = on foot to the pick-up (a station stair or a kerb), 2 = riding (out of sight: only a clock runs),
## 3 = on foot to the destination.  A walker has the single leg 3.  A far agent is never simulated: it keeps a start tick, an end tick and
## an origin and a target cell, and appears at the target when the end tick comes.  A near agent walks a real route (A* on the ground, a
## breadth-first search through the stairs and lifts inside a tower).  When the player comes close, a far agent on foot is put along its
## route according to the time that has passed; riders are only ever seen at the two ends.
const FF = preload("res://src/flowfield.gd")
const CLK = preload("res://src/clock.gd")
const WALK_NUM := 23                 # a walker covers a tile per tick, but streets are crowded: a tile costs 1.15 ticks on average
const WALK_DEN := 20
const LONG := 80                     # a trip longer than this (in tiles, as the crow walks) is made by car or subway
const KERB_REACH := 24               # how far from the door the kerb or the stairs may be
const SUBWAY_SPEED := 7              # tiles per tick, and a wait for the train
const SUBWAY_WAIT := 20
const CAR_SPEED_NUM := 2             # a car covers 3.5 tiles per tick (7 / 2) in traffic
const ROUTES_PER_TICK := 3

var s                                # the sim
var size: int = 0
var s2: int = 0
var leg: PackedByteArray             # 0 = at rest (or on some other errand), 1 on foot to the pick-up, 2 riding, 3 on foot to the destination
var wc: PackedInt32Array             # the cell this person works at, -1 = none (the old nearest-marker behaviour)
var mode: PackedByteArray            # the way they make a long trip: 1 = subway, 2 = car
var cdep: PackedInt32Array           # when they leave for work, a tick of the day (06:00 .. 08:30)
var cret: PackedInt32Array           # when they leave work (16:30 .. 19:00)
var dayw: PackedInt32Array           # the day they last set out for work / for home (-1 = never)
var dayh: PackedInt32Array
var tp: PackedInt32Array             # pick-up cell of the trip, drop-off cell, final cell
var td: PackedInt32Array
var te: PackedInt32Array
var lo: PackedInt32Array             # the cell the current leg began at, and its start and end ticks
var lt0: PackedInt32Array
var lt1: PackedInt32Array
var rtk: PackedInt32Array            # ticks the ride takes
var routes: Dictionary = {}          # agent -> PackedInt32Array (cells), near agents only
var rpos: Dictionary = {}            # agent -> index of the cell the agent stands on
var blocked: Dictionary = {}
var boarding: Array = []
var demoting: Array = []
var dep_b: Array = []                # minute of the day -> agents leaving for work then
var ret_b: Array = []
var budget: int = 0
var started: bool = false
var starts: int = 0                  # trips begun (a statistic for the tests)
var _astar: AStarGrid2D = null
var _comp := PackedInt32Array()     # the connected piece of ground each ground cell belongs to (see _build_grid)
var main_comp: int = 0
var _thread: Thread = null
var doors: PackedInt32Array = PackedInt32Array()   # subway station street entrances

func setup(sim) -> void:
	s = sim
	size = s.size
	s2 = s.s2
	var n: int = s.n
	leg = PackedByteArray(); leg.resize(n)
	wc = PackedInt32Array(); wc.resize(n); wc.fill(-1)
	mode = PackedByteArray(); mode.resize(n)
	cdep = PackedInt32Array(); cdep.resize(n)
	cret = PackedInt32Array(); cret.resize(n)
	dayw = PackedInt32Array(); dayw.resize(n); dayw.fill(-1)
	dayh = PackedInt32Array(); dayh.resize(n); dayh.fill(-1)
	tp = PackedInt32Array(); tp.resize(n)
	td = PackedInt32Array(); td.resize(n)
	te = PackedInt32Array(); te.resize(n)
	lo = PackedInt32Array(); lo.resize(n)
	lt0 = PackedInt32Array(); lt0.resize(n)
	lt1 = PackedInt32Array(); lt1.resize(n)
	rtk = PackedInt32Array(); rtk.resize(n)

## the clocks of a person and the way they travel: set once, from a hash of the person, so a loaded game gives the same answers
func assign(i: int, work_cell: int) -> void:
	wc[i] = work_cell
	var h: int = (hash([s.size, i, "commute"]) & 0x7fffffff)
	cdep[i] = (360 + h % 150) * CLK.MIN                # 06:00 .. 08:29
	cret[i] = (990 + (h / 150) % 150) * CLK.MIN        # 16:30 .. 18:59
	mode[i] = 1 if (h / 22500) % 100 < 42 else 2

## put the agents in their minute buckets (after every assign)
func index() -> void:
	dep_b = []
	ret_b = []
	for _m in 1440:
		dep_b.append(PackedInt32Array())
		ret_b.append(PackedInt32Array())
	for i in s.n:
		if wc[i] >= 0 and s.sticky[i] == 0 and s.alive[i] == 1:
			dep_b[cdep[i] / CLK.MIN].append(i)
			ret_b[cret[i] / CLK.MIN].append(i)
	doors = s.station_doors
	var any := false
	for i in s.n:
		if wc[i] >= 0:
			any = true
			break
	if any:
		prepare()                                          # (a no-op when the sim started it at setup)

## the walking grid is built on a thread (about half a second on the big map), and waited for the first time a route is wanted
func prepare() -> void:
	if _astar != null or _thread != null:
		return
	_thread = Thread.new()
	_thread.start(_build_grid.bind(s.walk.duplicate(), size))

func _build_grid(walk: PackedByteArray, sz: int) -> void:
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, sz, sz)
	a.cell_size = Vector2(1, 1)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	a.update()
	for y in sz:
		var b: int = y * sz
		for x in sz:
			if walk[b + x] == 0:
				a.set_point_solid(Vector2i(x, y), true)
	# which streets and rooms are joined to which: one number per ground cell (0 = not walkable).  A path between two different numbers does not exist,
	# and finding that out by search would mean searching the whole map.
	var cm := PackedInt32Array()
	cm.resize(sz * sz)
	var stack := PackedInt32Array()
	var label := 0
	for st in sz * sz:
		if walk[st] == 0 or cm[st] != 0:
			continue
		label += 1
		cm[st] = label
		stack.resize(0)
		stack.append(st)
		while not stack.is_empty():
			var cur: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var cx: int = cur % sz
			if cx > 0 and walk[cur - 1] == 1 and cm[cur - 1] == 0:
				cm[cur - 1] = label
				stack.append(cur - 1)
			if cx < sz - 1 and walk[cur + 1] == 1 and cm[cur + 1] == 0:
				cm[cur + 1] = label
				stack.append(cur + 1)
			if cur >= sz and walk[cur - sz] == 1 and cm[cur - sz] == 0:
				cm[cur - sz] = label
				stack.append(cur - sz)
			if cur < sz * (sz - 1) and walk[cur + sz] == 1 and cm[cur + sz] == 0:
				cm[cur + sz] = label
				stack.append(cur + sz)
	_comp = cm
	_astar = a

func _grid() -> AStarGrid2D:
	if _astar == null and _thread != null:
		_thread.wait_to_finish()
		_thread = null
	return _astar

func wait_ready() -> void:
	_grid()

## the piece of ground a cell belongs to: a ground cell itself, a tower floor by the street cell its way down comes out at
func comp_of(c: int) -> int:
	_grid()
	if c < s2:
		return _comp[c]
	var g: PackedInt32Array = _to_ground(c)
	return _comp[g[g.size() - 1]] if not g.is_empty() else 0

## can a person get from a to b at all
func connected(a: int, b: int) -> bool:
	var ca: int = comp_of(a)
	return ca != 0 and ca == comp_of(b)

# ------------------------------------------------------------------ distances
func _xy(c: int) -> Vector2i:
	var f: int = c % s2
	return Vector2i(f % size, f / size)

func manh(a: int, b: int) -> int:
	var p := _xy(a)
	var q := _xy(b)
	return absi(p.x - q.x) + absi(p.y - q.y)

func walk_ticks(a: int, b: int) -> int:
	return manh(a, b) * WALK_NUM / WALK_DEN + 6 * absi(a / s2 - b / s2) + 2

func _nearest_door(c: int) -> int:
	var best := -1
	var bd := 1 << 30
	for d in doors:
		var m: int = manh(c, d)
		if m < bd:
			bd = m
			best = d
	return best

## the nearest road cell to c within KERB_REACH (only for cells on the ground)
func _kerb(c: int) -> int:
	if c >= s2:
		return -1
	var x: int = c % size
	var y: int = c / size
	for r in range(0, KERB_REACH + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var nc: int = ny * size + nx
				if s.tiles[nc] == s.road_id and s.walk[nc] == 1:
					return nc
	return -1

# ------------------------------------------------------------------ starting a trip
## agent i sets out for goal g (HOME or WORK) from wherever it is
func start(i: int, g: int) -> void:
	if s.alive[i] == 0 or s.sticky[i] == 1:
		return
	var e: int = s.home_cell[i] if g == s.HOME else wc[i]
	if e < 0:
		s.set_goal(i, g)
		return
	var o: int = s.pos[i]
	if s.near[i] == 0 and s.arrive[i] >= 0 and leg[i] == 0:
		o = s.dest[i]                                      # on some other errand: the trip starts where that ends
	s.goal[i] = g
	s.idle[i] = 0
	routes.erase(i)
	rpos.erase(i)
	starts += 1
	if o == e:
		leg[i] = 0
		s.dest[i] = e
		s.arrive[i] = -1
		if s.near[i] == 0:
			s.pos[i] = e
		else:
			s.idle[i] = 1
		return
	s.dest[i] = e
	te[i] = e
	var d: int = manh(o, e)
	var p := -1
	var q := -1
	var ride := 0
	if d > LONG and o < s2 and e < s2:
		if mode[i] == 1 and not doors.is_empty():
			var a: int = _nearest_door(o)
			var b: int = _nearest_door(e)
			if a != b and manh(o, a) + manh(b, e) < d * 7 / 10:
				p = a
				q = b
				ride = SUBWAY_WAIT + manh(a, b) / SUBWAY_SPEED
		if p < 0:
			var a2: int = _kerb(o)
			var b2: int = _kerb(e)
			if a2 >= 0 and b2 >= 0 and a2 != b2:
				p = a2
				q = b2
				ride = 6 + manh(a2, b2) * CAR_SPEED_NUM / 7
	tp[i] = p
	td[i] = q
	rtk[i] = ride
	lo[i] = o
	lt0[i] = s.tick
	if p < 0:
		leg[i] = 3
		lt1[i] = s.tick + walk_ticks(o, e)
	else:
		leg[i] = 1
		lt1[i] = s.tick + walk_ticks(o, p)
		s.dest[i] = p
	if s.near[i] == 0:
		s.arrive[i] = lt1[i]
		s._bucket(lt1[i], i)

## agent i has reached the target of its leg (a far agent has just been put there, a near agent has walked there)
func arrived(i: int) -> void:
	match leg[i]:
		1:                                                  # down the stairs / into the car: gone from the map
			leg[i] = 2
			routes.erase(i)
			rpos.erase(i)
			if s.near[i] == 1:
				if s.at[s.pos[i]] == i:
					s.at[s.pos[i]] = -1
				boarding.append(i)                         # taken off the near list once the sim has finished walking it
			s.pos[i] = tp[i]
			s.dest[i] = td[i]
			lo[i] = tp[i]
			lt0[i] = s.tick
			lt1[i] = s.tick + rtk[i]
			s.arrive[i] = lt1[i]
			s._bucket(lt1[i], i)
		2:                                                  # out of the station / the car: walking again
			leg[i] = 3
			s.pos[i] = td[i]
			lo[i] = td[i]
			lt0[i] = s.tick
			lt1[i] = s.tick + walk_ticks(td[i], te[i])
			s.dest[i] = te[i]
			s.arrive[i] = lt1[i]
			s._bucket(lt1[i], i)
		3:
			leg[i] = 0
			routes.erase(i)
			rpos.erase(i)
			s.arrive[i] = -1
			s.pos[i] = s.dest[i]
			if s.near[i] == 1:
				s.idle[i] = 1

## a far agent walking a leg has come near the player: put it along its route
func reconstruct(i: int) -> void:
	var total: int = maxi(1, lt1[i] - lt0[i])
	var f: float = clampf(float(s.tick - lt0[i]) / total, 0.0, 1.0)
	var from: int = lo[i]
	var to: int = s.dest[i]
	if budget > 0:
		var r: PackedInt32Array = build(from, to)
		budget -= 1
		if not r.is_empty():
			var k: int = clampi(int(f * (r.size() - 1)), 0, r.size() - 1)
			s.pos[i] = r[k]
			routes[i] = r
			rpos[i] = k
			return
	# no route yet: somewhere along the line (the walking agent finds its route when its turn comes)
	var a := _xy(from)
	var b := _xy(to)
	var lv: int = (from / s2) if f < 0.5 else (to / s2)
	if lv != 0:
		lv = 0
		a = _xy(from) if f < 0.5 else _xy(to)
		b = a
	var x: int = int(lerpf(a.x, b.x, f))
	var y: int = int(lerpf(a.y, b.y, f))
	s.pos[i] = lv * s2 + y * size + x

# ------------------------------------------------------------------ routes
## cells from a to b (both included): up or down through the building at either end, A* over the ground between
func build(a: int, b: int) -> PackedInt32Array:
	var _t0 := Time.get_ticks_usec()
	var r := _build(a, b)
	builds += 1
	build_us += Time.get_ticks_usec() - _t0
	return r

var builds: int = 0
var build_us: int = 0

func _build(a: int, b: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var ga: int = a
	var head := PackedInt32Array()
	if a >= s2:
		head = _to_ground(a)
		if head.is_empty():
			return out
		ga = head[head.size() - 1]
	var gb: int = b
	var tail := PackedInt32Array()
	if b >= s2:
		tail = _to_ground(b)
		if tail.is_empty():
			return out
		gb = tail[tail.size() - 1]
	var mid := PackedInt32Array()
	if ga == gb:
		mid.append(ga)
	else:
		var gr := _grid()
		if gr == null or _comp[ga] != _comp[gb] or _comp[ga] == 0:
			return out
		var p: Array = gr.get_id_path(Vector2i(ga % size, ga / size), Vector2i(gb % size, gb / size))
		if p.is_empty():
			return out
		mid.resize(p.size())
		for k in p.size():
			var v: Vector2i = p[k]
			mid[k] = v.y * size + v.x
	if head.size() > 1:
		out.append_array(head.slice(0, head.size() - 1))
	out.append_array(mid)
	for k in range(tail.size() - 2, -1, -1):
		out.append(tail[k])
	return out

## the way from an upper floor (or a cellar) down to the street: breadth first through the floors and the stairs and lifts that link them
func _to_ground(c: int) -> PackedInt32Array:
	var prev: Dictionary = {c: -1}
	var queue: Array = [c]
	var qi := 0
	var cx: int = c % size
	var cy: int = (c / size) % size
	var found := -1
	while qi < queue.size() and queue.size() < 60000:
		var cur: int = queue[qi]
		qi += 1
		if cur < s2:
			found = cur
			break
		var nbs: Array = [cur - 1, cur + 1, cur - size, cur + size]
		if s.haslink[cur] == 1:
			nbs.append_array(s.links[cur])
		for nb in nbs:
			if prev.has(nb) or nb < 0 or nb >= s.walk.size() or s.walk[nb] == 0:
				continue
			if absi(nb % size - cx) > 60 or absi((nb / size) % size - cy) > 60:
				continue
			prev[nb] = cur
			queue.append(nb)
	var out := PackedInt32Array()
	if found < 0:
		return out
	var k: int = found
	var rev: Array = []
	while k != -1:
		rev.append(k)
		k = prev[k]
	rev.reverse()
	out.append_array(PackedInt32Array(rev))
	return out

# ------------------------------------------------------------------ the near agents
## one step of a near agent along its route
func follow(i: int) -> void:
	var c: int = s.pos[i]
	var tgt: int = s.dest[i]
	if c == tgt:
		arrived(i)
		return
	var r: PackedInt32Array = routes.get(i, PackedInt32Array())
	var k: int = int(rpos.get(i, -1))
	if r.is_empty() or k < 0 or k >= r.size() or r[k] != c or r[r.size() - 1] != tgt:
		if budget <= 0:
			return
		budget -= 1
		r = build(c, tgt)
		if r.is_empty():
			_skip(i)
			return
		routes[i] = r
		k = 0
	if k + 1 >= r.size():
		arrived(i)
		return
	var nb: int = r[k + 1]
	if s.at[nb] == -1:
		s.at[c] = -1
		s.at[nb] = i
		s.pos[i] = nb
		rpos[i] = k + 1
		blocked[i] = 0
		return
	var w: int = int(blocked.get(i, 0)) + 1
	blocked[i] = w
	if w >= 3:
		# somebody is standing in the way: step round them, then find the way again
		var side: int = (i + s.tick) & 3
		for t in 4:
			var q: int = c
			match (t + side) & 3:
				0: q = c - 1
				1: q = c + 1
				2: q = c - size
				_: q = c + size
			if q >= 0 and q < s.walk.size() and s.walk[q] == 1 and s.at[q] == -1 and q != (r[k - 1] if k > 0 else -1):
				s.at[c] = -1
				s.at[q] = i
				s.pos[i] = q
				break
		routes.erase(i)
		rpos.erase(i)
		blocked[i] = 0

## no way through (a locked-in room, a cell off the map): the trip simply takes its time and the person is there at the end
func _skip(i: int) -> void:
	routes.erase(i)
	rpos.erase(i)
	if s.near[i] == 1:
		demoting.append(i)                                  # handled once the sim has finished walking its near list
	else:
		s.arrive[i] = maxi(lt1[i], s.tick + 1)
		s._bucket(s.arrive[i], i)

## a near agent has gone out of range in the middle of a leg: the leg's clock is re-based from where it stands
func on_demote(i: int) -> void:
	routes.erase(i)
	rpos.erase(i)
	blocked.erase(i)
	lo[i] = s.pos[i]
	lt0[i] = s.tick
	lt1[i] = s.tick + walk_ticks(s.pos[i], s.dest[i])
	s.arrive[i] = lt1[i]
	s._bucket(lt1[i], i)

func forget(i: int) -> void:
	leg[i] = 0
	routes.erase(i)
	rpos.erase(i)
	blocked.erase(i)

# ------------------------------------------------------------------ the day
## called every tick by the sim
func step() -> void:
	budget = ROUTES_PER_TICK
	if dep_b.is_empty():
		return
	var t: int = s.tick
	if not started:
		started = true
		_settle_all()
	if t % CLK.MIN != 0:
		return
	var day: int = t / CLK.DAY
	var tod: int = t % CLK.DAY
	var m: int = tod / CLK.MIN
	for i in dep_b[m]:
		if leg[i] == 0 and dayw[i] != day and s.goal[i] == s.HOME and s.ctl[i] == 0:
			dayw[i] = day
			start(i, s.WORK)
	for i in ret_b[m]:
		if leg[i] == 0 and dayh[i] != day and s.goal[i] != s.HOME and s.ctl[i] == 0:
			dayh[i] = day
			start(i, s.HOME)
	# anyone who missed their minute (busy fleeing, put down somewhere, a game just loaded) goes when they can
	var sweep: int = s.n / 30 + 1
	var from: int = ((t / CLK.MIN) % 30) * sweep
	for i in range(from, mini(from + sweep, s.n)):
		if wc[i] < 0 or leg[i] != 0 or s.ctl[i] == 1 or s.sticky[i] == 1 or s.alive[i] == 0:
			continue
		if tod >= cdep[i] and tod < cret[i] and dayw[i] != day and s.goal[i] == s.HOME:
			dayw[i] = day
			start(i, s.WORK)
		elif tod >= cret[i] and dayh[i] != day and s.goal[i] == s.WORK:
			dayh[i] = day
			start(i, s.HOME)

## everyone is where the hour says they should be (at the first tick, and after a game is loaded)
func _settle_all() -> void:
	var t: int = s.tick
	var day: int = t / CLK.DAY
	var tod: int = t % CLK.DAY
	for i in s.n:
		if wc[i] < 0 or s.alive[i] == 0 or s.sticky[i] == 1 or leg[i] != 0:
			continue
		if s.near[i] == 1 or s.arrive[i] >= 0:
			continue
		var at_work: bool = tod >= cdep[i] + 45 * CLK.MIN and tod < cret[i]
		var cur: int = s.goal[i]
		if at_work and cur == s.HOME:
			s.goal[i] = s.WORK
			s.pos[i] = wc[i]
			s.dest[i] = wc[i]
			dayw[i] = day
		elif not at_work and cur == s.WORK:
			s.goal[i] = s.HOME
			s.pos[i] = s.home_cell[i]
			s.dest[i] = s.home_cell[i]
			if tod >= cret[i]:
				dayh[i] = day
		elif tod >= cdep[i] and tod < cdep[i] + 45 * CLK.MIN and cur == s.HOME and dayw[i] != day:
			dayw[i] = day
			start(i, s.WORK)

# ------------------------------------------------------------------ saving
func to_dict() -> Dictionary:
	return {"leg": Array(leg), "wc": Array(wc), "mode": Array(mode), "cdep": Array(cdep), "cret": Array(cret), "dayw": Array(dayw), "dayh": Array(dayh),
		"tp": Array(tp), "td": Array(td), "te": Array(te), "lo": Array(lo), "lt0": Array(lt0), "lt1": Array(lt1), "rtk": Array(rtk), "started": started}

func from_dict(d: Dictionary, tk: int = 1) -> void:
	var n: int = mini(s.n, d["leg"].size())
	for i in n:
		leg[i] = int(d["leg"][i])
		wc[i] = int(d["wc"][i])
		mode[i] = int(d["mode"][i])
		cdep[i] = int(d["cdep"][i])
		cret[i] = int(d["cret"][i])
		dayw[i] = int(d["dayw"][i])
		dayh[i] = int(d["dayh"][i])
		tp[i] = int(d["tp"][i])
		td[i] = int(d["td"][i])
		te[i] = int(d["te"][i])
		lo[i] = int(d["lo"][i])
		lt0[i] = int(d["lt0"][i]) * tk
		lt1[i] = int(d["lt1"][i]) * tk
		rtk[i] = int(d["rtk"][i])
	started = bool(d.get("started", true))
	routes.clear()
	rpos.clear()
	blocked.clear()
	index()
