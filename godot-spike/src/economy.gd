extends RefCounted
## The pressure systems and the people who deal with them.
##   debt:     a loan from Kuroda Lending, interest every midnight, an installment every three days; missed ones become arrears,
##             arrears become collectors (armed Nasim runners who find you), and clearing it is the long-term goal
##   implant:  a failing cortical stabiliser that must be serviced by a ripperdoc before it runs out: tremor, then seizures
##   jobs:     fixers hand out couriers (carry a parcel to a flat or office, anywhere in the city, floors up) and retrievals
##             (a data case left on a roof or down in the sewers); both pay by credstick on completion
##   vendors:  sell food, water, ammunition, a trauma patch and carrying gear
##   ripperdocs: two, one in the sewers (cheap, risky to reach) and one in a tower clinic (dear, safe); sticky, they never move
## People get roles from this module; `role` is indexed like the NPC arrays (0 none, 1 vendor, 2 ripperdoc, 3 fixer).
const CG = preload("res://src/citygen.gd")
const NONE := 0
const VENDOR := 1
const RIPPER := 2
const FIXER := 3
const DAY := 1440

var g
var role: PackedByteArray
var debt: int = 4000
var arrears: int = 0
var paid_cycle: int = 0
var implant_left: int = 96 * 60      # turns (a turn is a minute) until the stabiliser fails
var job: Dictionary = {}
var jobs_done: int = 0
var earned: int = 0
var debt_free: bool = false
var ripper_cells: Array = []
var last_tower_clinic: int = -1

func setup(game) -> void:
	g = game
	var n: int = g.sim.n
	role = PackedByteArray()
	role.resize(n)
	var order := range(n)
	var rng: RandomNumberGenerator = g.rng
	# ripperdocs first: one in the sewers, one in a tower clinic
	var used := 0
	var sew: int = _first_lair()
	if sew >= 0:
		_station(order[used], sew, RIPPER, "Dr. Okabe")
		used += 1
	var clinic: int = _clinic_cell()
	if clinic >= 0:
		_station(order[used], clinic, RIPPER, "Dr. Aoki")
		last_tower_clinic = clinic
		used += 1
	# squatters in the sewers
	var lairs: PackedInt32Array = g.city.lairs
	for k in mini(lairs.size(), 20):
		var i: int = order[used]
		used += 1
		var bratva := k % 3 != 2
		g.fac[i] = g.BRATVA if bratva else g.NASIM
		g.hpmax[i] = 45 if bratva else 30
		g.hpn[i] = g.hpmax[i]
		g.gunc[i] = 1 if bratva and k % 2 == 0 else (2 if bratva else 0)
		g.yenn[i] = rng.randi_range(40, 220)
		_station(i, lairs[k], NONE, "")
	# vendors and fixers among ordinary people (not the ones above)
	for i in range(used, n):
		if g.fac[i] != g.CIV:
			continue
		var r := rng.randf()
		if r < 0.06:
			role[i] = VENDOR
		elif r < 0.11:
			role[i] = FIXER

## put agent i at a cell for good
func _station(i: int, cell: int, r: int, name: String) -> void:
	role[i] = r
	var sim = g.sim
	sim.pos[i] = cell
	sim.home_cell[i] = cell
	sim.dest[i] = cell
	sim.goal[i] = sim.HOME
	sim.arrive[i] = -1
	sim.sticky[i] = 1
	if name != "":
		g.nname[i] = name
		g.fac[i] = g.CIV
		g.hpmax[i] = 40
		g.hpn[i] = 40

func _first_lair() -> int:
	var lairs: PackedInt32Array = g.city.lairs
	return lairs[lairs.size() - 1] if lairs.size() > 0 else -1

## a work marker on a mid floor of the tallest tower
func _clinic_cell() -> int:
	var tall: Dictionary = {}
	for t in g.city.tower_info:
		if tall.is_empty() or int(t["h"]) > int(tall["h"]):
			tall = t
	if tall.is_empty():
		return -1
	var want: int = mini(12, int(tall["h"]) - 1)
	for c in g.city.works_t:
		if g.z_of(c) == want and g.lx(c) >= tall["x0"] and g.lx(c) <= tall["x1"] and g.ly(c) >= tall["y0"] and g.ly(c) <= tall["y1"]:
			return c
	return -1

