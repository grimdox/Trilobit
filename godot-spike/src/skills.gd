extends RefCounted
## Attributes and skills: data tables and the pure rules (no game state in here).
##
## Five attributes, all starting at 10.  Every two points above 10 add 1 to each skill the attribute governs.
## Sixteen skills in four groups, all starting at 0.  A skill's shown number is its EFFECTIVE level:
##     base level (raised by skill-specific XP)  +  the bonus from each governing attribute.
## Disciplines are extras that unlock at an effective level and improve specific actions.
## The same rules serve the player (game.gd keeps `attrs`, `skills`, `xp`) and every NPC (derived from faction and person index).

const ATTR_START := 10
const BASE_MAX := 20                         # the cap on the XP-raised part of a skill

const ATTRS := [
	{"id": "str", "short": "S", "name": "Strength", "desc": "Raw physical power: hitting hard, hauling, shrugging off punishment."},
	{"id": "per", "short": "P", "name": "Perception", "desc": "Noticing things: aim, reading rooms and people, spotting weak points."},
	{"id": "agi", "short": "A", "name": "Agility", "desc": "Speed, balance and fine motor control."},
	{"id": "cog", "short": "C", "name": "Cognition", "desc": "Reasoning, memory and cunning."},
	{"id": "end", "short": "E", "name": "Endurance", "desc": "Stamina and stubbornness: lasting through pain, work and long negotiations."},
]

const GROUPS := ["Combat", "Hacking", "Labour", "Social"]

## live = the skill already changes something in play.  note = what it does today (or why it does not yet).
const SKILLS := [
	{"id": "unarmed", "name": "Unarmed", "group": "Combat", "attrs": ["str", "agi"], "live": true,
		"desc": "Weaponless melee combat.  The art of brawling and skilled martial arts.  Governs chance to hit, and how hard unarmed hits are.  At high levels, allows for martial arts disciplines.",
		"note": "Fists, kicks and implant blades: each level adds 1 to your 2d10 hit roll and 1 damage (an 11 or more hits).",
		"disc": [
			{"id": "iron_fist", "name": "Iron Fist", "req": 5, "desc": "Unarmed hits deal +2 damage."},
			{"id": "pressure_points", "name": "Pressure Points", "req": 8, "desc": "Unarmed hits stun for 3 turns about one time in five."}]},
	{"id": "melee", "name": "Melee", "group": "Combat", "attrs": ["str", "agi"], "live": true,
		"desc": "Combat with close-ranged weapons.  Governs chance to hit, and how hard melee hits are.  At high levels, allows for melee weapon disciplines.",
		"note": "Blades and other melee weapons: each level adds 1 to your 2d10 hit roll and 1 damage.  Every swing costs 100 action points and 1 stamina per kg of weapon.",
		"disc": [
			{"id": "parry", "name": "Parry", "req": 3, "desc": "Turn blows aside with your weapon (+12% parry, +2% per level)."},
			{"id": "riposte", "name": "Riposte", "req": 6, "desc": "A parried blow can become an instant counter-strike."}]},
	{"id": "ranged", "name": "Ranged", "group": "Combat", "attrs": ["per", "cog"], "live": true,
		"desc": "Accuracy and precision with guns.  Governs chance to hit with ranged weapons.  At high levels, allows for ranged weapon disciplines.",
		"note": "Each level adds 1 to your 2d10 shot roll and 1 damage, and settles your aim a little faster.",
		"disc": [
			{"id": "steady_aim", "name": "Steady Aim", "req": 5, "desc": "Each aim action steadies the shot a quarter level more."},
			{"id": "marksman", "name": "Marksman", "req": 8, "desc": "+6% to hit at five or more tiles."}]},
	{"id": "dodge", "name": "Dodge", "group": "Combat", "attrs": ["per", "agi"], "live": true,
		"desc": "Chance to completely avoid both melee and ranged damage.  Ranged dodging is not possible without very high skill levels.",
		"note": "Each level takes 1 off an attacker's 2d10 melee roll.  Bullets can only be dodged from level 7: 4% per level above 6.",
		"disc": []},
	{"id": "grit", "name": "Grit", "group": "Combat", "attrs": ["str", "end"], "live": true,
		"desc": "Ability to endure hits.  Grit decreases damage received and decreases critical hit chance.",
		"note": "Blows and bullets lose 1 damage per level (after armor).  An attack is a crit on a natural 19 or 20, or a total of 20 plus your Grit.  Blasts: 1 less damage per 4 levels.",
		"disc": []},
	{"id": "networking", "name": "Networking", "group": "Hacking", "attrs": ["cog"], "live": false,
		"desc": "The ability to connect to electronic networks, including computer systems and other people's implants.  Higher levels allow for quicker and easier connection.",
		"note": "Waits for the nanohack system.", "disc": []},
	{"id": "analysis", "name": "Analysis", "group": "Hacking", "attrs": ["per"], "live": false,
		"desc": "The ability to detect defensive firewalls, and overcome them.  High levels increase the chance of hacks succeeding.",
		"note": "Waits for the nanohack system.", "disc": []},
	{"id": "implementation", "name": "Implementation", "group": "Hacking", "attrs": ["cog"], "live": false,
		"desc": "The strength of hacks and defensive firewalls.  Higher levels increase hack power.",
		"note": "Waits for the nanohack system.", "disc": []},
	{"id": "manual", "name": "Manual", "group": "Labour", "attrs": ["str", "end"], "live": true,
		"desc": "Governs skill and speed of manual tasks, from warehouse work to stocking shelves.  At high levels, allows for manual labor disciplines.",
		"note": "Heavy furniture takes one turn to shove from level 3.", "disc": []},
	{"id": "engineering", "name": "Engineering", "group": "Labour", "attrs": ["per", "cog"], "live": true,
		"desc": "Performance of applied technical work, including repairs, electrical and mechanical tasks.  At high levels, allows for engineering disciplines.",
		"note": "Lock picking (+9% per level); guns you keep jam less (4% fewer jams per level, down to half).", "disc": []},
	{"id": "artisan", "name": "Artisan", "group": "Labour", "attrs": ["per", "agi"], "live": false,
		"desc": "Governs the outputs of artistic and bespoke creations, including cooking, visual arts and writing.  At high levels, allows for artisan disciplines.",
		"note": "Waits for crafting and cooking.", "disc": []},
	{"id": "research", "name": "Research", "group": "Labour", "attrs": ["cog", "end"], "live": true,
		"desc": "The ability to understand and investigate, including technical and social media data.  At high levels, allows for research disciplines.",
		"note": "Anyone you chat with tells you one more rumour for every 3 levels.", "disc": []},
	{"id": "streetwise", "name": "Streetwise", "group": "Social", "attrs": ["per"], "live": true,
		"desc": "The lingo of the lower class.  Used to communicate effectively with gang members and the impoverished.",
		"note": "Better prices from street stalls and low-district shops (2% a level).", "disc": []},
	{"id": "etiquette", "name": "Etiquette", "group": "Social", "attrs": ["per"], "live": true,
		"desc": "The understanding of eloquence and circumstance, used to communicate effectively with the upper class.",
		"note": "Better prices from upscale shops and tower stalls (2% a level).", "disc": []},
	{"id": "deception", "name": "Deception", "group": "Social", "attrs": ["cog"], "live": true,
		"desc": "The ability to lie to humans, both verbally and visually.",
		"note": "Pickpocketing: +7% a level.", "disc": []},
	{"id": "negotiation", "name": "Negotiation", "group": "Social", "attrs": ["end"], "live": true,
		"desc": "Haggling, bartering and debating.  Higher skills can improve many social and financial rewards.",
		"note": "1.5% off every purchase per level, and 2% more yen from jobs.", "disc": []},
]

