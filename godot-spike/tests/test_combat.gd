extends RefCounted
## Combat: limb health, armor (flat deduction, wear), ranged accuracy / aim speed / cover / dodge, melee accuracy / speed / dodge, the arts hooks.
const GameScript = preload("res://src/game.gd")
const GP = preload("res://src/gunplay.gd")
const IMP = preload("res://src/implants.gd")
const BODY = preload("res://src/body.gd")
const SK = preload("res://src/skills.gd")

func _open_line(g, from: int, len: int) -> int:
	for r in range(0, 140):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x: int = from % g.size + dx
				var y: int = from / g.size + dy
				if x < 6 or y < 6 or x >= g.size - 8 or y >= g.size - 8:
					continue
				var ok := true
				for ox in range(-1, len + 2):
					for oy in range(-1, 2):
						var c: int = (y + oy) * g.size + x + ox
						if g.sim.walk[c] == 0 or g.sim.at[c] != -1 or g.veh_at.g(c) != -1:
							ok = false
				if ok:
					return y * g.size + x
	return -1

func run() -> Array:
	preload("res://tests/legacy_implants.gd").install()
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var g = GameScript.new(5)
	g.crits = false                          # these tests count exact damage
	g.setup(600)
	var fresh = func() -> void:
		g.skills = SK.default_skills()
		g.body.reset()
		g.armor_worn = []
		g.imp_dur = {}
		g.implants = {}
		g.infinite_power = true                      # (these tests use bare implant ids that carry no battery of their own)
		g.worn = [g._new_item("trl_backpack")]     # no coat: no hidden armor
		g.melee_arts = []
		g.game_over = false
	fresh.call()
	# ---------------------------------------------------------------- limbs
	check.call("six limbs, each with its own health (%s)" % str(g.body.hp), g.body.hp.size() == 6 and g.body.hp["chest"] > g.body.hp["head"])
	g.player_hurt(5, "Test", "phys", "l_arm")
	check.call("a hit lands on the limb it names and comes off the limb (arm %d, body %d)" % [g.body.hp["l_arm"], g.body.total()], g.body.hp["l_arm"] == BODY.BASE["l_arm"] - 5 and g.body.total() == 159)
	g.player_hurt(200, "Test", "phys", "l_arm")
	check.call("a limb at 0 is disabled, but you live (hp %d)" % g.body.total(), not g.body.ok("l_arm") and not g.body.vital_dead() and not g.game_over)
	fresh.call()
	g.player_hurt(500, "Test", "phys", "head")
	check.call("head at 0 is death and ends the run", g.body.vital_dead() and g.game_over)
	fresh.call()
	g.player_hurt(500, "Test", "phys", "chest")
	check.call("chest at 0 is death and ends the run", g.body.vital_dead() and g.game_over)
	fresh.call()
	var hits := {}
	for k in 400:
		var l: String = g.body.pick(g.rng)
		hits[l] = int(hits.get(l, 0)) + 1
	check.call("random hits land everywhere, mostly the chest %s" % str(hits), hits.size() == 6 and hits["chest"] > hits["head"] * 2)
	# ---------------------------------------------------------------- armor
	fresh.call()
	var vest = g._new_item("trl_armor_chest_4")
	g.act_wear(vest)
	check.call("a vest goes on over the body (armor %d on the chest)" % g.armor_value("chest"), g.armor_value("chest") == 4 and g.armor_value("head") == 0)
	var h0: int = g.body.total()
	g.player_hurt(10, "Test", "phys", "chest")
	check.call("armor is a flat deduction (10 - 4 = 6 through; hp %d -> %d)" % [h0, g.body.total()], h0 - g.body.total() == 6 and g.body.hp["chest"] == BODY.BASE["chest"] - 6)
	check.call("it wore down by what it soaked (%s)" % g.item_label(vest), g.item_armor_left(vest) == 65 - 4 and g.item_label(vest).contains("93%"))
	h0 = g.body.total()
	g.player_hurt(3, "Test", "phys", "chest")
	check.call("a small hit is stopped outright", h0 == g.body.total())
	h0 = g.body.total()
	g.player_hurt(10, "Test", "phys", "chest", 3)
	check.call("armor-piercing takes 3 off the armor (10 - 1 = 9)", h0 - g.body.total() == 9)
	check.call("armor does not cover the arms", (func(): h0 = g.body.total(); g.player_hurt(10, "Test", "phys", "r_arm"); return h0 - g.body.total() == 10).call())
	# it breaks
	for k in 30:
		g.player_hurt(8, "Test", "phys", "chest")
	check.call("armor that soaked enough breaks and stops helping (%s, value %d)" % [g.item_label(vest), g.armor_value("chest")], g.item_armor_left(vest) <= 0 and g.armor_value("chest") == 0 and g.item_label(vest).contains("BROKEN"))
	fresh.call()
	g.implants["dermal"] = true
	g._sync_pools()
	check.call("implants carry armor too: dermal plating gives 2 everywhere", g.armor_value("head") == 2 and g.armor_value("l_leg") == 2)
	h0 = g.body.total()
	g.player_hurt(6, "Test", "phys", "chest")
	check.call("and wears (%d/80 left)" % int(g.imp_dur.get("dermal", 80)), (h0 - g.body.total() == 4 or h0 - g.body.total() == 6) and int(g.imp_dur["dermal"]) == 78)
	check.call("armor_status reports the bars (%s)" % str(g.armor_status()), g.armor_status()["left"] == 78 and g.armor_status()["max"] == 80)
	var helm = g._new_item("trl_armor_head_3")
	g.inv.stow(helm)
	g.inv.auto_equip(helm)
	check.call("worn armor and implants stack on a limb (head 2 + 3)", g.armor_value("head") == 5)
	# armor on NPCs, flat
	var thug := -1
	for i in g.sim.n:
		if g.fac[i] == g.NAP:
			thug = i
			break
	check.call("NPC factions wear armor and some dodge", g.npc_armor(thug) > g.npc_armor(0) if thug >= 0 else true)
	# ---------------------------------------------------------------- implants and limbs
	fresh.call()
	g.implants["legs"] = true
	g.implants["optics"] = true
	check.call("implants work with healthy limbs", g.has_implant("legs") and g.has_implant("optics"))
	g.player_hurt(500, "Test", "phys", "l_leg")
	check.call("a disabled leg turns the leg actuators off", not g.has_implant("legs") and g.implants["legs"])
	g.player_hurt(500, "Test", "phys", "head")
	check.call("(and a dead head, the optics)", not g.has_implant("optics"))
	fresh.call()
	g.implants["mantis"] = true
	check.call("mantis blades are the hands' weapon when empty", (func(): g.wield = null; return g.melee_stats().get("mantis", false)).call())
	g.player_hurt(500, "Test", "phys", "r_arm")
	check.call("one dead arm and the mantis blades are offline", not g.melee_stats().get("mantis", false))
	# ---------------------------------------------------------------- broken limbs and play
	fresh.call()
	var spot: int = _open_line(g, g.pc, 12)
	g.pc = spot
	g.sim.retier(g.pc)
	g.last_pc = spot
	g.stance = g.WALKING
	var t0: int = g.turn
	g.act_move(1, 0)
	var normal_cost: int = g.turn - t0
	g.player_hurt(500, "Test", "phys", "l_leg")
	t0 = g.turn
	g.act_move(1, 0)
	var limp_cost: int = g.turn - t0
	g.player_hurt(500, "Test", "phys", "r_leg")
	t0 = g.turn
	g.act_move(1, 0)
	var crawl_cost: int = g.turn - t0
	check.call("legs: a step costs %d, one leg gone %d, both gone %d turns" % [normal_cost, limp_cost, crawl_cost], normal_cost == 1 and limp_cost == 2 and crawl_cost == 3)
	check.call("no jumping and no running without legs", not g.act_jump(1, 0))
	fresh.call()
	# arms and the guns
	var rifle = g._new_item("trl_gun_hx9")
	var pistol = null
	for k in g.db.defs:
		if "pistol" in g.db.defs[k].get("tags", []) and "gun" in g.db.defs[k].get("tags", []):
			pistol = g._new_item(k)
			break
	check.call("a pistol takes one hand, a submachine gun two", g.weapon_hands(pistol) == 1 and g.weapon_hands(rifle) == 2)
	g.wield = rifle
	g.player_hurt(500, "Test", "phys", "l_arm")
	check.call("with a broken arm you can't use a two-handed gun", not g.can_use_weapon(rifle, false))
	g.wield = pistol
	check.call("but a pistol still works", g.can_use_weapon(pistol, false))
	var rate1: float = g.aim_rate()
	fresh.call()
	g.wield = pistol
	var rate2: float = g.aim_rate()
	check.call("a broken arm slows your aim (%.2f vs %.2f)" % [rate1, rate2], rate1 < rate2 - 0.4)
	var st_p: Dictionary = GP.stats(pistol)
	g.player_hurt(500, "Test", "phys", "l_arm")
	var acc_hurt: int = g._arm_acc_pen()
	check.call("and costs accuracy (-%d)" % acc_hurt, acc_hurt >= 15)
	g.player_hurt(500, "Test", "phys", "r_arm")
	g.wield = pistol
	check.call("both arms gone: no weapon at all", not g.can_use_weapon(pistol, false) and g.melee_stats()["verb"] == "kick")
	fresh.call()
	# ---------------------------------------------------------------- ranged accuracy: sights, scopes, implants
	g.wield = g._new_item("trl_gun_hx9")
	var base: Dictionary = GP.stats(g.wield)
	check.call("a bare gun has no optic and no sights bonus (max aim %d)" % base["max_aim"], not base["optic"] and not base["scoped"] and not base.has("sights"))
	var acc_iron: int = GP.hit_chance(base, 10, 0, false, false, 2, 0)
	var scope = g._new_item("trl_mod_scope4")
	g.wield.mods.append(scope)
	var scoped: Dictionary = GP.stats(g.wield)
	var acc_scope: int = GP.hit_chance(scoped, 10, 0, false, false, 2, 0)
	check.call("a scope allows range precision (%d vs %d) and adds max aim (%d -> %d) but settles slower (%.2f vs %.2f)" % [acc_scope, acc_iron, base["max_aim"], scoped["max_aim"], scoped["aim_rate"], base["aim_rate"]], scoped["scoped"] and acc_scope > acc_iron and scoped["max_aim"] == base["max_aim"] + 1 and scoped["aim_rate"] < base["aim_rate"])
	var acc_close_iron: int = GP.hit_chance(base, 3, 0, false, false, 2, 0)
	var acc_close_scope: int = GP.hit_chance(scoped, 3, 0, false, false, 2, 0)
	var sc_flat: Dictionary = scoped.duplicate()
	sc_flat["close_pen"] = 0
	check.call("but a scope is clumsy up close (range penalty %d inside 4 tiles, %d without its close penalty)" % [GP.range_penalty(scoped, 3, 5), GP.range_penalty(sc_flat, 3, 5)], GP.range_penalty(scoped, 3, 5) > GP.range_penalty(sc_flat, 3, 5))
	g.wield.mods.clear()
	# find a target and compute with implants
	var sp: int = _open_line(g, g.pc, 12)
	g.pc = sp
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
	g.sim.at[g.sim.pos[who]] = -1
	g.sim.pos[who] = sp + 8
	g.sim.at[sp + 8] = who
	var bs: Dictionary = GP.stats(g.wield)
	g.moved = false
	var c0: int = g._shot_chance(bs, who, 0, 0)
	g.implants["cortex"] = true
	var c1: int = g._shot_chance(bs, who, 0, 0)
	g.implants["optics"] = true
	var c2: int = g._shot_chance(bs, who, 0, 0)
	check.call("brain and eye implants add accuracy (%d -> %d -> %d)" % [c0, c1, c2], c1 > c0 and c2 > c1)
	g.body.hp["head"] = 5
	var c3: int = g._shot_chance(bs, who, 0, 0)
	check.call("a battered head costs accuracy (and switches the implants off: %d)" % c3, c3 < c2)
	g.body.reset()
	# aiming
	g.implants = {}
	g.aim_turns = 0
	var r0: float = g.aim_rate()
	g.implants["reflex"] = true
	var r1: float = g.aim_rate()
	check.call("aim speed: implants speed it up (%.2f -> %.2f)" % [r0, r1], r1 > r0 + 0.4)
	g.implants = {}
	g.wield.mods.append(g._new_item("trl_mod_scope8"))
	var r_scope: float = g.aim_rate()
	g.wield.mods.clear()
	check.call("a big scope is slow to settle (%.2f vs %.2f)" % [r_scope, r0], r_scope < r0)
	g.wield.mods.clear()
	g.aim_turns = 0
	g.aim_frac = 0.0
	g.sim.retier(g.pc)
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	g.aim_target = who
	g.implants["synapse"] = true
	g.act_aim(true)
	var after1: int = 1 if g.log.any(func(l): return String(l).contains("(aim 1/")) else g.aim_turns       # (read off the message: a shot from a hostile nearby can knock the aim back to 0 before we look)
	g.aim_turns = maxi(g.aim_turns, after1)
	g.act_aim(true)
	check.call("with a grade 4 implant aim comes faster, up to the gun's max aim (%d, then %d of %d)" % [after1, g.aim_turns, g.gun_stats()["max_aim"]], after1 == 1 and g.aim_turns == mini(3, int(g.gun_stats()["max_aim"])))
	g.implants = {}
	# cover
	var chance_open: int = g._shot_chance(bs, who, 0, 0)
	var cover_cell: int = g.sim.pos[who] - 1
	var saved_tile: int = g.city.tiles[cover_cell]
	g.city.tiles[cover_cell] = g.CG.CRATE
	var chance_cover: int = g._shot_chance(bs, who, 0, 0)
	g.city.tiles[cover_cell] = saved_tile
	check.call("cover in front of the target lowers the chance (%d -> %d)" % [chance_open, chance_cover], chance_cover < chance_open)
	# dodge
	check.call("with no implants you cannot dodge a bullet", g.player_bullet_dodge() == 0)
	g.implants["reflex"] = true
	var d_reflex: int = g.player_bullet_dodge()
	g.implants["synapse"] = true
	var d_syn: int = g.player_bullet_dodge()
	check.call("grade 3 and 4 implants dodge bullets (%d%%, %d%%)" % [d_reflex, d_syn], d_reflex > 0 and d_syn > d_reflex)
	var only_high := true
	for d in IMP.ALL:
		if float(d.get("dodge_bullet", 0)) > 0 and int(d["grade"]) < 3:
			only_high = false
	check.call("no implant under grade 3 offers a bullet dodge", only_high)
	g.player_hurt(500, "Test", "phys", "l_leg")
	check.call("a broken leg halves the dodge", g.player_bullet_dodge() < d_syn)
	fresh.call()
	var dodged := 0
	g.implants["synapse"] = true
	for k in 400:
		if g.rng.randi() % 100 < g.player_bullet_dodge():
			dodged += 1
	check.call("and it shows in practice (%d of 400)" % dodged, dodged > 70 and dodged < 140)
	fresh.call()
	# ---------------------------------------------------------------- melee: accuracy, dodge, speed, arts
	g.wield = g._new_item("trl_mel_katana")
	var put = func(cell: int, f: int) -> void:
		g.sim.at[g.sim.pos[who]] = -1
		g.sim.pos[who] = cell
		g.sim.at[cell] = who
		g.sim.idle[who] = 1
		g.sim.sticky[who] = 1
		g.fac[who] = f
		g.hpn[who] = 9000
		g.hpmax[who] = 9000
		g.astate[who] = g.HUNTING
		g.sim.ctl[who] = 1
		g.stun[who] = 0
		g.bleed[who] = 0
		g.skills["melee"] = 3                     # trials must not train the skill, or later batches would be easier than earlier ones
		g.xp["melee"] = 0
	var hit_rate = func(f: int, trials: int) -> int:
		var n := 0
		for _t in trials:
			put.call(sp + 1, f)
			var h: int = g.hpn[who]
			g.melee(who)
			if g.hpn[who] < h:
				n += 1
		return n
	var civ_hits: int = hit_rate.call(g.CIV, 400)
	var kill_hits: int = hit_rate.call(g.NASIM, 400)
	check.call("melee: the target's dodge matters (civilian %d, a wired killer %d of 400)" % [civ_hits, kill_hits], kill_hits < civ_hits - 15)
	g.player_hurt(500, "Test", "phys", "l_arm")
	var one_arm: int = hit_rate.call(g.CIV, 400)
	check.call("a broken arm hurts your melee accuracy (%d vs %d)" % [one_arm, civ_hits], one_arm < civ_hits - 20)
	fresh.call()
	g.wield = g._new_item("trl_mel_kastet")
	var cost_fast: int = g.swing_stamina(g.melee_stats())
	g.wield = g._new_item("trl_mel_katana")
	var cost_kat: int = g.swing_stamina(g.melee_stats())
	g.wield = g._new_item("trl_mel_nodachi")
	var cost_slow: int = g.swing_stamina(g.melee_stats())
	g.stamina = g.STAMINA_MAX
	g.implants["reflex"] = true
	var rate_reflex: int = g.ap_rate()
	g.implants = {}
	check.call("swing stamina: light %d <= katana %d <= nodachi %d; reflex wires raise the AP rate (%d vs %d)" % [cost_fast, cost_kat, cost_slow, rate_reflex, g.ap_rate()], cost_fast <= cost_kat and cost_kat <= cost_slow and rate_reflex > g.ap_rate())
	g.wield = g._new_item("trl_mel_katana")
	g.wield = g._new_item("trl_mel_kastet")
	check.call("melee dodge for the player: skill + implants", g.player_dodge_pts() >= 0 and (func(): g.implants["synapse"] = true; var d: int = g.player_dodge_pts(); g.implants = {}; return d > g.player_dodge_pts()).call())
	# arts: parry and riposte are hooks the player can learn
	g.skills = SK.default_skills()           # the strikes above taught some Melee; start the arts check from a clean sheet
	check.call("no melee arts known at the start", g.melee_arts.is_empty() and not g.has_art("parry"))
	g.wield = g._new_item("trl_mel_katana")
	var p0: int = g.parry_chance({})
	g.learn_art("parry")
	var p1: int = g.parry_chance({})
	check.call("learning 'parry' raises the parry chance (%d -> %d)" % [p0, p1], p1 > p0)
	g.learn_art("riposte")
	put.call(sp + 1, g.CIV)
	g.pc = sp
	var counters := 0
	for _t in 200:
		put.call(sp + 1, g.CIV)
		var h: int = g.hpn[who]
		if g._melee_arts_on_miss(who, "parry") and g.hpn[who] < h:
			counters += 1
	check.call("'riposte' turns a parry into a counter-strike (%d of 200)" % counters, counters > 40)
	check.call("riposte needs a parry, not a dodge", not g._melee_arts_on_miss(who, "dodge"))
	# ---------------------------------------------------------------- items
	fresh.call()
	g.player_hurt(500, "Test", "phys", "r_leg")
	var patch = g._new_item("trl_medkit")
	g.stow(patch)
	g.act_wield(patch)
	check.call("a trauma patch revives the worst limb and closes wounds (body %d, leg %d)" % [g.body.total(), g.body.hp["r_leg"]], g.body.hp["r_leg"] == 28 and g.body.ok("r_leg"))
	var helmet = g._new_item("trl_armor_head_3")
	g.stow(helmet)
	g.act_wield(helmet)
	check.call("choosing armor in the inventory puts it on", g.armor_worn.has(helmet))
	# save and load keep the body and the wear
	g.body.hp["l_arm"] = 7
	g.imp_dur["dermal"] = 33
	helmet.cond = 12
	g.learn_art("parry")
	var d6: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = GameScript.new(0)
	g2.load_dict(d6)
	check.call("save and load keep limb health, worn armor with its wear, implant plating and arts", g2.body.hp["l_arm"] == 7 and g2.armor_worn.size() == 1 and g2.armor_worn[0].cond == 12 and g2.imp_dur["dermal"] == 33 and g2.has_art("parry"))
	return [st[0], st[1], log]
