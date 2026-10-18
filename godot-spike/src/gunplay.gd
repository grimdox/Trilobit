extends RefCounted
## Gun rules, kept free of game state so they can be tested on their own.
## A gun's numbers = the class/model block in its item definition, changed by the installed mods and by the kind of ammunition loaded.
## One shot is 2d10 + ranged skill + aim points + small modifiers - |distance - the shot's roll of the gun's natural range|, times the cover
## factor; 11 or more hits, a natural 19-20 (or 20 + the target's Grit) is a critical, a natural 2 or less a critical miss.  Aim points are banked by
## aiming (up to the gun's max aim) and one is lost per bullet fired (less with mods), down to max aim - 5.
const SK = preload("res://src/skills.gd")
const AIM_FLOOR_DROP := 5
## what a gunman in the street carries, by the sim's gun code (1 pistol, 2 SMG, 3 rifle): the same fields as a gun's data (damage as before)
const NPC_GUN := {
	1: {"name": "pistol", "dmg": [5, 9], "range": [3, 7], "max_aim": 2, "want": 1, "noise": 14},
	2: {"name": "SMG", "dmg": [6, 11], "range": [4, 9], "max_aim": 2, "want": 1, "noise": 16},
	3: {"name": "rifle", "dmg": [6, 11], "range": [10, 15], "max_aim": 3, "want": 2, "noise": 20},
}
const AP_FIRE := 50          # action points to pull the trigger (a volley is one action); aiming costs a full 100
const STAM_FIRE := 2
const STAM_AIM := 1

## ammunition kinds: damage multiplier, armour penetration (reserved for armoured targets), pellet override, blast radius
const KIND := {
	"fmj": {"dmg": 1.0, "pen": 1, "label": "ball"},
	"ap": {"dmg": 0.9, "pen": 3, "label": "armor-piercing"},
	"hp": {"dmg": 1.25, "pen": 0, "label": "hollow-point"},
	"shot": {"dmg": 1.0, "pen": 0, "label": "buckshot"},
	"slug": {"dmg": 1.0, "pen": 2, "label": "slug", "pellets": 1},
	"he": {"dmg": 1.0, "pen": 0, "label": "HE", "blast": 2},
	"cell": {"dmg": 1.0, "pen": 2, "label": "charge"},
}
const KINDS_BY_CAL := {"9mm": ["fmj", "ap", "hp"], ".357": ["fmj", "ap", "hp"], "5.56": ["fmj", "ap", "hp"], "12ga": ["shot", "slug"], ".338": ["fmj", "ap"],
	"7.62": ["fmj", "ap"], "12.7": ["fmj", "ap"], "40mm": ["he"], "cell": ["cell"]}
## hands needed, and how quick the class is to settle (aim speed modifier)
const HANDS := {"pistol": 1, "revolver": 1, "laser": 1}
const AIM_CLASS := {"pistol": 0.1, "revolver": 0.05, "smg": 0.0, "rifle": -0.05, "shotgun": -0.1, "sniper": -0.2, "mg": -0.25, "heavy_mg": -0.35, "launcher": -0.2, "laser": 0.0}

static func default_kind(cal: String) -> String:
	return KINDS_BY_CAL[cal][0]

## the mod effects summed up
static func fx(gun) -> Dictionary:
	var t := {"acc": 0, "aim": 0, "hip": 0, "range_pct": 0, "rangepen_pct": 0, "close_pen": 0, "recoil_pct": 0, "dmg_pct": 0, "mag_pct": 0, "jam": 0.0, "reload": 0,
		"spread_pct": 0, "noise_cap": 999, "max_aim": 0, "aim_speed": 0.0}
	for m in gun.mods:
		var e: Dictionary = m.def["mod"]["fx"]
		for k in e:
			if k == "noise_cap":
				t[k] = mini(int(t[k]), int(e[k]))
			else:
				t[k] += e[k]
	return t

