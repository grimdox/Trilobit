extends SceneTree
## godot -s tests/shot_fix.gd -- out_prefix : the street outside some shops with their signs and the minimap; then the local map.
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	var w = WorldScript.new()
	w.start(21, 300)
	m.world = w
	m.start_play(w.game)
	await process_frame
	var g = w.game
	var pick := -1
	for s in g.city.signs:
		if s["kind"] == "biz" and s["type"] in ["noodle_stall", "cyberdoc", "pharmacy", "bar"]:
			pick = int(s["cell"])
			break
	g.pc = pick
	g.last_pc = pick
	g.sim.player = pick
	for dy in range(-40, 41):
		for dx in range(-70, 71):
			var c: int = pick + dy * g.size + dx
			if c > 0 and c < g.s2:
				g.fov.explored[c] = 1
	g.act_wait()
	g._compute_fov()
	m.refresh()
	for k in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "_world.png")
	m.open_tab("map")
	for k in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "_map.png")
	quit()
