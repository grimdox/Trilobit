extends RefCounted
## A helicopter on a tower roof of the 1536 island city: you climb in, lift off, fly clear of the building and set it down on the street.
## Returns [passed, total, log]
const World = preload("res://src/world.gd")
const CG = preload("res://src/citygen.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var w = World.new()
	w.start(7, 300)
	var g = w.game
	var hv := -1
	for k in g.vehicles.size():                               # (the one on the highest roof: the tallest tower)
		if g.vehicles[k]["kind"] == "heli" and g.z_of(g.vehicles[k]["cell"]) > 0 and (hv < 0 or g.z_of(g.vehicles[k]["cell"]) > g.z_of(g.vehicles[hv]["cell"])):
			hv = k
	check.call("a helicopter stands on a tower roof of the island city (map %d)" % g.size, hv >= 0 and g.size == 1536)
	if hv < 0:
		return [st[0], st[1], log]
	var tallest := 0
	for ti in g.city.tower_info:
		tallest = maxi(tallest, int(ti["h"]))
	check.call("there is open air above the tallest roof (tallest %d floors, top level %d)" % [tallest, g.city.zmax], g.city.zmax >= tallest + 3 and tallest <= 17)
	var hel: Dictionary = g.vehicles[hv]
	var roof_z: int = g.z_of(hel["cell"])
	# the tower it stands on, and the way into the cockpit from the roof
	var spot := -1
	for c in g.vs.cells(hel):
		for d in g.SIZE_DIRS:
			var nc: int = c + d[1] * g.size + d[0]
			if g.veh_at.g(nc) == -1 and g.sim.walk[nc] == 1 and g.sim.at[nc] == -1:
				spot = nc
	check.call("there is roof to stand on beside it", spot >= 0)
	g.pc = spot
	g.sim.retier(g.pc)
	check.call("you climb into it on the roof", g.act_vehicle() and g.in_vehicle == hv and g.z_of(g.pc) == roof_z)
	check.call("up lifts it off the roof", g.act_vertical(1) and hel["air"] and g.z_of(hel["cell"]) == roof_z + 1)
	# fly (east, west, south, north in turn) until there is clear air all the way down to the street below the helicopter
	var cleared := false
	var cell0: int = hel["cell"]
	var column_clear := func() -> bool:
		var lv: int = g.z_of(hel["cell"])
		for l in range(1, lv):
			if not g.vs.probe(hv, int(hel["cell"]) - l * g.s2, int(hel["dir"]), true).is_empty():
				return false
		return g.vs.probe(hv, int(hel["cell"]) - lv * g.s2, int(hel["dir"]), false).is_empty()
	for dir in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		g.vs.put(hv, cell0, int(hel["dir"]))
		for k in 120:
			if column_clear.call():
				cleared = true
				break
			if not g.act_move(dir[0], dir[1]):
				break
		if cleared:
			break
	check.call("it flies clear of the building to an open shaft down to the street (moved %d cells)" % g.cheb(cell0, hel["cell"]), cleared and hel["cell"] != cell0)
	# come down: through the air floors to the ground
	var tries := 0
	while hel["air"] and tries < 80:
		tries += 1
		g.act_vertical(-1)
	check.call("it descends and sets down at ground level (level %d, %d tries)" % [g.z_of(hel["cell"]), tries], not hel["air"] and g.z_of(hel["cell"]) == 0)
	check.call("the player is in it, on the ground, and the vehicle map agrees", g.in_vehicle == hv and g.z_of(g.pc) == 0 and g.veh_at.g(hel["cell"]) == hv)
	return [st[0], st[1], log]
