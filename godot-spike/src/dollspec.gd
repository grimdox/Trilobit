extends RefCounted
## What each person looks like: the paper-doll layers drawn over the base sprite, and the weapon in hand.
## Everything shown is real equipment or a real implant (the player) or follows from faction and role (everyone else).
## the doll art for a fitted implant is chosen by the body part it goes in (the art predates the catalogue)
const PART_LAYER := {"head": "imp_cortex", "eyes": "imp_optics", "spine": "imp_reflex", "chest": "imp_heart", "dermal": "imp_dermal", "arms": "imp_mantis",
	"hands": "imp_smartlink", "legs": "imp_legs"}
# draw order: back pack, outfit, body armor, limb armor, head, implants
const ARMOR_LAYER := {"trl_helmet": "helmet_ball", "trl_visor": "visor", "trl_helm_tac": "helm_tac", "trl_balaclava": "balaclava",
	"trl_vest": "vest", "trl_vest_heavy": "vest_heavy", "trl_vest_corp": "vest_corp", "trl_jacket": "jacket", "trl_coat": "coat",
	"trl_bracers": "bracers", "trl_bracers_heavy": "bracers_heavy", "trl_greaves": "greaves", "trl_greaves_heavy": "greaves_heavy", "trl_kneepads": "kneepads",
	"trl_backpack": "backpack", "trl_holster": "holster",
	"trl_armor_head_1": "balaclava", "trl_armor_head_2": "helmet_ball", "trl_armor_head_3": "helmet_ball", "trl_armor_head_4": "helm_tac", "trl_armor_head_5": "visor",
	"trl_armor_chest_1": "jacket", "trl_armor_chest_2": "vest", "trl_armor_chest_3": "vest_corp", "trl_armor_chest_4": "vest_heavy", "trl_armor_chest_5": "vest_heavy",
	"trl_armor_arms_1": "bracers", "trl_armor_arms_2": "bracers", "trl_armor_arms_3": "bracers", "trl_armor_arms_4": "bracers_heavy", "trl_armor_arms_5": "bracers_heavy",
	"trl_armor_legs_1": "greaves", "trl_armor_legs_2": "greaves", "trl_armor_legs_3": "greaves", "trl_armor_legs_4": "greaves_heavy", "trl_armor_legs_5": "greaves_heavy"}
const MELEE_THUG := ["trl_mel_kastet", "trl_mel_finka", "trl_mel_topor", "trl_mel_tonfa", "trl_mel_lopata", "trl_mel_chekan", "trl_mel_kistien", "trl_mel_kinzhal"]
const ORDER := ["backpack", "holster"]
const SKINS := [Color(0.96, 0.8, 0.68), Color(0.88, 0.69, 0.53), Color(0.74, 0.54, 0.38), Color(0.55, 0.38, 0.27), Color(0.38, 0.26, 0.19),
	Color(0.40, 0.52, 0.68), Color(0.68, 0.40, 0.38), Color(0.72, 0.65, 0.30), Color(0.40, 0.57, 0.40), Color(0.72, 0.45, 0.25), Color(0.52, 0.40, 0.63), Color(0.23, 0.24, 0.27)]    # then blue, red, yellow, green, orange, purple, dark gray
const NATURAL_SKINS := 5               # the first five are the natural tones; people get a muted blue, red, yellow, green, orange, purple or dark gray skin this often:
const COLOURED_SKIN_PCT := 30
const NATURAL_EYES := 6
const COLOURED_EYE_PCT := 25            # and an eye of one of the five unusual colours (red, violet, gold, orange, teal) this often (set both to 0 to switch the fantasy colours off)
const HAIRS := [Color(0.1, 0.09, 0.1), Color(0.22, 0.14, 0.09), Color(0.45, 0.3, 0.15), Color(0.72, 0.58, 0.3), Color(0.6, 0.62, 0.66), Color(0.8, 0.2, 0.3), Color(0.2, 0.75, 0.9)]
const STYLES_M := ["short", "buzz", "mohawk", "short", "buzz"]
const STYLES_F := ["long", "bob", "ponytail", "bun", "short"]
# the standing dolls (gfx/figure): skin ramps in SKINS order, hair styles in creation.gd STYLES order, eye shapes
const FIG_SKINS := ["skin_pale", "skin_fair", "skin_tan", "skin_brown", "skin_deep", "skin_blue", "skin_red", "skin_yellow", "skin_green", "skin_orange", "skin_purple", "skin_gray"]
const FIG_STYLES := ["short", "buzz", "mohawk", "long", "bob", "ponytail", "bun"]
const EYE_SHAPES := ["round", "almond", "hooded", "wide"]
const EYE_COUNT := 11
const BODY_SIZES := ["s", "m", "m", "l"]      # the layered dolls' body frames for people (small, medium twice as often, large)

