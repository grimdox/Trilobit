extends SceneTree
## The layered dolls drawn by the game's own view code for the game's own people specs (residents, Bratva, NAP, Nasim,
## criminals, armed), at the 27 px tile and enlarged.  godot ... -s tests/shot31.gd -- out_prefix
const DS = preload("res://src/dollspec.gd")
const ViewScript = preload("res://src/view.gd")

class Grid extends "res://src/view.gd":
	var specs: Array = []
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 16 * TILE, 6 * TILE * 1.6), Color(0.16, 0.17, 0.2))
		for n in specs.size():
			var p := Vector2((n % 16) * TILE, (n / 16) * TILE * 1.6 + TILE * 0.4)
			_draw_doll(specs[n], p, Vector2i(-1 if n % 5 == 4 else 1, 0))

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var g := Grid.new()
	var sets := [[0, []], [1, ["thug"]], [1, ["thug", "vest"]], [2, ["nap", "helmet_ball", "vest"]], [2, ["nap", "visor", "vest_heavy", "greaves"]],
		[3, ["nasim", "imp_reflex", "imp_optics"]], [3, ["nasim", "imp_reflex", "imp_optics", "imp_mantis"]], [4, ["jacket_2", "balaclava", "bracers"]]]
	var weapons := ["", "trl_gun_sp45", "trl_gun_vk74", "trl_mel_katana", "trl_mel_kastet", "trl_kit_repair"]
	for n in 96:
		var h: int = (n * 2654435761) & 0x7fffffff
		var st: Array = sets[n % sets.size()]
		var layers: Array = st[1].duplicate()
		if layers.is_empty():
			layers = ["jacket_%d" % (h % 6)] if h % 5 != 0 else (["suit"] if h % 2 == 0 else ["overalls"])
		var lk := DS.look(h, (h >> 3) % 2 == 1, int(st[0]))
		lk["hid"] = "helmet_ball" in layers or "visor" in layers
		g.specs.append({"layers": layers, "weapon": weapons[(n / 8) % weapons.size()], "look": lk})
	var vp := SubViewport.new()
	vp.size = Vector2i(16 * 27, int(6 * 27 * 1.6))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(g)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(out + "_grid.png")
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(out + "_grid_x3.png")
	quit()
