extends SceneTree
## Parking lots, charging stations, parked cars, vehicle charging, the interact key (doors, tables, posts, picker), no debt.  Run: godot --headless -s tests/run_lots.gd
const WorldScript = preload("res://src/world.gd")
const CG = preload("res://src/citygen.gd")
const PW = preload("res://src/power.gd")
const ST = preload("res://src/settings.gd")
const GameScript = preload("res://src/game.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

## put the player on a free walkable cell beside `cell` and return the direction that faces it
func stand_beside(g, cell: int) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var c: int = (cell / g.size + d.y) * g.size + cell % g.size + d.x
		if g.sim.walk[c] == 1 and g.sim.at[c] == -1 and g.thing_at.g(c) == -1 and g.veh_at.g(c) == -1 and not g.items_at.has(c):
			g.pc = c
			g.last_pc = c
			g._compute_fov()
			return Vector2i(-d.x, -d.y)
	return Vector2i.ZERO

func _initialize() -> void:
	var w = WorldScript.new()
	w.start(21, 300)
	var g = w.game
	# ---- lots and stations
	var nl := 0
	var ns := 0
	var bays := 0
	for lot in g.city.lots:
		if lot["kind"] == "lot":
			nl += 1
		else:
			ns += 1
		bays += lot["bays"].size()
	check("the city has parking lots (%d) and charging stations (%d) with %d bays" % [nl, ns, bays], nl >= 3 and ns >= 3 and bays >= 100)
	var banks_ok := true
	for c in g.city.ev_chargers:
		for k in 4:
			if g.city.tiles[c + (k / 2) * g.size + k % 2] != CG.TID["ev_charger_nw"] + k or g.sim.walk[c + (k / 2) * g.size + k % 2] != 0:
				banks_ok = false
	check("a vehicle charger is a solid 2 x 2 bank (%d of them), bigger than the 1-tile post for people" % g.city.ev_chargers.size(), banks_ok and g.city.ev_chargers.size() >= 6)
	var st_ok := true
	for lot in g.city.lots:
		if lot["kind"] == "station" and (lot["chargers"].size() < 4 or lot["posts"].size() != 1):
			st_ok = false
	check("every charging station has vehicle banks and a post for people", st_ok)
	var bay_ok := true
	for lot in g.city.lots:
		for b in lot["bays"]:
			for yy in 6:
				for xx in 4:
					if g.city.tiles[(int(b[1]) + yy) * g.size + int(b[0]) + xx] != CG.ROAD:
						bay_ok = false
	check("every bay is 4 x 6 of open paving", bay_ok)
	# ---- parked cars
	var per_lot: Array = []
	var inside := true
	var ev_lot_dead := 0
	for lot in g.city.lots:
		var cnt := 0
		for v in g.vehicles:
			if v["ai"] or v["kind"] != "car":
				continue
			var cell: int = int(v["cell"])
			var vx: int = cell % g.size
			var vy: int = (cell / g.size) % g.size
			if vx >= lot["x0"] and vx <= lot["x1"] and vy >= lot["y0"] and vy <= lot["y1"]:
				cnt += 1
		per_lot.append(cnt)
	var empty := per_lot.filter(func(c): return c == 0).size()
	var full := 0
	for i in g.city.lots.size():
		if g.city.lots[i]["bays"].size() >= 12 and per_lot[i] >= g.city.lots[i]["bays"].size():
			full += 1
	check("lots are filled to different degrees, some completely empty (%d empty of %d), at most one completely full (%d)" % [empty, per_lot.size(), full], empty >= 1 and full <= 1 and per_lot.max() >= 6)
	var parked: Array = []
	for vi in g.vehicles.size():
		if not g.vehicles[vi]["ai"] and g.vehicles[vi]["kind"] == "car":
			parked.append(vi)
	check("parked cars are normal cars you can get into and drive away (%d of them)" % parked.size(), parked.size() >= 20 and g.vehicles[parked[0]]["driver"] == -1)
	# get in and out of one
	var pv: int = parked[0]
	var pcells: PackedInt32Array = g.vs.cells(g.vehicles[pv])
	var ent := -1
	for c in pcells:
		for d in [1, -1, g.size, -g.size]:
			var nb: int = c + d
			if g.sim.walk[nb] == 1 and g.veh_at.g(nb) == -1 and g.sim.at[nb] == -1 and ent < 0:
				ent = nb
	g.pc = ent
	g.last_pc = ent
	g.act_vehicle()
	check("you can get in a parked car", g.in_vehicle == pv or g.in_vehicle >= 0)
	g.act_vehicle()
	check("and get out again", g.in_vehicle == -1)
	# ---- vehicle charging
	var bank: int = g.city.ev_chargers[0]
	var lot_i := -1
	for i in g.city.lots.size():
		if bank in g.city.lots[i]["chargers"]:
			lot_i = i
	var bay: Array = []
	for b in g.city.lots[lot_i]["bays"]:
		if int(b[2]) == 1:
			bay = b
			break
	for vi in g.vehicles.size():                 # clear whatever stands in the bay, then park a low car there
		var vc: int = int(g.vehicles[vi]["cell"])
		if not g.vehicles[vi]["ai"] and absi(vc % g.size - int(bay[0])) < 6 and absi((vc / g.size) % g.size - int(bay[1])) < 8 and g.vehicles[vi]["kind"] == "car":
			g.vs.lift(vi)
			g.vehicles[vi]["cell"] = 0
			g.vehicles[vi]["wreck"] = true
	var car: int = g.park_in_bay(int(bay[0]), int(bay[1]), Color.WHITE, 20, 20)
	check("a car parks in the bay beside a bank with its battery at 20%", car >= 0 and g.vehicles[car]["charge"] == 20 and g.vehicles_at_bank(bank).has(car))
	var dir: Vector2i = stand_beside(g, bank)
	var turn0: int = g.turn
	var bumped: bool = g.act_move(dir.x, dir.y)
	check("bumping the bank only says what it is and takes no time", not bumped and g.turn == turn0 and g.ev_hit == -1)
	var list: Array = g.interactables()
	var evs: Array = list.filter(func(it): return it["kind"] == "ev")
	check("the interact key finds the bank (once, though it has four tiles)", evs.size() == 1 and evs[0]["cell"] == bank)
	g.act_interact_with(evs[0])
	check("using it asks for the bank's menu", g.ev_hit == bank)
	g.ev_hit = -1
	g.yen = 0
	var m0: Dictionary = g.eco.ev_menu(bank)
	var idx := -1
	for k in m0["options"].size():
		if m0["options"][k]["op"] == "ev_charge" and int(m0["options"][k]["arg"][1]) == car:
			idx = k
			break
	check("the menu offers a full charge for the car with the real price", idx >= 0 and String(m0["options"][idx]["label"]).contains("¥%d" % PW.vehicle_quote(80, g.district_of(bank))))
	g.eco.choose(m0, idx)
	check("with no yen nothing is charged", g.vehicles[car]["charge"] == 20 and g.yen == 0)
	g.yen = 1000
	var m1: Dictionary = g.eco.ev_menu(bank)
	for k in m1["options"].size():
		if m1["options"][k]["op"] == "ev_charge" and int(m1["options"][k]["arg"][1]) == car:
			idx = k
			break
	var q: int = PW.vehicle_quote(80, g.district_of(bank))
	g.eco.choose(m1, idx)
	check("paying fills the pack to 100%% for ¥%d (80 points x 2 kJ x 1.1 in the middle district)" % q, g.vehicles[car]["charge"] == 100 and g.yen == 1000 - q and q > 0)
	check("a full pack is not charged again", not g.recharge_vehicle(bank, car, 50) and g.yen == 1000 - q)
	check("the price is the pack's kJ at the district rate plus the power tax: 100%% = %d yen in the middle" % PW.vehicle_quote(100, 1), PW.vehicle_quote(100, 1) == 220 and PW.vehicle_quote(0, 1) == 0 and PW.vehicle_affordable_pct(220, 1) == 100)
	g.vehicles[car]["charge"] = 50
	g.in_vehicle = car
	var in_v: Array = g.interactables()
	check("from inside the car the interact key still finds the bank", in_v.size() == 1 and in_v[0]["kind"] == "ev")
	g.in_vehicle = -1
	# ---- doors: every door starts shut
	check("every door starts shut: none is open, and shut ones are opaque", g.city.tiles.find(CG.DOOR) == -1 and g.city.tiles.find(CG.TID["door_closed"]) >= 0)
	var door := -1
	var dc: int = g.city.tiles.find(CG.TID["door_closed"])
	while dc >= 0 and dc < g.s2:
		if g.sim.at[dc] == -1 and g.thing_at.g(dc) == -1 and g.veh_at.g(dc) == -1 and not g.items_at.has(dc) and stand_beside(g, dc) != Vector2i.ZERO:
			door = dc
			break
		dc = g.city.tiles.find(CG.TID["door_closed"], dc + 1)
	var dd: Vector2i = stand_beside(g, door)
	g.facing = Vector2i(-dd.x, -dd.y)
	check("a shut door is opaque to sight", g.sim.opaque[door] == 1 and g.sim.walk[door] == 1)
	var dl: Array = g.interactables().filter(func(it): return it["kind"] == "door" and it["cell"] == door)
	check("a shut door is listed as shut", dl.size() == 1 and dl[0]["label"] == "Door (shut)")
	var turn1: int = g.turn
	var moved: bool = g.act_move(dd.x, dd.y)
	check("walking into a shut door opens it (a turn) and does not move you", g.city.tiles[door] == CG.DOOR and g.sim.opaque[door] == 0 and g.open_doors.has(door) and g.turn > turn1 and moved)
	var sd: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = GameScript.new(21)
	g2.load_dict(sd)
	check("an opened door stays open through a save and load, the rest stay shut", g2.city.tiles[door] == CG.DOOR and g2.sim.opaque[door] == 0 and g2.open_doors.has(door) and g2.city.tiles[dc] != 0)
	g2.dispose()
	g.act_interact_with(g.interactables().filter(func(it): return it["kind"] == "door" and it["cell"] == door)[0])
	check("using an open door shuts it again", g.city.tiles[door] == CG.TID["door_closed"] and g.sim.opaque[door] == 1 and not g.open_doors.has(door))
	g.act_interact_with(g.interactables().filter(func(it): return it["kind"] == "door" and it["cell"] == door)[0])
	check("using a shut door opens it", g.city.tiles[door] == CG.DOOR)
	g.act_interact_with(g.interactables().filter(func(it): return it["kind"] == "door" and it["cell"] == door)[0])
	var walker := 0
	while g.sim.alive[walker] == 0:
		walker += 1
	g.sim.place(walker, door)
	g._doors_tick()
	check("somebody stepping into a shut door opens it", g.city.tiles[door] == CG.DOOR and g.open_doors.has(door))
	# ---- the gunsmithing table and the picker
	var free := -1
	for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
		var c2: int = g.pc + d2.y * g.size + d2.x
		if g.sim.walk[c2] == 1 and g.sim.at[c2] == -1 and g.veh_at.g(c2) == -1 and g.thing_at.g(c2) == -1 and c2 != door and g.city.tiles[c2] != CG.DOOR:
			free = c2
			break
	var old_t: int = g.city.tiles[free]
	g.city.tiles[free] = CG.TID["gunsmith_table"]
	g.sim.walk[free] = 0
	var sl: Array = g.interactables().filter(func(it): return it["kind"] == "smith")
	check("a gunsmithing table is listed beside you", sl.size() == 1)
	g.act_interact_with(sl[0])
	check("using it opens the gun bench", g.smith_hit == free)
	g.smith_hit = -1
	check("a table is solid and bumping it only names it", not g.act_move(signi(free % g.size - g.pc % g.size), signi((free / g.size) % g.size - (g.pc / g.size) % g.size)) and g.smith_hit == -1)
	var many: Array = g.interactables()
	check("with a table and a door beside you the key lists both for you to choose (%d)" % many.size(), many.size() >= 2)
	g.city.tiles[free] = old_t
	g.sim.walk[free] = 1
	# ---- no debt, no gunsmith key, no service key
	var lots_sig: int = g.city.lots.size()                  # (one 1536 city at a time: the same-seed check is made last, from what the first city looked like)
	var ev_sig: PackedInt32Array = PackedInt32Array(g.city.ev_chargers)
	w.game.dispose()
	var w2 = WorldScript.new()
	w2.start(21, 300)
	check("the same seed gives the same lots and banks", w2.game.city.lots.size() == lots_sig and PackedInt32Array(w2.game.city.ev_chargers) == ev_sig)
	w2.game.dispose()
	var fresh = GameScript.new(5)
	fresh.setup(300)
	var keys: Array = ST.ACTIONS.map(func(a): return a[0])
	check("there is no debt, no pay action, no vehicle service action, no gunsmith key", fresh.eco.get("debt") == null and not fresh.has_method("act_pay") and not keys.has("pay") and not keys.has("service") and not keys.has("gunsmith") and keys.has("interact"))
	check("you start with no cash", fresh.yen == 0 and fresh.eco.status_text() == "")
	print("LOTS %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
