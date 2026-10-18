extends RefCounted
## The paper-doll atlas: icons for weapons and armor (32x32) and layers drawn over the base person sprite (32x36).
## Made by tools/content/gen_paperdoll.py into gfx/paperdoll/.  Keys: "icon:<item id>" and "doll:<layer>".
var tex: Texture2D
var index: Dictionary = {}
var scale: float = 2.0           # on-screen scale of an atlas cell (the old 32px atlas is drawn at 2x; the 64px one at 1x)

func _init() -> void:
	tex = load("res://gfx/paperdoll/pd_sheet.png")
	var f := FileAccess.open("res://gfx/paperdoll/pd_index.json", FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			index = d
			scale = float(d.get("_scale", 2.0))

func has(key: String) -> bool:
	return tex != null and key != "_scale" and index.has(key)

func rect(key: String) -> Rect2:
	var a: Array = index[key]
	return Rect2(a[0], a[1], a[2], a[3])
