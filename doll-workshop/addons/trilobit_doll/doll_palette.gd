extends RefCounted
## Palettes: the runtime port of tools/dollgen/materials.py (ramp, glow_ramp, palette_for).  Every colour is built in
## OKLab exactly as the generator builds it, so a doll in the game looks exactly like its bake preview; the tests compare
## this port against the reference ramps recorded in the manifest.
##
## A palette is 32 rows (materials) x 8 shades: 0-5 the lit ramp, 6 rim light, 7 specular.

const ROWS := 32
const SHADES := 8
# material rows (materials.py)
const INK := 1
const SKIN := 2
const LIP := 3
const HAIR := 4
const SCLERA := 5
const IRIS := 6
const DARK := 7
const CLOTH1 := 8
const CLOTH2 := 9
const CLOTH3 := 10
const CLOTH4 := 11
const LEATHER := 12
const LEATHER2 := 13
const METAL := 14
const POLY := 15
const SYNTH := 16
const GLOW := 17
const GLOW2 := 18
const UNDER := 19
const LENS := 20

const SHADOW_HUE := 290.0 * PI / 180.0
const LIGHT_HUE := 75.0 * PI / 180.0
const STEPS := [-0.40, -0.275, -0.145, 0.0, 0.125, 0.23]

const DEFAULT_COLOURS := {"skin": "tan", "hair": "black", "eyes": "brown", "cloth1": "gunmetal", "cloth2": "olive", "cloth3": "black",
	"cloth4": "teal", "leather": "#2e2a2a", "leather2": "#3a302a", "metal": "chrome", "poly": "#3a3f48", "synth": "pearl", "glow": "cyan",
	"glow2": "amber", "under": "#3a3d46"}


static func _s2l(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)

static func _l2s(c: float) -> float:
	c = clampf(c, 0.0, 1.0)
	return 12.92 * c if c <= 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055

static func hex_rgb(h: String) -> Vector3:
	var s := h.trim_prefix("#")
	return Vector3(s.substr(0, 2).hex_to_int() / 255.0, s.substr(2, 2).hex_to_int() / 255.0, s.substr(4, 2).hex_to_int() / 255.0)

static func rgb_hex(c: Vector3) -> String:
	var out := "#"
	for x in [c.x, c.y, c.z]:
		var v: int = int(floor(clampf(x, 0.0, 1.0) * 255.0 + 0.5))
		out += "%02x" % v
	return out

static func _cbrt(x: float) -> float:
	return signf(x) * pow(absf(x), 1.0 / 3.0)

static func to_oklab(rgb: Vector3) -> Vector3:
	var r := _s2l(rgb.x)
	var g := _s2l(rgb.y)
	var b := _s2l(rgb.z)
	var l := _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
	var m := _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
	var s := _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)

static func from_oklab(lab: Vector3) -> Vector3:
	var L := lab.x
	var a := lab.y
	var b := lab.z
	# cubed by multiplication: pow() of a negative base is NaN, Python's ** 3 keeps the sign
	var l := _cube(L + 0.3963377774 * a + 0.2158037573 * b)
	var m := _cube(L - 0.1055613458 * a - 0.0638541728 * b)
	var s := _cube(L - 0.0894841775 * a - 1.2914855480 * b)
	var r := 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
	var g := -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
	var bb := -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
	return Vector3(_l2s(r), _l2s(g), _l2s(bb))

static func _cube(x: float) -> float:
	return x * x * x

static func lch(hexc: String) -> Vector3:
	var lab := to_oklab(hex_rgb(hexc))
	return Vector3(lab.x, sqrt(lab.y * lab.y + lab.z * lab.z), atan2(lab.z, lab.y))

static func from_lch(L: float, C: float, h: float) -> String:
	return rgb_hex(from_oklab(Vector3(L, C * cos(h), C * sin(h))))

static func _toward(h: float, target: float, t: float) -> float:
	var d := fposmod(target - h + PI, 2.0 * PI) - PI
	return h + d * t

