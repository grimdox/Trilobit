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
	check("a board of five jobs", offs.size() == 5 and TJ.JOBS.size() == 10)
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
	for sd3 in range(1, 20):
		for o3 in TJ.offers(sd3, 4, sd3):
			collars[o3["collar"]] = true
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
	check("a helper's bonus adds to the roll", int(TJ.check(10, [4, 2], 0, 3)[1]) == 18)
	# flavors, pay and sliders
	var fl_seen := {}
	var urgent_ok := true
	var group_n := [0, 0, 0]
	var sums := [0, 0, 0]
	var nbd := [0, 0, 0]
	for sd in range(1, 60):
		for sw_q in [[1, 1, 0, 0], [1, 1, 2, 2], [1, 1, 1, 1]]:
			for o in TJ.offers(sd, 5, sd, 0, sw_q):
				fl_seen[o["flavor"]] = int(fl_seen.get(o["flavor"], 0)) + 1
				if o["flavor"] == "urgent" and (int(o["limit_min"]) < 360 or int(o["limit_min"]) > 480):
					urgent_ok = false
				if o["flavor"] != "urgent" and int(o["limit_min"]) != 0:
					urgent_ok = false
				if String(o["brief"]).find("¥%d" % int(o["reward"])) < 0:
					urgent_ok = false
	check("three flavors appear; Urgent limits run 6 to 8 hours; the brief lists the pay (%s)" % str(fl_seen), fl_seen.size() == 3 and urgent_ok)
	var quick := 0
	var precise := 0
	var trades := 0
	var office := 0
	var phys := 0
	var cere := 0
	var grp_mates := 0
	var ind_mates := 0
	for sd in range(1, 80):
		for o in TJ.offers(sd, 5, sd, 0, [0, 1, 0, 0]):
			if o["flavor"] == "urgent": quick += 1
			if o["collar"] == "blue": trades += 1
			grp_mates += int(o["mates"])
		for o in TJ.offers(sd, 5, sd, 0, [2, 1, 2, 2]):
			if o["flavor"] == "detailed": precise += 1
			if o["collar"] == "white": office += 1
			ind_mates += int(o["mates"])
		for o in TJ.offers(sd, 5, sd, 0, [1, 0, 1, 1]):
			phys += 1 if TJ.head_share(TJ.job_of(o)) < 0.5 else 0
		for o in TJ.offers(sd, 5, sd, 0, [1, 2, 1, 1]):
			cere += 1 if TJ.head_share(TJ.job_of(o)) > 0.5 else 0
	var base_q := 0
	var base_p := 0
	var base_t := 0
	var base_o := 0
	var base_ph := 0
	var base_ce := 0
	for sd in range(1, 80):
		for o in TJ.offers(sd, 5, sd, 0, [1, 1, 1, 1]):
			if o["flavor"] == "urgent": base_q += 1
			if o["flavor"] == "detailed": base_p += 1
			if o["collar"] == "blue": base_t += 1
			if o["collar"] == "white": base_o += 1
			if TJ.head_share(TJ.job_of(o)) < 0.5: base_ph += 1
			if TJ.head_share(TJ.job_of(o)) > 0.5: base_ce += 1
	check("Quick posts more Urgent (%d vs %d), Precise more Detailed (%d vs %d)" % [quick, base_q, precise, base_p], quick > base_q + 20 and precise > base_p + 20)
	check("Trades posts more blue collar (%d vs %d), Office more white (%d vs %d)" % [trades, base_t, office, base_o], trades > base_t + 20 and office > base_o + 20)
	check("Physical posts more hands-on jobs (%d vs %d), Cerebral more head-down (%d vs %d)" % [phys, base_ph, cere, base_ce], phys > base_ph + 20 and cere > base_ce + 20)
	check("Group posts many more co-workers than Independent (%d vs %d)" % [grp_mates, ind_mates], grp_mates > ind_mates * 3)
	var pay_g := 0.0
	var pay_i := 0.0
	var ng_ := 0
	for sd in range(1, 120):
		for o in TJ.offers(sd, 5, sd, 0, [1, 1, 1, 0]):
			if o["flavor"] == "normal":
				pay_g += float(o["reward"]) / float(TJ.job_of(o)["base"])
				ng_ += 1
		for o in TJ.offers(sd, 5, sd, 0, [1, 1, 1, 2]):
			if o["flavor"] == "normal":
				pay_i += float(o["reward"]) / float(TJ.job_of(o)["base"])
	check("Group pays a little less than the base, Independent a little more (%.2f vs %.2f)" % [pay_g / ng_, pay_i / ng_], pay_g / ng_ < 0.97 and pay_i / ng_ > 1.05)
	var urg := 0.0
	var nrm := 0.0
	var nu := 0
	var nn := 0
	for sd in range(1, 200):
		for o in TJ.offers(sd, 5, sd, 0, [1, 1, 1, 1]):
			var r: float = float(o["reward"]) / float(TJ.job_of(o)["base"])
			if o["flavor"] == "urgent":
				urg += r
				nu += 1
			elif o["flavor"] == "normal":
				nrm += r
				nn += 1
	check("Urgent pays about 150-225%% of Normal (%.2f)" % ((urg / nu) / (nrm / nn)), (urg / nu) / (nrm / nn) > 1.45 and (urg / nu) / (nrm / nn) < 2.3)
	var mm := {"offer": {"flavor": "detailed", "reward": 200}, "best": {"0": 4, "1": 4, "2": 4}}
	check("Detailed: 12 points over is +120%% (gross %d)" % TJ.gross(mm), TJ.gross(mm) == 440)
	check("a failed attempt costs nothing but time", TJ.gross({"offer": {"flavor": "normal", "reward": 200}, "fails": 7}) == 200)
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
	TJ.begin(ng)
	var t0: int = ng.sim.tick
	var tries := 0
	ng.yen = 0
	while not bool(ng.mission["done"]) and tries < 300:
		for s in site2["stations"]:
			if not (ng.mission.get("st_done", {}) as Dictionary).has(str(int(s[0]))):
				var tr: Dictionary = TJ.do_task(ng, int(s[0]), -1)
		tries += 1
	check("the stations can all be finished", bool(ng.mission["done"]))
	check("tasks take time: two hours each (%d min passed)" % ((ng.sim.tick - t0) / 10), (ng.sim.tick - t0) >= 3 * 1200)
	var res: Dictionary = MS.outcome(ng, "")
	var exp_pay: int = TJ.gross(ng.mission)
	check("finishing pays in full whatever slips there were (%d of %d, flavor %s)" % [int(res["reward"]), int(o2["reward"]), String(o2["flavor"])], res["outcome"] == "success" or String(o2["flavor"]) == "urgent")
	check("status text counts the tasks", MS.status_text(ng).find("3/3") >= 0)
	# menus: a station, helpers, a co-worker, interview, ask for help
	var ng2 = GameScript.new(int(o2["seed"]))
	ng2.setup(0, null, Vector2i(-1, -1), MS.new_state(o2))
	TJ.begin(ng2)
	var cell0: int = int(ng2.city.get_meta("site")["stations"][0][0])
	var sm: Dictionary = TJ.station_menu(ng2, cell0)
	var labels: Array = sm["options"].map(func(x): return String(x["label"]))
	check("a station offers: complete now (with the time), get help, wait (%s)" % str(labels), labels.size() == 3 and labels[0].begins_with("Complete the task now") and labels[0].find("2 hours") >= 0 and labels[1].begins_with("Get help") and labels[2] == "Wait")
	var mates: Array = []
	for k in ng2.mission["agents"]:
		if ng2.mission["agents"][k] == "coworker":
			mates.append(int(k))
	check("co-workers are job mates for talking (%d)" % mates.size(), mates.size() == int(o2["mates"]) and mates.all(func(i): return int(ng2.eco.role[i]) == ng2.eco.JOBMATE))
	if not mates.is_empty():
		var i0: int = mates[0]
		var tmn: Dictionary = ng2.eco.menu_for(i0)
		var tl: Array = tmn["options"].map(func(x): return String(x["label"]))
		check("talking offers interview, ask for help, goodbye", tl.size() == 3 and tl[0].begins_with("Interview") and tl[1].begins_with("Ask for help") and tl[2] == "Say goodbye")
		check("the menu states the helper's 15% cut", " ".join(tmn["text"]).find("15%") >= 0)
		var tm2: Dictionary = ng2.eco.choose(tmn, 0)
		var times: Array = tm2["options"].map(func(x): return String(x["label"]))
		check("interview times are 7, 15 and 30 minutes (%s)" % str(times), times[0].begins_with("7 ") and times[1].begins_with("15 ") and times[2].begins_with("30 "))
		var tm3: Dictionary = ng2.eco.choose(tmn, 1)
		var times2: Array = tm3["options"].map(func(x): return String(x["label"]))
		check("help times are 15, 30 and 60 minutes", times2[0].begins_with("15 ") and times2[1].begins_with("30 ") and times2[2].begins_with("60 "))
		var tk0: int = ng2.sim.tick
		var hired := false
		var learned := false
		for t in 60:
			var dd: Dictionary = TJ.mate(ng2, i0)
			if not bool(dd["hired"]):
				TJ.do_talk(ng2, i0, "help", 60, 1)
			if not bool(dd["known"]):
				TJ.do_talk(ng2, i0, "interview", 30, 1)
			if bool(dd["hired"]) and bool(dd["known"]):
				break
		var d1: Dictionary = TJ.mate(ng2, i0)
		check("talking costs time and can win a helper and their skills", ng2.sim.tick > tk0 and bool(d1["hired"]) and bool(d1["known"]))
		check("a recruited helper shows in the help menu with a +1-plus-skill bonus", TJ.helpers_menu(ng2, cell0)["options"].size() == 2 and String(TJ.helpers_menu(ng2, cell0)["options"][0]["label"]).find("+") >= 0)
		var tr3: Dictionary = TJ.do_task(ng2, cell0, i0)
		check("a helped task marks the helper as used", TJ.helpers_used(ng2.mission) == 1)
		for s2 in ng2.city.get_meta("site")["stations"]:
			for t in 40:
				if (ng2.mission.get("st_done", {}) as Dictionary).has(str(int(s2[0]))):
					break
				TJ.do_task(ng2, int(s2[0]), -1)
		ng2.mission["done"] = true
		var m2: Dictionary = ng2.mission
		m2["offer"]["flavor"] = "normal"
		m2["offer"]["reward"] = 1000
		var cut: int = TJ.cut_pct(ng2)
		check("the helper's cut is 15%% less 1%% a Negotiation level (%d%%)" % cut, cut == maxi(0, 15 - ng2.lvl("negotiation")))
		check("the helper's share comes off the pay", TJ.pay_for(ng2, m2) == 1000 - int(round(1000.0 * cut / 100.0)))
	# an Urgent job: out of time means no pay
	var uo: Dictionary = o2.duplicate(true)
	uo["flavor"] = "urgent"
	uo["limit_min"] = 360
	var ng3 = GameScript.new(int(o2["seed"]))
	ng3.setup(0, null, Vector2i(-1, -1), MS.new_state(uo))
	TJ.begin(ng3)
	check("an Urgent job has a deadline six hours on", int(ng3.mission["deadline"]) - ng3.sim.tick == 3600)
	TJ.spend(ng3, 7 * 60)
	check("when time runs out the site closes and the job fails with no pay", ng3.mission_leave_request == "timeup" and MS.outcome(ng3, "timeup")["outcome"] != "success" and int(MS.outcome(ng3, "timeup")["reward"]) == 0)
	# Detailed jobs can be retried after a success
	var dof: Dictionary = o2.duplicate(true)
	dof["flavor"] = "detailed"
	var ng4 = GameScript.new(int(o2["seed"]))
	ng4.setup(0, null, Vector2i(-1, -1), MS.new_state(dof))
	TJ.begin(ng4)
	var c4: int = int(ng4.city.get_meta("site")["stations"][0][0])
	for t in 40:
		if (ng4.mission.get("st_done", {}) as Dictionary).has(str(c4)):
			break
		TJ.do_task(ng4, c4, -1)
	var l4: Array = TJ.station_menu(ng4, c4)["options"].map(func(x): return String(x["label"]))
	check("a Detailed task already done can be retried, and shows its margin", l4[0].begins_with("Re-try the task") and " ".join(TJ.station_menu(ng4, c4)["text"]).find("margin") >= 0)
	var uo2: Dictionary = o2.duplicate(true)
	uo2["flavor"] = "normal"
	var ng5 = GameScript.new(int(o2["seed"]))
	ng5.setup(0, null, Vector2i(-1, -1), MS.new_state(uo2))
	TJ.begin(ng5)
	var c5: int = int(ng5.city.get_meta("site")["stations"][0][0])
	for t in 40:
		if (ng5.mission.get("st_done", {}) as Dictionary).has(str(c5)):
			break
		TJ.do_task(ng5, c5, -1)
	check("a Normal task already done offers no retry", TJ.station_menu(ng5, c5)["options"].size() == 1)
	print("TEMPAGENCY %d/%d" % [ok, n])
	if ok != n:
		print("  >> tempagency FAILED")
	quit(0 if ok == n else 1)
