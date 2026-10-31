extends RefCounted
## The enemy roster: every armed faction at every level from 1 to 10 (gangs, Bratva, the NAP, Nasim, corporate security).  Civilians are not enemies and keep their own rules.
## Everything an enemy is follows from (faction, level), so the roster is a table you can read (tools/export_enemies.py writes it to data/enemy_roster.xlsx):
##  HEALTH   80% of what a PC of that level would have.  A PC has 164 hp (head 20, chest 40, arms 24 x2, legs 28 x2) and, by level 10, a whole body of QL4 implants.  QL4 is
##           taken as the next step above the catalogue's Quality grade: 60 durability a part over the 8 implant parts = 480.  The PC's effective health rises evenly from 164
##           (level 1) to 644 (level 10), and an enemy has 0.8 of that: 131 at level 1, 515 at level 10.  That figure already counts what their implants soak, so implants add
##           skills and armour only (armour here is the vests and implant plating, a flat deduction).
##  SKILLS   never above the level.  One combat skill sits at the level itself (the faction's own: Melee for Bratva and Nasim, Unarmed for gangs, Ranged for the NAP and corporate
##           security), the other combat skill one below, the support skills at half the level (rounded up) and the rest a third.
##  GUNS     level 1 none; level 2 half of them have one; level 3 on all do, and the class rises: pistols, then SMGs, then rifles.
##  IMPLANTS up to 8 can roll (one per body part) at the top; the number and the quality range both rise with level.  Nasim refuse implants, gangs can afford two cheap ones,
##           the Bratva up to six, the NAP and corporate security the full table.
## A level-1 recruit is not a weaker kind of person than a level-10 veteran: it is the same faction a little earlier on.
const FAC_BRATVA := 1
const FAC_NAP := 2
const FAC_NASIM := 3
const FAC_GANG := 4
const FAC_CORP := 5

const BODY_BASE := 164.0                    # head 20 + chest 40 + arms 48 + legs 56
const QL4_PART_DUR := 60.0                  # durability of one QL4 implant (QL3 averages 46)
const IMPLANT_PARTS := 8
const ENEMY_SHARE := 0.8

const NAMES := {
	1: ["Errand Boy", "Torpedo", "Boyevik", "Silovik", "Brigadir", "Avtoritet's Fist", "Sovetnik", "Pakhan's Blade", "Vor", "Vor v Zakone"],
	2: ["Cadet", "Recruit Patrol", "Patrol Officer", "Senior Officer", "Sergeant", "Lieutenant", "Tactical Officer", "Captain", "Response Agent", "Commissioner's Guard"],
	3: ["Runner", "Blade Courier", "Operative", "Shadow", "Cutter", "Silent Hand", "Wire Adept", "Elder's Knife", "Ghost", "Grand Assassin"],
	4: ["Street Kid", "Corner Hustler", "Gang Member", "Enforcer", "Crew Lead", "Hard Case", "Cell Boss", "Warlord's Hand", "Street Marshal", "Gang Warlord"],
	5: ["Gate Guard", "Security Trainee", "Security Officer", "Patrol Lead", "Site Sergeant", "Response Agent", "Tactical Agent", "Black-Ops Operator", "Executive Protection", "Chief of Security"],
}
const FAC_LABEL := {1: "Bratva", 2: "NAP", 3: "Nasim", 4: "Gang (unaffiliated)", 5: "Corporate security"}

## [primary combat skill (= level), secondary combat (= level - 1), support skills]
const PROFILE := {
	1: ["melee", "grit", ["unarmed", "ranged", "streetwise", "negotiation"]],
	2: ["ranged", "grit", ["melee", "etiquette", "analysis", "networking", "dodge"]],
	3: ["melee", "dodge", ["deception", "streetwise", "ranged", "unarmed"]],
	4: ["unarmed", "melee", ["grit", "streetwise", "ranged", "dodge"]],
	5: ["ranged", "grit", ["melee", "analysis", "etiquette", "dodge", "engineering"]],
}

## the implants that can roll: [min count, max count] and [lowest QL, highest QL] by level (the table is for the NAP and corporate security; others are capped, see implant_caps)
const IMPLANT_COUNT := [[0, 0], [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8], [8, 8]]
const IMPLANT_QL := [[0, 0], [1, 1], [1, 1], [1, 2], [1, 2], [2, 2], [2, 3], [2, 3], [3, 4], [3, 4]]
## faction caps: [max count, highest QL]
const IMPLANT_CAPS := {1: [6, 2], 2: [8, 4], 3: [0, 0], 4: [2, 1], 5: [8, 4]}

## gun class (0 none, 1 pistol, 2 SMG, 3 rifle) odds by level, in percent [none, pistol, smg, rifle]; level 2 is the mix, level 3 on all armed
const GUN_ODDS := [[100, 0, 0, 0], [50, 50, 0, 0], [0, 100, 0, 0], [0, 70, 30, 0], [0, 40, 60, 0], [0, 20, 70, 10], [0, 0, 60, 40], [0, 0, 40, 60], [0, 0, 20, 80], [0, 0, 0, 100]]
const GUN_CLASS := ["none", "pistol", "SMG", "rifle"]
## faction ceilings on the gun class: Nasim and gangs do not field rifles below level 8
const GUN_CAP := {1: 3, 2: 3, 3: 2, 4: 2, 5: 3}

