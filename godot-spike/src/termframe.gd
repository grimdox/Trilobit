extends Control
## the monitor the Control Board and the network menus sit in: the game dims, a bezelled screen stands in the middle, and the margins fill with a motherboard's
## traces and a slow rain of 0s and 1s.  style "board" = a green-and-cyan computer terminal; style "net" = the neon Matrix screen.  Drawn in the 1280 x 720 play layer.

const MON := Rect2(150.0, 40.0, 980.0, 580.0)            # the whole monitor (bezel included)
const INSET := 26.0                                      # bezel width
const SCREEN := Rect2(176.0, 66.0, 928.0, 528.0)         # the glass
const TEXT := Rect2(194.0, 80.0, 892.0, 500.0)           # where the menu text goes

var style: String = ""                                   # "" = hidden, "board", "net", "popup" (a net menu over the scan map)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0

func _process(_d: float) -> void:
	if style != "":
		queue_redraw()

static func _h(a: int, b: int) -> int:
	var x: int = (a * 73856093) ^ (b * 19349663)
	return absi(x) & 0x7fffffff

static func _pal(style: String) -> Dictionary:
	if style == "board":
		return {"glow": Color(0.35, 1.0, 0.55), "edge": Color(0.25, 0.85, 1.0), "glass": Color(0.01, 0.045, 0.03, 0.97), "trace": Color(0.1, 0.55, 0.4), "via": Color(0.4, 1.0, 0.7), "rain": Color(0.2, 1.0, 0.5)}
	return {"glow": Color(0.3, 0.9, 1.0), "edge": Color(1.0, 0.28, 0.82), "glass": Color(0.006, 0.012, 0.06, 0.97), "trace": Color(0.2, 0.3, 0.9), "via": Color(1.0, 0.3, 0.8), "rain": Color(0.3, 0.9, 1.0)}

func _draw() -> void:
	paint(self, style)

## draws the monitor on any canvas item c (the scan overlay uses it too, with a transform that maps 1280 x 720 onto its own screen)
static func paint(c, style: String, with_glass: bool = true) -> void:
	if style == "":
		return
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var p: Dictionary = _pal(style)
	var glow: Color = p["glow"]
	var edge: Color = p["edge"]
	if style == "popup":                                 # a small neon window over the scan map
		var r := Rect2(300.0, 150.0, 680.0, 420.0)
		c.draw_rect(r.grow(10.0), Color(0, 0, 0.04, 0.55))
		c.draw_rect(r, Color(0.006, 0.012, 0.06, 0.97))
		c.draw_rect(r, edge, false, 2.0)
		c.draw_rect(r.grow(-6.0), Color(glow.r, glow.g, glow.b, 0.45), false, 1.0)
		_corners(c, r, glow)
		return
	c.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0.02, 0.8))      # the game dims behind the monitor
	_board_margin(c, style, p, t)
	# chassis
	c.draw_rect(MON.grow(8.0), Color(0, 0, 0, 0.5))
	c.draw_rect(MON, Color(0.09, 0.1, 0.13), true)
	c.draw_rect(MON, Color(0.32, 0.36, 0.44), false, 3.0)
	c.draw_rect(MON.grow(-5.0), Color(0.04, 0.045, 0.06), false, 2.0)
	c.draw_rect(Rect2(MON.position.x + 4.0, MON.position.y + 4.0, MON.size.x - 8.0, 2.0), Color(1, 1, 1, 0.12))
	for k in 4:                                          # screws
		var sx: float = MON.position.x + (12.0 if k % 2 == 0 else MON.size.x - 12.0)
		var sy: float = MON.position.y + (12.0 if k < 2 else MON.size.y - 12.0)
		c.draw_circle(Vector2(sx, sy), 4.0, Color(0.22, 0.24, 0.3))
		c.draw_line(Vector2(sx - 3.0, sy - 2.0), Vector2(sx + 3.0, sy + 2.0), Color(0.05, 0.05, 0.07), 1.5)
	# the glass
	c.draw_rect(SCREEN, p["glass"])
	c.draw_rect(SCREEN.grow(2.0), Color(glow.r, glow.g, glow.b, 0.25), false, 3.0)
	c.draw_rect(SCREEN, edge, false, 1.5)
	_screen_art(c, style, SCREEN, p, t)
	# power light and label on the bezel
	var blink: float = 0.55 + 0.45 * sin(t * 3.0)
	c.draw_circle(Vector2(MON.end.x - 44.0, MON.end.y - 13.0), 3.5, Color(glow.r, glow.g, glow.b, blink))
	c.draw_string(ThemeDB.fallback_font, Vector2(MON.position.x + 30.0, MON.end.y - 8.0), "TRL-OS  //  NODE TERMINAL" if style == "board" else "TRL-OS  //  NETWORK LINK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.58, 0.68))

static func _corners(c, r: Rect2, col: Color) -> void:
	var l := 16.0
	for q in [[r.position, 1.0, 1.0], [Vector2(r.end.x, r.position.y), -1.0, 1.0], [Vector2(r.position.x, r.end.y), 1.0, -1.0], [r.end, -1.0, -1.0]]:
		var o: Vector2 = q[0]
		c.draw_line(o, o + Vector2(l * float(q[1]), 0), col, 3.0)
		c.draw_line(o, o + Vector2(0, l * float(q[2])), col, 3.0)

## the glass: faint grid, scanlines, a sweeping bar, and for the terminal a prompt line along the bottom
static func _screen_art(c, style: String, r: Rect2, p: Dictionary, t: float) -> void:
	var glow: Color = p["glow"]
	var y: float = r.position.y + 2.0
	while y < r.end.y:
		c.draw_rect(Rect2(r.position.x, y, r.size.x, 1.0), Color(0, 0, 0, 0.22))
		y += 3.0
	var bar: float = r.position.y + fmod(t * 60.0, r.size.y + 80.0) - 40.0
	var top: float = maxf(bar, r.position.y)
	var bot: float = minf(bar + 40.0, r.end.y)
	if bot > top:
		c.draw_rect(Rect2(r.position.x, top, r.size.x, bot - top), Color(glow.r, glow.g, glow.b, 0.04))
	# rain in the screen's own gutters (the text sits in the middle)
	_rain(c, Rect2(r.position.x + 4.0, r.position.y + 4.0, 14.0, r.size.y - 8.0), p, t, 7)
	_rain(c, Rect2(r.end.x - 18.0, r.position.y + 4.0, 14.0, r.size.y - 8.0), p, t, 8)
	if style == "board":
		var cur: String = "_" if int(t * 2.0) % 2 == 0 else " "
		c.draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 22.0, r.end.y - 10.0), "TRL> select an option" + cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(glow.r, glow.g, glow.b, 0.8))

