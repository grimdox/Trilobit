extends RefCounted
## Character creation: attribute rules (6..14, fixed total, pool), appearance options, save/load and zone carry, the doll, and the New Game flow.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const SK = preload("res://src/skills.gd")
const CR = preload("res://src/creation.gd")
const DS = preload("res://src/dollspec.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)

	# ---- attributes
	var a: Dictionary = CR.start_attrs()
	check.call("everything starts at 10 with an empty pool", SK.ATTRS.all(func(x): return a[x["id"]] == 10) and CR.free_points(a) == 0 and CR.attrs_valid(a))
	check.call("with an empty pool no attribute can be raised", SK.ATTRS.all(func(x): return not CR.can_raise(a, x["id"])))
	var a2: Dictionary = CR.change(a, "str", 1)
	check.call("raising with nothing in the pool changes nothing", a2 == a)
	a2 = CR.change(a, "cog", -1)
	check.call("lowering Cognition to 9 puts one free point in the pool", a2["cog"] == 9 and CR.free_points(a2) == 1 and not CR.attrs_valid(a2))
	a2 = CR.change(a2, "str", 1)
	check.call("the free point raises Strength to 11 and the pool is empty again", a2["str"] == 11 and CR.free_points(a2) == 0 and CR.attrs_valid(a2))
	var lo: Dictionary = a
	for i in 10:
		lo = CR.change(lo, "agi", -1)
	check.call("an attribute cannot go below 6 (ten presses stop at 6, four points in the pool)", lo["agi"] == 6 and CR.free_points(lo) == 4)
	var hi: Dictionary = lo
	for i in 10:
		hi = CR.change(hi, "str", 1)
	check.call("an attribute cannot go above 14 (Strength stops at 14 using the four points)", hi["str"] == 14 and CR.free_points(hi) == 0 and CR.attrs_valid(hi))
	var two: Dictionary = CR.change(CR.change(CR.change(CR.change(a, "agi", -1), "agi", -1), "agi", -1), "agi", -1)     # Agility 6
	two = CR.change(CR.change(CR.change(CR.change(two, "end", -1), "end", -1), "end", -1), "end", -1)                  # Endurance 6
	for i in 4:
		two = CR.change(two, "str", 1)
		two = CR.change(two, "per", 1)
	check.call("the pool can be spent across several attributes (Str 14, Per 14, Agi 6, End 6)", two["str"] == 14 and two["per"] == 14 and two["agi"] == 6 and two["end"] == 6 and CR.attrs_valid(two))
	check.call("a fourteenth-point raise past the cap is refused even with points free", not CR.can_raise(CR.change(hi, "cog", -1), "str"))
	var tot_ok := true
	var rr := RandomNumberGenerator.new()
	rr.seed = 6
	var cur: Dictionary = a
	for i in 400:
		cur = CR.change(cur, SK.ATTRS[rr.randi() % 5]["id"], 1 if rr.randi() % 2 == 0 else -1)
		var sum := 0
		for x in SK.ATTRS:
			sum += cur[x["id"]]
			if cur[x["id"]] < 6 or cur[x["id"]] > 14:
				tot_ok = false
		if sum + CR.free_points(cur) != 50 or CR.free_points(cur) < 0:
			tot_ok = false
	check.call("400 random presses: always inside 6..14, never a negative pool, total plus pool always 50", tot_ok)
	check.call("a hand-made profile above 14 or below 6 is not valid", not CR.attrs_valid({"str": 15, "per": 5, "agi": 10, "cog": 10, "end": 10}) and not CR.attrs_valid({"str": 14, "per": 6, "agi": 10, "cog": 10, "end": 9}))

	# ---- appearance
	var app: Dictionary = CR.default_app()
	check.call("the default look is the figure the game always drew (Frame A, light skin, grey hair, buzz cut)", CR.look_of(app)["skin"] == DS.SKINS[0] and CR.look_of(app)["hair"] == DS.HAIRS[4] and CR.look_of(app)["style"] == "buzz" and not CR.look_of(app)["fem"])
	var wrap := true
	for f in ["sprite", "skin", "hair", "style", "eyes"]:
		var cur2: Dictionary = app
		for i in CR.count(f):
			cur2 = CR.cycle(cur2, f, 1)
		if cur2 != app:
			wrap = false
		if CR.cycle(app, f, -1)[f] != (int(app[f]) + CR.count(f) - 1) % CR.count(f):
			wrap = false
	check.call("every appearance row wraps in both directions", wrap)
	check.call("five skin tones, seven hair colours, seven styles, six eye colours, two sprites", CR.count("skin") == 5 and CR.count("hair") == 7 and CR.count("style") == 7 and CR.count("eyes") == 6 and CR.count("sprite") == 2)
	check.call("every style the creator offers exists in the doll's hair layers", CR.STYLES.all(func(s): return s in DS.STYLES_M or s in DS.STYLES_F))
	check.call("every option has a name", ["sprite", "skin", "hair", "style", "eyes"].all(func(f): return CR.option_name(app, f) != ""))
	check.call("the screen shows only the sprite row; skin, hair, style and eyes stay in the data", CR.LOOK_ROWS.size() == 1 and CR.LOOK_ROWS[0]["id"] == "sprite" and CR.HIDDEN_LOOK == ["skin", "hair", "style", "eyes"])
	var bad: Dictionary = CR.sanitize({"sprite": 9, "skin": -3, "hair": 99, "style": 40, "eyes": 12, "bg": "zzz"})
	check.call("out-of-range saved values are brought inside the tables", bad["sprite"] == 1 and bad["skin"] == 0 and bad["hair"] == 6 and bad["style"] == 6 and bad["eyes"] == 5 and bad["bg"] == "none")
	check.call("the background page is a placeholder (one 'not chosen' entry)", CR.BACKGROUNDS.size() == 1 and CR.BACKGROUNDS[0]["id"] == "none")

	# ---- applied to a game, saved, carried between zones, drawn
	var g = GameScript.new(21)
	g.setup(300)
	var prof: Dictionary = CR.new_profile()
	prof["app"] = CR.cycle(CR.cycle(CR.cycle(prof["app"], "skin", 3), "eyes", 3), "sprite", 1)
	prof["attrs"] = two.duplicate()
	check.call("a finished profile is valid", CR.profile_valid(prof))
	CR.apply(g, prof)
	check.call("applying it sets the player's attributes and look", g.attrs["str"] == 14 and g.attrs["agi"] == 6 and g.app["skin"] == 3 and g.app["eyes"] == 3 and g.app["sprite"] == 1)
	check.call("the attribute bonus uses the chosen attributes (Strength 14 gives +2 to Melee through Strength, Agility 6 gives 0)", g.lvl("melee") == 2 and g.lvl("grit") == 2 + 0)
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = GameScript.new(21)
	g2.setup(300)
	g2.load_dict(d)
	check.call("save and load round trip keeps attributes and look", g2.attrs == g.attrs and g2.app == g.app)
	var g3 = GameScript.new(21)
	g3.setup(300)
	g3.apply_player(JSON.parse_string(JSON.stringify(g.player_dict())))
	check.call("carrying the player to another zone keeps attributes and look", g3.attrs == g.attrs and g3.app == g.app)
	var old: Dictionary = d.duplicate(true)
	old.erase("app")
	var g4 = GameScript.new(21)
	g4.setup(300)
	g4.load_dict(old)
	check.call("an old save with no look loads with the default figure", g4.app == CR.default_app())
	var spec: Dictionary = DS.for_player(g)
	check.call("the player's doll uses the chosen skin and the other body frame", spec["look"]["skin"] == DS.SKINS[3] and spec["look"]["fem"] and spec["look"]["eyes"] == CR.EYES[3])
	var layers: Array = DS.base_layers(spec["look"], false)
	check.call("the doll's base layers follow the chosen frame and hair style", "d_torso_f" in layers and ("d_hair_" + String(spec["look"]["style"])) in layers)

	return [st[0], st[1], log]
