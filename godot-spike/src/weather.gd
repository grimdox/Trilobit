extends RefCounted
## Weather.  It is not stored: it is worked out from the island's seed and the clock, so every zone, save and load agrees about it.  For now it only rains
## (60% of the hours) and rain is an overlay on the map; it does not change the light.
const CLK = preload("res://src/clock.gd")
const RAIN_SHARE := 60                          # percent of the hours it rains
const SPELL := CLK.HOUR                         # the weather is decided an hour at a time

## whether it rains in the hour a tick falls in: 60% of hours do
static func raining(seed_value: int, tick: int) -> bool:
	return hash([seed_value, tick / SPELL, "wx"]) % 100 < RAIN_SHARE

## the weather: Rain or Clear, nothing else for now.  It is worked out from the island's seed and the clock, so every zone, save and load agrees.
##   kind   "Rain" or "Clear";  rain 0.6 while it rains, else 0;  cloud and mist stay 0 (the sky does not change the light yet)
static func at(seed_value: int, tick: int) -> Dictionary:
	var wet: bool = raining(seed_value, tick)
	return {"kind": "Rain" if wet else "Clear", "cloud": 0.0, "rain": 0.6 if wet else 0.0, "mist": 0.0}

## how much of the sunlight gets through the sky: all of it (rain is an overlay only, for now)
static func sun_factor(_w: Dictionary) -> float:
	return 1.0

## no lightning for now
static func flash(_seed_value: int, _tick: int, _w: Dictionary) -> bool:
	return false

## "Rain" or "Clear": the HUD word
static func label(w: Dictionary) -> String:
	return String(w["kind"])