## eight colours from a mid tone, exactly as materials.ramp
static func ramp(mid: String, contrast := 1.0, shadow_shift := 0.32, light_shift := 0.18, rim_mix := 0.42, chroma_keep := 1.0,
		spec := "", rim := "#7fe3ee") -> PackedStringArray:
	var lc := lch(mid)
	var L := lc.x
	var C := lc.y * chroma_keep
	var h := lc.z
	var out := PackedStringArray()
	for dl0 in STEPS:
		var dl: float = dl0 * contrast
		var Li := clampf(L + dl, 0.05, 0.97)
		var hi: float
		var Ci: float
		if dl < 0.0:
			var t := minf(1.0, -dl / 0.36) * shadow_shift
			hi = _toward(h, SHADOW_HUE, t)
			Ci = C * (1.0 - 0.45 * minf(1.0, -dl / 0.36)) + 0.012 * t
		else:
			var t2 := minf(1.0, dl / 0.2) * light_shift
			hi = _toward(h, LIGHT_HUE, t2)
			Ci = C * (1.0 - 0.25 * minf(1.0, dl / 0.2))
		out.append(from_lch(Li, Ci, hi))
	var r0 := hex_rgb(out[2])
	var r1 := hex_rgb(rim)
	var lin := Vector3(_s2l(r0.x) * (1.0 - rim_mix) + _s2l(r1.x) * rim_mix, _s2l(r0.y) * (1.0 - rim_mix) + _s2l(r1.y) * rim_mix,
		_s2l(r0.z) * (1.0 - rim_mix) + _s2l(r1.z) * rim_mix)
	out.append(rgb_hex(Vector3(_l2s(lin.x), _l2s(lin.y), _l2s(lin.z))))
	out.append(spec if spec != "" else from_lch(minf(0.97, L + 0.3), C * 0.35, _toward(h, LIGHT_HUE, 0.5)))
	return out

static func glow_ramp(core: String) -> PackedStringArray:
	var lc := lch(core)
	var L := lc.x
	var C := lc.y
	var h := lc.z
	return PackedStringArray([from_lch(0.25, C * 0.5, h), from_lch(0.4, C * 0.8, h), from_lch(0.55, C, h), from_lch(L, C, h),
		from_lch(minf(0.96, L + 0.1), C * 0.7, h), from_lch(0.97, C * 0.25, h), from_lch(L, C, h), "#ffffff"])

## a preset name or a #rrggbb colour
static func pick(name: String, table: Dictionary) -> String:
	if name.begins_with("#"):
		return name
	return String(table.get(name, table.values()[0]))

## the 32 x 8 palette (rows of hex strings) for a colour choice dictionary; `tables` is manifest["palette"]
static func palette_rows(colours: Dictionary, tables: Dictionary) -> Array:
	var c: Dictionary = DEFAULT_COLOURS.duplicate()
	for k in colours:
		if String(colours[k]) != "":
			c[k] = colours[k]
	var pal: Array = []
	for row in tables["default"]:
		pal.append(PackedStringArray(row))
	var skins: Dictionary = tables["skins"]
	var sk: String = c["skin"]
	var skin_mid := sk if sk.begins_with("#") else String(skins[sk]["mid"])
	var skin_k := 1.0 if sk.begins_with("#") else float(skins[sk]["contrast"])
	pal[SKIN] = ramp(skin_mid, skin_k)
	var sl := lch(skin_mid)
	pal[LIP] = ramp(from_lch(sl.x - 0.07, sl.y * 1.25 + 0.01, _toward(sl.z, 15.0 * PI / 180.0, 0.35)), 0.8)
	pal[HAIR] = ramp(pick(c["hair"], tables["hair"]), 0.85)
	pal[IRIS] = ramp(pick(c["eyes"], tables["eyes"]))
	pal[CLOTH1] = ramp(pick(c["cloth1"], tables["cloth"]))
	pal[CLOTH2] = ramp(pick(c["cloth2"], tables["cloth"]))
	pal[CLOTH3] = ramp(pick(c["cloth3"], tables["cloth"]))
	pal[CLOTH4] = ramp(pick(c["cloth4"], tables["cloth"]))
	pal[LEATHER] = ramp(pick(c["leather"], tables["cloth"]), 0.9)
	pal[LEATHER2] = ramp(pick(c["leather2"], tables["cloth"]), 0.9)
	pal[METAL] = ramp(pick(c["metal"], tables["metal"]), 1.35, 0.32, 0.18, 0.42, 0.6, "#ffffff")
	pal[POLY] = ramp(pick(c["poly"], tables["cloth"]), 1.0, 0.32, 0.18, 0.42, 1.0, "#c9d6e6")
	var syn: String = c["synth"]
	pal[SYNTH] = ramp(syn if syn.begins_with("#") else String(skins[syn]["mid"]), 0.85, 0.32, 0.18, 0.42, 1.0, "#ffffff")
	pal[GLOW] = glow_ramp(pick(c["glow"], tables["glow"]))
	pal[GLOW2] = glow_ramp(pick(c["glow2"], tables["glow"]))
	pal[UNDER] = ramp(pick(c["under"], tables["cloth"]), 0.9)
	return pal

## the palette as an 8 x 32 texture for the shader (row 0 is transparent: index 0 never draws)
static func texture_for(colours: Dictionary, tables: Dictionary) -> ImageTexture:
	var rows := palette_rows(colours, tables)
	var img := Image.create(SHADES, ROWS, false, Image.FORMAT_RGBA8)
	for r in ROWS:
		for s in SHADES:
			var col := Color(String(rows[r][s]))
			img.set_pixel(s, r, col)
	img.set_pixel(0, 0, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
