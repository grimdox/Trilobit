extends RefCounted
## Seeded character generation by archetype, with rules that keep every result well composed.
##
## generate(seed, archetype) -> DollSpec.  Same seed and archetype, same doll, on every machine (Godot's PCG32).
## The rules (validate) and the repairs are explicit: each repair is one targeted change written to spec.meta["log"],
## at most MAX_PASSES passes, and a spec that still fails falls back to the archetype's reference look (also logged).
##
## Rules
##   R1 one garment per category (base, legs, feet, outer, head, hands); armour at most one per body area
##      (torso, arms, legs); straps at most two
##   R2 implants never share a body slot (two hardware pieces in one place)
##   R3 contrast: an outer layer differs from the layer under it by at least MIN_DL in OKLab lightness, legwear from the
##      outer layer, and a bare-skin top from the skin
##   R4 danger red (the red coat) only on hostile archetypes
##   R5 androids wear a synthetic skin; humans a human one
##   R6 the held item's stance must exist (an item id the manifest knows)

const PAL = preload("res://addons/trilobit_doll/doll_palette.gd")
const SPEC = preload("res://addons/trilobit_doll/doll_spec.gd")

const MAX_PASSES := 6
const MIN_DL := 0.07
const HUMAN_SKINS := ["porcelain", "fair", "olive", "tan", "brown", "deep"]
const COLOURED_SKINS := ["blue", "red", "yellow", "green", "orange", "purple", "dark gray"]   # muted non-natural tones, as in the game
const COLOURED_SKIN_PCT := 30                  # how often a generated human gets one (the game's DollSpec rate); 0 switches them off
const SYNTH_SKINS := ["pearl", "graphite", "ceramic", "bone"]
const GENERATED_SYNTH := ["pearl", "graphite", "ceramic"]     # bone reads as human skin at game scale: hand-made dolls only
const NATURAL_HAIR := ["black", "violet black", "dark brown", "chestnut", "ash blond", "platinum", "grey"]
const DYED_HAIR := ["teal dye", "cyan dye", "violet dye", "wine dye"]
const CATEGORY := {"under": "under", "bodysuit": "base", "tank": "base", "tee": "base", "turtleneck": "base", "shirt": "base",
	"cargo": "legs", "slacks": "legs", "leggings": "legs", "shorts": "legs", "skirt": "legs",
	"boots": "feet", "boots_high": "feet", "sneakers": "feet",
	"bomber": "outer", "trench": "outer", "suit_jacket": "outer", "hoodie": "outer", "labcoat": "outer", "robe": "outer", "apron": "outer",
	"overalls": "outer", "poncho": "outer",
	"vest": "armor:torso", "vest_heavy": "armor:torso", "vest_corp": "armor:torso", "riot": "armor:torso", "bracers": "armor:arms",
	"bracers_heavy": "armor:arms", "greaves": "armor:legs", "greaves_heavy": "armor:legs", "kneepads": "armor:legs",
	"harness": "straps", "sling": "straps", "holster": "straps", "backpack": "straps",
	"gloves": "hands", "helmet_ball": "head", "helm_tac": "head", "visor": "head", "balaclava": "head", "facemask": "head", "hood_up": "head"}
# a bodysuit already covers the legs
const COVERS_LEGS := ["bodysuit", "overalls"]

