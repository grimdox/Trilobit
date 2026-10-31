extends RefCounted
## The pressure systems and the people who deal with them.
##   (no debt: loans and debts arrive with the banking update)
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
const HOSTAGE := 9       # a bound hostage on a mission site (missions.gd): talk to cut them loose
const VN = preload("res://src/venues.gd")
const CLK = preload("res://src/clock.gd")
const DAY := CLK.DAY

var g
var role: PackedByteArray
var venue_of: Dictionary = {}          # agent -> the venue record they keep
var look: Dictionary = {}              # agent -> paper-doll layers for a fixed outfit (doctors, cooks, priests, ripperdocs)
var job: Dictionary = {}
var jobs_done: int = 0
var earned: int = 0
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
		g.set_enemy(i)
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
## what the implant seller i offers: a cyberdoc office (or a lone ripperdoc) a handful of Basic and Improved implants, a store its half of the body, by the district's wealth
func ripper_stock(i: int) -> Array:
	var v: Dictionary = venue_of.get(i, {})
	var kind: String = String(v.get("kind", "cyberdoc"))
	var cell: int = g.sim.pos[i]
	var wealth: int = 0 if g.z_of(cell) < 0 else g.district_of(cell)
	if v.is_empty() and g.z_of(cell) > 0:
		wealth = 2                                           # the tower clinic
	return g.IMP.stock(kind, String(v.get("style", "")), wealth, cell)

## yen to repair every fitted implant: a quarter of its price at 100% wear, in proportion to the wear
func repair_cost() -> int:
	var t := 0
	for id in g.implants:
		if not g.implants[id]:
			continue
		var d: Dictionary = g.IMP.get_def(String(id))
		if not d.is_empty():
			t += g.IMP.repair_cost(d, int(g.imp_dur.get(id, g.IMP.dur(d))))
	return t

func _keeper(i: int, v: Dictionary) -> void:
	var r := COOK
	var outfit: Array = ["chef"]
	match v["kind"]:
		"grocery":
			r = GROCER
			outfit = ["overalls"]
		"implant", "cyberdoc":
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
		HOSTAGE: return "hostage"
	return ""

