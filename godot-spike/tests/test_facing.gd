extends RefCounted
## Facing and the player's half-circle of sight.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const FOV = preload("res://src/fov.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var g = GameScript.new(5)
	g.setup(400)
	# find a street spot with open ground five tiles each way
	var spot := -1
	for y in range(40, g.size - 40, 3):
		for x in range(40, g.size - 40, 3):
			var ok := true
			for k in range(-6, 7):
				if g.sim.walk[y * g.size + x + k] == 0 or g.sim.walk[(y + k) * g.size + x] == 0:
					ok = false
			if ok:
				spot = y * g.size + x
				break
		if spot >= 0:
			break
	check.call("found open ground", spot >= 0)
	g.pc = spot
	g.sim.retier(spot)
	check.call("the base field of view is 180 degrees", g.vision_arc() == 180.0)
	g.facing = Vector2i(0, -1)
	g._compute_fov()
	var ahead: int = spot - 4 * g.size
	var behind: int = spot + 4 * g.size
	var side: int = spot + 4
	check.call("you see ahead", g.fov.visible[ahead] == 1)
	check.call("you do not see behind you", g.fov.visible[behind] == 0)
	check.call("you see straight to the side (the edge of the half circle)", g.fov.visible[side] == 1)
	check.call("behind you is not remembered either", g.fov.explored[behind] == 0)
	check.call("the all-round line of sight (for NPCs looking at you) is not limited", g.fov.around[behind] == 1)
	g.turn_to(0, 1)
	check.call("turning round swaps what you see", g.fov.visible[behind] == 1 and g.fov.visible[ahead] == 0)
	g.facing = Vector2i(1, -1)
	g._compute_fov()
	check.call("facing a diagonal still sees a half plane", g.fov.visible[spot - 3 * g.size + 3] == 1 and g.fov.visible[spot + 3 * g.size - 3] == 0)
	# a wider arc (the hook for rear-view eyes)
	g.fov.compute(spot % g.size, spot / g.size, 18, 360.0, 0, -1)
	check.call("a 360 degree arc sees behind", g.fov.visible[behind] == 1)
	g.fov.compute(spot % g.size, spot / g.size, 18, 270.0, 0, -1)
	check.call("a 270 degree arc sees the sides and a little behind", g.fov.visible[side] == 1 and g.fov.visible[spot + 4 * g.size + 3] == 1 and g.fov.visible[behind] == 0 or g.fov.visible[spot + 4 * g.size + 4] == 1)
	# everyone has a facing
	var bad := 0
	for i in g.sim.alive.size():
		if g.sim.alive[i] == 1 and (int(g.face[i]) < 0 or int(g.face[i]) > 7):
			bad += 1
	check.call("every person has a facing 0..7", bad == 0 and g.face.size() >= g.sim.alive.size())
	var moved := 0
	var tried := 0
	for ki in g.critters.size():
		var k: Dictionary = g.critters[ki]
		if k["k"] == "":
			continue
		var from: int = k["cell"]
		for d in g.DIR8:
			var to: int = from + d[1] * g.size + d[0]
			if g._crit_free(to):
				g._move_crit(ki, to)
				tried += 1
				if g.DIR8[int(k["face"])] == d:
					moved += 1
				break
		if tried >= 3:
			break
	check.call("animals face the way they move (%d of %d)" % [moved, tried], tried == 0 or moved == tried)
	return [st[0], st[1], log]
