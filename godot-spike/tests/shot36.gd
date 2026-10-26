extends SceneTree
## screenshots inside a few businesses: tests/shot36.gd -- TYPE [TYPE...]   (saves /tmp/claude-0/biz_<type>.png)
func _init() -> void:
	var m = load("res://src/main.gd").new()
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 5:
		await process_frame
	var g = m.world.game
	m.game = g
	var want: Array = OS.get_cmdline_user_args()
	for id in want:
		var rec = null
		for b in g.city.businesses:
			if b["type"] == id and (rec == null or (int(b["x1"]) - int(b["x0"])) * (int(b["y1"]) - int(b["y0"])) > (int(rec["x1"]) - int(rec["x0"])) * (int(rec["y1"]) - int(rec["y0"]))):
				rec = b
		if rec == null:
			print("none of ", id)
			continue
		var cx: int = (int(rec["x0"]) + int(rec["x1"])) / 2
		var cy: int = (int(rec["y0"]) + int(rec["y1"])) / 2
		# stand on a free floor tile near the middle
		var spot := -1
		for r in range(0, 8):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var c: int = (cy + dy) * g.size + cx + dx
					if spot < 0 and g.sim.walk[c] == 1 and g.city.tiles[c] != 4:
						spot = c
		g.pc = spot
		g.last_pc = g.pc
		g.sim.retier(g.pc)
		g._compute_fov()
		m.refresh()
		for i in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/biz_%s.png" % id)
		print("shot ", id, " ", rec["name"], " ", rec["tag"], " ", rec["x1"] - rec["x0"] + 1, "x", rec["y1"] - rec["y0"] + 1)
	quit()
