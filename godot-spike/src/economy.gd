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
const COOK := 4          # restaurant keepers: order a meal and eat it on the spot
const GROCER := 5        # grocery keepers: food and water to carry
const DOCTOR := 6        # clinic doctors: treat wounds
const PRIEST := 7        # church: candles, confession, a blessing
const MIKO := 8          # shrine keeper: charms and offerings
const VN = preload("res://src/venues.gd")
const DAY := 1440

var g
var role: PackedByteArray
var venue_of: Dictionary = {}          # agent -> the venue record they keep
var look: Dictionary = {}              # agent -> paper-doll layers for a fixed outfit (doctors, cooks, priests, ripperdocs)
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
	# the keepers of every shop, clinic, church and shrine
	for vi in g.city.venues.size():
		var v: Dictionary = g.city.venues[vi]
		while used < n and (g.fac[order[used]] != g.CIV or role[order[used]] != NONE):
			used += 1
		if used >= n:
			break
		var ki: int = order[used]
		used += 1
		_keeper(ki, v)
	# vendors and fixers among ordinary people (not the ones above)
	for i in range(used, n):
		if g.fac[i] != g.CIV:
			continue
		var r := rng.randf()
		if r < 0.06:
			role[i] = VENDOR
			look[i] = ["backpack", "courier"]
		elif r < 0.11:
			role[i] = FIXER
			look[i] = ["coat", "imp_optics"]

## a venue's keeper stands at the counter, altar or desk for good, in the right clothes
func _keeper(i: int, v: Dictionary) -> void:
	var r := COOK
	var outfit: Array = ["chef"]
	match v["kind"]:
		"grocery":
			r = GROCER
			outfit = ["overalls"]
		"implant":
			r = RIPPER
			outfit = ["suit", "imp_optics", "imp_cortex", "imp_reflex"] if int(v["tier"]) >= 1 else ["jacket_5", "imp_optics", "imp_mantis"]
		"clinic":
			r = DOCTOR
			outfit = ["labcoat"]
		"church":
			r = PRIEST
			outfit = ["priest"]
		"temple":
			r = MIKO
			outfit = ["kannushi"]
	_station(i, int(v["keeper"]), r, "")
	g.fac[i] = g.CIV
	g.gunc[i] = 0
	g.hpmax[i] = 40
	g.hpn[i] = 40
	venue_of[i] = v
	look[i] = outfit

