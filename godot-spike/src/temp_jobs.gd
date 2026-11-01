extends RefCounted
## Temp Agency work: labor-related contracts that use social and labor skills instead of weapons.  A Temp Agency's terminal posts five jobs, each at a company's high-rise:
## the player goes in through a portal (the same machinery as the Labor Center contracts), finds the job's work stations on the floor, and tries each one in turn.
## A station is one skill check: 2d10 + the better of its skills + half the other, against the station's difficulty (a natural 2 always fails, 19 or 20 always works).
## Every station done and the job is done; leave by the exit portal and the agency pays.  See the flavors (Normal, Urgent, Detailed), helpers and pay below.
##
## The first version resolves each station with the roll above.  The planned minigames (see PLAN.md, "Temp Agency") will replace the roll at a station with a small
## game whose result feeds the same check: `MINIGAME` says which one belongs where.
const SK = preload("res://src/skills.gd")
const CLK = preload("res://src/clock.gd")

const TAG := "WORK"

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
	{"id": "robot_tune", "name": "Retune the Assembly Robot", "collar": "blue", "base": 270, "rooms": 6,
		"line": "An assembly robot is drifting out of tolerance and the line supervisor will not say how long it has been doing that.",
		"how": "Find the fault in the controller, swap the worn servo, and get the supervisor to pause the line.",
		"stations": [
			{"label": "Trace the fault in the controller log", "skills": ["research"], "dc": 12, "ok": "Line 14 of the log gives it away: a servo reporting late.", "fail": "The log is a wall of noise.  You filter it again.", "mini": "none"},
			{"label": "Swap the worn servo", "skills": ["engineering"], "dc": 12, "ok": "The new servo seats and the arm swings true.", "fail": "A bolt shears.  You find another.", "mini": "none"},
			{"label": "Get the supervisor to pause the line", "skills": ["streetwise", "negotiation"], "dc": 11, "ok": "The supervisor waves you in with two fingers.", "fail": "Not now.  The supervisor wants a reason.", "mini": "none"}]},
	{"id": "rush_order", "name": "Hand-Finish a Rush Order", "collar": "blue", "base": 220, "rooms": 6,
		"line": "A customer's rush order is half done and the machines cannot do the last of it.",
		"how": "Cut and fit the panels by hand, pack and label the crates, and talk the foreman into lending you more hands.",
		"stations": [
			{"label": "Cut and fit the panels", "skills": ["artisan"], "dc": 11, "ok": "The panels sit flush and the seams barely show.", "fail": "A cut runs wide.  You recut the panel.", "mini": "none"},
			{"label": "Pack and label the crates", "skills": ["manual"], "dc": 10, "ok": "Twelve crates, twelve labels, all legible.", "fail": "Half the labels are upside down.", "mini": "none"},
			{"label": "Talk the foreman into more hands", "skills": ["streetwise", "negotiation"], "dc": 11, "ok": "The foreman shrugs and sends two people over.", "fail": "The foreman says everybody is already busy.", "mini": "none"}]},
	{"id": "ledger_audit", "name": "Audit the Quarterly Ledger", "collar": "white", "base": 300, "rooms": 7,
		"line": "The quarterly ledger does not reconcile, and the auditors arrive tomorrow.",
		"how": "Trace the missing entries, fix the accounting server that keeps losing them, and brief the finance head before the auditors do.",
		"stations": [
			{"label": "Trace the missing entries", "skills": ["research"], "dc": 13, "ok": "Four entries, one transposed digit, one forgotten invoice.", "fail": "The totals still disagree by a sliver.  You go through it again.", "mini": "research_match"},
			{"label": "Fix the accounting server", "skills": ["engineering"], "dc": 12, "ok": "The server stops dropping rows.", "fail": "It drops another batch.  You restart the service.", "mini": "none"},
			{"label": "Brief the finance head", "skills": ["etiquette", "negotiation"], "dc": 13, "ok": "The finance head nods through the whole briefing.", "fail": "They interrupt, and the briefing goes sideways.", "mini": "none"}]},
	{"id": "showroom", "name": "Stage the Showroom", "collar": "white", "base": 230, "rooms": 6,
		"line": "Buyers arrive at noon and the showroom floor is still crated.",
		"how": "Haul the displays out, dress them properly, and greet the first buyers like you work there.",
		"stations": [
			{"label": "Haul the displays out of the crates", "skills": ["manual"], "dc": 10, "ok": "The displays are on the floor, undamaged.", "fail": "A display catches the door frame.  You straighten it.", "mini": "none"},
			{"label": "Dress and label the displays", "skills": ["artisan"], "dc": 11, "ok": "Clean lines, clean labels.", "fail": "The labels sit crooked.  You redo them.", "mini": "none"},
			{"label": "Greet the first buyers", "skills": ["etiquette"], "dc": 12, "ok": "The buyers are smiling by the third display.", "fail": "They want to talk to someone senior.", "mini": "none"}]},
	{"id": "dock_tally", "name": "Rush Tally at the Loading Dock", "collar": "blue", "base": 250, "rooms": 7,
		"line": "Three trucks arrived together and the dock cannot keep up.",
		"how": "Unload and stack the pallets, check the loads against the paperwork, and keep the drivers calm.",
		"stations": [
			{"label": "Unload and stack the pallets", "skills": ["manual"], "dc": 12, "ok": "The stacks are square and tied.", "fail": "A stack leans.  You take it down and start again.", "mini": "warehouse_sort"},
			{"label": "Check the loads against the paperwork", "skills": ["research"], "dc": 11, "ok": "Every line on the paperwork has a pallet to match.", "fail": "One line has no pallet.  You count again.", "mini": "none"},
			{"label": "Keep the drivers calm", "skills": ["streetwise"], "dc": 12, "ok": "A few words each, and the drivers wait their turn.", "fail": "A driver is shouting about his schedule.", "mini": "none"}]},
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

