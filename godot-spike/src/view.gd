extends Node2D
## Draws the game around the player with a CDDA-format tileset: terrain, items, cars, people with awareness marks, a target bracket.
const CG = preload("res://src/citygen.gd")
var game
var tileset
var cols: int = 40
var rows: int = 19
var font: Font = ThemeDB.fallback_font

const TERRAIN := {0: "t_sidewalk", 1: "t_pavement", 2: "t_wall", 3: "t_floor", 4: "t_door_c", 5: "t_water_dp", 6: "t_grass", 7: "",
	8: "t_stairs_up", 9: "t_elevator", 10: "t_wall_glass", 11: "t_metal_flat_roof", 12: "t_rock_floor", 13: "t_concrete", 14: "t_railroad_tie",
	15: "t_floor_metal_gangway", 16: "t_water_sh_murky_underground", 17: "t_rock", 18: "t_metal_floor", 19: "t_ladder_up_down", 20: "t_glass_railing",
	21: "t_manhole_cover", 22: "t_door_metal_locked", 23: "f_crate_c", 24: "f_dumpster", 25: "f_planter"}
const DARK := Color(0.38, 0.4, 0.55)

func tile() -> int:
	return tileset.tile_w

func _blit(id: String, pos: Vector2, mod: Color = Color.WHITE) -> bool:
	var sp: Array = tileset.sprite(id)
	if sp.is_empty():
		return false
	var r: Rect2 = sp[1]
	draw_texture_rect_region(sp[0], Rect2(pos + sp[2], r.size), r, mod)
	return true

func item_sprite(it) -> String:
	var id: String = it.def["id"]
	if tileset.has(id):
		return id
	var ll: String = it.def.get("looks_like", "")
	return ll if tileset.has(ll) else "money_bundle_hundred"

func person_sprite(i: int) -> String:
	match int(game.fac[i]):
		1: return "mon_trl_thug"
		2: return "mon_trl_soldier"
		3: return "mon_trl_assassin"
		_: return "npc_female" if game.fem[i] == 1 else "npc_male"

## the first solid tile below an air cell, or -1 (what you would see looking down from a window or the roof edge)
func _below(c: int) -> int:
	var s2: int = game.s2
	var local := c % s2
	var l := c / s2
	while l > 0:
		l -= 1
		var t: int = game.city.tiles[l * s2 + local]
		if t != 7:
			return t
	return -1

