extends SceneTree
## random play for a few thousand turns, hopping between levels; any script error shows up in the output
const GameScript = preload("res://src/game.gd")
func _init() -> void:
	var tot_turns := 0
	for seed in [3, 11]:
		var g = GameScript.new(seed)
		g.setup(1200)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var spots: Array = []
		spots.append_array(Array(g.city.lairs).slice(0, 6))
		for t in g.city.tower_info:
			spots.append(int(t["stairs"]) + rng.randi_range(1, int(t["h"])) * g.s2)
		spots.append(g.pc)
		for step in 3000:
			if step % 150 == 0:
				g.pc = spots[rng.randi() % spots.size()]
				g.sim.at[g.pc] = -1
				g.sim.retier(g.pc)
				g.hp = g.hp_max
				g.game_over = false
			match rng.randi() % 14:
				0, 1, 2, 3, 4, 5: g.act_move(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
				6: g.act_vertical(1)
				7: g.act_vertical(-1)
				8: g.act_pickup()
				9: g.act_fire(true)
				10: g.act_steal()
				11:
					var w: int = g.talk_target()
					if w >= 0:
						var m: Dictionary = g.eco.menu_for(w)
						g.eco.choose(m, rng.randi() % m["options"].size())
				12: g.act_wait()
				_: g.act_pay(100)
			g.hp = maxi(g.hp, 5)
			tot_turns += 1
		print("seed %d ok: turn %d, debt %d, jobs %d, heat %d" % [seed, g.turn, g.eco.debt, g.eco.jobs_done, g.heat])
	print("SOAK %d/%d" % [tot_turns, 6000])
	quit(0)
