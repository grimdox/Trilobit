extends RefCounted
## Round three: floors, stairs, elevators, locked doors, the subway, the implant clocks, jobs, vendors, save/load.
const GameScript = preload("res://src/game.gd")
const CG = preload("res://src/citygen.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var t0 := Time.get_ticks_msec()
	var g = GameScript.new(5)
	g.setup(1500)
	log.append("  (setup %d ms; %d levels; %d towers; %d people)" % [Time.get_ticks_msec() - t0, g.city.nlev, g.city.tower_info.size(), g.sim.n])
	var tall: Dictionary = {}
	for t in g.city.tower_info:
		if tall.is_empty() or int(t["h"]) > int(tall["h"]):
			tall = t
	var S: int = tall["stairs"]
	var E: int = tall["elev"]
	# --- stairs and elevators
	g.pc = S
	g.sim.retier(g.pc)
	g.fov.compute(g.lx(g.pc), g.pc / g.size, 18)
	var ok_up := true
	for k in 5:
		ok_up = g.act_vertical(1) and ok_up
	check.call("five flights of stairs up: floor 5, same x,y", ok_up and g.z_of(g.pc) == 5 and g.pc % g.s2 == S)
	g.act_vertical(-1)
	check.call("and one flight down", g.z_of(g.pc) == 4)
	g.pc = E
	check.call("using an elevator asks for a floor instead of moving", not g.act_vertical(1) and g.elev_hit == E)
	g.elev_hit = -1
	var floors: Array = g.elevator_floors(E)
	check.call("the elevator list holds every floor from the ground to the roof (%d)" % floors.size(), floors.size() == int(tall["h"]) + 1 and int(floors[0]["z"]) == 0)
	check.call("it rides straight to any floor (floor 7)", g.act_elevator_to(7) and g.z_of(g.pc) == 7 and g.city.tiles[g.pc] == CG.ELEVATOR)
	# whoever stands on the arrival cell is moved aside: the elevator is always open to the player
	var top_cell: int = g.pc % g.s2 + g.city.level_base(g.city.lvl_of_z(10))
	g.sim.at[top_cell] = 1
	check.call("someone is standing in the elevator at floor 10", g.sim.at[top_cell] == 1)
	var rode: bool = g.act_elevator_to(10)
	g.sim.at[top_cell] = -1
	check.call("it still takes you there, and they step aside", rode and g.z_of(g.pc) == 10)
	g.act_elevator_to(int(tall["h"]))
	check.call("there is no way up from the roof", not g.act_vertical(1))
	check.call("the roof is 14 storeys up", int(tall["h"]) == 14)
	# --- people on upper floors become real agents when you arrive
	var res := -1
	for i in g.sim.n:
		if g.sim.home_cell[i] / g.s2 >= 6 and g.sim.pos[i] == g.sim.home_cell[i] and g.sim.arrive[i] < 0:
			res = i
			break
	check.call("someone lives above the sixth floor", res >= 0)
	g.pc = g.sim.home_cell[res]
	g.sim.at[g.pc] = -1
	g.sim.retier(g.pc)
	g.fov.compute(g.lx(g.pc), g.pc / g.size, 18)
	var same := 0
	for k in g.sim.near_list.size():
		if g.sim.pos[g.sim.near_list[k]] / g.s2 == g.pc / g.s2:
			same += 1
	check.call("arriving on a floor promotes its residents (%d near)" % same, g.sim.near[res] == 1 and same >= 1)
	var other := 0
	for k in g.sim.near_list.size():
		if g.sim.pos[g.sim.near_list[k]] / g.s2 != g.pc / g.s2:
			other += 1
	check.call("nobody on other floors is a full agent", other == 0)
	# --- view: only this floor is visible
	var seen_other := false
	for i in range(0, g.s2 * 2, 997):
		if g.fov.visible[i] == 1 and (i / g.s2) != (g.pc / g.s2):
			seen_other = true
	check.call("FOV stays on the floor you are on", not seen_other)
	# --- locked vault
	check.call("there are locked vaults with loot", g.city.vaults.size() >= 3)
	var vault: PackedInt32Array = g.city.vaults[0]
	var loot_cells := 0
	for c in vault:
		if g.items_at.has(c):
			loot_cells += 1
	check.call("vault holds no loose loot", loot_cells == 0)
	var door := -1
	var vc: int = vault[0]
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			var c: int = vc + dy * g.size + dx
			if door < 0 and g.city.tiles[c] == CG.LOCKED:
				door = c
	check.call("a locked door guards the vault", door >= 0)
	var from := -1
	for nb in [door - 1, door + 1, door - g.size, door + g.size]:
		if g.city.tiles[nb] == CG.FLOOR and g.sim.at[nb] == -1 and not vault.has(nb):
			from = nb
	if from < 0:
		for nb in [door - 1, door + 1, door - g.size, door + g.size]:
			if g.city.tiles[nb] == CG.FLOOR and g.sim.at[nb] == -1:
				from = nb
	g.pc = from
	var dx2: int = (door % g.size) - (from % g.size)
	var dy2: int = ((door / g.size) % g.size) - ((from / g.size) % g.size)
	g.skills["engineering"] = 6
	var tries := 0
	while g.city.tiles[door] == CG.LOCKED and tries < 40:
		g.pc = from
		g.act_move(dx2, dy2)
		tries += 1
	check.call("picking the lock opens the door (%d tries)" % tries, g.city.tiles[door] == CG.DOOR)
	# --- the subway
	var tr = g.transit
	check.call("subway runs on a ring with four stops", tr.active() and tr.stop_heads.size() == 4 and tr.TRAINS >= 2)
	var h0: int = tr.head
	for k in 20:
		tr.step()
	check.call("the train moves along the ring", tr.head != h0)
	var waits := 0
	while tr.dwell == 0 and waits < 2000:
		tr.step()
		waits += 1
	check.call("the train stops at a station (%d steps)" % waits, tr.dwell > 0)
	# find an open tdoor with a platform beside it
	var occ: Dictionary = tr.occupancy()
	var tdoor := -1
	var plat := -1
	var dj := 0
	for c in occ:
		var inf: Array = tr.occ_unpack(int(occ[c]))
		if tr.dwell_of(int(inf[0])) > 0 and int(inf[2]) == tr.DOOR_A and (int(inf[3]) == 0 or int(inf[3]) == 3):
			for nb in [c - 1, c + 1, c - g.size, c + g.size]:
				if g.city.tiles[nb] == CG.PLATFORM and not occ.has(nb) and tdoor < 0:
					tdoor = c
					plat = nb
					dj = int(inf[0])
	check.call("a platform lies beside an open door of a stopped train", plat >= 0)
	g.pc = plat
	g.sim.retier(g.pc)
	g.act_move((tdoor % g.size) - (plat % g.size), ((tdoor / g.size) % g.size) - ((plat / g.size) % g.size))
	check.call("stepping through an open door boards", tr.riding >= 0 and g.pc == tdoor)
	var start_cell: int = g.pc
	# step inside, onto the floor
	var inner: int = -1
	for nb in [tdoor - 1, tdoor + 1, tdoor - g.size, tdoor + g.size]:
		var ri2: Array = tr.car_on(nb)
		if not ri2.is_empty() and int(ri2[0]) == dj and (int(ri2[3]) == 1 or int(ri2[3]) == 2):
			inner = nb
	g.act_move((inner % g.size) - (tdoor % g.size), ((inner / g.size) % g.size) - ((tdoor / g.size) % g.size))
	check.call("you can walk inside the carriage", g.pc == inner and tr.riding >= 0)
	start_cell = g.pc
	var guard := 0
	while (tr.dwell_of(dj) > 0 or guard < 3) and guard < 60:
		g.act_wait()
		guard += 1
	var moved_ok: bool = tr.riding >= 0 and g.pc == tr.seat_cell()
	check.call("while riding, you travel with the train", moved_ok)
	var rides := 0
	while tr.dwell_of(dj) == 0 and rides < 200:
		g.act_wait()
		rides += 1
	var far: int = g.cheb(g.pc, start_cell)
	check.call("it carries you to the next station (%d cells in %d turns)" % [far, rides], tr.dwell_of(dj) > 0 and far > 30 and not g.body.vital_dead())
	# walk to a tdoor and off onto the platform
	var exit_to := -1
	var exit_door := -1
	var occ2: Dictionary = tr.occupancy()
	for c in occ2:
		var inf2: Array = tr.occ_unpack(int(occ2[c]))
		if int(inf2[0]) == dj and int(inf2[2]) == tr.DOOR_A and int(inf2[1]) == tr.riding and (int(inf2[3]) == 0 or int(inf2[3]) == 3):
			for nb in [c - 1, c + 1, c - g.size, c + g.size]:
				if g.city.tiles[nb] == CG.PLATFORM and not occ2.has(nb) and exit_to < 0:
					exit_to = nb
					exit_door = c
	check.call("a door with a platform beyond it is in your carriage", exit_to >= 0)
	var wtries := 0
	while g.pc != exit_door and wtries < 20 and exit_door >= 0:
		var dx: int = signi((exit_door % g.size) - (g.pc % g.size))
		var dy: int = signi(((exit_door / g.size) % g.size) - ((g.pc / g.size) % g.size))
		if dx != 0 and dy != 0:
			dy = 0
		g.act_move(dx, dy)
		wtries += 1
	g.act_move((exit_to % g.size) - (g.pc % g.size), ((exit_to / g.size) % g.size) - ((g.pc / g.size) % g.size))
	check.call("you can step off onto the platform", tr.riding < 0 and g.city.tiles[g.pc] == CG.PLATFORM)
	var hp_before: int = g.body.total()
	var guard2 := 0
	while guard2 < 3000 and not (tr.tab_dwell[tr._u(0)] == 0 and tr.tab_dwell[(tr._u(0) + 1) % tr.period] == 0 and tr.dwell_of(0) == 0):
		tr.step()
		guard2 += 1
	var track_cell: int = tr.cell_of[(tr.head_of(0) + 3) % tr.path.size()]
	g.pc = track_cell
	tr.step()
	check.call("standing on the track when the train comes through hurts", g.body.total() < hp_before)
	# --- no debt: the clock runs past the old installment days and nothing is owed, no collectors come
	g.body.reset()
	g.game_over = false
	g.sim.tick = 6 * 14400 + 8 * 600 - 1
	g.end_turn()
	var collectors := 0
	for i in g.sim.n:
		if g.nname[i].begins_with("Collector"):
			collectors += 1
	check.call("there is no debt: no interest, no installment, no collectors (%d)" % collectors, g.eco.get("debt") == null and collectors == 0)
	# --- the ripperdoc has no stabiliser to service any more
	var ripper := -1
	for i in g.sim.n:
		if g.eco.role[i] == 2:
			ripper = i
	check.call("a ripperdoc exists and sells implants and trauma patches, not stabiliser service", ripper >= 0 and g.eco.menu_for(ripper)["options"].all(func(o): return o["op"] != "service"))
	# --- vendors and jobs
	var vendor := -1
	var fixer := -1
	for i in g.sim.n:
		if g.eco.role[i] == 1 and vendor < 0:
			vendor = i
		if g.eco.role[i] == 3 and fixer < 0:
			fixer = i
	g.yen = 500
	var inv0: int = g.inventory_list().size()
	g.eco.choose(g.eco.menu_for(vendor), 0)
	check.call("a vendor sells food", g.yen < 500 and g.inventory_list().size() >= inv0)
	g.eco.job = {}
	g.eco.choose(g.eco.menu_for(fixer), 0)
	check.call("a fixer gives a courier job to a high floor", g.eco.job.get("kind", "") == "courier" and int(g.eco.job["z"]) >= 4 and g.eco._find("trl_parcel") != null)
	var y0: int = g.yen
	g.pc = g.eco.job["cell"]
	g.sim.retier(g.pc)
	g.end_turn()
	check.call("delivering the parcel pays and clears the job", g.yen > y0 and g.eco.job.is_empty() and g.eco.jobs_done == 1)
	g.eco.choose(g.eco.menu_for(fixer), 1)
	check.call("a retrieval job places a data case", g.eco.job.get("kind", "") == "retrieval" and g.items_at.has(int(g.eco.job["cell"])))
	var y1: int = g.yen
	g.pc = g.eco.job["cell"]
	g.sim.retier(g.pc)
	g.act_pickup()
	check.call("recovering the case pays", g.yen > y1 and g.eco.job.is_empty())
	# --- save / load
	g.pc = g.eco.job.get("cell", S) if false else S
	var head1: int = g.transit.head
	var blob: String = JSON.stringify(g.save_dict())
	var d = JSON.parse_string(blob)
	g.load_dict(d)
	check.call("save and load keep the train and the position", g.transit.head == head1 and g.pc == S)
	# --- speed
	var t1 := Time.get_ticks_msec()
	for k in 120:
		g.end_turn()
	var per: float = float(Time.get_ticks_msec() - t1) / 120.0
	log.append("  (%.1f ms per full turn with %d people, %d cells in %d levels)" % [per, g.sim.n, g.total, g.city.nlev])
	check.call("a turn stays under 15 ms", per < 15.0)
	return [st[0], st[1], log]
