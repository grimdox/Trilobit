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
		var segs := PackedVector2Array()
		var per: int = 1 if rain < 0.55 else 2
		var len_: float = tile * (0.32 + 0.3 * rain)
		var speed: float = 1.6 + 1.4 * rain
		for i in outdoor.size():
			if outdoor[i] == 0:
				continue
			var x0: float = float(i % cols) * tile
			var y0: float = float(i / cols) * tile
			for k in per:
				var h: int = (i * 73856093 + k * 19349663) & 0xffff
				if float(h % 100) / 100.0 > rain + 0.25:
					continue
				var ph: float = fmod(t * speed + float(h) / 65535.0, 1.0)
				var sx: float = x0 + float((h >> 3) % 100) / 100.0 * tile
				var sy: float = y0 + ph * tile * 1.3 - tile * 0.3
				var cl: PackedVector2Array = clip(Vector2(sx, sy), Vector2(sx - wind * len_, sy + len_), Rect2(x0, y0, tile, tile))     # (a streak never leaves its tile: none falls on a wall or indoors)
				if cl.size() == 2:
					segs.append(cl[0])
					segs.append(cl[1])
		if segs.size() > 0:
			draw_multiline(segs, Color(0.72, 0.82, 1.0, 0.42), maxf(1.0, tile / 30.0))
	if flash > 0.0:
		draw_rect(Rect2(-200, -200, cols * tile + 400, rows * tile + 400), Color(0.9, 0.93, 1.0, 0.55 * flash))
