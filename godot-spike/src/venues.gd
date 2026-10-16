extends RefCounted
## The buildings you can walk into and do business in: restaurants, grocery stores, implant shops, clinics, churches and shrines.
## Each is stamped into a lot by `stamp`, laid out in (u, v) coordinates: u counts from the door wall inwards, v runs along the wall left to right.
## `stamp` returns the venue record that economy.gd turns into a keeper with a menu.
const CG = preload("res://src/citygen.gd")

const KINDS := ["restaurant", "grocery", "implant", "clinic", "church", "temple"]
const RESTAURANTS := [
	{"id": "ramen", "name": "Ramen stall", "floor": "floor_wood", "greet": "\"Irasshai!  Sit anywhere, the broth is hot.\"",
		"menu": ["cup_ramen", "gyoza", "onigiri", "miso", "sencha", "beer"]},
	{"id": "sushi", "name": "Sushi bar", "floor": "floor_hinoki", "greet": "\"Welcome.  The fish came in this morning.\"",
		"menu": ["sashimi", "onigiri", "unagi", "miso", "sencha", "sake"]},
	{"id": "izakaya", "name": "Izakaya", "floor": "floor_tatami", "greet": "\"Evening!  Drink first, or food?\"",
		"menu": ["yakitori", "takoyaki", "okonomiyaki", "gyoza", "beer", "sake"]},
	{"id": "pelmeni", "name": "Pelmeni house", "floor": "floor_wood", "greet": "\"Sit, sit.  Pelmeni like my grandmother made.\"",
		"menu": ["pelmeni", "borscht", "blini", "piroshki", "kotleta", "kvass", "kompot", "vodka"]},
	{"id": "diner", "name": "Diner", "floor": "floor_checker", "greet": "\"Coffee's fresh.  What'll it be?\"",
		"menu": ["hamburger", "fries", "taco", "crepe", "cola", "kan_coffee", "beer"]},
	{"id": "bistro", "name": "Caviar bistro", "floor": "floor_carpet", "greet": "\"Good evening.  May I suggest the blini?\"",
		"menu": ["caviar_blini", "solyanka", "unagi", "sashimi", "sake", "vodka", "oolong"]},
]
const NAMES := {
	"restaurant": ["Kuma-ya", "Babushka", "Hokkaido Table", "Red Lantern", "Taiga Kitchen", "Neon Noodle", "Sakhalin Grill", "Blue Crane", "Samovar", "Tsubame"],
	"grocery": ["Daily Mart", "Harbor Provisions", "Kolkhoz Market", "Sunrise Grocer", "Tanuki Foods", "Northern Pantry"],
	"implant": ["Back Alley Cyber", "Mizuki Implants", "Chrome Hand", "Zero Latency", "Kuroda Surgical", "Wire & Bone"],
	"clinic": ["Eastgate Clinic", "Sakhalin Medical", "Dr. Aoki's Practice", "Pine Street Surgery", "Seaview Clinic"],
	"church": ["Church of St. Nicholas", "Holy Intercession Church", "Church of the Savior", "St. Sergius Chapel"],
	"temple": ["Inari Shrine", "Hachiman Shrine", "Suwa Shrine", "Sakura Shrine"],
}

## which kinds go where, in the order they are placed: one of each first, then extras (shuffled with the map's own generator, so a seed gives one map)
static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> Array:
	var a: Array = arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a

static func city_plan(rng: RandomNumberGenerator) -> Array:
	return _shuffle(KINDS, rng) + _shuffle(["restaurant", "grocery", "restaurant", "implant", "clinic", "grocery"], rng)

static func town_plan(rng: RandomNumberGenerator) -> Array:
	return _shuffle(["restaurant", "grocery", "clinic", "temple", "church"], rng)

