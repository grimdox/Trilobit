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

func _process(delta: float) -> void:
	t += delta
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 3.0)
	if rain > 0.0 or flash > 0.0:
		queue_redraw()

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
				segs.append(Vector2(sx, sy))
				segs.append(Vector2(sx - wind * len_, sy + len_))
		if segs.size() > 0:
			draw_multiline(segs, Color(0.72, 0.82, 1.0, 0.42), maxf(1.0, tile / 30.0))
	if flash > 0.0:
		draw_rect(Rect2(-200, -200, cols * tile + 400, rows * tile + 400), Color(0.9, 0.93, 1.0, 0.55 * flash))
