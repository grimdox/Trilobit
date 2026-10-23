extends SceneTree
## Review sheets drawn by the runtime itself (no editing afterwards):
##   random_sample.png   seeds 1..64, any archetype, exactly as generated
##   archetypes.png      every archetype, eight seeds each
##   bodies.png          the six frames bare and in four looks
##   anim_<name>.png     every animation and grip for three looks
##   game_scale.png      a crowd at the game's tile size (27 px) next to 1x and 2x
## xvfb-run godot --path . --rendering-driver opengl3 -s tests/render_samples.gd -- OUT_DIR

const LIB = preload("res://addons/trilobit_doll/doll_library.gd")
const SPEC = preload("res://addons/trilobit_doll/doll_spec.gd")
const GEN = preload("res://addons/trilobit_doll/doll_generator.gd")
const RIG = preload("res://addons/trilobit_doll/doll_rig.gd")

var lib
var gen
var out_dir := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://samples"
	DirAccess.make_dir_recursive_absolute(out_dir)
	lib = LIB.new("res://dolls")
	gen = GEN.new(lib)
	# 1 unedited random sample
	var specs := []
	var labels := []
	for s in range(1, 65):
		var d = gen.generate(s)
		specs.append(d)
		labels.append("%d %s" % [s, d.meta["archetype"]])
	await sheet(specs, labels, 8, 2, "idle", 0, "random_sample.png")
	# 2 archetypes
	specs = []
	labels = []
	for a in GEN.ARCH.keys():
		for k in 8:
			var d2 = gen.generate(1000 + k * 17, a)
			specs.append(d2)
			labels.append("%s %d" % [a, 1000 + k * 17])
	await sheet(specs, labels, 8, 2, "idle", 0, "archetypes.png")
	# 3 bodies
	specs = []
	labels = []
	var looks := [
		{"garments": ["under"], "hair": "bald", "colours": {"skin": "tan"}},
		{"garments": ["under", "bodysuit", "boots_high", "gloves", "harness"], "hair": "bob", "colours": {"skin": "porcelain", "hair": "violet black", "cloth1": "gunmetal"}, "item": "trl_gun_sp45"},
		{"garments": ["under", "tee", "cargo", "boots", "riot", "kneepads"], "hair": "buzz", "colours": {"skin": "brown", "cloth3": "olive"}, "implants": ["cyberarm_r", "jaw"], "item": "trl_mel_ono"},
		{"garments": ["under", "turtleneck", "slacks", "boots", "trench"], "hair": "slick", "colours": {"skin": "fair", "cloth2": "drab", "cloth1": "black"}, "item": "trl_gun_vk74"},
		{"garments": ["under", "tank", "leggings", "sneakers", "hoodie"], "hair": "undercut", "colours": {"skin": "olive", "hair": "cyan dye", "cloth2": "gunmetal"}, "implants": ["cortex", "optic_l"], "item": "trl_kit_repair"},
	]
	for b in lib.man["bodies"]:
		for lk in looks:
			var d3: Dictionary = lk.duplicate(true)
			d3["body"] = b
			specs.append(SPEC.from_dict(d3))
			labels.append(b)
		var an = SPEC.from_dict({"body": b, "android": true, "garments": [], "hair": "bald", "eyes": "wide", "colours": {"skin": "pearl", "synth": "pearl"}, "implants": ["optic_twin"]})
		specs.append(an)
		labels.append(b + " android")
	await sheet(specs, labels, 6, 2, "idle", 0, "bodies.png")
	# 4 animations
	var anim_looks := [
		["operative", {"body": "f_m", "garments": ["under", "bodysuit", "boots_high", "gloves", "holster"], "hair": "bob", "eyes": "round", "colours": {"skin": "porcelain", "hair": "violet black"}}],
		["enforcer", {"body": "m_l", "garments": ["under", "tee", "cargo", "boots", "riot"], "hair": "mohawk", "eyes": "hooded", "colours": {"skin": "deep", "hair": "teal dye", "cloth3": "olive"}, "implants": ["cyberarm_r"]}],
		["detective", {"body": "m_m", "garments": ["under", "shirt", "slacks", "boots", "trench"], "hair": "slick", "eyes": "almond", "colours": {"skin": "fair", "cloth2": "khaki"}}],
	]
	var items := {"unarmed": "", "melee1": "trl_mel_wakizashi", "melee2": "trl_mel_katana", "pistol": "trl_gun_sp45", "rifle": "trl_gun_vk74", "tool": "trl_kit_repair"}
	for al in anim_looks:
		var rows := []
		for grip in lib.man["grips"]:
			for an2 in ["idle", "walk", "act", "hit"]:
				var dd: Dictionary = al[1].duplicate(true)
				dd["item"] = items[grip]
				rows.append([SPEC.from_dict(dd), an2, "%s %s" % [grip, an2]])
		var dd2: Dictionary = al[1].duplicate(true)
		rows.append([SPEC.from_dict(dd2), "down", "down"])
		await anim_sheet(rows, "anim_%s.png" % al[0])
	# 5 game scale
	specs = []
	for s2 in range(200, 216):
		specs.append(gen.generate(s2))
	await game_scale(specs, "game_scale.png")
	quit()

