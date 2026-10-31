extends RefCounted
## Temp Agency work: labor-related contracts that use social and labor skills instead of weapons.  A Temp Agency's terminal posts five jobs, each at a company's high-rise:
## the player goes in through a portal (the same machinery as the Labor Center contracts), finds the job's work stations on the floor, and tries each one in turn.
## A station is one skill check: 2d10 + the better of its skills + half the other, against the station's difficulty (a natural 2 always fails, 19 or 20 always works).
## Every station done and the job is done; leave by the exit portal and the agency pays, less 10% for every failed attempt (never under half).
##
## The first version resolves each station with the roll above.  The planned minigames (see PLAN.md, "Temp Agency") will replace the roll at a station with a small
## game whose result feeds the same check: `MINIGAME` says which one belongs where.
const SK = preload("res://src/skills.gd")

const TAG := "WORK"
const FAIL_PENALTY := 0.10
const MIN_PAY := 0.5

## white collar: carpet, desks, cubicles, copiers.  blue collar: concrete, racks, pallets, conveyors.
const JOBS := [
	{"id": "copier", "name": "Fix the Copy Machine", "collar": "white", "base": 180, "rooms": 6,
		"line": "The department's only copier is jammed an hour before a deadline.",
		"how": "Clear the jam and test the machine, and keep the department head happy while you do it.",
		"stations": [
			{"label": "Clear the paper jam", "skills": ["engineering"], "dc": 12, "ok": "You pry the sheet free and the rollers catch.", "fail": "The jam tears and takes the rest of the stack with it.", "mini": "none"},
			{"label": "Restock and test the toner", "skills": ["manual"], "dc": 10, "ok": "The test page comes out clean.", "fail": "Toner everywhere.  You wipe it up and try again.", "mini": "none"},
			{"label": "Calm the department head", "skills": ["etiquette"], "dc": 11, "ok": "A few polite words and the head of department goes back to their desk.", "fail": "They are not soothed.  They want it done now.", "mini": "none"}]},
	{"id": "budget", "name": "Last-Minute Budget Proposal", "collar": "white", "base": 260, "rooms": 7,
		"line": "A budget proposal is due at the end of the day and nobody has started it.",
		"how": "Pull the numbers from the old reports, write the proposal up, and talk the department heads into signing it.",
		"stations": [
			{"label": "Pull the figures from the old reports", "skills": ["research"], "dc": 12, "ok": "Five reports, one set of matching numbers.", "fail": "The figures do not add up.  You start again.", "mini": "research_match"},
			{"label": "Write up the proposal", "skills": ["artisan"], "dc": 11, "ok": "The proposal reads cleanly and fits on one page.", "fail": "The draft is a mess.  You rewrite the opening.", "mini": "slide_builder"},
			{"label": "Get the department heads to sign off", "skills": ["negotiation", "etiquette"], "dc": 13, "ok": "Three signatures, with only a little grumbling.", "fail": "They want changes, and they want them now.", "mini": "none"}]},
	{"id": "stockroom", "name": "Warehouse Stock Count", "collar": "blue", "base": 200, "rooms": 6,
		"line": "A distributor's stock room has been delivered into the wrong places.",
		"how": "Move the pallets to the right racks, reconcile the manifest with the shelves, and stay on the right side of the foreman.",
		"stations": [
			{"label": "Sort the pallets onto the right racks", "skills": ["manual"], "dc": 11, "ok": "Every colour of crate ends up on its own rack.", "fail": "Wrong rack.  You lift them down and start again.", "mini": "warehouse_sort"},
			{"label": "Reconcile the manifest with the shelf count", "skills": ["research"], "dc": 12, "ok": "The count matches the manifest, for once.", "fail": "Forty crates are missing on paper.  You count again.", "mini": "none"},
			{"label": "Keep the foreman off your back", "skills": ["streetwise", "negotiation"], "dc": 11, "ok": "The foreman grunts and leaves you to it.", "fail": "The foreman is not happy with the pace.", "mini": "none"}]},
	{"id": "presentation", "name": "Client Presentation Prep", "collar": "white", "base": 280, "rooms": 7,
		"line": "A client arrives in the afternoon and the deck is not finished.",
		"how": "Build the slides, get the room's equipment working, and brief the account manager on what they say.",
		"stations": [
			{"label": "Build the client's slide deck", "skills": ["artisan"], "dc": 12, "ok": "The deck is clean: a title, three points and a chart.", "fail": "The slides will not line up.  You rebuild the master.", "mini": "slide_builder"},
			{"label": "Make the projector and the room work", "skills": ["engineering"], "dc": 11, "ok": "The picture comes up on the first try.", "fail": "No signal.  You check the cables again.", "mini": "none"},
			{"label": "Brief the account manager", "skills": ["etiquette", "negotiation"], "dc": 12, "ok": "The account manager leaves the briefing knowing what to say.", "fail": "They have questions, and they do not like the answers.", "mini": "none"}]},
	{"id": "packing_line", "name": "Fix the Packing Line", "collar": "blue", "base": 240, "rooms": 6,
		"line": "The packing line has stopped, and the day's orders are stacking up behind it.",
		"how": "Clear the jam, repair the belt, and convince the shift lead to let you stop the line to do it.",
		"stations": [
			{"label": "Clear the jam on the conveyor", "skills": ["manual"], "dc": 11, "ok": "You haul the crate clear and the belt moves.", "fail": "The crate will not budge.  You get a better grip.", "mini": "none"},
			{"label": "Repair the sorting belt", "skills": ["engineering"], "dc": 13, "ok": "The belt runs smoothly again.", "fail": "A spring flies out.  You hunt for it and try again.", "mini": "none"},
			{"label": "Persuade the shift lead to stop the line", "skills": ["negotiation", "streetwise"], "dc": 12, "ok": "The shift lead throws the stop and lets you work.", "fail": "The lead refuses until you give them a reason.", "mini": "none"}]},
]

