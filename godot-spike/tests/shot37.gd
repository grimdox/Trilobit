extends SceneTree
## screenshots inside towers: tests/shot37.gd -- KIND[:N] ...   KIND = lobby | apartment | office | gym | shop   (saves /tmp/claude-0/tw_<kind><n>.png)
func _init() -> void:
	var m = load("res://src/main.gd").new()
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 5:
		await process_frame
	var g = m.world.game
	m.game = g
	var s2: int = g.s2
	for spec in OS.get_cmdline_user_args():
		var parts: PackedStringArray = String(spec).split(":")
		var kind: String = parts[0]
		var nth: int = int(parts[1]) if parts.size() > 1 else 0
		var seen := 0
		var done := false
		for t in g.city.tower_info:
			var z := 0
			var ok := false
			match kind:
				"lobby": ok = true
				"shop": ok = int(t["shops"]) > 0
				"apartment": ok = t["use"] != "office"; z = 2 if int(t["gym_z"]) == 1 else 1
				"office": ok = t["use"] != "apartment" and int(t["h"]) > 4; z = 2
				"gym": ok = t["use"] != "office" and int(t["gym_z"]) >= 1; z = int(t["gym_z"])
			if not ok or int(t["h"]) <= z + 1:
				continue
			if seen < nth:
				seen += 1
				continue
			var sc: int = t["stairs"]
			var base: int = g.city.lvl_of_z(z) * s2 if z > 0 else 0
			var spot: int = base + sc + 1
			if kind == "shop":
				spot = base + int(t["door"].y * g.size + t["door"].x) + (0)
			g.pc = spot
			g.last_pc = g.pc
			g.sim.retier(g.pc)
			g._compute_fov()
			m.refresh()
			for i in 4:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/tw_%s%d.png" % [kind, nth])
			print("shot ", spec, " use ", t["use"], " h ", t["h"], " size ", t["x1"] - t["x0"] + 1, "x", t["y1"] - t["y0"] + 1)
			done = true
			break
		if not done:
			print("none for ", spec)
	quit()
