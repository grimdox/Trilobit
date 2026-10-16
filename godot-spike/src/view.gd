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
	21: "t_manhole_cover", 22: "t_door_metal_locked", 23: "f_crate_c", 24: "f_dumpster", 25: "f_planter",
	26: "t_trl_gravel", 27: "t_rock_red", 28: "t_rock", 29: "t_tree", 30: "t_rock_floor", 31: "t_grass_grazed", 32: "t_sand"}
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

func _fallback(t: int) -> Color:
	match t:
		26: return Color(0.5, 0.48, 0.45)
		27: return Color(0.45, 0.3, 0.25)
		28: return Color(0.4, 0.4, 0.45)
		30: return Color(0.5, 0.48, 0.42)
		31: return Color(0.55, 0.62, 0.3)
		32: return Color(0.85, 0.8, 0.55)
	return Color(0.5, 0.5, 0.5)

## lane lines on roads and the rails and ties on a railway
func _paint_marks(c: int, pos: Vector2, T: int, mod: Color, t: int) -> void:
	var marks: PackedByteArray = game.city.marks
	var m: int = marks[c] if c < marks.size() else 0
	if m == 0:
		return
	var w := 5.0
	var size: int = game.size
	var white := Color(0.92, 0.92, 0.95) * mod
	var yellow := Color(0.98, 0.8, 0.15) * mod
	match m:
		1:   # white, vertical: on the outer edge, away from the black lane
			var x: float = pos.x + (T - w if game.city.tiles[c - 1] == 1 else 0.0)
			draw_rect(Rect2(x, pos.y, w, T), white)
		2:   # double yellow: the two tiles hug the centre
			var x2: float = pos.x + (T - w if marks[c + 1] == 2 else 0.0)
			draw_rect(Rect2(x2, pos.y, w, T), yellow)
		3:
			var y: float = pos.y + (T - w if game.city.tiles[c - size] == 1 else 0.0)
			draw_rect(Rect2(pos.x, y, T, w), white)
		4:
			var y2: float = pos.y + (T - w if marks[c + size] == 4 else 0.0)
			draw_rect(Rect2(pos.x, y2, T, w), yellow)
		5:
			for k in 4:
				draw_rect(Rect2(pos.x + k * T / 4.0 + 2, pos.y + 2, 4, T - 4), Color(0.32, 0.2, 0.12) * mod)
			draw_rect(Rect2(pos.x, pos.y + T * 0.5 - 2, T, 4), Color(0.7, 0.72, 0.78) * mod)
		6:
			for k in 4:
				draw_rect(Rect2(pos.x + 2, pos.y + k * T / 4.0 + 2, T - 4, 4), Color(0.32, 0.2, 0.12) * mod)
			draw_rect(Rect2(pos.x + T * 0.5 - 2, pos.y, 4, T), Color(0.7, 0.72, 0.78) * mod)

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
				if game.island != null and base == 0:
					var ot: int = game.outside_tile(wx, wy)
					var opos := Vector2(sx * T, sy * T)
					if ot == 29:
						_blit(TERRAIN[6], opos, DARK)
					if not _blit(TERRAIN[ot], opos, DARK):
						draw_rect(Rect2(opos, Vector2(T, T)), _fallback(ot) * DARK)
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
			if t >= 23 and t <= 25:
				_blit(TERRAIN[0], pos, mod)
				if not _blit(TERRAIN[t], pos, mod):
					draw_rect(Rect2(pos + Vector2(4, 4), Vector2(T - 8, T - 8)), Color(0.5, 0.4, 0.25) * mod)
			elif t == 29:
				_blit(TERRAIN[6], pos, mod)
				_blit(TERRAIN[t], pos, mod)
			elif t == 1:
				draw_rect(Rect2(pos, Vector2(T, T)), Color(0.13, 0.13, 0.15) * mod)
				if ((c * 7919) >> 3) % 11 == 0:
					draw_rect(Rect2(pos.x + (c % 5) * 5 + 3, pos.y + (c % 7) * 4 + 3, 2, 2), Color(0.2, 0.2, 0.23) * mod)
				if c < s2:
					_paint_marks(c, pos, T, mod, t)
			else:
				if not _blit(TERRAIN[t], pos, mod):
					draw_rect(Rect2(pos, Vector2(T, T)), _fallback(t) * mod)
				if c < s2:
					_paint_marks(c, pos, T, mod, t)
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
		_facing_mark(Vector2(kx * T, ky * T), int(k.get("face", 0)), Color(0.95, 0.75, 0.4, 0.85))
		if not _blit("mon_" + String(k["k"]), Vector2(kx * T, ky * T)):
			draw_string(font, Vector2(kx * T + T * 0.3, ky * T + T * 0.7), "d" if k["k"] == "dog" else "c", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.7, 0.4))
	# vehicles: whole bodies, a tile for every tile of the footprint
	for vi in game.vehicles.size():
		var v: Dictionary = game.vehicles[vi]
		if int(v["cell"]) / s2 != base / s2:
			continue
		_draw_body(vi, v, ox, oy, T)
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
		_facing_mark(pos, int(game.face[i]), Color(1, 0.35, 0.3) if (int(game.fac[i]) != 0 and int(game.astate[i]) >= 1) else Color(0.85, 0.9, 1.0, 0.85))
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
		draw_circle(centre + Vector2(T / 2.0, T / 2.0), T * 0.22, Color(0.95, 0.8, 0.65))
		draw_arc(centre + Vector2(T / 2.0, T / 2.0), T * 0.22, PI, TAU, 12, Color(0.15, 0.1, 0.1), 3.0)
	elif game.transit.riding < 0:
		if game.flying:
			draw_circle(centre + Vector2(T / 2.0, T * 0.9), T * 0.28, Color(0, 0, 0, 0.35))
			draw_circle(centre + Vector2(T / 2.0, T * 0.95), 5.0, Color(1, 0.7, 0.2, 0.9))
		_blit("player_male", centre)
	else:
		_blit("player_male", centre, Color(1, 1, 1, 0.9))
	if game.in_vehicle < 0 and game.transit.riding < 0:
		_facing_mark(centre, game.DIR8.find([signi(game.facing.x), signi(game.facing.y)]), Color(0.3, 0.95, 1.0, 0.9))
	# the job target, if it is on this level
	if not game.eco.job.is_empty() and int(game.eco.job["cell"]) / s2 == base / s2:
		var jc: int = game.eco.job["cell"]
		var jr := Rect2((game.lx(jc) - ox) * T, (game.ly(jc) - oy) * T, T, T)
		draw_rect(jr, Color(1, 0.8, 0.2), false, 2.0)
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
	_draw_hud()

