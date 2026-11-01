extends RefCounted
## The network overlay (Scan the Network): the map seen as the net sees it.  A deep-blue void with a slow rain of code; walls as faint thick lines of light,
## empty space as bare tinted gaps (a wave sweeps out from you), and the things on the network as bright pings.  Scanned things carry a red dot and a name;
## Networked things a red dot in a green ring.  Neon blue, yellow and pink: Ghost in the Shell's data-ocean by way of Anarchy Online's grid.
const CG = preload("res://src/citygen.gd")
const NW = preload("res://src/network.gd")

const BG_TOP := Color(0.006, 0.012, 0.045)
const BG_BOT := Color(0.020, 0.012, 0.075)
const CYAN := Color(0.30, 0.88, 1.00)
const BLUE := Color(0.14, 0.40, 1.00)
const PINK := Color(1.00, 0.26, 0.80)
const YELLOW := Color(1.00, 0.90, 0.30)
const RED := Color(1.00, 0.14, 0.20)
const GREEN := Color(0.26, 1.00, 0.52)
const WHITE := Color(1.0, 1.0, 1.0)

static func _h(a: int, b: int) -> int:
	var x: int = ((a * 73856093) ^ (b * 19349663) ^ 0x5bd1e995) & 0x7fffffff
	x = ((x >> 13) ^ x) * 1274126177 & 0x7fffffff
	return (x ^ (x >> 16)) & 0x7fffffff

static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0))

## ---------------------------------------------------------------------------------------------------------------- the whole picture
static func draw(v, g, ox: int, oy: int, T: int, S: float, vc: int) -> void:
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var W: float = float(v.cols * T)
	var H: float = float(v.rows * T)
	var size: int = g.size
	var base: int = (vc / g.s2) * g.s2
	var snap: Dictionary = g.net_snap
	var R: int = int(snap["radius"])
	var pcx: int = g.lx(snap["center"])
	var pcy: int = g.ly(snap["center"])
	_background(v, W, H)
	_rain(v, W, H, T, S, t)
	_cells(v, g, ox, oy, T, S, base, pcx, pcy, R, t)
	_frames(v, g, ox, oy, T, S, pcx, pcy, R, t)
	_scanlines(v, W, H, S, t)
	for p in snap["pings"]:
		var c: int = NW.ping_cell(g, p)
		if c < 0 or c / g.s2 != base / g.s2:
			continue
		_ping(v, g, p, Vector2((g.lx(c) - ox + 0.5) * T, (g.ly(c) - oy + 0.5) * T), T, S, t)
	_you(v, Vector2((pcx - ox + 0.5) * T, (pcy - oy + 0.5) * T), T, S, t)
	_cursor(v, g, ox, oy, T, S, pcx, pcy, t)
	for p in snap["pings"]:
		var c2: int = NW.ping_cell(g, p)
		if c2 >= 0 and c2 / g.s2 == base / g.s2 and NW.is_scanned(g, String(p["key"])):
			_label(v, p, Vector2((g.lx(c2) - ox + 0.5) * T, (g.ly(c2) - oy + 0.5) * T), T, S)
	_vignette(v, W, H)
	_title(v, g, S, t)

## ---------------------------------------------------------------------------------------------------------------- the void and the rain
static func _background(v, W: float, H: float) -> void:
	var bands := 12
	for k in bands:
		var f: float = float(k) / float(bands - 1)
		v.draw_rect(Rect2(0, H * float(k) / float(bands), W, H / float(bands) + 1.0), BG_TOP.lerp(BG_BOT, f))

static func _glyph(v, x: float, y: float, p: float, bits: int, col: Color) -> void:
	for i in 15:
		if (bits >> i) & 1 == 1:
			v.draw_rect(Rect2(x + float(i % 3) * p, y + float(i / 3) * p, p, p), col)

