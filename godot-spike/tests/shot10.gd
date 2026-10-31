extends SceneTree
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 100:
		await process_frame
	var g = m.game
	g.act_wear(g._new_item("trl_armor_chest_4"))
	g.act_wear(g._new_item("trl_armor_head_3"))
	g.implants["dermal"] = true
	g.player_hurt(9, "Test", "phys", "chest")
	g.player_hurt(30, "Test", "phys", "l_arm")
	g.player_hurt(14, "Test", "phys", "r_leg")
	g.player_hurt(5, "Test", "phys", "head")
	m.refresh()
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_hud.png")
	m.open_screen("implants")
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_imp.png")
	quit(0)
