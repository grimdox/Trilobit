extends SceneTree
## The enemy roster (src/enemies.gd): the rules for every faction and level, then the live game (street levels, health, guns, a mission site).  godot --headless -s tests/run_enemies.gd
const ENM = preload("res://src/enemies.gd")
const WorldScript = preload("res://src/world.gd")
const MS = preload("res://src/missions.gd")
const IMP = preload("res://src/implants.gd")
var ok := 0
var n := 0
func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _initialize() -> void:
	var combat := ["unarmed", "melee", "ranged", "dodge", "grit"]
	var sk_ok := true
	var one_ok := true
	var hp_ok := true
	var guns_ok := true
	var l1_ok := true
	var l2_mix := {}
	var cap_ok := true
	var imp_ok := true
	var name_ok := true
	for fac in range(1, 6):
		var last_hp := 0
		var last_imp := 0
		for lvl in range(1, 11):
			var sk: Dictionary = ENM.skills(fac, lvl)
			var at_level := 0
			for id in sk:
				sk_ok = sk_ok and int(sk[id]) <= lvl and int(sk[id]) >= 1
				if int(sk[id]) == lvl:
					at_level += 1
					one_ok = one_ok and (lvl == 1 or id in combat)
			one_ok = one_ok and (lvl == 1 or at_level == 1)
			one_ok = one_ok and sk.values().any(func(v): return v == lvl)
			var hp: int = ENM.total_hp(lvl)
			hp_ok = hp_ok and hp > last_hp and absi(hp - int(round(0.8 * ENM.pc_health(lvl)))) <= 1
			last_hp = hp
			var limbs: int = ENM.limb_hp(lvl, "head") + ENM.limb_hp(lvl, "chest") + 2 * ENM.limb_hp(lvl, "l_arm") + 2 * ENM.limb_hp(lvl, "l_leg")
			hp_ok = hp_ok and absi(limbs - hp) <= 4
			var ir: Array = ENM.implant_range(fac, lvl)
			imp_ok = imp_ok and ir[1] <= 8 and ir[0] <= ir[1] and ir[1] >= last_imp and (ir[1] == 0 or (ir[2] >= 1 and ir[2] <= ir[3] and ir[3] <= 4))
			last_imp = ir[1]
			if fac == ENM.FAC_NASIM:
				imp_ok = imp_ok and ir[1] == 0
			if fac == ENM.FAC_GANG:
				imp_ok = imp_ok and ir[1] <= 2 and ir[3] <= 1
			name_ok = name_ok and ENM.title(fac, lvl) != ""
			for p in 300:
				var gc: int = ENM.gun_class(fac, lvl, 99, p)
				if lvl == 1:
					l1_ok = l1_ok and gc == 0
				elif lvl == 2:
					l2_mix[gc] = true
					guns_ok = guns_ok and gc <= 1
				else:
					guns_ok = guns_ok and gc >= 1
				cap_ok = cap_ok and (lvl >= 8 or gc <= int(ENM.GUN_CAP[fac])) and (lvl < 10 or gc == 3)
	check("no skill is above the enemy's level, every skill is at least 1 (every faction, levels 1-10)", sk_ok)
	check("from level 2 exactly one skill sits at the level, and it is a combat skill; the rest are below it", one_ok)
	check("health is 80% of a PC's (164 rising to 644 with a QL4 body): 131 at level 1, 515 at level 10, rising every level, limbs adding up", hp_ok and ENM.total_hp(1) == 131 and ENM.total_hp(10) == 515)
	check("level 1 enemies carry no guns; level 2 is a mix; level 3 on all are armed", l1_ok and l2_mix.has(0) and l2_mix.has(1) and guns_ok)
	check("gun classes follow the level (pistols, then SMGs, then rifles; level 10 all rifles)", cap_ok)
	check("implants: none for Nasim, at most two cheap ones for gangs, counts and quality range rise with level", imp_ok)
	check("every level has a title", name_ok)
	var tally := {}
	var all_in := true
	for p in 4000:
		var l: int = ENM.street_level(ENM.FAC_NAP, 7, p)
		all_in = all_in and l >= 4 and l <= 6
		tally[l] = tally.get(l, 0) + 1
	var avg := 0.0
	for l in tally:
		avg += float(l) * float(tally[l])
	avg /= 4000.0
	check("NAP on the street are level 4-6, averaging about 5 (%.2f)" % avg, all_in and avg > 4.7 and avg < 5.3)
	var rr: Array = ENM.implant_range(ENM.FAC_NAP, 10)
	var rolled: Array = ENM.rolled_implants(ENM.FAC_NAP, 10, 5, 12, IMP.ALL)
	check("a level 10 NAP officer rolls a full body of implants (8), deterministic", rr[1] == 8 and rolled.size() == 8 and rolled == ENM.rolled_implants(ENM.FAC_NAP, 10, 5, 12, IMP.ALL))
	check("drops grow with level (medkit from level 4, vests for the armoured, mods at every level)", ENM.drops(ENM.FAC_NAP, 6).any(func(d): return d[0] == "trl_medkit") and not ENM.drops(ENM.FAC_NAP, 2).any(func(d): return d[0] == "trl_medkit") and ENM.vest_id(ENM.FAC_CORP, 5) == "trl_vest_corp" and ENM.vest_id(ENM.FAC_NAP, 9) == "trl_vest_heavy")
	# ---- the live street
	var w = WorldScript.new()
	w.start(21, 300)
	var g = w.game
	var by_fac := {}
	var hp_live := true
	var gun_live := true
	var skill_live := true
	var nap_sum := 0
	var nap_n := 0
	for i in g.sim.n:
		if g.fac[i] == g.CIV:
			continue
		var f: int = g.fac[i]
		var l: int = g.enemy_level(i)
		by_fac[f] = by_fac.get(f, 0) + 1
		hp_live = hp_live and g.hpmax[i] == ENM.hpmax(l) and g.hpn[i] == g.hpmax[i]
		gun_live = gun_live and (l > 1 or g.gunc[i] == 0) and (l < 3 or g.gunc[i] > 0)
		for id in ["ranged", "melee", "unarmed", "dodge", "grit"]:
			skill_live = skill_live and g.npc_lvl(i, id) <= l
		if f == g.NAP:
			nap_sum += l
			nap_n += 1
	check("the city has enemies of several factions (%s)" % str(by_fac), by_fac.size() >= 3)
	check("every armed person's health comes from the roster", hp_live)
	check("every armed person's gun follows their level; none are armed at level 1, all are from level 3", gun_live)
	check("no enemy's effective skill is above their level", skill_live)
	check("the NAP on this street average level %.1f (4-6)" % (float(nap_sum) / maxf(1.0, nap_n)), nap_n >= 8 and float(nap_sum) / nap_n >= 4.0 and float(nap_sum) / nap_n <= 6.0)
	# ---- a mission site: hostile levels follow the contract
	var offers: Array = MS.offers(5, 123, 0, 0, [1, 1, 1, 1], 6)
	var site_ok := true
	for o in offers:
		var s = preload("res://src/game.gd").new(int(o["seed"]))
		s.setup(0, null, Vector2i(-1, -1), MS.new_state(o))
		for k in s.mission["agents"]:
			var idx: int = int(k)
			if s.fac[idx] == s.CIV:
				continue
			var l2: int = s.enemy_level(idx)
			site_ok = site_ok and l2 >= maxi(1, int(o["lv"][0])) and l2 <= maxi(1, int(o["lv"][1])) and s.hpmax[idx] == ENM.hpmax(l2) and (l2 > 1 or s.gunc[idx] == 0) and (l2 < 3 or s.gunc[idx] > 0)
		s.dispose()
	check("mission hostiles are levelled by the contract (player level 6) with the roster's health and guns", site_ok)
	print("(NAP on street: %d)" % nap_n)
	print("ENEMIES %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