static func _rain(v, W: float, H: float, T: int, S: float, t: float) -> void:
	var p: float = maxf(2.0, floorf(S * 1.1))
	var step: float = p * 5.0
	var gh: float = p * 7.0
	var cols: int = int(W / step) + 1
	for k in cols:
		var h: int = _h(k, 17)
		var speed: float = 55.0 + float(h % 110)
		var len: int = 7 + (h >> 5) % 11
		var span: float = H + float(len) * gh
		var head: float = fmod(t * speed + float(h % 1000) * 3.0, span)
		var tint: Color = CYAN
		if h % 9 == 0:
			tint = PINK
		elif h % 13 == 0:
			tint = YELLOW
		elif h % 3 == 0:
			tint = BLUE.lerp(CYAN, 0.5)
		var x: float = float(k) * step
		for j in len:
			var y: float = head - float(j) * gh
			if y < -gh or y > H:
				continue
			var f: float = 1.0 - float(j) / float(len)
			var a: float = f * f * 0.34
			if a < 0.025:
				continue
			var bits: int = _h(k * 131 + j, int(t * (2.0 + float(h % 3))) + h) & 0x7fff
			var col: Color = _a(tint, a)
			if j == 0:
				col = _a(WHITE.lerp(tint, 0.35), 0.75)
			_glyph(v, x, y, p, bits, col)

## ---------------------------------------------------------------------------------------------------------------- walls and gaps
static func _is_wall(t: int) -> bool:
	return t == CG.WALL or t == CG.EARTH or t == CG.GLASS or t == CG.RAILING

