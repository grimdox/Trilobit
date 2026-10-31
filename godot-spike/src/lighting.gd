extends RefCounted
## Light, as the game and the view share it.  There are three levels, no more: DARK, DIM and LIT (see LightMap for where each is, and the rules of sight).
## This file holds the numbers the view draws them with, and the colours of the lights.
const CLK = preload("res://src/clock.gd")

const DARK := 0
const DIM := 1
const LIT := 2
const NAMES := ["dark", "dim", "lit"]

## how much each level darkens the map when it is drawn (LIT is drawn as it is)
const SHADE_DIM := 0.42
const SHADE_DARK := 0.82
const NIGHT_TINT := Color(0.03, 0.05, 0.15)     # the colour the darkness is drawn in
const DUSK_TINT := Color(0.42, 0.2, 0.24)       # the low sun's colour: sunrise and sunset warm the dim open air

const WARM_WHITE := Color(1.0, 0.92, 0.78)
const COOL_WHITE := Color(0.85, 0.95, 1.0)
const AMBER := Color(1.0, 0.72, 0.35)
const STREET := Color(1.0, 0.86, 0.55)
const DAYLIGHT := Color(1.0, 1.0, 1.0)

static func shade(level: int) -> float:
	return 0.0 if level >= LIT else (SHADE_DIM if level == DIM else SHADE_DARK)

## the colour of the darkening layer: night blue, warmed by the low sun at sunrise and sunset
static func tint(tick: int) -> Color:
	return NIGHT_TINT.lerp(DUSK_TINT, CLK.twilight(tick))

## the colour of a neon sprite name ("f_trl_neon_pink")
static func neon_colour(sprite: String) -> Color:
	var n: String = sprite.get_slice("_", sprite.get_slice_count("_") - 1)
	match n:
		"pink": return Color(1.0, 0.3, 0.7)
		"cyan": return Color(0.3, 0.9, 1.0)
		"green": return Color(0.4, 1.0, 0.5)
		"violet": return Color(0.7, 0.4, 1.0)
		"red": return Color(1.0, 0.3, 0.25)
		"amber": return Color(1.0, 0.7, 0.25)
	return Color(1.0, 0.5, 0.9)
