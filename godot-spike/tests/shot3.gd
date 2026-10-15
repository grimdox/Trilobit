extends SceneTree
## screenshots of the vertical world: a tower floor, the roof, the subway platform with the train, the sewers
func snap(main, name: String) -> void:
	main.refresh()
	await create_timer(0.35).timeout
	root.get_texture().get_image().save_png("/tmp/claude-0/v_%s.png" % name)

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	var g = main.game
	var tall: Dictionary = {}
	for t in g.city.tower_info:
		if tall.is_empty() or int(t["h"]) > int(tall["h"]):
			tall = t
	# a mid floor of the tallest tower, stood at the stairs
	g.pc = int(tall["stairs"]) + 14 * g.s2
	g.sim.retier(g.pc)
	g.end_turn()
	await snap(main, "floor14")
	# the roof, by the elevator
	g.pc = int(tall["elev"]) + 30 * g.s2
	g.sim.retier(g.pc)
	g.end_turn()
	await snap(main, "roof")
	# a bridge level: floor 20 near the tower edge
	g.pc = int(tall["stairs"]) + 2 * g.s2
	g.end_turn()
	await snap(main, "floor2")
	# the subway: wait for the train, stand on the platform beside it
	var tr = g.transit
	var guard := 0
	while tr.dwell == 0 and guard < 400:
		tr.step()
		guard += 1
	var car: int = tr.car_cell(1)
	for nb in [car - 1, car + 1, car - g.size, car + g.size]:
		if g.city.tiles[nb] == 13:
			g.pc = nb
	g.sim.retier(g.pc)
	g.end_turn()
	tr.dwell = 4
	await snap(main, "subway")
	# the sewers
	g.pc = g.city.lairs[3]
	g.sim.retier(g.pc)
	for k in 3:
		g.end_turn()
	await snap(main, "sewer")
	print("log: ", g.log.slice(-6))
	quit()