# ------------------------------------------------------------------ the clocks
func step() -> void:
	_job_step()

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
	g.inv.remove(it)

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
	return "Job: %s - %s%s  ¥%d, %s" % [job["kind"], where, hint, job["reward"], CLK.span_text(maxi(0, left))]

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
			m["text"] = ["\"What are we fitting today?\""]
			m["options"].append(_buy_opt(i, ["trl_medkit", "trauma patch", 40], "Trauma patch"))
			var wrecked := 0
			for l in g.BODY.LIMBS:
				if int(g.body.hp[l]) < int(g.body.mx[l]):
					wrecked += 1
			if wrecked > 0:
				var mc: int = 90 + 70 * wrecked
				m["options"].append({"label": "Rebuild: every limb to 70%%  ¥%d" % mc, "op": "mend", "arg": mc})
			var under: bool = cheap
			for iid in ripper_stock(i):
				var d: Dictionary = g.IMP.get_def(String(iid))
				if not g.implants.get(iid, false) and not g.carries_id("trl_imp_" + String(iid)):
					var pr: int = g.IMP.price(iid, under)
					m["options"].append({"label": "%s  ¥%d  (%s)" % [d["name"], pr, d["desc"]], "op": "implant", "arg": [iid, pr]})
			var rep: int = repair_cost()
			if rep > 0:
				m["options"].append({"label": "Repair worn implants  ¥%d" % rep, "op": "repair", "arg": rep})
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
			var missing: int = (g.body_missing() + 2) / 3        # the bill is by the old 60-point scale: a third of the limb points
			var wrecked := 0
			var hurt := 0
			for l in g.BODY.LIMBS:
				if int(g.body.hp[l]) <= 0:
					wrecked += 1
				if int(g.body.hp[l]) < int(g.body.mx[l]):
					hurt += 1
			m["text"] = ["\"Let me look at you.\"", "You are at %d of %d, with %d hurt limb%s." % [g.body.total(), g.body.mx.values().reduce(func(a, b): return a + b), hurt, "" if hurt == 1 else "s"]]
			if missing > 0 or hurt > 0:
				var c1: int = 20 + missing * 2 + hurt * 15
				m["options"].append({"label": "Treat my wounds (every limb half mended)  ¥%d" % c1, "op": "treat", "arg": [c1, 0.5]})
				var c2: int = 40 + missing * 3 + hurt * 30 + wrecked * 60
				m["options"].append({"label": "Full recovery (every limb whole)  ¥%d" % c2, "op": "treat", "arg": [c2, 1.0]})
			else:
				m["text"].append("\"Nothing wrong with you that I can see.\"")
			m["options"].append(_buy_opt(i, ["trl_medkit", "trauma patch", 35], "Trauma patch"))
		PRIEST:
			m["title"] = "%s - %s" % [who, venue_of.get(i, {}).get("name", "church")]
			m["text"] = ["\"Peace be with you.  Come in, stay as long as you need.\""]
			m["options"].append({"label": "Donation for the roof  ¥100  (a blessing, health +10)", "op": "pray", "arg": [100, 10, 480, "The priest makes a cross over you.  You feel lighter and luckier."]})
			for e in [["trl_faith_candle", "church candle", 20], ["trl_faith_icon", "small icon", 120], ["trl_faith_gospel", "pocket gospel", 60]]:
				m["options"].append(_buy_opt(i, e))
		MIKO:
			m["title"] = "%s - %s" % [who, venue_of.get(i, {}).get("name", "shrine")]
			m["text"] = ["\"Welcome.  Clap twice, bow, and ask quietly.\""]
			m["options"].append({"label": "Offering at the saisen box  ¥50  (a blessing, health +8)", "op": "pray", "arg": [50, 8, 360, "You throw the coin, clap twice and bow.  The air feels clean."]})
			for e in [["trl_faith_omamori", "omamori charm", 150], ["trl_faith_ofuda", "ofuda paper ward", 90], ["trl_faith_ema", "ema plaque", 50]]:
				m["options"].append(_buy_opt(i, e))
		HOSTAGE:
			m["title"] = "%s - hostage" % who
			if g.mission.get("freed", false):
				m["text"] = ["\"I'm with you.  Don't stop.\""]
			else:
				m["text"] = ["Bound, gagged at the mouth, and very awake.  \"Hurry.\""]
				m["options"].append({"label": "Cut the bonds", "op": "mission_free", "arg": null})
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
		out.append(["trl_fanny", "fanny pack", 25])
		out.append(["trl_holster_belt", "holster belt", 90])
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
	# tiered armor (Street +1 to Nanofab +5): the better the district, the better the pieces on offer
	var vt: Dictionary = venue_of.get(i, {})
	var top: int = [2, 4, 5][clampi(int(vt.get("tier", 0)), 0, 2)]
	for n in 3:
		var slot: String = ["chest", "head", "arms", "legs"][(i + n) % 4]
		var tier: int = clampi(top - ((i / 4 + n * 2) % 3), 1, top)
		var aid: String = "trl_armor_%s_%d" % [slot, tier]
		if g.db.defs.has(aid) and not out.any(func(x): return x[0] == aid):
			out.append([aid, g.db.defs[aid]["name"], int(g.db.defs[aid]["price"])])
	out.append(["trl_heal_bandage", "bandage", 12])
	out.append(["trl_heal_gel", "antiseptic gel", 25])
	if i % 2 == 0:
		out.append(["trl_heal_stim", "recovery stim", 55])
	else:
		out.append(["trl_heal_suture", "suture kit", 90])
	out.append(["trl_kit_repair", "field repair kit", 110])
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
	if last_tower_clinic >= 0:
		var tw: Dictionary = g.tower_at(last_tower_clinic)
		lines.append("\"A ripperdoc runs a clinic on floor %d of the tower at (%d,%d).  Pricey.\"" % [g.z_of(last_tower_clinic), tw.get("x0", 0), tw.get("y0", 0)])
	lines.append("\"There's a doc in the sewers.  Cheaper.  If the squatters let you through.\"")
	lines.append("\"The big towers have glass bridges between them.  Safer than the street.\"")
	lines.append("\"Locked rooms on the office floors.  Someone's keeping something in there.\"")
	lines.append("\"Fixers pay well for parcels to the high floors.  Elevators help.\"")
	return lines[(i * 7 + g.turn / 90 + shift * 3) % lines.size()]

