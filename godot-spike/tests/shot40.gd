extends SceneTree
## The clothes the shops sell, as the game draws them: the player doll (64 px set) wearing each outfit of clothes,
## then the resident street looks.  godot ... -s tests/shot40.gd -- out.png
const DI = preload("res://addons/trilobit_doll/doll_image.gd")
const ADAPT = preload("res://addons/trilobit_doll/trilobit_adapter.gd")

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var c = DI.for_library("res://gfx/dolls")
	var sets := [["cl_tee", "cl_jeans", "cl_cap"], ["cl_hoodie", "cl_cargo", "cl_shades"], ["cl_leather_jacket", "cl_jeans", "cl_leather_gloves"],
		["cl_oxford", "cl_slacks", "cl_glasses"], ["cl_blazer", "cl_tailored_trousers", "cl_beret"], ["cl_suit_jacket", "cl_tailored_trousers", "cl_dress_gloves"],
		["cl_armored_suit", "cl_slacks", "cl_fedora", "cl_shades"], ["cl_kimono", "cl_tailored_trousers"],
		["street_0"], ["street_1"], ["street_2"], ["office_0"], ["office_1"], ["silk"], ["noir"], ["jacket_2"]]
	var imgs := []
	for i in sets.size():
		var fem := i % 2 == 1
		var look := {"fem": fem, "skin_i": [1, 3, 0, 4, 2, 6][i % 6], "hair_i": [0, 2, 1, 5, 6, 3][i % 6], "eye_i": 2, "style": ["short", "bob", "long", "mohawk", "ponytail", "bun"][i % 6], "eye_shape": "round"}
		var spec = ADAPT.spec_from_game(sets[i], look, "", "m", "res://gfx/dolls")
		imgs.append(c.image(spec, "unarmed/idle/0"))
	var w: int = imgs[0].get_width()
	var h: int = imgs[0].get_height()
	var sheet := Image.create(w * 8, h * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.09, 0.1, 0.14))
	for i in imgs.size():
		sheet.blend_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i((i % 8) * w, (i / 8) * h))
	sheet.resize(w * 8 * 3, h * 2 * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png(out)
	quit()
