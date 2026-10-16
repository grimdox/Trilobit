extends SceneTree
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_new(11)
	for i in 120:
		await process_frame
	var g = m.game
	# go to the west edge of the city on the main street, then cross
	g.pc = (g.size / 2 - 4) * g.size + 30
	g.sim.retier(g.pc)
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	m.refresh()
	await process_frame
	g.pc = (g.size / 2 - 4) * g.size + 22
	m.refresh()
	for i in 90:
		await process_frame
	print("zone now ", m.game.zone)
	m.game.fov.compute(m.game.pc % m.game.size, m.game.pc / m.game.size, 18)
	m.refresh()
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_border.png")
	m.open_screen("map")
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_map.png")
	quit(0)