## put agent i at a cell for good
func _station(i: int, cell: int, r: int, name: String) -> void:
	role[i] = r
	if r == RIPPER:
		look[i] = ["labcoat", "imp_optics", "imp_cortex"]
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
		COOK: return "cook"
		GROCER: return "grocer"
		DOCTOR: return "doctor"
		PRIEST: return "priest"
		MIKO: return "shrine keeper"
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
		g._raw_hurt(2, "chest")
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
	g.skill_up("streetwise" if job.get("kind", "") == "courier" else "research", 2)
	g.skill_up("negotiation", 2)
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
				m["options"].append(_buy_opt(i, e))
		RIPPER:
			var rv: Dictionary = venue_of.get(i, {})
			var cheap: bool = g.z_of(g.sim.pos[i]) < 0 or (not rv.is_empty() and int(rv["tier"]) == 0)
			if not rv.is_empty():
				m["title"] = "%s - %s" % [who, rv["name"]]
			var cost: int = 350 if cheap else 700
			m["text"] = ["\"Let me see that stabiliser.\"  Service life: %dh." % (implant_left / 60)]
			m["options"].append({"label": "Service the stabiliser  ¥%d  (resets to 96h)" % cost, "op": "service", "arg": cost})
			m["options"].append(_buy_opt(i, ["trl_medkit", "trauma patch", 40], "Trauma patch"))
			var wrecked := 0
			for l in g.BODY.LIMBS:
				if int(g.body.hp[l]) < int(g.body.mx[l]):
					wrecked += 1
			if wrecked > 0 or g.armor_status()["left"] < g.armor_status()["max"]:
				var mc: int = 90 + 70 * wrecked
				m["options"].append({"label": "Rebuild: every limb to 70%%, replate implant armor  ¥%d" % mc, "op": "mend", "arg": mc})
			var under: bool = cheap
			for d in g.IMP.ALL:
				if d["live"] and not g.implants.get(d["id"], false):
					var pr: int = g.IMP.price(d["id"], under)
					m["options"].append({"label": "%s  ¥%d  (%s)" % [d["name"], pr, d["desc"]], "op": "implant", "arg": [d["id"], pr]})
		COOK:
			var v: Dictionary = venue_of.get(i, {})
			var st: Dictionary = VN.restaurant_style(String(v.get("style", "ramen")))
			m["title"] = "%s - %s" % [who, v.get("name", "restaurant")]
			m["text"] = [st["greet"], "(%s.  A meal heals and is eaten here.)" % st["name"]]
			for fid in st["menu"]:
				var d: Dictionary = g.db.defs["trl_food_" + fid]
				var pr: int = haggle(i, int(d["price"]) * (2 if int(v.get("tier", 1)) >= 1 else 1) + 4)
				m["options"].append({"label": "%s  ¥%d  (heals %d)" % [d["name"], pr, int(d["food"]["hp"])], "op": "dine", "arg": ["trl_food_" + fid, d["name"], pr]})
		GROCER:
			var gv: Dictionary = venue_of.get(i, {})
			m["title"] = "%s - %s" % [who, gv.get("name", "grocery")]
			m["text"] = ["\"Take a basket.  Cash at the counter.\""]
			for e in _grocery_stock(i):
				m["options"].append(_buy_opt(i, e))
		DOCTOR:
			var dv: Dictionary = venue_of.get(i, {})
			m["title"] = "%s - %s" % [who, dv.get("name", "clinic")]
			var missing: int = g.hp_max - g.hp
			var wrecked := 0
			var hurt := 0
			for l in g.BODY.LIMBS:
				if int(g.body.hp[l]) <= 0:
					wrecked += 1
				if int(g.body.hp[l]) < int(g.body.mx[l]):
					hurt += 1
			m["text"] = ["\"Let me look at you.\"", "You are at %d of %d, with %d hurt limb%s." % [g.hp, g.hp_max, hurt, "" if hurt == 1 else "s"]]
			if missing > 0 or hurt > 0:
				var c1: int = 20 + missing * 2 + hurt * 15
				m["options"].append({"label": "Treat my wounds (health full, limbs half mended)  ¥%d" % c1, "op": "treat", "arg": [c1, 0.5]})
				var c2: int = 40 + missing * 3 + hurt * 30 + wrecked * 60
				m["options"].append({"label": "Full recovery (health and every limb)  ¥%d" % c2, "op": "treat", "arg": [c2, 1.0]})
			else:
				m["text"].append("\"Nothing wrong with you that I can see.\"")
			m["options"].append(_buy_opt(i, ["trl_medkit", "trauma patch", 35], "Trauma patch"))
		PRIEST:
			m["title"] = "%s - %s" % [who, venue_of.get(i, {}).get("name", "church")]
			m["text"] = ["\"Peace be with you.  Come in, stay as long as you need.\""]
			m["options"].append({"label": "Light a candle  ¥20  (heat -8)", "op": "pray", "arg": [20, 0, 8, 0, "You light a candle.  The flame steadies you."]})
			m["options"].append({"label": "Confession  ¥150  (heat cleared)", "op": "pray", "arg": [150, 0, 100, 0, "You speak for a long time.  The priest absolves you.  Your heat is gone."]})
			m["options"].append({"label": "Donation for the roof  ¥100  (a blessing, health +10)", "op": "pray", "arg": [100, 10, 0, 480, "The priest makes a cross over you.  You feel lighter and luckier."]})
			for e in [["trl_faith_candle", "church candle", 20], ["trl_faith_icon", "small icon", 120], ["trl_faith_gospel", "pocket gospel", 60]]:
				m["options"].append(_buy_opt(i, e))
		MIKO:
			m["title"] = "%s - %s" % [who, venue_of.get(i, {}).get("name", "shrine")]
			m["text"] = ["\"Welcome.  Clap twice, bow, and ask quietly.\""]
			m["options"].append({"label": "Offering at the saisen box  ¥50  (a blessing, health +8)", "op": "pray", "arg": [50, 8, 0, 360, "You throw the coin, clap twice and bow.  The air feels clean."]})
			for e in [["trl_faith_omamori", "omamori charm", 150], ["trl_faith_ofuda", "ofuda paper ward", 90], ["trl_faith_ema", "ema plaque", 50]]:
				m["options"].append(_buy_opt(i, e))
		FIXER:
			if job.is_empty():
				m["text"] = ["\"I have work, if you can climb.\""]
				m["options"].append({"label": "Courier run (a parcel to a flat or office)", "op": "job", "arg": "courier"})
				m["options"].append({"label": "Retrieval (a data case from a roof or the sewers)", "op": "job", "arg": "retrieval"})
			else:
				m["text"] = ["\"Finish what you took first.\""]
		_:
			m["text"] = [_rumor(i)]
			for k in mini(3, g.lvl("research") / 3):
				m["text"].append(_rumor(i, 1 + k))
			g.skill_up("research", 1)
	m["options"].append({"label": "Leave", "op": "close", "arg": null})
	return m

