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
const SKINS := [Color(0.96, 0.8, 0.68), Color(0.88, 0.69, 0.53), Color(0.74, 0.54, 0.38), Color(0.55, 0.38, 0.27), Color(0.38, 0.26, 0.19)]
const HAIRS := [Color(0.1, 0.09, 0.1), Color(0.22, 0.14, 0.09), Color(0.45, 0.3, 0.15), Color(0.72, 0.58, 0.3), Color(0.6, 0.62, 0.66), Color(0.8, 0.2, 0.3), Color(0.2, 0.75, 0.9)]
const STYLES_M := ["short", "buzz", "mohawk", "short", "buzz"]
const STYLES_F := ["long", "bob", "ponytail", "bun", "short"]

## body and look: the layers every figure has, plus skin and hair tints
static func look(h: int, fem: bool, fac: int) -> Dictionary:
	var hs: int = (h >> 4) % 7
	if fac == 3:
		hs = 5 + (h >> 4) % 2
	elif fac == 2:
		hs = (h >> 4) % 4
	var styles: Array = STYLES_F if fem else STYLES_M
	return {"fem": fem, "skin": SKINS[(h >> 8) % SKINS.size()], "hair": HAIRS[hs], "style": styles[(h >> 12) % styles.size()]}

static func base_layers(look: Dictionary, hair_hidden: bool) -> Array:
	var sx: String = "f" if look["fem"] else "m"
	var l: Array = ["d_shadow", "d_legs", "d_torso_" + sx, "d_arms_" + sx, "d_hands", "d_head_" + sx]
	if not hair_hidden:
		l.append("d_hair_" + String(look["style"]))
	return l

## layers and the weapon id for person i (an NPC).  Returns {"layers": Array, "weapon": String}
static func for_person(g, i: int) -> Dictionary:
	var layers: Array = []
	var weapon := ""
	var h: int = (i * 2654435761) & 0x7fffffff
	var fac: int = int(g.fac[i])
	var extra: Array = g.eco.look.get(i, []) if g.eco != null else []
	if extra.is_empty() and fac == 0 and g.island != null and g.zone == Vector2i(0, 1):
		extra = ["overalls"] + (["helmet_ball"] if h % 2 == 0 else [])      # dock workers
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
			4:   # unaffiliated criminals: whatever they scavenged
				layers = ["jacket_%d" % (h % 6)]
				if h % 3 == 0:
					layers.append("bracers")
				if h % 4 == 0:
					layers.append("balaclava")
				if h % 5 == 0:
					layers.append("vest")
			_:   # residents: a jacket in one of six colours, now and then a backpack, a coat or a hood
				layers = ["jacket_%d" % (h % 6)]
				var wl: int = g.city.wealth_at(int(g.sim.home_cell[i]))
				if wl == 2 and h % 3 != 0:
					layers = ["suit"]
				elif wl == 0 and h % 3 == 0:
					layers = ["overalls"]
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
	elif fac == 1 or fac == 3 or fac == 4:
		if not ("imp_mantis" in layers):
			weapon = MELEE_THUG[h % MELEE_THUG.size()]
	var lk := look(h, g.fem[i] == 1, fac)
	lk["hid"] = _hides_hair(layers)
	return {"layers": layers, "weapon": weapon, "look": lk}

static func _hides_hair(layers: Array) -> bool:
	for l in layers:
		if l == "helmet_ball" or l == "visor" or l == "helm_tac" or l == "balaclava":
			return true
	return false

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
	var lk := look(7919, false, 0)
	lk["hid"] = _hides_hair(layers)
	return {"layers": layers, "weapon": (g.wield.id() if g.wield != null else ""), "look": lk}

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
