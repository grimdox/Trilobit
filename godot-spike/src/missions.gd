extends RefCounted
## Mission terminals: what they offer and how a mission is run.
##   Terminals are static computer objects in shops, clinics and restaurants (tile "terminal").  Bumping one opens the mission screen, which lists
##   five offers, one of each type below.  Accepting one opens a portal on the street beside the terminal; stepping through it enters a generated
##   site (mission_site.gd) that exists apart from the physical world.  Leaving the site, through its exit portal, closes the portal for good,
##   whether the mission was won, failed or dropped.  A mission pays out on return, in yen, and only if its objective was met.
## This file is the pure part: the offer tables, the offers a terminal shows on a given day, and the rules that run a mission (all take the Game).
const TJ = preload("res://src/temp_jobs.gd")
const SK = preload("res://src/skills.gd")
const CG = preload("res://src/citygen.gd")

## the five mission types.  `skills` are the skills the screen says will help; `need` is the work an objective takes (attempts that succeed).
const TYPES := [
	{"id": "assassination", "name": "Assassination", "tag": "KILL", "skills": ["ranged", "melee", "dodge"], "base": 420,
		"line": "Go in and kill one named person.",
		"how": "The target stands in the back of the site with bodyguards.  Kill them and walk out.  Nobody else has to die, but they will try."},
	{"id": "rescue", "name": "Rescue", "tag": "SAVE", "skills": ["streetwise", "deception", "melee"], "base": 380,
		"line": "Secure a hostage and bring them to the exit.",
		"how": "The hostage is bound in the back of the site.  Talk to them to cut them loose, then they follow you.  They must reach the exit portal alive."},
	{"id": "repair", "name": "Repair", "tag": "FIX", "skills": ["engineering", "manual"], "base": 330,
		"line": "Repair a machine in a hostile place.",
		"how": "A failed unit sits in the back of the site.  Work on it (walk into it) until it runs.  Each attempt makes noise; the guards are not far."},
	{"id": "recover", "name": "Recover Item", "tag": "GET", "skills": ["research", "streetwise", "ranged"], "base": 300,
		"line": "Find an item and carry it out.",
		"how": "A data case is hidden in one of the rooms.  Find it, pick it up and leave by the exit portal with it."},
	{"id": "sabotage", "name": "Sabotage", "tag": "BURN", "skills": ["engineering", "manual", "dodge"], "base": 450,
		"line": "Plant a charge on a site's core and get out before it blows.",
		"how": "Work on the core (walk into it) until the charge is set.  Setting it trips the alarm and starts a fuse: leave before it burns down."},
]

## ways in, as the board lists them (the game supports each: they are not flavour)
const WAYS := {
	"assassination": ["Shoot the target from cover before the guards close.", "Slip through the side rooms and strike in melee.", "Blow the target up: any explosion that reaches them counts."],
	"rescue": ["Cut the hostage loose and walk them out quietly.", "Clear the rooms first, then free them.", "Use another way out if the building has one."],
	"repair": ["Engineering gets it running fastest; Manual works half as well.", "Every attempt is noisy: clear the guards before you start.", "Fewer rooms and quieter routes mean fewer interruptions."],
	"recover": ["The case can be in any room: search quietly.", "Carry it out the way you came, or by any other exit.", "Unaffiliated crews drift; organised ones keep their posts."],
	"sabotage": ["Work the core (Engineering or Manual), then run for the exit.", "Or skip the work: a grenade or any blast that reaches the core wrecks it at once.", "Either way the alarm rings, and the guards come."],
}

const CLIENTS := ["an anonymous broker", "a nervous middle manager", "a fixer who owes someone", "a voice with no name", "a collector with a grudge", "a rival's former partner"]
const SITES := ["the Hollow Tannery", "Cold Store Nine", "the Salt Warehouse", "the Drowned Archive", "Relay Yard Four", "the Cinder Clinic", "the Night Foundry", "Pier Lock Seven"]
const FIRST_NAMES := ["Tanaka", "Volkov", "Reyes", "Mori", "Okafor", "Sato", "Brandt", "Ilyin", "Park", "Nakamura", "Costa", "Hale"]
const DIRS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const FUSE_TURNS := 36                 # turns from the charge being set to the blast
## the bomb is a little stronger than a 40mm grenade (radius 2, 40-70 damage, 55 on average, losing 30% a tile): radius 3, 66 at the core (+20% on the grenade's average)
## and it falls off the same way, 66 / 46 / 26 / 7 at 0 / 1 / 2 / 3 tiles.  It can hit any limb, the head and chest included, so stand well away when it goes.
const BOMB_RADIUS := 3
const BOMB_DAMAGE := 66

