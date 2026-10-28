extends RefCounted
## Signs and map symbols.  Every business, house and tower gets a unique name and a sign on its front wall; every business type has a pictogram and a colour, used
## on the signs and on the local map.  Pure data and drawing: citygen.gd holds the buildings, view.gd draws the signs, main.gd / screen_view.gd the map.
##   make(city, seed)  names every building (no two alike) and returns the signs: [{kind, type, name, cell (the street cell outside the door), side (0 N, 1 S, 2 W, 3 E: which way the
##                     door faces), shape, pal, glyph, col}]
##   draw_glyph(canvas, glyph, centre, radius, colour)   the pictograms (about 30), drawn from lines and polygons so they scale
##   Designs: four shapes (board, neon, banner, plaque) x three palettes per category = twelve looks for each business type, picked from the building's name.

const COL_FOOD := Color(1.0, 0.58, 0.25)
const COL_SHOP := Color(0.36, 0.82, 1.0)
const COL_SERVICE := Color(0.55, 1.0, 0.72)
const COL_CIVIC := Color(0.82, 0.64, 1.0)
const COL_INDUSTRY := Color(1.0, 0.85, 0.3)
const COL_MED := Color(0.45, 1.0, 0.55)
const COL_IMPLANT := Color(1.0, 0.3, 0.7)
const COL_HOME := Color(0.78, 0.74, 0.66)
const COL_TOWER := Color(0.7, 0.8, 0.95)
const COL_TERMINAL := Color(1.0, 0.95, 0.3)

## business type -> [glyph, colour, short legend text]
const TYPE_SYM := {
	"restaurant": ["fork", COL_FOOD, "Restaurant"], "noodle_stall": ["bowl", COL_FOOD, "Noodle stall"], "cafe": ["cup", Color(0.85, 0.65, 0.4), "Cafe"],
	"bar": ["glass", Color(1.0, 0.45, 0.45), "Bar"], "shady_bar": ["glass", Color(0.8, 0.3, 0.5), "Dive bar"], "nightclub": ["note", Color(0.85, 0.4, 1.0), "Nightclub, karaoke"],
	"karaoke": ["note", Color(0.85, 0.4, 1.0), "Nightclub, karaoke"], "bakery": ["bread", Color(1.0, 0.8, 0.45), "Bakery"],
	"convenience": ["cart", COL_SHOP, "Convenience store, grocery"], "grocery": ["cart", COL_SHOP, "Convenience store, grocery"], "liquor_store": ["bottle", Color(0.75, 0.55, 0.3), "Liquor store"],
	"clothing": ["hanger", Color(1.0, 0.6, 0.85), "Clothing"], "electronics": ["bolt", Color(0.4, 0.9, 1.0), "Electronics"], "office_supply": ["book", Color(0.7, 0.85, 1.0), "Office supply, bookshop"],
	"bookshop": ["book", Color(0.7, 0.85, 1.0), "Office supply, bookshop"], "martial_shop": ["fist", Color(1.0, 0.5, 0.35), "Martial arts, dojo"], "dojo": ["fist", Color(1.0, 0.5, 0.35), "Martial arts, dojo"],
	"pawn_shop": ["coin", Color(0.9, 0.8, 0.35), "Pawn shop, bank"], "bank": ["coin", Color(0.9, 0.8, 0.35), "Pawn shop, bank"], "gun_dealer": ["gun", Color(1.0, 0.3, 0.3), "Gun dealer"],
	"hardware": ["wrench", Color(0.95, 0.75, 0.3), "Hardware, garage"], "auto_garage": ["wrench", Color(0.95, 0.75, 0.3), "Hardware, garage"], "pharmacy": ["cross", Color(0.4, 1.0, 0.6), "Pharmacy"],
	"clinic": ["cross", Color(1.0, 1.0, 1.0), "Doctor's office"], "car_dealer": ["car", Color(0.5, 0.75, 1.0), "Car dealer"],
	"implant_shop": ["chip", COL_IMPLANT, "Implant store"], "implant_body": ["chip", Color(1.0, 0.55, 0.3), "Implant store (body)"], "cyberdoc": ["chip", Color(0.3, 1.0, 1.0), "Cyberdoc Office"],
	"police": ["shield", Color(0.4, 0.55, 1.0), "Police, government"], "gov_office": ["shield", Color(0.4, 0.55, 1.0), "Police, government"], "labor_center": ["people", COL_CIVIC, "Labor Center"],
	"post_depot": ["crate", Color(0.8, 0.7, 0.5), "Post depot, warehouse"], "warehouse": ["crate", Color(0.8, 0.7, 0.5), "Post depot, warehouse"],
	"hotel": ["bed", Color(0.6, 0.7, 1.0), "Hotel"], "gym": ["dumbbell", Color(1.0, 0.65, 0.3), "Gym"], "salon": ["scissors", Color(1.0, 0.6, 0.9), "Salon"], "laundromat": ["drop", Color(0.5, 0.85, 1.0), "Laundromat"],
	"arcade": ["pad", Color(0.6, 1.0, 0.5), "Arcade"], "church": ["church", Color(0.9, 0.85, 1.0), "Church"], "shrine": ["torii", Color(1.0, 0.4, 0.3), "Shrine"],
	"workshop": ["gear", COL_INDUSTRY, "Workshop, machine shop, scrap"], "machine_shop": ["gear", COL_INDUSTRY, "Workshop, machine shop, scrap"], "scrap_yard": ["gear", COL_INDUSTRY, "Workshop, machine shop, scrap"],
}
const OTHER_SYM := {"house": ["house", COL_HOME, "House"], "tower": ["tower", COL_TOWER, "Tower"], "terminal": ["terminal", COL_TERMINAL, "Mission terminal"]}

