extends Node2D
## Draws the game around the player with a CDDA-format tileset: terrain, items, cars, people with awareness marks, a target bracket.
const CG = preload("res://src/citygen.gd")
var game
var tileset
var cols: int = 40
var rows: int = 19
var font: Font = ThemeDB.fallback_font

const TERRAIN := {0: "t_sidewalk", 1: "t_pavement", 2: "t_wall", 3: "t_floor", 4: "t_door_c", 5: "t_water_dp", 6: "t_grass"}
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

func _draw() -> void:
	if game == null or tileset == null:
		return
	var T := tile()
	var size: int = game.size
	var px: int = game.pc % size
	var py: int = game.pc / size
	var ox := px - cols / 2
	var oy := py - rows / 2
	for sy in rows:
		for sx in cols:
			var wx := ox + sx
			var wy := oy + sy
			if wx < 0 or wy < 0 or wx >= size or wy >= size:
				continue
			var c := wy * size + wx
			if game.fov.explored[c] == 0:
				continue
			var vis: bool = game.fov.visible[c] == 1
			var mod: Color = Color.WHITE if vis else DARK
			var pos := Vector2(sx * T, sy * T)
			_blit(TERRAIN[int(game.city.tiles[c])], pos, mod)
			if vis and game.items_at.has(c):
				var arr: Array = game.items_at[c]
				_blit(item_sprite(arr[arr.size() - 1]), pos)
	# vehicles
	for v in game.vehicles:
		var c: int = v["cell"]
		var wx: int = c % size - ox
		var wy: int = c / size - oy
		if wx < 0 or wy < 0 or wx >= cols or wy >= rows:
			continue
		if game.fov.visible[c] == 0:
			continue
		_draw_car(Vector2(wx * T + T / 2.0, wy * T + T / 2.0), int(v["dir"]), v["color"], T)
	# people
	for k in game.sim.near_list.size():
		var i: int = game.sim.near_list[k]
		var c: int = game.sim.pos[i]
		var wx: int = c % size - ox
		var wy: int = c / size - oy
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
		if glyph != "":
			draw_string(font, pos + Vector2(T * 0.3, -2), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		elif game.meter[i] > 0 and game.astate[i] == 0:
			draw_rect(Rect2(pos.x + 4, pos.y - 2, (T - 8) * game.meter[i] / 100.0, 3), Color(1, 0.9, 0.2))
	# the player
	var centre := Vector2((px - ox) * T, (py - oy) * T)
	if game.in_vehicle < 0:
		_blit("player_male", centre)
	else:
		_draw_car(centre + Vector2(T / 2.0, T / 2.0), int(game.vehicles[game.in_vehicle]["dir"]), game.vehicles[game.in_vehicle]["color"], T)
	# target bracket
	var tg: int = game.nearest_target()
	if tg >= 0:
		var c: int = game.sim.pos[tg]
		var r := Rect2((c % size - ox) * T, (c / size - oy) * T, T, T)
		draw_rect(r, Color(1, 0.2, 0.2), false, 2.0)

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