func label(i: int) -> String:
	match role[i]:
		VENDOR: return "vendor"
		RIPPER: return "ripperdoc"
		FIXER: return "fixer"
	return ""

# ------------------------------------------------------------------ the clocks
func step() -> void:
	var t: int = g.sim.tick
	if t % DAY == 0:
		var add: int = int(ceil(debt * 0.02))
		if debt > 0:
			debt += add
			g.say("Midnight.  Kuroda Lending adds ¥%d interest.  You owe ¥%d." % [add, debt])
	if t >= DAY * 3 and t % (DAY * 3) == 8 * 60 and debt > 0:
		_due()
	# the implant
	if implant_left > 0:
		implant_left -= 1
		match implant_left:
			24 * 60: g.say("Your stabiliser throws a warning: 24 hours of service life left.")
			12 * 60: g.say("Your hands begin to tremble.  Twelve hours left on the stabiliser.")
			3 * 60: g.say("The stabiliser is failing.  Three hours.")
			0: g.say("The stabiliser dies.  Your nerves misfire.  Find a ripperdoc.")
	elif g.turn % 10 == 0:
		g.hp -= 2
		g.say("A seizure grips you (-2).")
	if implant_left < 12 * 60 and implant_left > 0 and g.turn % 40 == 0:
		g.say(["Your fingers jitter.", "A static hiss floods your ears.", "The edges of your vision flicker."][g.rng.randi() % 3])
	_job_step()

func min_payment() -> int:
	return maxi(150, debt / 20)

func _due() -> void:
	var need: int = min_payment()
	if paid_cycle >= need:
		g.say("Installment received.  Next one in three days.")
	else:
		arrears += 1
		debt += 120
		g.say("You missed the installment (¥%d).  Arrears: %d.  A ¥120 fee is added." % [need, arrears])
		if arrears >= 2 and arrears % 2 == 0:
			g.say("Kuroda Lending has sent collectors.")
			_collectors(2)
	paid_cycle = 0

## pay down the debt from cash
func pay(amount: int) -> bool:
	var amt: int = mini(mini(amount, g.yen), debt)
	if amt <= 0:
		g.say("Nothing to pay, or nothing to pay with.")
		return false
	g.yen -= amt
	debt -= amt
	paid_cycle += amt
	g.say("You pay ¥%d.  You owe ¥%d." % [amt, debt])
	if debt <= 0 and not debt_free:
		debt_free = true
		arrears = 0
		g.say("DEBT CLEARED.  Kuroda Lending closes your file.  You are free to leave this city, or to stay.")
	return true

func aim_penalty() -> int:
	if implant_left <= 0:
		return 28
	if implant_left < 12 * 60:
		return 10
	return 0

func _collectors(count: int) -> void:
	var sim = g.sim
	var picked := 0
	for _try in 400:
		if picked >= count:
			break
		var i: int = g.rng.randi() % sim.n
		if sim.alive[i] == 0 or role[i] != NONE or g.fac[i] != g.CIV:
			continue
		# a free walkable cell 9..13 away on the player's level
		var cell := -1
		for _t in 30:
			var a: float = g.rng.randf() * TAU
			var r: int = g.rng.randi_range(9, 13)
			var x: int = g.lx(g.pc) + int(cos(a) * r)
			var y: int = g.ly(g.pc) + int(sin(a) * r)
			if x < 1 or y < 1 or x >= g.size - 1 or y >= g.size - 1:
				continue
			var c: int = (g.pc / g.s2) * g.s2 + y * g.size + x
			if sim.walk[c] == 1 and sim.at[c] == -1 and g.veh_at[c] == -1:
				cell = c
				break
		if cell < 0:
			continue
		g.fac[i] = g.NASIM
		g.hpmax[i] = 36
		g.hpn[i] = 36
		g.gunc[i] = 1
		g.yenn[i] = g.rng.randi_range(120, 300)
		g.nname[i] = "Collector " + g.nname[i]
		sim.place(i, cell)
		sim.ctl[i] = 1
		g.astate[i] = g.HUNTING
		g.meter[i] = 100
		g.noticed_you[i] = 1
		g.lastpos[i] = g.pc
		picked += 1

