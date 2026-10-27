extends RefCounted
## People, homes, jobs and the daily commute: houses hold one to four people, flats up to three, the gangs stay out of the flats and out of
## the shops and offices, the shops and offices are worked by ordinary people (the keeper of a shop that trades is a merchant), the player starts
## in a flat, and everyone with a job goes to work in the morning and home in the evening (on foot along a real route, or by subway or car).
## Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const CG = preload("res://src/citygen.gd")
const CLK = preload("res://src/clock.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	GameScript.street_start = false                       # (the other tests begin on a road; this one checks the flat)
	var g = GameScript.new(5)
	g.setup(700)
	var sim = g.sim
	var com = sim.com
	var s2: int = g.s2
	var n: int = sim.n
	# ---- homes
	var in_house := {}
	var in_flat := {}
	for i in n:
		var h: int = sim.home_cell[i]
		for hs in g.city.houses:
			if h % s2 >= 0 and h < s2 and h % g.size >= hs["x0"] and h % g.size <= hs["x1"] and h / g.size >= hs["y0"] and h / g.size <= hs["y1"]:
				in_house[hs["cell"]] = int(in_house.get(hs["cell"], 0)) + 1
				break
	var most := 0
	for k in in_house:
		most = maxi(most, int(in_house[k]))
	check.call("houses hold between one and four people each (the fullest holds %d, %d houses lived in)" % [most, in_house.size()], most <= 4 and most >= 2 and in_house.size() >= 20)
	var gang_up := 0
	var flats_used := 0
	for i in n:
		if int(sim.home_cell[i]) >= s2 and int(sim.home_cell[i]) < (g.city.zmax + 1) * s2:
			flats_used += 1
			if g.fac[i] != g.CIV:
				gang_up += 1
	check.call("people live in the flats of the towers (%d) and no gang member is one of them (%d)" % [flats_used, gang_up], flats_used > 100 and gang_up == 0)
	var per_flat := {}
	for a in g.city.apartments:
		var r: Rect2i = a["rect"]
		var base: int = (int(a["cell"]) / s2) * s2
		for i in n:
			var h: int = sim.home_cell[i]
			if h >= s2 and h / s2 == base / s2 and Rect2i(r.position, r.size).has_point(Vector2i(h % g.size, (h % s2) / g.size)):
				per_flat[a["cell"]] = int(per_flat.get(a["cell"], 0)) + 1
	var worst := 0
	for k in per_flat:
		worst = maxi(worst, int(per_flat[k]))
	check.call("a flat holds at most three people (the fullest holds %d)" % worst, worst <= 3 and per_flat.size() > 20)
	# ---- jobs
	var staff_cells := {}
	var vendors := 0
	var keepers_ok := true
	for b in g.city.businesses:
		if b.get("legacy", false):
			continue
		for k in b["staff"].size():
			staff_cells[int(b["staff"][k])] = true
	var gang_in_new := 0
	var civ_in_new := 0
	for i in n:
		if com.wc[i] >= 0 and staff_cells.has(int(com.wc[i])):
			if g.fac[i] == g.CIV:
				civ_in_new += 1
			else:
				gang_in_new += 1
	check.call("the new shops and offices are worked by ordinary people (%d of %d places), never the gangs (%d)" % [civ_in_new, staff_cells.size(), gang_in_new], civ_in_new >= staff_cells.size() * 9 / 10 and civ_in_new > 50 and gang_in_new == 0)
	var desk := {}
	for c in g.city.works_t:
		desk[int(c)] = true
	var desk_civ := 0
	var desk_gang := 0
	for i in n:
		if desk.has(int(com.wc[i])):
			if g.fac[i] == g.CIV:
				desk_civ += 1
			else:
				desk_gang += 1
	check.call("the office desks and gym spots are worked by ordinary people (%d), never the gangs (%d)" % [desk_civ, desk_gang], desk_civ > 100 and desk_gang == 0)
	for b in g.city.businesses:
		if b.get("legacy", false) or b["role"] != "vendor" or int(b["keeper"]) < 0:
			continue
		var found := false
		for i in n:
			if com.wc[i] == int(b["keeper"]) and g.eco.role[i] == g.eco.VENDOR:
				found = true
				break
		if found:
			vendors += 1
		else:
			keepers_ok = false
	check.call("the keeper of every shop that trades is a merchant (%d)" % vendors, vendors >= 8 and keepers_ok)
	var jobless := 0
	for i in n:
		if sim.sticky[i] == 0 and com.wc[i] < 0:
			jobless += 1
	check.call("everyone who is not posted has somewhere to work (%d without)" % jobless, jobless == 0)
	# ---- the player starts in a flat
	var in_apartment := false
	for a in g.city.apartments:
		var r2: Rect2i = a["rect"]
		if g.pc / s2 == int(a["cell"]) / s2 and r2.has_point(Vector2i(g.pc % g.size, (g.pc % s2) / g.size)):
			in_apartment = true
	check.call("the player starts inside a flat of an apartment building", in_apartment)
	# ---- a day: the player is shut away so everyone is far and abstract
	var p0: int = g.pc
	for t in 3200:                                        # 06:40 -> 12:00
		sim.step(p0)
	var at_work := 0
	var away := 0
	var counted := 0
	for i in n:
		if sim.sticky[i] == 1 or com.wc[i] < 0 or sim.alive[i] == 0:
			continue
		counted += 1
		if com.leg[i] != 0:
			away += 1
		elif sim.pos[i] == com.wc[i] or (sim.near[i] == 1 and g.cheb(sim.pos[i], com.wc[i]) <= 4):
			at_work += 1
	check.call("by mid-day nearly everyone is at work (%d of %d, %d still on the way)" % [at_work, counted, away], at_work + away >= counted * 95 / 100 and at_work >= counted * 80 / 100)
	for t in 6000:                                        # 12:00 -> 22:00
		sim.step(p0)
	var home := 0
	var elsewhere := 0
	for i in n:
		if sim.sticky[i] == 1 or com.wc[i] < 0 or sim.alive[i] == 0:
			continue
		if sim.pos[i] == sim.home_cell[i] or (sim.near[i] == 1 and g.cheb(sim.pos[i], sim.home_cell[i]) <= 6):
			home += 1
		else:
			elsewhere += 1
	check.call("by ten at night everyone is home (%d of %d)" % [home, counted], home >= counted * 95 / 100)
	check.call("trips were made by foot, subway and car (%d trips begun)" % com.starts, com.starts > counted)
	# ---- one person walks a real route: close to the player, they set off from home and get to the work cell step by step
	var who := -1
	for i in n:
		if sim.sticky[i] == 0 and com.wc[i] >= 0 and sim.home_cell[i] < s2 and com.wc[i] < s2 and g.fac[i] == g.CIV:
			var d: int = com.manh(sim.home_cell[i], com.wc[i])
			if d >= 25 and d <= 60:
				who = i
				break
	var steps_ok := true
	var arrived := false
	var moves := 0
	if who >= 0:
		var day: int = sim.tick / CLK.DAY + 1
		sim.tick = day * CLK.DAY + com.cdep[who] - 30
		for i in n:                                       # everyone home, nobody mid-trip, a clean slate for the new day
			if sim.sticky[i] == 0:
				com.forget(i)
				sim.goal[i] = sim.HOME
				if sim.near[i] == 1:
					sim.at[sim.pos[i]] = -1
					sim._demote(i)
				sim.arrive[i] = -1
				sim.pos[i] = sim.home_cell[i]
				sim.dest[i] = sim.home_cell[i]
		sim.buckets.clear()
		sim.place(who, sim.home_cell[who])
		g.pc = sim.home_cell[who]
		sim.retier(g.pc)
		var last: int = -1
		for t in 900:
			sim.step(g.pc)
			if last < 0:
				if com.leg[who] != 0:
					last = sim.pos[who]                          # the walk begins here (before that, a person at rest just settles in)
				continue
			if sim.pos[who] != last:
				moves += 1
				if g.cheb(sim.pos[who], last) > 1 and sim.pos[who] / s2 == last / s2:
					steps_ok = false
				last = sim.pos[who]
			if sim.pos[who] == com.wc[who] and com.leg[who] == 0:
				arrived = true
				break
	log.append("  (walker %d: steps ok %s, arrived %s, at %d,%d -> work %d,%d, leg %d, tick %d)" % [who, steps_ok, arrived, sim.pos[who] % g.size, sim.pos[who] / g.size, com.wc[who] % g.size, com.wc[who] / g.size, com.leg[who], sim.tick])
	check.call("a person near the player walks to work a step at a time (%d steps) and arrives at their own desk" % moves, who >= 0 and steps_ok and arrived and moves >= 20)
	# ---- the commute survives a save
	var snap: Dictionary = com.to_dict()
	var wc0 := PackedInt32Array(com.wc)
	for i in n:
		com.wc[i] = -1
	com.from_dict(JSON.parse_string(JSON.stringify(snap)))
	check.call("the work cells and clocks come back from a save", com.wc == wc0)
	GameScript.street_start = OS.get_environment("TRL_STREET") != ""
	return [st[0], st[1], log]
