extends SceneTree
## A live scenario through the real game scene: the player cuts a thug apart limb by limb and looks at the wounds.  godot ... -s tests/shot25.gd -- out_prefix
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
	g.sim.place(who, c2)
	g.fac[who] = g.BRATVA
	g.astate[who] = g.HUNTING
	g.stun[who] = 40          # pinned, so the log shows only what the blows do to him
	g.hpn[who] = 200
	g.hpmax[who] = 60
	g.hp = 5000
	g.hp_max = 5000
	g.wield = g._new_item("trl_mel_katana")
	g.skills["melee"] = 6
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	var dir: int = c2 - g.pc
	var dx: int = 1 if dir == 1 else (-1 if dir == -1 else 0)
	var dy: int = 1 if dir == g.size else (-1 if dir == -g.size else 0)
	var l0: int = g.log.size()
	var t0: int = g.turn
	for n in 14:
		if g.sim.alive[who] == 0 or g.game_over:
			break
		g.melee(who)
	print("LOOK ", g.describe_at(c2).substr(0, 140))
	print("turns used ", g.turn - t0, " stamina ", g.stamina, " hp ", g.hp, "/", g.hp_max, " thug hp ", g.hpn[who], " alive ", g.sim.alive[who])
	for li in range(l0, g.log.size()):
		print("  LOG ", g.log[li])
	m.refresh()
	await process_frame
	await process_frame
	await _snap(out + "_parts.png")
	quit()

func _snap(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