# ------------------------------------------------------------------ jobs
func _job_step() -> void:
	if job.is_empty():
		return
	if g.turn > int(job["deadline"]):
		g.say("The job window closes.  The client writes you off.")
		_drop_job_items()
		job = {}
		return
	if job["kind"] == "courier":
		var it = _find("trl_parcel")
		if it != null and g.z_of(g.pc) == int(job["z"]) and g.cheb(g.pc, int(job["cell"])) <= 2:
			_remove(it)
			_pay_job("Parcel delivered.")
	else:
		var it = _find("trl_datacase")
		if it != null:
			_remove(it)
			_pay_job("Data case uploaded to the client.")

func _pay_job(msg: String) -> void:
	var r: int = job["reward"]
	g.yen += r
	earned += r
	jobs_done += 1
	g.skill_up("stealth", 2)
	g.say("%s  +¥%d." % [msg, r])
	job = {}

func _drop_job_items() -> void:
	for id in ["trl_parcel", "trl_datacase"]:
		var it = _find(id)
		if it != null:
			_remove(it)

func _find(id: String):
	for e in g.inventory_list():
		if e["item"].id() == id:
			return e["item"]
	return null

func _remove(it) -> void:
	if g.wield == it:
		g.wield = null
		return
	for c in g.worn:
		if c.remove(it):
			return

func job_text() -> String:
	if job.is_empty():
		return ""
	var left: int = int(job["deadline"]) - int(g.turn)
	var where: String = job["where"]
	var here: int = g.pc
	var hint := ""
	if job["kind"] == "courier":
		var dz: int = int(job["z"]) - int(g.z_of(here))
		var dx: int = g.lx(int(job["cell"])) - g.lx(here)
		var dy: int = g.ly(int(job["cell"])) - g.ly(here)
		hint = " [%d%s %d%s%s]" % [absi(dx), "E" if dx > 0 else "W", absi(dy), "S" if dy > 0 else "N", ("  %d floors %s" % [absi(dz), "up" if dz > 0 else "down"]) if dz != 0 else ""]
	return "Job: %s - %s%s  ¥%d, %dh%02dm" % [job["kind"], where, hint, job["reward"], left / 60, left % 60]

func _make_courier() -> Dictionary:
	var city = g.city
	var homes: PackedInt32Array = city.homes_t
	if homes.is_empty():
		return {}
	var cell := -1
	for _t in 40:
		var c: int = homes[g.rng.randi() % homes.size()]
		if g.z_of(c) >= 4:
			cell = c
			break
	if cell < 0:
		cell = homes[0]
	var z: int = g.z_of(cell)
	var dist: int = absi(g.lx(cell) - g.lx(g.pc)) + absi(g.ly(cell) - g.ly(g.pc))
	var tw: Dictionary = g.tower_at(cell)
	var name := "the %d-storey tower at (%d,%d)" % [tw.get("h", 0), tw.get("x0", 0), tw.get("y0", 0)]
	return {"kind": "courier", "cell": cell, "z": z, "where": "floor %d of %s" % [z, name],
			"reward": 60 + 14 * z + dist / 4, "deadline": g.turn + int(dist * 1.5) + z * 6 + 90}

