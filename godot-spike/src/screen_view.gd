extends Control
## Full-screen menus drawn in code: the title screen, pause menu, options, key bindings, save slots and the implants body map.
## main.gd owns the state (kind, items, selection) and keys; this only draws.
const IMP = preload("res://src/implants.gd")
const SK = preload("res://src/skills.gd")
const CR = preload("res://src/creation.gd")
const DS = preload("res://src/dollspec.gd")
const FG = preload("res://src/figure.gd")
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
var cc: Dictionary = {}            # the character being made on the create screen: {app, attrs}
var cc_sel: int = 0                # the highlighted row of the create screen (see cc_row_rect)
var cc_tileset = null              # the 64px tileset, for the doll preview when the standing dolls are missing
var cc_fig = null                  # the standing-doll atlas, loaded when the creation screen first draws
var map_tex: ImageTexture = null
var font: Font = ThemeDB.fallback_font
var kana_font: Font = load("res://gfx/fonts/NotoSansJP-kana-subset.otf")
var loading: bool = false          # the loading screen shows the name in hiragana
var t: float = 0.0
var skyline: Array = []

const TITLE_NAME := "とりろびつ"      # the name in hiragana (to-ri-ro-bi-tsu), on the title screen and the loading screen alike
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

## the room a menu row gives its label and its value, in pixels: [label_room, value_room, value_x] for a box of width bw at x0 (the key list gives labels more)
func rooms(bw: float, x0: float, has_value: bool) -> Array:
	var vx: float = x0 + bw * (0.56 if kind == "keys" else 0.47)
	if not has_value:
		return [bw - 70.0, 0.0, vx]
	return [vx - 14.0 - (x0 + 34.0), x0 + bw - 22.0 - vx, vx]

## the font size `s` is drawn at to fit `max_w` pixels (down to 12; below that the end is cut)
func fit_size(s: String, fsize: int, max_w: float) -> int:
	var sz: int = fsize
	while sz > 12 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > max_w:
		sz -= 1
	return sz

## draw text that fits in `max_w` pixels: the font size comes down (to 12) until it does, then the end is cut with an ellipsis
func _fit(s: String, pos: Vector2, fsize: int, col: Color, max_w: float) -> void:
	var sz: int = fit_size(s, fsize, max_w)
	var out := s
	while out.length() > 1 and font.get_string_size(out, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > max_w:
		out = out.substr(0, out.length() - 1)
		if font.get_string_size(out + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= max_w:
			out += "…"
			break
	_txt(out, pos, sz, col)

func _draw() -> void:
	var W: float = size.x if size.x > 0 else 1280.0
	var H: float = size.y if size.y > 0 else 720.0
	if kind == "implants" or kind == "map" or kind == "skills" or kind == "create":
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
		"create":
			_create(W, H)
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
	var name_txt := TITLE_NAME
	var f: Font = kana_font if kana_font != null else font
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
		# the label gets the room up to the value column and the value the room after it; text too long for its room is shrunk, never drawn over its neighbour
		var has_v: bool = it.has("value")
		var rm: Array = rooms(bw, x0, has_v)
		_fit(it["label"], Vector2(x0 + 34, y), 22, col, rm[0])
		if has_v:
			_fit(str(it["value"]), Vector2(rm[2], y), 22, CYAN if on else Color(0.55, 0.8, 0.95), rm[1])
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
	var iw: float = float(isl.W)
	var ih: float = float(isl.H)
	var sc: float = minf((W - 48.0) / iw, (H - 90.0) / ih)
	var ox: float = (W - iw * sc) * 0.5
	var oy := 48.0
	draw_texture_rect(map_tex, Rect2(ox, oy, iw * sc, ih * sc), false)       # the chart is drawn from this island's own seed (Island.overview_image)
	var P := func(gx: float, gy: float) -> Vector2:
		return Vector2(ox + gx * sc, oy + gy * sc)
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
	# place names
	for lm in isl.landmarks():
		var lp: Vector2 = P.call(float(lm["pos"].x), float(lm["pos"].y))
		_txt(lm["name"], lp + Vector2(-30, 0), 13, Color(1, 1, 1, 0.9))
	_rtxt("Island seed %d" % isl.seed_value, W - 24, 34, 16, Color(0.6, 0.85, 1.0))
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


# ---------------------------------------------------------------------------------------------- character creation
## rows: 0-4 appearance (CR.LOOK_ROWS), 5-9 attributes (SK.ATTRS), 10 Begin, 11 Back.  Everything fits one 1280x720 screen.
const CC_LOOK_H := 38.0
const CC_LOOK_STEP := 42.0
const CC_LOOK_X := 40.0
const CC_LOOK_Y := 356.0
const CC_ATTR_X := 622.0
const CC_ATTR_Y := 170.0
const CC_ATTR_H := 80.0

func cc_row_rect(i: int) -> Rect2:
	if i < CR.LOOK_ROWS.size():
		return Rect2(CC_LOOK_X, CC_LOOK_Y + i * CC_LOOK_STEP, 218.0, CC_LOOK_H)
	var a: int = i - CR.LOOK_ROWS.size()
	if a < SK.ATTRS.size():
		return Rect2(CC_ATTR_X, CC_ATTR_Y + a * (CC_ATTR_H + 4.0), 618.0, CC_ATTR_H)
	if a == SK.ATTRS.size():
		return Rect2(864, 640, 190, 46)
	return Rect2(1066, 640, 190, 46)

func cc_rows() -> int:
	return CR.LOOK_ROWS.size() + SK.ATTRS.size() + 2

## which row the mouse is on and which way it would move: {row, dir}; dir -1 / +1 for the arrow zones at either end of a row, 0 elsewhere
func cc_hit(p: Vector2) -> Dictionary:
	for i in cc_rows():
		var r: Rect2 = cc_row_rect(i)
		if r.has_point(p):
			var dir := 0
			if i < CR.LOOK_ROWS.size() + SK.ATTRS.size():
				var zone: float = r.size.x * 0.5 if i < CR.LOOK_ROWS.size() else 56.0          # a sprite row is split in halves
				if p.x < r.position.x + zone:
					dir = -1
				elif p.x > r.end.x - zone:
					dir = 1
			return {"row": i, "dir": dir}
	return {"row": -1, "dir": 0}

func _tri(c: Vector2, right: bool, on: bool) -> void:
	var d: float = 9.0 if right else -9.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(d, 0), c + Vector2(-d * 0.6, -9), c + Vector2(-d * 0.6, 9)]), CYAN if on else Color(0.3, 0.38, 0.45))

