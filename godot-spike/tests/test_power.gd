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

## the three reference rigs the economy is balanced on (see the rundown): what a player typically wears at each stage
static func rig(tier: int) -> Dictionary:
	var ids: Array = ["smartlink", "optics", "legs", "dermal"]
	if tier >= 2:
		ids += ["cortex", "mantis"]
	if tier >= 3:
		ids += ["reflex", "synapse"]
	var d := {}
	for i in ids:
		d[i] = true
	return d

func run() -> Array:
	# tiers follow the grade: street grade 2 is tier 1, grade 3 tier 2, military grade 4 tier 3
	check("every implant has a tier from 1 to 3", IMP.ALL.all(func(d): return PW.tier_of(d) >= 1 and PW.tier_of(d) <= 3))
	check("grade 2 / 3 / 4 are tier 1 / 2 / 3", PW.tier_of(IMP.get_def("optics")) == 1 and PW.tier_of(IMP.get_def("reflex")) == 2 and PW.tier_of(IMP.get_def("synapse")) == 3)
	check("a higher tier draws more: 2 / 4 / 8 kJ per hour", PW.draw_of(IMP.get_def("optics")) == 2.0 and PW.draw_of(IMP.get_def("cortex")) == 4.0 and PW.draw_of(IMP.get_def("synapse")) == 8.0)
	var l1: Dictionary = PW.loadout(rig(1))
	var l2: Dictionary = PW.loadout(rig(2))
	var l3: Dictionary = PW.loadout(rig(3))
	check("tier 1 rig: 4 implants, 8 kJ/h, 576 kJ for a full charge (72 h), quality 4, hardware 7,100 yen", int(l1["count"]) == 4 and l1["draw"] == 8.0 and l1["cap"] == 576.0 and int(l1["quality"]) == 4 and int(l1["value"]) == 7100)
	check("tier 2 rig: 6 implants, 16 kJ/h, quality 8, hardware 14,700 yen", int(l2["count"]) == 6 and l2["draw"] == 16.0 and int(l2["quality"]) == 8 and int(l2["value"]) == 14700)
	check("tier 3 rig: 8 implants, 28 kJ/h, quality 13, hardware 31,900 yen", int(l3["count"]) == 8 and l3["draw"] == 28.0 and int(l3["quality"]) == 13 and int(l3["value"]) == 31900)
	check("a full charge is 72 hours for any rig", PW.hours_left(rig(1), l1["cap"]) == 72.0 and PW.hours_left(rig(3), l3["cap"]) == 72.0)
	check("one turn costs a rig draw / 600 kJ (a turn is 6 s)", absf(PW.turn_draw(rig(1)) - 8.0 / 600.0) < 1e-9)
	check("no implants: no draw, no capacity, no hours", PW.loadout({})["cap"] == 0.0 and PW.hours_left({}, 100.0) == 0.0 and PW.turn_draw({}) == 0.0)
	# the four parts of a price, at the start of the game (middle district)
	var q: Dictionary = PW.quote(rig(1), 1, 576.0)
	check("fee: 100 yen a tier point (base implants 100 each): 400 for the tier 1 rig", int(q["fee"]) == 400)
	check("implant tax: 5% of the hardware's price per recharge: 355 on 7,100", int(q["tax"]) == 355 and absf(float(q["tax_pct"]) - 5.0) < 1e-9)
	check("power: 1 yen per kJ in the middle district: 576", int(q["energy"]) == 576)
	check("power tax: 0.1 yen per kJ: 58 (57.6 rounded)", int(q["ptax"]) == 58)
	check("the total is the four parts added: 400 + 355 + 576 + 58 = 1,389", int(q["total"]) == 1389 and int(q["total"]) == int(q["fee"]) + int(q["tax"]) + int(q["energy"]) + int(q["ptax"]))
	var half: Dictionary = PW.quote(rig(1), 1, 288.0)
	check("half a charge pays the same fee and tax but half the power: fixed parts do not shrink", int(half["fee"]) == 400 and int(half["tax"]) == 355 and int(half["energy"]) == 288 and int(half["total"]) < int(q["total"]))
	check("nothing asked for nothing delivered, or for no implants", int(PW.quote(rig(1), 1, 0.0)["total"]) == 0 and int(PW.quote({}, 1, 500.0)["total"]) == 0)
	# reputation and place
	check("the lower district is cheaper and the upper dearer", PW.power_rate(0) < PW.power_rate(1) and PW.power_rate(1) < PW.power_rate(2) and PW.power_rate(1) == 1.0)
	check("the upper district costs more than the lower for the same charge", int(PW.quote(rig(1), 2, 576.0)["total"]) > int(PW.quote(rig(1), 0, 576.0)["total"]))
	check("a district out of range is clamped, not a crash", PW.power_rate(9) == PW.power_rate(2) and PW.power_rate(-1) == PW.power_rate(0))
	# affordable_kj
	var aff: float = PW.affordable_kj(rig(1), 1, 1000)
	check("what 1,000 yen buys: after fee and tax (755) 245 left at 1.1 per kJ = 222 kJ", aff == 222.0)
	check("a purse that does not cover the fee and tax buys nothing", PW.affordable_kj(rig(1), 1, 700) == 0.0)
	var spend: Dictionary = PW.quote(rig(1), 1, aff)
	check("the affordable amount never costs more than the purse", int(spend["total"]) <= 1000)
	# comparisons to existing values
	check("a full tier 1 recharge is less than 4 days of a modest income and about the price of one mid implant: 1,389 vs Optic Suite 1,800", int(q["total"]) < 1800)
	check("NPC draw: Bratva wear a tier 1 rig (8 kJ/h, the player's), NAP a tier 2 rig (16), Nasim, gangs and civilians none", PW.NPC_DRAW[1] == 8.0 and PW.NPC_DRAW[2] == 16.0 and PW.NPC_DRAW[3] == 0.0 and PW.NPC_DRAW[0] == 0.0 and PW.NPC_DRAW[4] == 0.0)
	var rems: Array = []
	for k in 200:
		rems.append(PW.npc_remaining(1, k, 21, 0))
	check("a Bratva holds between nothing and a full 576 kJ, spread across the people (%d-%d)" % [rems.min(), rems.max()], rems.min() >= 0 and rems.max() <= 576 and rems.max() - rems.min() > 300)
	var nap_max := 0
	for k in 200:
		nap_max = maxi(nap_max, PW.npc_remaining(2, k, 21, 0))
	check("the same person at the same time always holds the same, and a NAP holds up to twice a Bratva (%d)" % nap_max, PW.npc_remaining(1, 7, 21, 5000) == PW.npc_remaining(1, 7, 21, 5000) and nap_max > 576 and nap_max <= 1152)
	check("a charge runs down with the clock: 10 hours later a Bratva has lost 80 kJ (or been recharged)", PW.npc_remaining(1, 3, 21, 0) - PW.npc_remaining(1, 3, 21, 6000) in [79, 80, 81] or PW.npc_remaining(1, 3, 21, 6000) > PW.npc_remaining(1, 3, 21, 0))
	check("civilians and Nasim hold nothing", PW.npc_remaining(0, 4, 21, 99) == 0 and PW.npc_remaining(3, 4, 21, 99) == 0)
	check("a draw takes a tenth of what is left, at least 1: 400 -> 40, 5 -> 1, 0 -> 0", PW.siphon_take(400) == 40 and PW.siphon_take(5) == 1 and PW.siphon_take(0) == 0)
	check("each draw takes less than the last (400 -> 360 left -> 36 taken)", PW.siphon_take(360) == 36)
	return [ok, n, log]