static func _tile_at(g, base: int, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= g.size or y >= g.size:
		return CG.AIR
	return g.city.tiles[base + y * g.size + x]

static func _cells(v, g, ox: int, oy: int, T: int, S: float, base: int, pcx: int, pcy: int, R: int, t: float) -> void:
	var wave: float = fmod(t * 7.0, float(R) + 8.0)
	var lw: float = float(T)
	# the gaps first
	for sy in v.rows:
		for sx in v.cols:
			var x: int = ox + sx
			var y: int = oy + sy
			var d: int = maxi(absi(x - pcx), absi(y - pcy))
			if d > R:
				continue
			var tt: int = _tile_at(g, base, x, y)
			if tt == CG.AIR or _is_wall(tt):
				continue
			var inside: bool = tt == CG.FLOOR or tt == CG.DOOR or tt == CG.LOCKED or tt == CG.STAIRS or tt == CG.ELEVATOR or (tt >= CG.EXTRA0 and CG.is_floor(tt)) or base > 0
			var col: Color = Color(0.10, 0.20, 0.62) if inside else Color(0.04, 0.34, 0.50)
			if tt == CG.WATER:
				col = Color(0.20, 0.10, 0.60)
			var dd: float = sqrt(float((x - pcx) * (x - pcx) + (y - pcy) * (y - pcy)))
			var sweep: float = clampf(1.0 - absf(dd - wave) / 1.8, 0.0, 1.0)
			var fade: float = 1.0 - 0.45 * float(d) / float(maxi(1, R))
			var a: float = (0.30 + 0.12 * sin(float(x * 3 + y * 5) * 0.9 + t * 1.3)) * fade + sweep * 0.30
			var r := Rect2(float(sx * T) + 2.0, float(sy * T) + 2.0, lw - 4.0, lw - 4.0)
			v.draw_rect(r, _a(col, a))
			v.draw_rect(Rect2(r.position, Vector2(lw - 4.0, maxf(1.0, S * 0.7))), _a(col.lerp(CYAN, 0.5), a * 0.8 + sweep * 0.4))
			if (x + y) % 4 == 0:
				var c: Vector2 = r.get_center()
				v.draw_rect(Rect2(c.x - 1.0, c.y - 1.0, 2.0, 2.0), _a(CYAN, 0.30 * fade + sweep * 0.5))
	# the walls on top: thick, faint, joined into runs
	for sy in v.rows:
		for sx in v.cols:
			var x2: int = ox + sx
			var y2: int = oy + sy
			if maxi(absi(x2 - pcx), absi(y2 - pcy)) > R:
				continue
			var tw: int = _tile_at(g, base, x2, y2)
			if not _is_wall(tw):
				continue
			var glass: bool = tw == CG.GLASS or tw == CG.RAILING
			var c2 := Vector2((float(sx) + 0.5) * lw, (float(sy) + 0.5) * lw)
			var core: Color = PINK if glass else CYAN
			var mid: Color = Color(0.55, 0.20, 0.85) if glass else BLUE
			var pulse: float = 0.75 + 0.25 * sin(t * 1.7 + float(x2 + y2) * 0.4)
			var nb: Array = []
			if _is_wall(_tile_at(g, base, x2 + 1, y2)):
				nb.append(Vector2(lw, 0.0))
			if _is_wall(_tile_at(g, base, x2, y2 + 1)):
				nb.append(Vector2(0.0, lw))
			for layer in 3:
				var wd: float = [lw * 0.50, lw * 0.30, maxf(2.0, lw * 0.10)][layer]
				var cl: Color = [_a(mid, 0.10 * pulse), _a(mid, 0.24 * pulse), _a(core, 0.50 * pulse)][layer]
				v.draw_rect(Rect2(c2 - Vector2(wd, wd) * 0.5, Vector2(wd, wd)), cl)
				for o in nb:
					var o2: Vector2 = o
					var q0: Vector2 = c2
					var q1: Vector2 = c2 + o2
					v.draw_rect(Rect2(minf(q0.x, q1.x) - (wd * 0.5 if o2.y != 0.0 else 0.0), minf(q0.y, q1.y) - (wd * 0.5 if o2.x != 0.0 else 0.0),
						absf(o2.x) + (wd if o2.y != 0.0 else 0.0), absf(o2.y) + (wd if o2.x != 0.0 else 0.0)), cl)

## ---------------------------------------------------------------------------------------------------------------- range frames
static func _dash_rect(v, r: Rect2, col: Color, w: float, dash: float, phase: float) -> void:
	var pts: Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var L: float = a.distance_to(b)
		var dirv: Vector2 = (b - a) / maxf(L, 0.001)
		var s: float = fmod(phase, dash * 2.0) - dash * 2.0
		while s < L:
			var s0: float = maxf(0.0, s)
			var s1: float = minf(L, s + dash)
			if s1 > s0:
				v.draw_line(a + dirv * s0, a + dirv * s1, col, w)
			s += dash * 2.0

static func _frames(v, g, ox: int, oy: int, T: int, S: float, pcx: int, pcy: int, R: int, t: float) -> void:
	var f := float(T)
	var rs := Rect2(float(pcx - R - ox) * f, float(pcy - R - oy) * f, float(2 * R + 1) * f, float(2 * R + 1) * f)
	v.draw_rect(rs, _a(CYAN, 0.55), false, maxf(2.0, S * 1.2))
	v.draw_rect(rs.grow(S * 2.5), _a(CYAN, 0.14), false, maxf(1.0, S))
	var L: int = NW.link_radius(g)
	var rl := Rect2(float(pcx - L - ox) * f, float(pcy - L - oy) * f, float(2 * L + 1) * f, float(2 * L + 1) * f)
	_dash_rect(v, rl, _a(PINK, 0.85), maxf(2.0, S * 1.3), f * 0.35, t * f * 1.2)
	_dash_rect(v, rl.grow(S * 2.0), _a(PINK, 0.25), maxf(1.0, S * 0.8), f * 0.35, -t * f * 0.8)

## ---------------------------------------------------------------------------------------------------------------- pings
static func _diamond(v, c: Vector2, r: float, col: Color) -> void:
	v.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)