static func clampl(l: int) -> int:
	return clampi(l, 1, 10)

static func title(fac: int, level: int) -> String:
	return NAMES[fac][clampl(level) - 1]

## a PC's health at this level, counting a body of implants that grows to QL4 at level 10
static func pc_health(level: int) -> float:
	return BODY_BASE + QL4_PART_DUR * IMPLANT_PARTS * float(clampl(level) - 1) / 9.0

static func total_hp(level: int) -> int:
	return int(round(ENEMY_SHARE * pc_health(level)))

## the sim's hpmax figure (limbs are BASE x hpmax / 60, see Game.npc_limb_max) that gives this body total
static func hpmax(level: int) -> int:
	return int(round(float(total_hp(level)) * 60.0 / BODY_BASE))

static func limb_hp(level: int, limb: String) -> int:
	var base := {"head": 20, "chest": 40, "l_arm": 24, "r_arm": 24, "l_leg": 28, "r_leg": 28}
	return maxi(3, int(round(float(base[limb]) * float(hpmax(level)) / 60.0)))

## one skill's level for an enemy of this faction and level (0 for skills they do not have)
static func skill(fac: int, level: int, id: String) -> int:
	var l: int = clampl(level)
	var p: Array = PROFILE[fac]
	if id == p[0]:
		return l
	if id == p[1]:
		return maxi(1, l - 1)
	var k: int = (p[2] as Array).find(id)
	if k < 0:
		return 0
	return maxi(1, (l + 1) / 2) if k < 2 else maxi(1, l / 3)

static func skills(fac: int, level: int) -> Dictionary:
	var out := {}
	var p: Array = PROFILE[fac]
	for id in [p[0], p[1]] + (p[2] as Array):
		out[id] = skill(fac, level, id)
	return out

## the implants that can roll: [min count, max count, lowest QL, highest QL]
static func implant_range(fac: int, level: int) -> Array:
	var l: int = clampl(level) - 1
	var cap: Array = IMPLANT_CAPS[fac]
	var cnt: Array = IMPLANT_COUNT[l]
	var ql: Array = IMPLANT_QL[l]
	var mx: int = mini(int(cnt[1]), int(cap[0]))
	var mn: int = mini(int(cnt[0]), mx)
	var qhi: int = mini(int(ql[1]), int(cap[1]))
	var qlo: int = mini(int(ql[0]), qhi)
	if mx == 0:
		return [0, 0, 0, 0]
	return [mn, mx, maxi(1, qlo), maxi(1, qhi)]

## the armour tier an enemy wears: levels 1-2 wear +1 armour (Street), 3-4 +2 (Patrol), 5-6 +3 (Kevlar), 7-8 +4 (Plasteel), 9-10 +5 (Nanofab)
static func armor_tier(level: int) -> int:
	return (clampl(level) + 1) / 2

## flat armour on the torso: implant plating (the middle count and QL spread over the body: n/8 x (1.5 + QL)) plus the chest piece of the tier they wear
static func armor(fac: int, level: int) -> int:
	var r: Array = implant_range(fac, level)
	var plating: float = 0.0
	if int(r[1]) > 0:
		plating = (float(r[0] + r[1]) * 0.5 / float(IMPLANT_PARTS)) * (1.5 + float(r[2] + r[3]) * 0.5)
	return int(round(plating)) + armor_tier(level)

## the armour piece of a slot ("head", "chest", "arms", "legs") at a tier
static func piece_id(slot: String, tier: int) -> String:
	return "trl_armor_%s_%d" % [slot, clampi(tier, 1, 5)]

## the chest piece they wear (the one the roster lists)
static func vest_id(_fac: int, level: int) -> String:
	return piece_id("chest", armor_tier(level))

## a piece of their tier for a drop: the slot comes from the roll
static func drop_piece(level: int, roll: int) -> String:
	return piece_id(["chest", "head", "arms", "legs"][roll % 4], armor_tier(level))

## the gun class this person carries (0 none ... 3 rifle): deterministic from the world seed and their index
static func gun_class(fac: int, level: int, seed_value: int, person: int) -> int:
	var odds: Array = GUN_ODDS[clampl(level) - 1]
	var roll: int = hash([seed_value, person, "gun"]) % 100
	var acc := 0
	var out := 0
	for k in 4:
		acc += int(odds[k])
		if roll < acc:
			out = k
			break
	return mini(out, int(GUN_CAP[fac]) if level < 8 else 3)

## yen on the body: faction purse x level
static func yen_range(fac: int, level: int) -> Array:
	var m: float = {1: 1.2, 2: 0.8, 3: 1.5, 4: 0.7, 5: 1.4}[fac]
	return [int(round(m * (15.0 * level + 10.0))), int(round(m * (70.0 * level + 40.0)))]