class Lay:
	## u/v to world cells for a door on the north (side 0) or south (side 1) wall
	var c
	var bx0: int
	var by0: int
	var bx1: int
	var by1: int
	var side: int
	var wi: int
	var di: int
	var floor_id: int = CG.FLOOR
	func _init(cg, x0: int, y0: int, x1: int, y1: int, sd: int) -> void:
		c = cg
		bx0 = x0; by0 = y0; bx1 = x1; by1 = y1; side = sd
		wi = x1 - x0 - 1
		di = y1 - y0 - 1
	func cell(u: int, v: int) -> Vector2i:
		var y: int = (by1 - 1 - u) if side == 1 else (by0 + 1 + u)
		return Vector2i(bx0 + 1 + v, y)
	func idx(u: int, v: int) -> int:
		var p := cell(u, v)
		return p.y * c.size + p.x
	func floor_all(f: int) -> void:
		floor_id = f
		for u in di:
			for v in wi:
				c.tiles[idx(u, v)] = f
				c.under[idx(u, v)] = f
	func put(u: int, v: int, name: String) -> void:
		if u < 0 or v < 0 or u >= di or v >= wi:
			return
		var i: int = idx(u, v)
		c.tiles[i] = CG.TID[name]
		c.under[i] = floor_id
	func row(u: int, v0: int, v1: int, name: String, skip: Array = []) -> void:
		for v in range(v0, v1 + 1):
			if not (v in skip):
				put(u, v, name)

