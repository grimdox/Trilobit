extends SceneTree
## Bio + implant health, sleep from 8pm, healing items, the mend nano, implant power drain per turn.  Run: TRL_STREET=1 godot --headless -s tests/run_health.gd
const GameScript = preload("res://src/game.gd")
const BODY = preload("res://src/body.gd")
const NANO = preload("res://src/nanohacks.gd")
var ok := 0
var n := 0
func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _initialize() -> void:
	var g = GameScript.new(3)
	g.setup(300)
	g._sync_pools()
	var b = g.body
	check("a Trilobit (head implant) halves head bio health and adds its durability: bio %d (was 20), implant %d" % [int(b.mx["head"]), int(b.imx["head"])], int(b.mx["head"]) == 10 and int(b.imx["head"]) == 16 and int(b.mx["chest"]) == 40)
	check("limbs with no implant keep full bio health", int(b.mx["l_arm"]) == 24 and int(b.imx["l_arm"]) == 0)
	var before: int = b.total_of("head")
	g._limb_hit("head", 4)
	check("bio takes a hit first (implant untouched)", int(b.hp["head"]) == 6 and int(b.imp["head"]) == 16)
	g._limb_hit("head", 8)
	check("then the implant (6 bio, 2 over wears the implant)", int(b.hp["head"]) == 0 and int(b.imp["head"]) == 14 and not b.vital_dead() and b.ok("head"))
	g._limb_hit("head", 14)
	check("death when bio + implant health reach 0", b.vital_dead())
	# a fresh body: heal items
	g = GameScript.new(3)
	g.setup(300)
	g._sync_pools()
	g._limb_hit("chest", 30)
	var h0: int = int(g.body.hp["chest"])
	g.heal_body(10)
	check("healing closes bio health (+10)", int(g.body.hp["chest"]) == h0 + 10)
	g._limb_hit("head", 14)
	var imp0: int = int(g.body.imp["head"])
	g.heal_body(50)
	check("healing never repairs implants (%d -> %d)" % [imp0, int(g.body.imp["head"])], int(g.body.imp["head"]) == imp0)
	var items_ok := true
	for id in ["trl_heal_bandage", "trl_heal_gel", "trl_heal_stim", "trl_heal_suture"]:
		items_ok = items_ok and g.db.defs.has(id) and int(g.db.defs[id]["heal"]) > 0
	check("four healing items exist", items_ok)
	# the nano
	g = GameScript.new(3)
	g.setup(300)
	g._sync_pools()
	g._limb_hit("chest", 25)
	g.nanos = ["mend"]
	g.nano_fx = {}
	var hp_before: int = int(g.body.hp["chest"])
	var ok_use: bool = g.act_nano_use("mend")
	check("the test healing nano adds +10 bio health (%s)" % str(ok_use), ok_use and int(g.body.hp["chest"]) == hp_before + 10)
	# sleep
	g = GameScript.new(3)
	g.setup(300)
	g._sync_pools()
	g._limb_hit("chest", 30)
	g.sim.tick = 12 * g.CLK.HOUR + 100
	check("no sleeping at noon", not g.can_sleep() and not g.sleep_until(6))
	g.sim.tick = 21 * g.CLK.HOUR
	check("sleep is allowed from 8pm", g.can_sleep())
	var hp1: int = int(g.body.hp["chest"])
	var sleeps: bool = g.sleep_until(6)
	var spent := 0
	while g.waiting() and spent < 20000:
		spent += g.wait_step(600)
	check("a night's sleep heals bio health (%d -> %d)" % [hp1, int(g.body.hp["chest"])], sleeps and int(g.body.hp["chest"]) > hp1 + 20)
	# power per turn
	g = GameScript.new(3)
	g.setup(300)
	g._sync_pools()
	g.power = -1.0
	g._power_tick()
	var p0: float = g.power_left()
	for k in 600:
		g._tick()
	var drop: float = p0 - g.power_left()
	var want: float = float(g.PW.loadout(g.implants)["draw"])
	check("implants draw power every turn: 600 turns (one hour) cost %.3f kJ (rig draw %.2f kJ/h)" % [drop, want], absf(drop - want) < 0.05 and drop > 0.0)
	# a new game starts indoors, in a flat, never on the street
	GameScript.street_start = false
	var indoor_ok := true
	for sd in [3, 4, 5]:
		var gs = GameScript.new(sd)
		gs.setup(300)
		var t: int = gs.city.tiles[gs.pc % gs.s2]
		indoor_ok = indoor_ok and t != 0 and gs.city.tiles[gs.pc] != 0 and gs.light.indoor(gs.pc)
	check("a new game starts indoors (not on a road or in the open) on several seeds", indoor_ok)
	print("HEALTH %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