static func type_index(id: String) -> int:
	for i in TYPES.size():
		if TYPES[i]["id"] == id:
			return i
	return -1

static func type_of(id: String) -> Dictionary:
	var i: int = type_index(id)
	return TYPES[i] if i >= 0 else {}

## the work an objective takes, in successful attempts
static func need_for(type_id: String, risk: int) -> int:
	match type_id:
		"repair": return 3 + risk * 2
		"sabotage": return 2 + risk
	return 0

# ---------------------------------------------------------------------------------------------- the board and its switches
## The four switches on a terminal's board.  Each has a Value A, a Value B and a Neutral between them (0, 1, 2).  Neutral picks, per contract, at random from
## A, B or the neutral mix defined below.  The settings apply to the NEXT batch of contracts: a batch already posted never changes.
const SWITCHES := [
	{"id": "layout", "name": "LAYOUT", "a": "Open", "b": "Closed", "mix": "Mixed",
		"hint_a": "Large rooms and many doorways.  You start outside the building.",
		"hint_b": "Small rooms with one or two doors each.  You start inside, with only an exit portal.",
		"hint_n": "A mix of large and small rooms, a mix of door counts."},
	{"id": "faction", "name": "OPPOSITION", "a": "Affiliated", "b": "Unaffiliated", "mix": "Mixed",
		"hint_a": "Everyone on site belongs to one organisation, named in the contract.",
		"hint_b": "Freelance gang members, no colours, no one to answer to.",
		"hint_n": "One organisation supplies a quarter to a half of them; the rest are hired gang muscle."},
	{"id": "length", "name": "LENGTH", "a": "Long", "b": "Short", "mix": "Standard",
		"hint_a": "About 20 rooms (twice the standard).  More opposition, more pay.",
		"hint_b": "About 5 rooms (half the standard).  Less opposition, less pay.",
		"hint_n": "About 10 rooms."},
	{"id": "risk", "name": "RISK", "a": "Low", "b": "High", "mix": "Moderate",
		"hint_a": "Opposition one or two levels below yours.",
		"hint_b": "More of them, at your level or one above.",
		"hint_n": "Opposition at your level or one below.  Every board keeps one Low and one Moderate contract."},
]
const NEUTRAL := [1, 1, 1, 1]
const ROOMS := {"long": 20, "mid": 10, "short": 5}
const NEW_BATCH_COST := 100
const AFFIL := [1, 3, 5, 2]            # the organisations an Affiliated board can name: Bratva, Nasim, corporate security, the NAP (Neutral never uses the NAP)
const AFFIL_NAMES := {0: "unaffiliated gang members", 1: "Bratva", 2: "the NAP", 3: "Nasim", 4: "unaffiliated gang members", 5: "corporate security"}

static func switch_label(si: int, v: int) -> String:
	var d: Dictionary = SWITCHES[si]
	return d["a"] if v == 0 else (d["b"] if v == 2 else "Neutral")

static func pick3(rng: RandomNumberGenerator, v: int) -> int:
	return v if v != 1 else [0, 2, 1][rng.randi() % 3]          # 0 = Value A, 2 = Value B, 1 = the neutral mix

## hostile NPCs in a site: it grows with the rooms, and the risk raises or lowers it.  The layout never changes it.
static func hostile_count(rooms: int, risk: int) -> int:
	return maxi(3, int(round((2.0 + 0.5 * float(rooms)) * [0.8, 1.0, 1.3][clampi(risk, 1, 3) - 1])))

## the character levels of a site's hostiles: Low one or two below the player, Moderate at the player's level or one below, High at it or one above
static func level_range(plvl: int, risk: int) -> Array:
	var d: Array = [[-2, -1], [-1, 0], [0, 1]][clampi(risk, 1, 3) - 1]
	return [clampi(plvl + int(d[0]), 0, 10), clampi(plvl + int(d[1]), 0, 10)]

