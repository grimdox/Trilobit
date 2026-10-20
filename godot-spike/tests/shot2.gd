extends SceneTree
func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	var g = main.game
	g.sim.tick = 8 * 60 + 5
	# find the street cell with the most people within 9 tiles
	var best := -1
	var bn := 0
	for c in range(0, g.size * g.size, 5):
		if g.city.tiles[c] != 1 or g.sim.at[c] != -1:
			continue
		var n := 0
		for k in g.sim.near_list.size():
			if g.cheb(g.sim.pos[g.sim.near_list[k]], c) <= 9:
				n += 1
		if n > bn:
			bn = n
			best = c
	# promote people around a thug-rich spot: put the player on a thug's street and let the sim catch up
	var thug := -1
	for i in g.sim.n:
		if g.fac[i] == 1 and g.city.tiles[g.sim.pos[i]] == 1 and g.sim.alive[i] == 1:
			thug = i
			break
	g.pc = g.sim.pos[thug] + 1
	if g.city.tiles[g.pc] != 1:
		g.pc = g.sim.pos[thug] - 1
	for k in 14:
		g.end_turn()
	g.wield = g._new_item("trl_gun_hx9")
	g.pool_add("9mm", "fmj", 60)
	for k in 40:
		var t: int = g.nearest_target()
		if t >= 0 and k % 3 == 0:
			g.act_fire()
		else:
			g.act_wait()
		if g.body.total() < 20:
			break
	main.refresh()
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("/tmp/claude-0/shot_action.png")
	print("log: ", g.log.slice(-8))
	print("people near: ", g.sim.near_list.size(), " hp ", g.body.total())
	quit()
