extends SceneTree
const CG = preload("res://src/citygen.gd")
const ISL = preload("res://src/island.gd")
func _init() -> void:
	for sd in [1, 2, 3, 7, 11, 99]:
		var isl = ISL.new(sd)
		var c = isl.build_zone(1, 1)
		var cnt := {}
		for v in c.venues:
			cnt[v["kind"]] = cnt.get(v["kind"], 0) + 1
		var t = isl.build_zone(ISL.TOWN_ZONE.x, ISL.TOWN_ZONE.y)
		var tc := {}
		for v in t.venues:
			tc[v["kind"]] = tc.get(v["kind"], 0) + 1
		print("seed ", sd, " city ", c.venues.size(), " ", cnt, " left ", c.venue_plan.size(), " | town ", t.venues.size(), " ", tc, " left ", t.venue_plan.size())
	quit(0)
