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
var sk_sel: int = 0                # the highlighted line of the attributes & skills screen (0-4 attributes, then the skills)
var world = null
var cc: Dictionary = {}            # the character being made on the create screen: {app, attrs}
var cc_sel: int = 0                # the highlighted row of the create screen (see cc_row_rect)
var cc_tileset = null              # the 64px tileset, for the doll preview when the standing dolls are missing
var tm: Dictionary = {}            # the open mission terminal (main.gd): {cell, offers, sel, msg}
var cc_fig = null                  # the standing-doll atlas, loaded when the creation screen first draws
var cc_dolls = null                # the layered dolls (64 px set) for the creation preview
const CC_DOLLS := "res://gfx/dolls"
const DIMG = preload("res://addons/trilobit_doll/doll_image.gd")
const ADAPT = preload("res://addons/trilobit_doll/trilobit_adapter.gd")
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
	if kind in TAB_KINDS or kind == "create" or kind == "barter":
		draw_rect(Rect2(0, 0, W, H), BG)
	elif overlay:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.72))
	else:
		_backdrop(W, H)
	if kind in TAB_KINDS:
		_gridlines(W, H)
		_tabbar(W)
	match kind:
		"barter":
			_gridlines(W, H)
			if bt != null and game != null:
				bt.draw(self, W, H, t, get_process_delta_time())
		"equipment", "implants":
			if gear != null and game != null:
				gear.draw(self, W, H, t, get_process_delta_time())
		"skills":
			draw_set_transform(Vector2(0, TAB_H))
			_skills(W, H - TAB_H)
			draw_set_transform(Vector2.ZERO)
		"create":
			_create(W, H)
		"terminal":
			_terminal(W, H)
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

# ---------------------------------------------------------------- the tab bar (equipment, implants, skills, map)
const TAB_KINDS := ["equipment", "implants", "skills", "map"]
const TAB_NAMES := {"equipment": "EQUIPMENT", "implants": "IMPLANTS", "skills": "SKILLS", "map": "MAP"}
const TAB_H := 44.0
var tab_keys: Dictionary = {}              # tab kind -> the key that opens it, for the label
var bt = null                              # BarterUI (barter_ui.gd): the merchant screen
var gear = null                            # GearUI (gear_ui.gd): the equipment and implants tabs
var map_local: bool = false                # the map tab shows the local map instead of the island
var local_tex: ImageTexture = null
var local_info: Dictionary = {}            # {origin: Vector2i of the PC in the window, radius, level, labels: [{dx, dy, text}]}

func is_tab() -> bool:
	return kind in TAB_KINDS

func tab_rect(i: int) -> Rect2:
	var w := 200.0
	var gap := 12.0
	var x0: float = (1280.0 - (w * TAB_KINDS.size() + gap * (TAB_KINDS.size() - 1))) * 0.5
	return Rect2(x0 + i * (w + gap), 4.0, w, 34.0)

func tab_arrow_rect(next: bool) -> Rect2:
	return Rect2(1280.0 * 0.5 + (452.0 if next else -452.0 - 40.0), 4.0, 40.0, 34.0)

## which tab a point is on: 0..3, or -1 / -2 for the < and > arrows, or -9 for none
func tab_at(p: Vector2) -> int:
	for i in TAB_KINDS.size():
		if tab_rect(i).has_point(p):
			return i
	if tab_arrow_rect(false).has_point(p):
		return -1
	if tab_arrow_rect(true).has_point(p):
		return -2
	return -9