# archetype: body weights, garment pools per category (with the chance a category is worn), implants, colours, hair, items
const ARCH := {
	"operative": {"bodies": {"m_m": 3, "f_m": 3, "m_l": 1, "f_l": 2, "m_s": 1, "f_s": 1},
		"wear": [[1.0, ["bodysuit", "bodysuit", "turtleneck"]], [1.0, ["cargo", "slacks"]], [1.0, ["boots", "boots_high"]],
			[0.35, ["trench", "bomber"]], [0.45, ["vest_heavy", "vest"]], [0.5, ["harness", "holster", "sling"]], [0.5, ["gloves"]],
			[0.12, ["helm_tac", "facemask"]]],
		"implants": [0, 3, ["cortex", "optic_r", "optic_twin", "shoulder_mount", "smartlink", "spine", "cyberarm_r", "neural_plate"]],
		"cloth": ["gunmetal", "black", "olive", "slate", "ink navy", "drab"], "accent": ["olive", "teal", "drab", "khaki"],
		"hair": ["crop", "bob", "buzz", "undercut", "slick", "ponytail", "pixie"], "dyed": 0.15,
		"items": ["trl_gun_vk74", "trl_gun_ha5", "trl_gun_sp45", "trl_gun_zp9", "trl_gun_hx9", "trl_gun_sa14"], "item_p": 0.8,
		"metal": ["chrome", "gunmetal", "black chrome"], "glow": ["cyan", "teal", "amber"]},
	"netrunner": {"bodies": {"m_s": 3, "f_s": 3, "f_m": 2, "m_m": 1},
		"wear": [[1.0, ["tank", "tee", "turtleneck"]], [1.0, ["leggings", "cargo", "shorts"]], [1.0, ["sneakers", "boots"]],
			[0.6, ["hoodie", "bomber", "poncho"]], [0.25, ["backpack", "sling"]], [0.15, ["facemask"]]],
		"implants": [1, 3, ["cortex", "neural_plate", "antenna", "spine", "optic_r", "optic_l", "smartlink", "jaw"]],
		"cloth": ["black", "gunmetal", "slate", "ink navy", "teal", "bone"], "accent": ["teal", "drab", "bone", "rust"],
		"hair": ["undercut", "mohawk", "pixie", "shag", "bob", "buzz", "topknot", "long"], "dyed": 0.55,
		"items": ["trl_kit_repair", "trl_gun_lp22", "trl_gun_gp10", "trl_mel_tanto", "trl_mel_kunai"], "item_p": 0.45,
		"metal": ["chrome", "black chrome"], "glow": ["cyan", "violet", "teal"]},
	"enforcer": {"bodies": {"m_l": 4, "f_l": 3, "m_m": 2}, "hostile": true,
		"wear": [[1.0, ["tee", "tank"]], [1.0, ["cargo"]], [1.0, ["boots"]], [0.85, ["riot", "vest_heavy"]], [0.5, ["kneepads", "greaves_heavy"]],
			[0.45, ["bracers_heavy", "bracers"]], [0.3, ["helmet_ball", "visor", "balaclava"]], [0.4, ["gloves"]]],
		"implants": [1, 3, ["cyberarm_r", "cyberarm_l", "knee_actuator", "jaw", "optic_twin", "calf_pistons", "shoulder_mount", "dermal"]],
		"cloth": ["black", "olive", "gunmetal", "drab", "slate"], "accent": ["olive", "black", "drab"],
		"hair": ["buzz", "mohawk", "topknot", "crop", "bald", "undercut"], "dyed": 0.1,
		"items": ["trl_mel_ono", "trl_mel_katana", "trl_gun_vm12", "trl_gun_hs10", "trl_mel_topor", "trl_gun_zk15"], "item_p": 0.9,
		"metal": ["gunmetal", "black chrome", "chrome"], "glow": ["amber", "cyan"]},
	"android": {"bodies": {"f_m": 3, "f_s": 2, "m_m": 2, "f_l": 1, "m_s": 1}, "android": true,
		"wear": [[0.4, ["bodysuit", "turtleneck", "tank"]], [0.35, ["leggings", "slacks"]], [0.35, ["sneakers", "boots_high"]],
			[0.3, ["labcoat", "trench", "suit_jacket"]]],
		"implants": [0, 2, ["optic_twin", "neural_plate", "cortex", "antenna", "jaw"]],
		"cloth": ["white", "bone", "slate", "black", "gunmetal"], "accent": ["teal", "slate", "bone"],
		"hair": ["bald", "bob", "slick", "pixie", "long", "bald"], "dyed": 0.3,
		"items": ["trl_kit_repair", "trl_medkit", "trl_gun_se9"], "item_p": 0.3,
		"metal": ["chrome", "black chrome"], "glow": ["cyan", "white", "violet"]},
	"corporate": {"bodies": {"m_m": 3, "f_m": 3, "m_s": 2, "f_s": 2, "f_l": 1, "m_l": 1},
		"wear": [[1.0, ["shirt", "turtleneck"]], [1.0, ["slacks", "skirt"]], [1.0, ["boots", "sneakers"]], [0.8, ["suit_jacket", "trench", "labcoat"]]],
		"implants": [0, 2, ["cortex", "optic_r", "neural_plate", "smartlink"]],
		"cloth": ["gunmetal", "slate", "ink navy", "black", "white", "bone", "khaki"], "accent": ["slate", "teal", "bone"],
		"hair": ["slick", "bob", "bun", "crop", "ponytail", "pixie"], "dyed": 0.08,
		"items": ["trl_gun_fp7", "trl_medkit"], "item_p": 0.2,
		"metal": ["chrome", "brass"], "glow": ["white", "cyan"]},
	"street": {"bodies": {"m_m": 3, "m_s": 2, "f_m": 2, "f_s": 2, "m_l": 2, "f_l": 1}, "hostile": true,
		"wear": [[1.0, ["tee", "tank", "shirt"]], [1.0, ["cargo", "slacks", "shorts", "leggings"]], [1.0, ["boots", "sneakers"]],
			[0.75, ["bomber", "hoodie", "trench"]], [0.25, ["vest", "bracers"]], [0.2, ["balaclava", "facemask"]], [0.2, ["holster", "harness"]]],
		"implants": [0, 2, ["mantis", "cyberarm_r", "jaw", "optic_r", "knee_actuator", "antenna"]],
		"cloth": ["black", "red coat", "oxblood", "drab", "olive", "rust", "gunmetal"], "accent": ["black", "bone", "rust"],
		"hair": ["undercut", "mohawk", "buzz", "shag", "crop", "ponytail", "braid", "slick"], "dyed": 0.3,
		"items": ["trl_mel_finka", "trl_mel_kastet", "trl_mel_topor", "trl_mel_kinzhal", "trl_gun_vr38", "trl_gun_zp19", "trl_mel_tonfa"],
		"item_p": 0.75, "metal": ["chrome", "gunmetal", "brass"], "glow": ["amber", "cyan", "violet"]},
	"resident": {"bodies": {"m_m": 3, "f_m": 3, "m_s": 2, "f_s": 2, "m_l": 1, "f_l": 1},
		"wear": [[1.0, ["tee", "shirt", "turtleneck", "tank"]], [1.0, ["slacks", "cargo", "shorts", "skirt", "leggings"]],
			[1.0, ["sneakers", "boots"]], [0.6, ["bomber", "hoodie", "trench", "apron", "overalls", "labcoat"]], [0.15, ["backpack"]]],
		"implants": [0, 1, ["optic_r", "cortex", "smartlink", "cyberarm_r", "cyberleg_r"]],
		"cloth": ["slate", "olive", "gunmetal", "ink navy", "drab", "teal", "bone", "khaki", "rust", "oxblood", "white"],
		"accent": ["bone", "teal", "slate", "drab"],
		"hair": ["crop", "bob", "long", "ponytail", "bun", "shag", "slick", "pixie", "buzz", "braid"], "dyed": 0.12,
		"items": ["trl_kit_repair", "trl_medkit"], "item_p": 0.15, "metal": ["chrome", "brass"], "glow": ["cyan", "amber"]},
}