## the company names on the board
const COMPANIES := ["Meridian Logistics", "Northgate Holdings", "Tsubame Trading", "Clearwater Group", "Hokkai Freight", "Kuroda & Partners", "Sakhalin Mutual", "Blue Heron Supply", "Ironbridge Systems"]
const MANAGERS := ["Ms. Aoki", "Mr. Brandt", "Ms. Okafor", "Mr. Tanaka", "Ms. Reyes", "Mr. Sato", "Ms. Volkov", "Mr. Park"]

## the furniture of each kind of floor (tile names of citygen's EXTRA list)
const WHITE_ROOMS := {
	"bullpen": ["desk_workstation", "office_chair", "cubicle_divider", "desk_workstation", "filing_cabinet"],
	"meeting": ["meeting_table", "whiteboard", "office_chair", "meeting_table", "water_cooler"],
	"supply": ["copier", "filing_cabinet", "office_shelf", "water_cooler", "copier", "server_rack"],
	"executive": ["desk_executive", "bookshelf", "office_chair", "filing_cabinet", "coffee_machine"],
}
const BLUE_ROOMS := {
	"racks": ["pallet_rack", "pallet_stack", "crate_stack", "pallet_rack", "parts_bin"],
	"line": ["conveyor", "workbench", "parts_bin", "crate_stack", "conveyor"],
	"bench": ["workbench", "tool_chest", "parts_bin", "barrel", "scrap_pile"],
	"dock": ["container", "pallet_stack", "barrel", "crate_stack", "lift_hoist"],
}
const WHITE_FLOORS := ["floor_carpet_grey", "floor_carpet_grey", "floor_tile"]
const BLUE_FLOORS := ["floor_concrete", "floor_concrete", "floor_rubber"]

static func job(id: String) -> Dictionary:
	for j in JOBS:
		if j["id"] == id:
			return j
	return {}

static func is_temp(o: Dictionary) -> bool:
	return String(o.get("kind", "")) == "temp"

