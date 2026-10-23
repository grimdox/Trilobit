extends RefCounted
## Attributes and skills: data, levelling, the rules wired into play, NPC stats, the economy, save/load and the screen layout.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const SK = preload("res://src/skills.gd")
const ScreenScript = preload("res://src/screen_view.gd")
const SettingsScript = preload("res://src/settings.gd")

func run() -> Array:
	var st := [0, 0]
	var log := []
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)

	# ---- the tables match the spec
	check.call("five attributes: Strength, Perception, Agility, Cognition, Endurance", SK.ATTRS.map(func(a): return a["name"]) == ["Strength", "Perception", "Agility", "Cognition", "Endurance"])
	check.call("sixteen skills in groups of 5, 3, 4 and 4", SK.SKILLS.size() == 16 and SK.skills_in("Combat").size() == 5 and SK.skills_in("Hacking").size() == 3 and SK.skills_in("Labour").size() == 4 and SK.skills_in("Social").size() == 4)
	var gov := {"unarmed": "str agi", "melee": "str agi", "ranged": "per cog", "dodge": "per agi", "grit": "str end", "networking": "cog", "analysis": "per", "implementation": "cog",
		"manual": "str end", "engineering": "per cog", "artisan": "per agi", "research": "cog end", "streetwise": "per", "etiquette": "per", "deception": "cog", "negotiation": "end"}
	var gov_ok := true
	for k in gov:
		if " ".join(SK.skill(k)["attrs"]) != gov[k]:
			gov_ok = false
	check.call("every skill is governed by the attributes in the spec", gov_ok)
	check.call("every skill has a description and every attribute governs a skill", SK.SKILLS.all(func(s): return String(s["desc"]).length() > 20 and not String(s["note"]).is_empty()) and SK.ATTRS.all(func(a): return SK.skills_of_attr(a["id"]).size() >= 1))
	check.call("attributes add 1 per two points above 10 (10:0 11:0 12:1 13:1 14:2 20:5) and take 1 per two below, odd values rounding towards 0 (9:0 8:-1 7:-1 6:-2)", SK.attr_bonus(10) == 0 and SK.attr_bonus(11) == 0 and SK.attr_bonus(12) == 1 and SK.attr_bonus(13) == 1 and SK.attr_bonus(14) == 2 and SK.attr_bonus(20) == 5 and SK.attr_bonus(9) == 0 and SK.attr_bonus(8) == -1 and SK.attr_bonus(7) == -1 and SK.attr_bonus(6) == -2)
	var low6: Dictionary = {}
	for a in SK.ATTRS:
		low6[a["id"]] = 6
	var bsk: Dictionary = SK.default_skills()
	var some: String = SK.SKILLS[0]["id"]
	check.call("a skill under low attributes is cut: every governing attribute at 6 takes 2 each (%s)" % some, SK.level(low6, bsk, some) == int(bsk.get(some, 0)) - 2 * SK.skill(some)["attrs"].size())

	# ---- a new character
	var g = GameScript.new(5)
	g.setup(300)
	check.call("attributes start at 10 and every skill at 0", g.attrs.values().all(func(v): return v == 10) and g.attrs.size() == 5 and g.skills.values().all(func(v): return v == 0) and g.skills.size() == 16 and g.xp.values().all(func(v): return v == 0))
	check.call("with default attributes every effective level is 0", SK.skill_ids().all(func(id): return g.lvl(id) == 0))
	g.attrs["str"] = 14
	g.attrs["agi"] = 12
	check.call("Strength 14 and Agility 12 give Unarmed/Melee +3, Manual +2, Ranged +0", g.lvl("unarmed") == 3 and g.lvl("melee") == 3 and g.lvl("manual") == 2 and g.lvl("grit") == 2 and g.lvl("ranged") == 0 and g.lvl("dodge") == 1)
	g.skills["melee"] = 4
	check.call("effective level = base + attribute bonus (4 + 3)", g.lvl("melee") == 7)
	g.attrs = SK.default_attrs()
	g.skills = SK.default_skills()

	# ---- skill XP
	var needed: int = SK.xp_needed(0)
	for k in needed:
		g.skill_up("dodge", 0)
	check.call("skill XP levels a skill up (%d XP at level 0) and resets" % needed, g.skills["dodge"] == 1 and g.xp["dodge"] == 0 and g.skills["melee"] == 0 and g.xp["melee"] == 0)
	g.skills["melee"] = 6
	g.skill_up("melee", 1)
	check.call("an easy task teaches nothing", g.xp["melee"] == 0)
	g.skill_up("melee", 9)
	check.call("a hard task teaches more (+4)", g.xp["melee"] == 4 and g.xp["unarmed"] == 0)
	g.skills["melee"] = SK.BASE_MAX
	g.skill_up("melee", 30)
	check.call("the base level stops at %d" % SK.BASE_MAX, g.skills["melee"] == SK.BASE_MAX)
	g.skill_up("stealth", 5)
	check.call("an unknown skill name is ignored, not a crash", true)
	g.skills = SK.default_skills()
	g.xp = SK.default_skills()

	# ---- the rules in play (player)
	check.call("fists use Unarmed", g.melee_skill_id() == "unarmed")
	var blade := ""
	for id in g.db.defs:
		if g.db.defs[id].has("melee"):
			blade = id
			break
	g.wield = g._new_item(blade)
	check.call("a blade uses Melee", g.melee_skill_id() == "melee")
	g.wield = null
	var d0: int = g.player_dodge_pts()
	g.skills["dodge"] = 3
	check.call("Dodge adds 1 point per level against blows (%d -> %d)" % [d0, g.player_dodge_pts()], g.player_dodge_pts() == d0 + 3)
	g.skills["dodge"] = 0
	check.call("a beginner cannot dodge bullets", g.player_bullet_dodge() == 0)
	g.skills["dodge"] = 6
	check.call("level 6 still cannot", g.player_bullet_dodge() == 0)
	g.skills["dodge"] = 10
	check.call("level 10 dodges bullets 16%% of the time (%d)" % g.player_bullet_dodge(), g.player_bullet_dodge() == 16)
	g.skills["dodge"] = 0
	var ar0: float = g.aim_rate()
	g.skills["ranged"] = 10
	check.call("Ranged steadies aim (%.2f -> %.2f), with the Steady Aim discipline from level 5" % [ar0, g.aim_rate()], g.aim_rate() > ar0 + 0.8 and g.discipline("steady_aim"))
	g.skills["ranged"] = 0
	var disc_ok := not g.has_art("parry")
	g.skills["melee"] = 3
	disc_ok = disc_ok and g.has_art("parry") and not g.has_art("riposte")
	g.skills["melee"] = 6
	disc_ok = disc_ok and g.has_art("riposte")
	g.skills["unarmed"] = 5
	disc_ok = disc_ok and g.discipline("iron_fist") and not g.discipline("pressure_points")
	g.skills["unarmed"] = 8
	disc_ok = disc_ok and g.discipline("pressure_points")
	check.call("disciplines unlock by effective level: Parry 3, Riposte 6, Iron Fist 5, Pressure Points 8", disc_ok)
	g.skills = SK.default_skills()
	# Grit: damage taken
	g.armor_worn = []
	var hp_a: int = g.body.total()
	g.player_hurt(8, "Test", "phys", "chest")
	var loss_a: int = hp_a - g.body.total()
	g.body.mend_to(1.0)
	g.skills["grit"] = 16
	g.player_hurt(8, "Test", "phys", "chest")
	var loss_b: int = hp_a - g.body.total()
	check.call("Grit cuts the damage you take (8 hit: lost %d at grit 0, %d at grit 16)" % [loss_a, loss_b], loss_a > 0 and loss_b > 0 and loss_b < loss_a)
	g.skills["grit"] = 0
	g.body.mend_to(1.0)
	var c0 := 0
	var c5 := 0
	for k in 4000:
		g.turn = k
		if g.crit_roll(0, 1, 2):
			c0 += 1
		if g.crit_roll(5, 1, 2):
			c5 += 1
	check.call("critical hits: about 6%% at Grit 0 (%d of 4000), about 1%% at Grit 5 (%d), the odds are %d%% / %d%% / %d%%" % [c0, c5, SK.crit_chance(0), SK.crit_chance(3), SK.crit_chance(12)], c0 > 150 and c0 < 340 and c5 > 15 and c5 < 90 and SK.crit_chance(3) == 3 and SK.crit_chance(12) == 1)
	var rs: int = g.rng.state
	g.crit_roll(0, 3, 4)
	check.call("crit rolls do not touch the game's random stream", g.rng.state == rs)

	# ---- people
	var seed_a := 5
	var avg_dodge := {}
	for f in 5:
		var tot := 0
		for i in 300:
			tot += SK.melee_dodge(SK.npc_level(f, seed_a, i, "dodge"))
		avg_dodge[f] = tot / 300
	var old_dodge := [4, 8, 10, 22, 6]
	var close := true
	for f in 5:
		if absi(int(avg_dodge[f]) - old_dodge[f]) > 3:
			close = false
	check.call("average NPC melee dodge stays near the old fixed values %s (now %s)" % [str(old_dodge), str([avg_dodge[0], avg_dodge[1], avg_dodge[2], avg_dodge[3], avg_dodge[4]])], close)
	var nb := 0
	for i in 300:
		nb += SK.bullet_dodge(SK.npc_level(3, seed_a, i, "dodge"))
	var nb_other := 0
	for f in [0, 1, 2, 4]:
		for i in 300:
			nb_other += SK.bullet_dodge(SK.npc_level(f, seed_a, i, "dodge"))
	check.call("only Nasim runners dodge bullets, about 12%% (avg %d)" % (nb / 300), nb / 300 >= 6 and nb / 300 <= 18 and nb_other == 0)
	var a1: Dictionary = SK.npc_attrs(1, 5, 17)
	check.call("NPC stats are deterministic per seed and person, and people differ", a1 == SK.npc_attrs(1, 5, 17) and SK.npc_attrs(1, 6, 17) != a1 or SK.npc_attrs(1, 5, 18) != a1)
	var differs := false
	for i in range(1, 40):
		if SK.npc_attrs(1, 5, i) != SK.npc_attrs(1, 5, 0):
			differs = true
	check.call("people of one faction are not clones", differs)
	var nap_r := 0
	var gang_r := 0
	for i in 200:
		nap_r += SK.npc_level(2, 5, i, "ranged")
		gang_r += SK.npc_level(4, 5, i, "ranged")
	check.call("NAP officers shoot better than gangsters (%d vs %d average x100)" % [nap_r / 2, gang_r / 2], nap_r > gang_r * 2)
	var hacker := 0
	for i in 100:
		hacker += SK.npc_level(2, 5, i, "networking")
	check.call("NPC levels use the same attribute rule (NAP networking > 0)", hacker > 0)
	var ai := -1
	for i in g.sim.n:
		if g.fac[i] == g.NASIM:
			ai = i
			break
	check.call("the game reads an NPC's skills from its faction (Nasim dodge %d)" % g.npc_melee_dodge(ai), ai >= 0 and g.npc_melee_dodge(ai) == SK.melee_dodge(SK.npc_level(g.NASIM, g.seed_value, ai, "dodge")) and g.npc_attr_set(ai).size() == 5)
	var t0 := Time.get_ticks_usec()
	for k in 20000:
		g.npc_lvl(k % g.sim.n, "melee")
	var us := (Time.get_ticks_usec() - t0) / 20000.0
	log.append("  (an NPC skill lookup costs %.2f us)" % us)
	check.call("an NPC skill lookup is cheap (%.1f us)" % us, us < 40.0)
	# damage to people: Grit cuts it
	var vi := -1
	for i in g.sim.n:
		if g.fac[i] == g.BRATVA:
			vi = i
			break
	var gsum := 0
	var gn := 0
	for i in g.sim.n:
		if g.fac[i] == g.BRATVA:
			gsum += g.npc_lvl(i, "grit")
			gn += 1
	check.call("Bratva have the Grit to take a point off a hit (average level %.1f over %d)" % [float(gsum) / maxf(1.0, gn), gn], vi >= 0 and gn > 0 and float(gsum) / gn >= 4.0 and SK.grit_cut(5) == 1)

	# a live fight: striking people with bare hands trains Unarmed (and nothing else), a blade trains Melee
	var tgt := vi
	g.skills = SK.default_skills()
	g.xp = SK.default_skills()
	g.crits = false
	for k in 12:
		g.hpn[tgt] = g.hpmax[tgt]
		g.sim.alive[tgt] = 1
		g.astate[tgt] = g.HUNTING
		g.melee(tgt)
	check.call("bare-handed strikes train Unarmed only (xp %d, level %d)" % [g.xp["unarmed"], g.skills["unarmed"]], (g.xp["unarmed"] > 0 or g.skills["unarmed"] > 0) and g.xp["melee"] == 0 and g.skills["melee"] == 0)
	g.wield = g._new_item(blade)
	for k in 12:
		g.hpn[tgt] = g.hpmax[tgt]
		g.sim.alive[tgt] = 1
		g.astate[tgt] = g.HUNTING
		g.melee(tgt)
	g.wield = null
	check.call("blade strikes train Melee (xp %d, level %d)" % [g.xp["melee"], g.skills["melee"]], g.xp["melee"] > 0 or g.skills["melee"] > 0)
	g.skills = SK.default_skills()
	g.xp = SK.default_skills()

	# ---- the economy
	var vend := -1
	for i in g.sim.n:
		if g.eco.role[i] == g.eco.VENDOR:
			vend = i
			break
	check.call("found a vendor", vend >= 0)
	g.skills["negotiation"] = 10
	check.call("Negotiation 10 takes 15%% off a price of 100 (%d)" % g.eco.haggle(vend, 100), g.eco.haggle(vend, 100) == 85)
	g.skills["streetwise"] = 5
	check.call("Streetwise 5 takes another 10%% (%d)" % g.eco.haggle(vend, 100), g.eco.haggle(vend, 100) == 75)
	g.skills["negotiation"] = 20
	g.skills["streetwise"] = 20
	check.call("discounts are capped at 30%%", g.eco.haggle(vend, 100) == 70)
	g.skills["negotiation"] = 10
	g.skills["streetwise"] = 0
	g.yen = 5000
	var m: Dictionary = g.eco.menu_for(vend)
	var k_buy := -1
	for k in m["options"].size():
		if m["options"][k]["op"] == "buy" and int(m["options"][k]["arg"][2]) >= 20:
			k_buy = k
			break
	check.call("vendor menu has a discounted purchase", k_buy >= 0)
	var price: int = int(m["options"][k_buy]["arg"][2])
	var label: String = m["options"][k_buy]["label"]
	var y0: int = g.yen
	var xn0: int = g.xp["negotiation"]
	g.eco.choose(m, k_buy)
	check.call("the menu price (%s) is what you pay (%d)" % [label, y0 - g.yen], y0 - g.yen == price and label.contains("¥%d" % price))
	check.call("an easy purchase teaches a level-10 haggler nothing", g.xp["negotiation"] == xn0)
	g.skills = SK.default_skills()
	g.xp = SK.default_skills()
	var m0: Dictionary = g.eco.menu_for(vend)
	g.eco.choose(m0, k_buy)
	check.call("a beginner learns Negotiation and a street skill from buying", g.xp["negotiation"] > 0 and (g.xp["streetwise"] > 0 or g.xp["etiquette"] > 0))
	var plain: Dictionary = g.eco.menu_for(vend)
	var plain_price := 0
	for o in plain["options"]:
		if o["op"] == "buy" and String(o["arg"][1]) == String(m["options"][k_buy]["arg"][1]):
			plain_price = int(o["arg"][2])
	check.call("without the skill the same item costs more (%d vs %d)" % [plain_price, price], plain_price > price)
	var chat := -1
	for i in g.sim.n:
		if g.eco.role[i] == g.eco.NONE:
			chat = i
			break
	var t_lo: int = (g.eco.menu_for(chat)["text"] as Array).size()
	g.skills["research"] = 9
	var t_hi: int = (g.eco.menu_for(chat)["text"] as Array).size()
	check.call("Research 9 gets 3 more rumours out of a chat (%d lines -> %d)" % [t_lo, t_hi], chat >= 0 and t_lo == 1 and t_hi == 4)
	g.skills = SK.default_skills()

	# ---- save and load
	g.attrs["str"] = 14
	g.attrs["cog"] = 13
	g.skills["melee"] = 4
	g.skills["negotiation"] = 2
	g.xp["melee"] = 3
	g.xp["ranged"] = 5
	var d: Dictionary = g.player_dict()
	var g2 = GameScript.new(5)
	g2.setup(300)
	g2.apply_player(JSON.parse_string(JSON.stringify(d)))
	check.call("player_dict round trip (through JSON) keeps attributes, skills and XP", g2.attrs == g.attrs and g2.skills == g.skills and g2.xp == g.xp and g2.lvl("melee") == 6)
	var d2: Dictionary = g.save_dict()
	var g3 = GameScript.new(5)
	g3.load_dict(JSON.parse_string(JSON.stringify(d2)))
	check.call("a full save and load keeps them too", g3.attrs == g.attrs and g3.skills == g.skills and g3.xp == g.xp and g3.attrs["str"] is int and g3.skills["melee"] is int)
	g3._load_skills({"skills": {"melee": 2, "ranged": 3, "stealth": 2, "theft": 1}, "xp": {"melee": 1, "stealth": 4}})
	check.call("an old save (stealth, theft) loads: known skills kept, the rest at defaults, attributes 10", g3.skills["melee"] == 2 and g3.skills["ranged"] == 3 and g3.skills.size() == 16 and not g3.skills.has("stealth") and g3.attrs.values().all(func(v): return v == 10) and g3.xp["melee"] == 1)

	# ---- the screen layout
	var sc = ScreenScript.new()
	var ents: Array = sc.sk_entries()
	var rects: Array = sc.sk_rects(1280.0, 720.0)
	check.call("the screen has 21 lines: 5 attributes then 16 skills", ents.size() == 21 and rects.size() == 21 and ents[0]["id"] == "str" and ents[5]["id"] == "unarmed" and ents[20]["id"] == "negotiation")
	var one_line := true
	for k in 5:
		if absf((rects[k] as Rect2).position.y - (rects[0] as Rect2).position.y) > 0.1:
			one_line = false
	check.call("the five attributes sit in one box on one line, across the top", one_line and (rects[4] as Rect2).end.x < 640.0 and (rects[4] as Rect2).end.y < 180.0)
	var low := true
	var inside := true
	for k in range(5, 21):
		var r: Rect2 = rects[k]
		if r.position.y < 720.0 * 0.25:
			low = false
		if r.position.x < 0 or r.end.x > 1280 or r.end.y > 720:
			inside = false
	check.call("the skills fill four boxes in the bottom three quarters of the screen", low and inside)
	var bx := {}
	for g_i in 4:
		var bxr: Rect2 = sc.sk_box_rect(g_i, 1280.0, 720.0)
		bx[g_i] = bxr
	check.call("four non-overlapping group boxes", not (bx[0] as Rect2).intersects(bx[1]) and not (bx[0] as Rect2).intersects(bx[2]) and not (bx[2] as Rect2).intersects(bx[3]) and not (bx[1] as Rect2).intersects(bx[3]))
	var mouse_ok := true
	for k in 21:
		if sc.sk_at_mouse((rects[k] as Rect2).get_center()) != k:
			mouse_ok = false
	check.call("the mouse finds every line, and nothing outside", mouse_ok and sc.sk_at_mouse(Vector2(5, 5)) == -1)
	sc.sk_sel = 0
	var moved_r: bool = sc.sk_move(Vector2i(1, 0))
	check.call("keys move right along the attributes", moved_r and sc.sk_sel == 1)
	sc.sk_sel = 4
	sc.sk_move(Vector2i(1, 0))
	check.call("and from the last one go on into the skill boxes", sc.sk_sel >= 5)
	sc.sk_sel = 0
	sc.sk_move(Vector2i(0, 1))
	check.call("down from an attribute goes into the skills", sc.sk_sel >= 5)
	sc.sk_sel = 5
	sc.sk_move(Vector2i(0, 1))
	check.call("down inside a box goes to the next skill (Unarmed to Melee)", sc.sk_sel == 6)
	sc.sk_sel = 5
	sc.sk_move(Vector2i(1, 0))
	check.call("right goes to the box beside it (Hacking)", ents[sc.sk_sel]["id"] in ["networking", "analysis", "implementation"])
	sc.sk_sel = 9
	sc.sk_move(Vector2i(0, 1))
	check.call("down from Grit goes to the Labour box", ents[sc.sk_sel]["id"] in ["manual", "engineering", "artisan", "research"])
	sc.sk_sel = 5
	sc.sk_move(Vector2i(0, -1))
	check.call("up from the first Combat skill goes to an attribute", sc.sk_sel < 5)
	sc.free()
	var keys_used := 0
	for a in SettingsScript.ACTIONS:
		if a[0] == "skills":
			keys_used = (a[2] as Array).size()
	var f7 := 0
	for a in SettingsScript.ACTIONS:
		if KEY_F7 in a[2]:
			f7 += 1
	check.call("the screen has a key binding (F7), used by nothing else", keys_used == 1 and f7 == 1)
	return [st[0], st[1], log]
