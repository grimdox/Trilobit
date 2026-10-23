extends SceneTree
## Runtime fidelity: render the reference specs (tests/expected/cases.json) through the real rig and palette shader
## and compare every pixel with the generator's own image.  Needs a display (the Compatibility renderer under xvfb):
##   xvfb-run godot --path . --rendering-driver opengl3 -s tests/render_check.gd
## Prints "RENDER passed/total"; exit code 0 only when all pass.

const LIB = preload("res://addons/trilobit_doll/doll_library.gd")
const SPEC = preload("res://addons/trilobit_doll/doll_spec.gd")
const RIG = preload("res://addons/trilobit_doll/doll_rig.gd")

var passed := 0
var total := 0

func _initialize() -> void:
	# usage: ... -s tests/render_check.gd -- [SET] [EXPECTED_DIR]   (defaults: res://dolls, res://tests/expected)
	var args := OS.get_cmdline_user_args()
	var set_path: String = args[0] if args.size() > 0 else "res://dolls"
	var exp_dir: String = args[1] if args.size() > 1 else "res://tests/expected"
	var lib = LIB.new(set_path)
	var cell := int(lib.man.get("cell", 96))
	var f := FileAccess.open(exp_dir.path_join("cases.json"), FileAccess.READ)
	var cases: Array = JSON.parse_string(f.get_as_text())
	for c in cases:
		var vp := SubViewport.new()
		vp.size = Vector2i(cell, cell)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(vp)
		var rig = RIG.new()
		rig.lib = lib
		rig.auto_blink = false
		rig.shadow = false
		rig.playing = false
		rig.position = lib.origin
		vp.add_child(rig)
		rig.set_spec(SPEC.from_dict(c["spec"]))
		rig.anim = c["anim"]
		rig.show_frame(int(c["i"]))
		for k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var got: Image = vp.get_texture().get_image()
		got.convert(Image.FORMAT_RGBA8)
		var want := Image.load_from_file(ProjectSettings.globalize_path(exp_dir.path_join("%s.png" % c["name"])))
		want.convert(Image.FORMAT_RGBA8)
		var diff := 0
		var first := ""
		for y in cell:
			for x in cell:
				var a := got.get_pixel(x, y)
				var b := want.get_pixel(x, y)
				var same := (a.a < 0.5 and b.a < 0.5) or (a.a >= 0.5 and b.a >= 0.5 and a.to_rgba32() | 0xff == b.to_rgba32() | 0xff)
				if not same:
					diff += 1
					if first == "":
						first = "(%d,%d) got %s want %s" % [x, y, a.to_html(), b.to_html()]
		got.save_png("user://render_%d_%s.png" % [cell, c["name"]])
		total += 1
		if diff == 0:
			passed += 1
		print(("  PASS " if diff == 0 else "  FAIL ") + "%s (%s): %d differing pixels %s" % [c["name"], c["frame"], diff, first])
		vp.queue_free()
	print("RENDER %d/%d" % [passed, total])
	quit(0 if passed == total else 1)
