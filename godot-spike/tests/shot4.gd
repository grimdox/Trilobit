extends SceneTree
## screenshots of the gun system: a volley with tracers and the gunsmith panel
func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	var g = main.game
	var found := -1
	for t in 400:
		for k in g.sim.near_list.size():
			var j: int = g.sim.near_list[k]
			if g.sim.alive[j] == 1 and g.z_of(g.sim.pos[j]) == 0 and g.sim._sees(g.pc, g.sim.pos[j], 12) and g.cheb(g.pc, g.sim.pos[j]) > 3:
				found = j
				break
		if found >= 0:
			break
		g.end_turn()
	print("target ", found, " turn ", g.turn)
	g.wield = g._new_item(g.gun_ids["smg"][0])
	g.wield.mods.append(g._new_item("trl_mod_redot"))
	g.wield.mode = 1
	g.stow(g._new_item("trl_mod_suppressor"))
	g.stow(g._new_item("trl_mod_extmag"))
	if found >= 0:
		g.astate[found] = 3
		g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
		print('vis ', g.sees_cell(g.sim.pos[found]), ' d ', g.cheb(g.pc, g.sim.pos[found]))
		g.act_aim(true)
		g.act_fire(true)
	main.refresh()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/claude-0/g_volley.png")
	main.mode = "mods"
	main.refresh()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/claude-0/g_mods.png")
	quit()
