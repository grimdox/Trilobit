extends RefCounted
## Loads a CDDA-format tileset (tile_config.json plus sheets) so the Godot game can draw with the Bouma / Mokuhanga / Neonoir / Pixel16 / Smog art.
## Sprite ids are the CDDA ids (t_wall, npc_male, a gun's looks_like...).  Sheets are numbered in order; fg index n maps to sheet n - base.
var textures: Dictionary = {}       # file -> Texture2D
var sheets: Array = []              # {file, base, n, sw, sh, cols, ox, oy}
var index: Dictionary = {}          # id -> fg
var tile_w: int = 32
var tile_h: int = 32

func load_dir(dir: String) -> bool:
	var f := FileAccess.open(dir + "/tile_config.json", FileAccess.READ)
	if f == null:
		return false
	var cfg: Dictionary = JSON.parse_string(f.get_as_text())
	tile_w = int(cfg["tile_info"][0]["width"])
	tile_h = int(cfg["tile_info"][0]["height"])
	var base := 1
	for s in cfg["tiles-new"]:
		if not s.has("sprite_width"):
			continue
		var file: String = s["file"]
		var tex: Texture2D = _load_tex(dir + "/" + file)
		if tex == null:
			return false
		textures[file] = tex
		var sw := int(s["sprite_width"])
		var sh := int(s["sprite_height"])
		var cols := int(tex.get_width()) / sw
		var n := cols * (int(tex.get_height()) / sh)
		sheets.append({"file": file, "base": base, "n": n, "sw": sw, "sh": sh, "cols": cols, "ox": int(s.get("sprite_offset_x", 0)), "oy": int(s.get("sprite_offset_y", 0))})
		for t in s["tiles"]:
			var ids = t["id"] if t["id"] is Array else [t["id"]]
			for id in ids:
				index[id] = int(t["fg"])
		base += n
	return true

func _load_tex(path: String) -> Texture2D:
	if FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			return ImageTexture.create_from_image(img)
	var r = load(path)
	if r is Texture2D:
		return r
	var img2 := Image.load_from_file(path)
	return ImageTexture.create_from_image(img2) if img2 != null else null

func has(id: String) -> bool:
	return index.has(id)

## [texture, source rect, draw offset] for an id, or [] when unknown
func sprite(id: String) -> Array:
	if not index.has(id):
		return []
	var fg: int = index[id]
	for s in sheets:
		if fg >= s["base"] and fg < s["base"] + s["n"]:
			var k: int = fg - s["base"]
			var r := Rect2((k % s["cols"]) * s["sw"], (k / s["cols"]) * s["sh"], s["sw"], s["sh"])
			return [textures[s["file"]], r, Vector2(s["ox"], s["oy"])]
	return []
