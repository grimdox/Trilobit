extends SceneTree
## memory / time of a stand-alone city of a given side:  godot --headless -s tests/bench_standalone.gd -- <side> <people>
const GameScript = preload("res://src/game.gd")
func _initialize() -> void:
	var side := int(OS.get_cmdline_user_args()[0])
	var people := int(OS.get_cmdline_user_args()[1])
	var t0 := Time.get_ticks_msec()
	var g = GameScript.new(21)
	g.test_size = side
	g.setup(people)
	var t_start := Time.get_ticks_msec() - t0
	var times := []
	for i in 40:
		var a := Time.get_ticks_usec()
		g.act_wait()
		times.append((Time.get_ticks_usec() - a) / 1000.0)
	times.sort()
	var sum := 0.0
	for v in times:
		sum += v
	print("RESULT side=%d people=%d size=%d start_ms=%d turn_avg_ms=%.2f turn_p95_ms=%.2f npcs=%d towers=%d buildings=%d" % [side, people, g.size, t_start, sum / times.size(), times[int(times.size() * 0.95)], g.sim.n, g.city.towers.size(), g.city.buildings])
	quit()
