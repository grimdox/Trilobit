extends RefCounted
## The player's body: six limbs, each with two pools: BIO health (hp / mx: regenerates with rest, food and healing items) and IMPLANT health (imp / imx: the summed durability
## of the implants fitted in that limb's group; only a repair service restores it).  A limb with any implant has its bio maximum halved.  Bio takes a hit first, then the implants.
## A limb is disabled when bio + implant is 0; the head or the chest at 0 in total is death.
const LIMBS := ["head", "chest", "l_arm", "r_arm", "l_leg", "r_leg"]
const NAME := {"head": "head", "chest": "chest", "l_arm": "left arm", "r_arm": "right arm", "l_leg": "left leg", "r_leg": "right leg"}
const BASE := {"head": 20, "chest": 40, "l_arm": 24, "r_arm": 24, "l_leg": 28, "r_leg": 28}
const WEIGHT := {"head": 8, "chest": 40, "l_arm": 13, "r_arm": 13, "l_leg": 13, "r_leg": 13}     # where a random hit lands (percent-ish)
## where a melee blow lands, in percent: torso 30, head 10, each arm and leg 15
const MELEE_WEIGHT := {"head": 10, "chest": 30, "l_arm": 15, "r_arm": 15, "l_leg": 15, "r_leg": 15}
## the implant slot groups: which limbs an implant needs in working order
const GROUP := {"head": "head", "chest": "chest", "l_arm": "arms", "r_arm": "arms", "l_leg": "legs", "r_leg": "legs"}
const PART_GROUP := {"head": "head", "eyes": "head", "spine": "chest", "chest": "chest", "dermal": "chest", "arms": "arms", "hands": "arms", "legs": "legs"}

var hp: Dictionary = {}                # bio health now
var mx: Dictionary = {}                # bio health maximum (halved when the limb carries an implant)
var imp: Dictionary = {}               # implant health now (the fitted implants' durability left)
var imx: Dictionary = {}               # implant health maximum

func _init() -> void:
	reset()

func reset() -> void:
	mx = BASE.duplicate()
	hp = BASE.duplicate()
	imp = {}
	imx = {}
	for l in LIMBS:
		imp[l] = 0
		imx[l] = 0

## bio + implant health of a limb now and at most
func total_of(limb: String) -> int:
	return int(hp[limb]) + int(imp.get(limb, 0))

func max_of(limb: String) -> int:
	return int(mx[limb]) + int(imx.get(limb, 0))

func ok(limb: String) -> bool:
	return total_of(limb) > 0

func frac(limb: String) -> float:
	return float(total_of(limb)) / float(maxi(1, max_of(limb)))

## set a limb's implant pools (game.gd, from the fitted implants) and rescale the bio maximum: halved with any implant, whole without.  Bio keeps its fraction.
func set_pools(limb: String, now: int, top: int) -> void:
	imp[limb] = now
	imx[limb] = top
	var want: int = BASE[limb] / 2 if top > 0 else int(BASE[limb])
	if int(mx[limb]) != want:
		var f: float = float(hp[limb]) / float(maxi(1, int(mx[limb])))
		mx[limb] = want
		hp[limb] = clampi(int(round(f * float(want))), 0 if int(hp[limb]) == 0 else 1, want)

## bio left of a limb is 0 and so is its implant health
func hurt_bio(limb: String) -> bool:
	return int(hp[limb]) < int(mx[limb])

## every limb of the group works (the group "all" is always true)
func group_ok(group: String) -> bool:
	if group == "all":
		return true
	for l in LIMBS:
		if GROUP[l] == group and not ok(l):
			return false
	return true

func arms_ok() -> int:
	return (1 if ok("l_arm") else 0) + (1 if ok("r_arm") else 0)

func legs_ok() -> int:
	return (1 if ok("l_leg") else 0) + (1 if ok("r_leg") else 0)

func vital_dead() -> bool:
	return total_of("head") <= 0 or total_of("chest") <= 0

func group_of_part(part: String) -> String:
	return PART_GROUP.get(part, "chest")

## a random limb, weighted towards the chest
func pick(rng: RandomNumberGenerator) -> String:
	var total := 0
	for l in LIMBS:
		total += int(WEIGHT[l])
	var r := rng.randi() % total
	for l in LIMBS:
		r -= int(WEIGHT[l])
		if r < 0:
			return l
	return "chest"

## the limb a melee blow lands on (MELEE_WEIGHT)
func pick_melee(rng: RandomNumberGenerator) -> String:
	var r := rng.randi() % 100
	for l in LIMBS:
		r -= int(MELEE_WEIGHT[l])
		if r < 0:
			return l
	return "chest"

## takes the hit on bio health only (the caller passes what is left over to the implants, then calls vital_dead).  Returns {"broke": bio reached 0, "dead": vital_dead()}
func damage(limb: String, amount: int) -> Dictionary:
	var before: int = hp[limb]
	hp[limb] = maxi(0, before - maxi(0, amount))
	var broke: bool = before > 0 and int(hp[limb]) == 0
	return {"broke": broke, "dead": vital_dead()}

func heal(limb: String, amount: int) -> void:
	hp[limb] = mini(int(mx[limb]), int(hp[limb]) + amount)

## repair everything up to a fraction of full health (disabled limbs come back too)
func mend_to(fraction: float) -> void:
	for l in LIMBS:
		hp[l] = maxi(int(hp[l]), int(ceil(float(mx[l]) * fraction)))

func worst() -> String:
	var w := "chest"
	var wf := 2.0
	for l in LIMBS:
		var f := frac(l)
		if f < wf:
			wf = f
			w = l
	return w

func total() -> int:
	var s := 0
	for l in LIMBS:
		s += total_of(l)
	return s

func to_dict() -> Dictionary:
	return {"hp": hp.duplicate(), "mx": mx.duplicate()}

func from_dict(d: Dictionary) -> void:
	reset()
	for l in LIMBS:
		hp[l] = int(d["hp"].get(l, BASE[l]))
		mx[l] = int(d["mx"].get(l, BASE[l]))