## a column of falling 0s and 1s inside the rect
static func _rain(c, r: Rect2, p: Dictionary, t: float, seed_: int) -> void:
	var col: Color = p["rain"]
	var f: Font = ThemeDB.fallback_font
	var step := 14.0
	var cols: int = maxi(1, int(r.size.x / 12.0))
	var rows: int = int(r.size.y / step)
	for cx in cols:
		var speed: float = 3.0 + float(_h(cx, seed_) % 5)
		var head: float = fmod(t * speed + float(_h(cx, seed_ + 9) % rows), float(rows))
		for k in 9:
			var ry: int = int(head) - k
			if ry < 0:
				ry += rows
			var a: float = (1.0 - float(k) / 9.0) * 0.8
			var ch := "1" if (_h(cx * 31 + ry, seed_ + int(t * 2.0 * (k + 1)) % 5) & 1) == 1 else "0"
			c.draw_string(f, Vector2(r.position.x + float(cx) * 12.0, r.position.y + float(ry) * step + 12.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col.r, col.g, col.b, a) if k > 0 else Color(1, 1, 1, 0.9))

## the dimmed game's margins: motherboard traces with vias and chips, and rain
static func _board_margin(c, style: String, p: Dictionary, t: float) -> void:
	var trace: Color = p["trace"]
	var via: Color = p["via"]
	var rects := [Rect2(0, 0, MON.position.x - 6.0, 720.0), Rect2(MON.end.x + 6.0, 0, 1280.0 - MON.end.x - 6.0, 720.0), Rect2(MON.position.x - 6.0, 0, MON.size.x + 12.0, MON.position.y - 6.0), Rect2(MON.position.x - 6.0, MON.end.y + 6.0, MON.size.x + 12.0, 720.0 - MON.end.y - 6.0)]
	var n := 0
	for r in rects:
		n += 1
		# traces: runs of horizontal/vertical lines with 45 degree jogs, on a 10 px grid
		var lines: int = int(maxf(r.size.x, r.size.y) / 22.0)
		for k in lines:
			var h1: int = _h(k, n * 7)
			var horiz: bool = r.size.x >= r.size.y
			var a: Vector2
			var b: Vector2
			if horiz:
				var yy: float = r.position.y + float((h1 % int(maxf(r.size.y, 10.0) / 10.0)) * 10)
				var x0: float = r.position.x + float(h1 % int(maxf(r.size.x * 0.6, 10.0)))
				a = Vector2(x0, yy)
				b = Vector2(minf(x0 + 40.0 + float(h1 % 120), r.end.x), yy)
			else:
				var xx: float = r.position.x + float((h1 % int(maxf(r.size.x, 10.0) / 10.0)) * 10)
				var y0: float = r.position.y + float(h1 % int(maxf(r.size.y * 0.7, 10.0)))
				a = Vector2(xx, y0)
				b = Vector2(xx, minf(y0 + 40.0 + float(h1 % 140), r.end.y))
			var mid: Vector2 = b + (Vector2(10, 10) if horiz else Vector2(10, 10))
			c.draw_line(a, b, Color(trace.r, trace.g, trace.b, 0.55), 2.0)
			c.draw_line(b, mid, Color(trace.r, trace.g, trace.b, 0.55), 2.0)
			c.draw_circle(a, 3.0, Color(via.r, via.g, via.b, 0.55))
			c.draw_circle(mid, 3.0, Color(via.r, via.g, via.b, 0.35))
			c.draw_circle(mid, 1.2, Color(0, 0, 0, 0.8))
		# a few chips
		for k in 3:
			var h2: int = _h(k + 40, n * 13)
			var cr := Rect2(r.position.x + 10.0 + float(h2 % int(maxf(r.size.x - 70.0, 10.0))), r.position.y + 8.0 + float((h2 / 7) % int(maxf(r.size.y - 50.0, 10.0))), 36.0, 24.0)
			if cr.end.x > r.end.x or cr.end.y > r.end.y:
				continue
			c.draw_rect(cr, Color(0.03, 0.04, 0.07, 0.9))
			c.draw_rect(cr, Color(trace.r, trace.g, trace.b, 0.8), false, 1.5)
			for pin in 5:
				c.draw_rect(Rect2(cr.position.x + 3.0 + float(pin) * 7.0, cr.position.y - 4.0, 2.0, 4.0), Color(via.r, via.g, via.b, 0.6))
				c.draw_rect(Rect2(cr.position.x + 3.0 + float(pin) * 7.0, cr.end.y, 2.0, 4.0), Color(via.r, via.g, via.b, 0.6))
		_rain(c, r, p, t, n * 3)
