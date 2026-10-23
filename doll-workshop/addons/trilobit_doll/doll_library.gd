extends RefCounted
## A baked doll set: the manifest (dolls.json), the index pages (8-bit, palette-coloured) and the colour pages (held items).
## Load once and share: DollLibrary.shared("res://dolls").  compose() is the one place that decides what a doll draws in
## a frame and in which order; the rig and the tests both use it.

const PAL = preload("res://addons/trilobit_doll/doll_palette.gd")

static var _shared := {}

var dir := ""
var man: Dictionary = {}
var idx_pages: Array = []
var rgba_pages: Array = []
var sprites: Dictionary = {}
var origin := Vector2(40, 88)
var ok := false
var error := ""

static func shared(path: String = "res://dolls"):
	if not _shared.has(path):
		_shared[path] = load("res://addons/trilobit_doll/doll_library.gd").new(path)
	return _shared[path]

func _init(path: String) -> void:
	dir = path
	var f := FileAccess.open(path.path_join("dolls.json"), FileAccess.READ)
	if f == null:
		error = "no dolls.json in " + path
		return
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		error = "dolls.json is not an object"
		return
	man = d
	sprites = man.get("sprites", {})
	var o: Array = man.get("origin", [40, 88])
	origin = Vector2(o[0], o[1])
	for n in int(man["pages"]["i"]):
		idx_pages.append(_texture(path.path_join("doll_idx_%d.png" % n)))
	for n in int(man["pages"]["c"]):
		rgba_pages.append(_texture(path.path_join("doll_rgba_%d.png" % n)))
	ok = error == ""

## an imported texture if the project imported it, else the PNG read directly (lossless either way)
func _texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t = ResourceLoader.load(path)
		if t is Texture2D:
			return t
	var img := Image.load_from_file(path if not path.begins_with("res://") else ProjectSettings.globalize_path(path))
	if img == null:
		error = "cannot load " + path
		return null
	return ImageTexture.create_from_image(img)

func bodies() -> Array:
	return man["bodies"].keys()

## frame ids of an animation for a grip, in play order ("unarmed/idle/0", ...; the fall is "any/down/i")
func frames(anim: String, grip: String) -> Array:
	var out := []
	if anim == "down":
		for i in int(man["down"]["frames"]):
			out.append("any/down/%d" % i)
	else:
		for i in int(man["anims"][anim]["frames"]):
			out.append("%s/%s/%d" % [grip, anim, i])
	return out

func durations(anim: String) -> Array:
	return man["down"]["dur"] if anim == "down" else man["anims"][anim]["dur"]

func loops(anim: String) -> bool:
	return false if anim == "down" else bool(man["anims"][anim]["loop"])

func event_frame(anim: String) -> int:
	return -1 if anim == "down" else int(man["anims"][anim]["event"])

func frame_meta(body: String, fid: String) -> Dictionary:
	return man["frames"].get(body, {}).get(fid, {})

func palette_texture(spec) -> ImageTexture:
	return PAL.texture_for(spec.colours, man["palette"])

## what spec draws in frame fid: [{key, page (Texture2D), region (Rect2), pos (Vector2, cell pixels), indexed (bool), order}]
## sorted back to front.  Garments that hide hair or the face remove them; frames that hide the face drop it.
func compose(spec, fid: String) -> Array:
	var out := []
	var groups: Array = man["groups"]
	var body: String = spec.body
	var fm := frame_meta(body, fid)
	var n := 0
	var hides_hair := false
	var hides_face := not bool(fm.get("face", true))
	for gid in spec.garments:
		var g: Dictionary = man["garments"].get(gid, {})
		hides_hair = hides_hair or bool(g.get("hides_hair", false))
		hides_face = hides_face or bool(g.get("hides_face", false))
	var prefix := "a" if spec.android else "b"
	for layer in ["back", "far", "body", "near", "hands"]:
		n = _add(out, "%s/%s/%s/%s" % [prefix, body, fid, layer], Vector2.ZERO, n)
	for gid in spec.garments:
		for grp in groups:
			n = _add(out, "g/%s/%s/%s/%s" % [body, fid, gid, grp], Vector2.ZERO, n)
	for iid in spec.implants:
		for grp in groups:
			n = _add(out, "i/%s/%s/%s/%s" % [body, fid, iid, grp], Vector2.ZERO, n)
	if not hides_hair and spec.hair != "bald":
		for grp in ["head", "back"]:
			n = _add(out, "h/%s/%s/%s/%s" % [body, fid, spec.hair, grp], Vector2.ZERO, n)
	if not hides_face and fm.has("eye"):
		var e: Array = fm["eye"]
		n = _add(out, "f/%s/%s/%s" % [body, spec.eyes, spec.expr], Vector2(e[0], e[1]), n)
	if spec.item != "" and fm.has("hold"):
		var gp: Array = fm["grip"]
		n = _add(out, "held/%s/%s" % [spec.item, fm["hold"]], Vector2(gp[0], gp[1]), n)
	out.sort_custom(func(a, b): return a["order"] < b["order"])
	return out

func _add(out: Array, key: String, at: Vector2, n: int) -> int:
	var s = sprites.get(key)
	if s == null:
		return n
	# [kind, page, x, y, w, h, ox, oy, group, sub]
	var indexed: bool = s[0] == "i"
	var pages: Array = idx_pages if indexed else rgba_pages
	var order: float = float(s[8]) * 1000.0 + float(s[9]) * 10.0 + n * 0.001
	out.append({"key": key, "page": pages[int(s[1])], "region": Rect2(s[2], s[3], s[4], s[5]), "pos": at + Vector2(s[6], s[7]),
		"indexed": indexed, "order": order})
	return n + 1