## the palettes of a category: [background, text, edge]
const PALS := {
	"food": [[Color(0.35, 0.1, 0.08), Color(1.0, 0.92, 0.8), Color(1.0, 0.6, 0.25)], [Color(0.95, 0.75, 0.3), Color(0.25, 0.1, 0.05), Color(0.6, 0.2, 0.1)], [Color(0.1, 0.1, 0.12), Color(1.0, 0.5, 0.2), Color(1.0, 0.8, 0.4)]],
	"retail": [[Color(0.08, 0.2, 0.32), Color(0.9, 0.97, 1.0), Color(0.36, 0.82, 1.0)], [Color(0.9, 0.95, 0.98), Color(0.05, 0.2, 0.35), Color(0.2, 0.5, 0.75)], [Color(0.08, 0.08, 0.14), Color(0.4, 0.9, 1.0), Color(1.0, 0.3, 0.7)]],
	"service": [[Color(0.06, 0.25, 0.2), Color(0.9, 1.0, 0.95), Color(0.5, 1.0, 0.7)], [Color(0.85, 0.95, 0.9), Color(0.05, 0.25, 0.2), Color(0.2, 0.6, 0.45)], [Color(0.07, 0.1, 0.1), Color(0.5, 1.0, 0.8), Color(0.3, 0.9, 1.0)]],
	"civic": [[Color(0.2, 0.1, 0.3), Color(0.96, 0.92, 1.0), Color(0.82, 0.64, 1.0)], [Color(0.85, 0.82, 0.92), Color(0.15, 0.08, 0.25), Color(0.5, 0.3, 0.75)], [Color(0.1, 0.08, 0.14), Color(0.9, 0.75, 1.0), Color(1.0, 0.85, 0.4)]],
	"industry": [[Color(0.22, 0.2, 0.1), Color(1.0, 0.95, 0.7), Color(1.0, 0.85, 0.3)], [Color(0.9, 0.8, 0.3), Color(0.15, 0.12, 0.05), Color(0.4, 0.35, 0.1)], [Color(0.12, 0.12, 0.12), Color(1.0, 0.85, 0.3), Color(0.8, 0.8, 0.8)]],
	"home": [[Color(0.25, 0.2, 0.16), Color(0.95, 0.9, 0.82), Color(0.78, 0.7, 0.55)], [Color(0.85, 0.8, 0.7), Color(0.2, 0.15, 0.1), Color(0.5, 0.4, 0.3)], [Color(0.12, 0.14, 0.18), Color(0.8, 0.85, 0.9), Color(0.5, 0.6, 0.7)]],
}
const SHAPES := ["board", "neon", "banner", "plaque"]

