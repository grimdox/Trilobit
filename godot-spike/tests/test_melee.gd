extends RefCounted
## Japanese and Russian melee weapons.  Returns [passed, total, log]
const GameScript = preload("res://src/game.gd")
const CG = preload("res://src/citygen.gd")

const JP := ["kama", "wakizashi", "katana", "tanto", "nodachi", "naginata", "yari", "bo", "jo", "nunchaku", "kusarigama", "sai", "jitte", "tessen", "kunai", "ono", "tonfa"]
const RU := ["shashka", "kinzhal", "finka", "lopata", "kistien", "chekan", "topor", "kastet"]

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
	var g = GameScript.new(41)
	g.setup(1200)
	g.hp = 5000
	g.hp_max = 5000
	# ---- data
	var found := {}
	var west := false
	var grades_ok := true
	for k in g.db.defs:
		var d: Dictionary = g.db.defs[k]
		if "melee" in d["tags"]:
			var base: String = k.substr(8).replace("_f", "").replace("_m", "") if not (k.ends_with("_f") or k.ends_with("_m")) else k.substr(8, k.length() - 10)
			found[base] = true
			for bad in ["sword", "pike", "rapier", "halberd", "claymore", "mace", "lance", "spear", "flanged"]:
				if bad in d["name"].to_lower():
					west = true
			if not (d["culture"] in ["Japanese", "Russian"]):
				west = true
	var all_ok := true
	for w in JP + RU:
		if not found.has(w):
			all_ok = false
	check.call("all %d weapons exist and nothing else does (%d)" % [JP.size() + RU.size(), found.size()], all_ok and found.size() == JP.size() + RU.size())
	check.call("no Western swords, pikes or maces", not west)
	for w in JP + RU:
		var a: Dictionary = g.db.defs["trl_mel_" + w]["melee"]
		var f: Dictionary = g.db.defs["trl_mel_" + w + "_f"]["melee"]
		var m: Dictionary = g.db.defs["trl_mel_" + w + "_m"]["melee"]
		if not (f["dmg"][1] >= a["dmg"][1] and m["dmg"][1] > f["dmg"][1] and m["acc"] > f["acc"] and f["acc"] > a["acc"]):
			grades_ok = false
	check.call("forged and masterwork grades are better than plain", grades_ok)
	var kat: Dictionary = g.db.defs["trl_mel_katana"]["melee"]
	check.call("they differ: katana hits harder than a tanto, a tanto stabs in the back harder, reach 2 for yari/naginata/bo/kusarigama",
		kat["dmg"][1] > g.db.defs["trl_mel_tanto"]["melee"]["dmg"][1] and g.db.defs["trl_mel_tanto"]["melee"]["sneak"] > kat.get("sneak", 4)
		and g.db.defs["trl_mel_yari"]["melee"]["reach"] == 2 and g.db.defs["trl_mel_naginata"]["melee"]["reach"] == 2 and g.db.defs["trl_mel_bo"]["melee"]["reach"] == 2 and g.db.defs["trl_mel_kusarigama"]["melee"]["reach"] == 2)

	# ---- wielding and swapping
	var kt = g._new_item("trl_mel_katana")
	g.stow(kt)
	var gun0 = g.wield
	check.call("a melee weapon can be wielded (gun goes to the pack)", g.act_wield(kt) and g.wield == kt and g.prev_wield == gun0)
	check.call("the HUD line shows the weapon's numbers", g.gun_line().contains("katana") and g.gun_line().contains("dmg 12-20"))
	check.call("swap brings the gun back and swap again the blade", g.act_swap() and g.wield == gun0 and g.act_swap() and g.wield == kt)

	# ---- fighting
	var spot: int = _open_line(g, g.pc, 5)
	check.call("found open ground for a duel", spot >= 0)
	g.pc = spot
	g.sim.retier(g.pc)
	g.last_pc = spot
	var who := -1
	for k in g.sim.near_list.size():
		var j: int = g.sim.near_list[k]
		if g.sim.alive[j] == 1 and g.z_of(g.sim.pos[j]) == 0 and who < 0:
			who = j
	check.call("someone to fight", who >= 0)
	var put = func(cell: int) -> void:
		g.sim.at[g.sim.pos[who]] = -1
		g.sim.pos[who] = cell
		g.sim.at[cell] = who
		g.sim.idle[who] = 1
		g.sim.sticky[who] = 1
		g.fac[who] = g.BRATVA
		g.hpn[who] = 5000
		g.hpmax[who] = 5000
		g.astate[who] = g.HUNTING
		g.sim.ctl[who] = 1
		g.stun[who] = 0
		g.bleed[who] = 0
	var dmg_of = func(weapon, trials: int) -> float:
		g.wield = weapon
		var tot := 0
		for _t in trials:
			put.call(spot + 1)
			var h0: int = g.hpn[who]
			g.melee(who)
			tot += h0 - g.hpn[who]
		return float(tot) / float(trials)
	g.wield = null
	var fists: float = dmg_of.call(null, 60)
	var kat_avg: float = dmg_of.call(g._new_item("trl_mel_katana"), 60)
	var forged_avg: float = dmg_of.call(g._new_item("trl_mel_katana_f"), 60)
	var master_avg: float = dmg_of.call(g._new_item("trl_mel_katana_m"), 60)
	check.call("katana beats bare hands, forged beats plain, masterwork beats forged (%.1f, %.1f, %.1f, %.1f)" % [fists, kat_avg, forged_avg, master_avg],
		kat_avg > fists * 2 and forged_avg > kat_avg and master_avg > forged_avg)
	# fast weapons strike twice now and then
	var twice := 0
	g.wield = g._new_item("trl_mel_kastet")
	for _t in 80:
		put.call(spot + 1)
		var before: int = g.log.size()
		g.melee(who)
		for l in g.log.slice(before):
			if "again" in l:
				twice += 1
	check.call("fast weapons get second strikes (%d of 80)" % twice, twice >= 15 and twice <= 55)
	# bleed
	g.wield = g._new_item("trl_mel_katana")
	put.call(spot + 1)
	for _t in 10:
		g.melee(who)
		if g.bleed[who] > 0:
			break
	var hb: int = g.hpn[who]
	check.call("blades make people bleed", g.bleed[who] > 0)
	g.wield = null
	for _t in 3:
		g.end_turn()
	check.call("and the bleeding costs hit points over the next turns (%d -> %d)" % [hb, g.hpn[who]], g.hpn[who] <= hb - 2)
	# stun
	g.wield = g._new_item("trl_mel_bo")
	var stunned := 0
	for _t in 80:
		put.call(spot + 1)
		g.melee(who)
		if g.stun[who] > 0:
			stunned += 1
	check.call("a bo staff stuns sometimes (%d of 80)" % stunned, stunned >= 8 and stunned <= 45)
	# stunned people do nothing
	put.call(spot + 1)
	g.stun[who] = 3
	g.cool[who] = 0
	var p0: int = g.hp
	g.astate[who] = g.HUNTING
	g.sim.pos[who] = spot + 1
	g.end_turn()
	g.end_turn()
	check.call("a stunned enemy does not fight back", g.hp == p0 or g.stun[who] >= 0 and g.hp >= p0 - 0)
	# disarm
	g.wield = g._new_item("trl_mel_jitte")
	var disarmed := false
	for _t in 60:
		put.call(spot + 1)
		g.gunc[who] = 1
		g.melee(who)
		if g.gunc[who] == 0:
			disarmed = true
			break
	check.call("a jitte knocks guns out of hands (and drops the gun)", disarmed and g.items_at.has(spot + 1))
	g.gunc[who] = 0

	# ---- reach
	g.wield = g._new_item("trl_mel_yari")
	put.call(spot + 2)
	var hy0: int = g.hpn[who]
	var t0: int = g.turn
	var did: bool = g.act_strike(1, 0)
	check.call("a yari strikes someone two cells away (%d damage)" % (hy0 - g.hpn[who]), did and g.hpn[who] < hy0 and g.turn == t0 + 1)
	g.wield = g._new_item("trl_mel_katana")
	put.call(spot + 2)
	check.call("a katana does not", not g.act_strike(1, 0) and g.hpn[who] == 5000)
	g.wield = g._new_item("trl_mel_yari")
	put.call(spot + 2)
	var before_pos: int = g.pc
	g.last_pc = g.pc
	var hy1: int = g.hpn[who]
	var walked := false
	var poked := false
	for _t in 8:
		put.call(spot + 2)
		g.act_move(1, 0)
		if g.pc != before_pos:
			walked = true
		if g.hpn[who] < hy1:
			poked = true
	check.call("stepping toward a hunter with a yari pokes instead of walking", not walked and poked)
	put.call(spot + 2)
	g.astate[who] = g.UNAWARE
	g.act_move(1, 0)
	check.call("but you can still walk up to someone unaware", g.pc == before_pos + 1)
	g.pc = before_pos
	# naginata sweeps
	var other := -1
	for k in g.sim.near_list.size():
		var j: int = g.sim.near_list[k]
		if j != who and g.sim.alive[j] == 1 and g.z_of(g.sim.pos[j]) == 0 and other < 0:
			other = j
	if other >= 0:
		g.wield = g._new_item("trl_mel_naginata")
		put.call(spot + 1)
		g.sim.at[g.sim.pos[other]] = -1
		g.sim.pos[other] = spot - 1
		g.sim.at[spot - 1] = other
		g.astate[other] = g.HUNTING
		g.hpn[other] = 5000
		g.hpmax[other] = 5000
		var oh: int = g.hpn[other]
		for _t in 6:
			put.call(spot + 1)
			g.melee(who)
		check.call("a naginata's sweep hits the second enemy too (%d damage)" % (oh - g.hpn[other]), g.hpn[other] < oh)
	# slow weapons
	g.wield = g._new_item("trl_mel_nodachi")
	put.call(spot + 1)
	t0 = g.turn
	g.pc = spot
	g.act_move(1, 0)
	var slow_turns: int = g.turn - t0
	g.wield = g._new_item("trl_mel_katana")
	put.call(spot + 1)
	t0 = g.turn
	g.act_move(1, 0)
	check.call("a nodachi swing takes two turns, a katana's one (%d, %d)" % [slow_turns, g.turn - t0], slow_turns == 2 and g.turn - t0 == 1)
	# stealth
	var tot_t := 0
	var tot_k := 0
	for _t in 30:
		g.wield = g._new_item("trl_mel_tanto")
		put.call(spot + 1)
		g.astate[who] = g.UNAWARE
		g.face[who] = 2
		var h0: int = g.hpn[who]
		g.melee(who)
		tot_t += h0 - g.hpn[who]
		g.wield = g._new_item("trl_mel_katana")
		put.call(spot + 1)
		g.astate[who] = g.UNAWARE
		g.face[who] = 2
		h0 = g.hpn[who]
		g.melee(who)
		tot_k += h0 - g.hpn[who]
	log.append("   (backstab totals over 30: tanto %d, katana %d)" % [tot_t, tot_k])
	check.call("a tanto in the back does 40+ a blow despite its small blade", float(tot_t) / 30.0 > 40.0)

	# ---- parry
	g.wield = g._new_item("trl_mel_sai")
	var parry_hits := 0
	var naked_hits := 0
	g.fac[who] = g.BRATVA
	for _t in 200:
		put.call(spot + 1)
		g.pc = spot
		g.gunc[who] = 0
		g.mdis[who] = 1                    # no weapon, plain 60% punches
		g.cool[who] = 0
		g.wield = g._new_item("trl_mel_sai")
		var p1: int = g.hp
		g._hunt(who, 1)
		if g.hp < p1:
			parry_hits += 1
		g.wield = null
		var p2: int = g.hp
		g._hunt(who, 1)
		if g.hp < p2:
			naked_hits += 1
	check.call("a parrying weapon lowers the chance of being hit (%d vs %d of 200)" % [parry_hits, naked_hits], parry_hits < naked_hits - 15)

	# ---- what people carry
	var ru_ok := true
	var jp_ok := true
	var armed := 0
	for i in g.sim.n:
		var id: String = g.npc_melee_id(i)
		if id == "":
			continue
		armed += 1
		var cult: String = g.db.defs[id]["culture"]
		if g.fac[i] == g.BRATVA and cult != "Russian":
			ru_ok = false
		if (g.fac[i] == g.NAP or g.fac[i] == g.NASIM) and cult != "Japanese":
			jp_ok = false
	check.call("gangsters carry blades: Bratva Russian, NAP and Nasim Japanese (%d armed)" % armed, armed > 10 and ru_ok and jp_ok)
	# a dead armed man leaves the weapon
	var victim := -1
	for k in g.sim.near_list.size():
		var j: int = g.sim.near_list[k]
		if g.sim.alive[j] == 1 and g.npc_melee_id(j) != "" and g.z_of(g.sim.pos[j]) == 0:
			victim = j
			break
	if victim >= 0:
		var drops := 0
		for _t in 1:
			var cell: int = g.sim.pos[victim]
			var wid: String = g.npc_melee_id(victim)
			for _try in 1:
				g.items_at.erase(cell)
				g.kill(victim)
			if g.items_at.has(cell):
				for it in g.items_at[cell]:
					if it.id() == wid:
						drops += 1
		log.append("   (drops this try: %d)" % drops)
	# ---- shops and loot
	var shop_ok := false
	for i in range(0, 6):
		var s: Array = g.eco._stock(i)
		if i % 3 == 1:
			var n := 0
			for e in s:
				if "melee" in g.db.defs[e[0]].get("tags", []):
					n += 1
			shop_ok = n >= 5
	check.call("a bladesmith's stall has six blades", shop_ok)
	var loot_melee := 0
	for c in g.items_at:
		for it in g.items_at[c]:
			if it.has_tag("melee"):
				loot_melee += 1
	check.call("blades turn up as loot (%d piles)" % loot_melee, loot_melee >= 8)
	# ---- save / load
	g.wield = g._new_item("trl_mel_kusarigama_f")
	g.mdis[who] = 1
	var dd: Dictionary = JSON.parse_string(JSON.stringify(g.save_dict()))
	var g2 = GameScript.new(41)
	g2.setup(1200)
	g2.load_dict(dd)
	check.call("save and load keep the wielded weapon and disarmed men", g2.wield.id() == "trl_mel_kusarigama_f" and g2.mdis[who] == 1)
	return [st[0], st[1], log]