## pay: a share of the type's base plus a sum for each hostile that would be there, dearer per head as the risk rises
static func reward_for(type_id: String, hostiles: int, risk: int) -> int:
	var raw: float = float(type_of(type_id)["base"]) * 0.55 + float(hostiles) * float(26 + 12 * clampi(risk, 1, 3))
	return int(round(raw / 5.0)) * 5

## a fresh board for a terminal: five contracts, one of each type.  The same arguments give the same board.  `sw` holds the four switch positions (0 A, 1 Neutral,
## 2 B); `plvl` is the player's character level (the hostiles are levelled from it).  Every board has one Low and one Moderate contract.
static func offers(world_seed: int, term_cell: int, day: int, gen: int = 0, sw: Array = NEUTRAL, plvl: int = 0) -> Array:
	var out: Array = []
	var brng := RandomNumberGenerator.new()
	brng.seed = hash([world_seed, term_cell, day, gen, "board"])
	var slots: Array = [0, 1, 2, 3, 4]
	for k in range(4, 0, -1):
		var j: int = brng.randi() % (k + 1)
		var tmp = slots[k]
		slots[k] = slots[j]
		slots[j] = tmp
	var low_slot: int = slots[0]
	var mod_slot: int = slots[1]
	for ti in TYPES.size():
		var t: Dictionary = TYPES[ti]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([world_seed, term_cell, day, gen, ti, "mission"])
		var risk: int
		if ti == low_slot:
			risk = 1
		elif ti == mod_slot:
			risk = 2
		else:
			risk = 1 if int(sw[3]) == 0 else (3 if int(sw[3]) == 2 else rng.randi_range(1, 3))
		var site: String = SITES[rng.randi() % SITES.size()]
		var client: String = CLIENTS[rng.randi() % CLIENTS.size()]
		var target := ""
		if t["id"] == "assassination" or t["id"] == "rescue":
			target = "%s %s" % [["Hana", "Dmitri", "Luis", "Mei", "Joon", "Ade", "Sven", "Rin"][rng.randi() % 8], FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]]
		# the neutral switches resolve now, per contract
		var lay: String = ["open", "mix", "closed"][pick3(rng, int(sw[0]))]
		var fct: String = ["affiliated", "mix", "unaffiliated"][pick3(rng, int(sw[1]))]
		var len_k: String = ["long", "mid", "short"][pick3(rng, int(sw[2]))]
		var rooms: int = int(ROOMS[len_k])
		var hostiles: int = hostile_count(rooms, risk)
		var aff := 0
		var share := 0.0
		match fct:
			"affiliated":
				aff = AFFIL[rng.randi() % AFFIL.size()]
				share = 1.0
			"mix":
				aff = AFFIL[rng.randi() % 3]                        # never the NAP
				share = 0.25 + 0.25 * rng.randf()
		var sd: int = rng.randi()
		var o := {"id": "%s-%08x" % [t["id"], sd], "type": t["id"], "name": t["name"], "tag": t["tag"], "risk": risk, "site": site, "client": client,
			"target": target, "seed": sd, "term": term_cell, "gen": gen, "layout": lay, "faction": fct, "length": len_k, "rooms": rooms, "hostiles": hostiles,
			"aff": aff, "share": share, "lv": level_range(plvl, risk)}
		o["reward"] = reward_for(String(t["id"]), hostiles, risk)
		o["title"] = title_of(o)
		o["brief"] = brief_of(o)
		out.append(o)
	return out

## who stands against you, as a phrase
static func opposition_text(o: Dictionary) -> String:
	match String(o.get("faction", "unaffiliated")):
		"affiliated":
			return AFFIL_NAMES[int(o["aff"])]
		"mix":
			return "%s, with hired gang muscle" % AFFIL_NAMES[int(o["aff"])]
	return "unaffiliated gang members"

static func opposition_short(o: Dictionary) -> String:
	var nm: String = {1: "BRATVA", 2: "NAP", 3: "NASIM", 5: "CORP SEC"}.get(int(o.get("aff", 0)), "GANG")
	match String(o.get("faction", "unaffiliated")):
		"affiliated": return nm
		"mix": return nm + " + GANG"
	return "GANG"

static func layout_short(o: Dictionary) -> String:
	return {"open": "OPEN", "closed": "CLOSED", "mix": "MIXED"}.get(String(o.get("layout", "mix")), "MIXED")

