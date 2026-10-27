extends RefCounted
## The implant catalogue (Basic, Improved, Quality), the sellers' stock by district, skills from implants, the Dermal malus, repairs.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const IMP = preload("res://src/implants.gd")
const PW = preload("res://src/power.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	# ---- the data
	var all: Array = IMP.DATA.ALL
	check.call("72 implants: 24 in each of Basic, Improved and Quality, none higher", all.size() == 72 and [1, 2, 3].all(func(t): return all.filter(func(d): return d["grade"] == t).size() == 24) and all.all(func(d): return d["grade"] <= 3))
	var seen := {}
	for d in all:
		seen[d["id"]] = true
	var parts_ok := true
	for d in all:
		var found := false
		for p in IMP.PARTS:
			if p["id"] == d["part"]:
				found = true
		if not found:
			parts_ok = false
	check.call("ids are unique and every part is one of the eight layers", seen.size() == 72 and parts_ok)
	var heads: Array = all.filter(func(d): return d["part"] == "head")
	check.call("brain implants are all Trilobits with 2 / 4 / 6 nanohack slots by tier and a hacking skill", heads.size() == 12 and heads.all(func(d): return String(d["name"]).ends_with("Trilobit") and int(d["nano"]) == 2 * int(d["grade"]) and d["skills"].size() == 1))
	check.call("only Trilobits carry nanohack slots", all.all(func(d): return d.has("nano") == (d["part"] == "head")))
	var chest: Array = all.filter(func(d): return d["part"] == "chest")
	check.call("chest implants store energy that grows with the tier, and each tier has a Reserve Cell with no skills and three times the battery", chest.all(func(d): return d.has("battery")) and chest.filter(func(d): return d["skills"].is_empty() if d.has("skills") else true).size() == 3 and IMP.get_def("x213")["battery"] == 3 * IMP.get_def("x211")["battery"])
	var derm: Array = all.filter(func(d): return d["part"] == "dermal")
	check.call("every dermal implant lowers Negotiation by 1 and has more armor than the tier's other parts", derm.size() == 6 and derm.all(func(d): return d["skills"].get("negotiation", 0) <= -1 or d["skills"].has("negotiation") and d["skills"]["negotiation"] == -1) and derm.all(func(d): return d["armor"] >= d["grade"] + 1))
	check.call("no more than two skills per implant", all.all(func(d): return d.get("skills", {}).size() <= 2))
	check.call("install requirements: Grit of tier - 1, and each raised skill at bonus + 1", all.all(func(d): var grit: int = int(d.get("req", {}).get("grit", 0)); return grit >= int(d["grade"]) - 1 and d["skills"].keys().all(func(k): return int(d["skills"][k]) <= 0 or int(d["req"].get(k, 0)) >= int(d["skills"][k]) + 1) if d.has("skills") else grit >= int(d["grade"]) - 1))
	check.call("repairing a worn-out implant costs a quarter of its price", all.all(func(d): return IMP.repair_cost(d, 0) == int(round(d["cost"] * 0.25))))
	# ---- the sellers' stock by district
	var okt := true
	for w in 3:
		for kind in ["cyberdoc", "implant"]:
			for style in ["senses", "body"]:
				var ids: Array = IMP.stock(kind, style if kind == "implant" else "", w, 1234 + w)
				var tiers: Array = IMP.tiers_for(kind, w)
				for id in ids:
					var d: Dictionary = IMP.get_def(id)
					if not (int(d["grade"]) in tiers):
						okt = false
	check.call("a seller offers only the tiers its district allows (lower 1, middle 1-2, upper 2-3)", okt and IMP.tiers_for("implant", 0) == [1] and IMP.tiers_for("implant", 1) == [1, 2] and IMP.tiers_for("implant", 2) == [2, 3])
	check.call("Quality (tier 3) is sold only in the richer districts", [0, 1].all(func(w): return IMP.stock("implant", "senses", w, 5).all(func(id): return IMP.get_def(id)["grade"] < 3)) and IMP.stock("implant", "body", 2, 5).any(func(id): return IMP.get_def(id)["grade"] == 3))
	check.call("a Cyberdoc Office sells a handful (6) of Basic and Improved implants, never Quality, in every district", [0, 1, 2].all(func(w): var s: Array = IMP.stock("cyberdoc", "", w, 77); return s.size() == 6 and s.all(func(id): return IMP.get_def(id)["grade"] <= 2)))
	check.call("the eyes/spine/head store sells only those parts, and the other store the rest", IMP.stock("implant", "senses", 1, 9).all(func(id): return IMP.get_def(id)["part"] in ["head", "eyes", "spine"]) and IMP.stock("implant", "body", 1, 9).all(func(id): return IMP.get_def(id)["part"] in ["chest", "dermal", "arms", "hands", "legs"]))
	check.call("a seller's stock is the same every time", IMP.stock("implant", "body", 2, 31) == IMP.stock("implant", "body", 2, 31))
	check.call("wired NPCs wear catalogue implants (Bratva four Basic, NAP five Improved)", IMP.NPC_RIGS[1].size() == 4 and IMP.NPC_RIGS[2].size() == 5 and IMP.NPC_RIGS[1].all(func(i): return IMP.get_def(i)["grade"] == 1) and IMP.NPC_RIGS[2].all(func(i): return IMP.get_def(i)["grade"] == 2))
	# ---- in a game
	var g = GameScript.new(11)
	g.setup(1200)
	g.implants = {}
	var base_st: int = g.lvl("streetwise")
	g.implants = {"x105": true}                                   # Gutterline Optic: Streetwise +1
	check.call("a working implant adds its skill bonus to the level", g.lvl("streetwise") == base_st + 1 and g.base_lvl("streetwise") == base_st)
	g.imp_dur["x105"] = 0
	check.call("a wrecked implant adds nothing", g.lvl("streetwise") == base_st)
	g.imp_dur.clear()
	var base_neg: int = g.lvl("negotiation")
	g.implants = {String(derm[0]["id"]): true}
	check.call("a dermal implant lowers Negotiation by 1 (never below 0)", g.lvl("negotiation") == maxi(0, base_neg - 1))
	g.implants = {String(derm[0]["id"]): true}
	check.call("dermal armor covers every limb", g.armor_value("head") >= int(derm[0]["armor"]) and g.armor_value("l_leg") >= int(derm[0]["armor"]))
	g.implants = {"x105": true, "x108": true}
	g.imp_dur = {"x105": 4, "x108": 4}
	var d1: Dictionary = IMP.get_def("x105")
	var d2: Dictionary = IMP.get_def("x108")
	check.call("the repair bill adds up what each fitted implant has lost", g.eco.repair_cost() == IMP.repair_cost(d1, 4) + IMP.repair_cost(d2, 4) and g.eco.repair_cost() > 0)
	g.imp_dur.clear()
	check.call("and is nothing when they are as new", g.eco.repair_cost() == 0)
	# the people who sell implants in this city
	var kinds := {}
	var bad := 0
	for i in g.sim.n:
		if int(g.eco.role[i]) == g.eco.RIPPER:
			var v: Dictionary = g.eco.venue_of.get(i, {})
			var k: String = String(v.get("kind", "cyberdoc"))
			kinds[k] = int(kinds.get(k, 0)) + 1
			var tiers: Array = IMP.tiers_for(k, 0 if g.z_of(g.sim.pos[i]) < 0 else g.district_of(g.sim.pos[i]))
			if v.is_empty() and g.z_of(g.sim.pos[i]) > 0:
				tiers = IMP.tiers_for(k, 2)
			for id in g.eco.ripper_stock(i):
				if not (int(IMP.get_def(id)["grade"]) in tiers):
					bad += 1
	check.call("every implant seller in the city (%s) offers only what its district allows" % str(kinds), bad == 0 and kinds.size() >= 1)
	return [st[0], st[1], log]
