extends RefCounted
## The player's body: six limbs, each with its own health.  A limb at 0 is disabled (its implants stop working, and it hurts what you can do).
## The head or the chest at 0 is death: there is no overall health pool, only these limbs (and the implants fitted in them, which take what a broken limb cannot).
const LIMBS := ["head", "chest", "l_arm", "r_arm", "l_leg", "r_leg"]
const NAME := {"head": "head", "chest": "chest", "l_arm": "left arm", "r_arm": "right arm", "l_leg": "left leg", "r_leg": "right leg"}
const BASE := {"head": 20, "chest": 40, "l_arm": 24, "r_arm": 24, "l_leg": 28, "r_leg": 28}
const WEIGHT := {"head": 8, "chest": 40, "l_arm": 13, "r_arm": 13, "l_leg": 13, "r_leg": 13}     # where a random hit lands (percent-ish)
## where a melee blow lands, in percent: torso 30, head 10, each arm and leg 15
const MELEE_WEIGHT := {"head": 10, "chest": 30, "l_arm": 15, "r_arm": 15, "l_leg": 15, "r_leg": 15}
## the implant slot groups: which limbs an implant needs in working order
const GROUP := {"head": "head", "chest": "chest", "l_arm": "arms", "r_arm": "arms", "l_leg": "legs", "r_leg": "legs"}
const PART_GROUP := {"head": "head", "eyes": "head", "spine": "chest", "chest": "chest", "dermal": "chest", "arms": "arms", "hands": "arms", "legs": "legs"}

var hp: Dictionary = {}
var mx: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	mx = BASE.duplicate()
	hp = BASE.duplicate()

func ok(limb: String) -> bool:
	return int(hp[limb]) > 0

func frac(limb: String) -> float:
	return float(hp[limb]) / float(mx[limb])

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
	return not ok("head") or not ok("chest")

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

## returns {"broke": the limb just reached 0, "dead": a vital limb is gone}
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
		s += int(hp[l])
	return s

func to_dict() -> Dictionary:
	return {"hp": hp.duplicate(), "mx": mx.duplicate()}

func from_dict(d: Dictionary) -> void:
	reset()
	for l in LIMBS:
		hp[l] = int(d["hp"].get(l, BASE[l]))
		mx[l] = int(d["mx"].get(l, BASE[l]))
