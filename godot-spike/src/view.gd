extends Node2D
## Draws the game around the player with a CDDA-format tileset: terrain, items, cars, people with awareness marks, a target bracket.
const CG = preload("res://src/citygen.gd")
const PD = preload("res://src/paperdoll.gd")
const DS = preload("res://src/dollspec.gd")
var pd = PD.new()
var game
var tileset
const TILE := 64            # screen pixels per cell: sprites are drawn at 64x64 whatever the tileset's own size
const S := 2.0              # TILE / 32: scale for hand-placed pixel offsets
var cols: int = 30
var rows: int = 15
var font: Font = ThemeDB.fallback_font

const TERRAIN := {0: "t_sidewalk", 1: "t_pavement", 2: "t_wall", 3: "t_floor", 4: "t_door_c", 5: "t_water_dp", 6: "t_grass", 7: "",
	8: "t_stairs_up", 9: "t_elevator", 10: "t_wall_glass", 11: "t_metal_flat_roof", 12: "t_rock_floor", 13: "t_concrete", 14: "t_railroad_tie",
	15: "t_floor_metal_gangway", 16: "t_water_sh_murky_underground", 17: "t_rock", 18: "t_metal_floor", 19: "t_ladder_up_down", 20: "t_glass_railing",
	21: "t_manhole_cover", 22: "t_door_metal_locked", 23: "f_crate_c", 24: "f_dumpster", 25: "f_planter",
	26: "t_trl_gravel", 27: "t_rock_red", 28: "t_rock", 29: "t_tree", 30: "t_rock_floor", 31: "t_grass_grazed", 32: "t_sand"}
const DARK := Color(0.38, 0.4, 0.55)

func tile() -> int:
	return TILE

func _blit(id: String, pos: Vector2, mod: Color = Color.WHITE) -> bool:
	if id.begins_with("icon:"):
		if not pd.has(id):
			return false
		var ir: Rect2 = pd.rect(id)
		draw_texture_rect_region(pd.tex, Rect2(pos, ir.size * pd.scale), ir, mod)
		return true
	var sp: Array = tileset.sprite(id)
	if sp.is_empty():
		return false
	var r: Rect2 = sp[1]
	var k: float = sp[3]
	draw_texture_rect_region(sp[0], Rect2(pos + sp[2] * k, r.size * k), r, mod)
	return true

func item_sprite(it) -> String:
	var id: String = it.def["id"]
	if tileset.has(id):
		return id
	if pd.has("icon:" + id):
		return "icon:" + id
	var ll: String = it.def.get("looks_like", "")
	return ll if tileset.has(ll) else "money_bundle_hundred"

func person_sprite(i: int) -> String:
	return "npc_female" if game.fem[i] == 1 else "npc_male"

## the paper doll.  The 64px set has top-down layers (facing up, centred on the cell) that are stacked by z and turned to the facing.
func doll_ready() -> bool:
	return tileset != null and tileset.has("dl:d_legs")

func _draw_doll(spec: Dictionary, pos: Vector2, face_dir: Vector2i, mod: Color = Color.WHITE) -> void:
	if doll_ready():
		_draw_doll64(spec, pos, face_dir, mod)
		return
	for l in spec["layers"]:
		var key := "doll:" + String(l)
		if pd.has(key):
			var dr: Rect2 = pd.rect(key)
			draw_texture_rect_region(pd.tex, Rect2(pos + Vector2(0, -2) * S, dr.size * pd.scale), dr, mod)
	var w: String = spec["weapon"]
	if w != "" and pd.has("icon:" + w):
		var d := Vector2(face_dir.x, face_dir.y)
		if d == Vector2.ZERO:
			d = Vector2(0, 1)
		var ang: float = d.angle()
		var left: bool = d.x < -0.1
		var hand := pos + (Vector2(9, 22) if left else Vector2(23, 22)) * S
		draw_set_transform(hand, ang, Vector2(1, -1) if left else Vector2(1, 1))
		var wr: Rect2 = pd.rect("icon:" + w)
		draw_texture_rect_region(pd.tex, Rect2(Vector2(-7, -14) * S, wr.size * pd.scale), wr, mod)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

