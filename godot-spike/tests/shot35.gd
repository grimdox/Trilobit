extends SceneTree
## screenshot of the barter screen
func _init() -> void:
	var m = load("res://src/main.gd").new()
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 5:
		await process_frame
	var g = m.world.game
	m.game = g
	var vend := -1
	for i in g.sim.n:
		if g.eco.role[i] == g.eco.VENDOR:
			vend = i
			break
	g.yen = 12345
	m.open_barter(vend)
	for i in 3:
		await process_frame
	m._barter_key(KEY_DOWN)
	m._barter_key(KEY_RIGHT)
	for i in 3:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/n_barter.png")
	print("MODE ", m.mode)
	m._barter_key(KEY_ESCAPE)
	print("MODE after esc ", m.mode)
	quit()