## all derived numbers for a gun item; {} if it is not a gun
static func stats(gun) -> Dictionary:
	if gun == null or not gun.def.has("gun"):
		return {}
	var b: Dictionary = gun.def["gun"]
	var f: Dictionary = fx(gun)
	var kind: String = gun.kind if gun.loaded > 0 and gun.kind != "" else default_kind(b["cal"])
	var km: Dictionary = KIND[kind]
	var dm: float = float(km["dmg"]) * (1.0 + float(f["dmg_pct"]) / 100.0)
	var s := {}
	s["name"] = gun.def["name"]
	s["cal"] = b["cal"]
	s["kind"] = kind
	s["label"] = km["label"]
	s["dmg"] = [maxi(1, int(round(float(b["dmg"][0]) * dm))), maxi(1, int(round(float(b["dmg"][1]) * dm)))]
	var rm: float = 1.0 + float(f["range_pct"]) / 100.0
	s["range_lo"] = maxi(1, int(round(float(b["range"][0]) * rm)))
	s["range_hi"] = maxi(int(s["range_lo"]), int(round(float(b["range"][1]) * rm)))
	s["range"] = s["range_hi"]
	s["max_aim"] = int(b["max_aim"]) + int(f["max_aim"])
	s["aim_loss"] = maxf(0.1, float(b["aim_loss"]) * (1.0 + float(f["recoil_pct"]) / 100.0))
	s["acc"] = int(b["acc"])
	s["acc_mod"] = int(f["acc"])
	s["mag"] = maxi(1, int(round(float(b["mag"]) * (1.0 + float(f["mag_pct"]) / 100.0))))
	s["noise"] = mini(int(b["noise"]), int(f["noise_cap"]))
	s["reload"] = maxi(1, int(b["reload"]) + int(f["reload"]))
	s["pellets"] = int(km.get("pellets", b["pellets"]))
	s["spread"] = maxf(0.2, 1.0 + float(f["spread_pct"]) / 100.0)
	s["blast"] = int(km.get("blast", 0))
	s["pen"] = int(km.get("pen", 0))
	s["hip"] = int(f["hip"])
	var cls := ""
	for tg in gun.def.get("tags", []):
		if tg != "gun":
			cls = String(tg)
	s["cls"] = cls
	var optic := false
	var scoped := false
	var rate: float = float(AIM_CLASS.get(cls, 0.0)) + float(f["aim_speed"])
	for m in gun.mods:
		if m.def["mod"]["slot"] == "optic":
			optic = true
			if int(m.def["mod"]["fx"].get("range_pct", 0)) > 0:
				scoped = true
	s["optic"] = optic
	s["scoped"] = scoped
	s["hands"] = int(HANDS.get(cls, 2))
	s["aim_rate"] = rate
	s["rangepen"] = 1.0 - clampf(float(f["rangepen_pct"]) / 100.0, 0.0, 0.9)      # points lost per tile off the natural range
	s["close_pen"] = int(f["close_pen"])
	s["jam"] = maxf(0.0, float(b["jam"]) + float(f["jam"]))
	s["modes"] = b["modes"]
	s["slots"] = b["slots"]
	s["suppressed"] = s["noise"] <= 6 and b["noise"] > 6
	return s

## the gun's own accuracy as a flat -2..+2 on the roll: 65 is neutral, every 5 away is one point, never more than two; mods add their own accuracy on top (5 percentage points = 1)
static func acc_points(s: Dictionary) -> int:
	return clampi(int(round(float(int(s["acc"]) - 65) / 5.0)), -2, 2) + int(round(float(int(s.get("acc_mod", 0))) / 5.0))

## the 2d10 modifiers that do not depend on the dice or the range roll: skill, the gun's own accuracy (acc_points), aim points
## (or the hip-fire bonus when there are none), and stance.  `extra` carries implants, blessings and injuries from the game.
static func bonus_points(s: Dictionary, aim: int, moved: bool, crouch: bool, skill: int, penalty: int, prone: bool = false, extra: int = 0) -> int:
	var b: float = float(skill) + float(acc_points(s)) + float(extra)
	b += float(aim) if aim > 0 else float(aim) + float(s["hip"]) / 5.0
	if moved:
		b -= 2.0
	if crouch:
		b += 1.0
	if prone:
		b += 1.0
	b -= float(penalty) / 5.0
	return int(round(b))