## what a body can leave behind, as [item, percent chance]; the gun and the melee weapon are separate (see Game.kill)
static func drops(fac: int, level: int) -> Array:
	var d: Array = []
	var l: int = clampl(level)
	if l >= 2:
		d.append(["spare ammunition (10-30 rounds, armour-piercing from level 6)", 25 + 5 * l])
	if l >= 4:
		d.append(["trl_medkit", mini(60, 10 + 4 * l)])
	if l <= 3:
		d.append(["trl_good_bandage_roll", 30])
	d.append(["a piece of %s armour (+%d)" % [["", "Street", "Patrol", "Kevlar", "Plasteel", "Nanofab"][armor_tier(l)], armor_tier(l)], 20 + 2 * l])
	d.append(["a gun mod", 5 + 3 * l])
	if fac == FAC_NAP:
		d.append(["NAP badge (not yet an item)", 0])
	return d

static func ammo_id(gunc: int, level: int, roll: int) -> String:
	var cal: String = "556" if gunc == 3 else "9mm"
	return "trl_ammo_%s_%s" % [cal, "ap" if (level >= 6 and roll % 100 < 30) else "fmj"]

## the level a street enemy of this faction is, by index: the NAP on the street average level 5 (4-6), the Bratva 2-5, Nasim 4-7, gangs 1-4, corporate security 3-6
static func street_level(fac: int, seed_value: int, person: int) -> int:
	var tbl: Array = {
		1: [[2, 25], [3, 35], [4, 25], [5, 15]],
		2: [[4, 30], [5, 40], [6, 30]],
		3: [[4, 25], [5, 35], [6, 25], [7, 15]],
		4: [[1, 30], [2, 35], [3, 25], [4, 10]],
		5: [[3, 25], [4, 35], [5, 25], [6, 15]],
	}[fac]
	var roll: int = hash([seed_value, person, "elevel"]) % 100
	var acc := 0
	for e in tbl:
		acc += int(e[1])
		if roll < acc:
			return int(e[0])
	return int(tbl[tbl.size() - 1][0])

## the implants this person actually has: deterministic ids from the catalogue (grade = QL, QL4 uses the Quality grade until military implants exist)
static func rolled_implants(fac: int, level: int, seed_value: int, person: int, catalogue: Array) -> Array:
	var r: Array = implant_range(fac, level)
	if int(r[1]) == 0:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, person, "implants"])
	var n: int = rng.randi_range(int(r[0]), int(r[1]))
	var parts: Array = ["head", "eyes", "spine", "chest", "dermal", "arms", "hands", "legs"]
	for k in range(parts.size() - 1, 0, -1):
		var j: int = rng.randi() % (k + 1)
		var t = parts[k]
		parts[k] = parts[j]
		parts[j] = t
	var out: Array = []
	for k in n:
		var ql: int = rng.randi_range(int(r[2]), int(r[3]))
		var grade: int = mini(ql, 3)
		var pool: Array = catalogue.filter(func(d): return d["part"] == parts[k] and int(d["grade"]) == grade and d.get("live", true))
		if not pool.is_empty():
			out.append(String(pool[rng.randi() % pool.size()]["id"]))
	return out

## one row of the roster, everything a designer reads
static func row(fac: int, level: int) -> Dictionary:
	var l: int = clampl(level)
	var sk: Dictionary = skills(fac, l)
	var combat := {}
	for id in ["unarmed", "melee", "ranged", "dodge", "grit"]:
		combat[id] = int(sk.get(id, 0))
	var odds: Array = GUN_ODDS[l - 1]
	var gun_txt := "none"
	if l == 2:
		gun_txt = "mixed: half carry a pistol, half are unarmed"
	elif l >= 3:
		var bits: Array = []
		for k in range(1, 4):
			var o: int = int(odds[k])
			if k > int(GUN_CAP[fac]) and l < 8:
				continue
			if o > 0:
				bits.append("%s %d%%" % [GUN_CLASS[k], o])
		gun_txt = ", ".join(bits)
	var ir: Array = implant_range(fac, l)
	var yr: Array = yen_range(fac, l)
	return {"faction": FAC_LABEL[fac], "fac": fac, "level": l, "title": title(fac, l), "hp_total": total_hp(l), "pc_health": int(round(pc_health(l))), "hpmax": hpmax(l),
		"head": limb_hp(l, "head"), "chest": limb_hp(l, "chest"), "arm": limb_hp(l, "l_arm"), "leg": limb_hp(l, "l_leg"), "armor": armor(fac, l), "skills": sk, "combat": combat,
		"top_skill": l, "guns": gun_txt, "implants_min": ir[0], "implants_max": ir[1], "ql_lo": ir[2], "ql_hi": ir[3], "yen_lo": yr[0], "yen_hi": yr[1], "drops": drops(fac, l),
		"vest": vest_id(fac, l)}