## the price a seller asks you: Negotiation takes 1.5% a level off, and Streetwise (low-district stalls) or Etiquette (upscale shops) another 2% a level; never more than 30% off
func haggle(i: int, price: int) -> int:
	var v: Dictionary = venue_of.get(i, {})
	var upscale: bool = not v.is_empty() and int(v.get("tier", 0)) >= 1 and g.z_of(g.sim.pos[i]) >= 0
	var social: int = g.lvl("etiquette") if upscale else g.lvl("streetwise")
	var off: float = minf(0.30, 0.015 * float(g.lvl("negotiation")) + 0.02 * float(social))
	return maxi(1, int(round(float(price) * (1.0 - off))))

func _buy_opt(i: int, e: Array, nm: String = "") -> Dictionary:
	var ee: Array = [e[0], e[1], haggle(i, int(e[2]))]
	var label: String = ("Buy %s" % e[1]) if nm == "" else nm
	return {"label": "%s  ¥%d" % [label, ee[2]], "op": "buy", "arg": ee}

func _stock(i: int = 0) -> Array:
	var out: Array = [["trl_ration", "cyber ration bar", 12], ["trl_water_bottle", "bottled water", 8], ["trl_ammo", "9mm ball box (12 rounds)", 22]]
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
	var melee_ids: Array = g.melee_all
	# three kinds of stall: guns and mods, blades, a bit of everything
	var kind: int = i % 3
	if kind != 1:
		out.append(["trl_backpack", "backpack", 120])
	if i % 2 == 0:
		out.append(["trl_vest", "ballistic vest", 500])
		out.append(["trl_helmet", "ballistic helmet", 350])
	else:
		out.append(["trl_bracers", "composite arm guards", 300])
		out.append(["trl_greaves", "shin guards", 300])
	for n in (2 if kind != 1 else 0):
		var a: String = ammo_ids[(i * 5 + n * 7) % ammo_ids.size()]
		out.append([a, g.db.defs[a]["name"], int(g.db.defs[a]["price"]) * 3 / 2])
	if kind == 0:
		for n in 3:
			var m: String = mod_ids[(i * 3 + n * 5) % mod_ids.size()]
			out.append([m, g.db.defs[m]["name"], int(g.db.defs[m]["price"]) * 3 / 2])
	else:
		var count: int = 6 if kind == 1 else 3
		for n in count:
			var w: String = melee_ids[(i * 5 + n * 3) % melee_ids.size()]
			var forged: bool = n % 2 == 1 or kind == 1 and n >= 3
			var id: String = w + ("_f" if forged else "")
			out.append([id, g.db.defs[id]["name"], int(g.db.defs[id]["price"]) * 3 / 2])
	out.append(["trl_kit_repair", "field repair kit", 110])
	if kind == 2:
		for eid in ["trl_eng_mini", "trl_eng_city", "trl_eng_sport"]:
			out.append([eid, g.db.defs[eid]["name"], int(g.db.defs[eid]["price"]) * 3 / 2])
	return out

