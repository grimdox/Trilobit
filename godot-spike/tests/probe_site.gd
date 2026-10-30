extends SceneTree
const MS = preload("res://src/missions.gd")
const SITE = preload("res://src/mission_site.gd")
const CG = preload("res://src/citygen.gd")
func _initialize() -> void:
	var lay := ["open", "closed", "mix"]
	var lens := ["short", "mid", "long"]
	var args := OS.get_cmdline_user_args()
	for l in lay:
		for ln in lens:
			var o: Dictionary = MS.offers(5, 100, 0)[4]
			o["layout"] = l
			o["length"] = ln
			o["rooms"] = MS.ROOMS[ln]
			o["hostiles"] = MS.hostile_count(o["rooms"], 2)
			o["seed"] = 777
			var c = SITE.build(o)
			var st: Dictionary = c.get_meta("site")
			var S: int = c.size
			# flood
			var seen := {int(st["entry"]): true}
			var q: Array = [int(st["entry"])]
			var qi := 0
			while qi < q.size():
				var cur: int = q[qi]; qi += 1
				for d in [1, -1, S, -S, S + 1, S - 1, -S + 1, -S - 1]:
					var nx: int = cur + d
					if nx < 0 or nx >= S * S or seen.has(nx) or CG.WALK[c.tiles[nx]] == 0: continue
					if abs((nx % S) - (cur % S)) > 1: continue
					seen[nx] = true
					q.append(nx)
			var ag: Array = st["agents"]
			print("%s/%s rooms=%d size=%d doors=%d agents=%d reach_exit=%s inside=%s" % [l, ln, st["rooms"].size(), S, st["doors"].size(), ag.size(), seen.has(int(st["exit"])), st["inside"]])
			if ln == "mid" and args.size() > 0:
				var amap := {}
				for a in ag: amap[int(a["cell"])] = "G" if a["role"] == "guard" else ("T" if a["role"] == "target" else "b")
				var out := ""
				for y in S:
					var line := ""
					for x in S:
						var ce: int = y * S + x
						var ch := " "
						var tt: int = c.tiles[ce]
						if tt == CG.WALL: ch = "#"
						elif tt == CG.DOOR: ch = "+"
						elif tt == CG.TID["portal"]: ch = "O"
						elif tt == CG.TID["mission_device"]: ch = "D"
						elif tt == CG.TID["floor_steel"] or tt == CG.TID["floor_clean"]: ch = "."
						elif tt == CG.GROUND: ch = ","
						if amap.has(ce): ch = amap[ce]
						if ce == int(st["entry"]): ch = "@"
						line += ch
					out += line + "\n"
				print(out)
	quit()
