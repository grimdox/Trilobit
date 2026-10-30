extends SceneTree
## the TEST--- title button and its scenarios:  godot --headless -s tests/run_scenarios.gd
const MainScript = preload("res://src/main.gd")
const GameScript = preload("res://src/game.gd")
var ok := 0
var n := 0
func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	var labels: Array = m.screen.items.map(func(i): return i["label"])
	check("the title has a TEST--- button, between Options and Exit (%s)" % str(labels), labels.has("TEST---") and labels.find("TEST---") == labels.find("Options") + 1 and labels.back() == "Exit")
	m.activate("test")
	check("TEST--- opens the scenario list", m.mode == "test" and m.screen.kind == "test")
	var ids: Array = m.screen.items.map(func(i): return i["id"])
	check("it lists Large City (3072) first, and Back", ids[0] == "scn:large_city" and ids.has("back") and String(m.screen.items[0]["label"]).contains("3072"))
	check("and a Large City (2560) beneath it", ids[1] == "scn:city_2560" and String(m.screen.items[1]["label"]).contains("2560"))
	m.back_from_screen()
	check("Esc / Back returns to the title", m.mode == "title" and m.screen.kind == "title")
	# the size plumbing, on a small city so the test is quick
	var g = GameScript.new(5)
	g.test_size = 192
	g.setup(60)
	check("a stand-alone game builds the city at the test size (%d)" % g.size, g.size == 192 and g.city.size == 192 and g.island == null)
	var d: Dictionary = g.save_dict()
	check("the size is saved", int(d["test_size"]) == 192)
	var g2 = GameScript.new(5)
	g2.load_dict(JSON.parse_string(JSON.stringify(d)))
	check("a load rebuilds the same size of city", g2.size == 192)
	var g3 = GameScript.new(5)
	g3.setup(60)
	check("the usual stand-alone city is still 512", g3.size == 512)
	print("SCENARIOS %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
