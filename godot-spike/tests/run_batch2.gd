extends SceneTree
## Batch 2: the character name, Randomize, muted colours, attribute penalties (player and NPCs), combat maths in the log, windows (block movement, not sight, breakable), and the
## BEGIN/BACK fix (play-layer controls ignore the mouse).  Run: godot --headless -s tests/run_batch2.gd
const MainScript = preload("res://src/main.gd")
const GameScript = preload("res://src/game.gd")
const CG = preload("res://src/citygen.gd")
const CR = preload("res://src/creation.gd")
const SK = preload("res://src/skills.gd")
const DS = preload("res://src/dollspec.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _initialize() -> void:
	# ---- name and Randomize (rules)
	check("a name keeps printable characters only, trimmed, at most %d long" % CR.NAME_MAX, CR.clean_name("  Mara\tVoss\n ") == "MaraVoss" and CR.clean_name("x".repeat(40)).length() == CR.NAME_MAX and CR.clean_name("") == "")
	var rr := RandomNumberGenerator.new()
	rr.seed = 5
	var good := true
	var seen := {}
	for i in 200:
		var p: Dictionary = CR.randomized(rr, {"name": "Mara"})
		seen[int(p["app"]["skin"])] = true
		if not CR.profile_valid(p) or CR.free_points(p["attrs"]) != 0 or p["name"] != "Mara":
			good = false
	check("200 randomized profiles: valid, no free points left, the typed name kept", good)
	check("Randomize reaches the muted skin colours too", seen.size() >= 9 and seen.keys().any(func(k): return k >= 5))
	# ---- attribute penalty
	check("the attribute bonus is -1 per 2 below 10, odd values round toward 0 (9:0 8:-1 7:-1 6:-2, 11:0 12:+1 13:+1 14:+2)",
		SK.attr_bonus(9) == 0 and SK.attr_bonus(8) == -1 and SK.attr_bonus(7) == -1 and SK.attr_bonus(6) == -2 and SK.attr_bonus(11) == 0 and SK.attr_bonus(12) == 1 and SK.attr_bonus(13) == 1 and SK.attr_bonus(14) == 2)
	var low := {"str": 6, "per": 6, "agi": 6, "cog": 6, "end": 6}
	check("a skill goes down with low attributes, for every skill", SK.SKILLS.all(func(s): return SK.level(low, {}, s["id"]) == -2 * s["attrs"].size() or s["attrs"].is_empty()))
	var g = GameScript.new(21)
	g.setup(300)
	var pen := 0
	var exact := true
	for i in 300:
		var at: Dictionary = SK.npc_attrs(g.fac[i], g.seed_value, i)
		for sk in ["melee", "dodge", "grit"]:
			var want := 0
			for a in SK.skill(sk)["attrs"]:
				want += (int(at[a]) - 10) / 2
			if SK.bonus(at, sk) != want:
				exact = false
			if want < 0:
				pen += 1
	check("NPC skill bonuses follow the same rule, penalty included (%d negative cases in 300 people)" % pen, exact and pen > 0)
	# ---- colours on NPCs
	var coloured := 0
	var natural := 0
	for i in 400:
		var lk: Dictionary = DS.look(hash([g.seed_value, i]) & 0x7fffffff, i % 2 == 0, 0)
		if DS.SKINS.find(lk["skin"]) >= 5:
			coloured += 1
		else:
			natural += 1
	check("NPCs show both natural and muted-colour skins (%d coloured / %d natural of 400)" % [coloured, natural], coloured > 40 and natural > 150)
	# ---- windows
	var wins := 0
	var gl: int = g.city.tiles.find(CG.GLASS)
	while gl >= 0 and gl < g.s2:
		wins += 1
		gl = g.city.tiles.find(CG.GLASS, gl + 1)
	check("the city has ground-floor windows (%d)" % wins, wins > 20)
	var w := -1
	gl = g.city.tiles.find(CG.GLASS)
	while gl >= 0 and gl < g.s2:
		if g.sim.walk[gl] == 0 and g.sim.opaque[gl] == 0:
			w = gl
			break
		gl = g.city.tiles.find(CG.GLASS, gl + 1)
	check("a window blocks movement and not sight", w >= 0)
	var g2 = GameScript.new(21)
	g2.setup(300)
	check("windows are the same every time for the same seed", g2.city.tiles == g.city.tiles)
	g2.dispose()                                   # (a 512 city is over a gigabyte: let go of each spare game)
	# stand beside it on the open side and strike it
	var stood := false
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var c: int = (w / g.size + d.y) * g.size + w % g.size + d.x
		if g.sim.walk[c] == 1 and g.sim.at[c] == -1 and g.thing_at.g(c) == -1 and g.veh_at.g(c) == -1:
			g.pc = c
			g.last_pc = c
			g._compute_fov()
			var t0: int = g.turn
			var st: bool = g.act_strike(-d.x, -d.y)
			stood = st and g.turn > t0 and g.sim.walk[w] == 1 and g.city.tiles[w] == CG.TID["window_broken"] and g.log.any(func(l): return String(l).contains("shatters"))
			break
	check("striking a window breaks it: a turn passes, the frame is open and the log says so", stood)
	# ---- combat maths in the log
	var tgt := -1
	for i in g.sim.alive.size():
		if g.sim.alive[i] == 1 and g.sim.pos[i] < g.s2:
			tgt = i
			break
	g.log.clear()
	g.melee(tgt)
	check("a melee attack writes its roll and modifiers into the message log", g.log.any(func(l): return String(l).contains("dice ") and String(l).contains("Hits at")))
	# ---- save/load of the name
	g.player_name = "Mara Voss"
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	# (one spare game at a time: a city is over a gigabyte)
	var g3 = GameScript.new(21)
	g3.setup(300)
	g3.load_dict(d)
	var name3: String = g3.player_name
	g3.dispose()
	var g4 = GameScript.new(21)
	g4.setup(300)
	g4.apply_player(JSON.parse_string(JSON.stringify(g.player_dict())))
	var name4: String = g4.player_name
	g4.dispose()
	check("the name survives a save and load and a zone change", name3 == "Mara Voss" and name4 == "Mara Voss")
	# ---- the screen: typing, HUD, mouse filter
	var m = MainScript.new()
	m.save_prefix = "user://test_b2_save_"
	m.settings_path = "user://test_b2_settings.json"
	root.add_child(m)
	for i in 4:
		await process_frame
	m.open_screen("title")
	m.activate("new")
	m.cc_sel = 0
	for ch in "Kit":
		m.key_unicode = ch.unicode_at(0)
		m.screen_key(KEY_A)
	check("typing on the name row fills the name, Backspace deletes", m.cc["name"] == "Kit" and (func():
		m.screen_key(KEY_BACKSPACE)
		return m.cc["name"] == "Ki").call())
	m.cc_randomize()
	check("Randomize keeps the typed name and leaves a valid profile", m.cc["name"] == "Ki" and CR.profile_valid(m.cc))
	m.cc_sel = 12
	m.begin_new(5, m.cc)
	for i in 600:
		await process_frame
		if m.mode == "play":
			break
	check("a game begun from the screen carries the name", m.mode == "play" and m.game.player_name == "Ki")
	var all_ignore := true
	var controls := 0
	for pn in m.play_nodes:
		for ctl in pn.get_children():
			if ctl is Control:
				controls += 1
				if ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					all_ignore = false
	check("every play-layer control (%d) ignores the mouse (BEGIN" % controls + " and BACK on the death-to-new-game screen work)", all_ignore)
	m.game.player_hurt(500, "Test", "phys", "head")
	m.game.end_turn()
	m.refresh()
	m.open_creation()
	m.cc_sel = m.cc_rows().size() - 2
	m.screen_key(KEY_ENTER)
	for i in 600:
		await process_frame
		if m.mode == "play" and not m.game.game_over:
			break
	check("after dying, New Game then Begin starts a fresh game", m.mode == "play" and not m.game.game_over)
	# ---- keys: C movement prompt, Z ammo, X interact; old settings files migrate
	var ST = load("res://src/settings.gd")
	var st = ST.new()
	check("defaults: C movement prompt, Z next ammo, X interact; no crouch or crawl key", st.binds["movement"] == [KEY_C] and st.binds["ammo"] == [KEY_Z] and st.binds["interact"] == [KEY_X] and not st.binds.has("crouch") and not st.binds.has("crawl"))
	var old = ST.new()
	old.from_dict({"binds": {"ammo": [KEY_X], "interact": [KEY_P], "crouch": [KEY_C], "crawl": [KEY_Z], "fire": [KEY_F]}})
	check("an old settings file moves to the new keys, with no key bound twice", old.binds["ammo"] == [KEY_Z] and old.binds["interact"] == [KEY_X] and old.binds["movement"] == [KEY_C] and old.action_for(KEY_X) == "interact" and old.action_for(KEY_Z) == "ammo")
	var ng = GameScript.new(21)
	ng.setup(300)
	var mv_ok := true
	for want in [[0, 0, false], [1, 1, false], [2, 2, false], [3, 2, true]]:
		ng.set_movement(want[0])
		mv_ok = mv_ok and ng.stance == want[1] and ng.run_mode == want[2]
	var sv: Dictionary = JSON.parse_string(JSON.stringify(ng.player_dict()))
	var ng2 = GameScript.new(21)
	ng2.setup(300)
	ng2.apply_player(sv)
	check("the movement prompt sets crawl, crouch, walk or run (run stays on) and run is carried to another zone (a loaded save, like stance, starts walking)", mv_ok and ng2.run_mode and ng2.stance == 2)
	ng2.dispose()                                   # (a 512 city is over a gigabyte: let go of each spare game)
	ng.set_movement(1)
	check("choosing crouch turns running off", not ng.run_mode and ng.stance == 1)
	ng.dispose()                                   # (a 512 city is over a gigabyte: let go of each spare game)
	# ---- the real key path: C opens the prompt, 4 runs, X with nothing near says so
	m.mode = "play"
	m.game.game_over = false
	var press = func(k: int) -> void:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = true
		m._unhandled_key_input(ev)
	press.call(KEY_C)
	var opened: bool = m.mode == "movemenu"
	press.call(KEY_4)
	check("C opens the movement prompt and 4 chooses Run (no turn spent)", opened and m.mode == "play" and m.game.run_mode)
	press.call(KEY_C)
	press.call(KEY_ESCAPE)
	check("Esc leaves the prompt unchanged", m.mode == "play" and m.game.run_mode)
	print("TWEAKS %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
