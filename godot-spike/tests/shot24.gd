extends SceneTree
## A live ranged scenario through the real game scene: the player aims and fires at a gunman who raises his own gun.  godot ... -s tests/shot24.gd -- out_prefix
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	for i in 4:
		await process_frame
	m.begin_new(5)
	for i in 60:
		await process_frame
		if m.mode == "play":
			break
	var g = m.game
	g.end_turn()
	var who := -1
	for k in g.sim.near_list.size():
		var j: int = g.sim.near_list[k]
		if g.sim.alive[j] == 1 and who < 0:
			who = j
	var c2: int = -1
	for dist in range(5, 3, -1):
		for d in [dist, -dist]:
			if g.sim.walk[g.pc + d] == 1 and g.sim.at[g.pc + d] == -1 and g.sim._sees(g.pc, g.pc + d, 20):
				c2 = g.pc + d
				break
		if c2 >= 0:
			break
	g.sim.at[g.sim.pos[who]] = -1
	g.sim.pos[who] = c2
	g.sim.at[c2] = who
	g.fac[who] = g.BRATVA
	g.astate[who] = g.HUNTING
	g.gunc[who] = 1
	g.hpn[who] = 80
	g.hpmax[who] = 80
	var gun = g._new_item(g.gun_ids["pistol"][0])
	g.wield = gun
	g.pool_add("9mm", "fmj", 60)
	gun.loaded = int(g.GP.stats(gun)["mag"])
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	var l0: int = g.log.size()
	for n in 6:
		if g.sim.alive[who] == 0 or g.game_over:
			break
		g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
		if n % 2 == 0:
			g.act_aim(true)
		else:
			g.act_fire(true)
	for li in range(l0, g.log.size()):
		print("  LOG ", g.log[li])
	m.refresh()
	await process_frame
	await process_frame
	await _snap(out + "_ranged.png")
	quit()

func _snap(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
