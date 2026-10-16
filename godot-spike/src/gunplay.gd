extends RefCounted
## Gun rules, kept free of game state so they can be tested on their own.
## A gun's numbers = the class/model block in its item definition, changed by the installed mods and by the kind of ammunition loaded.
## Accuracy per shot (percent) is built from: model accuracy + mods + skill + aiming (or the hip-fire bonus) - range - recoil within a burst
## - moving - the implant's tremor, and clamped to 5..95.

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
const MAX_AIM := 3
## iron sights (percent to hit, lost as soon as an optic is fitted), hands needed, and how quick the class is to settle (aim speed modifier)
const SIGHTS := {"pistol": 3, "revolver": 4, "smg": 4, "rifle": 6, "shotgun": 2, "sniper": 8, "mg": 3, "heavy_mg": 1, "launcher": 0, "laser": 5}
const HANDS := {"pistol": 1, "revolver": 1, "laser": 1}
const AIM_CLASS := {"pistol": 0.1, "revolver": 0.05, "smg": 0.0, "rifle": -0.05, "shotgun": -0.1, "sniper": -0.2, "mg": -0.25, "heavy_mg": -0.35, "launcher": -0.2, "laser": 0.0}
const AIM_MOD := {"trl_mod_redot": 0.05, "trl_mod_holo": 0.05, "trl_mod_scope4": -0.08, "trl_mod_scope8": -0.2, "trl_mod_smartlink": 0.1, "trl_mod_laser": 0.05, "trl_mod_bipod": -0.05}

static func default_kind(cal: String) -> String:
	return KINDS_BY_CAL[cal][0]

## the mod effects summed up
static func fx(gun) -> Dictionary:
	var t := {"acc": 0, "aim": 0, "hip": 0, "range_pct": 0, "rangepen_pct": 0, "close_pen": 0, "recoil_pct": 0, "dmg_pct": 0, "mag_pct": 0, "jam": 0.0, "reload": 0,
		"spread_pct": 0, "noise_cap": 999}
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
	s["range"] = maxi(3, int(float(b["range"]) * (1.0 + float(f["range_pct"]) / 100.0)))
	s["acc"] = int(b["acc"]) + int(f["acc"])
	s["mag"] = maxi(1, int(round(float(b["mag"]) * (1.0 + float(f["mag_pct"]) / 100.0))))
	s["recoil"] = maxf(0.0, float(b["recoil"]) * (1.0 + float(f["recoil_pct"]) / 100.0))
	s["noise"] = mini(int(b["noise"]), int(f["noise_cap"]))
	s["reload"] = maxi(1, int(b["reload"]) + int(f["reload"]))
	s["pellets"] = int(km.get("pellets", b["pellets"]))
	s["spread"] = maxf(0.2, 1.0 + float(f["spread_pct"]) / 100.0)
	s["blast"] = int(km.get("blast", 0))
	s["pen"] = int(km.get("pen", 0))
	s["aim_step"] = 6 + int(f["aim"])
	s["hip"] = int(f["hip"])
	var cls := ""
	for tg in gun.def.get("tags", []):
		if tg != "gun":
			cls = String(tg)
	s["cls"] = cls
	var optic := false
	var scoped := false
	var rate: float = float(AIM_CLASS.get(cls, 0.0))
	for m in gun.mods:
		if m.def["mod"]["slot"] == "optic":
			optic = true
			if int(m.def["mod"]["fx"].get("range_pct", 0)) > 0:
				scoped = true
		rate += float(AIM_MOD.get(m.def["id"], 0.0))
	s["optic"] = optic
	s["scoped"] = scoped
	s["sights"] = 0 if optic else int(SIGHTS.get(cls, 2))
	s["hands"] = int(HANDS.get(cls, 2))
	s["aim_rate"] = rate
	s["rangepen"] = 4.0 * (1.0 - clampf(float(f["rangepen_pct"]) / 100.0, 0.0, 0.9))
	s["close_pen"] = int(f["close_pen"])
	s["jam"] = maxf(0.0, float(b["jam"]) + float(f["jam"]))
	s["modes"] = b["modes"]
	s["slots"] = b["slots"]
	s["suppressed"] = s["noise"] <= 6 and b["noise"] > 6
	return s

## percent chance for the shot_index'th shot of a volley to hit at distance d
static func hit_chance(s: Dictionary, d: int, aim: int, moved: bool, crouch: bool, skill: int, penalty: int, shot_index: int = 0, prone: bool = false) -> int:
	var c: float = float(s["acc"]) + float(skill) * 2.0 + float(s.get("sights", 0))
	c += float(aim * int(s["aim_step"])) if aim > 0 else float(s["hip"])
	c -= float(s["rangepen"]) * float(maxi(0, d - 3))
	if d < 4:
		c -= float(s["close_pen"])
	if d > int(s["range"]):
		c -= 25.0
	c -= float(s["recoil"]) * float(shot_index) * 2.0
	if moved:
		c -= 10.0
	if crouch:
		c += 5.0
	if prone:
		c += 5.0
	c -= float(penalty)
	return clampi(int(c), 5, 95)

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
