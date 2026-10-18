extends RefCounted
## Hunger and thirst placeholders.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const ItemScript = preload("res://src/item.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var g = GameScript.new(5)
	g.setup(300)
	var spot := -1
	for y in range(40, g.size - 40, 3):
		for x in range(40, g.size - 40, 3):
			var ok := true
			for k in range(0, 60):
				if g.sim.walk[y * g.size + x + k] == 0 or g.sim.at[y * g.size + x + k] != -1:
					ok = false
					break
			if ok:
				spot = y * g.size + x
				break
		if spot >= 0:
			break
	check.call("found a long straight to walk", spot >= 0)
	g.pc = spot
	g.sim.retier(g.pc)
	check.call("a fresh character is neither hungry nor thirsty", not g.hungry() and not g.thirsty() and g.status_effects().is_empty() and is_equal_approx(g.speed_mult(), 1.0))
	var t0: int = g.sim.tick
	g.sim.tick = t0 + 4 * 600 - 1
	check.call("just under 4 hours: not thirsty", not g.thirsty())
	g.end_turn()
	check.call("after 4 hours without a drink you are Thirsty", g.thirsty() and not g.hungry() and g.status_effects() == ["Thirsty"])
	check.call("thirst costs 20% of your speed", is_equal_approx(g.speed_mult(), 0.8))
	# walk ten steps and count the turns
	var turn0: int = g.turn
	for k in 20:
		g.act_move(1, 0)
	var spent: int = g.turn - turn0
	check.call("20 steps while thirsty take 25 turns (%d)" % spent, spent == 25)
	var db = g.db
	var drink_id := ""
	for id in db.defs:
		if db.defs[id].get("food", {}).get("drink", false):
			drink_id = id
			break
	var drink = ItemScript.new(db.defs[drink_id], 1)
	g.eat_now(drink)
	check.call("drinking (%s) quenches thirst" % drink_id, drink_id != "" and not g.thirsty())
	g.sim.tick = g.last_ate + 24 * 600
	g.last_drank = g.sim.tick
	g.end_turn()
	check.call("after 24 hours without food you are Hungry", g.hungry() and not g.thirsty() and g.status_effects() == ["Hungry"])
	g.sim.tick = g.last_drank + 4 * 600
	g.end_turn()
	check.call("both at once stack to 64% speed", g.hungry() and g.thirsty() and is_equal_approx(g.speed_mult(), 0.64))
	turn0 = g.turn
	for k in 16:
		g.act_move(1, 0)
	spent = g.turn - turn0
	check.call("16 steps hungry and thirsty take 25 turns (%d)" % spent, spent >= 24 and spent <= 25)
	var food = ItemScript.new(db.defs["trl_ration"], 1)
	g.eat_now(food)
	check.call("eating clears hunger but not thirst", not g.hungry() and g.thirsty())
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = GameScript.new(5)
	g2.setup(300)
	g2.load_dict(d)
	check.call("save and load keep the clocks", g2.last_ate == g.last_ate and g2.last_drank == g.last_drank and g2.thirsty() and not g2.hungry())
	return [st[0], st[1], log]