## run option k of a menu; returns the next menu, or {} to close
## the menu at a government implant charging post: what a charge costs, in the four parts power.gd defines
func charger_menu(cell: int) -> Dictionary:
	var m := {"title": "Government implant charging post", "text": [], "options": [], "charger": cell}
	var L: Dictionary = g.PW.loadout(g.implants)
	if int(L["count"]) == 0:
		m["text"] = ["The cradle finds nothing of yours to charge.", "Fully human: no implants, no draw, no tax.  Move along."]
		m["options"].append({"label": "Leave", "op": "close", "arg": null})
		return m
	var room: float = g.power_cap() - g.power_left()
	var q1: Dictionary = g.charge_quote(cell, 1.0)
	m["text"] = [
		"Store: %d of %d kJ (about %d h of power left).  Your rig draws %.1f kJ/h." % [int(g.power_left()), int(g.power_cap()), int(g.power_hours()), float(L["draw"])],
		"A visit costs a quality fee of %d (tier points %d x %d), implant tax %.1f%% of your hardware's %d, plus per kJ: power %.2f and power tax %.2f." % [
			int(q1["fee"]), int(L["quality"]), g.PW.QUALITY_FEE, float(q1["tax_pct"]), int(L["value"]), g.PW.power_rate(g.district_of(cell)), g.PW.power_tax_rate()]]
	if room < 1.0:
		m["text"].append("Your cells are full.")
	else:
		var d24: float = minf(room, float(L["draw"]) * 24.0)
		var d72: float = room
		var aff: float = minf(room, g.PW.affordable_kj(g.implants, g.district_of(cell), g.yen))
		for e in [["Top up to full", d72], ["Charge 24 hours' worth", d24], ["Charge what I can afford", aff]]:
			var kj: float = float(e[1])
			if kj < 1.0 or (e[0] != "Top up to full" and kj >= d72 - 0.5) or (e[0] == "Charge what I can afford" and absf(kj - d24) < 0.5):
				continue
			var q: Dictionary = g.charge_quote(cell, kj)
			m["options"].append({"label": "%s  %d kJ  ¥%d  (about %d h)" % [e[0], int(kj), int(q["total"]), int(g.PW.hours_left(g.implants, kj))], "op": "charge", "arg": [cell, kj]})
	m["options"].append({"label": "Leave", "op": "close", "arg": null})
	return m

## the menu at a vehicle charging bank: one entry per vehicle in reach, to full or as far as the yen goes
func ev_menu(bank: int) -> Dictionary:
	var m := {"title": "Vehicle charging bank", "text": [], "options": [], "bank": bank}
	var list: Array = g.vehicles_at_bank(bank)
	if list.is_empty():
		m["text"] = ["No vehicle is parked within reach of the cables.", "Park a car beside the bank (within two tiles) and come back."]
		m["options"].append({"label": "Leave", "op": "close", "arg": null})
		return m
	var d: int = g.district_of(bank)
	m["text"] = ["Power ¥%.2f per kJ plus ¥%.2f power tax; a pack holds %d kJ.  You have ¥%d." % [g.PW.power_rate(d), g.PW.power_tax_rate(), int(g.PW.CAR_PACK_KJ), g.yen]]
	for vi in list:
		var v: Dictionary = g.vehicles[vi]
		var name: String = String(g.vs.KINDS[v["kind"]]["name"]).capitalize() + (" (you are in it)" if vi == g.in_vehicle else "")
		var need: int = 100 - int(v["charge"])
		if need <= 0:
			m["text"].append("%s: battery full." % name)
			continue
		m["options"].append({"label": "%s, battery %d%%: charge to full, ¥%d" % [name, int(v["charge"]), g.PW.vehicle_quote(need, d)], "op": "ev_charge", "arg": [bank, vi, need]})
		var aff: int = g.PW.vehicle_affordable_pct(g.yen, d)
		if aff > 0 and aff < need:
			m["options"].append({"label": "%s: charge what I can afford (+%d%%, ¥%d)" % [name, aff, g.PW.vehicle_quote(aff, d)], "op": "ev_charge", "arg": [bank, vi, aff]})
	m["options"].append({"label": "Leave", "op": "close", "arg": null})
	return m

