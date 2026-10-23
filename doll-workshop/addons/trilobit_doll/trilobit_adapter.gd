extends RefCounted
## Trilobit's current look data -> a DollSpec.
##
## The game (godot-spike/src/dollspec.gd) describes a person as a list of layer ids (outfits such as "thug" or
## "jacket_3", worn items such as "vest" or "helmet_ball", implant layers "imp_optics") plus a look dictionary
## (fem, skin_i, hair_i, eye_i, style, eye_shape) and a weapon id.  spec_from_game turns that into a spec for the
## new dolls, using the outfit, worn-item and implant tables the manifest carries.

const SPEC = preload("res://addons/trilobit_doll/doll_spec.gd")
const LIB = preload("res://addons/trilobit_doll/doll_library.gd")

const SKINS := ["porcelain", "fair", "tan", "brown", "deep", "blue", "red", "yellow", "green", "orange", "purple", "dark gray"]   # DollSpec.SKINS order
const HAIRS := ["black", "dark brown", "chestnut", "ash blond", "grey", "wine dye", "cyan dye"]   # DollSpec.HAIRS order
const EYES := ["brown", "hazel", "green", "blue", "grey", "amber", "red", "violet", "gold", "orange", "teal"]   # creation.gd EYES order
const STYLES := {"short": "crop", "buzz": "buzz", "mohawk": "mohawk", "long": "long", "bob": "bob", "ponytail": "ponytail", "bun": "bun"}


static func spec_from_game(layers: Array, look: Dictionary, weapon := "", size := "m", library_path := "res://dolls"):
	# the 64 px and 32 px sets share every id, so either library gives the same spec
	var lib = LIB.shared(library_path)
	var man: Dictionary = lib.man
	var s = SPEC.new()
	s.body = ("f_" if bool(look.get("fem", false)) else "m_") + size
	s.colours = {"skin": SKINS[clampi(int(look.get("skin_i", 0)), 0, SKINS.size() - 1)],
		"hair": HAIRS[clampi(int(look.get("hair_i", 0)), 0, HAIRS.size() - 1)],
		"eyes": EYES[clampi(int(look.get("eye_i", 0)), 0, EYES.size() - 1)]}
	s.hair = STYLES.get(String(look.get("style", "short")), "crop")
	s.eyes = String(look.get("eye_shape", "round"))
	if not man["eye_shapes"].has(s.eyes):
		s.eyes = "round"
	s.garments = ["under"]
	s.implants = []
	var outfits: Dictionary = man["outfits"]
	var worn: Dictionary = man["worn"]
	var game_imp: Dictionary = man["implant_game"]
	for l in layers:
		var id := String(l)
		if outfits.has(id):
			for g in outfits[id]["garments"]:
				if not (g in s.garments):
					s.garments.append(g)
			for slot in outfits[id]["colours"]:
				s.colours[slot] = outfits[id]["colours"][slot]
		elif worn.has(id):
			if not (worn[id] in s.garments):
				s.garments.append(worn[id])
		elif id.begins_with("imp_") and game_imp.has(id.substr(4)):
			for iid in game_imp[id.substr(4)]:
				if not (iid in s.implants):
					s.implants.append(iid)
	if weapon != "" and man["items"].has(weapon):
		s.item = weapon
	return s