func _grocery_stock(i: int) -> Array:
	var ids := ["black_bread", "tushonka", "herring", "natto", "mochi", "apple", "orange", "banana", "milk", "protein", "glucose", "hydrogel", "chocolate", "cheese", "onigiri", "cup_ramen"]
	var out: Array = [["trl_water_bottle", "bottled water", 8], ["trl_ration", "cyber ration bar", 12]]
	for k in 9:
		var fid: String = ids[(i * 3 + k * 5) % ids.size()]
		var d: Dictionary = g.db.defs["trl_food_" + fid]
		var e: Array = ["trl_food_" + fid, d["name"], int(d["price"])]
		if not out.any(func(x): return x[0] == e[0]):
			out.append(e)
	return out

func _rumor(i: int, shift: int = 0) -> String:
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
	return lines[(i * 7 + g.turn / 90 + shift * 3) % lines.size()]

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
			_haggle_xp(m, int(e[2]))
			return m
		"dine":
			var de: Array = o["arg"]
			if g.yen < int(de[2]):
				g.say("You can't afford that.")
				return m
			g.yen -= int(de[2])
			var meal = g._new_item(de[0])
			g.eat_now(meal)
			g.say("You order the %s (¥%d) and eat it at the counter." % [de[1], de[2]])
			_haggle_xp(m, int(de[2]))
			return m
		"treat":
			var tr: Array = o["arg"]
			if g.yen < int(tr[0]):
				g.say("You can't afford the treatment.")
				return m
			g.yen -= int(tr[0])
			g.hp = g.hp_max
			g.body.mend_to(float(tr[1]))
			g.say("The doctor works for an hour.  You feel much better.")
			m["text"] = ["\"Rest now.  Avoid being shot.\""]
			m["options"] = [{"label": "Leave", "op": "close", "arg": null}]
			return m
		"pray":
			var pa: Array = o["arg"]
			if g.yen < int(pa[0]):
				g.say("You can't afford the offering.")
				return m
			g.yen -= int(pa[0])
			if int(pa[1]) > 0:
				g.hp = mini(g.hp_max, g.hp + int(pa[1]))
			if int(pa[2]) > 0:
				g.heat = maxi(0, g.heat - int(pa[2]))
			if int(pa[3]) > 0:
				g.bless_left = maxi(g.bless_left, int(pa[3]))
			g.say(String(pa[4]))
			return m
		"implant":
			var im: Array = o["arg"]
			if g.yen < int(im[1]):
				g.say("You can't afford the surgery.")
				return m
			g.yen -= int(im[1])
			g.implants[im[0]] = true
			if im[0] == "jets":
				g.fuel = g.FUEL_MAX
			g.say("The surgery takes an hour.  You wake with new hardware: %s." % g.IMP.get_def(im[0]).get("name", im[0]))
			m["text"] = ["\"Don't test it indoors.\""]
			m["options"] = [{"label": "Leave", "op": "close", "arg": null}]
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
		"mend":
			var mcost: int = o["arg"]
			if g.yen < mcost:
				g.say("You can't afford the work.")
				return m
			g.yen -= mcost
			g.body.mend_to(0.7)
			g.imp_dur.clear()
			g.hp = g.hp_max
			g.say("Hours under the lamp.  Limbs rebuilt, implant plating replaced.")
			m["text"] = ["\"Good as used.\""]
			m["options"] = [{"label": "Leave", "op": "close", "arg": null}]
			return m
		"job":
			var j: Dictionary = _make_courier() if o["arg"] == "courier" else _make_retrieval()
			if j.is_empty():
				g.say("The fixer shrugs.  Nothing today.")
				return m
			j["reward"] = int(j["reward"]) * (100 + 2 * g.lvl("negotiation")) / 100
			job = j
			if j["kind"] == "courier":
				var p = g._new_item("trl_parcel")
				if not g.stow(p):
					g._put(g.pc, p)
					g.say("No room; the parcel is at your feet.")
			g.say("Job accepted: %s.  ¥%d." % [j["where"], j["reward"]])
			return {}
	return m

## buying teaches Negotiation, and the social skill of the seller's side of town
func _haggle_xp(m: Dictionary, spent: int) -> void:
	var i: int = int(m.get("who", -1))
	if i < 0:
		return
	var v: Dictionary = venue_of.get(i, {})
	var upscale: bool = not v.is_empty() and int(v.get("tier", 0)) >= 1 and g.z_of(g.sim.pos[i]) >= 0
	g.skill_up("negotiation", 1 + spent / 120)
	g.skill_up("etiquette" if upscale else "streetwise", 1 + spent / 150)

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