# ---------------------------------------------------------------------------------------------- the board and its sliders
## The four sliders on a Temp Agency board: Value A (0), Neutral (1), Value B (2).  They bias which jobs the next batch posts.
const SWITCHES := [
	{"id": "trade", "name": "SECTOR", "a": "Trades", "b": "Office", "mix": "Mixed",
		"hint_a": "More blue-collar jobs: the social side is Streetwise (foremen, drivers, shift leads).",
		"hint_b": "More white-collar jobs: the social side is Etiquette (department heads, clients, finance).",
		"hint_n": "An even mix of trades and office work."},
	{"id": "phys", "name": "WORK", "a": "Physical", "b": "Cerebral", "mix": "Mixed",
		"hint_a": "More jobs that lean on Manual and Artisan: hauling, cutting, fitting.",
		"hint_b": "More jobs that lean on Engineering and Research: diagnosing, tracing, auditing.",
		"hint_n": "An even mix of hands-on and head-down work."},
	{"id": "speed", "name": "PACE", "a": "Quick", "b": "Precise", "mix": "Mixed",
		"hint_a": "More Urgent jobs: a 6 to 8 hour limit, 150 to 225% pay, and nothing if you miss it.",
		"hint_b": "More Detailed jobs: 10% extra pay for every point your best roll on each task beats its difficulty.",
		"hint_n": "Mostly Normal jobs, a few Urgent and a few Detailed."},
	{"id": "group", "name": "TEAM", "a": "Group", "b": "Independent", "mix": "Mixed",
		"hint_a": "Four or five co-workers on the floor to recruit; the pay runs a little lower.",
		"hint_b": "Hardly anyone on the floor to help; the pay runs a little higher.",
		"hint_n": "Two or three co-workers on the floor; standard pay."},
]
const NEUTRAL := [1, 1, 1, 1]
const FLAVORS := ["normal", "urgent", "detailed"]
const FLAVOR_NAMES := {"normal": "Normal", "urgent": "Urgent", "detailed": "Detailed"}
const URGENT_PAY := [1.5, 2.25]                    # an Urgent job pays 150 to 225% of a Normal one
const DETAIL_STEP := 0.10                          # a Detailed job pays 10% more for every point over the difficulties
const TASK_MINUTES := 120                          # a task takes two hours until we tune them
const HELPER_CUT := 15                             # percent of the pay a helper takes, less a point per Negotiation level

static func switch_label(si: int, v: int) -> String:
	var d: Dictionary = SWITCHES[si]
	return d["a"] if v == 0 else (d["b"] if v == 2 else "Neutral")

static func pick3(rng: RandomNumberGenerator, v: int) -> int:
	return v if v != 1 else [0, 2, 1][rng.randi() % 3]

