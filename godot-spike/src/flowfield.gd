extends RefCounted
## Multi-source BFS distance field over a tile map: one field serves every agent heading for "the nearest work", "the nearest shop", etc.
## Agents step to the neighbouring tile with the lowest value.  This is what makes thousands of NPCs cheap compared with one path search each.
## The map may be several levels stacked in one array (level n occupies cells n*size*size ..); `links` joins cells on different levels
## (stairs, elevators, ladders), so the field flows through them like any other step.
const UNREACHED := 0x3fffffff

static func build(tiles: PackedByteArray, size: int, walk: PackedByteArray, sources: PackedInt32Array, links: Dictionary = {}, haslink: PackedByteArray = PackedByteArray()) -> PackedInt32Array:
	var total := walk.size()
	var dist := PackedInt32Array()
	dist.resize(total)
	dist.fill(UNREACHED)
	var q := PackedInt32Array()
	for s in sources:
		if dist[s] != 0:
			dist[s] = 0
			q.append(s)
	var use_links := haslink.size() == total
	var head := 0
	while head < q.size():
		var cur := q[head]
		head += 1
		var d := dist[cur] + 1
		var cx := cur % size
		if cx > 0 and walk[cur - 1] == 1 and dist[cur - 1] > d:
			dist[cur - 1] = d
			q.append(cur - 1)
		if cx < size - 1 and walk[cur + 1] == 1 and dist[cur + 1] > d:
			dist[cur + 1] = d
			q.append(cur + 1)
		if cur >= size and walk[cur - size] == 1 and dist[cur - size] > d:
			dist[cur - size] = d
			q.append(cur - size)
		if cur + size < total and walk[cur + size] == 1 and dist[cur + size] > d:
			dist[cur + size] = d
			q.append(cur + size)
		if use_links and haslink[cur] == 1:
			for nb in links[cur]:
				if walk[nb] == 1 and dist[nb] > d:
					dist[nb] = d
					q.append(nb)
	return dist