# ---------------------------------------------------------------- names
const FIRST := {
	"food": ["Golden", "Blue", "Red", "Little", "Happy", "Midnight", "Old", "Lucky", "Silver", "Jade", "Neon", "Rusty", "Quiet", "Grand", "Sunrise", "Harbor", "Iron", "Paper", "Saffron", "Copper"],
	"retail": ["Bright", "Kuro", "Sakura", "Metro", "Delta", "Atlas", "Nova", "Ginza", "Union", "Polar", "Orbit", "Apex", "Cobalt", "Lotus", "Vega", "Zen", "Maple", "Echo", "Ridge", "Pixel"],
	"service": ["Central", "Harbor", "Meridian", "Sun", "First", "Pacific", "Cedar", "Northern", "Crescent", "Summit", "Evergreen", "Riverside", "Kaiyo", "Halcyon", "Beacon", "Unity", "Willow", "Granite", "Aoi", "Tidewater"],
	"civic": ["Eastern", "Dawn", "Hope", "Peace", "Harmony", "Lantern", "Cherry", "Stone", "Cloud", "Mountain", "Quiet", "Crane", "Pine", "Moon", "Autumn", "Bamboo", "River", "Silent", "Bell", "Jade"],
	"industry": ["Iron", "Steel", "Kowloon", "Rivet", "Anvil", "Gantry", "Bolt", "Forge", "Coal", "Tide", "Ridge", "Mill", "Delta", "Cinder", "Hammer", "Pylon", "Slag", "Dock", "Rail", "Zinc"],
	"home": [],
}
const NOUNS := {
	"restaurant": ["Kitchen", "Table", "Diner", "Grill", "Bistro", "House", "Dining"], "noodle_stall": ["Noodles", "Ramen", "Udon", "Soba", "Noodle Bar", "Bowl"],
	"cafe": ["Coffee", "Cafe", "Roasters", "Espresso", "Tea Room", "Beans"], "bar": ["Bar", "Tap", "Lounge", "Taproom", "Pub", "Cellar"], "shady_bar": ["Den", "Back Room", "Pit", "Hole", "Joint", "Cellar"],
	"nightclub": ["Club", "Loft", "Floor", "Pulse", "Room", "Lights"], "karaoke": ["Karaoke", "Sing", "Booths", "Echo", "Mic"], "bakery": ["Bakery", "Bread", "Crumb", "Loaf", "Patisserie", "Oven"],
	"convenience": ["Mart", "Corner", "Pantry", "Stop", "Basket", "Express"], "grocery": ["Grocer", "Market", "Foods", "Provisions", "Greens", "Pantry"], "liquor_store": ["Spirits", "Bottles", "Cellar", "Wine & Sake", "Liquors"],
	"clothing": ["Threads", "Wear", "Fashion", "Tailors", "Outfitters", "Style"], "electronics": ["Electronics", "Circuits", "Gadgets", "Parts", "Screens", "Wire"], "office_supply": ["Stationers", "Supply", "Office", "Paper", "Desk Co"],
	"bookshop": ["Books", "Pages", "Reads", "Bookshop", "Library", "Folio"], "martial_shop": ["Budo", "Dojo Supply", "Gear", "Blades & Belts", "Pro Shop"], "pawn_shop": ["Pawn", "Loans", "Exchange", "Wares", "Trading"],
	"gun_dealer": ["Arms", "Parts", "Ordnance", "Tools", "Counter"], "hardware": ["Hardware", "Tools", "Builders", "Fixings", "Supply"], "pharmacy": ["Pharmacy", "Chemists", "Remedies", "Apothecary", "Drugs"],
	"car_dealer": ["Motors", "Autos", "Cars", "Wheels", "Drive"], "auto_garage": ["Garage", "Auto", "Mechanics", "Repairs", "Service"], "clinic": ["Clinic", "Medical", "Doctors", "Health", "Practice"],
	"implant_shop": ["Implants", "Augments", "Cybernetics", "Chromeworks", "Neuro"], "implant_body": ["Limbworks", "Chrome", "Augments", "Frames", "Prosthetics"], "cyberdoc": ["Cyberdoc", "Augment Clinic", "Chrome Doc", "Implant Office", "Surgery"],
	"bank": ["Bank", "Savings", "Trust", "Credit", "Finance"], "police": ["Precinct", "Police", "Station", "Constabulary"], "gov_office": ["Office", "Registry", "Bureau", "Civic Hall", "Records"],
	"labor_center": ["Labor Center", "Job Hall", "Work Hall", "Hiring Center", "Labor Exchange"], "post_depot": ["Post", "Courier Depot", "Parcel Depot", "Mail", "Freight Desk"],
	"hotel": ["Hotel", "Inn", "Suites", "Lodge", "Capsule Hotel"], "gym": ["Gym", "Fitness", "Iron", "Training", "Athletics"], "dojo": ["Dojo", "Budokan", "Academy", "School", "Hall"],
	"salon": ["Salon", "Cuts", "Hair", "Beauty", "Studio"], "laundromat": ["Laundromat", "Wash", "Suds", "Laundry", "Clean"], "arcade": ["Arcade", "Pachinko", "Games", "Play", "Parlour"],
	"church": ["Church", "Chapel", "Cathedral", "Parish"], "shrine": ["Shrine", "Jinja", "Temple", "Sanctuary"], "warehouse": ["Warehouse", "Storage", "Depot", "Logistics", "Freight"],
	"workshop": ["Works", "Workshop", "Fabrication", "Makers", "Industries"], "machine_shop": ["Machining", "Tooling", "Precision", "Lathe Works", "Metalworks"], "scrap_yard": ["Scrap", "Recycling", "Salvage", "Breakers", "Yard"],
}
const FAMILIES := ["Tanaka", "Sato", "Suzuki", "Watanabe", "Ito", "Yamamoto", "Nakamura", "Kobayashi", "Kato", "Yoshida", "Yamada", "Sasaki", "Matsumoto", "Inoue", "Kimura", "Hayashi", "Shimizu", "Mori", "Ikeda", "Hashimoto",
	"Volkov", "Petrov", "Sokolov", "Orlov", "Morozov", "Lebedev", "Kuznetsov", "Fedorov", "Popov", "Novak", "Reyes", "Okafor", "Haddad", "Lindqvist", "Moreau", "Cho", "Lin", "Park", "Nguyen", "Silva"]
const TOWER_WORDS := ["Meridian", "Halcyon", "Aegis", "Veyra", "Corvane", "Brightwater", "Kaiyo", "Orlov", "Zenith", "Vanguard", "Crescent", "Apex", "Sumida", "Haneda", "Northgate", "Sunrise", "Pacific", "Atlas", "Summit", "Aurora", "Cobalt", "Lotus", "Harbor", "Skyline", "Regency"]
const TOWER_KINDS := ["Tower", "Plaza", "Centre", "Heights", "Building", "Court", "Place", "House"]

static func cat_of(type: String) -> String:
	match type:
		"restaurant", "noodle_stall", "cafe", "bar", "shady_bar", "nightclub", "bakery", "karaoke": return "food"
		"convenience", "liquor_store", "clothing", "electronics", "office_supply", "martial_shop", "pawn_shop", "gun_dealer", "hardware", "pharmacy", "bookshop", "car_dealer", "grocery": return "retail"
		"auto_garage", "warehouse", "workshop", "machine_shop", "scrap_yard": return "industry"
		"labor_center", "church", "shrine": return "civic"
		"house": return "home"
		_: return "service"

static func sym_of(type: String) -> Array:
	return TYPE_SYM.get(type, OTHER_SYM.get(type, ["house", Color(0.8, 0.8, 0.8), type]))