const DOLL_S := 0.95

func _draw_doll64(spec: Dictionary, pos: Vector2, face_dir: Vector2i, mod: Color) -> void:
	var lk: Dictionary = spec["look"]
	var keys: Array = DS.base_layers(lk, bool(lk.get("hid", false)))
	keys.append_array(spec["layers"])
	var w: String = spec["weapon"]
	if w != "" and tileset.has("dl:hold:" + w):
		keys.append("hold:" + w)
	var items: Array = []
	for k in keys:
		var key := String(k)
		if not tileset.has("dl:" + key):
			continue
		var meta: Array = tileset.doll.get(key, [65, ""])
		items.append([int(meta[0]), key, String(meta[1])])
	items.sort_custom(func(a, b): return a[0] < b[0])
	var d := Vector2(face_dir.x, face_dir.y)
	if d == Vector2.ZERO:
		d = Vector2(0, 1)
	var centre := pos + Vector2(TILE, TILE) * 0.5
	draw_set_transform(centre, d.angle() + PI / 2.0, Vector2(DOLL_S, DOLL_S))
	for it in items:
		var sp: Array = tileset.sprite("dl:" + String(it[1]))
		var r: Rect2 = sp[1]
		var c := mod
		if it[2] == "skin":
			c = mod * lk["skin"]
		elif it[2] == "hair":
			c = mod * lk["hair"]
		if it[1] == "d_shadow":
			draw_set_transform(centre + Vector2(3, 4), 0.0, Vector2(DOLL_S, DOLL_S))
			draw_texture_rect_region(sp[0], Rect2(-r.size * 0.5, r.size), r, c)
			draw_set_transform(centre, d.angle() + PI / 2.0, Vector2(DOLL_S, DOLL_S))
			continue
		draw_texture_rect_region(sp[0], Rect2(-r.size * 0.5, r.size), r, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
	if m == 0 or ((m == 5 or m == 6) and tileset.index.has("t_railroad_tie.v")):
		return
	var w := 5.0 * S
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
				draw_rect(Rect2(pos.x + k * T / 4.0 + 2 * S, pos.y + 2 * S, 4 * S, T - 4 * S), Color(0.32, 0.2, 0.12) * mod)
			draw_rect(Rect2(pos.x, pos.y + T * 0.5 - 2 * S, T, 4 * S), Color(0.7, 0.72, 0.78) * mod)
		6:
			for k in 4:
				draw_rect(Rect2(pos.x + 2 * S, pos.y + k * T / 4.0 + 2 * S, T - 4 * S, 4 * S), Color(0.32, 0.2, 0.12) * mod)
			draw_rect(Rect2(pos.x + T * 0.5 - 2 * S, pos.y, 4 * S, T), Color(0.7, 0.72, 0.78) * mod)

## is the cell at (x, y) of the same level a wall, glass wall or door (what a wall segment joins up with)?
func _joins(base: int, x: int, y: int) -> bool:
	var size: int = game.size
	if x < 0 or y < 0 or x >= size or y >= size:
		return false
	var t: int = game.city.tiles[base + y * size + x]
	return t == 2 or t == 10 or t == 4 or t == 22

## one terrain cell: variants for texture, autotiled walls, doors that face along their wall, rails that turn
const WEALTH_TINT := [Color(0.80, 0.75, 0.70), Color(1, 1, 1), Color(1.10, 1.13, 1.22)]

func _cell_art(t: int, c: int, wx: int, wy: int, pos: Vector2, mod: Color, ground: bool) -> void:
	var T := TILE
	var wl: int = game.city.wealth_at(c)
	if wl != 1 and (t == 0 or t == 2 or t == 3 or t == 4 or t == 10):
		mod = mod * WEALTH_TINT[wl]
		if t == 3 and tileset.has("t_trl_marble") and tileset.has("t_concrete"):
			_blit(tileset.pick("t_trl_marble" if wl == 2 else "t_concrete", c), pos, mod)
			return
	var own: bool = tileset.index.has("t_wall.0")      # the Trilobit set has joined-up walls and doors
	var base: int = (c / game.s2) * game.s2
	if own and (t == 2 or t == 10):
		var m := 0
		if _joins(base, wx, wy - 1): m |= 1
		if _joins(base, wx + 1, wy): m |= 2
		if _joins(base, wx, wy + 1): m |= 4
		if _joins(base, wx - 1, wy): m |= 8
		_blit(tileset.pick("t_concrete", c), pos, mod)
		_blit(("t_wall_glass." if t == 10 else "t_wall.") + str(m), pos, mod)
		return
	if own and (t == 4 or t == 22):
		var vert: bool = _joins(base, wx, wy - 1) and _joins(base, wx, wy + 1) and not (_joins(base, wx - 1, wy) and _joins(base, wx + 1, wy))
		_blit(tileset.pick("t_floor", c), pos, mod)
		_blit(String(TERRAIN[t]) + (".v" if vert else ""), pos, mod)
		return
	if t == 14 and own:
		var mk: int = game.city.marks[c] if ground and c < game.city.marks.size() else 5
		_blit(String(TERRAIN[t]) + (".v" if mk == 6 else ""), pos, mod)
		return
	if t >= 23 and t <= 25:
		_blit(TERRAIN[0], pos, mod)
		if not _blit(tileset.pick(TERRAIN[t], c), pos, mod):
			draw_rect(Rect2(pos + Vector2(4, 4) * S, Vector2(T - 8 * S, T - 8 * S)), Color(0.5, 0.4, 0.25) * mod)
		return
	if t == 29:
		_blit(tileset.pick(TERRAIN[6], c), pos, mod)
		_blit(tileset.pick(TERRAIN[t], c), pos, mod)
		return
	if t == 1 and not tileset.variants.has("t_pavement"):
		draw_rect(Rect2(pos, Vector2(T, T)), Color(0.13, 0.13, 0.15) * mod)
		if ((c * 7919) >> 3) % 11 == 0:
			draw_rect(Rect2(pos.x + ((c % 5) * 5 + 3) * S, pos.y + ((c % 7) * 4 + 3) * S, 2 * S, 2 * S), Color(0.2, 0.2, 0.23) * mod)
	elif not _blit(tileset.pick(TERRAIN[t], c), pos, mod):
		draw_rect(Rect2(pos, Vector2(T, T)), _fallback(t) * mod)
	if ground:
		_paint_marks(c, pos, T, mod, t)

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
						_blit(tileset.pick(TERRAIN[6], wy * 4099 + wx), opos, DARK)
					if not _blit(tileset.pick(TERRAIN[ot], wy * 4099 + wx), opos, DARK):
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
					_blit(tileset.pick(TERRAIN[bt], c), pos, mod * below_mod)
				continue
			if t >= CG.EXTRA0:
				if t >= CG.EXTRA0 + 9:      # furniture stands on a floor
					var under_t: int = game.city.under[c] if c < game.city.under.size() else 3
					if under_t >= CG.EXTRA0:
						_blit(tileset.pick(String(CG.TILE_SPRITE.get(under_t, "t_floor")), c), pos, mod)
					else:
						_blit(tileset.pick(String(TERRAIN.get(under_t, "t_floor")), c), pos, mod)
				if not _blit(tileset.pick(String(CG.TILE_SPRITE.get(t, "")), c), pos, mod):
					draw_rect(Rect2(pos + Vector2(4, 4) * S, Vector2(T - 8 * S, T - 8 * S)), Color(0.5, 0.4, 0.25) * mod)
			else:
				_cell_art(t, c, wx, wy, pos, mod, c < s2)
			if vis and game.items_at.has(c):
				var arr: Array = game.items_at[c]
				_blit(item_sprite(arr[arr.size() - 1]), pos)
	# the trains
	if game.transit.active():
		for tc in game.transit.all_cars():
			var c: int = tc[2]
			if c / s2 != base / s2:
				continue
			var wx: int = c % size - ox
			var wy: int = (c / size) % size - oy
			if wx < 0 or wy < 0 or wx >= cols or wy >= rows or game.fov.visible[c] != 1:
				continue
			_draw_train_car(Vector2(wx * T, wy * T), game.transit.car_dir(tc[0], tc[1]), int(tc[1]) == 0, int(tc[0]))
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
			draw_rect(Rect2(tx * T + 6 * S, ty * T + 6 * S, T - 12 * S, T - 12 * S), Color(0.6, 0.45, 0.25))
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
			draw_string(font, Vector2(kx * T + T * 0.3, ky * T + T * 0.7), "d" if k["k"] == "dog" else "c", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.9, 0.7, 0.4))
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
		if not doll_ready():
			_blit(person_sprite(i), pos)
		var fd: Array = game.DIR8[int(game.face[i]) % 8]
		_draw_doll(DS.for_person(game, i), pos, Vector2i(fd[0], fd[1]))
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
				4, 5: glyph = "$"; col = Color(1, 0.7, 0.3)
				6: glyph = "+"; col = Color(0.4, 1, 0.8)
				7, 8: glyph = "^"; col = Color(0.9, 0.85, 1)
		if glyph != "":
			draw_string(font, pos + Vector2(T * 0.3, -2 * S), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
		elif game.meter[i] > 0 and game.astate[i] == 0:
			draw_rect(Rect2(pos.x + 4 * S, pos.y - 2 * S, (T - 8 * S) * game.meter[i] / 100.0, 3 * S), Color(1, 0.9, 0.2))
	# the player
	var centre := Vector2((px - ox) * T, (py - oy) * T)
	if game.in_vehicle >= 0:
		draw_circle(centre + Vector2(T / 2.0, T / 2.0), T * 0.22, Color(0.95, 0.8, 0.65))
		draw_arc(centre + Vector2(T / 2.0, T / 2.0), T * 0.22, PI, TAU, 12, Color(0.15, 0.1, 0.1), 3.0 * S)
	elif game.transit.riding < 0:
		if game.flying:
			draw_circle(centre + Vector2(T / 2.0, T * 0.9), T * 0.28, Color(0, 0, 0, 0.35))
			draw_circle(centre + Vector2(T / 2.0, T * 0.95), 5.0 * S, Color(1, 0.7, 0.2, 0.9))
		if not doll_ready():
			_blit("player_male", centre)
		_draw_doll(DS.for_player(game), centre, game.facing)
	else:
		_blit("player_male", centre, Color(1, 1, 1, 0.9))
	if game.in_vehicle < 0 and game.transit.riding < 0:
		_facing_mark(centre, game.DIR8.find([signi(game.facing.x), signi(game.facing.y)]), Color(0.3, 0.95, 1.0, 0.9))
	_draw_cranes(ox, oy, base)
	# the job target, if it is on this level
	if not game.eco.job.is_empty() and int(game.eco.job["cell"]) / s2 == base / s2:
		var jc: int = game.eco.job["cell"]
		var jr := Rect2((game.lx(jc) - ox) * T, (game.ly(jc) - oy) * T, T, T)
		draw_rect(jr, Color(1, 0.8, 0.2), false, 2.0 * S)
	# target bracket
	var tg: int = game.current_target()
	if tg >= 0:
		var c: int = game.sim.pos[tg]
		var r := Rect2((c % size - ox) * T, ((c / size) % size - oy) * T, T, T)
		draw_rect(r, Color(1, 0.2, 0.2), false, 2.0 * S)
		if game.aim_turns > 0:
			draw_rect(r.grow(3 * S), Color(1, 0.6, 0.2), false, 1.0 * S)
	# tracers from the last volley
	for tr in game.tracers:
		var a: int = tr[0]
		var b: int = tr[1]
		var pa := Vector2((a % size - ox + 0.5) * T, ((a / size) % size - oy + 0.5) * T)
		var pb := Vector2((b % size - ox + 0.5) * T, ((b / size) % size - oy + 0.5) * T)
		draw_line(pa, pb, Color(1, 0.95, 0.5) if tr[2] else Color(0.8, 0.8, 0.8, 0.6), 2.0 * S)
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.5, 1.5))
	var W: float = float(cols * tile()) / 1.5
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
	if _draw_body_sprite(vi, v, ox, oy, T):
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
			draw_rect(Rect2(px + 4 * S, py + T * 0.55, T, T), shade)
		draw_rect(r, cc)
		# panel seams
		match ch:
			"E":
				for k in 3:
					var gx: float = px + 6 * S + k * (T - 12 * S) / 2.0
					if dirn % 2 == 0:
						draw_line(Vector2(gx, py + 5 * S), Vector2(gx, py + T - 5 * S), cc.darkened(0.4), 2.0 * S)
					else:
						draw_line(Vector2(px + 5 * S, py + 6 * S + k * (T - 12 * S) / 2.0), Vector2(px + T - 5 * S, py + 6 * S + k * (T - 12 * S) / 2.0), cc.darkened(0.4), 2.0 * S)
			"T":
				draw_rect(r.grow(-6 * S), cc.darkened(0.12), false, 1.5 * S)
			"C":
				draw_rect(r.grow(-5 * S), Color(0.28, 0.33, 0.42))
			"W":
				var wr := Rect2(px + 6 * S, py + 3 * S, T - 12 * S, T - 6 * S) if dirn % 2 == 0 else Rect2(px + 3 * S, py + 6 * S, T - 6 * S, T - 12 * S)
				draw_rect(wr, Color(0.06, 0.06, 0.07))
			"L":
				draw_rect(r.grow(-7 * S), Color(0.15, 0.16, 0.19))
			"P":
				draw_line(Vector2(px + 3 * S, py + 3 * S), Vector2(px + T - 3 * S, py + T - 3 * S), cc.darkened(0.25), 1.0 * S)
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
				draw_line(e0, e1, Color(0, 0, 0, 0.8), 2.0 * S)
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
				draw_circle(Vector2(px, py) + Vector2(T / 2.0, T / 2.0) + Vector2(front) * (T * 0.32), 3.5 * S, Color(1, 1, 0.75))
			elif f_axis == minf and ch == "T":
				draw_circle(Vector2(px, py) + Vector2(T / 2.0, T / 2.0) - Vector2(front) * (T * 0.32), 3.0 * S, Color(0.9, 0.15, 0.15))
		# damage: cracks on tiles of a hurt part, smoke from a hurt engine
		var part: String = String(game.vs.PART_OF.get(ch, "body"))
		var pct: int = game.vs.part_pct(v, part)
		if pct < 55 and not wreck:
			draw_line(Vector2(px + 6 * S, py + 8 * S), Vector2(px + T * 0.55, py + T * 0.6), Color(0, 0, 0, 0.7), 1.5 * S)
			draw_line(Vector2(px + T * 0.55, py + T * 0.6), Vector2(px + T - 6 * S, py + T - 10 * S), Color(0, 0, 0, 0.7), 1.5 * S)
		if pct < 30 and ch == "E":
			draw_circle(Vector2(px + T * 0.5, py + T * 0.3), 6.0 * S, Color(0.15, 0.15, 0.15, 0.55))
			draw_circle(Vector2(px + T * 0.62, py), 8.0 * S, Color(0.2, 0.2, 0.2, 0.4))
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
				draw_line(Vector2(cx, cy) - Vector2(cos(aa), sin(aa)) * T * 3.0, Vector2(cx, cy) + Vector2(cos(aa), sin(aa)) * T * 3.0, Color(0.9, 0.92, 0.96, 0.75), 3.0 * S)
	if wreck:
		var ctr := Vector2((float(ax - ox) + 0.5) * T, (float(ay - oy) + 0.5) * T)
		draw_circle(ctr + Vector2(0, -T * 0.6), 9.0 * S, Color(0.15, 0.15, 0.15, 0.5))
		draw_circle(ctr + Vector2(T * 0.3, -T * 1.2), 12.0 * S, Color(0.2, 0.2, 0.2, 0.35))


