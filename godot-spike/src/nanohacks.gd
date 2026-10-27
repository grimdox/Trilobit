extends RefCounted
## Nanohacks: small programs run by a Trilobit.  One chip takes one Trilobit slot (Implants.slots counts them).
## kinds: "passive" works while it is installed and the Trilobit is powered, at no cost; "active" is switched on from the N menu for USE_KJ
## and runs `turns` turns, drawing `draw` kJ/h extra while it does; "instant" is a single act (Shock).
## Placeholders for now: the numbers live here so they can be tuned in one place.

const USE_KJ := 10.0                     # battery cost of one activation
const ACTIVE_TURNS := 100                # 10 minutes (600 turns = 1 hour)
const ACTIVE_DRAW := 5.0                 # extra kJ/h while an active hack runs
const SHOCK_DAMAGE := 10

## id, name, kind, effect, text, [tube colours] for the chip art
const ALL := [
	{"id": "plating", "name": "Plating", "kind": "active", "armor": 1, "turns": ACTIVE_TURNS, "draw": ACTIVE_DRAW,
		"text": "Hardens the skin-weave: +1 armor on every body part for 10 minutes.", "cols": ["#4fd0ff", "#9fe8ff", "#2a7fd0"]},
	{"id": "reflex", "name": "Reflex", "kind": "active", "skills": {"dodge": 1}, "turns": ACTIVE_TURNS, "draw": ACTIVE_DRAW,
		"text": "Overclocks the nerves: +1 Dodge for 10 minutes.", "cols": ["#ffe14a", "#ffb02a", "#fff3a0"]},
	{"id": "shock", "name": "Shock", "kind": "instant", "damage": SHOCK_DAMAGE,
		"text": "Overloads a target in sight: 10 damage to a random implanted body part.  Unwired people take nothing.", "cols": ["#ff3ec8", "#c23cff", "#ffd0f4"]},
	{"id": "strike", "name": "Strike", "kind": "active", "skills": {"unarmed": 1, "melee": 1}, "turns": ACTIVE_TURNS, "draw": ACTIVE_DRAW,
		"text": "Primes the muscles: +1 Unarmed and +1 Melee for 10 minutes.", "cols": ["#ff5a4a", "#ff9a3a", "#d02a2a"]},
	{"id": "research", "name": "Skill: Research", "kind": "passive", "skills": {"research": 1},
		"text": "A standing lookup routine: +1 Research while installed.  No upkeep.", "cols": ["#6dff9a", "#2ad08a", "#c8ffd8"]},
]

static var _by_id: Dictionary = {}

static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in ALL:
			_by_id[d["id"]] = d
	return _by_id.get(id, {})

static func chip_item(id: String) -> String:
	return "trl_nano_" + id

## the hack a chip item holds ("" for any other item)
static func of_item(item_id: String) -> String:
	return item_id.substr(9) if item_id.begins_with("trl_nano_") else ""

static func is_active(d: Dictionary) -> bool:
	return String(d["kind"]) == "active"
