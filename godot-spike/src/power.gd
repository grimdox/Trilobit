extends RefCounted
## Implant power: what implants draw, what a full charge holds, and what a government charging post asks for a recharge.  Pure data and rules;
## game.gd owns the store and the clock, economy.gd the menu at the post.
##   Every fitted implant has a tier (its grade minus one: street grade 2 is tier 1, military grade 4 is tier 3) and draws kJ per hour by tier.
##   A full charge is FULL_HOURS of the fitted implants' combined draw, so the timer is the same for any rig: about three days.
##   At 0 the implants stop (game.gd gates has_implant, imp_sum and armor on it): the player is "just" a normal human until recharged.
## The price of a recharge is four parts:
##   1  quality fee    QUALITY_FEE yen for each tier point of fitted implants (a tier 1 implant 100, tier 2 200, tier 3 300), charged once a visit
##   2  implant tax    TAX_PCT percent of the fitted implants' total price, once a visit; the player's heat adds TAX_PER_HEAT percent a point
##   3  power cost     POWER_RATE yen per kJ delivered, times the district (DISTRICT_RATE: lower, middle, upper) and (1 + heat / 200)
##   4  power tax      POWER_TAX yen per kJ delivered, times (1 + heat / 100)
## Heat (0-100, what the police and the corporations know of you) is the reputation: there are no faction ranks in the Godot game yet.
const IMP = preload("res://src/implants.gd")

const FULL_HOURS := 72.0
const TIER_DRAW := {1: 2.0, 2: 4.0, 3: 8.0}                # kJ per hour
const QUALITY_FEE := 100
const TAX_PCT := 5.0
const TAX_PER_HEAT := 0.1
const POWER_RATE := 1.0
const DISTRICT_RATE := [0.85, 1.0, 1.35]                   # lower, middle, upper (the charging posts of the rich districts are dearer)
const POWER_TAX := 0.1
const HOUR_TURNS := 600                                     # clock.gd: one hour is 600 turns
## what a person carries in an energy cell, by faction (game.gd: CIV 0, BRATVA 1, NAP 2, NASIM 3, GANG 4), in kJ.  Nasim refuse implants (design: absolutely none).
const NPC_ENERGY := [0, 40, 120, 0, 0]
const SIPHON_BASE := 12                                     # kJ drawn from a downed person in one go, plus SIPHON_PER_LEVEL per Engineering level
const SIPHON_PER_LEVEL := 3

static func tier_of(d: Dictionary) -> int:
	return clampi(int(d.get("grade", 2)) - 1, 1, 3)

## kJ per hour this implant draws
static func draw_of(d: Dictionary) -> float:
	return float(d.get("draw", TIER_DRAW[tier_of(d)]))

## the sums for a rig (a dictionary of fitted ids): draw (kJ/h), cap (kJ of a full charge), quality (tier points), value (what the implants cost)
static func loadout(implants: Dictionary) -> Dictionary:
	var draw := 0.0
	var q := 0
	var value := 0
	var n := 0
	for d in IMP.ALL:
		if implants.get(d["id"], false):
			draw += draw_of(d)
			q += tier_of(d)
			value += int(d["cost"])
			n += 1
	return {"count": n, "draw": draw, "cap": draw * FULL_HOURS, "quality": q, "value": value}

## how much one turn costs the store
static func turn_draw(implants: Dictionary) -> float:
	return float(loadout(implants)["draw"]) / float(HOUR_TURNS)

static func tax_pct(heat: int) -> float:
	return TAX_PCT + TAX_PER_HEAT * float(clampi(heat, 0, 100))

static func power_rate(heat: int, district: int) -> float:
	return POWER_RATE * float(DISTRICT_RATE[clampi(district, 0, 2)]) * (1.0 + float(clampi(heat, 0, 100)) / 200.0)

static func power_tax_rate(heat: int) -> float:
	return POWER_TAX * (1.0 + float(clampi(heat, 0, 100)) / 100.0)

## the yen asked for delivering `kj` kJ: {fee, tax, energy, ptax, total, kj, tax_pct}.  Nothing is delivered, nothing is charged.
static func quote(implants: Dictionary, heat: int, district: int, kj: float) -> Dictionary:
	var L: Dictionary = loadout(implants)
	var out := {"fee": 0, "tax": 0, "energy": 0, "ptax": 0, "total": 0, "kj": 0.0, "tax_pct": tax_pct(heat)}
	if kj <= 0.0 or int(L["count"]) == 0:
		return out
	out["kj"] = kj
	out["fee"] = QUALITY_FEE * int(L["quality"])
	out["tax"] = int(round(float(L["value"]) * tax_pct(heat) / 100.0))
	out["energy"] = int(round(kj * power_rate(heat, district)))
	out["ptax"] = int(round(kj * power_tax_rate(heat)))
	out["total"] = int(out["fee"]) + int(out["tax"]) + int(out["energy"]) + int(out["ptax"])
	return out

## the most kJ `yen` pays for after the visit's fixed charges (0 if it does not cover them)
static func affordable_kj(implants: Dictionary, heat: int, district: int, yen: int) -> float:
	var fixed: Dictionary = quote(implants, heat, district, 1.0)
	var left: float = float(yen) - float(fixed["fee"]) - float(fixed["tax"])
	if left <= 0.0:
		return 0.0
	return floorf(left / (power_rate(heat, district) + power_tax_rate(heat)))

## hours of life a charge of `kj` gives a rig
static func hours_left(implants: Dictionary, kj: float) -> float:
	var d: float = float(loadout(implants)["draw"])
	return kj / d if d > 0.0 else 0.0