## stamp a venue into the lot.  side: 0 door on the north wall, 1 on the south wall.  tier: 0 poor, 1 mid.
static func stamp(c, kind: String, bx0: int, by0: int, bx1: int, by1: int, side: int, tier: int) -> Dictionary:
	if c.under.size() != c.size * c.size:
		c.under = PackedByteArray()
		c.under.resize(c.size * c.size)
	var rng: RandomNumberGenerator = c.rng
	# shell: walls, a door in the middle of the street wall
	for y in range(by0, by1 + 1):
		for x in range(bx0, bx1 + 1):
			c.tiles[y * c.size + x] = CG.FLOOR
	for x in range(bx0, bx1 + 1):
		c.tiles[by0 * c.size + x] = CG.WALL
		c.tiles[by1 * c.size + x] = CG.WALL
	for y in range(by0, by1 + 1):
		c.tiles[y * c.size + bx0] = CG.WALL
		c.tiles[y * c.size + bx1] = CG.WALL
	c.buildings += 1
	var L := Lay.new(c, bx0, by0, bx1, by1, side)
	var dx: int = bx0 + 1 + L.wi / 2
	var dy: int = by1 if side == 1 else by0
	c.tiles[dy * c.size + dx] = CG.DOOR
	var mid: int = L.wi / 2
	var wi: int = L.wi
	var style := ""
	var sname: String = NAMES[kind][rng.randi() % NAMES[kind].size()]
	var keeper := Vector2i.ZERO
	match kind:
		"restaurant":
			var st: Dictionary = RESTAURANTS[(rng.randi() % (RESTAURANTS.size() - (0 if tier >= 1 else 1)))]
			style = st["id"]
			L.floor_all(CG.TID[st["floor"]])
			# dining at the door end: tables with stools, an aisle, then the counter, the cook, and the kitchen along the back wall
			var v := 1
			while v < wi - 1:
				L.put(2, v, "dining_table" if tier >= 1 or style == "bistro" else "table_plastic")
				L.put(1, v, "stool"); L.put(3, v, "stool")
				v += 3
			if style == "ramen" or style == "sushi":
				L.row(5, 0, wi - 1, "noodle_counter" if style == "ramen" else "sushi_case", [mid])
				for k in range(1, wi - 1, 2):
					L.put(4, k, "bar_stool")
			else:
				L.row(5, 0, wi - 1, "counter", [mid])
			L.put(5, mid, "counter")
			keeper = L.cell(6, mid)
			for k in range(0, wi):
				match (k + (rng.randi() % 2)) % 4:
					0: L.put(7, k, "range")
					1: L.put(7, k, "fridge")
					2: L.put(7, k, "pizza_oven" if style == "diner" else "hot_plate")
					_: L.put(7, k, "range")
			if style == "pelmeni":
				L.put(6, 0, "samovar")
			elif style == "izakaya" or style == "bistro":
				L.row(8, 0, wi - 1, "liquor_shelf")
			L.put(6, wi - 1, "menu_board")
			L.put(0, 0, "fern")
		"grocery":
			L.floor_all(CG.TID["floor_clean"])
			L.put(1, 1, "checkout"); L.put(1, 2, "checkout")
			keeper = L.cell(2, 1)
			L.put(1, wi - 2, "vending")
			for u in [4, 6]:
				L.row(u, 1, wi - 2, "shelf", [mid, mid + 1])
			L.row(8, 0, wi - 1, "freezer_case", [mid])
			L.put(2, wi - 2, "water_cooler")
			for k in range(1, wi - 2, 3):
				L.put(3, k, "produce_bin")
		"implant":
			L.floor_all(CG.TID["floor_steel"])
			L.row(1, 2, wi - 3, "counter", [mid])
			L.put(1, mid, "counter")
			keeper = L.cell(2, mid)
			L.put(2, 0, "neon"); L.put(2, wi - 1, "neon")
			L.put(4, 1, "implant_chair"); L.put(4, 4, "implant_chair"); L.put(4, wi - 2, "autodoc")
			L.put(6, 1, "implant_printer"); L.put(6, 3, "limb_bin"); L.put(6, wi - 2, "limb_bin")
			L.row(8, 0, wi - 1, "med_cabinet", [mid, mid - 1])
			if tier == 0:
				L.floor_id = CG.TID["floor_steel"]
		"clinic":
			L.floor_all(CG.TID["floor_clean"])
			L.row(1, 2, wi - 3, "reception", [mid])
			L.put(1, mid, "reception")
			keeper = L.cell(2, mid)
			L.put(2, 0, "water_cooler")
			for u in [4, 6]:
				L.put(u, 0, "hospital_bed"); L.put(u, 1, "iv_stand")
				L.put(u, wi - 1, "ward_bed"); L.put(u, wi - 2, "iv_stand")
			L.put(4, mid, "exam_couch")
			L.put(7, mid + 2, "scanner")
			L.row(8, 0, wi - 1, "med_cabinet", [mid - 1, mid])
		"church":
			L.floor_all(CG.TID["floor_church"])
			for u in [2, 3, 4]:
				L.row(u, 1, 3, "church_bench")
				L.row(u, wi - 4, wi - 2, "church_bench")
			L.put(1, wi - 2, "baptismal_font")
			L.put(1, 1, "icon_lamp")
			L.put(6, 1, "candle_stand"); L.put(6, wi - 2, "candle_stand")
			L.put(6, mid, "analoy")
			keeper = L.cell(7, mid + 1)
			L.row(8, 1, wi - 2, "iconostasis")
			L.put(8, 0, "worship_cross"); L.put(8, wi - 1, "worship_cross")
			L.put(7, 0, "icon_lamp"); L.put(7, wi - 1, "icon_lamp")
		"temple":
			L.floor_all(CG.TID["floor_hinoki"])
			L.put(1, 1, "chozuya"); L.put(1, wi - 2, "ema_rack")
			L.put(2, 1, "komainu"); L.put(2, wi - 2, "komainu")
			L.put(4, 2, "lantern_stone"); L.put(4, wi - 3, "lantern_stone")
			L.put(6, mid, "offering_table"); L.put(5, mid, "saisen_box")
			keeper = L.cell(5, mid + 2)
			L.put(8, mid, "shrine")
			L.put(7, 1, "shimenawa"); L.put(7, wi - 2, "shimenawa")
			L.put(8, 1, "bonsai"); L.put(8, wi - 2, "bonsai")
			L.put(3, mid, "charm_counter") if false else null
			# the torii stands on the pavement in front of the door
			var ty: int = dy + (1 if side == 1 else -1)
			if ty >= 0 and ty < c.size and c.tiles[ty * c.size + dx] != CG.WALL:
				c.under[ty * c.size + dx] = c.tiles[ty * c.size + dx]
				c.tiles[ty * c.size + dx] = CG.TID["torii"]
	# a floor underneath everything that is not furniture
	var v_rec := {"kind": kind, "style": style, "tier": tier, "name": sname, "x0": bx0, "y0": by0, "x1": bx1, "y1": by1,
		"door": Vector2i(dx, dy), "keeper": keeper.y * c.size + keeper.x, "side": side}
	c.venues.append(v_rec)
	return v_rec

static func restaurant_style(style: String) -> Dictionary:
	for s in RESTAURANTS:
		if s["id"] == style:
			return s
	return RESTAURANTS[0]