static func length_short(o: Dictionary) -> String:
	return {"long": "LONG", "mid": "STD", "short": "SHORT"}.get(String(o.get("length", "mid")), "STD")

static func layout_text(o: Dictionary) -> String:
	return {"open": "Open plan", "closed": "Closed rooms", "mix": "Mixed rooms"}.get(String(o.get("layout", "mix")), "Mixed rooms")

static func length_text(o: Dictionary) -> String:
	return {"long": "Long", "mid": "Standard", "short": "Short"}.get(String(o.get("length", "mid")), "Standard")

## an offer with every board field present (a contract from before the board settings gets the standard room count and the old guard count)
static func normalize(o: Dictionary) -> Dictionary:
	var d: Dictionary = o.duplicate()
	var defaults := {"layout": "mix", "faction": "mix", "length": "mid", "rooms": 10, "hostiles": guard_count(int(o.get("risk", 1))), "aff": 0, "share": 0.0, "lv": [0, 0], "term": -1, "gen": 0}
	for k in defaults:
		if not d.has(k):
			d[k] = defaults[k]
	return d

static func title_of(o: Dictionary) -> String:
	match o["type"]:
		"assassination": return "Remove %s" % o["target"]
		"rescue": return "Bring out %s" % o["target"]
		"repair": return "Get a dead unit running at %s" % o["site"]
		"recover": return "Fetch a data case from %s" % o["site"]
		"sabotage": return "Burn the core at %s" % o["site"]
	return String(o["name"])

static func brief_of(o: Dictionary) -> String:
	var t: Dictionary = type_of(o["type"])
	var where: String = "" if o["type"] in ["repair", "recover", "sabotage"] else "  Site: %s." % o["site"]
	var opp: String = ""
	if o.has("hostiles"):
		opp = "  Opposition: %s (%d hostiles, level %d-%d)." % [opposition_text(o), int(o["hostiles"]), int(o["lv"][0]), int(o["lv"][1])]
	return "Posted by %s.%s%s  %s" % [o["client"], where, opp, t["how"]]

static func risk_text(risk: int) -> String:
	return ["", "Low", "Moderate", "High"][clampi(risk, 1, 3)]

## the hostiles on a site that has no board settings (an old save): by risk
static func guard_count(risk: int) -> int:
	return 3 + risk * 2


# ---------------------------------------------------------------------------------------------- running a mission
## a fresh mission state for an accepted offer (held in Game.mission while the player is inside the site)
static func new_state(o: Dictionary) -> Dictionary:
	return {"offer": o.duplicate(true), "progress": 0, "need": need_for(o["type"], int(o["risk"])), "done": false, "planted": false, "fuse": -1,
		"freed": false, "agents": {}, "ended": ""}

static func active(g) -> bool:
	return not g.mission.is_empty()

## one-line HUD text for the objective, with where you stand
static func status_text(g) -> String:
	if g.mission.is_empty():
		return ""
	var m: Dictionary = g.mission
	var o: Dictionary = m["offer"]
	if TJ.is_temp(o):
		return TJ.status_text(g)
	var s: String = "Mission: %s" % o["title"]
	match o["type"]:
		"assassination":
			s += "  -  target %s" % ("down; leave" if m["done"] else "alive")
		"rescue":
			s += "  -  %s" % ("hostage free; reach the exit" if m["freed"] else "hostage bound")
		"repair":
			s += "  -  repair %d/%d%s" % [m["progress"], m["need"], "  (running; leave)" if m["done"] else ""]
		"recover":
			s += "  -  %s" % ("case in hand; leave" if has_case(g) else "case not found")
		"sabotage":
			if m["planted"] and int(m["fuse"]) == 0:
				s += "  -  core destroyed; leave"
			elif m["planted"]:
				s += "  -  CHARGE SET, %d turns to the blast" % maxi(0, int(m["fuse"]))
			else:
				s += "  -  core %d/%d" % [m["progress"], m["need"]]
	return s

## an explosion on a site: one that reaches a sabotage core wrecks it at once, with no work and no fuse
static func on_blast(g, c: int, radius: int) -> void:
	if g.mission.is_empty():
		return
	var m: Dictionary = g.mission
	if m["offer"]["type"] != "sabotage" or m["planted"]:
		return
	var obj: int = int(g.city.get_meta("site")["objective"])
	if g.cheb(c, obj) > radius:
		return
	m["planted"] = true
	m["progress"] = int(m["need"])
	m["fuse"] = 0
	g.say("The blast tears the core apart.  The sabotage is done.  Get out.")
	_alarm(g)