## the harbor's gantry cranes: a beam across the quay road with a trolley that runs back and forth carrying a container
## one carriage of a train: a long body with a roof stripe, windows, a lit nose on the front car
const TRAIN_LIVERY := [Color(0.85, 0.2, 0.35), Color(0.2, 0.62, 0.85), Color(0.9, 0.7, 0.2)]
func _draw_train_car(p: Vector2, dir: Vector2i, front: bool, train: int) -> void:
	var T: float = float(TILE)
	var horiz: bool = absi(dir.x) >= absi(dir.y)
	var body := Rect2(p + Vector2(0, 5 * S), Vector2(T, T - 10 * S)) if horiz else Rect2(p + Vector2(5 * S, 0), Vector2(T - 10 * S, T))
	var col: Color = TRAIN_LIVERY[train % TRAIN_LIVERY.size()]
	draw_rect(body.grow(1.5 * S), Color(0.05, 0.06, 0.09))
	draw_rect(body, Color(0.78, 0.8, 0.86))
	var stripe := Rect2(body.position + (Vector2(0, body.size.y * 0.62) if horiz else Vector2(body.size.x * 0.62, 0)), Vector2(body.size.x, 5 * S) if horiz else Vector2(5 * S, body.size.y))
	draw_rect(stripe, col)
	var n := 3
	for k in n:
		var wr: Rect2
		if horiz:
			wr = Rect2(body.position + Vector2((k + 0.3) * T / n, 5 * S), Vector2(T / n * 0.5, body.size.y * 0.3))
		else:
			wr = Rect2(body.position + Vector2(5 * S, (k + 0.3) * T / n), Vector2(body.size.x * 0.3, T / n * 0.5))
		draw_rect(wr, Color(0.15, 0.25, 0.4))
		draw_rect(Rect2(wr.position, wr.size * Vector2(1, 0.35) if horiz else wr.size * Vector2(0.35, 1)), Color(0.45, 0.7, 0.9))
	if front:
		var nose: Vector2 = p + Vector2(T, T) * 0.5 + Vector2(dir) * (T * 0.42)
		draw_circle(nose, 4.0 * S, Color(1, 0.95, 0.6))
		draw_circle(nose, 8.0 * S, Color(1, 0.95, 0.6, 0.25))

