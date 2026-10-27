extends RefCounted
## A per-cell int map that is almost entirely -1 (nothing there): the vehicle, thing and creature on each cell.  Only the occupied cells are stored,
## so a 1536 city's 50-million-cell stack does not cost 200 MB per map.  Read with g(cell) (-1 if empty), write with s(cell, value) (-1 clears).
## (GDScript cannot make an object answer a[i], so these are methods.)
var d: Dictionary = {}
var n: int = 0                          # how many cells the map covers (the bound the old arrays had)

func _init(cells: int = 0) -> void:
	n = cells

func g(i: int) -> int:
	return d.get(i, -1)

func s(i: int, v: int) -> void:
	if v == -1:
		d.erase(i)
	else:
		d[i] = v

func clear() -> void:
	d.clear()

func duplicate_map():
	var o = get_script().new(n)
	o.d = d.duplicate()
	return o
