extends SceneTree
## the network scan screen as drawn, under a virtual display: xvfb-run godot --path . --rendering-driver opengl3 -s tests/shot_net.gd
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 60:
		await process_frame
	var g = m.game
	g.implants["x303"] = true
	g._sync_pools()
	g.NW.build_snapshot(g)
	m.mode = "netscan"
	m.refresh()
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/claude-0/shot_net.png")
	print("saved ", g.net_snap.size())
	quit()