func choose(m: Dictionary, k: int) -> Dictionary:
	if k < 0 or k >= m["options"].size():
		return m
	var o: Dictionary = m["options"][k]
	match o["op"]:
		"close":
			return {}
		"charge":
			var ca: Array = o["arg"]
			g.recharge(int(ca[0]), float(ca[1]))
			return charger_menu(int(ca[0]))
		"ev_charge":
			var ea: Array = o["arg"]
			g.recharge_vehicle(int(ea[0]), int(ea[1]), int(ea[2]))
			return ev_menu(int(ea[0]))
		"mission_free":
			g.MS.free_hostage(g)
			return {}
		"buy":
			var e: Array = o["arg"]
			if g.yen < int(e[2]):
				g.say("You can't afford that.")
				return m
			var it = g._new_item(e[0])
			if e[0] == "trl_water_bottle":
				it.fill = 500
			if it.has_tag("ammo"):
				var am: Dictionary = it.def["ammo"]
				g.pool_add(am["cal"], am["kind"], int(am["rounds"]))
			elif not g.stow(it):
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
			var bf: int = g.food_left()
			var bd: int = g.drink_left()
			g.eat_now(meal)
			g.say("You order the %s (¥%d) and eat it at the counter.  (%s)" % [de[1], de[2], g._eat_report(meal, bf, bd)])
			_haggle_xp(m, int(de[2]))
			return m
		"treat":
			var tr: Array = o["arg"]
			if g.yen < int(tr[0]):
				g.say("You can't afford the treatment.")
				return m
			g.yen -= int(tr[0])
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
				g.heal_body(int(pa[1]))
			if int(pa[2]) > 0:
				g.bless_left = maxi(g.bless_left, int(pa[2]) * CLK.MIN)       # the data gives minutes
			g.say(String(pa[3]))
			return m
		"implant":
			var im: Array = o["arg"]
			if g.yen < int(im[1]):
				g.say("You can't afford the implant.")
				return m
			var imp_item = g._new_item("trl_imp_" + String(im[0]))
			if not g.stow(imp_item):
				g.say("No room in your pockets for the %s.  Make a tile free first." % imp_item.def["name"])
				return m
			g.yen -= int(im[1])
			g.say("You buy the %s (¥%d).  Fit it from the Implants screen." % [imp_item.def["name"], im[1]])
			m["text"] = ["\"It is yours to fit.  Don't test it indoors.\""]
			m["options"] = [{"label": "Leave", "op": "close", "arg": null}]
			return m
		"mend":
			var mcost: int = o["arg"]
			if g.yen < mcost:
				g.say("You can't afford the work.")
				return m
			g.yen -= mcost
			g.body.mend_to(0.7)
			g.say("Hours under the lamp.  Limbs rebuilt.")
			m["text"] = ["\"Good as used.\""]
			m["options"] = [{"label": "Leave", "op": "close", "arg": null}]
			return m
		"repair":
			var rcost: int = repair_cost()
			if rcost <= 0:
				g.say("Nothing of yours needs repairing.")
				return m
			if g.yen < rcost:
				g.say("You can't afford the repairs (¥%d)." % rcost)
				return m
			g.yen -= rcost
			g.imp_dur.clear()
			g.say("The implants are stripped, re-seated and tested (¥%d)." % rcost)
			m["text"] = ["\"Good as new.  Almost.\""]
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

## the line under the clock: nothing yet (loans and debts arrive with the banking update)
func status_text() -> String:
	return ""

func save() -> Dictionary:
	return {"tv": CLK.SAVE_VERSION, "job": job, "done": jobs_done, "earned": earned}

func load_from(d: Dictionary) -> void:
	job = d["job"]
	for k in ["cell", "z", "reward", "deadline"]:
		if job.has(k):
			job[k] = int(job[k])
	jobs_done = int(d["done"])
	earned = int(d["earned"])
