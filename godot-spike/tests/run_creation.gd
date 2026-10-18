extends SceneTree
## Character creation.  The rules and screen flow are in test_creation.gd; the live check builds a real world from a finished profile and plays a turn.
const MainScript = preload("res://src/main.gd")
const CR = preload("res://src/creation.gd")
func _initialize() -> void:
	var r = preload("res://tests/test_creation.gd").new().run()
	for l in r[2]:
		print(l)
	var ok: int = r[0]
	var n: int = r[1]
	var m = MainScript.new()
	m.save_prefix = "user://test_cc_save_"
	m.settings_path = "user://test_cc_settings.json"
	root.add_child(m)
	for i in 4:
		await process_frame
	var st := [ok, n]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		print(("  PASS " if cond else "  FAIL ") + name)
	m.open_screen("title")
	m.activate("new")
	check.call("New Game opens the creation screen and does not start the world", m.mode == "create" and m.game == null and m.screen.kind == "create")
	check.call("the screen starts with the default look and all attributes at 10", m.cc["app"] == CR.default_app() and m.cc["attrs"] == CR.start_attrs())
	check.call("rows: five appearance, five attributes, Begin, Back (twelve)", m.cc_rows().size() == 12 and m.screen.cc_rows() == 12)
	m.screen_key(KEY_DOWN)
	check.call("Down moves the highlight along the rows", m.cc_sel == 1 and m.cc_rows()[1]["kind"] == "look")
	m.screen_key(KEY_RIGHT)
	check.call("Right on a look row steps its option", m.cc["app"]["skin"] == 1)
	m.screen_key(KEY_LEFT)
	check.call("Left steps it back", m.cc["app"]["skin"] == 0)
	m.cc_sel = 5
	m.screen_key(KEY_RIGHT)
	check.call("Right on Strength with no free points is refused with a message", m.cc["attrs"]["str"] == 10 and m.screen.prompt.contains("free point"))
	m.cc_sel = 8
	m.screen_key(KEY_LEFT)
	check.call("Left on Cognition frees a point", m.cc["attrs"]["cog"] == 9 and CR.free_points(m.cc["attrs"]) == 1)
	m.cc_sel = 10
	m.screen_key(KEY_ENTER)
	check.call("Begin is refused while a point is unspent (still on the creation screen)", m.mode == "create" and m.game == null and m.screen.prompt.contains("free point"))
	m.cc_sel = 5
	m.screen_key(KEY_RIGHT)
	check.call("Strength takes the point and the pool is empty", m.cc["attrs"]["str"] == 11 and CR.free_points(m.cc["attrs"]) == 0)
	m.cc_sel = 9
	for i in 8:
		m.screen_key(KEY_LEFT)
	check.call("holding Left on Endurance stops at 6", m.cc["attrs"]["end"] == 6 and CR.free_points(m.cc["attrs"]) == 4)
	m.cc_sel = 2
	m.screen_key(KEY_TAB)
	check.call("Tab jumps from the appearance rows to the attributes, then to the buttons, then back", m.cc_sel == 5)
	m.screen_key(KEY_TAB)
	check.call("second Tab reaches Begin", m.cc_sel == 10)
	m.screen_key(KEY_TAB)
	check.call("third Tab returns to the top", m.cc_sel == 0)
	var hit: Dictionary = m.screen.cc_hit(m.screen.cc_row_rect(6).position + Vector2(8, 20))
	check.call("the mouse hit-test finds the minus zone of Perception", hit["row"] == 6 and hit["dir"] == -1)
	hit = m.screen.cc_hit(m.screen.cc_row_rect(6).end - Vector2(8, 20))
	check.call("and the plus zone", hit["row"] == 6 and hit["dir"] == 1)
	var fits := true
	for i in m.screen.cc_rows():
		var rect: Rect2 = m.screen.cc_row_rect(i)
		if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > 1280 or rect.end.y > 720:
			fits = false
	check.call("every row sits inside the 1280x720 screen", fits)
	m.screen_key(KEY_ESCAPE)
	check.call("Esc goes back to the title", m.mode == "title")

	ok = st[0]
	n = st[1]
	m.open_screen("title")
	m.open_creation()
	var prof: Dictionary = m.cc.duplicate(true)
	prof["attrs"] = {"str": 14, "per": 12, "agi": 6, "cog": 10, "end": 8}
	prof["app"] = CR.cycle(CR.cycle(prof["app"], "skin", 4), "hair", 2)
	m.cc = prof
	m.cc_begin()
	var shown: bool = m.mode == "loading"
	for i in 80:
		await process_frame
		if m.mode == "play":
			break
	var g = m.game
	var checks: Array = [
		["Begin builds the world and starts play", shown and m.mode == "play" and g != null],
		["the new game's player has the chosen attributes", g != null and g.attrs == prof["attrs"]],
		["and the chosen look", g != null and g.app["skin"] == 4 and g.app["hair"] == 6],
		["a turn passes with the chosen character", g != null and (func():
			var t0: int = g.turn
			g.end_turn()
			return g.turn > t0).call()],
		["the chosen look is what the player's doll is built from", g != null and m.view != null and preload("res://src/dollspec.gd").for_player(g)["look"]["skin"] == preload("res://src/dollspec.gd").SKINS[4]],
	]
	for c in checks:
		n += 1
		if c[1]:
			ok += 1
			print("  PASS " + c[0])
		else:
			print("  FAIL " + c[0])
	print("CREATION %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
