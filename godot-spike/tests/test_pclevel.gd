extends RefCounted
## Character levels: the requirement table, automatic level-up, attribute points, saves.
const GameScript = preload("res://src/game.gd")
const SK = preload("res://src/skills.gd")

func run() -> Array:
	var cnt: Array = [0, 0]
	var log: Array = []
	var check := func(label: String, ok: bool) -> void:
		cnt[1] += 1
		if ok:
			cnt[0] += 1
		else:
			log.append("  FAIL " + label)
	var ids: Array = SK.skill_ids()
	var mk := func(levels: Array) -> Dictionary:
		var d := SK.default_skills()
		for k in levels.size():
			d[ids[k]] = levels[k]
		return d
	check.call("no skills, no level", SK.level_for(SK.default_skills()) == 0)
	check.call("level 1: one skill at 1", SK.level_for(mk.call([1])) == 1)
	check.call("level 2 needs a 2 and a 1", SK.level_for(mk.call([2])) == 1 and SK.level_for(mk.call([2, 1])) == 2)
	check.call("level 3: 3, 2, 1", SK.level_for(mk.call([3, 2, 1])) == 3 and SK.level_for(mk.call([3, 2])) == 2)
	check.call("level 4: 4, 2, 2", SK.level_for(mk.call([4, 2, 2])) == 4 and SK.level_for(mk.call([4, 2, 1])) == 3)
	check.call("level 5: 5, 3, 2, 2", SK.level_for(mk.call([5, 3, 2, 2])) == 5 and SK.level_for(mk.call([5, 3, 2])) == 4)
	check.call("level 6: 6, 3, 3, 3", SK.level_for(mk.call([6, 3, 3, 3])) == 6 and SK.level_for(mk.call([6, 3, 3, 2])) == 5)
	check.call("level 7: 7, 4, 4, 3, 3", SK.level_for(mk.call([7, 4, 4, 3, 3])) == 7 and SK.level_for(mk.call([7, 4, 3, 3, 3])) == 6)
	check.call("level 8: 8, 4, 4, 4, 4", SK.level_for(mk.call([8, 4, 4, 4, 4])) == 8 and SK.level_for(mk.call([8, 4, 4, 4, 3])) == 7)
	check.call("level 9: 9, 5, 5, 5, 4, 4", SK.level_for(mk.call([9, 5, 5, 5, 4, 4])) == 9 and SK.level_for(mk.call([9, 5, 5, 4, 4, 4])) == 8)
	check.call("level 10: 10, 5, 5, 5, 5, 5", SK.level_for(mk.call([10, 5, 5, 5, 5, 5])) == 10 and SK.level_for(mk.call([10, 5, 5, 5, 5, 4])) == 9)
	check.call("the cap is 10 however high the skills go", SK.level_for(mk.call([20, 20, 20, 20, 20, 20, 20])) == 10)
	check.call("a high skill does not count twice", SK.level_for(mk.call([6])) == 1)
	check.call("requirement text", SK.level_text(4) == "one skill at 4, two skills at 2")
	var g = GameScript.new(5)
	g.setup(300)
	check.call("a new character is level 0 with no points", g.pc_level == 0 and g.attr_points == 0)
	g.skills[ids[0]] = 1
	g.check_level()
	check.call("reaching the skills levels you up and earns a point", g.pc_level == 1 and g.attr_points == 1)
	g.check_level()
	check.call("no double award", g.pc_level == 1 and g.attr_points == 1)
	g.skills[ids[0]] = 3
	g.skills[ids[1]] = 2
	g.skills[ids[2]] = 1
	g.check_level()
	check.call("several levels at once pay a point each", g.pc_level == 3 and g.attr_points == 3)
	var s0: int = g.attrs["str"]
	check.call("spending raises the attribute and the pool falls", g.spend_point("str") and g.attrs["str"] == s0 + 1 and g.attr_points == 2)
	g.attr_points = 0
	check.call("no points, no spending", not g.spend_point("str") and g.attrs["str"] == s0 + 1)
	g.skills[ids[0]] = 0
	g.check_level()
	check.call("a level is never lost", g.pc_level == 3)
	# XP drives it
	var g2 = GameScript.new(5)
	g2.setup(300)
	var guard := 0
	while g2.pc_level == 0 and guard < 200:
		g2.skill_up("melee", 0)
		guard += 1
	check.call("training a skill by XP raises the level", g2.pc_level == 1 and g2.attr_points == 1)
	# saves
	var d: Dictionary = g.save_dict()
	var g3 = GameScript.new(5)
	g3.setup(300)
	g3.load_dict(d)
	check.call("level and points survive a save", g3.pc_level == 3 and g3.attr_points == 0)
	d.erase("lvl")
	d.erase("pts")
	d["skills"] = {ids[0]: 3, ids[1]: 2, ids[2]: 1}
	var g4 = GameScript.new(5)
	g4.setup(300)
	g4.load_dict(d)
	check.call("an old save gets the level its skills earn", g4.pc_level == 3 and g4.attr_points == 3)
	return [cnt[0], cnt[1], log]
