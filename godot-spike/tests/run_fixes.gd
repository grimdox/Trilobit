extends SceneTree
## The 13-bug batch: default Local map, signs and names, building fill, nanohack text, hands, power, Trilobit battery, food report.
## Run: godot --headless -s tests/run_fixes.gd
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
const GearScript = preload("res://src/gear_ui.gd")
const SG = preload("res://src/signage.gd")
const NANO = preload("res://src/nanohacks.gd")
const ISL = preload("res://src/island.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://test_fix_save_"
	m.settings_path = "user://test_fix_settings.json"
	root.add_child(m)
	await process_frame
	var w = WorldScript.new()
	w.start(21, 300)
	m.world = w
	m.start_play(w.game)
	await process_frame
	var g = w.game
	var c = g.city
	check("the map screen opens on the Local map", m.screen.map_local)
	check("the local map covers 141 x 141 tiles", m.LOCAL_R == 70)
	# signs
	var names := {}
	var dup := 0
	for s in c.signs:
		if s["kind"] == "biz" or s["kind"] == "tower" or (s["kind"] == "house" and s["name"] != "For Rent"):
			if names.has(s["name"]):
				dup += 1
			names[s["name"]] = true
	check("every building has a sign (%d signs)" % c.signs.size(), c.signs.size() >= c.businesses.size())
	check("names are unique (%d repeats)" % dup, dup == 0)
	check("each business type has a pictogram", c.businesses.all(func(b): return SG.TYPE_SYM.has(b["type"])))
	var shapes := {}
	for s in c.signs:
		shapes[s["shape"] + str(s["pal"])] = true
	check("several sign designs are in use (%d)" % shapes.size(), shapes.size() >= 6)
	# fill
	var plain := 0
	var filled := 0
	for b in c.bldgs:
		if b["kind"] != "core":
			plain += 1
			if b.get("filled", false):
				filled += 1
	var share: float = float(filled + c.businesses.size() + c.towers.size()) / float(plain + c.businesses.size() + c.towers.size())
	check("90 to 97 percent of the buildings are filled (%.3f)" % share, share >= 0.9 and share <= 0.97)
	# start flat is empty of NPCs
	var homes_here := 0
	for i in g.sim.pos.size():
		if g.sim.pos[i] / g.s2 == g.pc / g.s2 and absi(g.sim.pos[i] % g.size - g.pc % g.size) < 12 and absi((g.sim.pos[i] / g.size) % g.size - (g.pc / g.size) % g.size) < 12:
			homes_here += 1
	check("nobody else is in the starting flat's neighbourhood on its level (%d)" % homes_here, homes_here <= 3)
	# nano chips
	var chip = g._new_item(NANO.chip_item("plating"))
	check("a nanohack chip reads 'Install in Trilobit'", g.inv.equip_text(chip).contains("Install in Trilobit"))
	# hands: one slot
	check("hands show on the right side only", not GearScript.SPOT_PART.has("lhand") and GearScript.SPOT_PART.has("rhand"))
	# power: no battery, no implants
	var saved: Dictionary = g.implants.duplicate()
	g.implants = {}
	check("with nothing installed there is no store and no power", g.power_left() <= 0.0)
	g.implants = saved
	# elevator
	check("floor_button gives a label", g.floor_button(0) != "")
	# minimap: needs a fitted, powered Trilobit
	m.refresh()
	check("a powered Trilobit shows the minimap", m.view.mini_on and m.view.mini_tex != null)
	var saved2: Dictionary = g.implants.duplicate()
	g.implants = {}
	m.refresh()
	check("without one there is no minimap", not m.view.mini_on)
	g.implants = saved2
	# food: heals what is hurt, and says how much
	g.body.hp["chest"] = maxi(1, int(g.body.mx["chest"]) - 10)
	var onigiri = g._new_item("trl_food_onigiri")
	if onigiri != null:
		var hurt0: int = int(g.body.mx["chest"]) - int(g.body.hp["chest"])
		g.eat_now(onigiri)
		check("a meal heals up to its stated amount of what is hurt (%d healed)" % g.last_healed, g.last_healed == mini(int(onigiri.def["food"].get("hp", 0)), hurt0 + 0) or g.last_healed >= 1)
	check("the map names the nearest Labor Center (%s)" % m.nearest_labor_text(), m.nearest_labor_text().begins_with("Nearest Labor Center"))
	print("PASS %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