## 0 = hands (Manual, Artisan) .. 1 = head (Engineering, Research): the share of a job's task skills that are cerebral
static func head_share(j: Dictionary) -> float:
	var n := 0.0
	var h := 0.0
	for st in j["stations"]:
		for sid in st["skills"]:
			if sid in ["manual", "artisan"]:
				n += 1.0
			elif sid in ["engineering", "research"]:
				n += 1.0
				h += 1.0
	return h / n if n > 0.0 else 0.5

## how much a slider position favours a job template when the board draws one
static func job_weight(j: Dictionary, sw: Array) -> float:
	var w := 1.0
	var blue: bool = String(j["collar"]) == "blue"
	match int(sw[0]):
		0: w *= 3.0 if blue else 1.0
		2: w *= 1.0 if blue else 3.0
	var hs: float = head_share(j)
	match int(sw[1]):
		0: w *= 1.0 + 3.0 * (1.0 - hs)
		2: w *= 1.0 + 3.0 * hs
	return w

## the weights of Normal, Urgent and Detailed for the Pace slider
static func flavor_weights(v: int) -> Array:
	return [[2.0, 4.0, 0.4], [3.0, 1.0, 1.0], [2.0, 0.4, 4.0]][clampi(v, 0, 2)]

static func _draw(rng: RandomNumberGenerator, weights: Array) -> int:
	var tot := 0.0
	for w in weights:
		tot += float(w)
	var r: float = rng.randf() * tot
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i
	return weights.size() - 1

static func span_words(minutes: int) -> String:
	var h: int = minutes / 60
	var m: int = minutes % 60
	if h > 0 and m > 0:
		return "%dh %02dm" % [h, m]
	return "%d hours" % h if h > 0 else "%d min" % m

## the one-line terms of a posting, listed in its description: pay, and the time allowed or the quality bonus
static func terms_text(o: Dictionary) -> String:
	match String(o.get("flavor", "normal")):
		"urgent":
			return "URGENT: finish every task within %s of stepping through, or you fail and are not paid.  Pays ¥%d." % [span_words(int(o["limit_min"])), int(o["reward"])]
		"detailed":
			return "DETAILED: pays ¥%d, plus 10%% for every point your best roll on each task beats its difficulty.  You may redo a task even after you succeed." % int(o["reward"])
	return "NORMAL: pays ¥%d." % int(o["reward"])