var lib


func _init(library) -> void:
	lib = library

func archetypes() -> Array:
	return ARCH.keys()

## one doll from a seed; archetype "" picks one from the seed too
func generate(seed_value: int, archetype := ""):
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var arch := archetype
	if arch == "" or not ARCH.has(arch):
		var names := ARCH.keys()
		names.sort()
		arch = names[rng.randi_range(0, names.size() - 1)]
	var A: Dictionary = ARCH[arch]
	var s = SPEC.new()
	s.meta = {"seed": seed_value, "archetype": arch, "log": []}
	# only bodies this baked set has (a partial bake still generates valid dolls)
	var bw := {}
	for k in A["bodies"]:
		if lib.man["bodies"].has(k):
			bw[k] = A["bodies"][k]
	if bw.is_empty():
		for k in lib.man["bodies"]:
			bw[k] = 1
	s.body = _weighted(rng, bw)
	s.android = bool(A.get("android", false))
	# wear: one draw per category line, kept only when the chance comes up
	s.garments = ["under"]
	for line in A["wear"]:
		if rng.randf() < float(line[0]):
			var pool: Array = line[1]
			s.garments.append(pool[rng.randi_range(0, pool.size() - 1)])
	# implants: a count, then distinct ones
	var ip: Array = A["implants"]
	var count := rng.randi_range(int(ip[0]), int(ip[1]))
	var pool2: Array = (ip[2] as Array).duplicate()
	for i in count:
		if pool2.is_empty():
			break
		var k := rng.randi_range(0, pool2.size() - 1)
		s.implants.append(pool2[k])
		pool2.remove_at(k)
	# colours: skin, hair, eyes, then cloth from the archetype's family
	var c := {}
	if s.android:
		c["skin"] = GENERATED_SYNTH[rng.randi_range(0, GENERATED_SYNTH.size() - 1)]
	elif rng.randi_range(0, 99) < COLOURED_SKIN_PCT:
		c["skin"] = COLOURED_SKINS[rng.randi_range(0, COLOURED_SKINS.size() - 1)]
	else:
		c["skin"] = HUMAN_SKINS[rng.randi_range(0, HUMAN_SKINS.size() - 1)]
	if s.android:
		c["synth"] = c["skin"]
	var dyed := rng.randf() < float(A["dyed"])
	var hp: Array = DYED_HAIR if dyed else NATURAL_HAIR
	c["hair"] = hp[rng.randi_range(0, hp.size() - 1)]
	var eyes: Array = lib.man["palette"]["eyes"].keys()
	eyes.sort()
	c["eyes"] = eyes[rng.randi_range(0, eyes.size() - 1)]
	var fam: Array = A["cloth"]
	for slot in ["cloth1", "cloth2", "cloth3"]:
		c[slot] = fam[rng.randi_range(0, fam.size() - 1)]
	var acc: Array = A["accent"]
	c["cloth4"] = acc[rng.randi_range(0, acc.size() - 1)]
	c["leather"] = ["black", "#2e2a2a", "#3a302a", "gunmetal"][rng.randi_range(0, 3)]
	c["leather2"] = ["black", "#3a302a", "#2e2a2a"][rng.randi_range(0, 2)]
	var metals: Array = A["metal"]
	c["metal"] = metals[rng.randi_range(0, metals.size() - 1)]
	var glows: Array = A["glow"]
	c["glow"] = glows[rng.randi_range(0, glows.size() - 1)]
	s.colours = c
	var hairs: Array = A["hair"]
	s.hair = hairs[rng.randi_range(0, hairs.size() - 1)]
	var shapes: Array = lib.man["eye_shapes"].keys()
	shapes.sort()
	s.eyes = shapes[rng.randi_range(0, shapes.size() - 1)]
	s.expr = ["neutral", "neutral", "neutral", "focused", "angry"][rng.randi_range(0, 4)] if bool(A.get("hostile", false)) else \
		["neutral", "neutral", "neutral", "focused"][rng.randi_range(0, 3)]
	if rng.randf() < float(A["item_p"]):
		var items: Array = A["items"]
		s.item = items[rng.randi_range(0, items.size() - 1)]
	repair(s, rng, A)
	return s

