extends SceneTree
## A live melee scenario through the real game scene: a Bratva thug closes and trades blows with the player.  godot ... -s tests/shot23.gd -- out_prefix
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
	for d in [1, -1, g.size, -g.size]:
		if g.sim.walk[g.pc + d] == 1 and g.sim.at[g.pc + d] == -1:
			c2 = g.pc + d
			break
	g.sim.at[g.sim.pos[who]] = -1
	g.sim.pos[who] = c2
	g.sim.at[c2] = who
	g.fac[who] = g.BRATVA
	g.astate[who] = g.HUNTING
	g.hpn[who] = 60
	g.hpmax[who] = 60
	g.wield = g._new_item("trl_mel_katana")
	g.skills["melee"] = 6
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	var dir: int = c2 - g.pc
	var dx: int = 1 if dir == 1 else (-1 if dir == -1 else 0)
	var dy: int = 1 if dir == g.size else (-1 if dir == -g.size else 0)
	var l0: int = g.log.size()
	var t0: int = g.turn
	for n in 8:
		if g.sim.alive[who] == 0 or g.game_over:
			break
		g.act_move(dx, dy)
	print("turns used ", g.turn - t0, " stamina ", g.stamina, " hp ", g.hp, "/", g.hp_max, " thug hp ", g.hpn[who], " alive ", g.sim.alive[who])
	for li in range(l0, g.log.size()):
		print("  LOG ", g.log[li])
	m.refresh()
	await process_frame
	await process_frame
	await _snap(out + "_melee.png")
	quit()

func _snap(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
