extends SceneTree
## screenshots of the light at different hours, in the rain and out:  xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s tests/shot_light.gd -- /tmp/shots/l
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
const GameScript = preload("res://src/game.gd")
const CG = preload("res://src/citygen.gd")
const CLK = preload("res://src/clock.gd")
const WX = preload("res://src/weather.gd")
func _snap(path: String) -> void:
	for k in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
func _tick_for(g, h: int, m: int, wet: bool) -> int:
	for d in range(1, 40):
		var t: int = d * CLK.DAY + h * CLK.HOUR + m * CLK.MIN
		if (float(WX.at(g.weather_seed(), t)["rain"]) > 0.0) == wet:
			return t
	return CLK.DAY + h * CLK.HOUR
func _initialize() -> void:
	GameScript.light_rules = true
	GameScript.street_start = true
	var out: String = OS.get_cmdline_user_args()[0]
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	var w = WorldScript.new()
	w.start(21, 300)
	m.world = w
	m.start_play(w.game)
	await process_frame
	var g = w.game
	# stand on the street by a neon sign
	var spot := -1
	for sg in g.city.signs:
		if String(sg["shape"]) == "neon" and int(sg["cell"]) < g.s2:
			var sc: int = int(sg["cell"])
			for r in range(1, 5):
				for d in [Vector2i(0, r), Vector2i(0, -r), Vector2i(r, 0), Vector2i(-r, 0)]:
					var nc: int = sc + d.y * g.size + d.x
					if spot < 0 and g.sim.walk[nc] == 1 and g.sim.at[nc] == -1 and g.city.tiles[nc] == CG.ROAD:
						spot = nc
			if spot >= 0:
				break
	g.pc = spot
	g.facing = Vector2i(0, 1)
	var shots := [["noon_clear", 12, 0, false], ["noon_rain", 12, 0, true], ["sunrise", 7, 45, false], ["sunset_rain", 18, 10, true], ["night_rain", 23, 0, true], ["night_clear", 23, 0, false]]
	for s in shots:
		g.sim.tick = _tick_for(g, s[1], s[2], s[3])
		g.light.invalidate()
		g._compute_fov()
		m.refresh()
		for k in 4:
			await process_frame
		await _snap("%s_%s.png" % [out, s[0]])
	# in a building, at night
	var inside := -1
	for b in g.city.bldgs:
		var c: int = (int(b["y0"]) + 2) * g.size + int(b["x0"]) + 2
		if g.city.tiles[c] == CG.FLOOR and g.sim.at[c] == -1:
			inside = c
			break
	g.pc = inside
	g.sim.tick = _tick_for(g, 23, 0, true)
	g.light.invalidate()
	g._compute_fov()
	m.refresh()
	await _snap("%s_inside.png" % out)
	quit()
