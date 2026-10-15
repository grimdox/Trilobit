extends RefCounted
## Spike test 3a: an overworld with fixed anchors and seeded detail.
## The same places always exist (coast, mountains, a big city, a harbor on the coast, an airport, an industrial belt);
## where they sit and what is around them changes with the seed.
const SEA := 0
const BEACH := 1
const PLAIN := 2
const HILL := 3
const MOUNTAIN := 4
const CITY_CORE := 5
const SUBURB := 6
const HARBOR := 7
const AIRPORT := 8
const INDUSTRIAL := 9
const FOREST := 10
const ROAD := 11
const NAMES := ["sea", "beach", "plain", "hill", "mountain", "core", "suburb", "harbor", "airport", "industrial", "forest", "road"]

var w: int
var h: int
var cells: PackedByteArray
var anchors: Dictionary = {}     # name -> {"pos": Vector2i, "radius": int, ...}
var seed_value: int = 0

func generate(seed: int, cfg: Dictionary) -> void:
	seed_value = seed
	w = int(cfg["size"][0])
	h = int(cfg["size"][1])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	cells = PackedByteArray()
	cells.resize(w * h)
	cells.fill(PLAIN)
	anchors.clear()

	# coast: a noisy shoreline on one allowed side
	var cc: Dictionary = cfg["coast"]
	var sides: Array = cc["sides"]
	var side: String = sides[rng.randi() % sides.size()]
	var depth: int = rng.randi_range(int(cc["depth_min"]), int(cc["depth_max"]))
	var n1 := FastNoiseLite.new()
	n1.seed = seed ^ 0x51ED
	n1.frequency = 0.07
	anchors["coast"] = {"side": side, "depth": depth}
	var opp := {"E": "W", "W": "E", "S": "N", "N": "S"}[side] as String
	var mc: Dictionary = cfg["mountains"]
	var mdepth: int = rng.randi_range(int(mc["depth_min"]), int(mc["depth_max"]))
	var n2 := FastNoiseLite.new()
	n2.seed = seed ^ 0xBEEF
	n2.frequency = 0.09
	anchors["mountains"] = {"side": opp, "depth": mdepth}
	for y in h:
		for x in w:
			var d_coast := _edge_dist(side, x, y)
			var d_mtn := _edge_dist(opp, x, y)
			var wob := n1.get_noise_2d(x, y) * 5.0
			var t := PLAIN
			if d_coast + wob < depth * 0.55:
				t = SEA
			elif d_coast + wob < depth * 0.55 + 1.6:
				t = BEACH
			elif d_mtn + n2.get_noise_2d(x, y) * 5.0 < mdepth * 0.5:
				t = MOUNTAIN
			elif d_mtn + n2.get_noise_2d(x, y) * 5.0 < mdepth * 0.5 + 4.0:
				t = HILL
			cells[y * w + x] = t
	# forests as noise blobs on plains and hills
	var nf := FastNoiseLite.new()
	nf.seed = seed ^ 0xF04E
	nf.frequency = 0.1
	for y in h:
		for x in w:
			var t := cells[y * w + x]
			if (t == PLAIN or t == HILL) and nf.get_noise_2d(x, y) > 0.28:
				cells[y * w + x] = FOREST

	# the big city: position varies inside its box, never on water or mountain
	var bc: Dictionary = cfg["big_city"]
	var cpos := Vector2i(-1, -1)
	for _try in 200:
		var px := int(w * rng.randf_range(float(bc["x"][0]), float(bc["x"][1])))
		var py := int(h * rng.randf_range(float(bc["y"][0]), float(bc["y"][1])))
		var t := cells[py * w + px]
		if t != SEA and t != MOUNTAIN and t != BEACH:
			cpos = Vector2i(px, py)
			break
	if cpos.x < 0:
		cpos = Vector2i(w / 2, h / 2)
	var cr: int = rng.randi_range(int(bc["radius_min"]), int(bc["radius_max"]))
	anchors["big_city"] = {"pos": cpos, "radius": cr}
	var nc := FastNoiseLite.new()
	nc.seed = seed ^ 0xC17E
	nc.frequency = 0.12
	for y in h:
		for x in w:
			var t := cells[y * w + x]
			if t == SEA or t == MOUNTAIN:
				continue
			var d := Vector2(x - cpos.x, y - cpos.y).length() + nc.get_noise_2d(x, y) * 3.5
			if d < cr * 0.5:
				cells[y * w + x] = CITY_CORE
			elif d < cr:
				cells[y * w + x] = SUBURB

	# harbor: the city's edge nearest the sea
	var best := Vector2i(-1, -1)
	var bestd := 1 << 30
	for y in h:
		for x in w:
			if cells[y * w + x] == BEACH:
				var dd: int = (Vector2i(x, y) - cpos).length_squared()
				if dd < bestd:
					bestd = dd
					best = Vector2i(x, y)
	var hr: int = int(cfg["harbor"]["radius"])
	anchors["harbor"] = {"pos": best, "radius": hr}
	_stamp(best, hr, HARBOR, [SEA, MOUNTAIN])

	# industrial belt: between the city and the harbor
	var ir: int = int(cfg["industrial_belt"]["radius"])
	var mid := Vector2i((cpos.x + best.x) / 2, (cpos.y + best.y) / 2)
	anchors["industrial_belt"] = {"pos": mid, "radius": ir}
	_stamp(mid, ir, INDUSTRIAL, [SEA, MOUNTAIN, CITY_CORE, HARBOR])

	# airport: flat land outside the city, within the allowed distance band
	var ac: Dictionary = cfg["airport"]
	var apos := Vector2i(-1, -1)
	for _try in 400:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(cr + float(ac["min_dist_from_city"]), cr + float(ac["max_dist_from_city"]))
		var p := Vector2i(cpos.x + int(cos(ang) * dist), cpos.y + int(sin(ang) * dist))
		if p.x < 4 or p.y < 4 or p.x >= w - 4 or p.y >= h - 4:
			continue
		var t := cells[p.y * w + p.x]
		if t == PLAIN or t == FOREST:
			apos = p
			break
	if apos.x < 0:
		apos = Vector2i(clampi(cpos.x + cr + 8, 4, w - 5), cpos.y)
	anchors["airport"] = {"pos": apos, "radius": int(ac["radius"])}
	_stamp(apos, int(ac["radius"]), AIRPORT, [SEA, MOUNTAIN, CITY_CORE])

	# roads: jittered lines city -> harbor, city -> airport, city -> a mountain pass
	var pass_pos := _nearest(cpos, [MOUNTAIN, HILL])
	for target in [best, apos, pass_pos]:
		_road(cpos, target, rng)

