extends RefCounted
## The paper-doll atlas: icons for weapons and armor (32x32) and layers drawn over the base person sprite (32x36).
## Made by trilobit-tools/gen_paperdoll.py into gfx/paperdoll/.  Keys: "icon:<item id>" and "doll:<layer>".
var tex: Texture2D
var index: Dictionary = {}

func _init() -> void:
	tex = load("res://gfx/paperdoll/pd_sheet.png")
	var f := FileAccess.open("res://gfx/paperdoll/pd_index.json", FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			index = d

func has(key: String) -> bool:
	return tex != null and index.has(key)

func rect(key: String) -> Rect2:
	var a: Array = index[key]
	return Rect2(a[0], a[1], a[2], a[3])
