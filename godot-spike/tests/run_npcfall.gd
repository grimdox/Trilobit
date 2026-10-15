extends SceneTree
func _init() -> void:
	var r = preload("res://tests/test_npcfall.gd").new().run()
	for l in r[2]:
		print(l)
	print("NPCFALL %d/%d" % [r[0], r[1]])
	quit(0 if r[0] == r[1] else 1)
