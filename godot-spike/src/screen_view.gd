extends Control
## Full-screen menus drawn in code: the title screen, pause menu, options, key bindings, save slots and the implants body map.
## main.gd owns the state (kind, items, selection) and keys; this only draws.
const IMP = preload("res://src/implants.gd")
const SK = preload("res://src/skills.gd")
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
var sk_sel: int = 0                # the highlighted line of the attributes & skills screen (0-4 attributes, then the skills)
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
	if kind == "implants" or kind == "map" or kind == "skills":
		draw_rect(Rect2(0, 0, W, H), BG)
	elif overlay:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.72))
	else:
		_backdrop(W, H)
	match kind:
		"implants":
			_implants(W, H)
		"skills":
			_skills(W, H)
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
	var gx_a := [0.0, 215.0, 800.0, 1240.0, 2304.0]
	var ix_a := [0.0, 195.0, 640.0, 967.0, 1680.0]
	var gy_a := [0.0, 704.0, 1408.0]
	var iy_a := [0.0, 548.0, 1050.0]
	var P := func(gx: float, gy: float) -> Vector2:
		return Vector2(ox + _pw(gx_a, ix_a, gx) * sc, oy + _pw(gy_a, iy_a, gy) * sc)
	# unexplored zones sit under a haze; the grid shows the zones
	for zx in isl.NZX:
		for zy in isl.NZY:
			var o: Vector2i = isl.zone_origin(zx, zy)
			var orc: Rect2i = isl.own_rect(zx, zy)
			var a0: Vector2 = P.call(float(orc.position.x), float(orc.position.y))
			var a1: Vector2 = P.call(float(orc.end.x), float(orc.end.y))
			if zx == 0:
				a0.x = ox
			if zy == 0:
				a0.y = oy
			var own := Rect2(a0, a1 - a0).intersection(Rect2(ox, oy, iw * sc, ih * sc))
			var vis: bool = world.visited.has(world.key(Vector2i(zx, zy)))
			if not vis:
				draw_rect(own, Color(0.02, 0.03, 0.08, 0.35))
			draw_rect(own, Color(1, 1, 1, 0.08), false, 1.0)
	# the river and the highway, drawn over the chart (the picture predates them)
	var rpts := PackedVector2Array()
	for gy in range(isl.RIVER_Y0, isl.H, 24):
		rpts.append(P.call(float(isl.river_span(gy).x + isl.river_span(gy).y) * 0.5, float(gy)))
	if rpts.size() > 1:
		draw_polyline(rpts, Color(0.25, 0.6, 0.95, 0.9), maxf(2.0, 3.0 * sc))
	var hpts := PackedVector2Array()
	for gx in range(isl._hx0, isl.HWY_X1 + 1, 24):
		hpts.append(P.call(float(gx), float(isl.pass_yc(gx))))
	if hpts.size() > 1:
		draw_polyline(hpts, Color(1.0, 0.82, 0.3, 0.85), maxf(1.5, 2.0 * sc))
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


# ---------------------------------------------------------------- attributes and skills
## one line per attribute (0-4) then per skill, in the order of SK.SKILLS
func sk_entries() -> Array:
	var out: Array = []
	for a in SK.ATTRS:
		out.append({"kind": "attr", "id": a["id"]})
	for sd in SK.SKILLS:
		out.append({"kind": "skill", "id": sd["id"]})
	return out

const SK_TOP := 50.0
const SK_TOP_H := 158.0
const SK_ROW := 34.0

func sk_box_rect(group: int, W: float, H: float) -> Rect2:
	var y0: float = SK_TOP + SK_TOP_H + 10.0
	var bw: float = (W - 80.0 - 16.0) * 0.5
	var bh: float = (H - y0 - 34.0 - 12.0) * 0.5
	return Rect2(40.0 + (group % 2) * (bw + 16.0), y0 + (group / 2) * (bh + 12.0), bw, bh)

## the clickable rectangle of every entry, in the order of sk_entries()
func sk_rects(W: float, H: float) -> Array:
	var out: Array = []
	for k in SK.ATTRS.size():
		out.append(Rect2(52.0 + k * 108.0, SK_TOP + 52.0, 100.0, 70.0))
	for g in SK.GROUPS.size():
		var box := sk_box_rect(g, W, H)
		var rows: Array = SK.skills_in(SK.GROUPS[g])
		for r in rows.size():
			out.append(Rect2(box.position.x + 8.0, box.position.y + 40.0 + r * SK_ROW, box.size.x - 16.0, SK_ROW - 2.0))
	return out

func sk_at_mouse(p: Vector2) -> int:
	var W: float = size.x if size.x > 0 else 1280.0
	var H: float = size.y if size.y > 0 else 720.0
	var rects := sk_rects(W, H)
	for i in rects.size():
		if (rects[i] as Rect2).has_point(p):
			return i
	return -1

