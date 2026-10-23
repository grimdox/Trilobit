extends RefCounted
## One character's look: everything a doll needs, as plain data (saved and loaded as a Dictionary / JSON).
##
##   body       m_s m_m m_l f_s f_m f_l
##   android    synthetic body: panel seams on the base sprites (pair with a synthetic skin colour)
##   colours    {skin, hair, eyes, cloth1..4, leather, leather2, metal, poly, synth, glow, glow2, under}: preset names or "#rrggbb"
##   hair       style id (manifest "hair"); eyes: shape id; expr: expression id
##   garments   garment ids, any order (draw order comes from the data)
##   implants   implant ids
##   item       held item id (its grip kind picks the stance) or ""

const FIELDS := ["body", "android", "colours", "hair", "eyes", "expr", "garments", "implants", "item"]

var body := "m_m"
var android := false
var colours := {}
var hair := "crop"
var eyes := "round"
var expr := "neutral"
var garments: Array = ["under"]
var implants: Array = []
var item := ""
var meta := {}          # free data (the generator's seed and repair log live here; not part of the look)


static func from_dict(d: Dictionary):
	var s = load("res://addons/trilobit_doll/doll_spec.gd").new()
	s.body = String(d.get("body", "m_m"))
	s.android = bool(d.get("android", false))
	s.colours = Dictionary(d.get("colours", {})).duplicate()
	s.hair = String(d.get("hair", "crop"))
	s.eyes = String(d.get("eyes", "round"))
	s.expr = String(d.get("expr", "neutral"))
	s.garments = Array(d.get("garments", ["under"])).duplicate()
	s.implants = Array(d.get("implants", [])).duplicate()
	s.item = String(d.get("item", ""))
	s.meta = Dictionary(d.get("meta", {})).duplicate(true)
	return s

func to_dict() -> Dictionary:
	return {"body": body, "android": android, "colours": colours.duplicate(), "hair": hair, "eyes": eyes, "expr": expr,
		"garments": garments.duplicate(), "implants": implants.duplicate(), "item": item, "meta": meta.duplicate(true)}

func duplicate_spec():
	return from_dict(to_dict())

## the stance for this look: the held item's grip kind, or unarmed
func grip(lib) -> String:
	if item == "":
		return "unarmed"
	return String(lib.man["items"].get(item, "unarmed"))

## a stable string of the look (palette and composition caches key on it)
func look_key() -> String:
	var g := garments.duplicate()
	var im := implants.duplicate()
	var ks := colours.keys()
	ks.sort()
	var cs := []
	for k in ks:
		cs.append("%s=%s" % [k, colours[k]])
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [body, android, ",".join(cs), hair, eyes, expr, ",".join(g), ",".join(im), item]