static func has_case(g) -> bool:
	return g.eco._find("trl_datacase") != null

## the chance one attempt at the device works: Engineering counts in full, Manual by half, each point of site risk takes 8% off
static func work_chance(g, risk: int) -> int:
	var sk: int = maxi(g.lvl("engineering"), g.lvl("manual")) + (mini(g.lvl("engineering"), g.lvl("manual")) / 2)
	return clampi(48 + 7 * sk - 8 * risk, 20, 92)

## walk into the site's machine: one attempt at the repair or the charge.  Returns true if a turn was spent.
static func use_device(g, cell: int = -1) -> bool:
	var m: Dictionary = g.mission
	if m.is_empty():
		return false
	var o: Dictionary = m["offer"]
	if TJ.is_temp(o):
		return TJ.use_station(g, cell)
	if o["type"] != "repair" and o["type"] != "sabotage":
		g.say("A machine of the site's.  It is not part of your job.")
		return false
	if m["done"] or m["planted"]:
		g.say("It is already done.")
		return false
	var risk: int = int(o["risk"])
	g.step_noise = maxi(g.step_noise, 5)
	g.sfx("shot" if o["type"] == "sabotage" else "blip")
	var roll: int = g.rng.randi() % 100
	var ch: int = work_chance(g, risk)
	g.skill_up("engineering", 2 + risk)
	g.skill_up("manual", 1 + risk)
	if roll < ch:
		m["progress"] = int(m["progress"]) + 1
		if int(m["progress"]) >= int(m["need"]):
			if o["type"] == "repair":
				m["done"] = true
				g.say("The unit coughs, catches and runs.  The job is done.  Get out.")
			else:
				m["planted"] = true
				m["fuse"] = FUSE_TURNS
				g.say("The charge is set and the fuse is lit.  The alarm goes up.  %d turns." % FUSE_TURNS)
				_alarm(g)
		else:
			g.say("You work the %s (%d/%d)." % ["unit" if o["type"] == "repair" else "core", m["progress"], m["need"]])
	else:
		g.say("The work slips.  Try again (%d%%)." % ch)
	g.end_turn()
	return true

static func _alarm(g) -> void:
	for i in g.sim.n:
		if g.sim.alive[i] == 1 and role_of(g, i) in ["guard", "bodyguard", "target"]:
			g._alert(i)

## the people of a site are indexed in Game.mission["agents"]: {str(agent index): role}
static func role_of(g, i: int) -> String:
	return String(g.mission.get("agents", {}).get(str(i), ""))

static func agent_with_role(g, role: String) -> int:
	for k in g.mission.get("agents", {}):
		if g.mission["agents"][k] == role:
			return int(k)
	return -1

## cut the hostage loose (the talk menu calls this)
static func free_hostage(g) -> void:
	if g.mission.is_empty() or g.mission["freed"]:
		return
	g.mission["freed"] = true
	var h: int = agent_with_role(g, "hostage")
	if h >= 0:
		g.sim.sticky[h] = 0
	g.say("You cut the bonds.  \"Thank you.  Get me out of here.\"  They stay close behind you.")
	g.sfx("select")

## every turn inside a site: the hostage follows, the fuse burns, a kill is noticed
static func step(g) -> void:
	if g.mission.is_empty():
		return
	var m: Dictionary = g.mission
	var o: Dictionary = m["offer"]
	match o["type"]:
		"assassination":
			var t: int = agent_with_role(g, "target")
			if not m["done"] and t >= 0 and g.sim.alive[t] == 0:
				m["done"] = true
				g.say("%s is dead.  The contract is met.  Get out." % o["target"])
		"rescue":
			var h: int = agent_with_role(g, "hostage")
			if h >= 0 and g.sim.alive[h] == 1:
				if m["freed"]:
					_follow(g, h)
			elif h >= 0 and not m.get("lost", false):
				m["lost"] = true
				g.say("The hostage is dead.  There is nothing left to bring out.")
		"sabotage":
			if m["planted"] and int(m["fuse"]) > 0:
				m["fuse"] = int(m["fuse"]) - 1
				if int(m["fuse"]) == 10:
					g.say("The core is whining.  Ten turns.")
				if int(m["fuse"]) == 0:
					g.say("The charge goes off.")
					g._explode(int(g.city.get_meta("site")["objective"]), BOMB_RADIUS, BOMB_DAMAGE)
					if not g.game_over:
						g.say("The roof comes down.  You are thrown out of the site.")
						g.mission_leave_request = "blast"