func _create(W: float, H: float) -> void:
	for gx in range(0, int(W), 32):
		draw_line(Vector2(gx, 0), Vector2(gx, H), Color(0.3, 0.9, 1.0, 0.05))
	for gy in range(0, int(H), 32):
		draw_line(Vector2(0, gy), Vector2(W, gy), Color(0.3, 0.9, 1.0, 0.05))
	var app: Dictionary = cc.get("app", CR.default_app())
	var attrs: Dictionary = cc.get("attrs", CR.start_attrs())
	var look: Dictionary = CR.look_of(app)
	_txt("CREATE CHARACTER", Vector2(40, 46), 32, Color.WHITE)
	_rtxt("Up / Down choose  -  Left / Right change  -  Enter begins  -  Esc back", W - 40, 42, 15, Color(0.6, 0.75, 0.9))
	# ---- appearance: the standing doll, then skin, hair and eyes
	var pa := Rect2(24, 66, 250, 560)
	_panel(pa)
	_txt("1  APPEARANCE", Vector2(pa.position.x + 16, pa.position.y + 28), 18, CYAN)
	draw_rect(Rect2(40, 108, 218, 236), Color(0.02, 0.03, 0.06))
	draw_rect(Rect2(40, 108, 218, 236), Color(0.3, 0.9, 1.0, 0.35), false, 1.0)
	_cc_doll(Vector2(149, 226), 2.0, look)
	for i in CR.LOOK_ROWS.size():
		var row: Dictionary = CR.LOOK_ROWS[i]
		var r: Rect2 = cc_row_rect(i)
		var on: bool = cc_sel == i
		draw_rect(r, Color(0.3, 0.9, 1.0, 0.2) if on else Color(1, 1, 1, 0.04))
		if on:
			draw_rect(Rect2(r.position.x, r.position.y, 4, r.size.y), MAGENTA)
		_txt(String(row["label"]).to_upper(), Vector2(r.position.x + 12, r.position.y + 13), 11, Color(0.6, 0.75, 0.9))
		_tri(Vector2(r.position.x + 16, r.position.y + 24), false, true)
		_tri(Vector2(r.end.x - 16, r.position.y + 24), true, true)
		var sw: Color = CR.option_color(app, row["id"])
		var vx: float = r.position.x + 34.0
		if sw.a > 0.0:
			draw_rect(Rect2(vx, r.position.y + 18, 12, 12), sw)
			draw_rect(Rect2(vx, r.position.y + 18, 12, 12), Color(1, 1, 1, 0.5), false, 1.0)
			vx += 20.0
		_fit(CR.option_name(app, row["id"]), Vector2(vx, r.position.y + 31), 17, Color.WHITE, r.end.x - 34.0 - vx)
	# ---- background and goals (placeholder)
	var pb := Rect2(290, 66, 300, 560)
	_panel(pb)
	_txt("2  BACKGROUND & GOALS", Vector2(pb.position.x + 16, pb.position.y + 28), 17, CYAN)
	var bgd: Dictionary = CR.BACKGROUNDS[0]
	for k in 2:
		var box := Rect2(pb.position.x + 16, pb.position.y + 52 + k * 150, pb.size.x - 32, 134)
		draw_rect(box, Color(1, 1, 1, 0.03))
		draw_rect(box, Color(0.4, 0.5, 0.6, 0.6), false, 1.0)
		_txt("BACKGROUND" if k == 0 else "GOALS", Vector2(box.position.x + 12, box.position.y + 24), 15, Color(0.55, 0.65, 0.75))
		_txt(String(bgd["name"]) if k == 0 else "None yet", Vector2(box.position.x + 12, box.position.y + 54), 20, Color(0.7, 0.78, 0.86))
		draw_multiline_string(font, Vector2(box.position.x + 12, box.position.y + 80), "Coming in a later update." if k == 0 else "You will pick what you are after here.", HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 24, 14, 3, Color(0.5, 0.6, 0.7))
	draw_multiline_string(font, Vector2(pb.position.x + 16, pb.position.y + 370), String(bgd["desc"]), HORIZONTAL_ALIGNMENT_LEFT, pb.size.x - 32, 14, 4, Color(0.6, 0.72, 0.85))
	# ---- attributes
	var pt := Rect2(606, 66, 650, 560)
	_panel(pt)
	_txt("3  ATTRIBUTES", Vector2(pt.position.x + 16, pt.position.y + 28), 18, CYAN)
	_rtxt("%d to %d each, %d points in all" % [CR.ATTR_MIN, CR.ATTR_MAX, CR.total()], pt.end.x - 16, pt.position.y + 26, 14, Color(0.6, 0.72, 0.85))
	var free: int = CR.free_points(attrs)
	var fc := Color(1.0, 0.8, 0.25) if free > 0 else Color(0.5, 1.0, 0.7)
	_txt("FREE POINTS", Vector2(CC_ATTR_X, 118), 16, Color(0.75, 0.88, 1.0))
	_txt(str(free), Vector2(CC_ATTR_X + 150, 126), 40, fc)
	_rtxt(CR.pool_text(attrs), CC_ATTR_X + 618, 118, 15, fc)
	_txt("Lower one attribute to free a point; spend it on another.", Vector2(CC_ATTR_X, 148), 13, Color(0.55, 0.68, 0.8))
	for k in SK.ATTRS.size():
		var ad: Dictionary = SK.ATTRS[k]
		var i: int = CR.LOOK_ROWS.size() + k
		var r: Rect2 = cc_row_rect(i)
		var on: bool = cc_sel == i
		var v: int = int(attrs.get(ad["id"], SK.ATTR_START))
		draw_rect(r, Color(0.3, 0.9, 1.0, 0.2) if on else Color(1, 1, 1, 0.04))
		if on:
			draw_rect(Rect2(r.position.x, r.position.y, 4, r.size.y), MAGENTA)
		_tri(Vector2(r.position.x + 20, r.position.y + 22), false, CR.can_lower(attrs, ad["id"]))
		_tri(Vector2(r.end.x - 20, r.position.y + 22), true, CR.can_raise(attrs, ad["id"]))
		_txt(String(ad["name"]).to_upper(), Vector2(r.position.x + 40, r.position.y + 28), 20, Color.WHITE)
		_txt(str(v), Vector2(r.end.x - 150, r.position.y + 34), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 70.0)
		var dv: int = v - SK.ATTR_START
		if dv != 0:
			_txt("%+d" % dv, Vector2(r.end.x - 74, r.position.y + 30), 16, Color(0.5, 1.0, 0.7) if dv > 0 else Color(1.0, 0.55, 0.45), HORIZONTAL_ALIGNMENT_LEFT, 30.0)
		_fit(String(ad["desc"]), Vector2(r.position.x + 40, r.position.y + 46), 13, Color(0.62, 0.75, 0.88), r.size.x - 70.0)
		var names: Array = []
		for sd in SK.skills_of_attr(ad["id"]):
			names.append(sd["name"])
		var bn: int = SK.attr_bonus(v)
		if names.size() > 4:
			names = names.slice(0, 3) + ["%d more" % (names.size() - 3)]
		_fit("Skills +%d:  %s" % [bn, ", ".join(names)], Vector2(r.position.x + 40, r.position.y + 72), 13, Color(1.0, 0.8, 0.25) if bn > 0 else Color(0.5, 0.6, 0.7), r.size.x - 56.0)
		# the 6..14 track: nine cells, the start (10) marked
		for c in range(CR.ATTR_MIN, CR.ATTR_MAX + 1):
			var cx: float = r.position.x + 40.0 + float(c - CR.ATTR_MIN) * 16.0
			draw_rect(Rect2(cx, r.position.y + 53.0, 13, 5), (CYAN if c <= v else Color(1, 1, 1, 0.12)))
			if c == SK.ATTR_START:
				draw_rect(Rect2(cx + 5, r.position.y + 50.0, 3, 2), Color(1, 1, 1, 0.8))
	# ---- buttons
	var valid: bool = CR.attrs_valid(attrs)
	var rb: Rect2 = cc_row_rect(CR.LOOK_ROWS.size() + SK.ATTRS.size())
	var rk: Rect2 = cc_row_rect(CR.LOOK_ROWS.size() + SK.ATTRS.size() + 1)
	for pair in [[rb, "BEGIN", valid, cc_sel == CR.LOOK_ROWS.size() + SK.ATTRS.size()], [rk, "BACK", true, cc_sel == CR.LOOK_ROWS.size() + SK.ATTRS.size() + 1]]:
		var br: Rect2 = pair[0]
		var okb: bool = pair[2]
		draw_rect(br, Color(0.3, 0.9, 1.0, 0.22) if pair[3] else Color(1, 1, 1, 0.05))
		draw_rect(br, (MAGENTA if pair[3] else (CYAN if okb else Color(0.4, 0.45, 0.5))), false, 2.0)
		_txt(pair[1], Vector2(br.position.x, br.position.y + 31), 22, (Color.WHITE if okb else Color(0.5, 0.55, 0.6)), HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
	var msg: String = prompt if prompt != "" else ("" if valid else "Spend your free points to begin")
	_txt(msg, Vector2(40, 664), 16, Color(1.0, 0.8, 0.25))

## the standing doll; without its atlas, the doll in the tileset, unrotated, at `k` times its drawn size, centred on c (stand-in art: the supplied sprites will replace the tileset layers)
func _cc_doll(c: Vector2, k: float, look: Dictionary) -> void:
	if cc_fig == null:
		cc_fig = FG.new()
	if cc_fig.ready():                     # the standing doll at 3x, in underwear, no weapon
		var keys: Array = DS.figure_keys({"layers": [], "weapon": "", "look": look}, cc_fig)
		cc_fig.draw(self, keys, c - Vector2(96, 104), 3.0, false)
		return
	if cc_tileset == null or not cc_tileset.has("dl:d_legs"):
		return
	var items: Array = []
	for key in DS.base_layers(look, false):
		if cc_tileset.has("dl:" + String(key)) and String(key) != "d_shadow":
			var meta: Array = cc_tileset.doll.get(String(key), [65, ""])
			items.append([int(meta[0]), String(key), String(meta[1])])
	items.sort_custom(func(a, b): return a[0] < b[0])
	draw_set_transform(c, 0.0, Vector2(k, k))
	for it in items:
		var sp: Array = cc_tileset.sprite("dl:" + String(it[1]))
		var r: Rect2 = sp[1]
		var tint := Color.WHITE
		if it[2] == "skin":
			tint = look["skin"]
		elif it[2] == "hair":
			tint = look["hair"]
		draw_texture_rect_region(sp[0], Rect2(-r.size * 0.5, r.size), r, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
