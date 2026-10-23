extends Node2D
## A doll on screen.  Give it a spec (set_spec) and an animation (play); it draws the frame's sprites back to front with a
## pool of Sprite2D children (index sprites through the palette shader, held items in full colour), turns to face left or
## right around its feet, blinks on its own, and reports strikes and the end of one-shot animations.
##
## The node's origin is the point between the feet on the ground.  scale_px sets how many screen pixels a sprite pixel
## takes (keep it a whole number for crisp pixels).

signal anim_event(anim: String)        # the frame where a strike lands or a shot fires
signal anim_finished(anim: String)     # a one-shot animation reached its last frame

const LIB = preload("res://addons/trilobit_doll/doll_library.gd")
const SPEC = preload("res://addons/trilobit_doll/doll_spec.gd")
const SHADER = preload("res://addons/trilobit_doll/palette.gdshader")

@export var library_path := "res://dolls"
@export var facing_left := false:
	set(v):
		facing_left = v
		_apply_facing()
@export var scale_px := 1:
	set(v):
		scale_px = max(1, v)
		_apply_facing()
@export var auto_blink := true
@export var shadow := true           # a pixel ellipse on the ground under the doll
@export var shadow_alpha := 0.38
@export var playing := true

var lib
var spec
var anim := "idle"
var frame_index := 0
var fid := ""
var _t := 0.0
var _mat: ShaderMaterial
var _pool: Array = []
var _blink_t := 0.0
var _blink_left := 0.0
var _rng := RandomNumberGenerator.new()
var _drawn := []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if lib == null:
		lib = LIB.shared(library_path)
	if spec == null:
		spec = SPEC.new()
	_rng.seed = hash(get_path())
	_blink_t = _rng.randf_range(1.5, 4.0)
	_apply_facing()
	_refresh()

## the ground shadow, in whole sprite pixels (drawn under the child sprites)
func _draw() -> void:
	if not shadow or spec == null:
		return
	var w := 12.0 if spec.body.ends_with("_l") else (10.0 if spec.body.ends_with("_m") else 9.0)
	var col := Color(0.02, 0.03, 0.05, shadow_alpha)
	for y in range(-2, 3):
		var hw := floorf(w * sqrt(maxf(0.0, 1.0 - pow(y / 2.6, 2.0))) + 0.5)
		draw_rect(Rect2(-hw + 1.0, float(y) - 1.0, hw * 2.0, 1.0), col)

func set_library(l) -> void:
	lib = l
	_refresh()

## a DollSpec or a Dictionary
func set_spec(s) -> void:
	spec = SPEC.from_dict(s) if s is Dictionary else s
	_mat = null
	_refresh()

func play(a: String, restart := true) -> void:
	if a == anim and not restart:
		return
	anim = a
	frame_index = 0
	_t = 0.0
	playing = true
	_refresh()

## show one frame of the current animation and stop
func show_frame(i: int) -> void:
	playing = false
	frame_index = i
	_refresh()

func frame_count() -> int:
	if lib == null or not lib.ok or spec == null:
		return 0
	return lib.frames(anim, spec.grip(lib)).size()

func _apply_facing() -> void:
	scale = Vector2(-scale_px if facing_left else scale_px, scale_px)

func _process(delta: float) -> void:
	if lib == null or not lib.ok or spec == null:
		return
	var redraw := false
	if playing:
		_t += delta * 1000.0
		var durs: Array = lib.durations(anim)
		var n := frame_count()
		while n > 0 and _t >= float(durs[frame_index % durs.size()]):
			_t -= float(durs[frame_index % durs.size()])
			if frame_index + 1 >= n:
				if lib.loops(anim):
					frame_index = 0
				else:
					playing = false
					anim_finished.emit(anim)
					break
			else:
				frame_index += 1
			if frame_index == lib.event_frame(anim):
				anim_event.emit(anim)
			redraw = true
	if auto_blink and spec.expr in ["neutral", "focused"]:
		_blink_t -= delta
		if _blink_t <= 0.0 and _blink_left <= 0.0:
			_blink_left = 0.12
			_blink_t = _rng.randf_range(2.0, 5.0)
			redraw = true
		elif _blink_left > 0.0:
			_blink_left -= delta
			if _blink_left <= 0.0:
				redraw = true
	if redraw:
		_refresh()

func _refresh() -> void:
	if not is_inside_tree() or lib == null or not lib.ok or spec == null:
		return
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		_mat.set_shader_parameter("palette", lib.palette_texture(spec))
	var fl: Array = lib.frames(anim, spec.grip(lib))
	if fl.is_empty():
		return
	fid = fl[clampi(frame_index, 0, fl.size() - 1)]
	var s = spec
	if _blink_left > 0.0:
		s = spec.duplicate_spec()
		s.expr = "blink"
	_drawn = lib.compose(s, fid)
	queue_redraw()
	while _pool.size() < _drawn.size():
		var sp := Sprite2D.new()
		sp.centered = false
		sp.region_enabled = true
		add_child(sp)
		_pool.append(sp)
	for i in _pool.size():
		var sp: Sprite2D = _pool[i]
		if i >= _drawn.size():
			sp.visible = false
			continue
		var e: Dictionary = _drawn[i]
		sp.visible = true
		sp.texture = e["page"]
		sp.region_rect = e["region"]
		sp.position = e["pos"] - lib.origin
		sp.material = _mat if e["indexed"] else null
		sp.z_index = 0
		move_child(sp, i)

## the keys drawn this frame, back to front (tests and debugging)
func drawn_keys() -> Array:
	var out := []
	for e in _drawn:
		out.append(e["key"])
	return out