func _weighted(rng: RandomNumberGenerator, w: Dictionary) -> String:
	var keys := w.keys()
	keys.sort()
	var total := 0.0
	for k in keys:
		total += float(w[k])
	var r := rng.randf() * total
	for k in keys:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return keys[-1]

## every rule broken by spec s: [[rule, detail, subject]]
func validate(s, archetype: Dictionary = {}) -> Array:
	var bad := []
	# R1
	var seen := {}
	var straps := 0
	for gid in s.garments:
		if not lib.man["garments"].has(gid):
			bad.append(["R1", "unknown garment", gid])
			continue
		var cat: String = CATEGORY.get(gid, "other")
		if cat == "straps":
			straps += 1
			if straps > 2:
				bad.append(["R1", "more than two strap pieces", gid])
			continue
		if seen.has(cat):
			bad.append(["R1", "two pieces in %s" % cat, gid])
		seen[cat] = gid
		if cat == "legs":
			for cover in COVERS_LEGS:
				if cover in s.garments:
					bad.append(["R1", "legwear under a full suit", gid])
	# R2
	var taken := {}
	for iid in s.implants:
		if not lib.man["implants"].has(iid):
			bad.append(["R2", "unknown implant", iid])
			continue
		for slot in lib.man["implants"][iid]["slots"]:
			if taken.has(slot):
				bad.append(["R2", "%s and %s share %s" % [taken[slot], iid, slot], iid])
			taken[slot] = iid
	# R3
	var mats_of := func(gid: String) -> Array:
		return lib.man["garments"].get(gid, {}).get("mats", [])
	var base_slot := ""
	var outer_slot := ""
	var legs_slot := ""
	for gid in s.garments:
		var cat: String = CATEGORY.get(gid, "")
		var m: Array = mats_of.call(gid)
		if cat == "base" and "cloth1" in m:
			base_slot = "cloth1"
		elif cat == "outer" and "cloth2" in m:
			outer_slot = "cloth2"
		elif cat == "legs" and "cloth3" in m:
			legs_slot = "cloth3"
	if base_slot != "" and outer_slot != "" and _dl(s, base_slot, outer_slot) < MIN_DL:
		bad.append(["R3", "outer layer too close to the layer under it", "cloth2"])
	if outer_slot != "" and legs_slot != "" and _dl(s, outer_slot, legs_slot) < MIN_DL * 0.6:
		bad.append(["R3", "legwear too close to the outer layer", "cloth3"])
	if ("tank" in s.garments) and outer_slot == "" and _dl(s, "cloth1", "skin") < MIN_DL:
		bad.append(["R3", "top too close to the skin", "cloth1"])
	# R4
	if not bool(archetype.get("hostile", false)):
		for k in s.colours:
			if String(s.colours[k]) == "red coat":
				bad.append(["R4", "danger red on a non-hostile doll", k])
	# R5
	var sk := String(s.colours.get("skin", "tan"))
	if s.android and (sk in HUMAN_SKINS or sk in COLOURED_SKINS):
		bad.append(["R5", "android with a human skin", "skin"])
	if not s.android and sk in SYNTH_SKINS:
		bad.append(["R5", "human with a synthetic skin", "skin"])
	# R6
	if s.item != "" and not lib.man["items"].has(s.item):
		bad.append(["R6", "unknown item", s.item])
	return bad

