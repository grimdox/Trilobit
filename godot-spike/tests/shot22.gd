extends SceneTree
## Screens for the awareness glows and attitude arrows.  godot ... -s tests/shot22.gd -- out_prefix
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
	var picks := []
	var spots := []
	for dy in range(-5, 6):
		for dx in range(-8, 9):
			var c: int = g.pc + dx + dy * g.size
			if (abs(dx) >= 2 or abs(dy) >= 2) and g.sim.walk[c] == 1 and g.sim.at[c] == -1 and abs(dx) % 3 == 0 and abs(dy) % 2 == 0:
				spots.append(c)
	for k in g.sim.near_list.size():
		var j: int = g.sim.near_list[k]
		if g.sim.alive[j] == 1 and picks.size() < 6 and picks.size() < spots.size():
			var c2: int = spots[picks.size() * 3]
			g.sim.at[g.sim.pos[j]] = -1
			g.sim.pos[j] = c2
			g.sim.at[c2] = j
			picks.append(j)
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	print("picked ", picks.size(), " near ", g.sim.near_list.size(), " turn ", g.turn, " z ", g.z_of(g.pc))
	var setup := [[0, 0], [0, 1], [1, 1], [3, 1], [3, 0], [0, 4]]   # [awareness, faction]
	for n in picks.size():
		g.astate[picks[n]] = setup[n][0]
		g.fac[picks[n]] = setup[n][1]
		g.face[picks[n]] = n % 8
	m.refresh()
	await process_frame
	await process_frame
	await _snap(out + "_glow.png")
	quit()

func _snap(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
