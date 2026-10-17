extends SceneTree
## Attributes & Skills screen with some progress filled in.  godot ... -s tests/shot19.gd -- out.png [selected index]
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
	g.attrs["str"] = 14
	g.attrs["per"] = 13
	g.attrs["agi"] = 12
	g.skills["melee"] = 4; g.xp["melee"] = 9
	g.skills["ranged"] = 6; g.xp["ranged"] = 20
	g.skills["dodge"] = 2; g.xp["dodge"] = 3
	g.skills["grit"] = 1; g.xp["grit"] = 5
	g.skills["negotiation"] = 3; g.xp["negotiation"] = 4
	g.skills["streetwise"] = 5; g.xp["streetwise"] = 11
	var args := OS.get_cmdline_user_args()
	m.game = g
	m.screen.game = g
	m.screen_back = "pause"
	m.open_screen("skills")
	m.screen.sk_sel = int(args[1]) if args.size() > 1 else 6
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(args[0] if args.size() > 0 else "/tmp/claude-0/shot_skills.png")
	quit()
