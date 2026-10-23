extends SceneTree
## Screenshot of the workshop (a seed and archetype), for docs and review.  xvfb-run godot --path . -s tests/shot_workshop.gd -- out.png [seed] [arch] [anim]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var sc = load("res://scenes/workshop.tscn").instantiate()
	root.add_child(sc)
	for i in 3:
		await process_frame
	if args.size() > 1:
		sc.controls["seed"].value = int(args[1])
		if args.size() > 2:
			for i in sc.controls["arch"].item_count:
				if sc.controls["arch"].get_item_text(i) == args[2]:
					sc.controls["arch"].select(i)
		sc._generate(int(args[1]))
	if args.size() > 3:
		sc.anim = args[3]
		for r in sc._rigs():
			r.play(sc.anim)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
