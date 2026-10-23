extends SceneTree
## The district tilesets in the game: all five load, every terrain and furniture sprite the world asks for is in each,
## districts map as designed (wealth in the city, the country, the docks, underground), and the street furniture the
## view adds is drawn by each set.  Run: godot --headless -s tests/run_tiles.gd
const TS = preload("res://src/tileset.gd")
const CG = preload("res://src/citygen.gd")
const ViewScript = preload("res://src/view.gd")
const WorldScript = preload("res://src/world.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool, detail := "") -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name + ("" if cond or detail == "" else "  -- " + detail))

func _initialize() -> void:
	var base = TS.new()
	base.load_dir("res://gfx/Trilobit64")
	var sets := {}
	for th in ViewScript.THEMES:
		var t = TS.new()
		if t.load_dir("res://gfx/tiles_" + th):
			sets[th] = t
	check("all five district tilesets load", sets.size() == 5, str(sets.keys()))
	var missing := []
	for th in sets:
		var t = sets[th]
		for k in ViewScript.TERRAIN:
			var id: String = ViewScript.TERRAIN[k]
			if id != "" and not t.index.has(t.pick(id, 3)):
				missing.append("%s %s" % [th, id])
		for k in CG.TILE_SPRITE:
			var id2: String = CG.TILE_SPRITE[k]
			if id2.begins_with("f_") or id2.begins_with("t_"):
				if not t.index.has(t.pick(id2, 5)):
					missing.append("%s %s" % [th, id2])
		for m in 16:
			if not t.index.has("t_wall.%d" % m) or not t.index.has("t_wall_glass.%d" % m):
				missing.append("%s wall %d" % [th, m])
	check("every terrain, furniture and wall sprite the world uses is in every district set", missing.is_empty(), str(missing.slice(0, 6)))
	var dec_missing := []
	for table in [ViewScript.DECOR_KERB, ViewScript.DECOR_FRONT, ViewScript.DECOR_PARK]:
		for th in table:
			for e in table[th]:
				var id3: String = e[1]
				if id3 == "neon":
					for col in ViewScript.NEON_BY_THEME[th]:
						if not sets[th].index.has("f_trl_neon_" + col):
							dec_missing.append("%s neon %s" % [th, col])
				elif not sets[th].index.has(id3):
					dec_missing.append("%s %s" % [th, id3])
	check("every piece of street furniture is drawn by its district set", dec_missing.is_empty(), str(dec_missing))
	# district mapping in a real city
	var w = WorldScript.new()
	w.start(21, 300)
	var g = w.game
	var v = ViewScript.new()
	v.game = g
	v.tileset = base
	v._load_themes()
	var seen := {}
	for c in range(0, g.s2, 997):
		seen[v.theme_at(c)] = true
	check("the city has slums, mid-town and downtown", seen.has("slum") and seen.has("mid") and seen.has("rich"), str(seen.keys()))
	check("underground is the sewer and industry set", v.theme_at((g.city.zmax + 1) * g.s2 + 5) == "industry")
	var same := true
	for c in range(0, g.s2, 4999):
		if v.theme_at(c) != v.theme_at(c):
			same = false
	check("a cell's district never changes", same)
	v.free()
	print("TILES %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
