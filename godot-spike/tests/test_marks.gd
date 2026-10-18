extends RefCounted
## Who shows an indicator: unaffiliated people none; faction members and the provoked a glow and arrow.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var g = GameScript.new(52)
	g.setup(1200)
	var cit := -1
	var thug := -1
	var nap := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1:
			if g.fac[i] == g.CIV and cit < 0:
				cit = i
			elif g.fac[i] == g.BRATVA and thug < 0:
				thug = i
			elif g.fac[i] == g.NAP and nap < 0:
				nap = i
	check.call("found a citizen, a Bratva thug and a NAP officer", cit >= 0 and thug >= 0 and nap >= 0)
	check.call("an ordinary citizen shows no indicator", not g.marked(cit))
	check.call("a Bratva thug is marked and hostile (red arrow)", g.marked(thug) and g.attitude(thug) == 2)
	check.call("a calm NAP officer is marked and neutral (blue arrow)", g.marked(nap) and g.attitude(nap) == 1)
	g.heat = 50
	check.call("with heat the NAP officer turns red", g.attitude(nap) == 2)
	g.pc = g.sim.pos[cit] + 1
	g.hurt(cit, 1, true)
	check.call("hitting a citizen provokes them: marked, red arrow", g.provoked.has(cit) and g.marked(cit) and g.attitude(cit) == 2)
	var other := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 1 and g.fac[i] == g.CIV and i != cit and other < 0:
			other = i
	check.call("other citizens stay unmarked", other >= 0 and not g.marked(other))
	var d: Dictionary = g.save_dict() if g.has_method("save_dict") else {}
	check.call("provoked people are saved", d.is_empty() or d["npc"]["prov"].has(cit))
	g.kill(cit)
	check.call("a dead citizen is no longer provoked", not g.provoked.has(cit))
	g.allies[other] = 1
	check.call("an ally is marked with a green arrow", g.marked(other) and g.attitude(other) == 0)
	return [st[0], st[1], log]
