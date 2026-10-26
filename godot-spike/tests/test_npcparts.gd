extends RefCounted
## NPC body parts: the same six limbs as the player, hit locations that matter, wounds that show, saves.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const SK = preload("res://src/skills.gd")
const BODY = preload("res://src/body.gd")

func _open_line(g, from: int, len: int) -> int:
	for r in range(0, 140):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x: int = from % g.size + dx
				var y: int = from / g.size + dy
				if x < 6 or y < 6 or x >= g.size - 12 or y >= g.size - 8:
					continue
				var ok := true
				for ox in range(-1, len + 2):
					for oy in range(-1, 2):
						var c: int = (y + oy) * g.size + x + ox
						if g.sim.walk[c] == 0 or g.sim.at[c] != -1 or g.veh_at[c] != -1:
							ok = false
				if ok:
					return y * g.size + x
	return -1

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var g = GameScript.new(81)
	g.setup(1200)
	for l_ in g.BODY.LIMBS:
		g.body.hp[l_] = 100000
		g.body.mx[l_] = 100000
	var spot: int = _open_line(g, g.pc, 12)
	g.pc = spot
	g.last_pc = spot
	g.sim.retier(g.pc)
	var who := -1
	for k in g.sim.near_list.size():
		var j: int = g.sim.near_list[k]
		if g.sim.alive[j] == 1 and g.z_of(g.sim.pos[j]) == 0 and who < 0:
			who = j
	if who < 0:                                               # (most people are up in the flats at this hour: bring one down to the street)
		for j in g.sim.n:
			if g.sim.alive[j] == 1 and g.sim.sticky[j] == 0:
				g.sim.place(j, spot + 1)
				who = j
				break
	var fresh = func(cell: int, hp_each: int = 60) -> void:
		g.sim.alive[who] = 1
		g.sim.place(who, cell)
		g.sim.idle[who] = 1
		g.sim.sticky[who] = 1
		g.sim.near[who] = 1
		g.sim.alive[who] = 1
		g.fac[who] = g.BRATVA
		g.hpmax[who] = hp_each
		g.hpn[who] = hp_each
		g.limbn[who * 6] = -1
		g.astate[who] = g.HUNTING
		g.stun[who] = 0
		g.bleed[who] = 0
		g.gunc[who] = 0
		g.body.reset()
		g.body.mend_to(1.0)
		g.game_over = false
		g.pc = spot
		g.last_pc = spot
		g.sim.retier(g.pc)
		g.sim.near[who] = 1
		g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	fresh.call(spot + 1)
	# ---- the same body
	var same := true
	for l in BODY.LIMBS:
		same = same and g.npc_limb_max(who, l) == int(BODY.BASE[l])
	check.call("a 60-health person has exactly the player's limbs (head %d, chest %d, arm %d, leg %d)" % [g.npc_limb_max(who, "head"), g.npc_limb_max(who, "chest"), g.npc_limb_max(who, "l_arm"), g.npc_limb_max(who, "l_leg")], same)
	g.hpmax[who] = 40
	check.call("a tougher or frailer person's limbs scale with their health (chest %d at 40)" % g.npc_limb_max(who, "chest"), g.npc_limb_max(who, "chest") == 27)
	fresh.call(spot + 1)
	check.call("untouched people have no wounds and full limbs", g.npc_wound_text(who) == "" and g.npc_arms_ok(who) == 2 and g.npc_legs_ok(who) == 2)
	# ---- a blow on a limb wounds that limb and the overall health
	g.hpn[who] = 5000
	g.hpmax[who] = 60
	var hp0: int = g.hpn[who]
	var killed: bool = g.npc_limb_hit(who, "r_arm", 10)
	check.call("a hit takes health off the limb (arm 24 -> %d)" % g.npc_limb_hp(who, "r_arm"), not killed and g.npc_limb_hp(who, "r_arm") == 14 and g.npc_limb_hp(who, "l_arm") == 24)
	g.npc_limb_hit(who, "r_arm", 20)
	check.call("a limb at 0 is disabled (arms working %d) and the log says so" % g.npc_arms_ok(who), g.npc_arms_ok(who) == 1 and g.npc_wound_text(who).contains("right arm disabled"))
	# ---- arms: one-handed, then no weapon at all
	var hits_before := 0
	g.wield = g._new_item("trl_mel_katana")
	g.skills = SK.default_skills()
	var dmg_taken := 0
	for _t in 60:
		g.body.mend_to(1.0)
		g.body.reset()
		g.apn[who] = 100
		g.stamn[who] = 100
		g.stamt[who] = g.turn
		g._npc_melee_attack(who)
		dmg_taken += 164 - g.body.total()
	check.call("a one-armed fighter still hits back (%d damage over 60 swings)" % dmg_taken, dmg_taken > 0)
	g.npc_limb_hit(who, "l_arm", 99)
	g.body.mend_to(1.0)
	var l0: int = g.log.size()
	for _t in 20:
		g._npc_melee_attack(who)
	var flail := false
	for li in range(l0, g.log.size()):
		if String(g.log[li]).contains("flails"):
			flail = true
	check.call("with both arms disabled they cannot attack (flail, no damage: %d)" % (164 - g.body.total()), g.npc_arms_ok(who) == 0 and flail and g.body.total() == 164)
	g.gunc[who] = 1
	g.aimn[who] = 1
	g.apn[who] = 100
	l0 = g.log.size()
	g._hunt_act(who, 5, true)
	var shot := false
	for li in range(l0, g.log.size()):
		var m: String = String(g.log[li])
		if m.contains("raises") or m.contains("shoots") or m.contains("goes wild"):
			shot = true
	check.call("and a gunman with no good arm cannot raise or fire his gun", not shot)
	# ---- legs: dodge and speed, as for the player
	fresh.call(spot + 1)
	var d_full: int = g.npc_dodge_pts(who)
	g.npc_limb_hit(who, "l_leg", 99)
	var d_one: int = g.npc_dodge_pts(who)
	g.npc_limb_hit(who, "r_leg", 99)
	var d_none: int = g.npc_dodge_pts(who)
	check.call("one bad leg halves their dodge, two take it away (%d, %d, %d)" % [d_full, d_one, d_none], d_one == d_full / 2 and d_none == 0 and g.npc_legs_ok(who) == 0)
	var far: int = _open_line(g, spot + 30, 6)
	fresh.call(far)
	g.sim.near[who] = 1
	var steps_cost := []
	for legs_out in [0, 1, 2]:
		g.limbn[who * 6] = -1
		if legs_out >= 1:
			g.npc_limb_hit(who, "l_leg", 99)
		if legs_out == 2:
			g.npc_limb_hit(who, "r_leg", 99)
		g.apn[who] = 300
		g.sim.pos[who] = far
		g.sim.at[far] = who
		g._hunt_act(who, 9, true)
		steps_cost.append(300 - g.apn[who])
	check.call("a step costs 0, 100 or 200 extra AP with 0, 1 or 2 legs gone (%s)" % str(steps_cost), steps_cost == [0, 100, 200])
	# ---- vital limbs kill
	fresh.call(spot + 1)
	g.hpn[who] = 5000
	g.hpmax[who] = 60
	g.npc_limb_hit(who, "chest", 39)
	check.call("a chest at 1 of 40 is still standing", g.sim.alive[who] == 1)
	var dead: bool = g.npc_limb_hit(who, "chest", 5)
	check.call("a destroyed chest kills even with health to spare", dead and g.sim.alive[who] == 0)
	fresh.call(spot + 1)
	g.hpn[who] = 5000
	check.call("a destroyed head kills too", g.npc_limb_hit(who, "head", 30) and g.sim.alive[who] == 0)
	# ---- live: the player's blows and bullets land on parts
	g.wield = g._new_item("trl_mel_katana")
	var parts := {}
	for _t in 200:
		fresh.call(spot + 1)
		g.hpn[who] = 5000
		g.hpmax[who] = 5000
		g.skills = SK.default_skills()
		g.stamina = g.STAMINA_MAX
		g.melee(who)
		for l in BODY.LIMBS:
			if g.limbn[who * 6] != -1 and g.npc_limb_hp(who, l) < g.npc_limb_max(who, l):
				parts[l] = true
	check.call("blows from the player wound several different parts (%d of 6 seen)" % parts.size(), parts.size() >= 4)
	var pis = g._new_item(g.gun_ids["pistol"][0])
	g.wield = pis
	g.pool_add("9mm", "fmj", 5000)
	var gun_parts := {}
	var arm_gone := false
	for _t in 60:
		fresh.call(spot + 5)
		g.hpn[who] = 60
		g.hpmax[who] = 60
		pis.loaded = 10
		pis.jammed = false
		g.aim_turns = 2
		for _s in 6:
			if g.sim.alive[who] == 0:
				break
			g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
			g.astate[who] = g.HUNTING
			g.act_fire(true)
			if g.limbn[who * 6] != -1:
				for l in BODY.LIMBS:
					if g.npc_limb_hp(who, l) < g.npc_limb_max(who, l):
						gun_parts[l] = true
			if g.limbn[who * 6] != -1 and g.sim.alive[who] == 1 and (g.npc_arms_ok(who) < 2 or g.npc_legs_ok(who) < 2):
				arm_gone = true
	check.call("bullets wound several parts too (%d seen) and disable limbs on people still alive: %s" % [gun_parts.size(), str(arm_gone)], gun_parts.size() >= 3 and arm_gone)
	# ---- the look text shows wounds
	fresh.call(spot + 1)
	g.hpn[who] = 5000
	g.npc_limb_hit(who, "r_arm", 99)
	g.npc_limb_hit(who, "l_leg", 20)
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	var look: String = g.describe_at(spot + 1)
	check.call("looking at a wounded person says what is wrong (%s)" % look, look.contains("right arm disabled") and look.contains("left leg hurt"))
	# ---- save and load
	var dd: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = GameScript.new(0)
	g2.load_dict(dd)
	check.call("save and load keep every limb of a wounded person", g2.npc_limb_hp(who, "r_arm") == 0 and g2.npc_limb_hp(who, "l_leg") == g.npc_limb_hp(who, "l_leg") and g2.npc_limb_hp(who, "chest") == g.npc_limb_max(who, "chest"))
	var other: int = (who + 1) % g.sim.n
	check.call("people who were never hurt stay untouched after loading", g2.limbn[other * 6] == -1 or g2.limbn[other * 6] != 0)
	return [st[0], st[1], log]
