extends SceneTree
## The game starts in a vacant flat, and no sign hangs over a window or door.  Run: godot --headless --path . -s tests/run_spawn.gd  (no TRL_STREET)
const GameScript = preload("res://src/game.gd")
const SG = preload("res://src/signage.gd")
var ok := 0
var n := 0
func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _initialize() -> void:
	for sd in [11, 44444]:
		var g = GameScript.new(sd)
		g.setup(2000)
		var inflat := false
		for a in g.city.apartments:
			var r: Rect2i = a["rect"]
			var base: int = (int(a["cell"]) / g.s2) * g.s2
			if g.pc >= base and g.pc < base + g.s2:
				var x: int = (g.pc - base) % g.size
				var y: int = (g.pc - base) / g.size
				if r.has_point(Vector2i(x, y)):
					inflat = true
		var hosts := 0
		for i in g.sim.n:
			if g.sim.pos[i] == g.pc:
				hosts += 1
		check("seed %d: the player starts inside a flat (floor %d), not on the road, with nobody on the cell" % [sd, g.z_of(g.pc)], inflat and g.z_of(g.pc) > 0 and hosts == 0)
		if sd == 11:
			var bad := 0
			var tile := 48.0
			var f := ThemeDB.fallback_font
			for sg in g.city.signs:
				var run: int = int(sg.get("run", 3))
				if run < 1:
					continue
				var kind: String = String(sg["kind"])
				var fsize: int = int(clampf(tile * 0.27, 12.0, 22.0)) if kind == "biz" else int(clampf(tile * 0.22, 10.0, 16.0))
				var bw: float = SG.sign_width(f, String(sg["name"]), fsize, tile, kind, run)
				var side: int = int(sg["side"])
				var d: int = -1 if bool(sg["flip"]) else 1
				var step: int = d * (1 if side < 2 else g.size)
				var a0: float = tile * 0.5 + 3.0
				for k in range(1, run + 3):
					if tile * (k + 0.5) > a0 and tile * (k - 0.5) < a0 + bw and g.city.tiles[int(sg["door"]) + step * k] != 2:
						bad += 1
			check("no sign covers a window or door (%d signs)" % g.city.signs.size(), bad == 0)
	print("SPAWN %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
