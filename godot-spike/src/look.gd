extends RefCounted
## Names for what the look cursor can point at: terrain by tile id (data table), plus helpers that read the game state.
const CG = preload("res://src/citygen.gd")

const TERRAIN := {0: "bare ground", 1: "road", 2: "wall", 3: "floor", 4: "door", 5: "water", 6: "grass", 7: "open air", 8: "stairs", 9: "elevator shaft",
	10: "glass", 11: "roof", 12: "maintenance catwalk", 13: "platform", 14: "railway track", 15: "sewer catwalk", 16: "sewer sludge", 17: "solid rock",
	18: "train carriage", 19: "ladder", 20: "railing", 21: "manhole cover", 22: "locked door", 23: "crate", 24: "dumpster", 25: "planter",
	26: "gravel", 27: "cliff", 28: "mountain", 29: "tree", 30: "rocky ground", 31: "field", 32: "sand"}

static func terrain_name(t: int) -> String:
	if TERRAIN.has(t):
		return String(TERRAIN[t])
	var k: int = t - CG.EXTRA0
	if k >= 0 and k < CG.EXTRA.size():
		return String(CG.EXTRA[k][0]).replace("_", " ")
	return "unknown ground"