func _draw_cranes(ox: int, oy: int, base: int) -> void:
	if base != 0 or game.city.cranes.is_empty():
		return
	var T := TILE
	var turn_f: float = float(game.turn) * 0.045
	for k in game.city.cranes.size():
		var cr: Dictionary = game.city.cranes[k]
		var cy: int = int(cr["y"]) - oy
		if cy < -2 or cy > rows + 1:
			continue
		var x0: int = int(cr["x0"])
		var x1: int = int(cr["x1"])
		if x1 - ox < -1 or x0 - ox > cols:
			continue
		for x in range(x0 + 1, x1):
			var sx: int = x - ox
			if sx >= 0 and sx < cols:
				_blit("f_trl_crane_beam", Vector2(sx * T, cy * T))
		var u: float = 0.5 + 0.5 * sin(turn_f + float(k) * 1.7)
		var tx: float = (float(x0 + 1) + u * float(x1 - x0 - 2) - float(ox)) * T
		var carrying: bool = cos(turn_f + float(k) * 1.7) > 0.0
		if carrying and tileset.has("f_trl_container.0"):
			var sp: Array = tileset.sprite("f_trl_container." + str(k % 4))
			if not sp.is_empty():
				var r: Rect2 = sp[1]
				draw_texture_rect_region(sp[0], Rect2(Vector2(tx + 8, cy * T + 12), r.size * 0.8), r, Color(1, 1, 1, 0.95))
		_blit("f_trl_crane_trolley", Vector2(tx, cy * T))


