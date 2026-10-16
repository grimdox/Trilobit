extends Control
## Full-screen menus drawn in code: the title screen, pause menu, options, key bindings, save slots and the implants body map.
## main.gd owns the state (kind, items, selection) and keys; this only draws.
const IMP = preload("res://src/implants.gd")
var kind: String = "title"
var title: String = ""
var subtitle: String = ""
var items: Array = []              # [{label, value, disabled}]
var sel: int = 0
var scroll: int = 0
var footer: String = ""
var overlay: bool = false          # dim the game behind instead of the title backdrop
var prompt: String = ""            # "Press a key..." while rebinding
var game                           # for the implants screen
var part_sel: int = 0
var world = null
var map_tex: ImageTexture = null
var ow_tex: Texture2D = null
var font: Font = ThemeDB.fallback_font
var kana_font: Font = load("res://gfx/fonts/NotoSansJP-kana-subset.otf")
var loading: bool = false          # the loading screen shows the name in hiragana
var t: float = 0.0
var skyline: Array = []

const CYAN := Color(0.3, 0.9, 1.0)
const MAGENTA := Color(1.0, 0.25, 0.65)
const BG := Color(0.03, 0.04, 0.08)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var x := 0.0
	while x < 1400.0:
		var w := r.randf_range(30.0, 90.0)
		skyline.append(Rect2(x, 0, w, r.randf_range(90.0, 330.0)))
		x += w + r.randf_range(0.0, 14.0)

func _process(delta: float) -> void:
	t += delta
	if visible:
		queue_redraw()

func _txt(s: String, pos: Vector2, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(font, pos, s, align, width, size, col)

func _draw() -> void:
	var W: float = size.x if size.x > 0 else 1280.0
	var H: float = size.y if size.y > 0 else 720.0
	if kind == "implants" or kind == "map":
		draw_rect(Rect2(0, 0, W, H), BG)
	elif overlay:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.72))
	else:
		_backdrop(W, H)
	match kind:
		"implants":
			_implants(W, H)
		"map":
			_map(W, H)
		"title":
			_title(W, H)
		_:
			_menu(W, H)

func _backdrop(W: float, H: float) -> void:
	draw_rect(Rect2(0, 0, W, H), BG)
	for i in 24:
		var u := float(i) / 24.0
		draw_rect(Rect2(0, H * 0.35 + u * H * 0.65, W, H * 0.65 / 24.0 + 1), Color(0.25 * u, 0.04 + 0.05 * u, 0.2 * u + 0.05, 0.55))
	for k in skyline.size():
		var b: Rect2 = skyline[k]
		var top := H - b.size.y - 40.0
		draw_rect(Rect2(b.position.x, top, b.size.x, H - top), Color(0.02, 0.025, 0.05))
		draw_rect(Rect2(b.position.x, top, b.size.x, 2), Color(0.2, 0.6, 0.8, 0.5))
		var wy := top + 10.0
		var seedk := k * 7
		while wy < H - 20.0:
			var wx := b.position.x + 6.0
			while wx < b.position.x + b.size.x - 8.0:
				seedk += 13
				if (seedk * 31) % 7 < 2:
					var flick := 0.55 + 0.45 * sin(t * (0.6 + float(seedk % 5) * 0.2) + seedk)
					draw_rect(Rect2(wx, wy, 4, 5), Color(1.0, 0.8, 0.35, 0.5 * flick) if seedk % 3 != 0 else Color(0.3, 0.9, 1.0, 0.5 * flick))
				wx += 9.0
			wy += 12.0
	for y in range(0, int(H), 4):
		draw_rect(Rect2(0, y, W, 1), Color(0, 0, 0, 0.18))