## the five postings of a Temp Agency terminal's board, drawn by weight from the templates (the sliders bias the draw)
static func offers(world_seed: int, term_cell: int, day: int, gen: int = 0, sw: Array = NEUTRAL) -> Array:
	var out: Array = []
	var ws: Array = JOBS.map(func(j): return job_weight(j, sw))
	for slot in 5:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([world_seed, term_cell, day, gen, slot, "temp2"])
		var ji: int = _draw(rng, ws)
		if slot < 3:                                      # the first three slots never repeat a template: the board keeps some variety
			var tries := 0
			while tries < 8 and out.any(func(o): return String(o["job"]) == String(JOBS[ji]["id"])):
				ji = _draw(rng, ws)
				tries += 1
		var j: Dictionary = JOBS[ji]
		var company: String = COMPANIES[rng.randi() % COMPANIES.size()]
		var mgr: String = MANAGERS[rng.randi() % MANAGERS.size()]
		var dc_adj: int = rng.randi_range(-1, 1)
		var flavor: String = FLAVORS[_draw(rng, flavor_weights(int(sw[2])))]
		var grp: int = pick3(rng, int(sw[3]))             # 0 group, 1 mixed, 2 independent
		var mates: int = [rng.randi_range(4, 5), rng.randi_range(2, 3), rng.randi_range(0, 1)][grp]
		var pay_f: float = 0.9 + 0.2 * rng.randf()
		if flavor == "urgent":
			pay_f *= rng.randf_range(URGENT_PAY[0], URGENT_PAY[1])
		if grp == 0:
			pay_f *= 1.0 - rng.randf_range(0.08, 0.15)    # (a crowd takes the edge off the pay; not shown to the player)
		elif grp == 2:
			pay_f *= 1.0 + rng.randf_range(0.10, 0.20)    # (working alone pays a little better; not shown)
		var pay: int = int(round(float(j["base"]) * pay_f / 5.0)) * 5
		var limit: int = rng.randi_range(24, 32) * 15     # 6 to 8 hours, in quarter hours
		var sd: int = rng.randi()
		var sp: Array = skill_split(j)
		var o := {"id": "temp_%s-%08x" % [j["id"], sd], "kind": "temp", "job": j["id"], "type": "temp_" + String(j["id"]), "name": String(j["name"]), "tag": TAG, "risk": 1,
			"site": company, "client": "%s at %s" % [mgr, company], "target": "", "seed": sd, "term": term_cell, "gen": gen, "layout": "open", "faction": "unaffiliated",
			"length": "short", "rooms": int(j["rooms"]), "hostiles": 0, "aff": 0, "share": 0.0, "lv": [0, 0], "collar": j["collar"], "dc_adj": dc_adj, "reward": pay,
			"social": sp[0], "labour": sp[1], "flavor": flavor, "limit_min": limit if flavor == "urgent" else 0, "mates": mates}
		o["title"] = "%s (%s)" % [j["name"], company]
		o["brief"] = "Posted by %s.  %s  %s  Social: %s.  Labour: %s.  %s" % [o["client"], j["line"], j["how"], skill_names(sp[0]), skill_names(sp[1]), terms_text(o)]
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
	var o: Dictionary = m["offer"]
	var n: int = stations_of(g).size()
	var s := "Mission: %s  -  %d/%d tasks" % [o["title"], done_count(m), n]
	if String(o.get("flavor", "normal")) == "urgent" and int(m.get("deadline", 0)) > 0:
		s += "  -  %s left" % CLK.span_text(maxi(0, int(m["deadline"]) - g.sim.tick))
	elif String(o.get("flavor", "")) == "detailed":
		s += "  -  +%d%% quality" % int(round(quality_points(m) * DETAIL_STEP * 100.0))
	if m["done"]:
		s += "  (done; leave)"
	return s

## the check: 2d10 + the better skill + half the other (+ a helper's bonus), against the difficulty.  Returns [success, total, needed].
static func check(nat: int, skill_levels: Array, dc: int, extra: int = 0) -> Array:
	var best := 0
	var other := 0
	for l in skill_levels:
		if int(l) > best:
			other = best
			best = int(l)
		elif int(l) > other:
			other = int(l)
	var bonus: int = best + other / 2 + extra
	var total: int = nat + bonus
	var ok: bool = nat > 2 and (nat >= 19 or total >= dc)
	return [ok, total, dc]

## the chance (percent) a station's check works for these skill levels
static func chance(skill_levels: Array, dc: int, extra: int = 0) -> int:
	var n := 0
	for a in range(1, 11):
		for b in range(1, 11):
			if bool(check(a + b, skill_levels, dc, extra)[0]):
				n += 1
	return n

# ---------------------------------------------------------------------------------------------- time
const MIN_TURNS := 10                              # a turn is six seconds: ten to the minute

## the clock of a job starts when you step through: an Urgent job's deadline
static func begin(g) -> void:
	var m: Dictionary = g.mission
	var o: Dictionary = m["offer"]
	if int(o.get("limit_min", 0)) > 0 and not m.has("deadline"):
		m["deadline"] = g.sim.tick + int(o["limit_min"]) * MIN_TURNS
	if not m.has("st_done"):
		m["st_done"] = {}
		m["fails"] = 0
	if not m.has("mates"):
		m["mates"] = {}
	if not m.has("best"):
		m["best"] = {}
	if not m.has("helped"):
		m["helped"] = {}

static func is_urgent(o: Dictionary) -> bool:
	return String(o.get("flavor", "normal")) == "urgent"

static func is_detailed(o: Dictionary) -> bool:
	return String(o.get("flavor", "normal")) == "detailed"

static func late(g) -> bool:
	var m: Dictionary = g.mission
	return is_urgent(m["offer"]) and int(m.get("deadline", 0)) > 0 and g.sim.tick >= int(m["deadline"]) and not bool(m.get("done", false))

## every turn inside a site: an Urgent job's clock runs out
static func step(g) -> void:
	var m: Dictionary = g.mission
	if late(g) and not bool(m.get("timeup", false)):
		m["timeup"] = true
		g.say("Time is up.  The job was not finished in time.  The site closes around you.")
		g.mission_leave_request = "timeup"