static var _skill_index: Dictionary = {}
static var _attr_index: Dictionary = {}

static func skill(id: String) -> Dictionary:
	if _skill_index.is_empty():
		for s in SKILLS:
			_skill_index[s["id"]] = s
	return _skill_index.get(id, {})

static func attr(id: String) -> Dictionary:
	if _attr_index.is_empty():
		for a in ATTRS:
			_attr_index[a["id"]] = a
	return _attr_index.get(id, {})

static func skill_ids() -> Array:
	var out: Array = []
	for s in SKILLS:
		out.append(s["id"])
	return out

static func skills_in(group: String) -> Array:
	return SKILLS.filter(func(s): return s["group"] == group)

static func skills_of_attr(attr_id: String) -> Array:
	return SKILLS.filter(func(s): return attr_id in s["attrs"])

static func default_attrs() -> Dictionary:
	var d := {}
	for a in ATTRS:
		d[a["id"]] = ATTR_START
	return d

static func default_skills() -> Dictionary:
	var d := {}
	for s in SKILLS:
		d[s["id"]] = 0
	return d

## +1 for every two points above 10; below 10 there is no penalty
static func attr_bonus(value: int) -> int:
	return maxi(0, (value - ATTR_START) / 2)

## the part of a skill that comes from its governing attributes
static func bonus(attrs: Dictionary, id: String) -> int:
	var b := 0
	for a in skill(id).get("attrs", []):
		b += attr_bonus(int(attrs.get(a, ATTR_START)))
	return b

## the number shown next to a skill and used by every check
static func level(attrs: Dictionary, base: Dictionary, id: String) -> int:
	return int(base.get(id, 0)) + bonus(attrs, id)

## XP to go from base level n to n + 1 (the same curve the game has always used)
static func xp_needed(base_level: int) -> int:
	return 6 + base_level * 4

