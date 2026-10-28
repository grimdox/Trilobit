extends SceneTree
## How full are the buildings?  Builds the island city and counts plain buildings, businesses, venues, houses and towers, and how many have furniture.
const ISL = preload("res://src/island.gd")
const CG = preload("res://src/citygen.gd")
const LV = preload("res://src/levels.gd")
func furn(c, x0, y0, x1, y1) -> int:
	var n := 0
	for y in range(y0 + 1, y1):
		for x in range(x0 + 1, x1):
			if int(c.tiles[y * c.size + x]) >= CG.EXTRA0 and int(CG.WALK[c.tiles[y * c.size + x]]) == 0:
				n += 1
	return n
func _init() -> void:
	var sd := 7
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		sd = int(args[0])
	var isl = ISL.new(sd)
	var c = isl.build_zone(ISL.CITY_ZONE.x, ISL.CITY_ZONE.y)
	var kinds := {}
	var filled := {}
	for b in c.bldgs:
		var k: String = b["kind"]
		kinds[k] = int(kinds.get(k, 0)) + 1
		if furn(c, b["x0"], b["y0"], b["x1"], b["y1"]) >= 3:
			filled[k] = int(filled.get(k, 0)) + 1
	var nf := 0
	for b in c.bldgs:
		if b["kind"] != "core" and b.get("filled", false):
			nf += 1
	var nplain := 0
	for b in c.bldgs:
		if b["kind"] != "core":
			nplain += 1
	var tot: int = nplain + c.businesses.size() + c.towers.size()
	print("FILL: plain non-tower ", nplain, " furnished ", nf, " businesses ", c.businesses.size(), " towers ", c.towers.size(), " -> filled share ", float(nf + c.businesses.size() + c.towers.size()) / float(tot), " signs ", c.signs.size())
	print("plain buildings by kind ", kinds, " with 3+ solid furniture ", filled)
	var hist := {}
	for b in c.bldgs:
		if b["kind"] == "mid":
			var w: int = b["x1"] - b["x0"] + 1
			var h: int = b["y1"] - b["y0"] + 1
			var key: String = "%dx%d" % [mini(w, h) / 2 * 2, maxi(w, h) / 4 * 4]
			hist[key] = int(hist.get(key, 0)) + 1
	var ks: Array = hist.keys()
	ks.sort()
	print("mid sizes (min side x max side): ", hist)
	var bt := {}
	for b in c.businesses:
		bt[b["type"]] = int(bt.get(b["type"], 0)) + 1
	print("businesses ", c.businesses.size(), " ", bt)
	var vt := {}
	for v in c.venues:
		vt[v["kind"]] = int(vt.get(v["kind"], 0)) + 1
	print("venues ", c.venues.size(), " ", vt)
	print("houses ", c.houses.size(), " towers ", c.towers.size(), " buildings counter ", c.buildings)
	var tt := 0
	for i in c.size * c.size:
		if int(c.tiles[i]) == CG.TID["terminal"]:
			tt += 1
	print("mission terminal tiles (ground): ", tt)
	var booth := {}
	for b in c.businesses:
		var ts := 0
		for y in range(b["y0"], b["y1"] + 1):
			for x in range(b["x0"], b["x1"] + 1):
				if int(c.tiles[y * c.size + x]) == CG.TID["terminal"]:
					ts += 1
		if ts > 0:
			booth[b["type"]] = int(booth.get(b["type"], 0)) + ts
	print("terminals by business: ", booth)
	quit(0)