func _tabbar(W: float) -> void:
	draw_rect(Rect2(0, 0, W, TAB_H), Color(0.02, 0.03, 0.06))
	draw_line(Vector2(0, TAB_H), Vector2(W, TAB_H), Color(0.3, 0.9, 1.0, 0.5), 1.5)
	for nx in [false, true]:
		var ar: Rect2 = tab_arrow_rect(nx)
		_txt("<" if not nx else ">", Vector2(ar.position.x, ar.position.y + 27.0), 28, CYAN, HORIZONTAL_ALIGNMENT_CENTER, ar.size.x)
	for i in TAB_KINDS.size():
		var k: String = TAB_KINDS[i]
		var r: Rect2 = tab_rect(i)
		var on: bool = k == kind
		if on:
			draw_rect(r, Color(0.3, 0.9, 1.0, 0.22))
			draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), MAGENTA)
			draw_rect(r, CYAN, false, 1.5)
		var col: Color = Color.WHITE if on else Color(0.5, 0.62, 0.75)
		var label: String = TAB_NAMES[k]
		var key: String = String(tab_keys.get(k, ""))
		_txt(label, Vector2(r.position.x, r.position.y + 24.0), 20, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - (22.0 if key != "" else 0.0))
		if key != "":
			_rtxt("[%s]" % key, r.end.x - 8.0, r.position.y + 23.0, 13, Color(1.0, 0.8, 0.25) if on else Color(0.45, 0.55, 0.65))

func _gridlines(W: float, H: float) -> void:
	for gx in range(0, int(W), 32):
		draw_line(Vector2(gx, 0), Vector2(gx, H), Color(0.3, 0.9, 1.0, 0.05))
	for gy in range(0, int(H), 32):
		draw_line(Vector2(0, gy), Vector2(W, gy), Color(0.3, 0.9, 1.0, 0.05))

# ---------------------------------------------------------------- the island map
func map_button_rect(local: bool) -> Rect2:
	return Rect2(1280.0 - 24.0 - (140.0 if local else 280.0) - (0.0 if local else 8.0), TAB_H + 8.0, 140.0, 28.0)

## 0 the island button, 1 the local button, -1 none
func map_button_at(p: Vector2) -> int:
	if map_button_rect(false).has_point(p):
		return 0
	if map_button_rect(true).has_point(p):
		return 1
	return -1