func _title(W: float, H: float) -> void:
	var glow := 0.75 + 0.25 * sin(t * 2.0)
	var name_txt := "とりろびつ" if loading else "TRILOBIT"
	var f: Font = kana_font if (loading and kana_font != null) else font
	draw_string(f, Vector2(0, 150), name_txt, HORIZONTAL_ALIGNMENT_CENTER, W, 96, Color(1.0, 0.25, 0.65, 0.35 * glow))
	draw_string(f, Vector2(3, 147), name_txt, HORIZONTAL_ALIGNMENT_CENTER, W, 96, CYAN)
	draw_string(f, Vector2(0, 150), name_txt, HORIZONTAL_ALIGNMENT_CENTER, W, 96, Color(0.9, 0.97, 1.0))
	if subtitle != "":
		_txt(subtitle, Vector2(0, 190), 20, Color(0.7, 0.85, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER, W)
	var y := 290.0
	for i in items.size():
		var it: Dictionary = items[i]
		var on: bool = i == sel
		var col := Color(0.55, 0.6, 0.7) if it.get("disabled", false) else (Color.WHITE if on else Color(0.62, 0.78, 0.9))
		if on:
			draw_rect(Rect2(W * 0.5 - 170, y - 32, 340, 44), Color(0.3, 0.9, 1.0, 0.16))
			draw_rect(Rect2(W * 0.5 - 170, y - 32, 4, 44), CYAN)
			draw_rect(Rect2(W * 0.5 + 166, y - 32, 4, 44), CYAN)
		_txt(it["label"], Vector2(0, y), 30, col, HORIZONTAL_ALIGNMENT_CENTER, W)
		y += 56.0
	_txt(footer, Vector2(0, H - 28), 15, Color(0.6, 0.7, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)

## Which menu row is under the mouse (-1 for none). Mirrors the layout in _title and _menu.
func item_at_mouse(p: Vector2) -> int:
	var W: float = size.x if size.x > 0 else 1280.0
	var H: float = size.y if size.y > 0 else 720.0
	if kind == "title":
		for i in items.size():
			var y := 290.0 + 56.0 * i
			if Rect2(W * 0.5 - 170, y - 32, 340, 44).has_point(p):
				return i
		return -1
	if kind == "implants" or kind == "map":
		return -1
	var bw := 760.0
	var rows := 14
	var bh := 150.0 + rows * 34.0
	var x0 := (W - bw) * 0.5
	var y0 := (H - bh) * 0.5
	for k in mini(rows, items.size() - scroll):
		var y := y0 + 118.0 + 34.0 * k
		if Rect2(x0 + 14, y - 24, bw - 28, 32).has_point(p):
			return scroll + k
	return -1

func _menu(W: float, H: float) -> void:
	var bw := 760.0
	var rows := 14
	var bh := 150.0 + rows * 34.0
	var x0 := (W - bw) * 0.5
	var y0 := (H - bh) * 0.5
	draw_rect(Rect2(x0, y0, bw, bh), Color(0.04, 0.06, 0.11, 0.96))
	draw_rect(Rect2(x0, y0, bw, bh), CYAN, false, 2.0)
	draw_rect(Rect2(x0, y0, bw, 4), MAGENTA)
	_txt(title, Vector2(x0 + 28, y0 + 48), 34, Color.WHITE)
	if subtitle != "":
		_txt(subtitle, Vector2(x0 + 28, y0 + 76), 16, Color(0.6, 0.75, 0.9))
	var y := y0 + 118.0
	var shown := mini(rows, items.size() - scroll)
	for k in shown:
		var i := scroll + k
		var it: Dictionary = items[i]
		var on := i == sel
		if on:
			draw_rect(Rect2(x0 + 14, y - 24, bw - 28, 32), Color(0.3, 0.9, 1.0, 0.16))
			draw_rect(Rect2(x0 + 14, y - 24, 4, 32), CYAN)
		var col := Color(0.5, 0.55, 0.62) if it.get("disabled", false) else (Color.WHITE if on else Color(0.72, 0.84, 0.95))
		_txt(it["label"], Vector2(x0 + 34, y), 22, col)
		if it.has("value"):
			_txt(str(it["value"]), Vector2(x0 + bw * 0.47, y), 22, CYAN if on else Color(0.55, 0.8, 0.95))
		y += 34.0
	if scroll > 0:
		_txt("^ more", Vector2(x0 + bw - 100, y0 + 100), 14, Color(0.6, 0.7, 0.8))
	if scroll + rows < items.size():
		_txt("v more", Vector2(x0 + bw - 100, y0 + bh - 40), 14, Color(0.6, 0.7, 0.8))
	if prompt != "":
		draw_rect(Rect2(x0 + 60, y0 + bh * 0.5 - 40, bw - 120, 80), Color(0.02, 0.03, 0.06, 0.98))
		draw_rect(Rect2(x0 + 60, y0 + bh * 0.5 - 40, bw - 120, 80), MAGENTA, false, 2.0)
		_txt(prompt, Vector2(x0 + 60, y0 + bh * 0.5 + 8), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bw - 120)
	_txt(footer, Vector2(x0 + 28, y0 + bh - 14), 15, Color(0.6, 0.7, 0.8))

# ---------------------------------------------------------------- the implants body map
func part_screen_pos(part: Dictionary, r: Rect2) -> Vector2:
	var a: Vector2 = part["at"]
	return r.position + Vector2(a.x * r.size.x, a.y * r.size.y)

func _body_rect(W: float, H: float) -> Rect2:
	return Rect2(60, 60, 470, H - 110)

func part_at_mouse(p: Vector2) -> int:
	var r := _body_rect(size.x, size.y)
	var best := -1
	var bd := 46.0
	for i in IMP.PARTS.size():
		var d := part_screen_pos(IMP.PARTS[i], r).distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best

func _implants(W: float, H: float) -> void:
	var r := _body_rect(W, H)
	# blueprint grid
	for gx in range(0, int(W), 32):
		draw_line(Vector2(gx, 0), Vector2(gx, H), Color(0.3, 0.9, 1.0, 0.05))
	for gy in range(0, int(H), 32):
		draw_line(Vector2(0, gy), Vector2(W, gy), Color(0.3, 0.9, 1.0, 0.05))
	_txt("IMPLANTS", Vector2(560, 56), 34, Color.WHITE)
	_txt("Up / Down chooses a body part  -  Esc closes", Vector2(560, 82), 16, Color(0.6, 0.75, 0.9))
	var lc := Color(0.3, 0.9, 1.0, 0.8)
	var cx := r.position.x + r.size.x * 0.5
	var cy := r.position.y + r.size.y * 0.42
	# the Vitruvian circle and square
	draw_arc(Vector2(cx, cy), r.size.x * 0.46, 0, TAU, 96, Color(0.3, 0.9, 1.0, 0.35), 1.5)
	var sq := r.size.x * 0.46
	draw_rect(Rect2(cx - sq, r.position.y + 10, sq * 2.0, r.size.y - 20), Color(0.3, 0.9, 1.0, 0.25), false, 1.5)
	var P := func(u: float, v: float) -> Vector2: return r.position + Vector2(u * r.size.x, v * r.size.y)
	# head
	draw_arc(P.call(0.5, 0.115), r.size.x * 0.07, 0, TAU, 32, lc, 2.0)
	draw_line(P.call(0.5, 0.17), P.call(0.5, 0.2), lc, 2.0)
	# torso
	var torso := PackedVector2Array([P.call(0.37, 0.2), P.call(0.63, 0.2), P.call(0.58, 0.5), P.call(0.42, 0.5), P.call(0.37, 0.2)])
	draw_polyline(torso, lc, 2.0)
	draw_line(P.call(0.5, 0.2), P.call(0.5, 0.5), Color(0.3, 0.9, 1.0, 0.3), 1.0)     # spine
	for k in 6:
		var yy := 0.23 + 0.04 * k
		draw_line(P.call(0.44, yy), P.call(0.56, yy), Color(0.3, 0.9, 1.0, 0.2), 1.0)  # ribs
	# arms: outstretched
	draw_polyline(PackedVector2Array([P.call(0.37, 0.21), P.call(0.24, 0.3), P.call(0.13, 0.4), P.call(0.1, 0.47)]), lc, 2.0)
	draw_polyline(PackedVector2Array([P.call(0.63, 0.21), P.call(0.76, 0.3), P.call(0.87, 0.4), P.call(0.9, 0.47)]), lc, 2.0)
	# pelvis and legs
	draw_polyline(PackedVector2Array([P.call(0.42, 0.5), P.call(0.36, 0.72), P.call(0.34, 0.93)]), lc, 2.0)
	draw_polyline(PackedVector2Array([P.call(0.58, 0.5), P.call(0.64, 0.72), P.call(0.66, 0.93)]), lc, 2.0)
	draw_line(P.call(0.42, 0.5), P.call(0.58, 0.5), lc, 2.0)
	# the part markers
	for i in IMP.PARTS.size():
		var part: Dictionary = IMP.PARTS[i]
		var pp := part_screen_pos(part, r)
		var list: Array = IMP.for_part(part["id"])
		var inst := 0
		for d in list:
			if game != null and game.has_implant(d["id"]):
				inst += 1
		var on := i == part_sel
		var col := Color(1.0, 0.8, 0.25) if inst > 0 else Color(0.3, 0.9, 1.0)
		if on:
			var pulse := 0.5 + 0.5 * sin(t * 5.0)
			draw_circle(pp, 26.0 + 4.0 * pulse, Color(col.r, col.g, col.b, 0.18))
			draw_arc(pp, 22.0, 0, TAU, 32, MAGENTA, 2.5)
			draw_line(pp + Vector2(22, 0), Vector2(545, pp.y), Color(1.0, 0.25, 0.65, 0.6), 1.5)
		draw_circle(pp, 7.0, col)
		draw_arc(pp, 11.0, 0, TAU, 24, Color(col.r, col.g, col.b, 0.6), 1.5)
		if inst > 0:
			_txt("%d" % inst, pp + Vector2(12, -10), 16, col)
	# the detail panel
	var part: Dictionary = IMP.PARTS[part_sel]
	var px := 560.0
	var py := 120.0
	draw_rect(Rect2(px, py, W - px - 40, H - py - 60), Color(0.04, 0.06, 0.11, 0.9))
	draw_rect(Rect2(px, py, W - px - 40, H - py - 60), CYAN, false, 1.5)
	draw_rect(Rect2(px, py, W - px - 40, 4), MAGENTA)
	_txt(part["name"].to_upper(), Vector2(px + 20, py + 44), 28, Color.WHITE)
	var y := py + 90.0
	for d in IMP.for_part(part["id"]):
		var fitted: bool = game != null and game.implants.get(d["id"], false)
		var have: bool = fitted
		var status := "INSTALLED" if have else ("available - ripperdocs" if d["live"] else "not yet available")
		status = "grade %d   " % int(d.get("grade", 1)) + status
		if fitted and not game.has_implant(d["id"]):
			status = "OFFLINE - the %s is disabled" % game.BODY.PART_GROUP.get(d["part"], "limb")
		elif fitted and d.has("armor"):
			status += "   armor %d  (plating %d/%d)" % [int(d["armor"]), int(game.imp_dur.get(d["id"], int(d["dur"]))), int(d["dur"])]
		elif d.has("armor"):
			status += "   armor %d" % int(d["armor"])
		var col := Color(1.0, 0.8, 0.25) if have else (Color(0.5, 1.0, 0.7) if d["live"] else Color(0.55, 0.6, 0.68))
		draw_rect(Rect2(px + 16, y - 26, W - px - 72, 92), Color(1, 1, 1, 0.04))
		_txt(d["name"], Vector2(px + 28, y), 24, Color.WHITE if (have or d["live"]) else Color(0.7, 0.75, 0.82))
		_txt(status, Vector2(px + 28, y + 26), 17, col)
		_txt(d["desc"], Vector2(px + 28, y + 52), 16, Color(0.7, 0.82, 0.92))
		if d["live"] and not have:
			_txt("from ¥%d" % IMP.price(d["id"], true), Vector2(W - 190, y), 18, col)
		y += 108.0
	# overall tally
	var total_have := 0
	for d in IMP.ALL:
		if game != null and game.implants.get(d["id"], false):
			total_have += 1
	_txt("%d of %d implants fitted" % [total_have, IMP.ALL.size()], Vector2(px + 20, H - 78), 16, Color(0.6, 0.75, 0.9))

# ---------------------------------------------------------------- the island map
func _map(W: float, H: float) -> void:
	var cyan := Color(0.3, 0.9, 1.0)
	draw_string(font, Vector2(24, 34), "ISLAND MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, cyan)
	if world == null or map_tex == null:
		draw_string(font, Vector2(24, 80), "No chart of this place.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		return
	var isl = world.island
	if ow_tex == null:
		ow_tex = load("res://gfx/overworld.png") as Texture2D
	var ow: Texture2D = ow_tex
	var iw: float = 1680.0
	var ih: float = 1050.0
	var sc: float = minf((W - 48.0) / iw, (H - 90.0) / ih)
	var ox: float = (W - iw * sc) * 0.5
	var oy := 48.0
	if ow != null:
		draw_texture_rect(ow, Rect2(ox, oy, iw * sc, ih * sc), false)
	else:
		draw_texture_rect(map_tex, Rect2(ox, oy, float(isl.W) * sc * iw / float(isl.W), ih * sc), false)
	# the drawn map is not to scale: island coordinates are matched to it by landmarks (port, city, town, coasts)
	var gx_a := [0.0, 215.0, 704.0, 1152.0, 2304.0]
	var ix_a := [0.0, 195.0, 640.0, 967.0, 1680.0]
	var gy_a := [0.0, 704.0, 1408.0]
	var iy_a := [0.0, 548.0, 1050.0]
	var P := func(gx: float, gy: float) -> Vector2:
		return Vector2(ox + _pw(gx_a, ix_a, gx) * sc, oy + _pw(gy_a, iy_a, gy) * sc)
	# unexplored zones sit under a haze; the grid shows the zones
	for zx in isl.NZX:
		for zy in isl.NZY:
			var o: Vector2i = isl.zone_origin(zx, zy)
			var a0: Vector2 = P.call(float(o.x + isl.OWN_INSET), float(o.y + isl.OWN_INSET))
			var a1: Vector2 = P.call(float(o.x + isl.OWN_INSET + isl.STRIDE), float(o.y + isl.OWN_INSET + isl.STRIDE))
			if zx == 0:
				a0.x = ox
			if zy == 0:
				a0.y = oy
			var own := Rect2(a0, a1 - a0).intersection(Rect2(ox, oy, iw * sc, ih * sc))
			var vis: bool = world.visited.has(world.key(Vector2i(zx, zy)))
			if not vis:
				draw_rect(own, Color(0.02, 0.03, 0.08, 0.35))
			draw_rect(own, Color(1, 1, 1, 0.08), false, 1.0)
	# you are here
	if game != null and game.island != null:
		var gp: Vector2i = game.global_pos()
		var pp: Vector2 = P.call(float(gp.x), float(gp.y))
		var pulse: float = 0.5 + 0.5 * sin(t * 6.0)
		draw_circle(pp, 9.0 + 4.0 * pulse, Color(1.0, 0.2, 0.5, 0.25 + 0.2 * pulse))
		draw_arc(pp, 8.0, 0.0, TAU, 24, Color(1.0, 0.3, 0.6), 2.0)
		draw_circle(pp, 3.5, Color.WHITE)
		draw_line(pp + Vector2(-14, 0), pp + Vector2(14, 0), Color(1, 0.3, 0.6, 0.8), 1.0)
		draw_line(pp + Vector2(0, -14), pp + Vector2(0, 14), Color(1, 0.3, 0.6, 0.8), 1.0)
		draw_string(font, pp + Vector2(12, -12), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.4, 0.7))
		draw_string(font, Vector2(24, H - 14), "You are at (%d, %d) in %s.   M or Esc closes." % [gp.x, gp.y, isl.zone_name(game.zone)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.9, 1.0))

## piecewise-linear map of v through matching anchor lists
func _pw(from: Array, to: Array, v: float) -> float:
	for k in range(1, from.size()):
		if v <= from[k] or k == from.size() - 1:
			var f: float = (v - from[k - 1]) / (from[k] - from[k - 1])
			return lerpf(to[k - 1], to[k], f)
	return v
