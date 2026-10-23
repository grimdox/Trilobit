extends Control
## The doll workshop: build a character by hand or from a seed, see it at work scale and at game scale, play every
## animation with every grip, save the spec as JSON for the game, export the frames as a PNG strip.

const LIB = preload("res://addons/trilobit_doll/doll_library.gd")
const SPEC = preload("res://addons/trilobit_doll/doll_spec.gd")
const GEN = preload("res://addons/trilobit_doll/doll_generator.gd")
const RIG = preload("res://addons/trilobit_doll/doll_rig.gd")
const PAL = preload("res://addons/trilobit_doll/doll_palette.gd")

const BG := Color("#151a21")
const PANEL := Color("#0d1117")
const ACCENT := Color("#5fe3ec")
const COLOUR_SLOTS := ["skin", "hair", "eyes", "cloth1", "cloth2", "cloth3", "cloth4", "leather", "leather2", "metal", "poly", "synth", "glow", "glow2"]
const SLOT_NAMES := {"skin": "Skin", "hair": "Hair colour", "eyes": "Eye colour", "cloth1": "Cloth 1 (base layer)", "cloth2": "Cloth 2 (outer layer)",
	"cloth3": "Cloth 3 (legwear)", "cloth4": "Cloth 4 (accents)", "leather": "Leather (boots, belts)", "leather2": "Leather 2 (gloves, holsters)",
	"metal": "Metal", "poly": "Plates", "synth": "Prosthetic shell", "glow": "Implant light", "glow2": "Second light"}

var lib
var gen
var spec
var rig_big
var rig_one
var rig_game
var anim := "idle"
var zoom := 5
var controls := {}
var garment_boxes := {}
var implant_boxes := {}
var log_label: Label
var status: Label
var stage: Control
var crowd: GridContainer
var crowd_on := false
var _building := false


func _ready() -> void:
	lib = LIB.shared("res://dolls")
	if not lib.ok:
		var l := Label.new()
		l.text = "No baked doll set: run tools/dollgen/bake.py first (%s)" % lib.error
		add_child(l)
		return
	gen = GEN.new(lib)
	spec = gen.generate(1, "operative")
	_build_ui()
	_apply_spec()

