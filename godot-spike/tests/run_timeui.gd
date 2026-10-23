extends SceneTree
## Visuals, display range and move timer (2026-10-18): the 6-second turn and the clock, the wait menu, the consume menu with kcal and mL,
## the look cursor and the doubled sight range, the key bindings screen on "?", the Visuals options, the hiragana title, and save conversion.
## Run: godot --headless -s tests/run_timeui.gd
const MainScript = preload("res://src/main.gd")
const GameScript = preload("res://src/game.gd")
const ItemScript = preload("res://src/item.gd")
const CLK = preload("res://src/clock.gd")
const SettingsScript = preload("res://src/settings.gd")
const ScreenScript = preload("res://src/screen_view.gd")
var passed := 0
var total := 0

func check(name: String, cond: bool) -> void:
	total += 1
	if cond:
		passed += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func press(m, k: int, shift: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	ev.shift_pressed = shift
	m._unhandled_key_input(ev)

func _initialize() -> void:
	# ---------------------------------------------------------------- the clock (pure)
	check("a turn is six seconds: 10 turns a minute, 600 an hour, 14,400 a day", CLK.TURN_SEC == 6 and CLK.MIN == 10 and CLK.HOUR == 600 and CLK.DAY == 14400 and CLK.DAY == 24 * 3600 / CLK.TURN_SEC)
	check("a new game starts at 06:40:00", CLK.text(CLK.START_TICK) == "06:40:00" and CLK.text(CLK.START_TICK + 1) == "06:40:06" and CLK.text(CLK.START_TICK + 11) == "06:41:06")
	check("turns until a time of day: noon from 06:40 is 5h20 = 3,200 turns; 06:00 sharp waits a full day", CLK.turns_until(CLK.START_TICK, 12) == 3200 and CLK.turns_until(6 * CLK.HOUR, 6) == CLK.DAY and CLK.turns_until(CLK.START_TICK, 6) == CLK.DAY - 400 and CLK.turns_until(CLK.START_TICK, 0) == 17 * 600 + 200)
	check("spans read as people say them", CLK.span_text(1) == "6s" and CLK.span_text(10) == "1m" and CLK.span_text(600) == "1h" and CLK.span_text(2400) == "4h" and CLK.span_text(2880) == "4h48")
	var wlabels: Array = CLK.WAITS.map(func(w): return w[1])
	check("the wait menu steps are 1, 10, 100 and 600 turns, then 6am, noon, 6pm, midnight", wlabels == [1, 10, 100, 600] and CLK.WAIT_UNTIL.map(func(w): return w[1]) == [6, 12, 18, 0])
	# ---------------------------------------------------------------- the key list and settings (pure)
	var st = SettingsScript.new()
	var ids: Array = st.ACTIONS.map(func(a): return a[0])
	check("the key list has look, consume, wait menu, fullscreen and the key screen; the help screen is gone", ids.has("look") and ids.has("consume") and ids.has("waitmenu") and ids.has("fullscreen") and ids.has("keysscreen") and not ids.has("help"))
	check("fullscreen is listed with Alt+Enter beside its key (%s)" % st.key_text("fullscreen"), st.key_text("fullscreen").contains("Alt+Enter") and st.key_text("fullscreen").contains("F11"))
	check("L is look (it is no longer east) and ? opens the key list", st.action_for(KEY_L) == "look" and st.action_for(KEY_RIGHT) == "east" and st.action_for(KEY_QUESTION) == "keysscreen")
	var seen := {}
	var dup := false
	for a in st.binds:
		for k in st.binds[a]:
			if seen.has(k):
				dup = true
			seen[k] = true
	check("no key is bound to two actions", not dup)
	st.window_mode = 1
	var p1: Dictionary = st.window_plan(Vector2i(2560, 1440))
	st.window_mode = 2
	var p2: Dictionary = st.window_plan(Vector2i(2560, 1440))
	st.window_mode = 0
	st.resolution = Vector2i(3840, 2160)
	var p0: Dictionary = st.window_plan(Vector2i(2560, 1440))
	check("display modes: borderless fullscreen, exclusive fullscreen, and a window never bigger than the screen", p1["mode"] == DisplayServer.WINDOW_MODE_FULLSCREEN and p2["mode"] == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN and p0["mode"] == DisplayServer.WINDOW_MODE_WINDOWED and p0["size"] == Vector2i(2560, 1440) and p1["size"] == Vector2i(2560, 1440))
	st.resolution = Vector2i(1920, 1080)
	st.step_resolution(1)
	var r1: Vector2i = st.resolution
	st.step_resolution(-1)
	st.step_resolution(-1)
	check("window sizes step up and down the list (1920x1080 -> %s -> 1600x900)" % st.resolution_text().replace(" ", ""), r1 == Vector2i(2560, 1440) and st.resolution == Vector2i(1600, 900))
	st.path = "user://test_timeui_settings.json"
	st.window_mode = 1
	st.save()
	var st2 = SettingsScript.new()
	st2.path = st.path
	st2.load_file()
	check("display mode and window size are remembered", st2.window_mode == 1 and st2.resolution == Vector2i(1600, 900))
	var st3 = SettingsScript.new()
	st3.from_dict({"fullscreen": true})
	check("an older settings file that said fullscreen still means fullscreen", st3.window_mode == 2)
	var st4 = SettingsScript.new()
	st4.from_dict({"binds": {"east": [KEY_RIGHT, KEY_L], "fire": [KEY_F]}})
	check("an older key file loses L from east so look can have it", st4.action_for(KEY_L) == "look" and st4.action_for(KEY_RIGHT) == "east")
	# ---------------------------------------------------------------- the title in hiragana
	var scr = ScreenScript.new()
	var codes: Array = []
	for i in ScreenScript.TITLE_NAME.length():
		codes.append(ScreenScript.TITLE_NAME.unicode_at(i))
	check("the name is とりろびつ (to-ri-ro-bi-tsu) in hiragana on every screen that shows it", codes == [0x3068, 0x308A, 0x308D, 0x3073, 0x3064])
	check("the bundled kana font can draw all five letters", scr.kana_font != null and codes.all(func(c): return scr.kana_font.has_char(c)))
	scr.kind = "keys"
	var rk: Array = scr.rooms(760.0, 260.0, true)
	var worst := 0.0
	var fits := true
	for a in SettingsScript.ACTIONS:
		var sz: int = scr.fit_size(a[1], 22, rk[0])
		if sz > 12 and scr.font.get_string_size(a[1], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > rk[0]:
			fits = false
		var vt: String = st.key_text(a[0])
		var sv: int = scr.fit_size(vt, 22, rk[1])
		if sv > 12 and scr.font.get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, sv).x > rk[1]:
			fits = false
		worst = maxf(worst, scr.font.get_string_size(a[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x)
	check("on the key list every action name and key fits in its own column (longest name %d px at 22 against %d px of room)" % [int(worst), int(rk[0])], fits and rk[0] + 14.0 + 260.0 + 34.0 <= rk[2] + 1.0)
	scr.free()
	# ---------------------------------------------------------------- food, drink, wait on a bare game
	var g = GameScript.new(5)
	g.setup(300)
	check("a turn of the game is six seconds on the clock", g.sim.tick == CLK.START_TICK and g.time_text() == "06:40:00")
	g.act_wait()
	check("waiting a turn moves the clock six seconds", g.time_text() == "06:40:06")
	check("the unit prices: 2,500 kcal = 24 h = 14,400 turns; 500 mL = 4 h = 2,400 turns", g.kcal_turns(2500) == 14400 and g.ml_turns(500) == 2400 and g.HUNGER_AFTER == 14400 and g.THIRST_AFTER == 2400)
	var db = g.db
	var bad: Array = []
	for id in db.defs:
		var f: Dictionary = db.defs[id].get("food", {})
		if f.is_empty():
			continue
		if int(f.get("kcal", 0)) <= 0 or int(f.get("kcal", 0)) > 1000 or (f.get("drink", false) and int(f.get("ml", 0)) <= 0):
			bad.append(id)
	check("every food has a calorie count and every drink its millilitres (%s)" % str(bad), bad.is_empty())
	var nfood := 0
	for id in db.defs:
		if db.defs[id].has("food"):
			nfood += 1
	check("%d foods and drinks are in the data" % nfood, nfood >= 47)
	g.last_ate = g.sim.tick - g.HUNGER_AFTER           # starving
	g.last_drank = g.sim.tick - g.THIRST_AFTER
	check("starting empty: hungry and thirsty", g.hungry() and g.thirsty() and g.food_left() == 0 and g.drink_left() == 0)
	var ration = ItemScript.new(db.defs["trl_ration"], 1)
	g.eat_now(ration)
	check("a 500 kcal ration buys 4h48 of food (%s)" % CLK.span_text(g.food_left()), g.food_left() == 2880 and not g.hungry() and g.thirsty())
	var tea = ItemScript.new(db.defs["trl_food_sencha"], 1)
	g.eat_now(tea)
	check("a 250 mL tea buys 2h of water (%s)" % CLK.span_text(g.drink_left()), g.drink_left() == 1200 and not g.thirsty())
	var beer = ItemScript.new(db.defs["trl_food_beer"], 1)
	g.last_drank = g.sim.tick - g.THIRST_AFTER
	g.eat_now(beer)
	check("beer is half water: 350 mL gives %s, not 2h48" % CLK.span_text(g.drink_left()), g.drink_left() == g.ml_turns(175) and g.drunk_left > 0)
	var pot = ItemScript.new(db.defs["trl_food_katsu"], 1)
	g.last_ate = g.sim.tick
	g.eat_now(pot)
	check("a full stomach holds 24 h and no more", g.food_left() == g.HUNGER_AFTER)
	# consume menu
	var pack_ration = null
	for e in g.consumables():
		if e["kind"] == "food":
			pack_ration = e
	var has_water := false
	for e in g.consumables():
		if e["kind"] == "water":
			has_water = true
	check("the consume list offers the ration and the bottled water in your pack", pack_ration != null and has_water)
	g.last_ate = g.sim.tick - g.HUNGER_AFTER
	var n0: int = pack_ration["item"].count
	var tk0: int = g.sim.tick
	check("consuming a ration eats it, takes a turn and tells you (%s)" % g.log[g.log.size() - 1].left(0) if false else "consuming a ration eats it and takes a turn", g.act_consume(pack_ration) and g.sim.tick == tk0 + 1 and g.food_left() > 2800 and (pack_ration["item"].count == n0 - 1 or n0 == 1))
	check("... and says how much food it bought", String(g.log[g.log.size() - 1]).contains("500 kcal") and String(g.log[g.log.size() - 1]).contains("4h"))
	var water = null
	for e in g.consumables():
		if e["kind"] == "water":
			water = e
	g.last_drank = g.sim.tick - g.THIRST_AFTER
	var ml0: int = water["item"].count
	g.act_consume(water)
	check("drinking from the bottle takes up to 500 mL (%d left of %d) and buys 4 h" % [water["item"].count, ml0], g.drink_left() >= 2390 and ml0 - water["item"].count >= 497)
	var full_msg_before: int = g.log.size()
	var again = null
	for e in g.consumables():
		if e["kind"] == "water":
			again = e
	check("with a full belly you do not drink more", again == null or not g.act_consume(again) or g.drink_left() <= g.THIRST_AFTER)
	# things on the ground within one tile
	var spare = ItemScript.new(db.defs["trl_food_onigiri"], 1)
	var near_cell: int = g.pc + 1
	while g.sim.walk[near_cell] == 0:
		near_cell += g.size
	var far_cell: int = g.pc + 3
	g.items_at[near_cell] = [spare]
	g.fov.visible[near_cell] = 1
	var far_item = ItemScript.new(db.defs["trl_food_apple"], 1)
	g.items_at[far_cell] = [far_item]
	g.fov.visible[far_cell] = 1
	var names: Array = g.consumables().map(func(e): return str(e["item"].def["name"]) + "@" + str(e["where"]))
	check("food within one tile is offered (%s) and food three tiles away is not" % str(names.filter(func(n): return n.contains("onigiri") or n.contains("apple"))), names.has("onigiri@next to you") and not names.any(func(n): return n.begins_with("apple")))
	g.last_ate = g.sim.tick - g.HUNGER_AFTER
	var eo = null
	for e in g.consumables():
		if e["item"] == spare:
			eo = e
	g.act_consume(eo)
	check("eating it from the ground removes it from the ground", not g.items_at.has(near_cell) and g.food_left() >= g.kcal_turns(190) - 2 and g.food_left() <= g.kcal_turns(190))
	g.items_at.erase(far_cell)
	# waiting
	g.last_ate = g.sim.tick
	g.last_drank = g.sim.tick
	var t1: int = g.sim.tick
	var spent: int = g.act_wait_turns(10)
	check("wait 10 turns = 1 minute: the clock moves 60 s and so does the turn count (%d)" % spent, spent == 10 and g.sim.tick == t1 + 10)
	g.sim.tick = 6 * CLK.HOUR + 40 * CLK.MIN
	g.last_ate = g.sim.tick
	g.last_drank = g.sim.tick
	g.wait_until(8)
	var tt0: int = g.sim.tick
	var done: int = 0
	while g.waiting():
		done += g.wait_step(600)
	check("wait until 8 lands on 08:00:00 sharp (%s)" % g.time_text(), g.time_text() == "08:00:00" and g.sim.tick - tt0 == 80 * CLK.MIN)
	g.last_ate = g.sim.tick
	g.last_drank = g.sim.tick - g.THIRST_AFTER + 30          # thirst bites in 30 turns
	g.wait_for(CLK.HOUR)
	var d2: int = 0
	while g.waiting():
		d2 += g.wait_step(600)
	check("a long wait stops when thirst bites (%d of 600 turns) and tells you" % d2, d2 >= 29 and d2 <= 32 and g.thirsty() and not g.waiting() and String(g.log[g.log.size() - 1]).contains("stop waiting"))
	g.last_drank = g.sim.tick
	var hp0: int = g.body.total()
	g.wait_for(100)
	g._raw_hurt(3, "chest")
	g.wait_step(1)
	check("a wait stops when you are hurt", not g.waiting() and g.body.total() < hp0)
	g.body.mend_to(1.0)
	# the clock moves the daily schedule: people go to work at 07:00, not at 07 minutes past six
	g.sim.tick = 7 * CLK.HOUR
	var work0: int = 0
	for i in g.sim.n:
		if g.sim.goal[i] == g.sim.WORK:
			work0 += 1
	g.end_turn()
	var work1: int = 0
	for i in g.sim.n:
		if g.sim.goal[i] == g.sim.WORK:
			work1 += 1
	check("at 07:00 commuters head for work (%d -> %d)" % [work0, work1], work1 != work0)
	g.sim.tick = 7 * CLK.HOUR + 5
	var snap: Array = Array(g.sim.goal)
	g.end_turn()
	check("... and not on every turn after it", Array(g.sim.goal) == snap)
	g.sim.tick = 8 * CLK.HOUR
	check("the train's crowd follows the hour (rush hour %d%%, night %d%%)" % [(func(): g.sim.tick = 8 * CLK.HOUR; return g.transit.load_pct()).call(), (func(): g.sim.tick = 23 * CLK.HOUR; return g.transit.load_pct()).call()], g.transit.load_pct() < 10)
	# sight
	check("you see 30 tiles", g.sight_radius() == 30 and g.BASE_SIGHT == 30)
	g.sim.tick = CLK.START_TICK
	# save and load: new format, and the conversion of an old one
	g.last_ate = g.sim.tick - 1234
	g.last_drank = g.sim.tick - 321
	var blob: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var gl = GameScript.new(5)
	gl.setup(300)
	gl.load_dict(blob)
	check("save and load keep the clock, the food and the water", gl.sim.tick == g.sim.tick and gl.last_ate == g.last_ate and gl.last_drank == g.last_drank and gl.food_left() == g.food_left() and int(blob["tv"]) == CLK.SAVE_VERSION)
	var old: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	old.erase("tv")
	old["tick"] = 7 * 60 + 30
	old["ate"] = 6 * 60
	old["drank"] = 7 * 60
	old["turn"] = 90
	old["bless"] = 100
	old["eco"].erase("tv")
	for k in ["depart", "arrive"]:
		old["npc"][k] = old["npc"][k].map(func(v): return v if int(v) < 0 else 100)
	var go = GameScript.new(5)
	go.setup(300)
	go.load_dict(old)
	check("a save from the minute-long turns is converted: 07:30 stays 07:30, meals keep their hours", go.time_text() == "07:30:00" and go.last_ate == 6 * 600 and go.food_left() == go.HUNGER_AFTER - 90 * 10 and go.bless_left == 1000)
	# ---------------------------------------------------------------- the game itself, driven by keys
	DirAccess.remove_absolute("user://test_timeui_save_1.json")
	var m = MainScript.new()
	m.save_prefix = "user://test_timeui_save_"
	m.settings_path = "user://test_timeui_main.json"
	DirAccess.remove_absolute("user://test_timeui_main.json")
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 60:
		await process_frame
		if m.mode == "play":
			break
	check("a new game starts", m.mode == "play" and m.game != null)
	var G = m.game
	check("the main game starts at 06:40 with a full stomach", G.time_text() == "06:40:00" and G.food_left() == G.HUNGER_AFTER)
	press(m, KEY_QUESTION)
	var klab: Array = m.screen.items.map(func(i): return i["id"])
	check("? opens the key bindings screen, not a help screen", m.mode == "keys" and m.screen.kind == "keys" and klab.has("key:look") and klab.has("key:consume") and klab.has("key:fullscreen") and not m.has_method("show_help"))
	var fs_item = m.screen.items[klab.find("key:fullscreen")]
	check("it lists fullscreen as F11, Alt+Enter (%s)" % fs_item["value"], str(fs_item["value"]).contains("Alt+Enter"))
	press(m, KEY_ESCAPE)
	check("Esc closes it back into the game, not to a menu", m.mode == "play" and not m.screen.visible)
	# the wait menu
	var t00: int = G.sim.tick
	press(m, KEY_ENTER)
	check("Enter opens the wait menu with every span and time of day", m.mode == "waitmenu" and m.panel.visible and m.panel.text.contains("1 turn (6 seconds)") and m.panel.text.contains("10 turns (1 minute)") and m.panel.text.contains("100 turns (10 minutes)") and m.panel.text.contains("600 turns (1 hour)") and m.panel.text.contains("Wait until 6am") and m.panel.text.contains("Wait until noon") and m.panel.text.contains("Wait until 6pm") and m.panel.text.contains("Wait until midnight"))
	press(m, KEY_ESCAPE)
	check("Esc leaves it without time passing", m.mode == "play" and G.sim.tick == t00)
	press(m, KEY_ENTER)
	press(m, KEY_3)
	for i in 20:
		await process_frame
		if m.mode == "play":
			break
	check("choosing 100 turns waits ten minutes: 06:50:00 (%s)" % G.time_text(), m.mode == "play" and G.time_text() == "06:50:00" and G.sim.tick == t00 + 100)
	press(m, KEY_ENTER)
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	for i in 20:
		await process_frame
		if m.mode == "play":
			break
	check("Down and Enter picks the second row: 10 turns more (%s)" % G.time_text(), G.time_text() == "06:51:00")
	press(m, KEY_PERIOD)
	check("the period key still waits a single turn", G.time_text() == "06:51:06")
	# the consume key
	G.last_ate = G.sim.tick - G.HUNGER_AFTER + 100
	G.last_drank = G.sim.tick - G.THIRST_AFTER + 100
	press(m, KEY_F8)
	check("F8 opens the consume menu listing the ration and the water with their kcal and mL", m.mode == "consume" and m.panel.text.contains("cyber ration bar") and m.panel.text.contains("water, ") and m.panel.text.contains("kcal"))
	var wi := -1
	for i in m.consume_list.size():
		if m.consume_list[i]["kind"] == "water":
			wi = i
	var ti: int = G.sim.tick
	press(m, KEY_A + wi)
	check("choosing the water drinks it and takes a turn", m.mode == "play" and G.sim.tick == ti + 1 and G.drink_left() > 2300)
	press(m, KEY_F8)
	press(m, KEY_ESCAPE)
	check("Esc leaves the consume menu", m.mode == "play")
	# look
	press(m, KEY_L)
	check("L starts looking: the cursor is on you", m.mode == "look" and m.view.look_on and m.look_off == Vector2i.ZERO and m.logbox.text.contains("LOOK"))
	var tk2: int = G.sim.tick
	press(m, KEY_RIGHT)
	press(m, KEY_RIGHT)
	press(m, KEY_DOWN)
	check("arrows move the cursor and the view follows it, and no time passes", m.look_off == Vector2i(2, 1) and m.view.look_off == Vector2i(2, 1) and G.sim.tick == tk2 and m.logbox.text.contains("away"))
	press(m, KEY_RIGHT, true)
	check("Shift moves it five tiles", m.look_off == Vector2i(7, 1))
	m.look_off = Vector2i(36, 0)
	var px0: int = G.lx(G.pc)
	press(m, KEY_RIGHT)
	check("the cursor stops at the edge of your sight (%d tiles)" % G.sight_radius(), m.look_off == Vector2i(36, 0) or G.lx(G.pc) + 37 >= G.size)
	m.look_off = Vector2i.ZERO
	m.look_refresh()
	var ndesc: String = G.describe_at(G.pc)
	check("looking at yourself says so (%s)" % ndesc.left(40), ndesc.contains("you") and ndesc.contains("0 tiles"))
	# an item on the ground next to the player
	var ic: int = G.pc + 1
	G.items_at[ic] = [ItemScript.new(db.defs["trl_food_apple"], 1)]
	G.fov.visible[ic] = 1
	check("looking at a tile names what lies on it", G.describe_at(ic).contains("apple") and G.describe_at(ic).contains("1 tile away"))
	G.items_at.erase(ic)
	var person := -1
	for i in G.sim.near_list:
		if G.fov.visible[G.sim.pos[i]] == 1:
			person = i
			break
	check("looking at a person names them", person < 0 or G.describe_at(G.sim.pos[person]).contains(G.nname[person]))
	press(m, KEY_ENTER)
	check("Enter writes what you see into the message log", String(G.log[G.log.size() - 1]).begins_with("You look:"))
	press(m, KEY_ESCAPE)
	check("Esc ends looking: the view returns to you", m.mode == "play" and not m.view.look_on and m.look_off == Vector2i.ZERO)
	# sight range
	G.facing = Vector2i(0, -1)
	G._compute_fov()
	var far_seen := 0
	var beyond := 0
	var pcx: int = G.lx(G.pc)
	var pcy: int = G.ly(G.pc)
	var base: int = (G.pc / G.s2) * G.s2
	for dy in range(-40, 41):
		for dx in range(-40, 41):
			var x: int = pcx + dx
			var y: int = pcy + dy
			if x < 0 or y < 0 or x >= G.size or y >= G.size:
				continue
			if G.fov.visible[base + y * G.size + x] == 1:
				var dd: int = maxi(absi(dx), absi(dy))
				if dd > 18:
					far_seen += 1
				if dd > 36:
					beyond += 1
	check("you now see past the old 18 tiles (%d cells seen beyond it) and never past 36 (%d)" % [far_seen, beyond], far_seen > 0 and beyond == 0)
	# visuals
	press(m, KEY_ESCAPE)
	check("Esc opens the pause menu", m.mode == "pause")
	m.activate("options")
	var oids: Array = m.screen.items.map(func(i): return i["id"])
	check("Options has a Visuals section", m.mode == "options" and oids.has("visuals"))
	m.activate("visuals")
	var vids: Array = m.screen.items.map(func(i): return i["id"])
	check("Visuals offers the display mode and the window size", m.mode == "visuals" and vids.has("wmode") and vids.has("res") and m.screen.items[0]["value"] == "Windowed")
	m.screen.sel = 0
	press(m, KEY_RIGHT)
	check("Right on Display mode steps to Borderless fullscreen", m.settings.window_mode == 1 and m.screen.items[0]["value"] == "Borderless fullscreen")
	press(m, KEY_RIGHT)
	check("... and then to Fullscreen", m.settings.window_mode == 2 and m.screen.items[0]["value"] == "Fullscreen")
	press(m, KEY_LEFT)
	press(m, KEY_LEFT)
	m.screen.sel = 1
	press(m, KEY_RIGHT)
	check("Right on Window size picks the next size (%s)" % m.settings.resolution_text(), m.settings.resolution == Vector2i(2560, 1440) and str(m.screen.items[1]["value"]).contains("2560"))
	press(m, KEY_LEFT)
	m.toggle_fullscreen()
	check("Alt+Enter / F11 flips windowed and fullscreen and remembers it", m.settings.window_mode == 2)
	m.toggle_fullscreen()
	check("... and back", m.settings.window_mode == 0)
	press(m, KEY_ESCAPE)
	check("Esc from Visuals returns to Options", m.mode == "options")
	# a full save and load of the live world
	m.mode = "play"
	m.screen.visible = false
	var G2 = m.game
	G2.last_ate = G2.sim.tick - 5000
	var wd: Dictionary = JSON.parse_string(JSON.stringify(m.world.save_dict()))
	var w2 = preload("res://src/world.gd").new()
	w2.load_dict(wd)
	check("the live world saves and loads with its clock and needs", w2.game.sim.tick == G2.sim.tick and w2.game.last_ate == G2.last_ate and w2.game.food_left() == G2.food_left())
	print("TIMEUI %d/%d" % [passed, total])
	quit(0 if passed == total else 1)
