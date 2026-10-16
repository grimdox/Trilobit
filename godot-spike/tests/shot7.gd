extends SceneTree
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 80:
		await process_frame
	var g = m.game
	print("vehicles ", g.vehicles.size(), " player ", g.pc % g.size, ",", g.pc / g.size)
	# stand next to the nearest car and shoot a frame
	var best := -1
	var bd := 1 << 30
	for vi in g.vehicles.size():
		var v = g.vehicles[vi]
		if v["kind"] == "car":
			var d: int = g.cheb(v["cell"], g.pc)
			if d < bd and d > 3:
				bd = d
				best = vi
	var v = g.vehicles[best]
	var ap: int = v["cell"]
	g.pc = ap + 5
	g.sim.retier(g.pc)
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	m.refresh()
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_cars.png")
	quit(0)