# ------------------------------------------------------------------------------------------------ UI
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	# left: the look
	var left := _panel(row, 360)
	var lv := _scroll_box(left)
	_title(lv, "TRILOBIT DOLL WORKSHOP")
	_section(lv, "Generate")
	var seed_row := HBoxContainer.new()
	lv.add_child(seed_row)
	var seed_box := SpinBox.new()
	seed_box.max_value = 999999
	seed_box.value = 1
	seed_box.custom_minimum_size.x = 110
	seed_row.add_child(seed_box)
	controls["seed"] = seed_box
	var arch := OptionButton.new()
	arch.add_item("any archetype")
	for a in GEN.ARCH.keys():
		arch.add_item(a)
	seed_row.add_child(arch)
	controls["arch"] = arch
	var gen_row := HBoxContainer.new()
	lv.add_child(gen_row)
	_button(gen_row, "Generate", func(): _generate(int(seed_box.value)))
	_button(gen_row, "Next seed", func():
		seed_box.value += 1
		_generate(int(seed_box.value)))
	_button(gen_row, "Crowd", func(): _toggle_crowd())
	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	log_label.add_theme_font_size_override("font_size", 11)
	log_label.add_theme_color_override("font_color", Color("#8fa6bf"))
	lv.add_child(log_label)
	_section(lv, "Body")
	_option(lv, "body", "Frame", lib.man["bodies"].keys(), func(k): return lib.man["bodies"][k]["name"])
	var andro := CheckBox.new()
	andro.text = "Android (synthetic body, panel seams)"
	andro.toggled.connect(func(on):
		if not _building:
			spec.android = on
			_apply_spec())
	lv.add_child(andro)
	controls["android"] = andro
	_option(lv, "hair_style", "Hair", lib.man["hair"].keys(), func(k): return lib.man["hair"][k])
	_option(lv, "eye_shape", "Eyes", lib.man["eye_shapes"].keys(), func(k): return lib.man["eye_shapes"][k])
	_option(lv, "expr", "Expression", lib.man["expressions"].keys(), func(k): return lib.man["expressions"][k])
	_section(lv, "Colours")
	var pt: Dictionary = lib.man["palette"]
	for slot in COLOUR_SLOTS:
		var table: Dictionary = _table_for(slot, pt)
		_colour(lv, slot, table)
	_section(lv, "Outfit presets")
	var outfit := OptionButton.new()
	outfit.add_item("(choose to apply)")
	for o in lib.man["outfits"]:
		outfit.add_item(lib.man["outfits"][o]["name"])
		outfit.set_item_metadata(outfit.item_count - 1, o)
	outfit.item_selected.connect(func(i):
		if i > 0:
			_apply_outfit(outfit.get_item_metadata(i))
			outfit.select(0))
	lv.add_child(outfit)
	_section(lv, "Garments")
	var cats := {}
	for gid in lib.man["garments"]:
		var cat: String = GEN.CATEGORY.get(gid, "other").split(":")[0]
		if not cats.has(cat):
			cats[cat] = []
		cats[cat].append(gid)
	for cat in ["under", "base", "legs", "feet", "outer", "armor", "straps", "hands", "head"]:
		if not cats.has(cat):
			continue
		var l := Label.new()
		l.text = cat
		l.add_theme_color_override("font_color", Color("#8fa6bf"))
		lv.add_child(l)
		var grid := GridContainer.new()
		grid.columns = 2
		lv.add_child(grid)
		for gid in cats[cat]:
			var cb := CheckBox.new()
			cb.text = lib.man["garments"][gid]["name"]
			cb.toggled.connect(func(on): _toggle_list(spec.garments, gid, on))
			grid.add_child(cb)
			garment_boxes[gid] = cb
	_section(lv, "Implants")
	var ig := GridContainer.new()
	ig.columns = 2
	lv.add_child(ig)
	for iid in lib.man["implants"]:
		var cb2 := CheckBox.new()
		cb2.text = lib.man["implants"][iid]["name"]
		cb2.toggled.connect(func(on): _toggle_list(spec.implants, iid, on))
		ig.add_child(cb2)
		implant_boxes[iid] = cb2
	_section(lv, "Held item")
	var items: Array = lib.man["items"].keys()
	items.sort()
	_option(lv, "item", "Item", [""] + items, func(k): return "(empty hands)" if k == "" else "%s  [%s]" % [k.trim_prefix("trl_"), lib.man["items"][k]])
	# centre: the stage
	var centre := VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(centre)
	var bar := HBoxContainer.new()
	centre.add_child(bar)
	var an := OptionButton.new()
	for a in ["idle", "walk", "act", "hit", "down"]:
		an.add_item(a)
	an.item_selected.connect(func(i):
		anim = an.get_item_text(i)
		for r in _rigs():
			r.play(anim))
	bar.add_child(an)
	_button(bar, "Play / pause", func():
		for r in _rigs():
			r.playing = not r.playing)
	_button(bar, "Turn", func():
		for r in _rigs():
			r.facing_left = not r.facing_left)
	var zs := HSlider.new()
	zs.min_value = 1
	zs.max_value = 8
	zs.value = zoom
	zs.custom_minimum_size.x = 140
	zs.value_changed.connect(func(v):
		zoom = int(v)
		_layout_stage())
	bar.add_child(_label("zoom"))
	bar.add_child(zs)
	_button(bar, "Save spec", func(): _save_spec())
	_button(bar, "Export strip", func(): _export_strip())
	stage = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	centre.add_child(stage)
	var floor_rect := ColorRect.new()
	floor_rect.color = Color("#1b222b")
	floor_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(floor_rect)
	rig_big = _make_rig(stage)
	rig_one = _make_rig(stage)
	rig_game = _make_rig(stage)
	# the world set (32 px, rendered at half scale, its own faces) when it is baked; otherwise the 64 px doll scaled down
	var lib32 = LIB.shared("res://dolls32")
	if lib32.ok:
		rig_game.set_library(lib32)
	crowd = GridContainer.new()
	crowd.columns = 8
	crowd.visible = false
	stage.add_child(crowd)
	status = _label("")
	centre.add_child(status)
	stage.resized.connect(_layout_stage)

