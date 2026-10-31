extends Node2D
## The animated part of the weather, drawn over the map: rain streaks falling on the open ground the player can see, and the white flash of a lightning strike.
## The view hands it what to draw each time it redraws; it keeps animating between turns.
var rain := 0.0                     # 0..1
var flash := 0.0                    # 1 right after a strike, fading
var tile := 61.0
var cols := 0
var rows := 0
var outdoor := PackedByteArray()    # 1 for each visible tile of the open air (cols x rows)
var wind := 0.35
var t := 0.0
var _shown := -1.0                   # the rain last drawn: when it changes (it stops, say) the layer is drawn once more

func _process(delta: float) -> void:
	t += delta
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 3.0)
	if rain > 0.0 or flash > 0.0 or rain != _shown:
		_shown = rain
		queue_redraw()

## the part of the segment a-b that lies inside the rectangle (Liang-Barsky), or an empty array if none: a raindrop is drawn only on the tile it falls on
static func clip(a: Vector2, b: Vector2, r: Rect2) -> PackedVector2Array:
	var t0 := 0.0
	var t1 := 1.0
	var d: Vector2 = b - a
	var p: Array = [-d.x, d.x, -d.y, d.y]
	var q: Array = [a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y]
	for k in 4:
		if absf(float(p[k])) < 0.00001:
			if float(q[k]) < 0.0:
				return PackedVector2Array()
		else:
			var u: float = float(q[k]) / float(p[k])
			if float(p[k]) < 0.0:
				t0 = maxf(t0, u)
			else:
				t1 = minf(t1, u)
	if t0 >= t1:
		return PackedVector2Array()
	return PackedVector2Array([a + d * t0, a + d * t1])

func _draw() -> void:
	if rain > 0.0 and outdoor.size() == cols * rows:
		var far := PackedVector2Array()                 # thin, faint, slow drops (the distance)
		var near := PackedVector2Array()                # longer, brighter, faster drops (close to the eye)
		var wet: float = 0.07 * rain
		var lw: float = maxf(1.0, tile / 36.0)
		for i in outdoor.size():
			if outdoor[i] == 0:
				continue
			var x0: float = float(i % cols) * tile
			var y0: float = float(i / cols) * tile
			var box := Rect2(x0, y0, tile, tile)
			draw_rect(box, Color(0.08, 0.13, 0.24, wet))               # wet ground, a little darker
			for k in 3:
				var h: int = (i * 73856093 + k * 19349663) & 0xffff
				if float(h % 100) / 100.0 > rain * 0.9 + 0.2:
					continue
				var is_near: bool = k == 2 or (k == 1 and rain > 0.7)
				var speed: float = (1.1 + 0.9 * rain) * (1.55 if is_near else 1.0)
				var ln: float = tile * (0.16 + 0.16 * rain) * (1.7 if is_near else 1.0)
				var ph: float = fmod(t * speed + float(h) / 65535.0, 1.0)
				var sx: float = x0 + float((h >> 3) % 100) / 100.0 * tile
				var sy: float = y0 + ph * tile * 1.3 - tile * 0.3
				var cl: PackedVector2Array = clip(Vector2(sx, sy), Vector2(sx - wind * ln, sy + ln), box)       # (a streak never leaves its tile: none falls on a wall or indoors)
				if cl.size() == 2:
					var dst: PackedVector2Array = near if is_near else far
					dst.append(cl[0])
					dst.append(cl[1])
				if is_near and ph > 0.86:                                # the drop lands: a small ripple that spreads and fades
					var u: float = (ph - 0.86) / 0.14
					var cx: float = clampf(sx - wind * ln, x0 + 2.0, x0 + tile - 2.0)
					var cy: float = y0 + tile * (0.5 + 0.4 * float((h >> 5) % 100) / 100.0)
					draw_arc(Vector2(cx, cy), 1.0 + u * tile * 0.12, 0.0, TAU, 10, Color(0.85, 0.93, 1.0, 0.38 * (1.0 - u)), 1.0)
		if far.size() > 0:
			draw_multiline(far, Color(0.62, 0.74, 0.95, 0.2), lw)
		if near.size() > 0:
			draw_multiline(near, Color(0.84, 0.92, 1.0, 0.46), lw * 1.2)
	if flash > 0.0:
		draw_rect(Rect2(-200, -200, cols * tile + 400, rows * tile + 400), Color(0.9, 0.93, 1.0, 0.55 * flash))