static func job_of(o: Dictionary) -> Dictionary:
	return job(String(o.get("job", "")))

## the skills a job's stations use, split into [social, labour]
static func skill_split(j: Dictionary) -> Array:
	var soc: Array = []
	var lab: Array = []
	for st in j["stations"]:
		for sid in st["skills"]:
			var grp: String = String(SK.skill(String(sid))["group"])
			if grp == "Social" and not soc.has(sid):
				soc.append(sid)
			elif grp == "Labour" and not lab.has(sid):
				lab.append(sid)
	return [soc, lab]

static func skill_names(ids: Array) -> String:
	return ", ".join(ids.map(func(i): return String(SK.skill(String(i))["name"])))

## the five jobs of a Temp Agency terminal's board.  Each is one of the five jobs, with a company, a manager, a pay and a difficulty drawn from the seed.
static func offers(world_seed: int, term_cell: int, day: int, gen: int = 0) -> Array:
	var out: Array = []
	for ji in JOBS.size():
		var j: Dictionary = JOBS[ji]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([world_seed, term_cell, day, gen, ji, "temp"])
		var company: String = COMPANIES[rng.randi() % COMPANIES.size()]
		var mgr: String = MANAGERS[rng.randi() % MANAGERS.size()]
		var dc_adj: int = rng.randi_range(-1, 1)
		var pay: int = int(round(float(j["base"]) * (0.9 + 0.2 * rng.randf()) / 5.0)) * 5
		var sd: int = rng.randi()
		var sp: Array = skill_split(j)
		var o := {"id": "temp_%s-%08x" % [j["id"], sd], "kind": "temp", "job": j["id"], "type": "temp_" + String(j["id"]), "name": String(j["name"]), "tag": TAG, "risk": 1,
			"site": company, "client": "%s at %s" % [mgr, company], "target": "", "seed": sd, "term": term_cell, "gen": gen, "layout": "open", "faction": "unaffiliated",
			"length": "short", "rooms": int(j["rooms"]), "hostiles": 0, "aff": 0, "share": 0.0, "lv": [0, 0], "collar": j["collar"], "dc_adj": dc_adj, "reward": pay,
			"social": sp[0], "labour": sp[1]}
		o["title"] = "%s (%s)" % [j["name"], company]
		o["brief"] = "Posted by %s.  %s  %s  Social: %s.  Labour: %s.  A %s-collar job." % [o["client"], j["line"], j["how"], skill_names(sp[0]), skill_names(sp[1]), j["collar"]]
		out.append(o)
	return out

# ---------------------------------------------------------------------------------------------- the floor
## what the site builder puts on a floor: [floor names, room kinds]
static func floor_style(collar: String) -> Dictionary:
	if collar == "blue":
		return {"floors": BLUE_FLOORS, "rooms": BLUE_ROOMS}
	return {"floors": WHITE_FLOORS, "rooms": WHITE_ROOMS}

# ---------------------------------------------------------------------------------------------- running a job
static func stations_of(g) -> Array:
	return g.city.get_meta("site").get("stations", [])

## the station on a tile (index into the job's list), or -1
static func station_at(g, c: int) -> int:
	for s in stations_of(g):
		if int(s[0]) == c:
			return int(s[1])
	return -1

static func done_count(m: Dictionary) -> int:
	return (m.get("st_done", {}) as Dictionary).size()

static func status_text(g) -> String:
	var m: Dictionary = g.mission
	var n: int = stations_of(g).size()
	var s := "Mission: %s  -  %d/%d tasks" % [m["offer"]["title"], done_count(m), n]
	if int(m.get("fails", 0)) > 0:
		s += ", %d slip%s" % [int(m["fails"]), "" if int(m["fails"]) == 1 else "s"]
	if m["done"]:
		s += "  (done; leave)"
	return s