## move the highlight to the nearest line in a direction; false if there is none
func sk_move(dir: Vector2i) -> bool:
	var W: float = size.x if size.x > 0 else 1280.0
	var H: float = size.y if size.y > 0 else 720.0
	var rects := sk_rects(W, H)
	var c: Vector2 = (rects[sk_sel] as Rect2).get_center()
	var best := -1
	var bs := 1.0e9
	var band: float = 18.0 if dir.x != 0 else 40.0          # first look for a line in the same row (or column)
	for pass_i in 2:
		for i in rects.size():
			if i == sk_sel:
				continue
			var d: Vector2 = (rects[i] as Rect2).get_center() - c
			var along: float = d.x * dir.x + d.y * dir.y
			if along < 6.0:
				continue
			var across: float = absf(d.y) if dir.x != 0 else absf(d.x)
			if pass_i == 0 and across > band:
				continue
			var score: float = along + 3.0 * across
			if score < bs:
				bs = score
				best = i
		if best >= 0:
			break
	if best < 0:
		return false
	sk_sel = best
	return true

func _skills(W: float, H: float) -> void:
	for gx in range(0, int(W), 32):
		draw_line(Vector2(gx, 0), Vector2(gx, H), Color(0.3, 0.9, 1.0, 0.05))
	for gy in range(0, int(H), 32):
		draw_line(Vector2(0, gy), Vector2(W, gy), Color(0.3, 0.9, 1.0, 0.05))
	var entries := sk_entries()
	var rects := sk_rects(W, H)
	sk_sel = clampi(sk_sel, 0, entries.size() - 1)
	var sel: Dictionary = entries[sk_sel]
	var attrs: Dictionary = game.attrs if game != null else SK.default_attrs()
	var base: Dictionary = game.skills if game != null else SK.default_skills()
	var xps: Dictionary = game.xp if game != null else SK.default_skills()
	var gov: Array = []                                     # attributes governing the selected skill
	if sel["kind"] == "skill":
		gov = SK.skill(sel["id"])["attrs"]
	_txt("ATTRIBUTES & SKILLS", Vector2(40, 36), 30, Color.WHITE)
	_rtxt("Arrows / numpad / mouse choose  -  Esc closes", W - 40, 34, 15, Color(0.6, 0.75, 0.9))
	# the attribute box: one line, five attributes
	var abox := Rect2(40, SK_TOP + 8.0, 580, SK_TOP_H - 8.0)
	_panel(abox)
	_txt("ATTRIBUTES", Vector2(abox.position.x + 14, abox.position.y + 26), 16, CYAN)
	_rtxt("+1 to each skill it governs per 2 points over 10", abox.end.x - 14, abox.position.y + 26, 14, Color(0.6, 0.72, 0.85))
	for k in SK.ATTRS.size():
		var ad: Dictionary = SK.ATTRS[k]
		var r: Rect2 = rects[k]
		var on: bool = sk_sel == k
		var lit: bool = ad["id"] in gov
		draw_rect(r, Color(0.3, 0.9, 1.0, 0.2) if on else Color(1, 1, 1, 0.04))
		if on or lit:
			draw_rect(r, MAGENTA if on else Color(1.0, 0.8, 0.25), false, 2.0)
		_txt((ad["name"] as String).substr(0, 3).to_upper(), Vector2(r.position.x, r.position.y + 22), 16, Color(0.75, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var v: int = int(attrs.get(ad["id"], 10))
		_txt(str(v), Vector2(r.position.x, r.position.y + 56), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var bn: int = SK.attr_bonus(v)
		if bn > 0:
			_rtxt("+%d" % bn, r.end.x - 8, r.position.y + 20, 15, Color(1.0, 0.8, 0.25))
	# the detail box
	var dbox := Rect2(632, SK_TOP + 8.0, W - 632 - 40, SK_TOP_H - 8.0)
	_panel(dbox)
	_skill_detail(dbox, sel, attrs, base)
	# the four skill boxes
	for g in SK.GROUPS.size():
		var box := sk_box_rect(g, W, H)
		_panel(box)
		_txt((SK.GROUPS[g] as String).to_upper(), Vector2(box.position.x + 14, box.position.y + 26), 18, CYAN)
		var rows: Array = SK.skills_in(SK.GROUPS[g])
		for rr in rows.size():
			var sd: Dictionary = rows[rr]
			var idx: int = 5 + SK.skill_ids().find(sd["id"])
			var r: Rect2 = rects[idx]
			var on: bool = sk_sel == idx
			var lit: bool = sel["kind"] == "attr" and sel["id"] in sd["attrs"]
			if on:
				draw_rect(r, Color(0.3, 0.9, 1.0, 0.18))
				draw_rect(Rect2(r.position.x, r.position.y, 4, r.size.y), MAGENTA)
			elif lit:
				draw_rect(r, Color(1.0, 0.8, 0.25, 0.1))
			var col := Color.WHITE if sd["live"] else Color(0.55, 0.62, 0.72)
			var b: int = int(base.get(sd["id"], 0))
			var eff: int = SK.level(attrs, base, sd["id"])
			var ty: float = r.position.y + 22.0
			_txt(sd["name"], Vector2(r.position.x + 14, ty), 18, col)
			_txt(str(eff), Vector2(r.position.x + 170, ty), 22, Color(1.0, 0.8, 0.25) if eff > b else col, HORIZONTAL_ALIGNMENT_RIGHT, 40.0)
			var need: int = SK.xp_needed(b)
			var have: int = int(xps.get(sd["id"], 0))
			var bx: float = r.position.x + 226.0
			var bw: float = r.end.x - bx - 70.0
			draw_rect(Rect2(bx, ty - 12.0, bw, 10.0), Color(1, 1, 1, 0.1))
			var f: float = 1.0 if b >= SK.BASE_MAX else clampf(float(have) / float(need), 0.0, 1.0)
			draw_rect(Rect2(bx, ty - 12.0, bw * f, 10.0), CYAN if sd["live"] else Color(0.4, 0.5, 0.6))
			_rtxt("%d/%d" % [have, need] if b < SK.BASE_MAX else "max", r.end.x - 8.0, ty - 2.0, 14, Color(0.65, 0.78, 0.9))

## text whose right edge sits at right_x
func _rtxt(s: String, right_x: float, y: float, size_px: int, col: Color) -> void:
	var w: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(font, Vector2(right_x - w, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)

func _panel(r: Rect2) -> void:
	draw_rect(r, Color(0.04, 0.06, 0.11, 0.9))
	draw_rect(r, CYAN, false, 1.5)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3), MAGENTA)

func _skill_detail(r: Rect2, sel: Dictionary, attrs: Dictionary, base: Dictionary) -> void:
	var x: float = r.position.x + 14.0
	var y: float = r.position.y + 24.0
	var w: float = r.size.x - 28.0
	var dim := Color(0.7, 0.82, 0.92)
	if sel["kind"] == "attr":
		var ad: Dictionary = SK.attr(sel["id"])
		var v: int = int(attrs.get(ad["id"], 10))
		_txt("%s  %d" % [ad["name"].to_upper(), v], Vector2(x, y), 20, Color.WHITE)
		draw_multiline_string(font, Vector2(x, y + 22.0), ad["desc"], HORIZONTAL_ALIGNMENT_LEFT, w, 15, 2, dim)
		var names: Array = []
		for sd in SK.skills_of_attr(ad["id"]):
			names.append(sd["name"])
		draw_multiline_string(font, Vector2(x, y + 62.0), "Governs: " + ", ".join(names), HORIZONTAL_ALIGNMENT_LEFT, w, 14, 3, Color(1.0, 0.8, 0.25))
		return
	var sd: Dictionary = SK.skill(sel["id"])
	var b: int = int(base.get(sd["id"], 0))
	var eff: int = SK.level(attrs, base, sd["id"])
	var parts: Array = []
	for a in sd["attrs"]:
		parts.append("%s %d (+%d)" % [SK.attr(a)["name"], int(attrs.get(a, 10)), SK.attr_bonus(int(attrs.get(a, 10)))])
	_txt("%s   level %d" % [sd["name"].to_upper(), eff], Vector2(x, y), 20, Color.WHITE)
	_rtxt("base %d" % b, r.end.x - 14.0, y, 15, dim)
	draw_multiline_string(font, Vector2(x, y + 20.0), sd["desc"], HORIZONTAL_ALIGNMENT_LEFT, w, 14, 3, dim)
	_txt("Governed by: " + ", ".join(parts), Vector2(x, y + 80.0), 14, Color(1.0, 0.8, 0.25))
	var dl: Array = sd["disc"]
	var line: String = ""
	if dl.is_empty():
		line = "Disciplines: none"
	else:
		var bits: Array = []
		for d in dl:
			bits.append("%s%s (level %d)" % ["" if eff >= int(d["req"]) else "locked: ", d["name"], int(d["req"])])
		line = "Disciplines: " + "; ".join(bits)
	_txt(line, Vector2(x, y + 98.0), 14, Color(0.5, 1.0, 0.7) if (not dl.is_empty() and eff >= int(dl[0]["req"])) else dim)
	var note: String = sd["note"] if sd["live"] else "Not in play yet: " + sd["note"]
	_txt(note, Vector2(x, y + 116.0), 13, Color(0.6, 0.75, 0.9) if sd["live"] else Color(0.9, 0.55, 0.45))
