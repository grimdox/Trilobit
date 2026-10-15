extends SceneTree
## Renders the real main scene under a virtual display and saves screenshots.  usage: xvfb-run godot --path . --rendering-driver opengl3 -s tests/shot.gd
func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	main.game.sim.tick = 8 * 60
	for k in 25:
		main.game.act_wait()
	main.refresh()
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("/tmp/claude-0/shot_play.png")
	main.mode = "inventory"
	main.refresh()
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("/tmp/claude-0/shot_inv.png")
	print("shots saved")
	quit()