## discipline ids unlocked at an effective level
static func disciplines_at(id: String, lvl: int) -> Array:
	var out: Array = []
	for d in skill(id).get("disc", []):
		if lvl >= int(d["req"]):
			out.append(d["id"])
	return out

# ---------------------------------------------------------------- rule formulas shared by player and NPCs
static func melee_dodge(dodge_lvl: int) -> int:
	return 4 + 2 * dodge_lvl

## bullets are only dodgeable at very high levels
static func bullet_dodge(dodge_lvl: int) -> int:
	return clampi((dodge_lvl - 6) * 4, 0, 40)

# ---- melee: the 2d10 hit roll.  final = 2d10 + attacker's skill - defender's dodge.  11 or more hits.  A natural 19 or 20, or a final of 20 + the
## defender's Grit or more, is a critical hit; a natural 2 is a critical miss (and the other side strikes back for free).
const HIT_AT := 11
const CRIT_NAT := 19
const CRIT_MISS_NAT := 2

## "cmiss", "crit", "hit" or "miss" for a natural roll (2..20), the final total and the defender's Grit level
static func melee_outcome(nat: int, total: int, defender_grit: int) -> String:
	if nat <= CRIT_MISS_NAT:
		return "cmiss"
	if nat >= CRIT_NAT or total >= 20 + defender_grit:
		return "crit"
	return "hit" if total >= HIT_AT else "miss"

## chance in percent that 2d10 + bonus reaches 11 (bonus = attacker skill - defender dodge), for the tests and the HUD text
static func hit_percent(bonus: int) -> int:
	var n := 0
	for a in range(1, 11):
		for b in range(1, 11):
			if a + b > CRIT_MISS_NAT and (a + b >= CRIT_NAT or a + b + bonus >= HIT_AT):
				n += 1
	return n

## damage of a melee blow before armor and Grit: the weapon roll (the maximum on a critical) plus the weapon skill, doubled on a critical
static func melee_base(weapon_roll: int, weapon_max: int, skill: int, crit: bool) -> int:
	return ((weapon_max if crit else weapon_roll) + skill) * (2 if crit else 1)

static func grit_cut(grit_lvl: int) -> int:
	return grit_lvl / 4

static func crit_chance(grit_lvl: int) -> int:
	return clampi(6 - grit_lvl, 1, 6)

# ---------------------------------------------------------------- people other than the player
## faction ids as in game.gd: 0 CIV, 1 BRATVA, 2 NAP, 3 NASIM, 4 GANG
const NPC_ATTRS := [
	[10, 10, 10, 10, 10],     # civilians
	[12, 10, 12, 9, 12],      # Bratva: big, tough, not bookish
	[11, 12, 11, 11, 12],     # NAP: trained, watchful
	[10, 12, 13, 13, 10],     # Nasim: quick, sharp
	[11, 10, 12, 9, 11],      # unaffiliated criminals
]
const NPC_SKILLS := [
	{},
	{"unarmed": 3, "melee": 3, "ranged": 2, "dodge": 1, "grit": 3, "streetwise": 4, "negotiation": 2, "deception": 1},
	{"unarmed": 2, "melee": 3, "ranged": 4, "dodge": 2, "grit": 3, "etiquette": 3, "analysis": 2, "networking": 2, "research": 1},
	{"unarmed": 3, "melee": 3, "ranged": 3, "dodge": 7, "grit": 2, "deception": 2, "streetwise": 2},
	{"unarmed": 3, "melee": 2, "ranged": 1, "dodge": 0, "grit": 2, "streetwise": 3},
]

static func _mix(seed_value: int, person: int, salt: int) -> int:
	return hash([seed_value, person, salt]) & 0x7fffffff

## a person's five attributes: the faction's template, nudged by -1..+1 (civilians -2..+2).  Deterministic per seed and index.
static func npc_attrs(fac: int, seed_value: int, person: int) -> Dictionary:
	var tpl: Array = NPC_ATTRS[clampi(fac, 0, NPC_ATTRS.size() - 1)]
	var spread: int = 5 if fac == 0 else 3
	var d := {}
	for k in ATTRS.size():
		var j: int = _mix(seed_value, person, k + 1) % spread - spread / 2
		d[ATTRS[k]["id"]] = int(tpl[k]) + j
	return d

## a person's base skills: the faction template, plus a point for about one in four of the ones they have
static func npc_base(fac: int, seed_value: int, person: int) -> Dictionary:
	var tpl: Dictionary = NPC_SKILLS[clampi(fac, 0, NPC_SKILLS.size() - 1)]
	var d := default_skills()
	for k in tpl:
		var v: int = int(tpl[k])
		if _mix(seed_value, person, 100 + skill_ids().find(k)) % 4 == 0:
			v += 1
		d[k] = v
	return d

static func npc_level(fac: int, seed_value: int, person: int, id: String) -> int:
	return level(npc_attrs(fac, seed_value, person), npc_base(fac, seed_value, person), id)
