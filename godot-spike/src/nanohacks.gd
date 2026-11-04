extends RefCounted
## Nanohacks: small programs run by a Trilobit.  A chip takes `slots` of the Trilobit's slots (one if not stated) and costs 400 yen x `mult` (one if not stated).
## kinds: "passive" works while it is installed and the Trilobit is powered, at no cost; "active" is switched on from the N menu and runs `turns` turns,
## drawing extra kJ/h while it does; "instant" is a single act.  1 turn = 6 seconds, 10 turns = 1 minute.
## Cost of a use: `cost` kJ; or `cost_part` x the six body parts (plating); or `cost_imp` x the implanted body parts (mend, heal).  Upkeep while running: `draw` kJ/h, or `draw_part` x six.
## `cooldown` is in minutes and falls 10% for every level of Networking (to nothing).  `offensive` hacks run only through the network, on a Networked target.
## The tool tools/export_items.py reads this table for the chips (id, name, text, cols, mult): keep one entry per line pair as below.

const USE_KJ := 10.0                     # battery cost of one activation when a hack does not say
const ACTIVE_TURNS := 100                # 10 minutes (600 turns = 1 hour)
const ACTIVE_DRAW := 5.0                 # extra kJ/h while an active hack runs, when a hack does not say
const SHOCK_DAMAGE := 10
const BASE_PRICE := 400

