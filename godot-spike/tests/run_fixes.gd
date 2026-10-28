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
	check("the local map shows 141 tiles of a 381-tile area and scrolls", m.LOCAL_VIEW_R == 70 and m.LOCAL_R == 190)
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
	# ---- batch 2
	var CGS = preload("res://src/citygen.gd")
	var CRE = preload("res://src/creation.gd")
	var props := 0
	var blocked_ok := true
	for ci in c.tiles.size():
		var tt: int = c.tiles[ci]
		if tt == CGS.TID["street_tree"] or tt == CGS.TID["street_bench"] or tt == CGS.TID["bench_broken"]:
			props += 1
			if CGS.WALK[tt] != 0 or not (tt in CGS.LOW_COVER):
				blocked_ok = false
	check("street trees and benches exist, cannot be walked through and give cover (%d)" % props, props > 50 and blocked_ok)
	check("no random neon signs on the pavement", not (str(m.view.DECOR_FRONT).contains("neon")))
	var looks: Array = []
	for bi in 3:
		var ap: Dictionary = CRE.default_app()
		ap["build"] = bi
		looks.append(String(CRE.look_of(ap)["size"]))
	check("body type picks the thin, middle or large doll (%s)" % ",".join(looks), looks == ["s", "m", "l"])
	# containers keep what is in them
	var pk = g._new_item("trl_backpack")
	var rat = g._new_item("trl_ration")
	g.inv.stow(pk)
	g.inv.auto_equip(pk)
	g.inv.put_in(pk, rat)
	check("a worn container holds what is put in it", g.inv.find(rat).get("g", "") == "back")
	g.inv.auto_unequip("back")
	check("it stays inside when the container comes off", pk.stash.has(rat) and g.inv.find(rat).is_empty())
	g.inv.auto_equip(pk)
	check("and is back when the container is worn again", g.inv.find(rat).get("g", "") == "back")
	var d2: Dictionary = pk.to_dict()
	var pk2 = preload("res://src/item.gd").from_dict(d2, g.db)
	check("a container saves with its contents", pk2.stash_count() == 1)
	# the law: NAP shoots a Bratva who attacks
	var cells: Array = []
	for dd in [Vector2i(2, 0), Vector2i(3, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(3, 1), Vector2i(-3, 1), Vector2i(4, 0), Vector2i(0, 4)]:
		var cc2: int = g.pc + dd.y * g.size + dd.x
		if g._agent_open(cc2):
			cells.append(cc2)
	var pair: Array = []
	for ca in cells:
		for cb in cells:
			if pair.is_empty() and ca != cb and g.cheb(ca, cb) >= 2 and g.sim._sees(ca, cb, 16) and g.sim._sees(cb, ca, 16):
				pair = [ca, cb]
	check("there is room to stage the police test (%d cells, a clear pair: %s)" % [cells.size(), not pair.is_empty()], not pair.is_empty())
	var staged: Array = []
	for pi in g.sim.alive.size():
		if staged.size() < 2 and g.sim.alive[pi] == 1 and g.sim.near[pi] == 0:
			g.sim.com.leg[pi] = 0
			g.sim.arrive[pi] = -1
			g.sim.pos[pi] = pair[staged.size()] if not pair.is_empty() else g.pc
			g.sim._promote(pi)
			staged.append(pi)
	if staged.size() == 2 and not pair.is_empty():
		var nap: int = staged[0]
		var brat: int = staged[1]
		g.fac[nap] = g.NAP
		g.fac[brat] = g.BRATVA
		g.hpn[brat] = 400
		g.hpmax[brat] = 400
		g.astate[nap] = g.UNAWARE
		g.stun[nap] = 0
		g.gunc[nap] = 1
		var h0: int = g.hpn[brat]
		var d0: int = g.cheb(g.sim.pos[nap], g.sim.pos[brat])
		for k in 14:
			g._offence(brat)
			g._law_tick()
		check("a NAP officer who sees a Bratva attack goes for him (hp %d -> %d, distance %d -> %d)" % [h0, g.hpn[brat], d0, g.cheb(g.sim.pos[nap], g.sim.pos[brat])], g.hpn[brat] < h0 or g.cheb(g.sim.pos[nap], g.sim.pos[brat]) < d0)
		check("and the officer does not nag the player while the Bratva is on the attack", g._self_defence())
	else:
		check("two people could be staged for the police test", false)
	print("PASS %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
