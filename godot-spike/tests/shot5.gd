extends SceneTree
func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	var g = main.game
	var best := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1 and g.fac[i] == 1 and g.z_of(g.sim.pos[i]) == 0:
			best = i
			break
	g.pc = g.sim.pos[best] + 6 * g.size
	for d in range(0, 12):
		var c: int = g.sim.pos[best] + (4 + d) * g.size
		if g.sim.walk[c] == 1 and g.sim.at[c] == -1:
			g.pc = c
			break
	g.sim.retier(g.pc)
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	g.sim.sticky[best] = 1
	g.face[best] = 4
	g.end_turn()
	print("watcher ", best, " turn ", g.turn)
	g._set_stance(g.CROUCH)
	main.refresh()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/claude-0/s_cone.png")
	quit()
