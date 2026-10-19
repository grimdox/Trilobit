extends RefCounted
## The standing-doll atlas: 64x64 layers of a person standing, three-quarter turned to the right, that stack pixel for pixel.
## Made by tools/content/gen_figures.py into gfx/figure/.  Index: key -> [x, y, w, h, z]; z is the draw order (lowest first).
## DollSpec.figure_keys turns a doll spec into the keys to draw.
var tex: Texture2D
var index: Dictionary = {}

func _init() -> void:
	if ResourceLoader.exists("res://gfx/figure/fig_sheet.png"):
		tex = load("res://gfx/figure/fig_sheet.png")
	var f := FileAccess.open("res://gfx/figure/fig_index.json", FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			index = d

func ready() -> bool:
	return tex != null and index.has("base:shadow")

func has(key: String) -> bool:
	return not key.begins_with("_") and index.has(key)

func z(key: String) -> int:
	return int(index[key][4])

func rect(key: String) -> Rect2:
	var a: Array = index[key]
	return Rect2(a[0], a[1], a[2], a[3])

## draw a spec's layers into a 64x64 cell at `pos` (top-left), `k` times its size, mirrored when the person faces left
func draw(ci: CanvasItem, keys: Array, pos: Vector2, k: float, mirror: bool, mod: Color = Color.WHITE) -> void:
	var cell := 64.0 * k
	if mirror:
		ci.draw_set_transform(pos + Vector2(cell, 0), 0.0, Vector2(-k, k))
	else:
		ci.draw_set_transform(pos, 0.0, Vector2(k, k))
	for key in keys:
		var r: Rect2 = rect(String(key))
		ci.draw_texture_rect_region(tex, Rect2(Vector2.ZERO, r.size), r, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
