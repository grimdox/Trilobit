extends SceneTree
## Prints the implant economy rundown (tiers 1-3, a generic mission, an average week and month) from the live rules.  Not a test: godot --headless -s tests/econ_rundown.gd
const PW = preload("res://src/power.gd")
const MS = preload("res://src/missions.gd")
const TP = preload("res://tests/test_power.gd")

const LIVING := 100            # yen a day: five cup ramen (18 each) and a coffee or two
const DEBT_DAY := 67           # the loan's minimum installment (150 per 3 days at least; 5% of the debt = 200 on 4,000) per day
const MISSION_TURNS := 600     # a generic mission: about an hour from portal to portal (entering, a quiet room-to-room, leaving)

func _initialize() -> void:
	var tot := 0
	var cnt := 0
	var by_type := {}
	var lo := 0
	var lon := 0
	for day in 60:
		for cell in [1000, 5000, 9000]:
			for o in MS.offers(21, cell, day):
				tot += int(o["reward"])
				cnt += 1
				by_type[o["type"]] = by_type.get(o["type"], []) + [int(o["reward"])]
				if int(o["risk"]) == 1:
					lo += int(o["reward"])
					lon += 1
	var avg: float = float(tot) / float(cnt)
	print("## Contracts: %d sampled postings, mean reward ¥%d (risk 1 only: ¥%d)" % [cnt, int(avg), int(lo / maxi(1, lon))])
	for t in by_type:
		var a: Array = by_type[t]
		print("   %s: ¥%d - ¥%d" % [t, a.min(), a.max()])
	print("\n## Rigs")
	print("| Rig | Implants | Hardware | Quality | Draw kJ/h | Full charge kJ (72 h) | Fee | Tax 5% | Power | Power tax | One recharge |")
	var costs := {}
	for tier in [1, 2, 3]:
		var rg: Dictionary = TP.rig(tier)
		var L: Dictionary = PW.loadout(rg)
		var q: Dictionary = PW.quote(rg, 1, float(L["cap"]))
		costs[tier] = int(q["total"])
		print("| Tier %d | %d | ¥%d | %d | %.0f | %d | %d | %d | %d | %d | **¥%d** |" % [tier, int(L["count"]), int(L["value"]), int(L["quality"]), L["draw"], int(L["cap"]), int(q["fee"]), int(q["tax"]), int(q["energy"]), int(q["ptax"]), int(q["total"])])
	print("\n## A generic mission (%d turns = %.1f h)" % [MISSION_TURNS, MISSION_TURNS / 600.0])
	print("| Rig | kJ drawn | Marginal power bill (power + power tax) | Share of the mission's mean pay |")
	for tier in [1, 2, 3]:
		var L: Dictionary = PW.loadout(TP.rig(tier))
		var kj: float = float(L["draw"]) * MISSION_TURNS / 600.0
		var q: Dictionary = PW.quote(TP.rig(tier), 1, kj)
		var marg: int = int(q["energy"]) + int(q["ptax"])
		print("| Tier %d | %.0f | ¥%d | %.1f%% |" % [tier, kj, marg, 100.0 * marg / avg])
	print("\n## Average week / month (living ¥%d/day, loan installments ¥%d/day, a recharge every 3 days)" % [LIVING, DEBT_DAY])
	print("| Missions a day | Rig | Gross per week | Recharge per week | Net per week | Net per month | Recharge share of income |")
	for mpd in [1.0, 2.0, 3.0]:
		for tier in [0, 1, 2, 3]:
			var gross: float = avg * mpd * 7.0
			var rech: float = 0.0
			if tier > 0:
				rech = float(costs[tier]) * 7.0 / 3.0
			var net: float = gross - rech - (LIVING + DEBT_DAY) * 7.0
			print("| %.0f | %s | %d | %d | %d | %d | %s |" % [mpd, "human" if tier == 0 else "Tier %d" % tier, int(gross), int(rech), int(net), int(net * 30.0 / 7.0), "-" if tier == 0 else "%.0f%%" % (100.0 * rech / gross)])
	print("\n## Place (Tier 2 rig, one full recharge)")
	print("| District | Total |")
	for d in [0, 1, 2]:
		var rg2: Dictionary = TP.rig(2)
		print("| %s | ¥%d |" % [["lower", "middle", "upper"][d], int(PW.quote(rg2, d, float(PW.loadout(rg2)["cap"]))["total"])])
	quit()