func _colour_hex(s, slot: String) -> String:
	var tables: Dictionary = lib.man["palette"]
	var v := String(s.colours.get(slot, PAL.DEFAULT_COLOURS.get(slot, "")))
	if slot == "skin":
		return v if v.begins_with("#") else String(tables["skins"][v]["mid"])
	return PAL.pick(v, tables["cloth"])

func _dl(s, a: String, b: String) -> float:
	return absf(PAL.lch(_colour_hex(s, a)).x - PAL.lch(_colour_hex(s, b)).x)

## targeted, logged repairs until the spec is valid; falls back to the archetype's reference look
func repair(s, rng: RandomNumberGenerator, A: Dictionary) -> void:
	var log: Array = s.meta.get("log", [])
	for p in MAX_PASSES:
		var bad := validate(s, A)
		if bad.is_empty():
			s.meta["log"] = log
			return
		var b: Array = bad[0]
		match b[0]:
			"R1", "R6":
				if b[0] == "R6":
					s.item = ""
				else:
					s.garments.erase(b[2])
				log.append("%s: dropped %s (%s)" % [b[0], b[2], b[1]])
			"R2":
				s.implants.erase(b[2])
				log.append("R2: dropped %s (%s)" % [b[2], b[1]])
			"R3", "R4", "R5":
				var slot: String = b[2]
				var choices: Array
				if slot == "skin":
					choices = GENERATED_SYNTH if s.android else HUMAN_SKINS
				else:
					choices = A.get("cloth", ["gunmetal"]) if slot != "cloth4" else A.get("accent", ["slate"])
				var before := String(s.colours.get(slot, ""))
				var tries := choices.duplicate()
				tries.erase(before)
				if b[0] == "R4":
					tries.erase("red coat")
				# pick the candidate that fixes the rule with the most contrast, deterministically
				var best := ""
				var best_score := -1.0
				for cand in tries:
					s.colours[slot] = cand
					var still := false
					for nb in validate(s, A):
						if nb[0] == b[0] and nb[2] == slot:
							still = true
					var score := (0.0 if still else 1.0) + rng.randf() * 0.01
					if score > best_score:
						best_score = score
						best = cand
				s.colours[slot] = best
				if slot == "skin" and s.android:
					s.colours["synth"] = best
				log.append("%s: %s %s -> %s (%s)" % [b[0], slot, before, best, b[1]])
	var bad2 := validate(s, A)
	if not bad2.is_empty():
		log.append("fallback: %d rules still broken, reference look used" % bad2.size())
		s.garments = ["under", "tee", "cargo", "boots"]
		s.implants = []
		s.colours = {"skin": "pearl" if s.android else "tan", "synth": "pearl", "cloth1": "slate", "cloth2": "olive", "cloth3": "black"}
		s.item = ""
	s.meta["log"] = log