## id, name, kind, effect, text, [tube colours] for the chip art
const ALL := [
	{"id": "minor_plating", "name": "Minor Plating", "kind": "active", "armor": 1, "armor_imp": 1, "cost_part": 5.0, "draw_part": 1.0, "turns": 100, "slots": 1, "mult": 1,
		"text": "+1 armor on every body part, and +1 more on implanted parts, for 10 minutes.  5 kJ per body part, then 1 kJ/h per body part.", "cols": ["#5a9aff", "#a8caff", "#2a5ad0"]},
	{"id": "plating", "name": "Plating", "kind": "active", "armor": 1, "armor_imp": 3, "cost_part": 10.0, "draw_part": 2.0, "turns": 100, "slots": 2, "mult": 3,
		"text": "+1 armor on every body part, and +3 more on implanted parts, for 10 minutes.  10 kJ per body part, then 2 kJ/h per body part.", "cols": ["#4fd0ff", "#9fe8ff", "#2a7fd0"]},
	{"id": "major_plating", "name": "Major Plating", "kind": "active", "armor": 2, "armor_imp": 5, "cost_part": 15.0, "draw_part": 3.0, "turns": 150, "slots": 4, "mult": 12,
		"text": "+2 armor on every body part, and +5 more on implanted parts, for 15 minutes.  15 kJ per body part, then 3 kJ/h per body part.", "cols": ["#2ae8e8", "#b0fff4", "#1a9a9a"]},
	{"id": "reflex", "name": "Reflex", "kind": "active", "skills": {"dodge": 1}, "turns": ACTIVE_TURNS, "draw": ACTIVE_DRAW,
		"text": "Overclocks the nerves: +1 Dodge for 10 minutes.", "cols": ["#ffe14a", "#ffb02a", "#fff3a0"]},
	{"id": "strike", "name": "Strike", "kind": "active", "skills": {"unarmed": 1, "melee": 1}, "turns": ACTIVE_TURNS, "draw": ACTIVE_DRAW,
		"text": "Primes the muscles: +1 Unarmed and +1 Melee for 10 minutes.", "cols": ["#ff5a4a", "#ff9a3a", "#d02a2a"]},
	{"id": "mend", "name": "Mend", "kind": "instant", "heal_imp": 10, "heal_other": 2, "cost_imp": 5.0, "cooldown": 1, "slots": 1, "mult": 1,
		"text": "Closes 10 points of bio damage on each implanted body part and 2 on each other part.  5 kJ per implanted part.  Cooldown 1 minute.", "cols": ["#6dff6d", "#2ad04a", "#c8ffc8"]},
	{"id": "heal", "name": "Heal", "kind": "instant", "heal_imp": 15, "heal_other": 10, "cost_imp": 7.0, "cooldown": 1, "slots": 2, "mult": 3,
		"text": "Closes 15 points of bio damage on each implanted body part and 10 on each other part.  7 kJ per implanted part.  Cooldown 1 minute.", "cols": ["#3aff9a", "#a8ffd0", "#10b060"]},
	{"id": "shock", "name": "Shock", "kind": "instant", "damage": SHOCK_DAMAGE, "offensive": true,
		"text": "Offensive; runs through the network (B, then Network to a target): 10 damage x (1 + your Implementation/10 - their Analysis/10) to a random implanted body part.  Unwired people take nothing.", "cols": ["#ff3ec8", "#c23cff", "#ffd0f4"]},
	{"id": "impair", "name": "Impair", "kind": "instant", "offensive": true, "cost": 20.0, "turns": 50, "cooldown": 5, "slots": 2, "mult": 3,
		"text": "Offensive; through the network.  Disables one random arm or leg implant of the target for 5 minutes: they lose the use of those limbs, but their health is untouched.  20 kJ.  Cooldown 5 minutes.", "cols": ["#ff8a2a", "#ffc07a", "#c04a0a"]},
	{"id": "acid", "name": "Acid Feedback", "kind": "instant", "offensive": true, "cost": 20.0, "turns": 5, "dmg_imp": 2, "dmg_other": 1, "cooldown": 1, "slots": 2, "mult": 3,
		"text": "Offensive; through the network.  Every turn (6 seconds) for 5 turns: 2 damage to an implanted body part of the target and 1 to another random body part.  20 kJ.  Cooldown 1 minute.", "cols": ["#b8ff2a", "#e4ff8a", "#6aa000"]},
	{"id": "underclock", "name": "Underclock", "kind": "instant", "offensive": true, "cost": 10.0, "turns": 50, "cooldown": 1, "slots": 1, "mult": 1,
		"text": "Offensive; through the network.  The target acts 10% slower (110 action points per action instead of 100) for 5 minutes.  10 kJ.  Cooldown 1 minute.", "cols": ["#4a8aff", "#a0c0ff", "#2a3aa0"]},
	{"id": "chaotic", "name": "Chaotic Resonance", "kind": "instant", "offensive": true, "cost": 40.0, "turns": 5, "cooldown": 1, "slots": 4, "mult": 12,
		"text": "Offensive; through the network.  After 30 seconds a random implant of the target is completely destroyed.  40 kJ.  Cooldown 1 minute.", "cols": ["#ffffff", "#e0b0ff", "#ff3ec8"]},
	{"id": "unarmed", "name": "Skill: Unarmed", "kind": "passive", "skills": {"unarmed": 1}, "group": "Combat",
		"text": "A standing routine: +1 Unarmed while installed.  No upkeep.", "cols": ["#ff5a4a", "#ff9a3a", "#d02a2a"]},
	{"id": "melee", "name": "Skill: Melee", "kind": "passive", "skills": {"melee": 1}, "group": "Combat",
		"text": "A standing routine: +1 Melee while installed.  No upkeep.", "cols": ["#ff5a4a", "#ff9a3a", "#d02a2a"]},
	{"id": "ranged", "name": "Skill: Ranged", "kind": "passive", "skills": {"ranged": 1}, "group": "Combat",
		"text": "A standing routine: +1 Ranged while installed.  No upkeep.", "cols": ["#ff5a4a", "#ff9a3a", "#d02a2a"]},
	{"id": "dodge", "name": "Skill: Dodge", "kind": "passive", "skills": {"dodge": 1}, "group": "Combat",
		"text": "A standing routine: +1 Dodge while installed.  No upkeep.", "cols": ["#ff5a4a", "#ff9a3a", "#d02a2a"]},
	{"id": "grit", "name": "Skill: Grit", "kind": "passive", "skills": {"grit": 1}, "group": "Combat",
		"text": "A standing routine: +1 Grit while installed.  No upkeep.", "cols": ["#ff5a4a", "#ff9a3a", "#d02a2a"]},
	{"id": "networking", "name": "Skill: Networking", "kind": "passive", "skills": {"networking": 1}, "group": "Hacking",
		"text": "A standing routine: +1 Networking while installed.  No upkeep.", "cols": ["#c23cff", "#e0a0ff", "#7a2ad0"]},
	{"id": "analysis", "name": "Skill: Analysis", "kind": "passive", "skills": {"analysis": 1}, "group": "Hacking",
		"text": "A standing routine: +1 Analysis while installed.  No upkeep.", "cols": ["#c23cff", "#e0a0ff", "#7a2ad0"]},
	{"id": "implementation", "name": "Skill: Implementation", "kind": "passive", "skills": {"implementation": 1}, "group": "Hacking",
		"text": "A standing routine: +1 Implementation while installed.  No upkeep.", "cols": ["#c23cff", "#e0a0ff", "#7a2ad0"]},
	{"id": "manual", "name": "Skill: Manual", "kind": "passive", "skills": {"manual": 1}, "group": "Labour",
		"text": "A standing routine: +1 Manual while installed.  No upkeep.", "cols": ["#ffc24a", "#ffe08a", "#d08a1a"]},
	{"id": "engineering", "name": "Skill: Engineering", "kind": "passive", "skills": {"engineering": 1}, "group": "Labour",
		"text": "A standing routine: +1 Engineering while installed.  No upkeep.", "cols": ["#ffc24a", "#ffe08a", "#d08a1a"]},
	{"id": "artisan", "name": "Skill: Artisan", "kind": "passive", "skills": {"artisan": 1}, "group": "Labour",
		"text": "A standing routine: +1 Artisan while installed.  No upkeep.", "cols": ["#ffc24a", "#ffe08a", "#d08a1a"]},
	{"id": "research", "name": "Skill: Research", "kind": "passive", "skills": {"research": 1}, "group": "Labour",
		"text": "A standing routine: +1 Research while installed.  No upkeep.", "cols": ["#ffc24a", "#ffe08a", "#d08a1a"]},
	{"id": "streetwise", "name": "Skill: Streetwise", "kind": "passive", "skills": {"streetwise": 1}, "group": "Social",
		"text": "A standing routine: +1 Streetwise while installed.  No upkeep.", "cols": ["#ff6ac0", "#ffb0e0", "#d02a8a"]},
	{"id": "etiquette", "name": "Skill: Etiquette", "kind": "passive", "skills": {"etiquette": 1}, "group": "Social",
		"text": "A standing routine: +1 Etiquette while installed.  No upkeep.", "cols": ["#ff6ac0", "#ffb0e0", "#d02a8a"]},
	{"id": "diplomacy", "name": "Skill: Diplomacy", "kind": "passive", "skills": {"diplomacy": 1}, "group": "Social",
		"text": "A standing routine: +1 Diplomacy while installed.  No upkeep.", "cols": ["#ff6ac0", "#ffb0e0", "#d02a8a"]},
	{"id": "negotiation", "name": "Skill: Negotiation", "kind": "passive", "skills": {"negotiation": 1}, "group": "Social",
		"text": "A standing routine: +1 Negotiation while installed.  No upkeep.", "cols": ["#ff6ac0", "#ffb0e0", "#d02a8a"]},
]

