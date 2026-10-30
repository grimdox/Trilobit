extends RefCounted
## The implant catalogue: what can be fitted to which part of the body.  `live` implants work in the game now; the rest are listed
## on the body screen as "not yet available" so the whole map of the body is visible.
const PARTS := [
	{"id": "head", "name": "Head / cortex", "at": Vector2(0.50, 0.095)},
	{"id": "eyes", "name": "Eyes", "at": Vector2(0.50, 0.135)},
	{"id": "spine", "name": "Spine", "at": Vector2(0.50, 0.28)},
	{"id": "chest", "name": "Chest / organs", "at": Vector2(0.50, 0.36)},
	{"id": "dermal", "name": "Dermal", "at": Vector2(0.50, 0.31)},
	{"id": "arms", "name": "Arms", "at": Vector2(0.27, 0.34)},
	{"id": "hands", "name": "Hands", "at": Vector2(0.14, 0.47)},
	{"id": "legs", "name": "Legs", "at": Vector2(0.43, 0.72)},
]
## The catalogue is generated (tools/gen_implants.py -> implant_data.gd) from the implant spreadsheet: Basic, Improved and Quality implants (tier 1-3, grade = tier).
## Military and Prototype designs stay out of the game for now.  Fields: armor + armor_group + dur (a flat damage deduction on that limb group that wears out as it soaks
## damage), draw (kJ/h the implant always draws), battery (kJ a chest implant stores), skills (bonus to skills while it works), nano (nanohack slots of a Trilobit;
## not used yet), req (skill levels needed to fit it: Grit = tier - 1, and each skill it raises needs bonus + 1), cost (yen).  It stops working with its limb.
const DATA = preload("res://src/implant_data.gd")
const TIER_NAME := {1: "Basic", 2: "Improved", 3: "Quality", 4: "Military", 5: "Prototype"}
const REPAIR_FRACTION := 0.25            # repairing an implant worn to nothing costs this fraction of its price
## what wired people carry (game.gd faction numbers: BRATVA 1, NAP 2): ids from the catalogue.  power.gd NPC_DRAW is the sum of their draw.  Civilians and the gang are unwired;
## Nasim refuse implants (design), so they hold nothing here.
const NPC_RIGS := {1: ["x105", "x108", "x116", "x122"], 2: ["x205", "x208", "x214", "x216", "x222"], 5: ["x205", "x208", "x214", "x216", "x222"]}
static var ALL: Array = _build()
static var _by_id: Dictionary = {}

static func _build() -> Array:
	var out: Array = []
	for d in DATA.ALL:
		var e: Dictionary = (d as Dictionary).duplicate(true)
		e["desc"] = describe(e)
		out.append(e)
	return out

static func skill_name(id: String) -> String:
	return id.substr(0, 1).to_upper() + id.substr(1)

## one line of what an implant does, for the shops and the implants screen
static func describe(d: Dictionary) -> String:
	var bits: Array = []
	var sk: Dictionary = d.get("skills", {})
	for k in sk:
		bits.append("%s %+d" % [skill_name(k), int(sk[k])])
	if int(d.get("armor", 0)) > 0:
		bits.append("armor %d" % int(d["armor"]))
	if d.has("battery"):
		bits.append("stores %d kJ" % int(d["battery"]))
	if d.has("nano"):
		bits.append("%d nanohack slots" % int(d["nano"]))
	bits.append("draws %s kJ/h" % ("%.1f" % float(d.get("draw", 0.0))).trim_suffix(".0"))
	return "%s grade: %s." % [TIER_NAME.get(int(d.get("grade", 1)), "?"), ", ".join(bits)]

## what is still missing before `d` can be fitted: [{skill, need, have}] given a callable skill id -> base level
static func missing(d: Dictionary, level: Callable) -> Array:
	var out: Array = []
	var rq: Dictionary = d.get("req", {})
	for k in rq:
		var have: int = int(level.call(k))
		if have < int(rq[k]):
			out.append({"skill": k, "need": int(rq[k]), "have": have})
	return out

