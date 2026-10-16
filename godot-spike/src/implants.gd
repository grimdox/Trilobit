extends RefCounted
## The implant catalogue: what can be fitted to which part of the body.  `live` implants work in the game now; the rest are listed
## on the body screen as "not yet available" so the whole map of the body is visible.
const PARTS := [
	{"id": "head", "name": "Head / cortex", "at": Vector2(0.50, 0.095)},
	{"id": "eyes", "name": "Eyes", "at": Vector2(0.50, 0.135)},
	{"id": "spine", "name": "Spine", "at": Vector2(0.50, 0.28)},
	{"id": "chest", "name": "Chest / organs", "at": Vector2(0.50, 0.36)},
	{"id": "arms", "name": "Arms", "at": Vector2(0.27, 0.34)},
	{"id": "hands", "name": "Hands", "at": Vector2(0.14, 0.47)},
	{"id": "legs", "name": "Legs", "at": Vector2(0.43, 0.72)},
]
const ALL := [
	{"id": "cortex", "part": "head", "name": "Neural Link", "cost": 4200, "live": false, "desc": "Wireless interface for nanohacks and drone control."},
	{"id": "optics", "part": "eyes", "name": "Optic Suite", "cost": 1800, "live": true, "desc": "Ranging overlay: +5% to hit at five or more tiles."},
	{"id": "thermal", "part": "eyes", "name": "Thermal Vision", "cost": 2600, "live": false, "desc": "See warm bodies through smoke and darkness."},
	{"id": "jets", "part": "spine", "name": "Dorsal Jump Jets", "cost": 3000, "live": true, "desc": "Short flight, no falling damage while fuel lasts."},
	{"id": "reflex", "part": "spine", "name": "Reflex Wires", "cost": 3600, "live": false, "desc": "Extra action when surprised."},
	{"id": "dermal", "part": "chest", "name": "Dermal Plating", "cost": 2200, "live": true, "desc": "Every hit that lands does 2 less damage."},
	{"id": "heart", "part": "chest", "name": "Cardiac Booster", "cost": 2800, "live": false, "desc": "Bigger stamina reserve."},
	{"id": "mantis", "part": "arms", "name": "Mantis Blades", "cost": 3400, "live": false, "desc": "Forearm blades that unfold in a turn."},
	{"id": "smartlink", "part": "hands", "name": "Smartlink Palm", "cost": 1500, "live": true, "desc": "Gun-to-hand link: +8% to hit with any firearm."},
	{"id": "grip", "part": "hands", "name": "Gecko Grip", "cost": 1700, "live": false, "desc": "Climb sheer walls."},
	{"id": "legs", "part": "legs", "name": "Leg Actuators", "cost": 1600, "live": true, "desc": "Long jumps and softer landings."},
]

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