func _make_retrieval() -> Dictionary:
	var city = g.city
	var spots: Array = []
	for t in city.tower_info:
		var roof: int = int(t["h"]) * g.s2 + ((int(t["y0"]) + int(t["y1"])) / 2 + 3) * g.size + (int(t["x0"]) + int(t["x1"])) / 2 + 3
		if city.walkable(city.tiles[roof]) and int(t["h"]) >= 14:
			spots.append(roof)
	for c in city.lairs:
		spots.append(c)
	if spots.is_empty():
		return {}
	var cell: int = spots[g.rng.randi() % spots.size()]
	var z: int = g.z_of(cell)
	var where: String = ("a roof %d floors up" % z) if z > 0 else "the sewers"
	g._put(cell, g._new_item("trl_datacase"))
	var dist: int = absi(g.lx(cell) - g.lx(g.pc)) + absi(g.ly(cell) - g.ly(g.pc))
	return {"kind": "retrieval", "cell": cell, "z": z, "where": "recover a data case from %s near (%d,%d)" % [where, g.lx(cell), g.ly(cell)],
			"reward": 180 + 8 * absi(z) + dist / 3, "deadline": g.turn + int(dist * 2.0) + 240}

# ------------------------------------------------------------------ talking
## the menu for talking to agent i: {title, text: [lines], options: [{label, op, arg}]}
func menu_for(i: int) -> Dictionary:
	var who: String = g.nname[i]
	var r: int = int(role[i])
	var m := {"title": g.name_of(i), "text": [], "options": [], "who": i}
	match r:
		VENDOR:
			m["text"] = ["\"Cash only.  Cards are for banks.\""]
			for e in _stock(i):
				m["options"].append({"label": "Buy %s  ¥%d" % [e[1], e[2]], "op": "buy", "arg": e})
		RIPPER:
			var cost: int = 350 if g.z_of(g.sim.pos[i]) < 0 else 700
			m["text"] = ["\"Let me see that stabiliser.\"  Service life: %dh." % (implant_left / 60)]
			m["options"].append({"label": "Service the stabiliser  ¥%d  (resets to 96h)" % cost, "op": "service", "arg": cost})
			m["options"].append({"label": "Trauma patch  ¥40", "op": "buy", "arg": ["trl_medkit", "trauma patch", 40]})
		FIXER:
			if job.is_empty():
				m["text"] = ["\"I have work, if you can climb.\""]
				m["options"].append({"label": "Courier run (a parcel to a flat or office)", "op": "job", "arg": "courier"})
				m["options"].append({"label": "Retrieval (a data case from a roof or the sewers)", "op": "job", "arg": "retrieval"})
			else:
				m["text"] = ["\"Finish what you took first.\""]
		_:
			m["text"] = [_rumor(i)]
	m["options"].append({"label": "Leave", "op": "close", "arg": null})
	return m

func _stock(i: int = 0) -> Array:
	var out: Array = [["trl_ration", "cyber ration bar", 12], ["trl_water_bottle", "bottled water", 8], ["trl_ammo", "9mm ball box (12 rounds)", 22],
			["trl_backpack", "backpack", 120]]
	# each vendor has a few different rounds and gun mods on the shelf
	var ammo_ids: Array = []
	var mod_ids: Array = []
	for k in g.db.defs:
		var tags: Array = g.db.defs[k].get("tags", [])
		if "ammo" in tags and k != "trl_ammo":
			ammo_ids.append(k)
		elif "mod" in tags:
			mod_ids.append(k)
	ammo_ids.sort()
	mod_ids.sort()
	for n in 2:
		var a: String = ammo_ids[(i * 5 + n * 7) % ammo_ids.size()]
		out.append([a, g.db.defs[a]["name"], int(g.db.defs[a]["price"]) * 3 / 2])
	for n in 3:
		var m: String = mod_ids[(i * 3 + n * 5) % mod_ids.size()]
		out.append([m, g.db.defs[m]["name"], int(g.db.defs[m]["price"]) * 3 / 2])
	return out

