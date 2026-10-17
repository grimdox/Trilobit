extends RefCounted
## The revamped city: a big organic outline, a river from the mountains to the south coast, three four-lane bridges, a six-lane highway from the
## harbor out to the east coast, a rail bridge to the downtown, and the three districts.  Returns [passed, total, log]
const World = preload("res://src/world.gd")
const TR = preload("res://src/transit.gd")
const CG = preload("res://src/citygen.gd")
const ISL = preload("res://src/island.gd")
const VS = preload("res://src/vehicles.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var w = World.new()
	w.start(7, 300)
	var g = w.game
	var isl = g.island
	var c = g.city
	var n: int = g.size
	var o: Vector2i = ISL.zone_origin(1, 1)
	var plan: Dictionary = c.plan
	var mask: PackedByteArray = plan["mask"]

	# ---- the size and the outline
	var paved := 0
	var inside := 0
	var minx := n
	var maxx := 0
	var miny := n
	var maxy := 0
	for y in n:
		for x in n:
			if mask[y * n + x] == 1:
				inside += 1
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
				var t: int = c.tiles[y * n + x]
				if t != CG.PARK and t != CG.WATER and t != CG.SAND and t != CG.TREE:
					paved += 1
	var old_paved: int = (512 - 2 * 72) * (512 - 2 * 72)       # the previous city: a 368 x 368 square
	check.call("the city is larger than the old one: %d built tiles against %d (x%.2f)" % [paved, old_paved, float(paved) / float(old_paved)], paved >= int(old_paved * 1.35))
	var fill: float = float(inside) / float((maxx - minx + 1) * (maxy - miny + 1))
	var edge_lo := n
	var edge_hi := 0
	for y in range(miny + 30, maxy - 30, 6):
		for x in n:
			if mask[y * n + x] == 1:
				edge_lo = mini(edge_lo, x)
				edge_hi = maxi(edge_hi, x)
				break
	check.call("the outline is not a square: it fills %.0f%% of its bounding box and its edge wanders" % (fill * 100.0), fill < 0.9 and edge_lo < 140 and edge_hi < n)
	var edge_rows := []
	for y in range(miny + 40, maxy - 40, 8):
		for x in n:
			if mask[y * n + x] == 1:
				edge_rows.append(x)
				break
	var wander: int = edge_rows.max() - edge_rows.min()
	check.call("the west edge of town moves by %d tiles from row to row" % wander, wander >= 30)

	# ---- the river
	var okc := true
	for y in range(ISL.RIVER_Y0 + 3, ISL.H - 2, 9):
		var cx := int(isl._rv_x[y])
		var t2: int = isl.terrain(cx, y)
		if t2 != CG.WATER and t2 != CG.ROAD:
			okc = false
	check.call("the river is one unbroken channel from the foothills to the south edge", okc)
	var ys0: int = ISL.RIVER_Y0 + 8
	var xs0 := int(isl._rv_x[ys0])
	check.call("it rises inside the mountain range (x %d, the range is %d-%d)" % [xs0, int(isl.mtn_west(ys0)), int(isl.mtn_east(ys0))], float(xs0) > isl.mtn_west(ys0) and float(xs0) < isl.mtn_east(ys0) + 20.0 and isl.terrain(xs0 - 14, ys0) == CG.MOUNTAIN)
	var mouth_y := -1
	for y in range(1000, ISL.H):
		if float(y) >= isl.south_y(int(isl._rv_x[y])):
			mouth_y = y
			break
	check.call("it reaches the sea on the south coast (mouth at row %d)" % mouth_y, mouth_y > 1150 and mouth_y < 1380 and isl.terrain(int(isl._rv_x[ISL.H - 20]), ISL.H - 20) == CG.WATER)
	var wet := 0
	for i in n * n:
		if c.tiles[i] == CG.WATER:
			wet += 1
	check.call("it runs through the city (%d tiles of water in the city map)" % wet, wet > 6000)
	var widths := []
	for y in [ISL.RIVER_Y0 + 10, 500, 700, 900, 1100, 1300]:
		var sp: Vector2i = isl.river_span(y)
		widths.append(sp.y - sp.x + 1)
	check.call("and it widens on its way down (%s)" % str(widths), widths[0] < widths[2] and widths[2] <= widths[5] and widths[5] >= 50)

	# ---- the bridges: three four-lane (24-wide) roads over the river
	var bridges_ok := 0
	var bridge_rail := 0
	var marks_ok := 0
	for e in isl.bridges_y:
		var sp2: Vector2i = isl.river_span(o.y + e + 12)
		var sx: int = (sp2.x + sp2.y) / 2 - o.x
		var run_up := 0
		while c.tiles[(e + 12 - run_up) * n + sx] == CG.ROAD:
			run_up += 1
		var run_dn := 0
		while c.tiles[(e + 12 + run_dn) * n + sx] == CG.ROAD:
			run_dn += 1
		var deck_full := true
		for x in range(sp2.x - o.x, sp2.y - o.x + 1):
			if c.tiles[(e + 5) * n + x] != CG.ROAD or c.tiles[(e + 18) * n + x] != CG.ROAD:
				deck_full = false
		if run_up + run_dn - 1 == ISL.AVENUE_W and deck_full:
			bridges_ok += 1
		if c.tiles[(e - 1) * n + sx] == CG.RAILING and c.tiles[(e + ISL.AVENUE_W) * n + sx] == CG.RAILING:
			bridge_rail += 1
		var dashed := false
		for x in range(sp2.x - o.x, sp2.y - o.x + 1):
			if c.marks[(e + 6) * n + x] == CG.M_DASH_H and c.marks[(e + 18) * n + x - x % 6] != CG.M_YELLOW_H:
				dashed = true
		if dashed and c.marks[(e + 11) * n + sx - 1] != CG.M_WHITE_H:
			marks_ok += 1
	check.call("three bridges, each a four-lane road 24 tiles wide that spans the whole river (%d of 3)" % bridges_ok, bridges_ok == 3)
	check.call("each bridge has a railing down both sides (%d of 3)" % bridge_rail, bridge_rail == 3)
	check.call("the bridges are painted as four-lane roads (dashed lane lines: %d of 3)" % marks_ok, marks_ok == 3)
	# the highway bridge and the rail bridge are separate crossings beside them
	var trunk: int = plan["trunk"]
	var hsp: Vector2i = isl.river_span(o.y + trunk + 18)
	var hx: int = (hsp.x + hsp.y) / 2 - o.x
	var hrun := 0
	while c.tiles[(trunk + hrun) * n + hx] == CG.ROAD:
		hrun += 1
	check.call("the highway crosses on its own six-lane bridge (%d tiles wide) railed on both sides" % hrun, hrun == 36 and c.tiles[(trunk - 1) * n + hx] == CG.RAILING and c.tiles[(trunk + 36) * n + hx] == CG.RAILING)

	# ---- the highway: harbor to the east coast, six lanes wide, walkable end to end
	var wide_ok := true
	var rows_checked := 0
	for x in range(isl._hx0 + 4, ISL.HWY_X1, 7):
		var hy: int = isl.pass_yc(x)
		var nn: int = isl.hwy_n(x)
		var ss: int = isl.hwy_s(x)
		var width := 0
		for dy in range(-30, 30):
			if isl.terrain(x, hy + dy) in [CG.ROAD, CG.RAILING] and absi(isl.terrain(x, hy + dy) - CG.ROAD) < 100:
				if isl.terrain(x, hy + dy) == CG.ROAD:
					width += 1
		rows_checked += 1
		var expect: int = nn + ss + 1
		if x < ISL.PASS_X0 - 18 or x >= ISL.PASS_X1 + 12:
			expect = 36
		if width != expect:
			wide_ok = false
	check.call("the highway is 36 tiles (six lanes) wide the whole way except the pass (%d columns checked)" % rows_checked, wide_ok)
	var seen := {}
	var q := [Vector2i(isl._hx0 + 2, ISL.HWY_Y)]
	seen[q[0]] = true
	var head := 0
	var reached_east := false
	while head < q.size() and not reached_east:
		var cur: Vector2i = q[head]
		head += 1
		if cur.x >= ISL.HWY_X1 - 2:
			reached_east = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + d
			if absi(nx.y - ISL.HWY_Y) > 24 or nx.x < isl._hx0 or seen.has(nx):
				continue
			if CG.WALK[isl.terrain(nx.x, nx.y)] == 1:
				seen[nx] = true
				q.append(nx)
	check.call("you can walk from the harbor all the way east along the highway (over both bridges)", reached_east)
	var cliff_gap: int = int(isl.east_x(ISL.HWY_Y)) - ISL.HWY_X1
	check.call("it ends at the coast (%d tiles from the clifftop)" % cliff_gap, cliff_gap >= 0 and cliff_gap <= 30 and isl.terrain(ISL.HWY_X1, ISL.HWY_Y) == CG.ROAD)
	var hz = w._make(Vector2i(0, 1))
	var quay_ok := false
	var qx: int = int(isl.west_x(ISL.PORT.y)) + 6 + 3
	quay_ok = hz.city.tiles[(ISL.HWY_Y - 448) * hz.size + qx] == CG.ROAD and hz.city.tiles[(ISL.HWY_Y - 448 - 17) * hz.size + qx + 40] == CG.ROAD and hz.city.tiles[(ISL.HWY_Y - 448 + 17) * hz.size + qx + 40] == CG.ROAD
	check.call("in the harbor the six-lane highway starts at the quay road", quay_ok and hz.city.ys_w.values().has(36))
	# the highway through the city, edge to edge
	var tr_seen := {}
	var tq := [(trunk + 3) * n]
	tr_seen[tq[0]] = true
	var th := 0
	var cross := false
	while th < tq.size():
		var cur2: int = tq[th]
		th += 1
		if cur2 % n >= n - 2:
			cross = true
			break
		for d2 in [1, -1, n, -n]:
			var nb: int = cur2 + d2
			if nb < 0 or nb >= n * n or tr_seen.has(nb) or absi(nb / n - (trunk + 18)) > 22:
				continue
			if g.sim.walk[nb] == 1 or c.tiles[nb] == CG.ROAD:
				tr_seen[nb] = true
				tq.append(nb)
	check.call("the highway crosses the whole city map west to east", cross)

	# ---- districts: towers downtown, mid-rise round them, suburbs beyond; rich in the middle, poor at the edges
	var dt: Vector2 = plan["centre"]
	var rad: float = plan["rad"]
	var tall := []
	var mid := []
	var tallest_d := 9999.0
	var tallest_h := 0
	for ti in c.tower_info:
		var cxt: float = (float(ti["x0"]) + float(ti["x1"])) * 0.5
		var cyt: float = (float(ti["y0"]) + float(ti["y1"])) * 0.5
		var d: float = Vector2(cxt, cyt).distance_to(dt)
		if int(ti["h"]) > tallest_h:
			tallest_h = int(ti["h"])
			tallest_d = d
		if int(ti["h"]) >= 9:
			tall.append(d)
		elif int(ti["h"]) >= 3:
			mid.append(d)
	var mean_tall := 0.0
	for d in tall:
		mean_tall += d
	mean_tall /= maxf(1.0, float(tall.size()))
	var mean_mid := 0.0
	for d in mid:
		mean_mid += d
	mean_mid /= maxf(1.0, float(mid.size()))
	check.call("downtown: %d large towers of 9+ floors (tallest %d floors, %.0f tiles from the heart), averaging %.0f tiles out" % [tall.size(), tallest_h, tallest_d, mean_tall], tall.size() >= 3 and tallest_h >= 18 and tallest_d < 0.3 * rad)
	check.call("mid-rise round it: %d buildings of 3-8 floors, farther out on average (%.0f against %.0f)" % [mid.size(), mean_mid, mean_tall], mid.size() >= 6 and mean_mid > mean_tall)
	var far_homes := 0
	var near_homes := 0
	for hm in c.homes_g:
		var hd: float = Vector2(float(hm % n), float(hm / n)).distance_to(dt)
		if hd > 0.62 * rad:
			far_homes += 1
		elif hd < 0.25 * rad:
			near_homes += 1
	check.call("suburbs and exurbs lie beyond the mid-rise (%d house sites there, %d in the heart)" % [far_homes, near_homes], far_homes >= 300 and far_homes > near_homes)
	var sum := [0.0, 0.0, 0.0]
	var cnt := [0, 0, 0]
	for i in n * n:
		if mask[i] == 1:
			var wl: int = c.wealth[i]
			cnt[wl] += 1
			sum[wl] += Vector2(float(i % n), float(i / n)).distance_to(dt)
	var md0: float = sum[0] / maxf(1.0, float(cnt[0]))
	var md2: float = sum[2] / maxf(1.0, float(cnt[2]))
	check.call("the rich part of town is nearer the heart than the poor part (%.0f against %.0f tiles); all three tiers are present" % [md2, md0], md2 < md0 and cnt[0] > 8000 and cnt[1] > 8000 and cnt[2] > 8000)
	var ring: Rect2i = plan["ring"]
	check.call("the downtown lies east of the river, the river's corridor is x %d-%d" % [plan["river"].x, plan["river"].y], dt.x > float(plan["river"].y) + 80.0 and ring.position.x > int(plan["river"].y) + 60)

	# ---- the rail: a bridge over the river to the downtown, with stops
	var t = g.transit
	var rb: Dictionary = plan["rail"]
	var surf := 0
	var over_water := 0
	var track_ok := true
	for i in t.path.size():
		var v: Vector3i = TR.unpack(t.path[i])
		if v.z == 0 and v.x >= o.x and v.x < o.x + n and v.y >= o.y and v.y < o.y + n:
			var lx: int = v.x - o.x
			var ly: int = v.y - o.y
			if lx >= int(rb["xw"]) and lx <= int(rb["xe"]):
				surf += 1
				if isl.river_tile(v.x, v.y) == 1:
					over_water += 1
				if c.tiles[ly * n + lx] != CG.TRACK:
					track_ok = false
	check.call("the line comes up into the daylight and crosses the river: %d cells on the surface, %d of them over open water, all laid as track" % [surf, over_water], surf >= 2 * (int(rb["xe"]) - int(rb["xw"])) and over_water >= 40 and track_ok)
	var rail_walls := 0
	var sx0: int = int(rb["xw"]) + 30
	for x in range(int(rb["xw"]), int(rb["xe"]) + 1):
		if isl.river_tile(o.x + x, o.y + int(rb["y_ret"]) - 2) == 1 and c.tiles[(int(rb["y_ret"]) - 2) * n + x] == CG.RAILING:
			rail_walls += 1
	check.call("the rail bridge has a railing along its north side (%d tiles)" % rail_walls, rail_walls >= 30)
	var east_stops := 0
	var ring_cells: PackedInt32Array = c.subway["ring"]
	for si in c.subway["stops"]:
		if ring_cells[int(si)] % n > int(plan["river"].y):
			east_stops += 1
	check.call("at least three stops in the downtown on the east bank, plus the Harbor Terminal (%d + 1)" % east_stops, east_stops >= 3 and t.stop_names.has("Harbor Terminal") and t.stop_heads.size() >= 4)
	# a train really stands on the bridge
	var on_bridge := false
	var guard := 0
	while not on_bridge and guard < t.period:
		t.clock += 1
		guard += 1
		var occ: Dictionary = t.occupancy()
		for cc in occ:
			if int(cc) < g.s2 and c.tiles[int(cc)] == CG.TRACK and isl.river_tile(o.x + int(cc) % n, o.y + int(cc) / n) == 1:
				on_bridge = true
				break
	check.call("a train runs over the river (seen after %d turns)" % guard, on_bridge)
	# ride it: board at a downtown stop and stay on until the carriage is over the water
	var si_gate: int = t.stop_names.find("Kuroda Plaza")
	guard = 0
	while t.turns_to(si_gate) > 0 and guard < 3000:
		t.clock += 1
		guard += 1
	var occ2: Dictionary = t.occupancy()
	var door_cell := -1
	var plat := -1
	for cc in occ2:
		var inf: Array = TR.occ_unpack(int(occ2[cc]))
		if t.dwell_of(int(inf[0])) > 0 and t.stop_of(int(inf[0])) == si_gate and int(inf[2]) == TR.DOOR_A and (int(inf[3]) == 0 or int(inf[3]) == 3):
			for nb in [int(cc) - 1, int(cc) + 1, int(cc) - n, int(cc) + n]:
				if c.tiles[nb] == CG.PLATFORM and not occ2.has(nb) and door_cell < 0:
					door_cell = int(cc)
					plat = nb
	var boarded := false
	if door_cell >= 0:
		g.pc = plat
		g.sim.retier(g.pc)
		g.act_move((door_cell % n) - (plat % n), ((door_cell / n) % n) - ((plat / n) % n))
		boarded = t.riding >= 0
	check.call("the player boards a train at a downtown stop", boarded)
	var over_river := false
	var turns := 0
	while boarded and turns < t.period + 40 and w.game == g and g.hp > 0:
		g.act_wait()
		turns += 1
		var gp: Vector2i = g.global_pos()
		if g.pc < g.s2 and isl.river_tile(gp.x, gp.y) == 1:
			over_river = true
			break
	check.call("riding carries the player across the river on the rail bridge (%d turns)" % turns, over_river)

	# ---- traffic: a car drives over a four-lane bridge
	var e2: int = isl.bridges_y[1]
	var sp3: Vector2i = isl.river_span(o.y + e2 + 12)
	for vi in g.vehicles.size():
		g.vs.lift(vi)
	g.vehicles.clear()
	g.veh_at.fill(-1)
	g.in_vehicle = -1
	var start_x: int = sp3.x - o.x - 20
	var cars := []
	for k in 6:
		var kk: int = [2, 3, 2, 3, 2, 3][k]
		var sxk: int = start_x - 16 * (k / 2)
		var anchor: int = g.vs.anchor_for("car", 1, 2 * sxk, VS.lane_k2(e2, kk), 0)
		var vk: int = g.vs.spawn("car", anchor, 1, Color.RED, true)
		if vk >= 0:
			cars.append(vk)
	check.call("six cars stand in the east-bound lanes of a bridge avenue (%d placed)" % cars.size(), cars.size() >= 4)
	var crossed := 0
	var off_road := false
	var x0s := {}
	for vk in cars:
		x0s[vk] = g.vehicles[vk]["cell"] % n
	g.pc = (e2 + 12) * n + start_x
	g.sim.retier(g.pc)
	var reached := {}
	for k in 140:
		g.vs.ai_turn()
		for vk in cars:
			var cell: int = g.vehicles[vk]["cell"]
			for cc2 in g.vs.cells(g.vehicles[vk]):
				if c.tiles[cc2] != CG.ROAD:
					off_road = true
			if cell % n > sp3.y - o.x and absi(cell / n - (e2 + 12)) < 12:
				reached[vk] = true
		g.pc = g.vehicles[cars[0]]["cell"] - 8 if g.vehicles[cars[0]]["cell"] % n > 12 else g.pc
		g.sim.retier(g.pc)
	crossed = reached.size()
	check.call("%d of them drive across the river (it is x %d-%d) and none leaves the road" % [crossed, sp3.x - o.x, sp3.y - o.x], crossed >= 1 and not off_road)

	# ---- save and load: the same city comes back
	var d: Dictionary = JSON.parse_string(JSON.stringify(w.save_dict()))
	var w2 = World.new()
	w2.load_dict(d)
	var g2 = w2.game
	check.call("save and load bring back the same city (plan, roads, river, line, player)", g2.zone == g.zone and g2.size == n and g2.city.xs == c.xs and g2.city.ys == c.ys and g2.city.ys_w == c.ys_w and g2.city.tiles.slice(0, n * n) == c.tiles.slice(0, n * n) and g2.transit.path == t.path and g2.pc == g.pc)
	# an old save (made before the revamp, so without a layout stamp) does not crash the load: it starts afresh on the same island
	var old: Dictionary = d.duplicate(true)
	old.erase("layout")
	var w3 = World.new()
	w3.load_dict(old)
	check.call("a save from before the revamp starts a fresh city on the same island with a notice (layout %d now)" % ISL.LAYOUT_VER, w3.game.zone == ISL.CITY_ZONE and w3.game.size == ISL.CZS and w3.seed_value == w.seed_value and w3.game.log.any(func(l): return String(l).contains("before the city was rebuilt")))
	return [st[0], st[1], log]