func _map(W: float, H: float) -> void:
	for loc in [false, true]:
		var br: Rect2 = map_button_rect(loc)
		var on: bool = map_local == loc
		draw_rect(br, Color(0.3, 0.9, 1.0, 0.22) if on else Color(1, 1, 1, 0.04))
		draw_rect(br, CYAN if on else Color(0.35, 0.45, 0.55), false, 1.5)
		_txt("LOCAL" if loc else "ISLAND", Vector2(br.position.x, br.position.y + 20.0), 16, Color.WHITE if on else Color(0.55, 0.65, 0.78), HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
	if map_local:
		_local_map(W, H)
	else:
		draw_set_transform(Vector2(0, TAB_H))
		_island_map(W, H - TAB_H)
		draw_set_transform(Vector2.ZERO)

func _island_map(W: float, H: float) -> void:
	var cyan := Color(0.3, 0.9, 1.0)
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
	_txt("Island seed %d" % isl.seed_value, Vector2(24, 30), 16, Color(0.6, 0.85, 1.0))
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
		draw_string(font, Vector2(24, H - 14), "You are at (%d, %d) in %s.   Tab switches to the local map, Esc closes." % [gp.x, gp.y, isl.zone_name(game.zone)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.9, 1.0))

## the local map: every tile you have seen within 40 of you, drawn in plain neon colours (the picture is built by main.gd's _make_local_map)
const LOCAL_PX := 7
func _local_map(W: float, H: float) -> void:
	var n: int = int(local_info.get("n", 81))
	var side: float = float(n * LOCAL_PX)
	var ox := 60.0
	var oy: float = TAB_H + 44.0
	if local_tex == null:
		_txt("Nothing charted here.", Vector2(ox, oy + 30.0), 18, Color.WHITE)
		return
	draw_rect(Rect2(ox - 4.0, oy - 4.0, side + 8.0, side + 8.0), Color(0.04, 0.06, 0.11))
	draw_rect(Rect2(ox - 4.0, oy - 4.0, side + 8.0, side + 8.0), CYAN, false, 1.5)
	draw_texture_rect(local_tex, Rect2(ox, oy, side, side), false)
	# you are here
	var ctr: float = float(n / 2) * LOCAL_PX + LOCAL_PX * 0.5
	var pp := Vector2(ox + ctr, oy + ctr)
	var pulse: float = 0.5 + 0.5 * sin(t * 6.0)
	draw_circle(pp, 7.0 + 3.0 * pulse, Color(1.0, 0.2, 0.5, 0.25 + 0.2 * pulse))
	draw_circle(pp, 3.5, Color.WHITE)
	# building names sit just above the middle tile of the building
	for lb in local_info.get("labels", []):
		var lp := Vector2(ox + (float(lb["dx"]) + float(n / 2) + 0.5) * LOCAL_PX, oy + (float(lb["dy"]) + float(n / 2)) * LOCAL_PX - 4.0)
		_txt(String(lb["text"]), lp - Vector2(80, 0), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 160.0)
	# the key
	var kx: float = ox + side + 40.0
	var ky: float = oy + 4.0
	_txt("LOCAL MAP", Vector2(kx, ky + 14.0), 24, Color.WHITE)
	_txt("Everything you have seen within %d tiles." % (n / 2), Vector2(kx, ky + 40.0), 16, Color(0.6, 0.75, 0.9))
	var ky2: float = ky + 76.0
	for e in LOCAL_KEY:
		draw_rect(Rect2(kx, ky2 - 12.0, 18.0, 18.0), e[1])
		draw_rect(Rect2(kx, ky2 - 12.0, 18.0, 18.0), Color(1, 1, 1, 0.25), false, 1.0)
		_txt(String(e[0]), Vector2(kx + 30.0, ky2 + 3.0), 17, Color(0.85, 0.92, 1.0))
		ky2 += 28.0
	var lvl: int = int(local_info.get("level", 0))
	_txt("You are at (%d, %d)%s.   Tab switches to the island map, Esc closes." % [int(local_info.get("gx", 0)), int(local_info.get("gy", 0)), "" if lvl == 0 else ", level %d" % lvl], Vector2(24, H - 14.0), 15, Color(0.8, 0.9, 1.0))

## colours of the local map: [name, colour]
const LOCAL_KEY := [["Wall", Color(1.0, 0.25, 0.65)], ["Window", Color(0.55, 0.9, 1.0)], ["Door", Color(1.0, 0.8, 0.25)], ["Road", Color(0.1, 0.14, 0.32)],
	["Sidewalk", Color(0.24, 0.3, 0.5)], ["Floor", Color(0.07, 0.2, 0.28)], ["Obstacle", Color(0.62, 0.68, 0.8)], ["Water", Color(0.05, 0.12, 0.5)],
	["Stairs, lift, ladder", Color(1.0, 0.65, 0.1)], ["Open ground", Color(0.06, 0.3, 0.26)]]

# ---------------------------------------------------------------- attributes and skills
## one line per attribute (0-4) then per skill, in the order of SK.SKILLS
func sk_entries() -> Array:
	var out: Array = []
	for a in SK.ATTRS:
		out.append({"kind": "attr", "id": a["id"]})
	for sd in SK.SKILLS:
		out.append({"kind": "skill", "id": sd["id"]})
	return out

const SK_TOP := 28.0
const SK_TOP_H := 158.0
const SK_ROW := 34.0

func sk_box_rect(group: int, W: float, H: float) -> Rect2:
	var y0: float = SK_TOP + SK_TOP_H + 12.0
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
	var H: float = (size.y if size.y > 0 else 720.0) - TAB_H
	p.y -= TAB_H
	var rects := sk_rects(W, H)
	for i in rects.size():
		if (rects[i] as Rect2).has_point(p):
			return i
	return -1

## move the highlight to the nearest line in a direction; false if there is none
func sk_move(dir: Vector2i) -> bool:
	var W: float = size.x if size.x > 0 else 1280.0
	var H: float = (size.y if size.y > 0 else 720.0) - TAB_H
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
	var lv: int = game.pc_level if game != null else 0
	var pts: int = game.attr_points if game != null else 0
	var hint := "Arrows / numpad / mouse choose  -  Esc closes"
	if pts > 0:
		hint = "Enter or click an attribute to spend a point  -  " + hint
	_rtxt(hint, W - 40, 18, 14, Color(0.6, 0.75, 0.9))
	if lv < SK.LEVEL_MAX:
		_txt("Level %d needs %s" % [lv + 1, SK.level_text(lv + 1)], Vector2(40, 18), 14, Color(1.0, 0.8, 0.25))
	# the attribute box: one line, five attributes
	var b0 := sk_box_rect(0, W, H)
	var b1 := sk_box_rect(1, W, H)
	var abox := Rect2(b0.position.x, SK_TOP + 8.0, b0.size.x, SK_TOP_H - 8.0)       # the top boxes share the columns of the skill boxes under them
	_panel(abox)
	_txt("ATTRIBUTES", Vector2(abox.position.x + 14, abox.position.y + 26), 16, CYAN)
	_rtxt("+1 per 2 over 10", abox.end.x - 14, abox.position.y + 26, 14, Color(0.6, 0.72, 0.85))
	_txt("LEVEL %d" % lv + ("  (max)" if lv >= SK.LEVEL_MAX else ""), Vector2(abox.position.x + 130, abox.position.y + 26), 16, Color(1.0, 0.8, 0.25))
	_txt("POINTS %d" % pts, Vector2(abox.position.x + 250, abox.position.y + 26), 16, MAGENTA if pts > 0 else Color(0.5, 0.6, 0.72))
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
		if pts > 0:
			_txt("+", Vector2(r.position.x + 6, r.position.y + 20), 20, MAGENTA)
		var bn: int = SK.attr_bonus(v)
		if bn != 0:
			_rtxt("%+d" % bn, r.end.x - 8, r.position.y + 20, 15, Color(1.0, 0.8, 0.25) if bn > 0 else Color(1.0, 0.45, 0.4))
	# the detail box
	var dbox := Rect2(b1.position.x, SK_TOP + 8.0, b1.size.x, SK_TOP_H - 8.0)
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
			var bw: float = r.end.x - bx - 110.0
			draw_rect(Rect2(bx, ty - 12.0, bw, 10.0), Color(1, 1, 1, 0.1))
			var f: float = 1.0 if b >= SK.BASE_MAX else clampf(float(have) / float(need), 0.0, 1.0)
			draw_rect(Rect2(bx, ty - 12.0, bw * f, 10.0), CYAN if sd["live"] else Color(0.4, 0.5, 0.6))
			_rtxt("%s/%s" % [SK.short_num(have), SK.short_num(need)] if b < SK.BASE_MAX else "max", r.end.x - 8.0, ty - 2.0, 14, Color(0.65, 0.78, 0.9))

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
		parts.append("%s %d (%+d)" % [SK.attr(a)["name"], int(attrs.get(a, 10)), SK.attr_bonus(int(attrs.get(a, 10)))])
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
const CC_LOOK_H := 32.0
const CC_LOOK_STEP := 36.0
const CC_LOOK_X := 40.0
const CC_LOOK_Y := 356.0
const CC_ATTR_X := 622.0
const CC_ATTR_Y := 170.0
const CC_ATTR_H := 80.0

## rows: 0 the name, then the appearance rows, the attributes, and the buttons Randomize, Begin, Back
func cc_row_rect(i: int) -> Rect2:
	if i == 0:
		return Rect2(306, 90, 268, 52)
	var j: int = i - 1
	if j < CR.LOOK_ROWS.size():
		return Rect2(CC_LOOK_X, CC_LOOK_Y + j * CC_LOOK_STEP, 218.0, CC_LOOK_H)
	var a: int = j - CR.LOOK_ROWS.size()
	if a < SK.ATTRS.size():
		return Rect2(CC_ATTR_X, CC_ATTR_Y + a * (CC_ATTR_H + 4.0), 618.0, CC_ATTR_H)
	if a == SK.ATTRS.size():
		return Rect2(662, 640, 190, 46)
	if a == SK.ATTRS.size() + 1:
		return Rect2(864, 640, 190, 46)
	return Rect2(1066, 640, 190, 46)

func cc_rows() -> int:
	return 1 + CR.LOOK_ROWS.size() + SK.ATTRS.size() + 3

## which row the mouse is on and which way it would move: {row, dir}; dir -1 / +1 for the arrow zones at either end of a row, 0 elsewhere
func cc_hit(p: Vector2) -> Dictionary:
	for i in cc_rows():
		var r: Rect2 = cc_row_rect(i)
		if r.has_point(p):
			var dir := 0
			if i >= 1 and i < 1 + CR.LOOK_ROWS.size() + SK.ATTRS.size():
				var zone: float = r.size.x * 0.5 if i < 1 + CR.LOOK_ROWS.size() else 56.0          # a sprite row is split in halves
				if p.x < r.position.x + zone:
					dir = -1
				elif p.x > r.end.x - zone:
					dir = 1
			return {"row": i, "dir": dir}
	return {"row": -1, "dir": 0}

## the gender symbol, drawn with lines (the font has no guaranteed glyph): male = ring with an arrow up and right, female = ring on a cross
func _gender_mark(c: Vector2, fem: bool) -> void:
	var col := Color(1.0, 0.35, 0.75) if fem else Color(0.3, 0.9, 1.0)
	if fem:
		draw_arc(c + Vector2(0, -4), 6.0, 0.0, TAU, 20, col, 2.0)
		draw_line(c + Vector2(0, 2), c + Vector2(0, 12), col, 2.0)
		draw_line(c + Vector2(-4, 7), c + Vector2(4, 7), col, 2.0)
	else:
		draw_arc(c + Vector2(-2, 3), 6.0, 0.0, TAU, 20, col, 2.0)
		draw_line(c + Vector2(2, -1), c + Vector2(9, -8), col, 2.0)
		draw_line(c + Vector2(3, -8), c + Vector2(9, -8), col, 2.0)
		draw_line(c + Vector2(9, -2), c + Vector2(9, -8), col, 2.0)

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
	_rtxt("Up / Down choose  -  Left / Right change  -  type a name on the NAME line  -  Esc back", W - 40, 42, 15, Color(0.6, 0.75, 0.9))
	# ---- appearance: the standing doll, then skin, hair and eyes
	var pa := Rect2(24, 66, 250, 560)
	_panel(pa)
	_txt("1  APPEARANCE", Vector2(pa.position.x + 16, pa.position.y + 28), 18, CYAN)
	draw_rect(Rect2(40, 108, 218, 236), Color(0.02, 0.03, 0.06))
	draw_rect(Rect2(40, 108, 218, 236), Color(0.3, 0.9, 1.0, 0.35), false, 1.0)
	_cc_doll(Vector2(149, 226), 2.0, look)
	for li in CR.LOOK_ROWS.size():
		var row: Dictionary = CR.LOOK_ROWS[li]
		var r: Rect2 = cc_row_rect(li + 1)
		var on: bool = cc_sel == li + 1
		draw_rect(r, Color(0.3, 0.9, 1.0, 0.2) if on else Color(1, 1, 1, 0.04))
		if on:
			draw_rect(Rect2(r.position.x, r.position.y, 4, r.size.y), MAGENTA)
		_txt(String(row["label"]).to_upper(), Vector2(r.position.x + 12, r.position.y + 11), 11, Color(0.6, 0.75, 0.9))
		_tri(Vector2(r.position.x + 16, r.position.y + 21), false, true)
		_tri(Vector2(r.end.x - 16, r.position.y + 21), true, true)
		if row["id"] == "sprite" or row["id"] == "build":
			var mk := Vector2(r.position.x + 44.0, r.position.y + 21.0)
			if row["id"] == "sprite":
				_gender_mark(mk, bool(look["fem"]))
				_fit(CR.option_name(app, "sprite"), Vector2(mk.x + 22.0, r.position.y + 27), 16, Color.WHITE, r.end.x - 34.0 - mk.x - 22.0)
			else:
				var bars: int = int(app.get("build", 1)) + 1
				for bi in bars:
					draw_rect(Rect2(mk.x - 9.0 + bi * 7.0, r.position.y + 11.0, 3.0, 20.0), Color(1.0, 0.8, 0.25))
				_fit(String(CR.BUILDS[int(app.get("build", 1))]["id"]).capitalize(), Vector2(mk.x + 22.0, r.position.y + 27), 16, Color.WHITE, r.end.x - 34.0 - mk.x - 22.0)
			continue
		var sw: Color = CR.option_color(app, row["id"])
		var vx: float = r.position.x + 34.0
		if sw.a > 0.0:
			draw_rect(Rect2(vx, r.position.y + 15, 12, 12), sw)
			draw_rect(Rect2(vx, r.position.y + 15, 12, 12), Color(1, 1, 1, 0.5), false, 1.0)
			vx += 20.0
		_fit(CR.option_name(app, row["id"]), Vector2(vx, r.position.y + 27), 16, Color.WHITE, r.end.x - 34.0 - vx)
	# ---- the name, then background and goals (placeholder)
	var pb := Rect2(290, 66, 300, 560)
	_panel(pb)
	_txt("2  NAME, BACKGROUND & GOALS", Vector2(pb.position.x + 16, pb.position.y + 22), 15, CYAN)
	var nr: Rect2 = cc_row_rect(0)
	var non: bool = cc_sel == 0
	draw_rect(nr, Color(0.3, 0.9, 1.0, 0.2) if non else Color(1, 1, 1, 0.04))
	draw_rect(nr, MAGENTA if non else Color(0.4, 0.5, 0.6, 0.6), false, 2.0 if non else 1.0)
	_txt("NAME", Vector2(nr.position.x + 12, nr.position.y + 15), 11, Color(0.6, 0.75, 0.9))
	var nm: String = String(cc.get("name", ""))
	var shown: String = nm + ("_" if non and int(Time.get_ticks_msec() / 450) % 2 == 0 else "")
	_fit(shown if (nm != "" or non) else "Type a name", Vector2(nr.position.x + 12, nr.position.y + 40), 19, Color.WHITE if nm != "" else Color(0.5, 0.58, 0.66), nr.size.x - 24.0)
	var bgd: Dictionary = CR.BACKGROUNDS[0]
	for k in 2:
		var box := Rect2(pb.position.x + 16, pb.position.y + 92 + k * 150, pb.size.x - 32, 134)
		draw_rect(box, Color(1, 1, 1, 0.03))
		draw_rect(box, Color(0.4, 0.5, 0.6, 0.6), false, 1.0)
		_txt("BACKGROUND" if k == 0 else "GOALS", Vector2(box.position.x + 12, box.position.y + 24), 15, Color(0.55, 0.65, 0.75))
		_txt(String(bgd["name"]) if k == 0 else "None yet", Vector2(box.position.x + 12, box.position.y + 54), 20, Color(0.7, 0.78, 0.86))
		draw_multiline_string(font, Vector2(box.position.x + 12, box.position.y + 80), "Coming in a later update." if k == 0 else "You will pick what you are after here.", HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 24, 14, 3, Color(0.5, 0.6, 0.7))
	draw_multiline_string(font, Vector2(pb.position.x + 16, pb.position.y + 430), String(bgd["desc"]), HORIZONTAL_ALIGNMENT_LEFT, pb.size.x - 32, 14, 4, Color(0.6, 0.72, 0.85))
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
		var i: int = 1 + CR.LOOK_ROWS.size() + k
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
		_fit("Skills %+d:  %s" % [bn, ", ".join(names)], Vector2(r.position.x + 40, r.position.y + 72), 13, (Color(1.0, 0.8, 0.25) if bn > 0 else (Color(1.0, 0.45, 0.4) if bn < 0 else Color(0.5, 0.6, 0.7))), r.size.x - 56.0)
		# the 6..14 track: nine cells, the start (10) marked
		for c in range(CR.ATTR_MIN, CR.ATTR_MAX + 1):
			var cx: float = r.position.x + 40.0 + float(c - CR.ATTR_MIN) * 16.0
			draw_rect(Rect2(cx, r.position.y + 53.0, 13, 5), (CYAN if c <= v else Color(1, 1, 1, 0.12)))
			if c == SK.ATTR_START:
				draw_rect(Rect2(cx + 5, r.position.y + 50.0, 3, 2), Color(1, 1, 1, 0.8))
	# ---- buttons
	var valid: bool = CR.attrs_valid(attrs)
	var b0: int = 1 + CR.LOOK_ROWS.size() + SK.ATTRS.size()
	var rr: Rect2 = cc_row_rect(b0)
	var rb: Rect2 = cc_row_rect(b0 + 1)
	var rk: Rect2 = cc_row_rect(b0 + 2)
	for pair in [[rr, "RANDOMIZE", true, cc_sel == b0], [rb, "BEGIN", valid, cc_sel == b0 + 1], [rk, "BACK", true, cc_sel == b0 + 2]]:
		var br: Rect2 = pair[0]
		var okb: bool = pair[2]
		draw_rect(br, Color(0.3, 0.9, 1.0, 0.22) if pair[3] else Color(1, 1, 1, 0.05))
		draw_rect(br, (MAGENTA if pair[3] else (CYAN if okb else Color(0.4, 0.45, 0.5))), false, 2.0)
		_txt(pair[1], Vector2(br.position.x, br.position.y + 31), 22, (Color.WHITE if okb else Color(0.5, 0.55, 0.6)), HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
	var msg: String = prompt if prompt != "" else ("" if valid else "Spend your free points to begin")
	_txt(msg, Vector2(40, 664), 16, Color(1.0, 0.8, 0.25))

## the standing doll; without its atlas, the doll in the tileset, unrotated, at `k` times its drawn size, centred on c (stand-in art: the supplied sprites will replace the tileset layers)
func _cc_doll(c: Vector2, k: float, look: Dictionary) -> void:
	if cc_dolls == null:
		cc_dolls = DIMG.for_library(CC_DOLLS)
	if cc_dolls.ok():                      # the layered doll (64 px set) at 3x, in underwear, no weapon, feet where the old doll's were
		var ds = ADAPT.spec_from_game([], look, "", String(look.get("size", "m")), CC_DOLLS)
		var tex: Texture2D = cc_dolls.texture(ds, "unarmed/idle/0")
		if tex != null:
			draw_set_transform(c + Vector2(0, 82), 0.0, Vector2(3.0 * float(look.get("build", 1.0)), 3))
			draw_texture(tex, -cc_dolls.origin())
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
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


# ---------------------------------------------------------------------------------------------- the mission terminal
const MS = preload("res://src/missions.gd")
const TM_ROW := 98.0

func _terminal(W: float, H: float) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.0, 0.55))
	var offers: Array = tm.get("offers", [])
	var sel: int = int(tm.get("sel", 0))
	var left := Rect2(40, 50, 520, 580)
	var right := Rect2(580, 50, 660, 580)
	_panel(left)
	_panel(right)
	_txt("MISSION TERMINAL", Vector2(60, 84), 24, CYAN)
	_txt("Five contracts are posted today", Vector2(60, 106), 14, Color(0.6, 0.75, 0.9))
	var portal_open: bool = game != null and not game.portal.is_empty()
	for k in offers.size():
		var o: Dictionary = offers[k]
		var r := Rect2(54, 122 + k * TM_ROW, 492, TM_ROW - 8)
		var on: bool = k == sel
		draw_rect(r, Color(0.12, 0.2, 0.3, 0.95) if on else Color(0.06, 0.09, 0.14, 0.9))
		draw_rect(r, MAGENTA if on else Color(0.2, 0.4, 0.5), false, 1.5 if on else 1.0)
		var tcol: Color = [Color(1.0, 0.4, 0.4), Color(0.4, 1.0, 0.7), Color(1.0, 0.8, 0.25), Color(0.5, 0.8, 1.0), Color(1.0, 0.55, 0.2)][k % 5]
		draw_rect(Rect2(r.position.x + 10, r.position.y + 12, 64, 24), tcol * Color(1, 1, 1, 0.25))
		draw_rect(Rect2(r.position.x + 10, r.position.y + 12, 64, 24), tcol, false, 1.0)
		_txt(String(o["tag"]), Vector2(r.position.x + 10, r.position.y + 30), 15, tcol, HORIZONTAL_ALIGNMENT_CENTER, 64.0)
		_txt("%d" % (k + 1), Vector2(r.position.x + 12, r.position.y + 62), 14, Color(0.5, 0.65, 0.8))
		_txt(String(o["name"]).to_upper(), Vector2(r.position.x + 90, r.position.y + 28), 18, Color.WHITE)
		_fit(String(o["title"]), Vector2(r.position.x + 90, r.position.y + 52), 15, Color(0.8, 0.9, 1.0), 300.0)
		var is_done: bool = game != null and game.done_contracts.has(String(o["id"]))
		_rtxt("DONE" if is_done else "¥%d" % int(o["reward"]), r.end.x - 14, r.position.y + 28, 20, Color(0.5, 0.6, 0.65) if is_done else Color(1.0, 0.8, 0.25))
		_rtxt("risk: " + MS.risk_text(int(o["risk"])), r.end.x - 14, r.position.y + 52, 14, [Color(0.5, 1.0, 0.6), Color(1.0, 0.85, 0.3), Color(1.0, 0.4, 0.4)][clampi(int(o["risk"]), 1, 3) - 1])
		_fit(String(o["site"]) if o["type"] in ["assassination", "rescue"] else String(o["client"]), Vector2(r.position.x + 90, r.position.y + 72), 13, Color(0.55, 0.7, 0.85), 390.0)
	if offers.is_empty():
		return
	var o: Dictionary = offers[sel]
	var t: Dictionary = MS.type_of(o["type"])
	var x: float = right.position.x + 22
	var w: float = right.size.x - 44
	_txt(String(o["name"]).to_upper(), Vector2(x, 86), 26, Color.WHITE)
	_rtxt("¥%d on completion" % int(o["reward"]), right.end.x - 22, 86, 22, Color(1.0, 0.8, 0.25))
	_txt(String(o["title"]), Vector2(x, 116), 18, CYAN)
	draw_multiline_string(font, Vector2(x, 150), String(t["line"]), HORIZONTAL_ALIGNMENT_LEFT, w, 17, 2, Color(0.9, 0.95, 1.0))
	draw_multiline_string(font, Vector2(x, 206), String(o["brief"]), HORIZONTAL_ALIGNMENT_LEFT, w, 15, 6, Color(0.7, 0.82, 0.92))
	_txt("RISK", Vector2(x, 340), 14, Color(0.55, 0.7, 0.85))
	for p in 3:
		var filled: bool = p < int(o["risk"])
		draw_rect(Rect2(x + 52 + p * 26, 326, 20, 14), [Color(1.0, 0.4, 0.4) if filled else Color(0.15, 0.2, 0.28)][0])
	_txt("HELPS", Vector2(x, 372), 14, Color(0.55, 0.7, 0.85))
	var bits: Array = []
	for sid in t["skills"]:
		var sd: Dictionary = SK.skill(sid)
		var mine: int = game.lvl(sid) if game != null else 0
		bits.append("%s %d%s" % [sd["name"], mine, "" if sd["live"] else " (not in play yet)"])
	_txt(", ".join(bits), Vector2(x + 62, 372), 15, Color(0.5, 1.0, 0.7))
	draw_multiline_string(font, Vector2(x, 412), "Accepting opens a portal on the street beside this terminal.  Stepping through it enters the site.  The site is its own place, and leaving it closes the portal for good: pay only on a met objective.", HORIZONTAL_ALIGNMENT_LEFT, w, 14, 4, Color(0.6, 0.75, 0.9))
	if portal_open:
		draw_rect(Rect2(x, 482, w, 60), Color(0.35, 0.1, 0.2, 0.6))
		draw_multiline_string(font, Vector2(x + 12, 506), "A portal is already open for: %s.  Finish that contract, or scrap it with C." % String(game.portal["offer"]["title"]), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 15, 2, Color(1.0, 0.6, 0.7))
	var msg: String = String(tm.get("msg", ""))
	if msg != "":
		_txt(msg, Vector2(x, 570), 16, Color(1.0, 0.8, 0.25))
	_txt("Up / Down or 1-5 chooses  -  Enter accepts  -  C scraps an open contract  -  Esc leaves", Vector2(60, 664), 15, Color(0.6, 0.75, 0.9))