## a small pointer on the edge of a tile showing which way someone faces (index into DIR8)
func _facing_mark(pos: Vector2, fi: int, col: Color) -> void:
	var d: Array = game.DIR8[fi % 8]
	var T: float = float(tile())
	var dir := Vector2(d[0], d[1]).normalized()
	var c := pos + Vector2(T, T) * 0.5 + dir * T * 0.47
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([c + dir * T * 0.14, c - dir * T * 0.1 + side * T * 0.14, c - dir * T * 0.1 - side * T * 0.14]), col)

func _limb_color(f: float) -> Color:
	if f <= 0.0:
		return Color(0.25, 0.25, 0.28)
	return Color(0.9, 0.15, 0.15).lerp(Color(0.25, 0.85, 0.35), clampf(f, 0.0, 1.0))

func _bar(x: float, y: float, w: float, h: float, f: float, col: Color, label: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(x + 1, y + 1, (w - 2) * clampf(f, 0.0, 1.0), h - 2), col)
	draw_rect(Rect2(x, y, w, h), Color(1, 1, 1, 0.35), false, 1.0)
	draw_string(font, Vector2(x + 4, y + h - 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h) - 2, Color.WHITE)

## health and armor bars and a body diagram, top right: each limb is coloured by its health, grey when disabled
func _draw_hud() -> void:
	var W: float = float(cols * tile())
	var x0: float = W - 236.0
	var y0: float = 6.0
	draw_rect(Rect2(x0 - 6, y0 - 4, 238, 188), Color(0.03, 0.04, 0.08, 0.72))
	_bar(x0, y0, 224, 16, float(game.hp) / float(maxi(1, game.hp_max)), _limb_color(float(game.hp) / float(maxi(1, game.hp_max))), "HP  %d / %d" % [game.hp, game.hp_max])
	var ar: Dictionary = game.armor_status()
	var broken := false
	for l in game.BODY.LIMBS:
		for p in game.armor_pieces(l):
			if int(p["left"]) <= 0:
				broken = true
	var af: float = float(ar["left"]) / float(maxi(1, int(ar["max"])))
	_bar(x0, y0 + 20, 224, 16, af if int(ar["max"]) > 0 else 0.0, Color(0.35, 0.65, 0.95) if not broken else Color(0.9, 0.55, 0.2), "ARMOR %d   %d / %d%s" % [int(ar["value"]), int(ar["left"]), int(ar["max"]), "  BROKEN!" if broken else ""])
	# the figure
	var fx: float = x0 + 34.0
	var fy: float = y0 + 46.0
	var B = game.body
	draw_circle(Vector2(fx, fy + 8), 8.0, _limb_color(B.frac("head")))
	draw_rect(Rect2(fx - 10, fy + 18, 20, 32), _limb_color(B.frac("chest")))
	draw_rect(Rect2(fx - 20, fy + 19, 8, 28), _limb_color(B.frac("r_arm")))
	draw_rect(Rect2(fx + 12, fy + 19, 8, 28), _limb_color(B.frac("l_arm")))
	draw_rect(Rect2(fx - 9, fy + 52, 8, 34), _limb_color(B.frac("r_leg")))
	draw_rect(Rect2(fx + 1, fy + 52, 8, 34), _limb_color(B.frac("l_leg")))
	for r in [Rect2(fx - 20, fy + 19, 8, 28), Rect2(fx + 12, fy + 19, 8, 28), Rect2(fx - 9, fy + 52, 8, 34), Rect2(fx + 1, fy + 52, 8, 34), Rect2(fx - 10, fy + 18, 20, 32)]:
		draw_rect(r, Color(1, 1, 1, 0.3), false, 1.0)
	# per-limb bars with the armor on each
	var names := {"head": "HEAD", "chest": "CHEST", "l_arm": "L ARM", "r_arm": "R ARM", "l_leg": "L LEG", "r_leg": "R LEG"}
	var k := 0
	for l in game.BODY.LIMBS:
		var by: float = y0 + 44.0 + float(k) * 22.0
		var av: int = game.armor_value(l)
		_bar(x0 + 74, by, 150, 18, B.frac(l), _limb_color(B.frac(l)), "%s %d/%d%s" % [names[l], int(B.hp[l]), int(B.mx[l]), ("  [%d]" % av) if av > 0 else ""])
		if not B.ok(l):
			draw_string(font, Vector2(x0 + 190, by + 14), "OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.4, 0.4))
		k += 1

## a vehicle drawn tile by tile from its template
func _draw_body(vi: int, v: Dictionary, ox: int, oy: int, T: int) -> void:
	var size: int = game.size
	var kind: String = v["kind"]
	var dirn: int = int(v["dir"])
	var offs: Array = game.vs.offsets(kind, dirn)
	var a: int = int(v["cell"])
	var ax: int = a % size
	var ay: int = (a / size) % size
	var base: int = (a / game.s2) * game.s2
	var col: Color = v["color"]
	var wreck: bool = v["wreck"]
	var occupied := {}
	var any_vis := false
	for o in offs:
		occupied[Vector2i(o[0], o[1])] = String(o[2])
		var c: int = base + (ay + o[1]) * size + ax + o[0]
		if c >= 0 and c < game.total and game.fov.visible[c] == 1:
			any_vis = true
	if not any_vis:
		return
	var shade := Color(0, 0, 0, 0.28)
	var front: Vector2i = Vector2i(game.vs.DIR4[dirn][0], game.vs.DIR4[dirn][1])
	# a soft shadow under anything in the air
	var airborne: bool = bool(v.get("air", false))
	for o in offs:
		var px: float = float(ax + o[0] - ox) * T
		var py: float = float(ay + o[1] - oy) * T
		if px < -T or py < -T or px > cols * T or py > rows * T:
			continue
		var ch: String = String(o[2])
		var r := Rect2(px, py, T, T)
		var cc: Color = col
		match ch:
			"E": cc = col.darkened(0.18)
			"T": cc = col.lightened(0.06)
			"P": cc = col.lightened(0.25)
			"H": cc = col.darkened(0.35)
			"L": cc = Color(0.28, 0.3, 0.34)
			"C": cc = Color(0.17, 0.2, 0.26)
			"K": cc = Color(0.35, 0.55, 0.7)
		if airborne:
			draw_rect(Rect2(px + 4, py + T * 0.55, T, T), shade)
		draw_rect(r, cc)
		# panel seams
		match ch:
			"E":
				for k in 3:
					var gx: float = px + 6 + k * (T - 12) / 2.0
					if dirn % 2 == 0:
						draw_line(Vector2(gx, py + 5), Vector2(gx, py + T - 5), cc.darkened(0.4), 2.0)
					else:
						draw_line(Vector2(px + 5, py + 6 + k * (T - 12) / 2.0), Vector2(px + T - 5, py + 6 + k * (T - 12) / 2.0), cc.darkened(0.4), 2.0)
			"T":
				draw_rect(r.grow(-6), cc.darkened(0.12), false, 1.5)
			"C":
				draw_rect(r.grow(-5), Color(0.28, 0.33, 0.42))
			"W":
				var wr := Rect2(px + 6, py + 3, T - 12, T - 6) if dirn % 2 == 0 else Rect2(px + 3, py + 6, T - 6, T - 12)
				draw_rect(wr, Color(0.06, 0.06, 0.07))
			"L":
				draw_rect(r.grow(-7), Color(0.15, 0.16, 0.19))
			"P":
				draw_line(Vector2(px + 3, py + 3), Vector2(px + T - 3, py + T - 3), cc.darkened(0.25), 1.0)
			"H":
				draw_circle(r.get_center(), T * 0.28, Color(0.9, 0.3, 0.2))
		# the outer edge of the whole body
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			if not occupied.has(Vector2i(o[0], o[1]) + d):
				var e0 := Vector2(px, py)
				var e1 := Vector2(px, py)
				if d == Vector2i(0, -1):
					e1 = Vector2(px + T, py)
				elif d == Vector2i(1, 0):
					e0 = Vector2(px + T, py)
					e1 = Vector2(px + T, py + T)
				elif d == Vector2i(0, 1):
					e0 = Vector2(px, py + T)
					e1 = Vector2(px + T, py + T)
				else:
					e1 = Vector2(px, py + T)
				draw_line(e0, e1, Color(0, 0, 0, 0.8), 2.0)
		# lights: headlamps on the front tiles, brake lamps on the back
		if kind == "car" or kind == "truck":
			var f_axis: int = o[0] * front.x + o[1] * front.y
			var maxf := -99
			var minf := 99
			for o2 in offs:
				var fa: int = o2[0] * front.x + o2[1] * front.y
				maxf = maxi(maxf, fa)
				minf = mini(minf, fa)
			if f_axis == maxf and (ch == "E"):
				draw_circle(Vector2(px, py) + Vector2(T / 2.0, T / 2.0) + Vector2(front) * (T * 0.32), 3.5, Color(1, 1, 0.75))
			elif f_axis == minf and ch == "T":
				draw_circle(Vector2(px, py) + Vector2(T / 2.0, T / 2.0) - Vector2(front) * (T * 0.32), 3.0, Color(0.9, 0.15, 0.15))
		# damage: cracks on tiles of a hurt part, smoke from a hurt engine
		var part: String = String(game.vs.PART_OF.get(ch, "body"))
		var pct: int = game.vs.part_pct(v, part)
		if pct < 55 and not wreck:
			draw_line(Vector2(px + 6, py + 8), Vector2(px + T * 0.55, py + T * 0.6), Color(0, 0, 0, 0.7), 1.5)
			draw_line(Vector2(px + T * 0.55, py + T * 0.6), Vector2(px + T - 6, py + T - 10), Color(0, 0, 0, 0.7), 1.5)
		if pct < 30 and ch == "E":
			draw_circle(Vector2(px + T * 0.5, py + T * 0.3), 6.0, Color(0.15, 0.15, 0.15, 0.55))
			draw_circle(Vector2(px + T * 0.62, py), 8.0, Color(0.2, 0.2, 0.2, 0.4))
		if wreck:
			draw_rect(r, Color(0, 0, 0, 0.35))
	# the rotor of a helicopter: a disc and two blades
	if kind == "heli":
		var cx: float = (float(ax - ox) + 0.5) * T
		var cy: float = (float(ay - oy) + 1.2) * T
		if dirn == 1: cx -= T * 0.5
		var ang: float = float(game.turn) * 0.9
		if not wreck:
			draw_circle(Vector2(cx, cy), T * 3.0, Color(1, 1, 1, 0.06))
			for k in 2:
				var aa: float = ang + k * PI / 2.0
				draw_line(Vector2(cx, cy) - Vector2(cos(aa), sin(aa)) * T * 3.0, Vector2(cx, cy) + Vector2(cos(aa), sin(aa)) * T * 3.0, Color(0.9, 0.92, 0.96, 0.75), 3.0)
	if wreck:
		var ctr := Vector2((float(ax - ox) + 0.5) * T, (float(ay - oy) + 0.5) * T)
		draw_circle(ctr + Vector2(0, -T * 0.6), 9.0, Color(0.15, 0.15, 0.15, 0.5))
		draw_circle(ctr + Vector2(T * 0.3, -T * 1.2), 12.0, Color(0.2, 0.2, 0.2, 0.35))