## the distinct pictograms on the local map's key: [[glyph, colour, text]] in a fixed order
static func legend() -> Array:
	var seen := {}
	var out: Array = []
	for t in ["restaurant", "noodle_stall", "cafe", "bakery", "bar", "shady_bar", "nightclub", "convenience", "liquor_store", "clothing", "electronics", "office_supply", "martial_shop", "pawn_shop", "gun_dealer", "hardware",
			"pharmacy", "car_dealer", "clinic", "implant_shop", "implant_body", "cyberdoc", "police", "labor_center", "post_depot", "hotel", "gym", "salon", "laundromat", "arcade", "church", "shrine", "workshop"]:
		var e: Array = TYPE_SYM[t]
		if not seen.has(e[2]):
			seen[e[2]] = true
			out.append(e)
	out.append(OTHER_SYM["house"])
	out.append(OTHER_SYM["tower"])
	out.append(OTHER_SYM["terminal"])
	return out

static func _pick_name(rng: RandomNumberGenerator, type: String, curated: String, used: Dictionary) -> String:
	if curated != "" and not used.has(curated):
		return curated
	var cat: String = cat_of(type)
	var firsts: Array = FIRST.get(cat, FIRST["service"])
	var nouns: Array = NOUNS.get(type, ["Shop"])
	for _t in 80:
		var n: String = "%s %s" % [firsts[rng.randi() % firsts.size()], nouns[rng.randi() % nouns.size()]]
		if rng.randf() < 0.2:
			n = "%s's %s" % [FAMILIES[rng.randi() % FAMILIES.size()], nouns[rng.randi() % nouns.size()]]
		if not used.has(n):
			return n
	var k := 2
	var base: String = "%s %s" % [firsts[rng.randi() % firsts.size()], nouns[rng.randi() % nouns.size()]]
	while used.has("%s %d" % [base, k]):
		k += 1
	return "%s %d" % [base, k]

static func _house_name(rng: RandomNumberGenerator, used: Dictionary) -> String:
	for _t in 60:
		var n: String = "%s %d" % [FAMILIES[rng.randi() % FAMILIES.size()], 1 + rng.randi() % 99]
		if not used.has(n):
			return n
	var k := 100
	while used.has("House %d" % k):
		k += 1
	return "House %d" % k

static func _tower_name(rng: RandomNumberGenerator, used: Dictionary) -> String:
	for _t in 80:
		var n: String = "%s %s" % [TOWER_WORDS[rng.randi() % TOWER_WORDS.size()], TOWER_KINDS[rng.randi() % TOWER_KINDS.size()]]
		if not used.has(n):
			return n
	var k := 2
	while used.has("Tower %d" % k):
		k += 1
	return "Tower %d" % k

## the street cell outside a door and the way the door faces, from the building's rectangle
static func outside(x0: int, y0: int, x1: int, y1: int, door: Vector2i) -> Dictionary:
	if door.y == y0:
		return {"cell": Vector2i(door.x, door.y - 1), "side": 0}
	if door.y == y1:
		return {"cell": Vector2i(door.x, door.y + 1), "side": 1}
	if door.x == x0:
		return {"cell": Vector2i(door.x - 1, door.y), "side": 2}
	return {"cell": Vector2i(door.x + 1, door.y), "side": 3}

static func _sign(kind: String, type: String, name: String, rect: Array, door: Vector2i, size: int) -> Dictionary:
	var o: Dictionary = outside(rect[0], rect[1], rect[2], rect[3], door)
	var oc: Vector2i = o["cell"]
	var sy: Array = sym_of(type if kind == "biz" else kind)
	var h: int = absi(hash(name))
	var design: int = h % 12
	return {"kind": kind, "type": type, "name": name, "cell": oc.y * size + oc.x, "side": int(o["side"]), "shape": SHAPES[design % 4], "pal": (design / 4) % 3, "glyph": sy[0], "col": sy[1], "cat": cat_of(type),
		"flip": (h / 12) % 2 == 1, "door": door.y * size + door.x, "mid": ((rect[1] + rect[3]) / 2) * size + (rect[0] + rect[2]) / 2}