## let `minutes` pass (the world turns: hunger, thirst, the clock).  Stops at once if the job's clock runs out or the player is hurt badly.
static func spend(g, minutes: int) -> void:
	var left: int = minutes * MIN_TURNS
	while left > 0 and not g.game_over:
		g._tick()
		left -= 1
		if bool(g.mission.get("timeup", false)):
			break

## walking into a work station: the front end opens its menu (no time passes yet)
static func use_station(g, c: int) -> bool:
	if station_at(g, c) < 0:
		g.say("A machine of the site's.  It is not part of your job.")
		return false
	g.station_hit = c
	return false

# ---------------------------------------------------------------------------------------------- the people on the floor
const SOCIAL := ["etiquette", "streetwise", "negotiation", "diplomacy"]
const LABOUR := ["manual", "engineering", "artisan", "research"]

## a co-worker's skill levels: fixed by the site and the person (the same on a reload)
static func mate_skills(g, i: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(g.mission["offer"]["seed"]), "mate", int(g.sim.home_cell[i])])
	var out := {}
	for sid in SOCIAL + LABOUR:
		out[sid] = clampi((rng.randi_range(0, 3) + rng.randi_range(0, 3)) / 2 + (1 if rng.randf() < 0.25 else 0), 0, 5)
	return out

static func mate(g, i: int) -> Dictionary:
	var ms: Dictionary = g.mission["mates"]
	if not ms.has(str(i)):
		ms[str(i)] = {"known": false, "ask_mod": 0, "hired": false}
	return ms[str(i)]

static func is_mate(g, i: int) -> bool:
	return not g.mission.is_empty() and is_temp(g.mission["offer"]) and String(g.mission.get("agents", {}).get(str(i), "")) == "coworker"

## the social skill a job's conversations use: Etiquette for white collar, Streetwise for blue
static func help_skill(o: Dictionary) -> String:
	return "streetwise" if String(o["collar"]) == "blue" else "etiquette"

## the skills a helper is judged on at a station: the best of the station's own skills
static func relevant_skill(g, i: int, st: Dictionary) -> int:
	var ms: Dictionary = mate_skills(g, i)
	var best := 0
	for sid in st["skills"]:
		best = maxi(best, int(ms.get(sid, 0)))
	return best

static func cut_pct(g) -> int:
	return maxi(0, HELPER_CUT - g.lvl("negotiation"))

const TALK_TIMES := [[15, -1], [30, 0], [60, 1]]          # minutes, and the modifier they buy on a social roll

const HELP_YES := ["\"Sure, I'll help for a price.\"", "\"Yeah, I can lend a hand.  It'll cost you.\"", "\"Fine.  Pay me and I'm yours for the day.\"",
	"\"Count me in, for a cut of the fee.\"", "\"I've got the time.  I want my share, though.\"", "\"Alright.  A fair cut and we have a deal.\"",
	"\"I can do that.  Nothing's free, you know.\"", "\"Happy to help, as long as the agency's cut includes me.\"",
	"\"You've got the look of someone who knows what they're doing.  I'm in, for a price.\"", "\"Done.  Just remember who helped when the cheque comes.\"",
	"\"Sure thing.  My rate is a slice of yours.\"", "\"Why not?  The boss is not paying me extra for today anyway.\""]
const HELP_CONFUSED := ["\"I don't really follow what the job is yet.\"", "\"Wait, what are you actually trying to get done?\"",
	"\"Slow down.  I haven't got the scope of this at all.\"", "\"Hmm, I can't picture what you need from me.  Explain it better?\"", "\"I'm not sure I understand the job yet.\""]
const HELP_NO := ["\"I'm not interested in helping you.\"", "\"Find someone else.  I've got my own work.\"", "\"No.  Not today.\"",
	"\"I don't do favours for strangers.\"", "\"That is not my job, and it's not going to be.\""]

# ---------------------------------------------------------------------------------------------- menus
## walking into a work station (or an NPC) asks the front end for a menu; these build the menus.  Each option is {label, op, arg} for Economy.choose.
static func _opt(label: String, op: String, arg = null) -> Dictionary:
	return {"label": label, "op": op, "arg": arg}

