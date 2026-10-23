extends RefCounted
## Dolls for code that draws with CanvasItem.draw_* (one canvas item for a whole view, so no per-doll shader):
## composes a spec's frame into one RGBA texture on the CPU, palette applied, exactly as the palette shader would, and
## keeps the result.  A look is composed once per frame id; afterwards drawing it costs one draw_texture call.
##
##   var dim = DollImage.for_library("res://gfx/dolls32")
##   var tex: Texture2D = dim.texture(spec, "unarmed/idle/0")
##   draw_texture(tex, foot - dim.origin())          # the cell's ground point on the foot point

const LIB = preload("res://addons/trilobit_doll/doll_library.gd")
const PAL = preload("res://addons/trilobit_doll/doll_palette.gd")
const MAX_TEXTURES := 800          # looks x frames kept; the oldest are dropped first

static var _by_path := {}

var lib
var cell := 96
var _idx: Array = []               # PackedByteArray per index page (L8)
var _rgba: Array = []              # PackedByteArray per colour page (RGBA8)
var _pw := 2048
var _luts := {}
var _tex := {}
var _order: Array = []

static func for_library(path: String):
	if not _by_path.has(path):
		_by_path[path] = load("res://addons/trilobit_doll/doll_image.gd").new(LIB.shared(path))
	return _by_path[path]

func _init(library) -> void:
	lib = library
	if not lib.ok:
		return
	cell = int(lib.man.get("cell", 96))
	_pw = int(lib.man.get("page_size", 2048))
	for t in lib.idx_pages:
		var img: Image = t.get_image()
		if img.is_compressed():
			img.decompress()
		if img.get_format() != Image.FORMAT_L8:
			img.convert(Image.FORMAT_L8)
		_idx.append(img.get_data())
	for t in lib.rgba_pages:
		var img2: Image = t.get_image()
		if img2.is_compressed():
			img2.decompress()
		if img2.get_format() != Image.FORMAT_RGBA8:
			img2.convert(Image.FORMAT_RGBA8)
		_rgba.append(img2.get_data())

func ok() -> bool:
	return lib != null and lib.ok

## the ground point (between the feet) inside the cell
func origin() -> Vector2:
	return lib.origin

func _lut(colours: Dictionary) -> PackedByteArray:
	var ks := colours.keys()
	ks.sort()
	var key := ""
	for k in ks:
		key += "%s=%s;" % [k, colours[k]]
	if _luts.has(key):
		return _luts[key]
	var rows: Array = PAL.palette_rows(colours, lib.man["palette"])
	var lut := PackedByteArray()
	lut.resize(256 * 4)
	for r in PAL.ROWS:
		for s in PAL.SHADES:
			var c := Color(String(rows[r][s]))
			var o := (r * PAL.SHADES + s) * 4
			lut[o] = c.r8
			lut[o + 1] = c.g8
			lut[o + 2] = c.b8
			lut[o + 3] = 255
	lut[3] = 0                     # index 0 never draws
	_luts[key] = lut
	return lut

## the doll as one cell-sized texture (null if the set is missing)
func texture(spec, fid: String) -> Texture2D:
	if not ok():
		return null
	var key: String = spec.look_key() + "#" + fid
	if _tex.has(key):
		return _tex[key]
	var img := image(spec, fid)
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	_order.append(key)
	if _order.size() > MAX_TEXTURES:
		_tex.erase(_order.pop_front())
	return tex

## the doll as an RGBA image, back to front as compose() orders it
func image(spec, fid: String) -> Image:
	var lut := _lut(spec.colours)
	var buf := PackedByteArray()
	buf.resize(cell * cell * 4)
	for e in lib.compose(spec, fid):
		var s: Array = lib.sprites[e["key"]]
		var page: int = int(s[1])
		var rx: int = int(s[2])
		var ry: int = int(s[3])
		var w: int = int(s[4])
		var h: int = int(s[5])
		var p: Vector2 = e["pos"]
		var px: int = int(p.x)
		var py: int = int(p.y)
		var x0: int = maxi(0, -px)
		var x1: int = mini(w, cell - px)
		if x1 <= x0:
			continue
		if e["indexed"]:
			var data: PackedByteArray = _idx[page]
			for y in range(maxi(0, -py), mini(h, cell - py)):
				var src: int = (ry + y) * _pw + rx
				var dst: int = ((py + y) * cell + px) * 4
				for x in range(x0, x1):
					var v: int = data[src + x]
					if v == 0:
						continue
					var o: int = dst + x * 4
					var l: int = v * 4
					buf[o] = lut[l]
					buf[o + 1] = lut[l + 1]
					buf[o + 2] = lut[l + 2]
					buf[o + 3] = 255
		else:
			var cdata: PackedByteArray = _rgba[page]
			for y in range(maxi(0, -py), mini(h, cell - py)):
				var src2: int = ((ry + y) * _pw + rx) * 4
				var dst2: int = ((py + y) * cell + px) * 4
				for x in range(x0, x1):
					var a: int = cdata[src2 + x * 4 + 3]
					if a == 0:
						continue
					var o2: int = dst2 + x * 4
					var q: int = src2 + x * 4
					buf[o2] = cdata[q]
					buf[o2 + 1] = cdata[q + 1]
					buf[o2 + 2] = cdata[q + 2]
					buf[o2 + 3] = 255
	return Image.create_from_data(cell, cell, false, Image.FORMAT_RGBA8, buf)