## the check: 2d10 + the better skill + half the other, against the station's difficulty.  Returns [success, total, needed].
static func check(nat: int, skill_levels: Array, dc: int) -> Array:
	var best := 0
	var other := 0
	for l in skill_levels:
		if int(l) > best:
			other = best
			best = int(l)
		elif int(l) > other:
			other = int(l)
	var bonus: int = best + other / 2
	var total: int = nat + bonus
	var ok: bool = nat > 2 and (nat >= 19 or total >= dc)
	return [ok, total, dc]

## the chance (percent) a station's check works for these skill levels
static func chance(skill_levels: Array, dc: int) -> int:
	var n := 0
	for a in range(1, 11):
		for b in range(1, 11):
			if bool(check(a + b, skill_levels, dc)[0]):
				n += 1
	return n

## walk into a work station: one attempt.  Returns true if a turn was spent.
static func use_station(g, c: int) -> bool:
	var m: Dictionary = g.mission
	var o: Dictionary = m["offer"]
	var j: Dictionary = job_of(o)
	var idx: int = station_at(g, c)
	if j.is_empty() or idx < 0:
		g.say("A machine of the site's.  It is not part of your job.")
		return false
	if not m.has("st_done"):
		m["st_done"] = {}
		m["fails"] = 0
	var st: Dictionary = j["stations"][idx]
	if (m["st_done"] as Dictionary).has(str(c)):
		g.say("That is already done: %s." % String(st["label"]).to_lower())
		return false
	var dc: int = int(st["dc"]) + int(o.get("dc_adj", 0))
	var levels: Array = (st["skills"] as Array).map(func(sid): return g.lvl(String(sid)))
	var nat: int = g._roll_2d10()
	var r: Array = check(nat, levels, dc)
	g.sfx("blip")
	for sid in st["skills"]:
		g.skill_up(String(sid), 2)
	g._math("%s: dice %d + %s = %d against %d (%s)." % [st["label"], nat, " + ".join((st["skills"] as Array).map(func(sid): return "%s %d" % [String(SK.skill(String(sid))["name"]), g.lvl(String(sid))])), int(r[1]), dc, "works" if bool(r[0]) else "slips"])
	if bool(r[0]):
		(m["st_done"] as Dictionary)[str(c)] = true
		g.say("%s: %s  (%d/%d)" % [st["label"], st["ok"], done_count(m), stations_of(g).size()])
		if done_count(m) >= stations_of(g).size():
			m["done"] = true
			g.say("That is the job done.  Report out: leave by the exit portal and the agency pays.")
	else:
		m["fails"] = int(m.get("fails", 0)) + 1
		g.say("%s: %s  Try again (%d%%)." % [st["label"], st["fail"], chance(levels, dc)])
	g.end_turn()
	return true

## pay for the job as it stands: less 10% a failed attempt, never under half
static func pay(m: Dictionary) -> int:
	var o: Dictionary = m["offer"]
	var f: float = maxf(MIN_PAY, 1.0 - FAIL_PENALTY * float(int(m.get("fails", 0))))
	return int(round(float(int(o["reward"])) * f / 5.0)) * 5

static func outcome(g, _forced: String = "") -> Dictionary:
	var m: Dictionary = g.mission
	var o: Dictionary = m["offer"]
	var ok: bool = bool(m["done"])
	var started: bool = done_count(m) > 0
	var res := {"outcome": "success" if ok else ("failed" if started else "abandoned"), "reward": pay(m) if ok else 0, "type": o["type"], "title": o["title"], "text": ""}
	if ok:
		res["text"] = "Job complete: %s.  The agency credits ¥%d%s." % [o["title"], int(res["reward"]), "" if int(m.get("fails", 0)) == 0 else " (less %d slip%s)" % [int(m["fails"]), "" if int(m["fails"]) == 1 else "s"]]
	elif started:
		res["text"] = "Job unfinished: %s.  You leave with %d of %d tasks done.  No pay." % [o["title"], done_count(m), stations_of(g).size()]
	else:
		res["text"] = "You walk away from %s.  No pay." % o["title"]
	return res
