extends RefCounted
## The game clock.  One turn is six seconds; everything that is measured in minutes, hours or days is measured here, in turns.
##   10 turns = 1 minute     600 turns = 1 hour     14,400 turns = 1 day
## (Before 2026-10-18 a turn was a minute: saves with no "tv" key are converted by OLD_TO_NEW.)
const TURN_SEC := 6
const MIN := 10
const HOUR := 600
const DAY := 14400
const START_TICK := 7 * HOUR - 20 * MIN       # a new game begins at 06:40
const OLD_TO_NEW := 10                        # a turn used to be a minute
const SAVE_VERSION := 2

## the wait menu: [label, turns] for fixed spans, [label, hour of day] for "until"
const WAITS := [
	["1 turn (6 seconds)", 1],
	["10 turns (1 minute)", 10],
	["100 turns (10 minutes)", 100],
	["600 turns (1 hour)", 600],
]
const WAIT_UNTIL := [
	["Wait until 6am", 6],
	["Wait until noon", 12],
	["Wait until 6pm", 18],
	["Wait until midnight", 0],
]

static func hour_of(tick: int) -> int:
	return (tick / HOUR) % 24

static func minute_of(tick: int) -> int:
	return (tick / MIN) % 60

static func second_of(tick: int) -> int:
	return (tick % MIN) * TURN_SEC

static func day_of(tick: int) -> int:
	return tick / DAY + 1

## "06:40:06"
static func text(tick: int) -> String:
	return "%02d:%02d:%02d" % [hour_of(tick), minute_of(tick), second_of(tick)]

## turns from `tick` until the next time the clock reads `hour`:00 (a full day if it already does)
static func turns_until(tick: int, hour: int) -> int:
	var t: int = hour * HOUR - (tick % DAY)
	if t <= 0:
		t += DAY
	return t

## a span of turns for people: "4h", "1h05", "35m", "50s"
static func span_text(turns: int) -> String:
	if turns >= HOUR:
		var h: int = turns / HOUR
		var m: int = (turns % HOUR) / MIN
		return "%dh%02d" % [h, m] if m > 0 else "%dh" % h
	if turns >= MIN:
		return "%dm" % (turns / MIN)
	return "%ds" % (turns * TURN_SEC)

# ---------------------------------------------------------------- the sun
## Daylight begins with the half hour of sunrise at 07:30 (07:30 to 08:00) and ends with the half hour of sunset at 18:00 (18:00 to 18:30); the open air is
## lit from 08:00 to 18:00, dim in the two half hours, and dark from 18:30 to 07:30.
const SUNRISE_FROM := 7 * HOUR + 30 * MIN
const DAY_FROM := 8 * HOUR
const DAY_UNTIL := 18 * HOUR
const SUNSET_TO := 18 * HOUR + 30 * MIN

## the three light levels the game knows
const DARK := 0
const DIM := 1
const LIT := 2

## the light level of the open air: LIT in the day, DIM in the half hours of sunrise and sunset, DARK at night
static func ambient_level(tick: int) -> int:
	var t: int = tick % DAY
	if t >= DAY_FROM and t < DAY_UNTIL:
		return LIT
	if (t >= SUNRISE_FROM and t < DAY_FROM) or (t >= DAY_UNTIL and t < SUNSET_TO):
		return DIM
	return DARK

## turns into the day (0 to DAY - 1)
static func in_day(tick: int) -> int:
	return tick % DAY

## how much of the sun there is: 0 at night, 1 in full daylight, a smooth ramp over the 30 minutes of sunrise and of sunset
static func daylight(tick: int) -> float:
	var t: int = in_day(tick)
	if t >= DAY_FROM and t < DAY_UNTIL:
		return 1.0
	var f := 0.0
	if t >= SUNRISE_FROM and t < DAY_FROM:
		f = float(t - SUNRISE_FROM) / float(DAY_FROM - SUNRISE_FROM)
	elif t >= DAY_UNTIL and t < SUNSET_TO:
		f = 1.0 - float(t - DAY_UNTIL) / float(SUNSET_TO - DAY_UNTIL)
	return f * f * (3.0 - 2.0 * f)

## 0 in full day or night, rising to 1 half way through a sunrise or sunset: the warm colour of the low sun
static func twilight(tick: int) -> float:
	var t: int = in_day(tick)
	var f := -1.0
	if t >= SUNRISE_FROM and t < DAY_FROM:
		f = float(t - SUNRISE_FROM) / float(DAY_FROM - SUNRISE_FROM)
	elif t >= DAY_UNTIL and t < SUNSET_TO:
		f = float(t - DAY_UNTIL) / float(SUNSET_TO - DAY_UNTIL)
	return 0.0 if f < 0.0 else sin(f * PI)

## "Night", "Sunrise", "Day" or "Sunset"
static func phase(tick: int) -> String:
	var t: int = in_day(tick)
	if t >= DAY_FROM and t < DAY_UNTIL:
		return "Day"
	if t >= SUNRISE_FROM and t < DAY_FROM:
		return "Sunrise"
	if t >= DAY_UNTIL and t < SUNSET_TO:
		return "Sunset"
	return "Night"
