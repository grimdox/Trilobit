extends SceneTree
## Temp Agency: the five jobs, the white/blue-collar floors, the stations, the checks, the board at an agency's terminal and a whole job played through.
## Run: TRL_STREET=1 godot --headless -s tests/run_tempagency.gd
const TJ = preload("res://src/temp_jobs.gd")
const MS = preload("res://src/missions.gd")
const SITE = preload("res://src/mission_site.gd")
const CG = preload("res://src/citygen.gd")
const BZ = preload("res://src/business.gd")
const WorldScript = preload("res://src/world.gd")
const GameScript = preload("res://src/game.gd")
var ok := 0
var n := 0
func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _reach(c, from: int) -> Dictionary:
	var S: int = c.size
	var seen := {from: true}
	var q: Array = [from]
	var qi := 0
	while qi < q.size():
		var cur: int = q[qi]
		qi += 1
		for d in [1, -1, S, -S]:
			var nx: int = cur + d
			if nx < 0 or nx >= S * S or seen.has(nx):
				continue
			var t: int = c.tiles[nx]
			if t == CG.TID["mission_device"] or t == CG.TID["portal"] or CG.WALK[t] == 1:
				seen[nx] = true
				if CG.WALK[t] == 1:
					q.append(nx)
	return seen

func _initialize() -> void:
	var offs: Array = TJ.offers(77, 1234, 3)
	check("a board of five jobs", offs.size() == 5 and TJ.JOBS.size() == 5)
	check("same arguments, same board", str(TJ.offers(77, 1234, 3)) == str(offs))
	check("another day, another board", str(TJ.offers(77, 1234, 4)) != str(offs))
	var all_ok := true
	var collars := {}
	for o in offs:
		var sp: Array = TJ.skill_split(TJ.job_of(o))
		if sp[0].size() < 1 or sp[0].size() > 2 or sp[1].size() < 1 or sp[1].size() > 2:
			all_ok = false
		if int(o["hostiles"]) != 0 or int(o["reward"]) <= 0 or String(o["kind"]) != "temp":
			all_ok = false
		collars[o["collar"]] = true
	check("each job uses one or two social and one or two labour skills, and no fighting", all_ok)
	check("both collars appear", collars.has("white") and collars.has("blue"))
	# the sites
	var site_ok := true
	var floors_ok := true
	var conn_ok := true
	var civ_ok := true
	for sd in [1, 2, 3]:
		for o in TJ.offers(sd, 99, sd):
			var c = SITE.build(o)
			var site: Dictionary = c.get_meta("site")
			var st: Array = site["stations"]
			if st.size() != 3:
				site_ok = false
			var reach: Dictionary = _reach(c, int(site["entry"]))
			var S: int = c.size
			for s in st:
				if c.tiles[int(s[0])] != CG.TID["mission_device"]:
					site_ok = false
				var near := false
				for d in [1, -1, S, -S]:
					if reach.has(int(s[0]) + d):
						near = true
				if not near:
					conn_ok = false
			if not reach.has(int(site["exit"])) and not reach.has(int(site["exit"]) - S):
				conn_ok = false
			var want: Array = ["floor_carpet_grey", "floor_tile"] if o["collar"] == "white" else ["floor_concrete", "floor_rubber"]
			var seen_ok := false
			for k in c.size * c.size:
				var t: int = c.tiles[k]
				if t == CG.TID[want[0]] or t == CG.TID[want[1]]:
					seen_ok = true
				if t == CG.TID["floor_steel"]:
					floors_ok = false
			if not seen_ok:
				floors_ok = false
			for a in site["agents"]:
				if a["role"] != "coworker" or int(a["fac"]) != 0:
					civ_ok = false
	check("every site has three stations on device tiles", site_ok)
	check("every station and the exit can be reached from the entry", conn_ok)
	check("white collar floors are carpet and tile, blue collar concrete and rubber", floors_ok)
	check("only harmless coworkers on a temp site", civ_ok)
	var furn_ok := true
	for o in TJ.offers(4, 5, 6):
		var c2 = SITE.build(o)
		var cnt := 0
		for k in c2.size * c2.size:
			var t: int = c2.tiles[k]
			if t >= CG.EXTRA0 and not CG.is_floor(t) and t != CG.TID["mission_device"] and t != CG.TID["portal"] and t != CG.TID["door_closed"]:
				cnt += 1
		if cnt < 6:
			furn_ok = false
	check("every temp floor is furnished", furn_ok)
	# the check rule
	check("a natural 2 always fails", not bool(TJ.check(2, [10, 10], 5)[0]))
	check("a natural 19 always works", bool(TJ.check(19, [0], 99)[0]))
	check("skills add: best in full, the other by half", int(TJ.check(10, [4, 2], 0)[1]) == 15)
	check("higher skill, higher chance", TJ.chance([6], 12) > TJ.chance([0], 12))
	check("pay falls 10% a slip, never under half", TJ.pay({"offer": {"reward": 200}, "fails": 2}) == 160 and TJ.pay({"offer": {"reward": 200}, "fails": 9}) == 100)
	# the agency on a real map
	var gen := CG.new()
	var city = null
	for sd in [21, 22, 23]:
		var w = WorldScript.new()
		w.start(sd, 300)
		for b in w.game.city.businesses:
			if b["type"] == "temp_agency":
				city = w.game
				break
		if city != null:
			break
	check("a temp agency spawns on a generated map", city != null)
	if city != null:
		var nag := 0
		for b in city.city.businesses:
			if b["type"] == "temp_agency":
				nag += 1
		print("  temp agencies in the city: %d" % nag)
		check("a city has at least 20 temp agencies", nag >= 20)
		var term := -1
		for b in city.city.businesses:
			if b["type"] != "temp_agency":
				continue
			for y in range(int(b["y0"]), int(b["y1"]) + 1):
				for x in range(int(b["x0"]), int(b["x1"]) + 1):
					if city.city.tiles[y * city.size + x] == CG.TID["terminal"]:
						term = y * city.size + x
		check("the agency has a mission terminal", term >= 0)
		if term >= 0:
			var bd: Dictionary = city.board_open(term)
			check("its board posts temp jobs", city.is_temp_terminal(term) and String(bd["offers"][0]["kind"]) == "temp")
	# a whole job
	var o2: Dictionary = TJ.offers(5, 7, 1)[0]
	var ng = GameScript.new(int(o2["seed"]))
	ng.setup(0, null, Vector2i(-1, -1), MS.new_state(o2))
	var site2: Dictionary = ng.city.get_meta("site")
	check("a site game has the job", ng.mission["offer"]["kind"] == "temp" and site2["stations"].size() == 3)
	var tries := 0
	while not bool(ng.mission["done"]) and tries < 300:
		for s in site2["stations"]:
			if not (ng.mission.get("st_done", {}) as Dictionary).has(str(int(s[0]))):
				TJ.use_station(ng, int(s[0]))
		tries += 1
	check("the stations can all be finished", bool(ng.mission["done"]))
	var res: Dictionary = MS.outcome(ng)
	check("finishing pays, less any slips", res["outcome"] == "success" and int(res["reward"]) > 0 and int(res["reward"]) <= int(o2["reward"]))
	check("status text counts the tasks", MS.status_text(ng).find("3/3") >= 0)
	print("TEMPAGENCY %d/%d" % [ok, n])
	if ok != n:
		print("  >> tempagency FAILED")
	quit(0 if ok == n else 1)