func _edge_dist(side: String, x: int, y: int) -> int:
	match side:
		"E": return w - 1 - x
		"W": return x
		"S": return h - 1 - y
		_: return y

func _stamp(c: Vector2i, r: int, t: int, keep: Array) -> void:
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			if Vector2(x - c.x, y - c.y).length() <= r and not (cells[y * w + x] in keep):
				cells[y * w + x] = t

func _nearest(c: Vector2i, types: Array) -> Vector2i:
	var best := c
	var bd := 1 << 30
	for y in h:
		for x in w:
			if cells[y * w + x] in types:
				var d := (Vector2i(x, y) - c).length_squared()
				if d < bd:
					bd = d
					best = Vector2i(x, y)
	return best

func _road(a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var p := Vector2(a)
	var steps := int(Vector2(a).distance_to(Vector2(b))) * 2 + 1
	for i in steps:
		var t := float(i) / steps
		var q := Vector2(a).lerp(Vector2(b), t) + Vector2(sin(t * 9.0 + rng.randf()) * 1.2, cos(t * 7.0) * 1.2)
		var x := int(q.x)
		var y := int(q.y)
		if x < 0 or y < 0 or x >= w or y >= h:
			continue
		var cur := cells[y * w + x]
		if cur != SEA and cur != CITY_CORE and cur != HARBOR and cur != AIRPORT and cur != INDUSTRIAL and cur != SUBURB:
			cells[y * w + x] = ROAD

func count(t: int) -> int:
	var n := 0
	for c in cells:
		if c == t:
			n += 1
	return n

func signature() -> int:
	return hash(cells)

func save_png(path: String, scale: int = 6) -> void:
	var pal := [Color("#1d4f91"), Color("#e8d9a0"), Color("#8cbf6a"), Color("#a08f5a"), Color("#8a8a92"), Color("#e04a8a"), Color("#d9a0c8"),
				Color("#2fb6c9"), Color("#f2f2f2"), Color("#c9822f"), Color("#3e7d3e"), Color("#333333")]
	var img := Image.create(w * scale, h * scale, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			img.fill_rect(Rect2i(x * scale, y * scale, scale, scale), pal[cells[y * w + x]])
	img.save_png(path)
