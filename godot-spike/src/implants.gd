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
## Every implant has a grade (1 street grade ... 4 military).  Fields: acc / acc_far (ranged accuracy; acc_far only at 5+ tiles), aim (aim speed),
## dodge_melee, dodge_bullet (ONLY grade 3 and up can dodge bullets), atk_speed (extra action points per turn: speed above 100), armor + dur (a flat damage deduction
## on `armor_group` limbs that wears out as it soaks damage), arc (degrees added to the 180-degree field of view: a rear-view eye gives 180), and the limb group it lives in (from its body part): it stops working with that limb.
const ALL := [
	{"id": "cortex", "part": "head", "name": "Neural Link", "cost": 4200, "live": true, "grade": 3, "acc": 4, "aim": 0.25, "armor": 1, "armor_group": "head", "dur": 30,
		"desc": "Wireless interface and skull lattice: +4% to hit, faster aim, 1 armor on the head."},
	{"id": "optics", "part": "eyes", "name": "Optic Suite", "cost": 1800, "live": true, "grade": 2, "acc": 2, "acc_far": 5,
		"desc": "Ranging overlay: +2% to hit, +5% more at five or more tiles."},
	{"id": "thermal", "part": "eyes", "name": "Thermal Vision", "cost": 2600, "live": true, "grade": 2, "acc": 3,
		"desc": "Warm bodies stand out of cover and smoke: +3% to hit."},
	{"id": "jets", "part": "spine", "name": "Dorsal Jump Jets", "cost": 3000, "live": true, "grade": 2, "desc": "Short flight, no falling damage while fuel lasts."},
	{"id": "reflex", "part": "spine", "name": "Reflex Wires", "cost": 6200, "live": true, "grade": 3, "aim": 0.5, "dodge_melee": 10, "dodge_bullet": 14, "atk_speed": 10,
		"desc": "Grade 3 wiring: 14% to dodge a bullet, 10% to dodge a blade, quicker aim and strikes."},
	{"id": "synapse", "part": "spine", "name": "Synapse Accelerator", "cost": 11000, "live": true, "grade": 4, "aim": 0.5, "dodge_melee": 18, "dodge_bullet": 26, "atk_speed": 20,
		"desc": "Military grade 4: time slows.  26% to dodge a bullet, 18% to dodge a blade, much faster strikes."},
	{"id": "dermal", "part": "dermal", "name": "Dermal Plating", "cost": 2200, "live": true, "grade": 2, "armor": 2, "armor_group": "all", "dur": 80,
		"desc": "Subdermal plates over the whole body: 2 armor everywhere, until the plating wears through."},
	{"id": "heart", "part": "chest", "name": "Cardiac Booster", "cost": 2800, "live": false, "grade": 2, "armor": 1, "armor_group": "chest", "dur": 30, "desc": "Bigger stamina reserve."},
	{"id": "mantis", "part": "arms", "name": "Mantis Blades", "cost": 3400, "live": true, "grade": 3, "armor": 1, "armor_group": "arms", "dur": 30, "atk_speed": 15,
		"desc": "Forearm blades unfold when your hands are empty: fast, accurate, cannot be knocked away.  1 armor on the arms."},
	{"id": "smartlink", "part": "hands", "name": "Smartlink Palm", "cost": 1500, "live": true, "grade": 2, "acc": 8, "aim": 0.1, "desc": "Gun-to-hand link: +8% to hit with any firearm."},
	{"id": "grip", "part": "hands", "name": "Gecko Grip", "cost": 1700, "live": false, "grade": 2, "desc": "Climb sheer walls."},
	{"id": "legs", "part": "legs", "name": "Leg Actuators", "cost": 1600, "live": true, "grade": 2, "armor": 1, "armor_group": "legs", "dur": 40,
		"desc": "Long jumps and softer landings.  1 armor on the legs."},
]

## durability of an implant: its `dur` (armor implants) or this default.  Damage past a limb's own health wears it down; at 0 it stops working until serviced.
const DEFAULT_DUR := 20
static func dur(d: Dictionary) -> int:
	return int(d.get("dur", DEFAULT_DUR))

## the sum of one numeric field over the implants that are fitted and working
static func sum(implants: Dictionary, field: String, active: Callable = Callable()) -> float:
	var t := 0.0
	for d in ALL:
		if implants.get(d["id"], false) and d.has(field) and (not active.is_valid() or active.call(d)):
			t += float(d[field])
	return t

static func get_def(id: String) -> Dictionary:
	for d in ALL:
		if d["id"] == id:
			return d
	return {}

static func for_part(part: String) -> Array:
	return ALL.filter(func(d): return d["part"] == part)

## surgery price: cheaper in the underground clinics
static func price(id: String, underground: bool) -> int:
	var c: int = int(get_def(id).get("cost", 0))
	return int(c * (0.8 if underground else 1.0))