static var _by_id: Dictionary = {}

static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for d in ALL:
			_by_id[d["id"]] = d
	return _by_id.get(id, {})

static func chip_item(id: String) -> String:
	return "trl_nano_" + id

## the hack a chip item holds ("" for any other item)
static func of_item(item_id: String) -> String:
	return item_id.substr(9) if item_id.begins_with("trl_nano_") else ""

static func is_active(d: Dictionary) -> bool:
	return String(d["kind"]) == "active"

## Trilobit slots a chip fills
static func width(d: Dictionary) -> int:
	return int(d.get("slots", 1))

static func is_offensive(d: Dictionary) -> bool:
	return bool(d.get("offensive", false))

## the table every chip shows, like a gun's: [variable, value] rows.  g (the game) is optional: with it the costs and the cooldown are the player's own.
static func rows(d: Dictionary, g = null) -> Array:
	var out: Array = []
	var kind: String = String(d.get("kind", "passive"))
	out.append(["Type", {"passive": "Passive (always on)", "active": "Active (timed)", "instant": "Instant (one use)"}[kind]])
	out.append(["Target", "Networked target" if is_offensive(d) else "Self"])
	out.append(["Slots", str(width(d))])
	for sk in d.get("skills", {}):
		out.append([String(sk).capitalize(), "+%d" % int(d["skills"][sk])])
	if d.has("armor"):
		out.append(["Armor, every body part", "+%d" % int(d["armor"])])
		out.append(["Armor, implanted parts", "+%d more" % int(d["armor_imp"])])
	if d.has("heal_imp"):
		out.append(["Healing, implanted part", "%d" % int(d["heal_imp"])])
		out.append(["Healing, other parts", "%d" % int(d["heal_other"])])
	if d.has("damage"):
		out.append(["Damage", str(int(d["damage"])) + " x (1 + Impl/10 - their Ana/10)"])
		out.append(["Hits", "1 random implanted part"])
	if d.has("dmg_imp"):
		out.append(["Damage, implanted part", "%d per turn" % int(d["dmg_imp"])])
		out.append(["Damage, other part", "%d per turn" % int(d["dmg_other"])])
		out.append(["Damage turns", str(int(d["turns"]))])
	if String(d.get("id", "")) == "impair":
		out.append(["Disables", "1 random arm or leg implant"])
		out.append(["Health lost", "0"])
	if String(d.get("id", "")) == "underclock":
		out.append(["Action points per action", "110  (normal 100)"])
	if String(d.get("id", "")) == "chaotic":
		out.append(["Destroys", "1 random implant"])
		out.append(["Delay", "30 s"])
	if kind != "passive":
		var per: String = ""
		var kj: float = float(d.get("cost", USE_KJ))
		if d.has("cost_part"):
			kj = float(d["cost_part"]) * 6.0
			per = "  (" + String.num(float(d["cost_part"])) + " per body part)"
		elif d.has("cost_imp"):
			kj = float(d["cost_imp"]) * (float(g.implanted_limb_count()) if g != null else 1.0)
			per = "  (" + String.num(float(d["cost_imp"])) + " per implanted part)"
		out.append(["Energy per use", String.num(kj) + " kJ" + per])
	if d.has("draw") or d.has("draw_part"):
		var up: float = float(d["draw_part"]) * 6.0 if d.has("draw_part") else float(d["draw"])
		out.append(["Upkeep while running", String.num(up) + " kJ/h"])
	if kind == "active" and d.has("turns"):
		out.append(["Duration", span(int(d["turns"]))])
	elif d.has("turns") and kind == "instant" and not d.has("dmg_imp") and String(d.get("id", "")) in ["impair", "underclock"]:
		out.append(["Duration", span(int(d["turns"]))])
	if d.has("cooldown"):
		out.append(["Cooldown", span(int(round(float(d["cooldown"]) * 10.0)))])
		if g != null and int(g.lvl("networking")) > 0:
			out.append(["Cooldown (your Networking)", span(g.nano_cd_turns(d))])
	out.append(["Price", "¥%d" % (BASE_PRICE * int(d.get("mult", 1)))])
	return out

static func span(turns: int) -> String:
	if turns <= 0:
		return "none"
	if turns >= 600:
		return String.num(float(turns) / 600.0) + " h"
	if turns >= 10:
		return String.num(float(turns) / 10.0) + " min"
	return "%d s" % (turns * 6)