static func margin_text(m: Dictionary, idx: int) -> String:
	var b: Dictionary = m.get("best", {})
	if not b.has(str(idx)):
		return ""
	var v: int = int(b[str(idx)])
	return "margin %s%d" % ["+" if v >= 0 else "", v]

## the menu at a work station
static func station_menu(g, cell: int, note: String = "") -> Dictionary:
	var m: Dictionary = g.mission
	var o: Dictionary = m["offer"]
	var j: Dictionary = job_of(o)
	var idx: int = station_at(g, cell)
	var st: Dictionary = j["stations"][idx]
	var done: bool = (m.get("st_done", {}) as Dictionary).has(str(cell))
	var dc: int = int(st["dc"]) + int(o.get("dc_adj", 0))
	var levels: Array = (st["skills"] as Array).map(func(sid): return g.lvl(String(sid)))
	var menu := {"title": String(st["label"]), "text": [], "options": [], "station": cell}
	var mins: int = int(st.get("minutes", TASK_MINUTES))
	menu["text"].append("%s.  Skills: %s.  Difficulty %d; your chance on your own is %d%%." % [String(j["name"]), skill_names(st["skills"]), dc, chance(levels, dc)])
	if done:
		menu["text"].append("Done  (%s)." % margin_text(m, idx))
	if is_urgent(o):
		menu["text"].append("Time left: %s." % CLK.span_text(maxi(0, int(m.get("deadline", 0)) - g.sim.tick)))
	if note != "":
		menu["text"].append(note)
	if not done or is_detailed(o):
		menu["options"].append(_opt("%s  (%s)" % ["Re-try the task" if done else "Complete the task now", span_words(mins)], "tj_task", [cell, -1]))
		menu["options"].append(_opt("Get help  (%s)" % span_words(mins), "tj_helpmenu", cell))
	menu["options"].append(_opt("Wait", "close"))
	return menu

## who is helping: the co-workers the player has recruited, with the bonus each would give at this station
static func helpers_menu(g, cell: int) -> Dictionary:
	var m: Dictionary = g.mission
	var j: Dictionary = job_of(m["offer"])
	var idx: int = station_at(g, cell)
	var st: Dictionary = j["stations"][idx]
	var menu := {"title": "Who helps with: %s" % String(st["label"]), "text": [], "options": [], "station": cell}
	var n := 0
	for k in m["mates"]:
		var d: Dictionary = m["mates"][k]
		if not bool(d["hired"]) or g.sim.alive[int(k)] == 0:
			continue
		var bonus: int = 1 + relevant_skill(g, int(k), st)
		menu["options"].append(_opt("%s  (+%d to the roll)" % [g.name_of(int(k)), bonus], "tj_task", [cell, int(k)]))
		n += 1
	if n == 0:
		menu["text"].append("Nobody is helping you yet.  Talk to a co-worker (T) and ask.")
	else:
		menu["text"].append("A helper adds +1 plus their own skill to your roll, and takes %d%% of the pay (%d%% less your Negotiation)." % [cut_pct(g), HELPER_CUT])
	menu["options"].append(_opt("Back", "tj_station", cell))
	return menu