static func _text(v, pos: Vector2, s: String, size: int, col: Color) -> void:
	var f: Font = v.font
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = pos - Vector2(w * 0.5, 0.0)
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1)]:
		v.draw_string(f, p + o * 1.5, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.0, 0.0, 0.05, 0.95))
	v.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func _ping(v, g, p: Dictionary, c: Vector2, T: int, S: float, t: float) -> void:
	var f := float(T)
	var h: int = _h(int(p["cell"]), 3)
	var ph: float = fmod(t * 0.55 + float(h % 100) / 100.0, 1.0)
	var key: String = String(p["key"])
	# glow
	v.draw_circle(c, f * 0.95, _a(PINK, 0.05))
	v.draw_circle(c, f * 0.62, _a(PINK, 0.09))
	v.draw_circle(c, f * 0.36, _a(YELLOW, 0.14))
	# two pulses going out
	for k in 2:
		var q: float = fmod(ph + float(k) * 0.5, 1.0)
		var col: Color = PINK if k == 0 else YELLOW
		v.draw_arc(c, f * (0.22 + 1.05 * q), 0.0, TAU, 40, _a(col, (1.0 - q) * 0.85), maxf(1.5, S * (1.6 - q)), false)
	# the body: a bright diamond with a hot centre and four ticks
	_diamond(v, c, f * 0.27, _a(YELLOW, 0.95))
	_diamond(v, c, f * 0.18, _a(Color(1.0, 0.55, 0.12), 0.95))
	_diamond(v, c, f * 0.09, WHITE)
	for a in 4:
		var d := Vector2(1, 0).rotated(float(a) * PI * 0.5 + PI * 0.25)
		v.draw_line(c + d * f * 0.34, c + d * f * 0.46, _a(PINK, 0.9), maxf(1.5, S))
	var scanned: bool = NW.is_scanned(g, key)
	var linked: bool = NW.is_linked(g, p)
	if scanned:
		v.draw_circle(c, f * 0.15, _a(RED, 0.30))
		v.draw_circle(c, f * 0.11, RED)
		v.draw_rect(Rect2(c.x - f * 0.05, c.y - f * 0.06, maxf(2.0, S), maxf(2.0, S)), _a(WHITE, 0.9))
	if linked:
		var rr: float = f * 0.46
		v.draw_arc(c, rr, 0.0, TAU, 40, _a(GREEN, 0.9), maxf(2.0, S * 1.5), false)
		v.draw_arc(c, rr + S * 3.0, 0.0, TAU, 40, _a(GREEN, 0.25), maxf(1.0, S), false)
		for k in 3:
			var a0: float = t * 1.8 + float(k) * TAU / 3.0
			v.draw_arc(c, rr + S * 6.0, a0, a0 + 0.7, 8, _a(GREEN, 0.8), maxf(2.0, S * 1.4), false)