func _rumor(i: int) -> String:
	var lines: Array = []
	lines.append("\"The Ring Line runs under the roads.  Four stations, a train every few minutes.\"")
	lines.append("\"Kuroda's collectors come after the second missed installment.  Don't miss two.\"")
	if last_tower_clinic >= 0:
		var tw: Dictionary = g.tower_at(last_tower_clinic)
		lines.append("\"A ripperdoc runs a clinic on floor %d of the tower at (%d,%d).  Pricey.\"" % [g.z_of(last_tower_clinic), tw.get("x0", 0), tw.get("y0", 0)])
	lines.append("\"There's a doc in the sewers.  Cheaper.  If the squatters let you through.\"")
	lines.append("\"The big towers have glass bridges between them.  Safer than the street.\"")
	lines.append("\"Locked rooms on the office floors.  Someone's keeping something in there.\"")
	lines.append("\"Fixers pay well for parcels to the high floors.  Elevators help.\"")
	return lines[(i * 7 + g.turn / 90) % lines.size()]

## run option k of a menu; returns the next menu, or {} to close
func choose(m: Dictionary, k: int) -> Dictionary:
	if k < 0 or k >= m["options"].size():
		return m
	var o: Dictionary = m["options"][k]
	match o["op"]:
		"close":
			return {}
		"buy":
			var e: Array = o["arg"]
			if g.yen < int(e[2]):
				g.say("You can't afford that.")
				return m
			var it = g._new_item(e[0])
			if e[0] == "trl_water_bottle":
				it.pockets[0].append(g._new_item("trl_water", 500))
			if it.has_tag("ammo"):
				var am: Dictionary = it.def["ammo"]
				g.pool_add(am["cal"], am["kind"], int(am["rounds"]))
			elif not g.stow(it):
				if e[0] in ["trl_pouch", "trl_backpack"] and g.worn.size() < 4:
					g.worn.append(it)
				else:
					g._put(g.pc, it)
					g.say("No room; it falls at your feet.")
			g.yen -= int(e[2])
			g.say("You buy the %s (¥%d)." % [e[1], e[2]])
			return m
		"service":
			var cost: int = o["arg"]
			if g.yen < cost:
				g.say("You can't afford the service.")
				return m
			g.yen -= cost
			implant_left = 96 * 60
			g.say("The stabiliser hums back to life.  96 hours.")
			m["text"] = ["\"Come back in four days.\""]
			return m
		"job":
			var j: Dictionary = _make_courier() if o["arg"] == "courier" else _make_retrieval()
			if j.is_empty():
				g.say("The fixer shrugs.  Nothing today.")
				return m
			job = j
			if j["kind"] == "courier":
				var p = g._new_item("trl_parcel")
				if not g.stow(p):
					g._put(g.pc, p)
					g.say("No room; the parcel is at your feet.")
			g.say("Job accepted: %s.  ¥%d." % [j["where"], j["reward"]])
			return {}
	return m

func status_text() -> String:
	var d := ""
	if debt > 0:
		var t: int = g.sim.tick
		var due_at: int = DAY * 3 + 8 * 60 if t < DAY * 3 + 8 * 60 else 8 * 60 + ((t - 8 * 60) / (DAY * 3) + 1) * DAY * 3
		var due: int = due_at - t
		d = "Debt ¥%d  (min ¥%d in %dd%02dh%s)" % [debt, min_payment(), due / DAY, (due % DAY) / 60, ", arrears %d" % arrears if arrears > 0 else ""]
	else:
		d = "Debt-free"
	var im := "Implant %dh" % (implant_left / 60) if implant_left > 0 else "IMPLANT DEAD"
	return d + "   " + im

func save() -> Dictionary:
	return {"debt": debt, "arrears": arrears, "paid": paid_cycle, "implant": implant_left, "job": job, "done": jobs_done, "earned": earned, "free": debt_free}

func load_from(d: Dictionary) -> void:
	debt = int(d["debt"])
	arrears = int(d["arrears"])
	paid_cycle = int(d["paid"])
	implant_left = int(d["implant"])
	job = d["job"]
	for k in ["cell", "z", "reward", "deadline"]:
		if job.has(k):
			job[k] = int(job[k])
	jobs_done = int(d["done"])
	earned = int(d["earned"])
	debt_free = bool(d["free"])
