extends RefCounted
## The city map kept on disk is exactly the map that is generated: every property of a map read back equals a freshly generated one, and so does its
## random-number state.  A stale file (an older version of the code) is not read.  Returns [passed, total, log]
const ISL = preload("res://src/island.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var a = ISL.new(7)
	var z: Vector2i = a.CITY_ZONE
	var path: String = a._gen_path(z.x, z.y)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var t0 := Time.get_ticks_msec()
	var first = a.build_zone_cached(z.x, z.y)             # generates and writes
	var t1 := Time.get_ticks_msec()
	check.call("the first build writes the file", FileAccess.file_exists(path))
	var second = a.build_zone_cached(z.x, z.y)            # reads
	var t2 := Time.get_ticks_msec()
	log.append("  (generate and write %d ms, read %d ms)" % [t1 - t0, t2 - t1])
	check.call("reading it back is much quicker than generating it", t2 - t1 < (t1 - t0) / 3)
	var fresh = a.build_zone(z.x, z.y)
	var diff := ""
	for k in a._cache_props(fresh):
		if fresh.get(k) != second.get(k):
			diff += k + " "
	check.call("every property of the map read back equals a fresh one (differing: %s)" % diff, diff == "")
	check.call("so does the random-number state", fresh.rng.seed == second.rng.seed and fresh.rng.state == second.rng.state and fresh.rng.randi() == second.rng.randi())
	var other = ISL.new(8)
	check.call("another seed has its own file", other._gen_path(z.x, z.y) != path)
	return [st[0], st[1], log]