func _draw() -> void:
	if game == null or tileset == null:
		return
	var T := tile()
	var size: int = game.size
	var s2: int = game.s2
	var base: int = (game.pc / s2) * s2
	var px: int = game.lx(game.pc)
	var py: int = game.ly(game.pc)
	var ox := px - cols / 2
	var oy := py - rows / 2
	var below_mod := Color(0.5, 0.55, 0.75)
	for sy in rows:
		for sx in cols:
			var wx := ox + sx
			var wy := oy + sy
			if wx < 0 or wy < 0 or wx >= size or wy >= size:
				continue
			var c := base + wy * size + wx
			if game.fov.explored[c] == 0:
				continue
			var vis: bool = game.fov.visible[c] == 1
			var mod: Color = Color.WHITE if vis else DARK
			var pos := Vector2(sx * T, sy * T)
			var t: int = game.city.tiles[c]
			if t == 7:
				var bt := _below(c)
				if bt >= 0:
					_blit(TERRAIN[bt], pos, mod * below_mod)
				continue
			if t >= 23:
				_blit(TERRAIN[0], pos, mod)
				if not _blit(TERRAIN[t], pos, mod):
					draw_rect(Rect2(pos + Vector2(4, 4), Vector2(T - 8, T - 8)), Color(0.5, 0.4, 0.25) * mod)
			else:
				_blit(TERRAIN[t], pos, mod)
			if vis and game.items_at.has(c):
				var arr: Array = game.items_at[c]
				_blit(item_sprite(arr[arr.size() - 1]), pos)
	# the train
	if game.transit.active() and game.z_of(game.pc) == -1:
		var k := 0
		for c in game.transit.car_cells():
			var wx: int = c % size - ox
			var wy: int = (c / size) % size - oy
			if wx >= 0 and wy >= 0 and wx < cols and wy < rows and game.fov.visible[c] == 1:
				var r := Rect2(wx * T + 2, wy * T + 2, T - 4, T - 4)
				draw_rect(r, Color(0.85, 0.2, 0.35) if k == 0 else Color(0.75, 0.78, 0.85))
				draw_rect(r.grow(-5), Color(0.15, 0.2, 0.3))
				draw_rect(Rect2(r.position.x + 4, r.position.y + 4, r.size.x - 8, 3), Color(1, 0.9, 0.5))
			k += 1
	# loose things and animals
	for t in game.things:
		if t["k"] == "":
			continue
		var tc: int = t["cell"]
		if tc / s2 != base / s2 or game.fov.visible[tc] == 0:
			continue
		var tx: int = tc % size - ox
		var ty: int = (tc / size) % size - oy
		if tx < 0 or ty < 0 or tx >= cols or ty >= rows:
			continue
		var tid: String = "f_" + String(t["k"]) + ("_c" if t["k"] == "crate" else "")
		if not _blit(tid, Vector2(tx * T, ty * T)):
			draw_rect(Rect2(tx * T + 6, ty * T + 6, T - 12, T - 12), Color(0.6, 0.45, 0.25))
	for k in game.critters:
		if k["k"] == "":
			continue
		var kc: int = k["cell"]
		if kc / s2 != base / s2 or game.fov.visible[kc] == 0:
			continue
		var kx: int = kc % size - ox
		var ky: int = (kc / size) % size - oy
		if kx < 0 or ky < 0 or kx >= cols or ky >= rows:
			continue
		if not _blit("mon_" + String(k["k"]), Vector2(kx * T, ky * T)):
			draw_string(font, Vector2(kx * T + T * 0.3, ky * T + T * 0.7), "d" if k["k"] == "dog" else "c", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.7, 0.4))
	# vehicles (they stay on the ground)
	for v in game.vehicles:
		var c: int = v["cell"]
		if c / s2 != base / s2:
			continue
		var wx: int = c % size - ox
		var wy: int = (c / size) % size - oy
		if wx < 0 or wy < 0 or wx >= cols or wy >= rows:
			continue
		if game.fov.visible[c] == 0:
			continue
		_draw_vehicle(Vector2(wx * T + T / 2.0, wy * T + T / 2.0), v, T)
	# people
	for k in game.sim.near_list.size():
		var i: int = game.sim.near_list[k]
		var c: int = game.sim.pos[i]
		if c / s2 != base / s2:
			continue
		var wx: int = c % size - ox
		var wy: int = (c / size) % size - oy
		if wx < 0 or wy < 0 or wx >= cols or wy >= rows or game.fov.visible[c] == 0:
			continue
		var pos := Vector2(wx * T, wy * T)
		_blit(person_sprite(i), pos)
		var glyph := ""
		var col := Color.WHITE
		match int(game.astate[i]):
			1: glyph = "?"; col = Color(1, 0.9, 0.2)
			2: glyph = "?"; col = Color(1, 0.55, 0.1)
			3: glyph = "!"; col = Color(1, 0.2, 0.2)
			5: glyph = "~"; col = Color(0.6, 0.9, 1)
			6: glyph = "="; col = Color.WHITE
		if glyph == "":
			match int(game.eco.role[i]):
				1: glyph = "$"; col = Color(0.4, 1, 0.5)
				2: glyph = "+"; col = Color(0.4, 0.9, 1)
				3: glyph = "*"; col = Color(1, 0.8, 0.3)
		if glyph != "":
			draw_string(font, pos + Vector2(T * 0.3, -2), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		elif game.meter[i] > 0 and game.astate[i] == 0:
			draw_rect(Rect2(pos.x + 4, pos.y - 2, (T - 8) * game.meter[i] / 100.0, 3), Color(1, 0.9, 0.2))
	# the player
	var centre := Vector2((px - ox) * T, (py - oy) * T)
	if game.in_vehicle >= 0:
		_draw_vehicle(centre + Vector2(T / 2.0, T / 2.0), game.vehicles[game.in_vehicle], T)
	elif game.transit.riding < 0:
		if game.flying:
			draw_circle(centre + Vector2(T / 2.0, T * 0.9), T * 0.28, Color(0, 0, 0, 0.35))
			draw_circle(centre + Vector2(T / 2.0, T * 0.95), 5.0, Color(1, 0.7, 0.2, 0.9))
		_blit("player_male", centre)
	else:
		_blit("player_male", centre, Color(1, 1, 1, 0.9))
	# the job target, if it is on this level
	if not game.eco.job.is_empty() and int(game.eco.job["cell"]) / s2 == base / s2:
		var jc: int = game.eco.job["cell"]
		var jr := Rect2((game.lx(jc) - ox) * T, (game.ly(jc) - oy) * T, T, T)
		draw_rect(jr, Color(1, 0.8, 0.2), false, 2.0)
	# vision cones of the watchful (armed or hostile, still unaware)
	for k in game.sim.near_list.size():
		var i: int = game.sim.near_list[k]
		if game.sim.alive[i] == 0 or int(game.fac[i]) == 0 or game.astate[i] > 2 or game.sim.pos[i] / s2 != base / s2:
			continue
		var pcell: int = game.sim.pos[i]
		if game.fov.visible[pcell] == 0:
			continue
		var fd: Array = game.DIR8[game.face[i]]
		var fl: float = sqrt(float(fd[0] * fd[0] + fd[1] * fd[1]))
		var tint := Color(1, 0.85, 0.2, 0.13) if game.astate[i] == 0 else Color(1, 0.5, 0.1, 0.2)
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				if dx == 0 and dy == 0:
					continue
				var dl: float = sqrt(float(dx * dx + dy * dy))
				if dl > 6.5 or float(fd[0] * dx + fd[1] * dy) / (fl * dl) < 0.5:
					continue
				var cc: int = pcell + dy * size + dx
				if cc < 0 or cc >= game.total or game.fov.visible[cc] == 0 or not game.sim._sees(pcell, cc, 7):
					continue
				draw_rect(Rect2((game.lx(cc) - ox) * T, (game.ly(cc) - oy) * T, T, T), tint)
	# target bracket
	var tg: int = game.current_target()
	if tg >= 0:
		var c: int = game.sim.pos[tg]
		var r := Rect2((c % size - ox) * T, ((c / size) % size - oy) * T, T, T)
		draw_rect(r, Color(1, 0.2, 0.2), false, 2.0)
		if game.aim_turns > 0:
			draw_rect(r.grow(3), Color(1, 0.6, 0.2), false, 1.0)
	# tracers from the last volley
	for tr in game.tracers:
		var a: int = tr[0]
		var b: int = tr[1]
		var pa := Vector2((a % size - ox + 0.5) * T, ((a / size) % size - oy + 0.5) * T)
		var pb := Vector2((b % size - ox + 0.5) * T, ((b / size) % size - oy + 0.5) * T)
		draw_line(pa, pb, Color(1, 0.95, 0.5) if tr[2] else Color(0.8, 0.8, 0.8, 0.6), 2.0)

func _draw_vehicle(centre: Vector2, v: Dictionary, T: int) -> void:
	var kind: String = String(v.get("kind", "car"))
	if kind == "gyro":
		var col: Color = v["color"]
		if v.get("air", false):
			draw_circle(centre + Vector2(0, T * 0.45), T * 0.3, Color(0, 0, 0, 0.3))
		draw_circle(centre, T * 0.3, col)
		draw_circle(centre, T * 0.16, col.darkened(0.5))
		draw_line(centre - Vector2(T * 0.5, 0), centre + Vector2(T * 0.5, 0), Color(0.9, 0.9, 0.95), 2.0)
		draw_line(centre - Vector2(0, T * 0.5), centre + Vector2(0, T * 0.5), Color(0.9, 0.9, 0.95), 2.0)
	elif kind == "mech":
		var col2: Color = v["color"]
		draw_rect(Rect2(centre + Vector2(-T * 0.3, -T * 0.1), Vector2(T * 0.6, T * 0.45)), col2)
		draw_rect(Rect2(centre + Vector2(-T * 0.15, -T * 0.4), Vector2(T * 0.3, T * 0.28)), col2.lightened(0.3))
		draw_rect(Rect2(centre + Vector2(-T * 0.1, -T * 0.32), Vector2(T * 0.2, 4)), Color(1, 0.9, 0.3))
		draw_rect(Rect2(centre + Vector2(-T * 0.4, T * 0.15), Vector2(T * 0.18, T * 0.3)), col2.darkened(0.3))
		draw_rect(Rect2(centre + Vector2(T * 0.22, T * 0.15), Vector2(T * 0.18, T * 0.3)), col2.darkened(0.3))
	else:
		_draw_car(centre, int(v["dir"]), v["color"], T)

func _draw_car(centre: Vector2, dir: int, col: Color, T: int) -> void:
	var horiz := dir == 1 or dir == 3
	var w := T * 0.9 if horiz else T * 0.55
	var h := T * 0.55 if horiz else T * 0.9
	var r := Rect2(centre - Vector2(w, h) / 2.0, Vector2(w, h))
	draw_rect(r, Color(0, 0, 0, 0.5).lerp(col, 0.0) if false else col)
	draw_rect(r.grow(-3), col.lightened(0.25))
	# windscreen and headlights on the front end
	var f := Vector2([0, 1, 0, -1][dir], [-1, 0, 1, 0][dir])
	draw_circle(centre + f * (T * 0.4), 3.0, Color(1, 1, 0.7))
	draw_rect(Rect2(centre + f * (T * 0.12) - Vector2(4, 4), Vector2(8, 8)), Color(0.1, 0.15, 0.25))