## the aim points a bullet in a volley is fired with: the banked aim less the loss per earlier bullet, never below max aim - 5
static func aim_at_shot(s: Dictionary, aim: int, shot_index: int) -> int:
	return maxi(int(s["max_aim"]) - AIM_FLOOR_DROP, aim - int(floor(float(s["aim_loss"]) * float(shot_index) + 0.0001)))

## points lost for being off the natural range: |d - r| scaled by the gun's range-penalty factor (a choked shotgun spreads less), plus the
## close-range penalty of long optics
static func range_penalty(s: Dictionary, d: int, r: int) -> int:
	var f: float = float(s["rangepen"])
	if int(s["pellets"]) > 1:
		f *= float(s["spread"])
	var p: float = float(absi(d - r)) * f
	if d < 4:
		p += float(s["close_pen"]) / 5.0
	return int(round(p))

## the shot's total after the cover factor (cover is the percent of the target hidden: 20 -> total x 0.8)
static func shot_total(nat: int, bonus: int, rpen: int, cover: int) -> int:
	return int(floor(float(nat + bonus - rpen) * (1.0 - float(clampi(cover, 0, 90)) / 100.0)))

## percent chance for the shot_index'th bullet of a volley to hit at distance d: every 2d10 roll and every roll of the natural range is counted
static func hit_chance(s: Dictionary, d: int, aim: int, moved: bool, crouch: bool, skill: int, penalty: int, shot_index: int = 0, prone: bool = false, extra: int = 0, cover: int = 0) -> int:
	var b: int = bonus_points(s, aim_at_shot(s, aim, shot_index), moved, crouch, skill, penalty, prone, extra)
	var lo: int = int(s["range_lo"])
	var hi: int = int(s["range_hi"])
	var hits := 0
	for r in range(lo, hi + 1):
		var rp: int = range_penalty(s, d, r)
		for x in range(1, 11):
			for y in range(1, 11):
				var nat: int = x + y
				if nat <= SK.CRIT_MISS_NAT:
					continue
				if nat >= SK.CRIT_NAT or shot_total(nat, b, rp, cover) >= SK.HIT_AT:
					hits += 1
	return clampi(int(round(float(hits) / float(hi - lo + 1))), 1, 99)

## the visible stat block of a gun, shown on the gunsmith screen: damage, natural range, max aim, clip size, mod slots and more
static func stat_line(s: Dictionary, aim_rate: float) -> String:
	return "dmg %d-%d   natural range %d-%d   max aim %d   clip %d   mod slots %d   aim loss %.2f a bullet   aim %.2f a turn   report %d   reload %d   ammo %s %s" % [
		s["dmg"][0], s["dmg"][1], s["range_lo"], s["range_hi"], s["max_aim"], s["mag"], s["slots"].size(), s["aim_loss"], aim_rate, s["noise"], s["reload"], s["cal"], s["label"]]

## average damage of one hit, for display
static func avg_dmg(s: Dictionary) -> float:
	return (float(s["dmg"][0]) + float(s["dmg"][1])) / 2.0

static func mode_name(gun) -> String:
	var m: Array = gun.def["gun"]["modes"]
	return m[gun.mode % m.size()][0]

static func mode_shots(gun) -> int:
	var m: Array = gun.def["gun"]["modes"]
	return int(m[gun.mode % m.size()][1])

static func mod_slot(modit) -> String:
	return modit.def["mod"]["slot"]

## cells on the straight line from a to b (exclusive of both), same level, in flat coordinates
static func line_cells(a: int, b: int, size: int) -> Array:
	var s2: int = size * size
	var base: int = (a / s2) * s2
	var x0: int = (a % s2) % size
	var y0: int = (a % s2) / size
	var x1: int = (b % s2) % size
	var y1: int = (b % s2) / size
	var out: Array = []
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var x := x0
	var y := y0
	while not (x == x1 and y == y1):
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		if not (x == x1 and y == y1):
			out.append(base + y * size + x)
	return out
