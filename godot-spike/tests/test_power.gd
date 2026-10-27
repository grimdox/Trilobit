extends RefCounted
## Implant power: the pure rules of power.gd (tiers, draw, a full charge, the four-part price).  Returns [passed, total, log].
const PW = preload("res://src/power.gd")
const IMP = preload("res://src/implants.gd")
var ok := 0
var n := 0
var log: Array = []

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	log.append(("  PASS " if cond else "  FAIL ") + name)

## reference rigs (catalogue ids): the Bratva's four Basic implants, the NAP's five Improved ones, and a full Improved rig of eight with a chest battery
static func rig(tier: int) -> Dictionary:
	var ids: Array = ["x105", "x108", "x116", "x122"]
	if tier >= 2:
		ids = ["x205", "x208", "x214", "x216", "x222"]
	if tier >= 3:
		ids = ["x201", "x205", "x208", "x211", "x214", "x216", "x219", "x222"]
	var d := {}
	for i in ids:
		d[i] = true
	return d

func run() -> Array:
	check("every implant has a tier from 1 to 3", IMP.ALL.all(func(d): return PW.tier_of(d) >= 1 and PW.tier_of(d) <= 3))
	check("the catalogue's tier is its grade: Basic 1, Improved 2, Quality 3 (draw 0.5 / 1 / 2 kJ per hour, doubling with each tier)", IMP.DATA.ALL.all(func(d): return PW.draw_of(d) == 0.5 * pow(2.0, float(int(d["grade"]) - 1))))
	var l1: Dictionary = PW.loadout(rig(1))
	var l2: Dictionary = PW.loadout(rig(2))
	var l3: Dictionary = PW.loadout(rig(3))
	check("Basic rig: 4 implants draw 2 kJ/h and run on the built-in 168 kJ cell (84 h)", int(l1["count"]) == 4 and l1["draw"] == 2.0 and l1["cap"] == PW.BASE_CELL_KJ and PW.hours_left(rig(1), l1["cap"]) == 84.0)
	check("a rig of five Improved implants draws 5 kJ/h", int(l2["count"]) == 5 and l2["draw"] == 5.0 and l2["cap"] == PW.BASE_CELL_KJ)
	check("a full Improved rig (one per layer, 8 implants) draws 8 kJ/h and its chest battery (1,344 kJ) lasts exactly a week", int(l3["count"]) == 8 and l3["draw"] == 8.0 and l3["cap"] == 1344.0 and PW.hours_left(rig(3), l3["cap"]) == 168.0)
	check("a chest battery is worth its draw: the Improved Lung Pack stores a week of an eight-implant Improved rig", IMP.get_def("x211")["battery"] == 1344 and IMP.get_def("x211")["draw"] == 1.0)
	check("batteries double per tier, and Reserve Cells hold three times the standard", IMP.get_def("x311")["battery"] == 2688 and IMP.get_def("x213")["battery"] == 4032)
	check("one turn costs a rig draw / 600 kJ (a turn is 6 s)", absf(PW.turn_draw(rig(1)) - 2.0 / 600.0) < 1e-9)
	check("no implants: no draw, no capacity, no hours", PW.loadout({})["cap"] == 0.0 and PW.hours_left({}, 100.0) == 0.0 and PW.turn_draw({}) == 0.0)
	# the price of a recharge: tax + power + power tax (the quality fee became the repair cost), middle district
	var q: Dictionary = PW.quote(rig(1), 1, 168.0)
	var worth: int = int(l1["value"])
	check("no quality fee any more", int(q["fee"]) == 0)
	check("implant tax: 5%% of the hardware's price per recharge (%d on %d)" % [int(q["tax"]), worth], int(q["tax"]) == int(round(float(worth) * 0.05)) and absf(float(q["tax_pct"]) - 5.0) < 1e-9)
	check("power: 1 yen per kJ in the middle district: 168", int(q["energy"]) == 168)
	check("power tax: 0.1 yen per kJ: 17 (16.8 rounded)", int(q["ptax"]) == 17)
	check("the total is the three parts added", int(q["total"]) == int(q["tax"]) + int(q["energy"]) + int(q["ptax"]))
	var half: Dictionary = PW.quote(rig(1), 1, 84.0)
	check("half a charge pays the same tax but half the power: fixed parts do not shrink", int(half["tax"]) == int(q["tax"]) and int(half["energy"]) == 84 and int(half["total"]) < int(q["total"]))
	check("nothing asked for nothing delivered, or for no implants", int(PW.quote(rig(1), 1, 0.0)["total"]) == 0 and int(PW.quote({}, 1, 500.0)["total"]) == 0)
	check("the lower district is cheaper and the upper dearer", PW.power_rate(0) < PW.power_rate(1) and PW.power_rate(1) < PW.power_rate(2) and PW.power_rate(1) == 1.0)
	check("the upper district costs more than the lower for the same charge", int(PW.quote(rig(1), 2, 168.0)["total"]) > int(PW.quote(rig(1), 0, 168.0)["total"]))
	check("a district out of range is clamped, not a crash", PW.power_rate(9) == PW.power_rate(2) and PW.power_rate(-1) == PW.power_rate(0))
	var aff: float = PW.affordable_kj(rig(1), 1, 1000)
	var fixed: int = int(PW.quote(rig(1), 1, 1.0)["tax"])
	check("what 1,000 yen buys: after the tax (%d) the rest at 1.1 per kJ" % fixed, aff == maxf(0.0, floorf(float(1000 - fixed) / 1.1)))
	check("a purse that does not cover the tax buys nothing", PW.affordable_kj(rig(1), 1, fixed) == 0.0)
	check("the affordable amount never costs more than the purse", int(PW.quote(rig(1), 1, aff)["total"]) <= 1000)
	# repairs: a quarter of the price at 100% wear, in proportion
	var d: Dictionary = IMP.get_def("x211")
	check("repair: nothing when as new, a quarter of the price when worn out, half that at half wear", IMP.repair_cost(d, IMP.dur(d)) == 0 and IMP.repair_cost(d, 0) == int(round(d["cost"] * 0.25)) and absi(IMP.repair_cost(d, IMP.dur(d) / 2) - IMP.repair_cost(d, 0) / 2) <= int(d["cost"]) / IMP.dur(d))
	# NPCs
	var bratva_draw := 0.0
	for id in IMP.NPC_RIGS[1]:
		bratva_draw += PW.draw_of(IMP.get_def(id))
	var nap_draw := 0.0
	for id in IMP.NPC_RIGS[2]:
		nap_draw += PW.draw_of(IMP.get_def(id))
	check("NPC draw follows their rigs: Bratva four Basic implants (2 kJ/h), NAP five Improved ones (5), Nasim, gangs and civilians none", PW.NPC_DRAW[1] == bratva_draw and PW.NPC_DRAW[2] == nap_draw and bratva_draw == 2.0 and nap_draw == 5.0 and PW.NPC_DRAW[3] == 0.0 and PW.NPC_DRAW[0] == 0.0 and PW.NPC_DRAW[4] == 0.0)
	var rems: Array = []
	for k in 200:
		rems.append(PW.npc_remaining(1, k, 21, 0))
	check("a Bratva holds between nothing and 144 kJ (72 h of 2 kJ/h), spread across the people (%d-%d)" % [rems.min(), rems.max()], rems.min() >= 0 and rems.max() <= 144 and rems.max() - rems.min() > 60)
	var nap_max := 0
	for k in 200:
		nap_max = maxi(nap_max, PW.npc_remaining(2, k, 21, 0))
	check("the same person at the same time always holds the same, and a NAP holds up to 360 (%d)" % nap_max, PW.npc_remaining(1, 7, 21, 5000) == PW.npc_remaining(1, 7, 21, 5000) and nap_max > 144 and nap_max <= 360)
	check("civilians and Nasim hold nothing", PW.npc_remaining(0, 4, 21, 99) == 0 and PW.npc_remaining(3, 4, 21, 99) == 0)
	check("a draw takes a tenth of what is left, at least 1: 400 -> 40, 5 -> 1, 0 -> 0", PW.siphon_take(400) == 40 and PW.siphon_take(5) == 1 and PW.siphon_take(0) == 0)
	check("each draw takes less than the last (400 -> 360 left -> 36 taken)", PW.siphon_take(360) == 36)
	return [ok, n, log]
