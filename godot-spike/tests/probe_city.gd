extends SceneTree
## Builds the island city and writes a flat colour map of it (one 2x2 block per tile) for a quick look.
const ISL = preload("res://src/island.gd")
const CG = preload("res://src/citygen.gd")
const LV = preload("res://src/levels.gd")
func _init() -> void:
	var out := "/tmp/claude-0/city_probe.png"
	var sd := 7
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		sd = int(args[1])
	var t0 := Time.get_ticks_msec()
	var isl = ISL.new(sd)
	var c = isl.build_zone(ISL.CITY_ZONE.x, ISL.CITY_ZONE.y)
	print("generate ms ", Time.get_ticks_msec() - t0)
	LV.build(c, sd)
	isl.rail_portal(c)
	print("total ms ", Time.get_ticks_msec() - t0, " size ", c.size, " buildings ", c.buildings, " towers ", c.towers.size(), " zmax ", c.zmax)
	print("stops ", c.subway["stops"].size(), " homes ", c.homes.size(), " works ", c.works.size(), " shops ", c.shops.size(), " venues ", c.venues.size())
	print("xs ", c.xs)
	print("ys ", c.ys, " ", c.ys_w)
	for i in c.xs.size() - 1:
		var line := ""
		for j in c.ys.size() - 1:
			var cx: int = (int(c.xs[i]) + 12 + int(c.xs[i + 1])) / 2
			var cy: int = (int(c.ys[j]) + c.line_w(int(c.ys[j]), true) + int(c.ys[j + 1])) / 2
			var tt: int = c.tiles[cy * c.size + cx]
			line += {0: "g", 1: "r", 3: "F", 6: "P", 2: "W", 4: "D"}.get(tt, "?")
		print("blk ", i, " ", line)
	print("plan rail ", c.plan["rail"], " river ", c.plan["river"])
	var pal := {0: "#8a8a8f", 1: "#2a2a30", 2: "#d8d8e0", 3: "#9a8f7a", 4: "#e0a030", 5: "#1d4f91", 6: "#3f8f3f", 11: "#6a6a78", 13: "#b09060", 14: "#ff5a5a", 20: "#ffffff", 26: "#b0a090", 27: "#a04632", 28: "#5a5a68", 29: "#1c4a24", 30: "#8a8070", 31: "#a8a040", 32: "#cdbd7c", 10: "#7fd6e8", 23: "#c08040", 24: "#80a080", 25: "#4a9a4a"}
	var sc := 1
	var img := Image.create(c.size * sc, c.size * sc, false, Image.FORMAT_RGB8)
	for y in c.size:
		for x in c.size:
			var tt: int = c.tiles[y * c.size + x]
			var col := Color(pal.get(tt, "#554455"))
			var mk: int = c.marks[y * c.size + x]
			if tt == CG.ROAD and (mk == 2 or mk == 4):
				col = Color("#c8a010")
			img.fill_rect(Rect2i(x * sc, y * sc, sc, sc), col)
	# the underground rail (level -1) over the top in red where it is track
	var l1: int = c.lvl_of_z(-1) * c.size * c.size
	for y in c.size:
		for x in c.size:
			if c.tiles[l1 + y * c.size + x] == CG.TRACK:
				img.fill_rect(Rect2i(x * sc, y * sc, sc, sc), Color("#ff9a3a"))
	img.save_png(out)
	quit(0)