func _vp(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#1b222b")
	bg.size = Vector2(size)
	vp.add_child(bg)
	return vp

func _rig(parent: Node, spec, at: Vector2, k: int, anim: String, i: int):
	var r = RIG.new()
	r.lib = lib
	r.auto_blink = false
	r.scale_px = k
	r.position = at
	parent.add_child(r)
	r.set_spec(spec)
	r.anim = anim
	r.show_frame(i)
	return r

func _label(parent: Node, t: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = t
	l.position = at
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color("#8fa6bf"))
	parent.add_child(l)

func _save(vp: SubViewport, name: String) -> void:
	for k in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out_dir.path_join(name))
	print("wrote ", name)
	vp.queue_free()

func sheet(specs: Array, labels: Array, cols: int, k: int, anim: String, i: int, name: String) -> void:
	var cw := 72 * k
	var ch := 80 * k + 16
	var rows := int(ceil(specs.size() / float(cols)))
	var vp := _vp(Vector2i(cols * cw, rows * ch))
	for n in specs.size():
		var cx := (n % cols) * cw
		var cy := (n / cols) * ch
		_rig(vp, specs[n], Vector2(cx + cw * 0.42, cy + 78 * k), k, anim, i)
		_label(vp, labels[n], Vector2(cx + 4, cy + 80 * k))
	await _save(vp, name)

func anim_sheet(rows: Array, name: String) -> void:
	var k := 2
	var cw := 76 * k
	var ch := 82 * k
	var vp := _vp(Vector2i(8 * cw + 120, rows.size() * ch))
	for r in rows.size():
		var spec = rows[r][0]
		var an: String = rows[r][1]
		var n: int = lib.frames(an, spec.grip(lib)).size()
		_label(vp, rows[r][2], Vector2(4, r * ch + 6))
		for i in n:
			_rig(vp, spec, Vector2(120 + i * cw + cw * 0.42, r * ch + 78 * k), k, an, i)
	await _save(vp, name)

func game_scale(specs: Array, name: String) -> void:
	# the same dolls at 1x, scaled into the game's 27 px tiles (what the game does today), and the 32 px world set
	var lib32 = LIB.new("res://dolls32")
	var vp := _vp(Vector2i(16 * 64, 4 * 110))
	for n in specs.size():
		_rig(vp, specs[n], Vector2(n * 64 + 30, 100), 1, "idle", 0)
		var r2 = _rig(vp, specs[n], Vector2(n * 64 + 32, 230), 1, "idle", 0)
		r2.scale = Vector2(27.0 / 64.0, 27.0 / 64.0)
		r2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var r3 = _rig(vp, specs[n], Vector2(n * 64 + 32, 330), 1, "idle", 0)
		r3.scale = Vector2(0.5, 0.5)
		if lib32.ok:
			var r4 = RIG.new()
			r4.lib = lib32
			r4.auto_blink = false
			r4.position = Vector2(n * 64 + 32, 425)
			vp.add_child(r4)
			r4.set_spec(specs[n])
			r4.anim = "idle"
			r4.show_frame(0)
	_label(vp, "1x (64 px sprites)", Vector2(4, 4))
	_label(vp, "64 px scaled into the game's 27 px tile, linear filtering (what the game does today)", Vector2(4, 134))
	_label(vp, "64 px at half size, nearest", Vector2(4, 244))
	_label(vp, "the 32 px world set, 1x (rendered natively at half scale)", Vector2(4, 342))
	await _save(vp, name)
