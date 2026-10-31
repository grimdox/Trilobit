extends SceneTree
## Basic enemy tactics: gunmen keep their range band and take cover, melee fighters close in unless your gun is on them.
## Run: TRL_STREET=1 TRL_NOLIGHT=1 godot --headless --path . -s tests/run_tactics.gd
const GameScript = preload("res://src/game.gd")
const CG = preload("res://src/citygen.gd")
var ok := 0
var n := 0
func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

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
				var okk := true
				for ox in range(-3, len + 3):
					for oy in range(-3, 4):
						var c: int = (y + oy) * g.size + x + ox
						if g.sim.walk[c] == 0 or g.sim.at[c] != -1 or g.veh_at.g(c) != -1 or g.city.tiles[c] != g.city.tiles[y * g.size + x]:
							okk = false
				if okk:
					return y * g.size + x
	return -1

func _initialize() -> void:
	GameScript.street_start = true
	var g = GameScript.new(71)
	g.setup(1200)
	for l_ in g.BODY.LIMBS:
		g.body.hp[l_] = 100000
		g.body.mx[l_] = 100000
	var spot: int = _open_line(g, g.pc, 14)
	check("found open ground", spot >= 0)
	g.pc = spot
	g.last_pc = spot
	g.sim.retier(g.pc)
	var who := -1
	for j in g.sim.n:
		if g.sim.alive[j] == 1 and g.sim.sticky[j] == 0:
			who = j
			break
	var put = func(cell: int) -> void:
		g.sim.at[g.sim.pos[who]] = -1
		g.sim.pos[who] = cell
		g.sim.at[cell] = who
		g.sim.idle[who] = 1
		g.sim.sticky[who] = 1
		g.sim.near[who] = 1
		g.fac[who] = g.BRATVA
		g.hpn[who] = 50000
		g.hpmax[who] = 50000
		g.astate[who] = g.HUNTING
		g.sim.ctl[who] = 1
		g.stun[who] = 0
		g.aimn[who] = 0
		g.apn[who] = 100
		g.pc = spot
		g.last_pc = spot
		g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	# ---- a pistol (band 3-7) too close backs off
	g.gunc[who] = 1
	put.call(spot + 2)
	var d0: int = g.cheb(g.sim.pos[who], g.pc)
	g._hunt_act(who, d0, true)
	check("a gunman two tiles away backs off to keep his range (%d -> %d)" % [d0, g.cheb(g.sim.pos[who], g.pc)], g.cheb(g.sim.pos[who], g.pc) > d0)
	# ---- in the band, in the open, with a crate for cover one step off
	put.call(spot + 5)
	var crate_cell: int = spot + 5 + g.size * 0 + 1
	var tile_save: int = g.city.tiles[spot + 5 + 1 - g.size]
	g.city.tiles[spot + 5 + 1 - g.size] = CG.WALL        # a wall corner north-east of him: cover from the player's side only if it lies between them
	var c_before: int = g.sim.pos[who]
	var cov_before: int = g.cover_vs(g.pc, c_before, false)
	g._hunt_act(who, 5, true)
	var c_after: int = g.sim.pos[who]
	check("in the band he either shoots from where he is or steps into better cover, never away from the band (%d -> %d)" % [g.cover_vs(g.pc, c_before, false), g.cover_vs(g.pc, c_after, false)],
		g.cheb(c_after, g.pc) >= 3 and g.cheb(c_after, g.pc) <= 10 and g.cover_vs(g.pc, c_after, false) >= cov_before)
	g.city.tiles[spot + 5 + 1 - g.size] = tile_save
	# a crate beside the cell to his south, on the player's side: stepping there gives cover
	put.call(spot + 5)
	g.thing_at.s(spot + 4 + g.size, 0)
	var cov0: int = g.cover_vs(g.pc, spot + 5, false)
	g._hunt_act(who, 5, true)
	check("with cover one step away he takes it (cover %d -> %d)" % [cov0, g.cover_vs(g.pc, g.sim.pos[who], false)], cov0 == 0 and g.sim.pos[who] == spot + 5 + g.size and g.cover_vs(g.pc, g.sim.pos[who], false) > 0)
	g.thing_at.s(spot + 4 + g.size, -1)
	# ---- a rifle (band 10-15) far away closes in
	g.gunc[who] = 3
	put.call(spot + 14)
	var dr: int = g.cheb(g.sim.pos[who], g.pc)
	g._hunt_act(who, dr, true)
	check("a rifleman beyond his band closes in or fires (%d -> %d)" % [dr, g.cheb(g.sim.pos[who], g.pc)], g.cheb(g.sim.pos[who], g.pc) <= dr)
	# ---- melee fighters
	g.gunc[who] = 0
	var gun = null
	for k in g.db.defs:
		if "pistol" in g.db.defs[k].get("tags", []) and "gun" in g.db.defs[k].get("tags", []):
			gun = g._new_item(k)
			break
	put.call(spot + 6)
	g.inv.equip.erase("rhand")
	var dm0: int = g.cheb(g.sim.pos[who], g.pc)
	g._hunt_act(who, dm0, true)
	check("a melee fighter you are not aiming at closes in (%d -> %d)" % [dm0, g.cheb(g.sim.pos[who], g.pc)], g.cheb(g.sim.pos[who], g.pc) < dm0)
	g.inv.stow(gun)
	g.act_wield(gun)
	gun.loaded = 10
	put.call(spot + 6)
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	g.aim_target = who
	g.sim.near_list = PackedInt32Array([who]) if g.sim.near_list is PackedInt32Array else [who]
	check("your loaded gun is on him", g._player_gun_on(who))
	var dm1: int = g.cheb(g.sim.pos[who], g.pc)
	g._hunt_act(who, dm1, true)
	check("a melee fighter with your gun on him keeps away (%d -> %d)" % [dm1, g.cheb(g.sim.pos[who], g.pc)], g.cheb(g.sim.pos[who], g.pc) > dm1)
	put.call(spot + 2)
	g.aim_target = who
	var dm2: int = g.cheb(g.sim.pos[who], g.pc)
	g._hunt_act(who, dm2, true)
	check("but inside two tiles he closes in anyway (%d -> %d)" % [dm2, g.cheb(g.sim.pos[who], g.pc)], g.cheb(g.sim.pos[who], g.pc) <= dm2)
	# ---- manual targeting then aiming at someone who is not hostile
	put.call(spot + 5)
	g.astate[who] = g.UNAWARE
	g.fac[who] = g.CIV
	g.aim_target = -1
	g.fov.compute(g.pc % g.size, g.pc / g.size, 18)
	var picked: bool = g.act_manual_target(g.sim.pos[who])
	var a0: int = g.aim_turns
	var aimed: bool = g.act_aim()
	check("a hand-picked non-hostile target can be aimed at (picked %s, aimed %s)" % [str(picked), str(aimed)], picked and aimed and g.aim_target == who)
	print("TACTICS %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