## do the task: one roll (with a helper's bonus if one is named), then the time passes
static func do_task(g, cell: int, helper: int) -> Dictionary:
	var m: Dictionary = g.mission
	var o: Dictionary = m["offer"]
	var j: Dictionary = job_of(o)
	var idx: int = station_at(g, cell)
	var st: Dictionary = j["stations"][idx]
	var dc: int = int(st["dc"]) + int(o.get("dc_adj", 0))
	var levels: Array = (st["skills"] as Array).map(func(sid): return g.lvl(String(sid)))
	var extra := 0
	var who := ""
	if helper >= 0:
		extra = 1 + relevant_skill(g, helper, st)
		who = " with %s's help (+%d)" % [g.name_of(helper), extra]
		(m["helped"] as Dictionary)[str(helper)] = true
	var nat: int = g._roll_2d10()
	var r: Array = check(nat, levels, dc, extra)
	g.sfx("blip")
	for sid in st["skills"]:
		g.skill_up(String(sid), 2)
	var margin: int = int(r[1]) - dc
	g._math("%s%s: dice %d + %s%s = %d against %d (%s, margin %d)." % [st["label"], who, nat, " + ".join((st["skills"] as Array).map(func(sid): return "%s %d" % [String(SK.skill(String(sid))["name"]), g.lvl(String(sid))])), (" + help %d" % extra) if extra > 0 else "", int(r[1]), dc, "works" if bool(r[0]) else "slips", margin])
	var text: String
	if bool(r[0]):
		var best: Dictionary = m["best"]
		if not best.has(str(idx)) or margin > int(best[str(idx)]):
			best[str(idx)] = margin
		var first: bool = not (m["st_done"] as Dictionary).has(str(cell))
		(m["st_done"] as Dictionary)[str(cell)] = true
		text = "%s  (margin %s%d)" % [String(st["ok"]), "+" if margin >= 0 else "", margin]
		if first:
			g.say("%s: %s  (%d/%d)" % [st["label"], st["ok"], done_count(m), stations_of(g).size()])
		if done_count(m) >= stations_of(g).size() and not bool(m["done"]):
			m["done"] = true
			g.say("That is the job done.  Report out: leave by the exit portal and the agency pays.")
	else:
		m["fails"] = int(m.get("fails", 0)) + 1
		text = "%s  Try again (%d%%)." % [String(st["fail"]), chance(levels, dc, extra)]
		g.say("%s: %s" % [st["label"], st["fail"]])
	spend(g, int(st.get("minutes", TASK_MINUTES)))
	return {"text": text, "ok": bool(r[0])}

## the menu when you speak to a co-worker
static func talk_menu(g, i: int, note: String = "") -> Dictionary:
	var m: Dictionary = g.mission
	var o: Dictionary = m["offer"]
	var d: Dictionary = mate(g, i)
	var menu := {"title": g.name_of(i), "text": [], "options": [], "who": i}
	menu["text"].append("A co-worker on the %s floor." % ("trades" if String(o["collar"]) == "blue" else "office"))
	if bool(d["known"]):
		var ms: Dictionary = mate_skills(g, i)
		var bits: Array = []
		for sid in (o["social"] as Array) + (o["labour"] as Array):
			bits.append("%s %d" % [String(SK.skill(String(sid))["name"]), int(ms.get(sid, 0))])
		menu["text"].append("Their skills for this job: %s." % ", ".join(bits))
	if bool(d["hired"]):
		menu["text"].append("They have agreed to help.  A helper you use takes %d%% of the pay (%d%% less %d%% for your Negotiation), paid when you are paid." % [cut_pct(g), HELPER_CUT, mini(HELPER_CUT, g.lvl("negotiation"))])
	else:
		menu["text"].append("If someone helps you they take %d%% of the pay (%d%%, less 1%% for each level of your Negotiation)." % [cut_pct(g), HELPER_CUT])
	if note != "":
		menu["text"].append(note)
	menu["options"].append(_opt("Interview  (Diplomacy)", "tj_timemenu", [i, "interview"]))
	if not bool(d["hired"]):
		menu["options"].append(_opt("Ask for help  (%s)" % String(SK.skill(help_skill(o))["name"]), "tj_timemenu", [i, "help"]))
	menu["options"].append(_opt("Say goodbye", "close"))
	return menu

static func time_menu(g, i: int, kind: String) -> Dictionary:
	var o: Dictionary = g.mission["offer"]
	var sk: String = "diplomacy" if kind == "interview" else help_skill(o)
	var menu := {"title": "%s: %s" % [g.name_of(i), "an interview" if kind == "interview" else "ask for help"], "text": [], "options": [], "who": i}
	menu["text"].append("Roll: %s (you have %d) against %d.  More time buys a better roll." % [String(SK.skill(sk)["name"]), g.lvl(sk), 11 if kind == "interview" else 12])
	for tm in TALK_TIMES:
		var minutes: int = int(tm[0]) / (2 if kind == "interview" else 1)
		menu["options"].append(_opt("%d minutes  (%s%d)" % [minutes, "+" if int(tm[1]) >= 0 else "", int(tm[1])], "tj_talk", [i, kind, minutes, int(tm[1])]))
	menu["options"].append(_opt("Back", "tj_talkback", i))
	return menu

