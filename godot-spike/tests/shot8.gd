extends SceneTree
func _init() -> void:
	var isl = preload("res://src/island.gd").new(7)
	print("init ok")
	for z in [Vector2i(3,1), Vector2i(0,1), Vector2i(2,1)]:
		var t0 := Time.get_ticks_msec()
		var c = isl.build_zone(z.x, z.y)
		print(z, " ", Time.get_ticks_msec() - t0, " ms, buildings ", c.buildings)
		c.save_png("/tmp/claude-0/zone_%d_%d.png" % [z.x, z.y], 2)
	quit()