## the hostage trails the player along the shortest walkable route (a flood from the player's cell, so doors and walls are respected): one step a turn,
## to the free neighbouring cell nearest the player, never onto them
static func _follow(g, h: int) -> void:
	g.astate[h] = g.UNAWARE
	g.sim.ctl[h] = 0
	g.sim.sticky[h] = 1
	var c: int = g.sim.pos[h]
	if g.cheb(c, g.pc) <= 1:
		return
	var size: int = g.size
	var dist := {g.pc: 0}
	var q: Array = [g.pc]
	var qi := 0
	while qi < q.size():
		var cur: int = q[qi]
		qi += 1
		if cur == c:
			break
		var cx: int = cur % size
		var cy: int = cur / size
		for d in DIRS:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or ny < 0 or nx >= size or ny >= size:
				continue
			var n: int = ny * size + nx
			if dist.has(n) or g.sim.walk[n] == 0:
				continue
			dist[n] = int(dist[cur]) + 1
			q.append(n)
	if not dist.has(c):
		return
	var best: int = c
	var bd: int = int(dist[c])
	for d in DIRS:
		var nx: int = c % size + d.x
		var ny: int = c / size + d.y
		if nx < 0 or ny < 0 or nx >= size or ny >= size:
			continue
		var n: int = ny * size + nx
		if not dist.has(n) or g.sim.at[n] != -1 or n == g.pc or g.thing_at.g(n) != -1 or g.city.tiles[n] == CG.TID["portal"]:
			continue
		if int(dist[n]) < bd or (best == c and int(dist[n]) == bd and n != int(g.mission.get("hostage_prev", -1))):
			bd = int(dist[n])                              # (a step round whoever stands on the shortest way: an equal step, never straight back)
			best = n
	if best != c:
		g.mission["hostage_prev"] = c
		g.sim.at[c] = -1
		g.sim.at[best] = h
		g.sim.pos[h] = best

## how the mission stands if the player leaves now: {outcome: success|failed|abandoned, text}
static func outcome(g, forced: String = "") -> Dictionary:
	var m: Dictionary = g.mission
	var o: Dictionary = m["offer"]
	if TJ.is_temp(o):
		return TJ.outcome(g, forced)
	var ok := false
	var why := ""
	match o["type"]:
		"assassination":
			ok = bool(m["done"])
			why = "The target still breathes." if not ok else ""
		"rescue":
			var h: int = agent_with_role(g, "hostage")
			ok = m["freed"] and h >= 0 and g.sim.alive[h] == 1 and g.cheb(g.sim.pos[h], g.pc) <= 4
			if not m["freed"]:
				why = "The hostage was never freed."
			elif h >= 0 and g.sim.alive[h] == 0:
				why = "The hostage died."
			elif not ok:
				why = "The hostage was left behind."
		"repair":
			ok = bool(m["done"])
			why = "The unit is still dead." if not ok else ""
		"recover":
			ok = has_case(g)
			why = "You are leaving without the case." if not ok else ""
		"sabotage":
			ok = bool(m["planted"])
			why = "No charge was set." if not ok else ""
	if forced == "blast":
		ok = false
		why = "You were still inside when the charge went off."
	var started: bool = int(m["progress"]) > 0 or m["freed"] or m["done"] or m["planted"] or has_case(g)
	var res := {"outcome": "success" if ok else ("failed" if (started or forced != "") else "abandoned"), "reward": int(o["reward"]) if ok else 0,
		"type": o["type"], "title": o["title"], "text": ""}
	if ok:
		res["text"] = "Contract complete: %s.  ¥%d is credited." % [o["title"], int(o["reward"])]
	elif res["outcome"] == "failed":
		res["text"] = "Contract failed: %s.  %s  No pay." % [o["title"], why]
	else:
		res["text"] = "You walk away from %s.  No pay." % o["title"]
	return res
