extends RefCounted
## The twelve implants the game shipped before the catalogue was replaced (Neural Link, Mantis Blades, Dorsal Jump Jets ...).  They are not in the game any more, but the engine paths they
## drove (flight, jumps, blades, dodge, accuracy, wear) are still tested, so tests that need one register it here: `IMP.add_def`.
const IMP = preload("res://src/implants.gd")
const OLD := [
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

static func install() -> void:
	for d in OLD:
		IMP.add_def(d)
