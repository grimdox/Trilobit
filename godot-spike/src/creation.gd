extends RefCounted
## Character creation: the choices, their limits and how they are applied.  Pure data and rules; the screen (screen_view.gd) draws it and main.gd owns the keys.
##
##  Appearance  `app` = {sprite, skin, hair, style, eyes} (indices into the tables below, so a save stays valid if a colour is retouched) plus the
##              placeholder background id.  The sprite list is where the supplied character sprites plug in: add an entry and give it art.
##  Attributes  the five attributes of skills.gd start at 10; each can go from 6 to 14, and the total is fixed (50): lowering one frees a point,
##              and a free point is only ever spent raising another.  Nothing here changes the attribute-to-skill rules.
const SK = preload("res://src/skills.gd")
const DS = preload("res://src/dollspec.gd")

const ATTR_MIN := 6
const ATTR_MAX := 14

# the doll still draws from the two bodies in the tileset; `fem` picks the layer set (d_torso_m / d_torso_f)
const SPRITES := [{"id": "m", "name": "Frame A", "fem": false}, {"id": "f", "name": "Frame B", "fem": true}]
const STYLES := ["short", "buzz", "mohawk", "long", "bob", "ponytail", "bun"]
const SKIN_NAMES := ["Pale", "Light tan", "Tanned", "Dark", "Deep brown"]
const HAIR_NAMES := ["Black", "Dark brown", "Chestnut", "Blond", "Grey", "Crimson dye", "Cyan dye"]
const STYLE_NAMES := ["Short", "Buzz cut", "Mohawk", "Long", "Bob", "Ponytail", "Bun"]
# natural eye colours only: an eye that glows or sees in the dark is an implant (pillar 3)
const EYES := [Color(0.34, 0.2, 0.1), Color(0.5, 0.36, 0.14), Color(0.3, 0.5, 0.22), Color(0.25, 0.45, 0.72), Color(0.52, 0.58, 0.62), Color(0.62, 0.45, 0.12)]
const EYE_NAMES := ["Brown", "Hazel", "Green", "Blue", "Grey", "Amber"]
# the appearance rows the screen shows.  Only the sprite for now: skin, hair, eyes and style stay in `app` (saved, drawn on the doll, and
# steppable with `cycle`) but have no row until the supplied sprites say which of them creation should still offer.
const LOOK_ROWS := [{"id": "sprite", "label": "Sprite"}]
const HIDDEN_LOOK := ["skin", "hair", "style", "eyes"]

const BACKGROUNDS := [{"id": "none", "name": "Not chosen yet", "desc": "Background and goals arrive in a later update.  Nothing on this page changes play yet."}]


static func default_app() -> Dictionary:
	# the figure the game has always drawn for the player: Frame A, light skin, grey hair, buzz cut
	return {"sprite": 0, "skin": 0, "hair": 4, "style": 1, "eyes": 0, "bg": "none"}

static func count(field: String) -> int:
	match field:
		"sprite": return SPRITES.size()
		"skin": return DS.SKINS.size()
		"hair": return DS.HAIRS.size()
		"style": return STYLES.size()
		"eyes": return EYES.size()
	return 0

static func option_name(app: Dictionary, field: String) -> String:
	var i: int = int(app.get(field, 0))
	match field:
		"sprite": return String(SPRITES[i]["name"])
		"skin": return SKIN_NAMES[i]
		"hair": return HAIR_NAMES[i]
		"style": return STYLE_NAMES[i]
		"eyes": return EYE_NAMES[i]
	return ""

static func option_color(app: Dictionary, field: String) -> Color:
	var i: int = int(app.get(field, 0))
	match field:
		"skin": return DS.SKINS[i]
		"hair": return DS.HAIRS[i]
		"eyes": return EYES[i]
	return Color(0, 0, 0, 0)

## step one option forward (dir 1) or back (-1), wrapping; returns a new dictionary
static func cycle(app: Dictionary, field: String, dir: int) -> Dictionary:
	var out: Dictionary = app.duplicate()
	var n: int = count(field)
	if n > 0:
		out[field] = (int(out.get(field, 0)) + dir + n) % n
	return out

## a loaded or hand-edited dictionary made safe: every index inside its table, the background a known one
static func sanitize(d: Dictionary) -> Dictionary:
	var out: Dictionary = default_app()
	for f in ["sprite", "skin", "hair", "style", "eyes"]:
		if d.has(f):
			out[f] = clampi(int(d[f]), 0, count(f) - 1)
	var bg := String(d.get("bg", "none"))
	out["bg"] = bg if BACKGROUNDS.any(func(b): return b["id"] == bg) else "none"
	return out

## the look dictionary the paper doll and portrait draw from (same shape as DollSpec.look, plus eye colour)
static func look_of(app: Dictionary) -> Dictionary:
	var a: Dictionary = sanitize(app)
	return {"fem": bool(SPRITES[a["sprite"]]["fem"]), "skin": DS.SKINS[a["skin"]], "hair": DS.HAIRS[a["hair"]], "style": STYLES[a["style"]], "eyes": EYES[a["eyes"]]}


# ---------------------------------------------------------------------------------------------- attributes
static func start_attrs() -> Dictionary:
	return SK.default_attrs()

## the fixed total every character shares: five attributes at the starting 10
static func total() -> int:
	return SK.ATTRS.size() * SK.ATTR_START

## points in the pool: what the lowered attributes have given up and the raised ones have not yet used
static func free_points(attrs: Dictionary) -> int:
	var sum := 0
	for a in SK.ATTRS:
		sum += int(attrs.get(a["id"], SK.ATTR_START))
	return total() - sum

static func can_raise(attrs: Dictionary, id: String) -> bool:
	return attrs.has(id) and int(attrs[id]) < ATTR_MAX and free_points(attrs) > 0

static func can_lower(attrs: Dictionary, id: String) -> bool:
	return attrs.has(id) and int(attrs[id]) > ATTR_MIN

## move one point: raise takes from the pool, lower gives to it; an illegal move returns the attributes unchanged
static func change(attrs: Dictionary, id: String, dir: int) -> Dictionary:
	var out: Dictionary = attrs.duplicate()
	if dir > 0 and can_raise(attrs, id):
		out[id] = int(out[id]) + 1
	elif dir < 0 and can_lower(attrs, id):
		out[id] = int(out[id]) - 1
	return out

## a character may begin when every attribute is inside 6..14 and the pool is empty
static func attrs_valid(attrs: Dictionary) -> bool:
	for a in SK.ATTRS:
		var v: int = int(attrs.get(a["id"], -1))
		if v < ATTR_MIN or v > ATTR_MAX:
			return false
	return free_points(attrs) == 0

## what the pool's state means in words, for the screen
static func pool_text(attrs: Dictionary) -> String:
	var f: int = free_points(attrs)
	if f == 0:
		return "All points spent"
	return "%d free point%s to spend" % [f, "" if f == 1 else "s"]


# ---------------------------------------------------------------------------------------------- a whole profile
static func new_profile() -> Dictionary:
	return {"app": default_app(), "attrs": start_attrs()}

static func profile_valid(p: Dictionary) -> bool:
	return attrs_valid(p.get("attrs", {})) and sanitize(p.get("app", {})) == p.get("app", {})

## put a finished profile on a game's player (called once, right after the world is built)
static func apply(g, p: Dictionary) -> void:
	g.attrs = p["attrs"].duplicate()
	g.app = sanitize(p["app"])