## give every building a unique name and a sign.  Businesses (and the venues they were built from) keep their curated name when it is free; houses are named for a family and a number,
## towers for a company and a kind.  Deterministic in the city's seed, so a loaded game shows the same names.
static func make(c, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	var used := {}
	var out: Array = []
	for b in c.businesses:
		rng.seed = hash([seed_v, int(b["x0"]), int(b["y0"]), "name"])
		var nm: String = _pick_name(rng, String(b["type"]), String(b.get("name", "")), used)
		used[nm] = true
		b["name"] = nm
		for v in c.venues:                                                   # (the venue this business was drawn from)
			if int(v["x0"]) == int(b["x0"]) and int(v["y0"]) == int(b["y0"]):
				v["name"] = nm
		out.append(_sign("biz", String(b["type"]), nm, [b["x0"], b["y0"], b["x1"], b["y1"]], b["door"], c.size))
	for v in c.venues:                                                       # venues stamped directly (no business record)
		var found := false
		for s in out:
			if s["name"] == v["name"]:
				found = true
				break
		if found:
			continue
		rng.seed = hash([seed_v, int(v["x0"]), int(v["y0"]), "vname"])
		var vt: String = {"temple": "shrine", "implant": "implant_shop"}.get(String(v["kind"]), String(v["kind"]))
		var vn: String = _pick_name(rng, vt, String(v.get("name", "")), used)
		used[vn] = true
		v["name"] = vn
		out.append(_sign("biz", vt, vn, [v["x0"], v["y0"], v["x1"], v["y1"]], v["door"], c.size))
	for b in c.bldgs:
		var k: String = String(b["kind"])
		rng.seed = hash([seed_v, int(b["x0"]), int(b["y0"]), "bname"])
		var nm2: String
		if k == "core":
			nm2 = _tower_name(rng, used)
			used[nm2] = true
		elif bool(b.get("filled", false)):
			nm2 = _house_name(rng, used)
			used[nm2] = true
		else:
			nm2 = "For Rent"
		b["name"] = nm2
		out.append(_sign("tower" if k == "core" else "house", "tower" if k == "core" else "house", nm2, [b["x0"], b["y0"], b["x1"], b["y1"]], b["door"], c.size))
	return out

# ---------------------------------------------------------------- the sign, drawn
## how wide a sign is in tiles (for a name at the given font size)
static func sign_width(font: Font, name: String, fsize: int, tile: float, kind: String) -> float:
	var w: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var extra: float = fsize * 1.7 + 10.0
	return minf(w + extra, tile * (7.0 if kind == "biz" else (5.0 if kind == "tower" else 4.2)))

## draw one sign.  `cell_pos` is the top-left corner of the street cell outside the door; the board hugs the wall beside the door (flip decides which side), turned to the wall.
static func draw_sign(ci: CanvasItem, font: Font, s: Dictionary, cell_pos: Vector2, tile: float, vis: bool) -> void:
	var kind: String = String(s["kind"])
	var fsize: int = int(clampf(tile * 0.28, 12.0, 22.0)) if kind == "biz" else int(clampf(tile * 0.22, 10.0, 16.0))
	var bw: float = sign_width(font, String(s["name"]), fsize, tile, kind)
	var bh: float = tile * (0.68 if kind == "biz" else 0.5)
	var pals: Array = PALS[String(s["cat"])]
	var pal: Array = pals[int(s["pal"])]
	var bg: Color = pal[0]
	var fg: Color = pal[1]
	var edge: Color = pal[2]
	if kind == "tower":
		bg = Color(0.1, 0.12, 0.18)
		fg = Color(0.85, 0.92, 1.0)
		edge = COL_TOWER
	var dim: float = 1.0 if vis else 0.55
	var side: int = int(s["side"])
	var sgn: float = -1.0 if bool(s["flip"]) else 1.0
	# the board's own frame: x along the wall, y out from the wall.  Origin at the middle of the board's edge against the wall.
	var centre: Vector2 = cell_pos + Vector2(tile, tile) * 0.5
	var wall_dir: Vector2 = Vector2(0, 1) if side == 0 else (Vector2(0, -1) if side == 1 else (Vector2(1, 0) if side == 2 else Vector2(-1, 0)))     # from the street cell towards the wall
	var along: Vector2 = Vector2(1, 0) if side < 2 else Vector2(0, 1)
	var origin: Vector2 = centre + wall_dir * (tile * 0.5 - 1.0) + along * sgn * (tile * 0.5 + bw * 0.5 + 2.0)
	var rot: float = 0.0
	match side:
		0: rot = 0.0
		1: rot = PI
		2: rot = -PI * 0.5
		_: rot = PI * 0.5
	# 0 N: the board sits above the street cell (wall is below it): its far side from the wall is up... keep text upright for N and S, turned for W and E
	var upright: bool = side < 2
	ci.draw_set_transform(origin, 0.0 if upright else (-PI * 0.5 if side == 2 else PI * 0.5), Vector2.ONE)
	var r := Rect2(-bw * 0.5, -bh if side != 1 else 0.0, bw, bh)
	if not upright:
		r = Rect2(-bw * 0.5, -bh, bw, bh)
	var shape: String = String(s["shape"])
	match shape:
		"board":
			ci.draw_rect(r.grow(1.5), edge * Color(1, 1, 1, dim))
			ci.draw_rect(r, bg * Color(1, 1, 1, 0.96 * dim))
		"neon":
			ci.draw_rect(r.grow(3.0), Color(edge.r, edge.g, edge.b, 0.16 * dim))
			ci.draw_rect(r, Color(0.03, 0.03, 0.05, 0.96 * dim))
			ci.draw_rect(r, Color(edge.r, edge.g, edge.b, dim), false, 2.0)
			fg = edge.lerp(Color.WHITE, 0.35)
		"banner":
			var nt: float = bh * 0.3
			var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x - nt, r.position.y + bh * 0.5), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y), Vector2(r.position.x + nt, r.position.y + bh * 0.5)])
			ci.draw_colored_polygon(pts, edge.lerp(bg, 0.25) * Color(1, 1, 1, 0.97 * dim))
			fg = bg.lerp(Color.BLACK, 0.4) if bg.get_luminance() > 0.4 else Color(1, 1, 1)
			if edge.get_luminance() > 0.55:
				fg = Color(0.1, 0.07, 0.05)
		_:
			ci.draw_rect(r.grow(1.0), Color(0.15, 0.13, 0.1, dim))
			ci.draw_rect(r, Color(0.78, 0.7, 0.5, 0.97 * dim).lerp(bg, 0.15))
			fg = Color(0.15, 0.1, 0.05)
			for sx in [r.position.x + 3.0, r.end.x - 3.0]:
				ci.draw_circle(Vector2(sx, r.position.y + 3.0), 1.1, Color(0.3, 0.25, 0.15))
				ci.draw_circle(Vector2(sx, r.end.y - 3.0), 1.1, Color(0.3, 0.25, 0.15))
	var gr: float = bh * 0.34
	draw_glyph(ci, String(s["glyph"]), Vector2(r.position.x + bh * 0.5, r.position.y + bh * 0.5), gr, (s["col"] as Color) * Color(1, 1, 1, dim) if shape != "banner" and shape != "plaque" else fg)
	var tx: float = r.position.x + bh * 0.95
	var avail: float = r.end.x - tx - 4.0
	var txt: String = String(s["name"])
	var fs: int = fsize
	while fs > 7 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 1
	while txt.length() > 2 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		txt = txt.substr(0, txt.length() - 1)
	ci.draw_string(font, Vector2(tx, r.position.y + bh * 0.5 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg * Color(1, 1, 1, dim))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- pictograms
static func _ln(ci: CanvasItem, c: Vector2, r: float, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(c + a * r, c + b * r, col, w)

static func _poly(ci: CanvasItem, c: Vector2, r: float, pts: Array, col: Color) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(c + (q as Vector2) * r)
	ci.draw_colored_polygon(p, col)

static func _rc(ci: CanvasItem, c: Vector2, r: float, x: float, y: float, w: float, h: float, col: Color, fill: bool = true, lw: float = 1.5) -> void:
	ci.draw_rect(Rect2(c + Vector2(x, y) * r, Vector2(w, h) * r), col, fill, lw)

## one pictogram in a box of half-size r round c
static func draw_glyph(ci: CanvasItem, glyph: String, c: Vector2, r: float, col: Color) -> void:
	var w: float = maxf(1.4, r * 0.16)
	match glyph:
		"fork":
			for x in [-0.5, 0.0, 0.5]:
				_ln(ci, c, r, Vector2(x, -0.9), Vector2(x, -0.1), col, w)
			_ln(ci, c, r, Vector2(-0.5, -0.1), Vector2(0.5, -0.1), col, w)
			_ln(ci, c, r, Vector2(0, -0.1), Vector2(0, 0.9), col, w * 1.2)
		"bowl":
			ci.draw_arc(c + Vector2(0, -0.1) * r, r * 0.8, 0.0, PI, 16, col, w * 1.3)
			_ln(ci, c, r, Vector2(-0.85, -0.1), Vector2(0.85, -0.1), col, w)
			_ln(ci, c, r, Vector2(-0.1, -0.2), Vector2(0.5, -0.95), col, w * 0.8)
			_ln(ci, c, r, Vector2(0.15, -0.2), Vector2(0.8, -0.85), col, w * 0.8)
		"cup":
			_poly(ci, c, r, [Vector2(-0.6, -0.3), Vector2(0.4, -0.3), Vector2(0.3, 0.7), Vector2(-0.5, 0.7)], col)
			ci.draw_arc(c + Vector2(0.45, 0.1) * r, r * 0.3, -PI * 0.5, PI * 0.5, 8, col, w)
			_ln(ci, c, r, Vector2(-0.3, -0.5), Vector2(-0.2, -0.9), col, w * 0.7)
			_ln(ci, c, r, Vector2(0.1, -0.5), Vector2(0.2, -0.9), col, w * 0.7)
		"glass":
			_poly(ci, c, r, [Vector2(-0.85, -0.8), Vector2(0.85, -0.8), Vector2(0, 0.1)], col)
			_ln(ci, c, r, Vector2(0, 0.1), Vector2(0, 0.85), col, w)
			_ln(ci, c, r, Vector2(-0.45, 0.85), Vector2(0.45, 0.85), col, w)
		"note":
			ci.draw_circle(c + Vector2(-0.35, 0.5) * r, r * 0.34, col)
			ci.draw_circle(c + Vector2(0.45, 0.2) * r, r * 0.3, col)
			_ln(ci, c, r, Vector2(-0.05, 0.5), Vector2(-0.05, -0.85), col, w)
			_ln(ci, c, r, Vector2(0.72, 0.2), Vector2(0.72, -0.85), col, w)
			_ln(ci, c, r, Vector2(-0.05, -0.85), Vector2(0.72, -0.85), col, w * 1.4)
		"bread":
			var pts: Array = []
			for k in 14:
				var a: float = TAU * float(k) / 14.0
				pts.append(Vector2(cos(a) * 0.9, sin(a) * 0.55))
			_poly(ci, c, r, pts, col)
			for x in [-0.4, 0.0, 0.4]:
				_ln(ci, c, r, Vector2(x - 0.1, -0.35), Vector2(x + 0.1, 0.35), Color(0, 0, 0, 0.45), w * 0.8)
		"cart":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.95, -0.7) * r, c + Vector2(-0.6, -0.7) * r, c + Vector2(-0.3, 0.35) * r, c + Vector2(0.75, 0.35) * r, c + Vector2(0.9, -0.4) * r, c + Vector2(-0.52, -0.4) * r]), col, w)
			ci.draw_circle(c + Vector2(-0.1, 0.75) * r, r * 0.18, col)
			ci.draw_circle(c + Vector2(0.6, 0.75) * r, r * 0.18, col)
		"bottle":
			_rc(ci, c, r, -0.18, -0.95, 0.36, 0.5, col)
			_rc(ci, c, r, -0.42, -0.5, 0.84, 1.4, col)
			_rc(ci, c, r, -0.42, 0.0, 0.84, 0.3, Color(0, 0, 0, 0.35))
		"hanger":
			ci.draw_arc(c + Vector2(0, -0.6) * r, r * 0.22, PI * 0.9, PI * 2.4, 8, col, w)
			_ln(ci, c, r, Vector2(0, -0.38), Vector2(0, -0.15), col, w)
			_ln(ci, c, r, Vector2(0, -0.15), Vector2(-0.95, 0.55), col, w)
			_ln(ci, c, r, Vector2(0, -0.15), Vector2(0.95, 0.55), col, w)
			_ln(ci, c, r, Vector2(-0.95, 0.55), Vector2(0.95, 0.55), col, w)
		"bolt":
			_poly(ci, c, r, [Vector2(0.25, -0.95), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.25, 0.95), Vector2(0.55, -0.2), Vector2(0.05, -0.2)], col)
		"book":
			_rc(ci, c, r, -0.85, -0.6, 1.7, 1.2, col, false, w)
			_ln(ci, c, r, Vector2(0, -0.6), Vector2(0, 0.6), col, w)
			for y in [-0.25, 0.1, 0.4]:
				_ln(ci, c, r, Vector2(-0.65, y), Vector2(-0.2, y), col, w * 0.6)
				_ln(ci, c, r, Vector2(0.2, y), Vector2(0.65, y), col, w * 0.6)
		"fist":
			_rc(ci, c, r, -0.65, -0.15, 1.3, 0.95, col)
			for k in 4:
				ci.draw_circle(c + Vector2(-0.48 + 0.32 * k, -0.25) * r, r * 0.19, col)
			_rc(ci, c, r, -0.45, 0.8, 0.9, 0.2, col)
		"coin":
			ci.draw_arc(c, r * 0.88, 0.0, TAU, 20, col, w * 1.3)
			var f: Font = ThemeDB.fallback_font
			ci.draw_string(f, c + Vector2(-r * 0.32, r * 0.42), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.35), col)
		"gun":
			_rc(ci, c, r, -0.95, -0.5, 1.7, 0.45, col)
			_rc(ci, c, r, 0.0, -0.1, 0.4, 0.95, col)
			_rc(ci, c, r, 0.45, -0.5, 0.25, 0.2, Color(0, 0, 0, 0.35))
		"wrench":
			_ln(ci, c, r, Vector2(-0.7, 0.75), Vector2(0.3, -0.3), col, w * 1.9)
			ci.draw_circle(c + Vector2(0.45, -0.45) * r, r * 0.38, col)
			_poly(ci, c, r, [Vector2(0.45, -0.45), Vector2(0.95, -0.55), Vector2(0.95, -0.95), Vector2(0.55, -0.95)], Color(0, 0, 0, 0.55))
		"cross":
			_rc(ci, c, r, -0.27, -0.9, 0.54, 1.8, col)
			_rc(ci, c, r, -0.9, -0.27, 1.8, 0.54, col)
		"chip":
			_rc(ci, c, r, -0.5, -0.5, 1.0, 1.0, col, false, w * 1.2)
			_rc(ci, c, r, -0.22, -0.22, 0.44, 0.44, col)
			for k in [-0.3, 0.0, 0.3]:
				_ln(ci, c, r, Vector2(k, -0.5), Vector2(k, -0.9), col, w * 0.8)
				_ln(ci, c, r, Vector2(k, 0.5), Vector2(k, 0.9), col, w * 0.8)
				_ln(ci, c, r, Vector2(-0.5, k), Vector2(-0.9, k), col, w * 0.8)
				_ln(ci, c, r, Vector2(0.5, k), Vector2(0.9, k), col, w * 0.8)
		"car":
			_rc(ci, c, r, -0.95, -0.05, 1.9, 0.55, col)
			_poly(ci, c, r, [Vector2(-0.55, -0.05), Vector2(-0.3, -0.55), Vector2(0.4, -0.55), Vector2(0.7, -0.05)], col)
			ci.draw_circle(c + Vector2(-0.5, 0.55) * r, r * 0.25, Color(0.05, 0.05, 0.08))
			ci.draw_circle(c + Vector2(0.5, 0.55) * r, r * 0.25, Color(0.05, 0.05, 0.08))
			ci.draw_arc(c + Vector2(-0.5, 0.55) * r, r * 0.25, 0.0, TAU, 10, col, w * 0.7)
			ci.draw_arc(c + Vector2(0.5, 0.55) * r, r * 0.25, 0.0, TAU, 10, col, w * 0.7)
		"crate":
			_rc(ci, c, r, -0.8, -0.8, 1.6, 1.6, col, false, w * 1.2)
			_ln(ci, c, r, Vector2(-0.8, -0.8), Vector2(0.8, 0.8), col, w * 0.8)
			_ln(ci, c, r, Vector2(0.8, -0.8), Vector2(-0.8, 0.8), col, w * 0.8)
		"shield":
			_poly(ci, c, r, [Vector2(-0.75, -0.85), Vector2(0.75, -0.85), Vector2(0.75, 0.05), Vector2(0, 0.95), Vector2(-0.75, 0.05)], col)
			_ln(ci, c, r, Vector2(0, -0.6), Vector2(0, 0.55), Color(0, 0, 0, 0.5), w)
			_ln(ci, c, r, Vector2(-0.45, -0.1), Vector2(0.45, -0.1), Color(0, 0, 0, 0.5), w)
		"people":
			ci.draw_circle(c + Vector2(-0.45, -0.45) * r, r * 0.3, col)
			ci.draw_circle(c + Vector2(0.45, -0.45) * r, r * 0.3, col)
			ci.draw_arc(c + Vector2(-0.45, 0.55) * r, r * 0.55, PI, TAU, 10, col, w * 1.6)
			ci.draw_arc(c + Vector2(0.45, 0.55) * r, r * 0.55, PI, TAU, 10, col, w * 1.6)
		"bed":
			_rc(ci, c, r, -0.9, 0.0, 1.8, 0.45, col)
			_rc(ci, c, r, -0.9, -0.6, 0.25, 1.2, col)
			ci.draw_circle(c + Vector2(-0.4, -0.15) * r, r * 0.22, col)
			_rc(ci, c, r, 0.0, -0.25, 0.9, 0.25, col)
		"dumbbell":
			_ln(ci, c, r, Vector2(-0.6, 0), Vector2(0.6, 0), col, w * 1.2)
			for x in [-0.8, 0.8]:
				_rc(ci, c, r, x - 0.14, -0.55, 0.28, 1.1, col)
			for x in [-0.55, 0.55]:
				_rc(ci, c, r, x - 0.1, -0.38, 0.2, 0.76, col)
		"scissors":
			ci.draw_arc(c + Vector2(-0.4, 0.55) * r, r * 0.28, 0.0, TAU, 10, col, w)
			ci.draw_arc(c + Vector2(0.4, 0.55) * r, r * 0.28, 0.0, TAU, 10, col, w)
			_ln(ci, c, r, Vector2(-0.3, 0.3), Vector2(0.6, -0.9), col, w)
			_ln(ci, c, r, Vector2(0.3, 0.3), Vector2(-0.6, -0.9), col, w)
		"drop":
			_poly(ci, c, r, [Vector2(0, -0.95), Vector2(0.55, 0.05), Vector2(0.55, 0.45), Vector2(0.3, 0.8), Vector2(-0.3, 0.8), Vector2(-0.55, 0.45), Vector2(-0.55, 0.05)], col)
		"pad":
			_rc(ci, c, r, -0.9, -0.5, 1.8, 1.0, col)
			_rc(ci, c, r, -0.6, -0.1, 0.5, 0.18, Color(0, 0, 0, 0.55))
			_rc(ci, c, r, -0.44, -0.26, 0.18, 0.5, Color(0, 0, 0, 0.55))
			ci.draw_circle(c + Vector2(0.4, -0.1) * r, r * 0.12, Color(0, 0, 0, 0.55))
			ci.draw_circle(c + Vector2(0.65, 0.1) * r, r * 0.12, Color(0, 0, 0, 0.55))
		"church":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.7, 0.85) * r, c + Vector2(-0.7, -0.05) * r, c + Vector2(0, -0.55) * r, c + Vector2(0.7, -0.05) * r, c + Vector2(0.7, 0.85) * r, c + Vector2(-0.7, 0.85) * r]), col, w)
			_ln(ci, c, r, Vector2(0, -0.55), Vector2(0, -1.0), col, w)
			_ln(ci, c, r, Vector2(-0.2, -0.82), Vector2(0.2, -0.82), col, w)
			_rc(ci, c, r, -0.18, 0.2, 0.36, 0.65, col)
		"torii":
			_ln(ci, c, r, Vector2(-0.58, -0.1), Vector2(-0.58, 0.95), col, w * 1.3)
			_ln(ci, c, r, Vector2(0.58, -0.1), Vector2(0.58, 0.95), col, w * 1.3)
			_ln(ci, c, r, Vector2(-0.95, -0.55), Vector2(0.95, -0.55), col, w * 1.7)
			_ln(ci, c, r, Vector2(-0.72, -0.15), Vector2(0.72, -0.15), col, w)
		"house":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.75, 0.8) * r, c + Vector2(-0.75, -0.1) * r, c + Vector2(0, -0.85) * r, c + Vector2(0.75, -0.1) * r, c + Vector2(0.75, 0.8) * r, c + Vector2(-0.75, 0.8) * r]), col, w)
			_rc(ci, c, r, -0.18, 0.25, 0.36, 0.55, col)
		"tower":
			_rc(ci, c, r, -0.45, -0.95, 0.9, 1.9, col, false, w * 1.2)
			for y in [-0.65, -0.2, 0.25]:
				_rc(ci, c, r, -0.2, y, 0.4, 0.18, col)
		"terminal":
			_rc(ci, c, r, -0.85, -0.8, 1.7, 1.2, col, false, w * 1.3)
			_ln(ci, c, r, Vector2(-0.5, -0.4), Vector2(-0.15, -0.2), col, w)
			_ln(ci, c, r, Vector2(-0.15, -0.2), Vector2(-0.5, 0.0), col, w)
			_ln(ci, c, r, Vector2(0.0, 0.0), Vector2(0.4, 0.0), col, w)
			_ln(ci, c, r, Vector2(0, 0.4), Vector2(0, 0.7), col, w)
			_ln(ci, c, r, Vector2(-0.5, 0.8), Vector2(0.5, 0.8), col, w * 1.3)
		"gear":
			for k in 8:
				var a: float = TAU * float(k) / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.55, c + Vector2(cos(a), sin(a)) * r * 0.95, col, w * 1.9)
			ci.draw_arc(c, r * 0.55, 0.0, TAU, 16, col, w * 1.4)
			ci.draw_circle(c, r * 0.2, col)
		_:
			ci.draw_circle(c, r * 0.6, col)