## the conversation itself: the roll, then the time
static func do_talk(g, i: int, kind: String, minutes: int, mod: int) -> Dictionary:
	var m: Dictionary = g.mission
	var o: Dictionary = m["offer"]
	var d: Dictionary = mate(g, i)
	var interview: bool = kind == "interview"
	var sk: String = "diplomacy" if interview else help_skill(o)
	var dc: int = 11 if interview else 12
	var adj: int = mod + (0 if interview else int(d["ask_mod"]))
	var nat: int = g._roll_2d10()
	var total: int = nat + g.lvl(sk) + adj
	var ok: bool = nat > 2 and (nat >= 19 or total >= dc)
	g.skill_up(sk, 2)
	g._math("%s with %s: dice %d + %s %d %s= %d against %d (%s)." % ["Interview" if interview else "Ask for help", g.name_of(i), nat, String(SK.skill(sk)["name"]), g.lvl(sk), ("%s%d " % ["+" if adj >= 0 else "", adj]) if adj != 0 else "", total, dc, "works" if ok else "fails"])
	var note := ""
	var rng: RandomNumberGenerator = g.rng
	if ok and interview:
		d["known"] = true
		note = "They tell you what they can do."
	elif ok:
		d["hired"] = true
		note = HELP_YES[rng.randi() % HELP_YES.size()] + "  (%d%% of the pay if you use them)" % cut_pct(g)
	elif interview:
		note = "They say very little."
	elif rng.randi() % 2 == 0:
		d["ask_mod"] = int(d["ask_mod"]) + 1
		note = HELP_CONFUSED[rng.randi() % HELP_CONFUSED.size()] + "  (ask again with +1)"
	else:
		d["ask_mod"] = int(d["ask_mod"]) - 2
		note = HELP_NO[rng.randi() % HELP_NO.size()] + "  (ask again at -2)"
	spend(g, minutes)
	return {"note": note}

# ---------------------------------------------------------------------------------------------- the pay
## the points above the difficulty levels on a Detailed job: the best margin on each task, never below nothing
static func quality_points(m: Dictionary) -> int:
	var t := 0
	for k in m.get("best", {}):
		t += maxi(0, int(m["best"][k]))
	return t

## the pay as the job stands, before the helpers' cut
static func gross(m: Dictionary) -> int:
	var o: Dictionary = m["offer"]
	var f := 1.0
	if is_detailed(o):
		f += DETAIL_STEP * float(quality_points(m))
	return int(round(float(int(o["reward"])) * f / 5.0)) * 5

static func helpers_used(m: Dictionary) -> int:
	return (m.get("helped", {}) as Dictionary).size()

## what the player actually gets: the gross pay less each used helper's cut
static func pay_for(g, m: Dictionary) -> int:
	var gr: int = gross(m)
	var per: int = int(round(float(gr) * float(cut_pct(g)) / 100.0))
	return maxi(0, gr - per * helpers_used(m))

static func outcome(g, forced: String = "") -> Dictionary:
	var m: Dictionary = g.mission
	var o: Dictionary = m["offer"]
	var ok: bool = bool(m["done"]) and forced != "timeup" and not late(g)
	var started: bool = done_count(m) > 0
	var res := {"outcome": "success" if ok else ("failed" if (started or forced == "timeup") else "abandoned"), "reward": 0, "type": o["type"], "title": o["title"], "text": ""}
	if ok:
		var nh: int = helpers_used(m)
		res["reward"] = pay_for(g, m)
		for k in nh:
			g.skill_up("negotiation", 2)                # each helper paid out is a bit of practice at the table
		var bits: Array = []
		if is_detailed(o):
			bits.append("quality +%d%%" % int(round(quality_points(m) * DETAIL_STEP * 100.0)))
		if nh > 0:
			bits.append("%d helper%s took %d%% each" % [nh, "" if nh == 1 else "s", cut_pct(g)])
		res["text"] = "Job complete: %s.  The agency credits ¥%d%s." % [o["title"], int(res["reward"]), (" (" + ", ".join(bits) + ")") if not bits.is_empty() else ""]
	elif forced == "timeup" or late(g):
		res["text"] = "Out of time: %s.  The job was not finished within %s.  No pay." % [o["title"], span_words(int(o["limit_min"]))]
	elif started:
		res["text"] = "Job unfinished: %s.  You leave with %d of %d tasks done.  No pay." % [o["title"], done_count(m), stations_of(g).size()]
	else:
		res["text"] = "You walk away from %s.  No pay." % o["title"]
	return res
