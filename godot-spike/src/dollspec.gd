extends RefCounted
## What each person looks like: the paper-doll layers drawn over the base sprite, and the weapon in hand.
## Everything shown is real equipment or a real implant (the player) or follows from faction and role (everyone else).
const IMPLANT_LAYER := {"cortex": "imp_cortex", "optics": "imp_optics", "thermal": "imp_thermal", "jets": "imp_jets", "reflex": "imp_reflex",
	"synapse": "imp_synapse", "dermal": "imp_dermal", "mantis": "imp_mantis", "legs": "imp_legs", "smartlink": "imp_smartlink", "heart": "imp_heart", "grip": "imp_grip"}
# draw order: back pack, outfit, body armor, limb armor, head, implants
const ARMOR_LAYER := {"trl_helmet": "helmet_ball", "trl_visor": "visor", "trl_helm_tac": "helm_tac", "trl_balaclava": "balaclava",
	"trl_vest": "vest", "trl_vest_heavy": "vest_heavy", "trl_vest_corp": "vest_corp", "trl_jacket": "jacket", "trl_coat": "coat",
	"trl_bracers": "bracers", "trl_bracers_heavy": "bracers_heavy", "trl_greaves": "greaves", "trl_greaves_heavy": "greaves_heavy", "trl_kneepads": "kneepads",
	"trl_backpack": "backpack", "trl_holster": "holster"}
const MELEE_THUG := ["trl_mel_kastet", "trl_mel_finka", "trl_mel_topor", "trl_mel_tonfa", "trl_mel_lopata", "trl_mel_chekan", "trl_mel_kistien", "trl_mel_kinzhal"]
const ORDER := ["backpack", "holster"]

## layers and the weapon id for person i (an NPC).  Returns {"layers": Array, "weapon": String}
static func for_person(g, i: int) -> Dictionary:
	var layers: Array = []
	var weapon := ""
	var h: int = (i * 2654435761) & 0x7fffffff
	var fac: int = int(g.fac[i])
	var extra: Array = g.eco.look.get(i, []) if g.eco != null else []
	if not extra.is_empty():
		layers = extra.duplicate()
	else:
		match fac:
			1:   # Bratva: red coats, vests on some, anything in the hand
				layers = ["thug"]
				if h % 5 < 2:
					layers.append("vest")
				if h % 7 == 0:
					layers.append("bracers")
				if h % 11 == 0:
					layers.append("balaclava")
			2:   # NAP officers: uniform, helmet, vest, a few with leg armor
				layers = ["nap", "visor" if h % 4 == 0 else "helmet_ball", "vest_heavy" if h % 3 == 0 else "vest"]
				if h % 3 == 1:
					layers.append("greaves")
				if h % 5 == 0:
					layers.append("bracers")
			3:   # Nasim runners: black suits and visible implants
				layers = ["nasim", "imp_reflex", "imp_optics"]
				if h % 3 == 0:
					layers.append("imp_mantis")
				if h % 4 == 0:
					layers.append("imp_cortex")
				if h % 5 == 0:
					layers.append("imp_legs")
			_:   # residents: a jacket in one of six colours, now and then a backpack, a coat or a hood
				layers = ["jacket_%d" % (h % 6)]
				if h % 9 == 0:
					layers = ["coat"]
				elif h % 6 == 0:
					layers.insert(0, "backpack")
				if h % 13 == 0:
					layers.append("kneepads")
	# weapon: by gun class, else a street blade
	var gc: int = int(g.gunc[i])
	if gc > 0:
		var tag: String = ["", "pistol", "smg", "rifle"][gc]
		var arr: Array = g.gun_ids.get(tag, [])
		if not arr.is_empty():
			weapon = arr[h % arr.size()]
	elif fac == 1 or fac == 3:
		if not ("imp_mantis" in layers):
			weapon = MELEE_THUG[h % MELEE_THUG.size()]
	return {"layers": layers, "weapon": weapon}

## the player: worn armor and containers, implants that work, the wielded weapon
static func for_player(g) -> Dictionary:
	var layers: Array = []
	for c in g.worn:
		var l: String = ARMOR_LAYER.get(c.id(), "")
		if l != "":
			layers.append(l)
	for a in g.armor_worn:
		var l2: String = ARMOR_LAYER.get(a.id(), "")
		if l2 != "":
			layers.append(l2)
	for id in IMPLANT_LAYER:
		if g.has_implant(id):
			if id == "mantis" and g.wield != null:
				continue
			layers.append(IMPLANT_LAYER[id])
	# back and holster first, then the rest in the order worn, so a vest sits over a coat
	layers.sort_custom(func(a, b): return _rank(a) < _rank(b))
	return {"layers": layers, "weapon": (g.wield.id() if g.wield != null else "")}

static func _rank(l: String) -> int:
	if l == "backpack" or l == "holster":
		return 0
	if l == "coat" or l == "jacket":
		return 1
	if l.begins_with("vest") or l.begins_with("bracers") or l.begins_with("greaves") or l == "kneepads":
		return 2
	if l.begins_with("imp_"):
		return 4
	return 3