## body and look: the layers every figure has, plus skin and hair tints
static func look(h: int, fem: bool, fac: int) -> Dictionary:
	var hs: int = (h >> 4) % 7
	if fac == 3:
		hs = 5 + (h >> 4) % 2
	elif fac == 2:
		hs = (h >> 4) % 4
	var styles: Array = STYLES_F if fem else STYLES_M
	var si: int = (h >> 8) % NATURAL_SKINS
	if (h >> 25) % 100 < COLOURED_SKIN_PCT:
		si = NATURAL_SKINS + (h >> 20) % (SKINS.size() - NATURAL_SKINS)
	var ei: int = (h >> 16) % NATURAL_EYES
	if (h >> 17) % 100 < COLOURED_EYE_PCT:
		ei = NATURAL_EYES + (h >> 22) % (EYE_COUNT - NATURAL_EYES)
	return {"fem": fem, "skin": SKINS[si], "hair": HAIRS[hs], "style": styles[(h >> 12) % styles.size()],
		"skin_i": si, "hair_i": hs, "eye_i": ei, "eye_shape": EYE_SHAPES[(h >> 19) % EYE_SHAPES.size()],
		"size": BODY_SIZES[(h >> 27) % BODY_SIZES.size()]}

static func base_layers(look: Dictionary, hair_hidden: bool) -> Array:
	var sx: String = "f" if look["fem"] else "m"
	var l: Array = ["d_shadow", "d_legs", "d_torso_" + sx, "d_arms_" + sx, "d_hands", "d_head_" + sx]
	if not hair_hidden:
		l.append("d_hair_" + String(look["style"]))
	return l

## the standing-doll keys for a spec, in draw order.  `fig` is the atlas (figure.gd); keys it has no sprite for are left out
## (implants have no standing sprites yet).  Augmented people (any implant layer) get the augmented body.
static func figure_keys(spec: Dictionary, fig) -> Array:
	var lk: Dictionary = spec["look"]
	var layers: Array = spec["layers"]
	var aug := false
	for l in layers:
		if String(l).begins_with("imp_"):
			aug = true
	var base: String = "base:%s:%s:" % ["BX" if aug else "B", FIG_SKINS[clampi(int(lk.get("skin_i", 0)), 0, FIG_SKINS.size() - 1)]]
	var keys: Array = ["base:shadow", base + "body", "base:under"]
	var sleeved := false
	for l in layers:
		var ls := String(l)
		keys.append(ls)
		keys.append(ls + "_back")
		if fig.has(ls + "_arm"):
			keys.append(ls + "_arm")
			if fig.z(ls + "_arm") < 48:          # a sleeve (z 45-46) covers the arm; arm armor (z 48) sits on the bare arm
				sleeved = true
	keys.append(base + ("arms_sleeved" if sleeved else "arms"))
	keys.append(base + "hands")
	if String(spec.get("weapon", "")) != "":
		keys.append(String(spec["weapon"]))
	var style := String(lk.get("style", "short"))
	if not bool(lk.get("hid", false)) and style in FIG_STYLES:
		keys.append("hair_%s_%d" % [style, int(lk.get("hair_i", 0))])
		keys.append("hair_%s_%d_back" % [style, int(lk.get("hair_i", 0))])
	if not ("visor" in layers or "helm_tac" in layers):
		keys.append("eyes_%s_%d" % [String(lk.get("eye_shape", "round")), int(lk.get("eye_i", 0))])
	var out: Array = []
	for n in keys.size():
		var k := String(keys[n])
		if fig.has(k):
			out.append([fig.z(k) * 1000 + n, k])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out.map(func(e): return e[1])

## layers and the weapon id for person i (an NPC).  Returns {"layers": Array, "weapon": String}
static func for_person(g, i: int) -> Dictionary:
	var layers: Array = []
	var weapon := ""
	var h: int = (i * 2654435761) & 0x7fffffff
	var fac: int = int(g.fac[i])
	var extra: Array = g.eco.look.get(i, []) if g.eco != null else []
	if extra.is_empty() and fac == 0 and g.island != null and g.zone == g.island.PORT_ZONE:
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

## a commuter on a train: a resident's clothes, picked by a hash (see Transit.passenger)
static func for_commuter(h: int) -> Dictionary:
	var layers: Array = ["jacket_%d" % (h % 6)]
	if h % 5 == 0:
		layers = ["suit"]
	elif h % 7 == 0:
		layers = ["coat"]
	elif h % 4 == 0:
		layers.insert(0, "backpack")
	var lk := look(h, (h >> 20) % 2 == 1, 0)
	lk["hid"] = false
	return {"layers": layers, "weapon": "", "look": lk}

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
	var shown := {}
	for id in g.implants:
		if not g.has_implant(String(id)):
			continue
		var part: String = String(g.IMP.get_def(String(id)).get("part", ""))
		if part == "" or shown.has(part) or (part == "arms" and g.wield != null):
			continue
		shown[part] = true
		layers.append(PART_LAYER[part])
	# back and holster first, then the rest in the order worn, so a vest sits over a coat
	layers.sort_custom(func(a, b): return _rank(a) < _rank(b))
	var lk: Dictionary = load("res://src/creation.gd").look_of(g.app)      # loaded here, not preloaded: creation.gd reads this file's colour tables
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