## the name above a scanned ping, on a dark plate so it reads over anything
static func _label(v, p: Dictionary, c: Vector2, T: int, S: float) -> void:
	var f: Font = v.font
	var size: int = maxi(13, int(S * 10.0))
	var lines: Array = [String(p["name"])]
	if String(p["kind"]) == "human":
		lines = ["Implanted Human"]
		for nm in p["detail"]:
			lines.append(String(nm))
	var lh: float = float(size) + 4.0
	var wmax := 0.0
	for l in lines:
		wmax = maxf(wmax, f.get_string_size(String(l), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var h: float = lh * float(lines.size()) + 4.0
	var top: float = c.y - float(T) * 0.62 - h
	var plate := Rect2(c.x - wmax * 0.5 - 8.0, top, wmax + 16.0, h)
	v.draw_rect(plate, Color(0.0, 0.01, 0.06, 0.78))
	v.draw_rect(plate, _a(CYAN, 0.55), false, maxf(1.0, S * 0.7))
	v.draw_rect(Rect2(plate.position.x, plate.position.y, 3.0, plate.size.y), _a(PINK, 0.9))
	v.draw_line(Vector2(c.x, plate.end.y), Vector2(c.x, c.y - float(T) * 0.3), _a(CYAN, 0.5), maxf(1.0, S * 0.7))
	for k in lines.size():
		var col: Color = CYAN if k == 0 else YELLOW
		v.draw_string(f, Vector2(c.x - wmax * 0.5, top + 2.0 + lh * float(k + 1) - 5.0), String(lines[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, size if k == 0 else size - 1, col)

static func _you(v, c: Vector2, T: int, S: float, t: float) -> void:
	var f := float(T)
	for k in 3:
		var q: float = fmod(t * 0.4 + float(k) / 3.0, 1.0)
		v.draw_arc(c, f * (0.2 + 0.9 * q), 0.0, TAU, 32, _a(CYAN, (1.0 - q) * 0.6), maxf(1.5, S), false)
	_diamond(v, c, f * 0.22, _a(CYAN, 0.9))
	_diamond(v, c, f * 0.12, WHITE)

static func _cursor(v, g, ox: int, oy: int, T: int, S: float, pcx: int, pcy: int, t: float) -> void:
	var f := float(T)
	var cx: int = pcx + v.look_off.x
	var cy: int = pcy + v.look_off.y
	var c := Vector2((float(cx - ox) + 0.5) * f, (float(cy - oy) + 0.5) * f)
	var on_ping: bool = not NW.ping_at(g, g.pc / g.s2 * g.s2 + cy * g.size + cx).is_empty()
	var col: Color = YELLOW if on_ping else CYAN
	if v.look_off != Vector2i.ZERO:
		v.draw_line(Vector2((float(pcx - ox) + 0.5) * f, (float(pcy - oy) + 0.5) * f), c, _a(col, 0.28), maxf(1.0, S))
	var r: float = f * (0.58 + 0.05 * sin(t * 6.0))
	var arm: float = f * 0.22
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner: Vector2 = c + Vector2(sx * r, sy * r)
			v.draw_line(corner, corner - Vector2(sx * arm, 0.0), col, maxf(2.0, S * 1.6))
			v.draw_line(corner, corner - Vector2(0.0, sy * arm), col, maxf(2.0, S * 1.6))

## ---------------------------------------------------------------------------------------------------------------- finish
static func _scanlines(v, W: float, H: float, S: float, t: float) -> void:
	var step: float = maxf(3.0, S * 2.0)
	var y: float = 0.0
	while y < H:
		v.draw_rect(Rect2(0, y, W, 1.0), Color(0, 0, 0.04, 0.16))
		y += step
	var bar: float = fmod(t * 90.0, H + 160.0) - 80.0
	v.draw_rect(Rect2(0, bar, W, 70.0), _a(CYAN, 0.035))
	v.draw_rect(Rect2(0, bar + 66.0, W, 3.0), _a(CYAN, 0.10))

static func _vignette(v, W: float, H: float) -> void:
	for k in 10:
		var m: float = float(k) * 14.0
		var a: float = 0.05 * float(10 - k)
		var col := Color(0.0, 0.0, 0.03, a)
		v.draw_rect(Rect2(m, m, W - 2.0 * m, H - 2.0 * m), col, false, 14.0)

static func _title(v, g, S: float, t: float) -> void:
	var size: int = maxi(14, int(S * 11.0))
	var f: Font = v.font
	var s := "NETWORK  //  SCAN %d  ·  REACH %d  ·  %d SIGNALS" % [NW.scan_radius(g), NW.link_radius(g), (g.net_snap["pings"] as Array).size()]
	var p := Vector2(18.0, 8.0 + float(size))
	v.draw_string(f, p + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0.05, 0.9))
	v.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, CYAN)
	v.draw_rect(Rect2(18.0, p.y + 6.0, f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, 2.0), _a(PINK, 0.8))
	var blink: float = 0.5 + 0.5 * sin(t * 4.0)
	v.draw_rect(Rect2(8.0, 12.0, 5.0, float(size)), _a(YELLOW, 0.4 + 0.5 * blink))