func _panel(parent: Control, w: int) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.x = w
	parent.add_child(p)
	return p

func _scroll_box(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v

func _title(p: Control, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", ACCENT)
	l.add_theme_font_size_override("font_size", 18)
	p.add_child(l)

func _section(p: Control, t: String) -> void:
	var l := Label.new()
	l.text = t.to_upper()
	l.add_theme_color_override("font_color", ACCENT)
	p.add_child(HSeparator.new())
	p.add_child(l)

func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l

func _button(p: Control, t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(f)
	p.add_child(b)
	return b

func _option(p: Control, key: String, label: String, ids: Array, name_of: Callable) -> void:
	var h := HBoxContainer.new()
	p.add_child(h)
	var l := _label(label)
	l.custom_minimum_size.x = 90
	h.add_child(l)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.fit_to_longest_item = false
	for id in ids:
		o.add_item(String(name_of.call(id)))
		o.set_item_metadata(o.item_count - 1, id)
	o.item_selected.connect(func(i): _set_field(key, o.get_item_metadata(i)))
	h.add_child(o)
	controls[key] = o

func _table_for(slot: String, pt: Dictionary) -> Dictionary:
	match slot:
		"skin", "synth":
			var t := {}
			for k in pt["skins"]:
				t[k] = pt["skins"][k]["mid"]
			return t
		"hair":
			return pt["hair"]
		"eyes":
			return pt["eyes"]
		"metal":
			return pt["metal"]
		"glow", "glow2":
			return pt["glow"]
	return pt["cloth"]

func _colour(p: Control, slot: String, table: Dictionary) -> void:
	var h := HBoxContainer.new()
	p.add_child(h)
	var l := _label(SLOT_NAMES[slot])
	l.custom_minimum_size.x = 150
	l.add_theme_font_size_override("font_size", 12)
	h.add_child(l)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.add_item("(default)")
	o.set_item_metadata(0, "")
	for k in table:
		o.add_item(k)
		o.set_item_metadata(o.item_count - 1, k)
	h.add_child(o)
	var cp := ColorPickerButton.new()
	cp.custom_minimum_size = Vector2(28, 20)
	cp.edit_alpha = false
	h.add_child(cp)
	o.item_selected.connect(func(i):
		if _building:
			return
		var v := String(o.get_item_metadata(i))
		if v == "":
			spec.colours.erase(slot)
		else:
			spec.colours[slot] = v
		_apply_spec(false))
	cp.color_changed.connect(func(c):
		if _building:
			return
		spec.colours[slot] = "#" + c.to_html(false)
		_apply_spec(false))
	controls["colour_" + slot] = [o, cp, table]

func _make_rig(parent: Control):
	var r = RIG.new()
	r.lib = lib
	parent.add_child(r)
	return r

func _rigs() -> Array:
	return [rig_big, rig_one, rig_game]

func _layout_stage() -> void:
	if stage == null:
		return
	var s := stage.size
	rig_big.scale_px = zoom
	rig_big.position = Vector2(s.x * 0.45, s.y * 0.5 + 48 * zoom * 0.5)
	rig_one.scale_px = 1
	rig_one.position = Vector2(s.x - 180, s.y * 0.5)
	rig_game.scale_px = 1
	if rig_game.lib != lib:
		rig_game.position = Vector2(s.x - 90, s.y * 0.5)           # the 32 px world set at 1x
	else:
		# no world set: the 64 px doll scaled into the game's 27 px tile
		rig_game.scale = Vector2(27.0 / 64.0 * (-1.0 if rig_game.facing_left else 1.0), 27.0 / 64.0)
		rig_game.position = Vector2(s.x - 90, s.y * 0.5)
	crowd.position = Vector2(10, 10)

# ------------------------------------------------------------------------------------------------ state
func _set_field(key: String, v) -> void:
	if _building:
		return
	match key:
		"body":
			spec.body = v
		"hair_style":
			spec.hair = v
		"eye_shape":
			spec.eyes = v
		"expr":
			spec.expr = v
		"item":
			spec.item = v
	_apply_spec()

func _toggle_list(arr: Array, id: String, on: bool) -> void:
	if _building:
		return
	if on and not (id in arr):
		arr.append(id)
	elif not on:
		arr.erase(id)
	_apply_spec()

func _apply_outfit(o: String) -> void:
	var od: Dictionary = lib.man["outfits"][o]
	spec.garments = ["under"] + Array(od["garments"])
	for slot in od["colours"]:
		spec.colours[slot] = od["colours"][slot]
	_apply_spec()

func _generate(seed_value: int) -> void:
	var a := ""
	var ai: int = controls["arch"].selected
	if ai > 0:
		a = controls["arch"].get_item_text(ai)
	spec = gen.generate(seed_value, a)
	_apply_spec()

func _apply_spec(sync := true) -> void:
	for r in _rigs():
		r.set_spec(spec.duplicate_spec())
		r.play(anim)
	if sync:
		_sync_controls()
	var problems: Array = gen.validate(spec, GEN.ARCH.get(String(spec.meta.get("archetype", "resident")), {}))
	var lg: Array = spec.meta.get("log", [])
	log_label.text = "seed %s  %s\n%s%s" % [spec.meta.get("seed", "-"), spec.meta.get("archetype", "hand made"),
		("repairs: " + "; ".join(lg)) if not lg.is_empty() else "no repairs", ("\nrules broken: " + str(problems)) if not problems.is_empty() else ""]
	status.text = "%s · %s · grip %s · %d sprites" % [lib.man["bodies"][spec.body]["name"], anim, spec.grip(lib), lib.compose(spec, rig_big.fid).size()]
	_layout_stage()

func _sync_controls() -> void:
	_building = true
	_select(controls["body"], spec.body)
	_select(controls["hair_style"], spec.hair)
	_select(controls["eye_shape"], spec.eyes)
	_select(controls["expr"], spec.expr)
	_select(controls["item"], spec.item)
	controls["android"].button_pressed = spec.android
	for slot in COLOUR_SLOTS:
		var c: Array = controls["colour_" + slot]
		var v := String(spec.colours.get(slot, ""))
		_select(c[0], v if not v.begins_with("#") else "")
		var hexv := v if v.begins_with("#") else String(c[2].get(v, PAL.DEFAULT_COLOURS.get(slot, "#808080")))
		if not hexv.begins_with("#"):
			hexv = String(c[2].get(hexv, "#808080"))
		c[1].color = Color(hexv)
	for gid in garment_boxes:
		garment_boxes[gid].button_pressed = gid in spec.garments
	for iid in implant_boxes:
		implant_boxes[iid].button_pressed = iid in spec.implants
	_building = false

func _select(o: OptionButton, meta) -> void:
	for i in o.item_count:
		if o.get_item_metadata(i) == meta:
			o.select(i)
			return

func _toggle_crowd() -> void:
	crowd_on = not crowd_on
	crowd.visible = crowd_on
	for r in _rigs():
		r.visible = not crowd_on
	for ch in crowd.get_children():
		ch.queue_free()
	if not crowd_on:
		return
	var base := int(controls["seed"].value)
	for k in 32:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(110, 130)
		crowd.add_child(cell)
		var r = RIG.new()
		r.lib = lib
		r.scale_px = 2
		r.position = Vector2(55, 118)
		cell.add_child(r)
		r.set_spec(gen.generate(base + k))
		r.play("idle")

func _save_spec() -> void:
	var path := "user://doll_%s.json" % str(spec.meta.get("seed", "custom"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(spec.to_dict(), "  "))
	status.text = "saved " + ProjectSettings.globalize_path(path)

func _export_strip() -> void:
	# draw every frame of the animation into one strip at 1x through a SubViewport
	var fl: Array = lib.frames(anim, spec.grip(lib))
	var vp := SubViewport.new()
	vp.size = Vector2i(96 * fl.size(), 96)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	for i in fl.size():
		var r = RIG.new()
		r.lib = lib
		r.auto_blink = false
		r.position = Vector2(96 * i, 0) + lib.origin
		vp.add_child(r)
		r.set_spec(spec.duplicate_spec())
		r.anim = anim
		r.show_frame(i)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := "user://strip_%s_%s.png" % [str(spec.meta.get("seed", "custom")), anim]
	img.save_png(path)
	vp.queue_free()
	status.text = "exported " + ProjectSettings.globalize_path(path)
