extends RefCounted
## Recursive shadowcasting field of view on the tile grid, with a map memory ("explored").
var size: int
var row_lo: int = 0       # the level being looked at: rows [row_lo, row_hi) of the stacked map
var row_hi: int = 0
var opaque: PackedByteArray
var visible: PackedByteArray
var explored: PackedByteArray
var touched: PackedInt32Array = PackedInt32Array()

func setup(sz: int, opaque_map: PackedByteArray) -> void:
	size = sz
	opaque = opaque_map
	visible = PackedByteArray(); visible.resize(opaque_map.size())
	explored = PackedByteArray(); explored.resize(opaque_map.size())
	row_hi = size

func compute(cx: int, cy: int, radius: int) -> void:
	for c in touched:
		visible[c] = 0
	touched.clear()
	row_lo = (cy / size) * size       # one level at a time: cy is a row of the stacked map
	row_hi = row_lo + size
	_mark(cx, cy)
	for oct in 8:
		_scan(cx, cy, 1, 1.0, 0.0, radius, oct)

func _mark(x: int, y: int) -> void:
	var c := y * size + x
	if visible[c] == 0:
		visible[c] = 1
		explored[c] = 1
		touched.append(c)

const MULT := [[1, 0, 0, -1, -1, 0, 0, 1], [0, 1, -1, 0, 0, -1, 1, 0], [0, 1, 1, 0, 0, -1, -1, 0], [1, 0, 0, 1, -1, 0, 0, -1]]

func _scan(cx: int, cy: int, row: int, start: float, end: float, radius: int, oct: int) -> void:
	if start < end:
		return
	var r2 := radius * radius
	var new_start := start
	var blocked := false
	var j := row
	while j <= radius and not blocked:
		var dx := -j - 1
		var dy := -j
		while dx <= 0:
			dx += 1
			var X: int = cx + dx * MULT[0][oct] + dy * MULT[1][oct]
			var Y: int = cy + dx * MULT[2][oct] + dy * MULT[3][oct]
			var l_slope := (dx - 0.5) / (dy + 0.5)
			var r_slope := (dx + 0.5) / (dy - 0.5)
			if start < r_slope:
				continue
			elif end > l_slope:
				break
			if X < 0 or Y < row_lo or X >= size or Y >= row_hi:
				continue
			if dx * dx + dy * dy <= r2:
				_mark(X, Y)
			var op := opaque[Y * size + X] == 1
			if blocked:
				if op:
					new_start = r_slope
					continue
				else:
					blocked = false
					start = new_start
			elif op and j < radius:
				blocked = true
				_scan(cx, cy, j + 1, start, l_slope, radius, oct)
				new_start = r_slope
		j += 1

func sees(c: int) -> bool:
	return visible[c] == 1