## yen to repair an implant that has `left` of its durability: the fraction of its price that is worn away
static func repair_cost(d: Dictionary, left: int) -> int:
	var mx: int = dur(d)
	if left >= mx:
		return 0
	return int(round(float(d["cost"]) * REPAIR_FRACTION * float(mx - maxi(left, 0)) / float(mx)))

## durability of an implant: its `dur` (armor implants) or this default.  Damage past a limb's own health wears it down; at 0 it stops working until serviced.
const DEFAULT_DUR := 20
static func dur(d: Dictionary) -> int:
	return int(d.get("dur", DEFAULT_DUR))

## the sum of one numeric field over the implants that are fitted and working
static func sum(implants: Dictionary, field: String, active: Callable = Callable()) -> float:
	var t := 0.0
	for id in implants:
		if not implants[id]:
			continue
		var d: Dictionary = get_def(String(id))
		if d.has(field) and (not active.is_valid() or active.call(d)):
			t += float(d[field])
	return t

## the bonus (or malus) to one skill from the implants that are fitted and working
static func skill_bonus(implants: Dictionary, skill: String, active: Callable = Callable()) -> int:
	var t := 0
	for id in implants:
		if not implants[id]:
			continue
		var d: Dictionary = get_def(String(id))
		var sk: Dictionary = d.get("skills", {})
		if sk.has(skill) and (not active.is_valid() or active.call(d)):
			t += int(sk[skill])
	return t

## register an implant definition at run time (tests, mods); replaces one of the same id
static func add_def(d: Dictionary) -> void:
	for i in ALL.size():
		if ALL[i]["id"] == d["id"]:
			ALL[i] = d
			_by_id.clear()
			return
	ALL.append(d)
	_by_id.clear()

static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in ALL:
			_by_id[d["id"]] = d
	return _by_id.get(id, {})

static func for_part(part: String) -> Array:
	return ALL.filter(func(d): return d["part"] == part)

## surgery price: cheaper in the underground clinics
static func price(id: String, underground: bool) -> int:
	var c: int = int(get_def(id).get("cost", 0))
	return int(c * (0.8 if underground else 1.0))

## ---- what the implant sellers stock
## Tiers on offer follow the district's wealth (0 lower, 1 middle, 2 upper): Basic in the lower districts, Basic and Improved in the middle ones, Improved and Quality in the
## rich ones.  A Cyberdoc Office sells only a handful of Basic and Improved implants whatever the district.  The two implant stores split the body: "senses" (head, eyes, spine)
## and "body" (chest, dermal, arms, hands, legs).  Military and Prototype designs are not in the game.
const STORE_PARTS := {"senses": ["head", "eyes", "spine"], "body": ["chest", "dermal", "arms", "hands", "legs"]}
const DOC_COUNT := 6
const STORE_COUNT := 16

static func tiers_for(kind: String, wealth: int) -> Array:
	var t: Array = [[1], [1, 2], [2, 3]][clampi(wealth, 0, 2)]
	if kind == "cyberdoc":
		t = t.filter(func(x): return x <= 2)
	return t

## the implant ids a seller offers: deterministic from `seed_v`, so a shop keeps its stock
static func stock(kind: String, style: String, wealth: int, seed_v: int) -> Array:
	var tiers: Array = tiers_for(kind, wealth)
	var parts: Array = STORE_PARTS.get(style, []) if kind != "cyberdoc" else []
	var pool: Array = []
	for d in ALL:
		if not d.get("live", true) or not (int(d["grade"]) in tiers):
			continue
		if not parts.is_empty() and not (String(d["part"]) in parts):
			continue
		pool.append(d["id"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_v, kind, style, "stock"])
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var n: int = DOC_COUNT if kind == "cyberdoc" else STORE_COUNT
	return pool.slice(0, mini(n, pool.size()))