var veh_tex: Dictionary = {}
const HELI_MAST := Vector2(0, -70)     # where the helicopter's rotor mast is, in sprite pixels from the middle of the body

func _veh_tex(kind: String, layer: String):
	var key := "veh_%s_%s" % [kind, layer]
	if not veh_tex.has(key):
		veh_tex[key] = tileset._load_tex("res://gfx/Trilobit64/veh/%s.png" % key) if tileset != null and tileset.has("t_trl_marble") else null
	return veh_tex[key]

## the painted vehicle: shadow/wheels, the tinted paint, glass and lights; the whole stack is turned to the vehicle's heading
func _draw_body_sprite(vi: int, v: Dictionary, ox: int, oy: int, T: int) -> bool:
	var kind: String = v["kind"]
	var tu = _veh_tex(kind, "u")
	var tp = _veh_tex(kind, "p")
	var to = _veh_tex(kind, "o")
	if tu == null or tp == null or to == null:
		return false
	var dirn: int = int(v["dir"])
	var wreck: bool = v["wreck"]
	var c2: Vector2i = game.vs.center2(kind, int(v["cell"]), dirn)
	var ctr := Vector2((float(c2.x) * 0.5 - float(ox)) * T, (float(c2.y) * 0.5 - float(oy)) * T)
	var k: float = float(T) / 64.0
	var tint: Color = Color(0.32, 0.30, 0.30) if wreck else (v["color"] as Color) * 1.12
	tint.a = 1.0
	var plain := Color(0.34, 0.32, 0.32) if wreck else Color.WHITE
	var airborne: bool = bool(v.get("air", false))
	if airborne:
		draw_set_transform(ctr + Vector2(10, 24) * k, float(dirn) * PI / 2.0, Vector2(k, k))
		draw_texture(tu, -tu.get_size() * 0.5, Color(0, 0, 0, 0.35))
	draw_set_transform(ctr, float(dirn) * PI / 2.0, Vector2(k, k))
	draw_texture(tu, -tu.get_size() * 0.5, plain)
	draw_texture(tp, -tp.get_size() * 0.5, tint)
	draw_texture(to, -to.get_size() * 0.5, plain)
	# damage: soot over the paint and smoke from a hurt engine
	var body_pct: int = game.vs.part_pct(v, "body")
	if body_pct < 55 and not wreck:
		draw_texture(tp, -tp.get_size() * 0.5, Color(0, 0, 0, 0.35))
	if kind == "heli" and not wreck:
		var ang: float = float(game.turn) * 0.9
		var r := 3.3 * 64.0
		draw_circle(HELI_MAST, r, Color(1, 1, 1, 0.05))
		for b in 2:
			var aa: float = ang + float(b) * PI / 2.0
			var d := Vector2(cos(aa), sin(aa)) * r
			draw_line(HELI_MAST - d, HELI_MAST + d, Color(0.1, 0.11, 0.13, 0.55), 9.0)
			draw_line(HELI_MAST - d, HELI_MAST + d, Color(0.85, 0.88, 0.93, 0.55), 5.0)
		draw_circle(HELI_MAST, 12.0, Color(0.18, 0.2, 0.24))
		draw_circle(HELI_MAST, 6.0, Color(0.6, 0.63, 0.68))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if wreck or game.vs.part_pct(v, "engine") < 30:
		draw_circle(ctr + Vector2(0, -T * 0.6), 9.0 * S, Color(0.15, 0.15, 0.15, 0.5))
		draw_circle(ctr + Vector2(T * 0.3, -T * 1.2), 12.0 * S, Color(0.2, 0.2, 0.2, 0.35))
	return true
