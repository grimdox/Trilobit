extends SceneTree
## The tabbed Equipment / Implants / Skills / Map screens.  godot ... -s tests/shot33.gd -- out_prefix [tab] [cursor]
const MainScript = preload("res://src/main.gd")
func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://shot_save_"
	m.settings_path = "user://shot_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 5:
		await process_frame
	var g = m.world.game
	for id in ["trl_backpack", "trl_coat", "trl_imp_cortex", "trl_imp_optics", "trl_imp_reflex", "trl_water_bottle", "trl_ration", "trl_gun_hx9", "trl_mel_kama"]:
		var it = g._new_item(id)
		if it != null:
			g.inv.stow(it)
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "/tmp/claude-0/shot_tab"
	var which: String = args[1] if args.size() > 1 else "equipment"
	var sids: Array = ["melee", "ranged", "dodge", "grit", "engineering"]
	for k in sids.size():
		g.skills[sids[k]] = [4, 2, 2, 1, 0][k]
	g.check_level()
	m.game = g
	m.screen.game = g
	m.open_tab(which, "play")
	if args.size() > 2 and args[2] == "local":
		m.screen.map_local = true
	elif args.size() > 2:
		m.gear.cur = args[2]
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(prefix + "_" + which + ".png")
	quit()
