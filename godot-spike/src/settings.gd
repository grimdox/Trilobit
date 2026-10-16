extends RefCounted
## Player settings: key bindings, sound, tileset.  Stored in user://trilobit_settings.json.

## action id -> [label, default keycodes]
const ACTIONS := [
	["north", "Move north", [KEY_UP, KEY_KP_8, KEY_K]],
	["south", "Move south", [KEY_DOWN, KEY_KP_2, KEY_J]],
	["west", "Move west", [KEY_LEFT, KEY_KP_4, KEY_H]],
	["east", "Move east", [KEY_RIGHT, KEY_KP_6, KEY_L]],
	["nw", "Move north-west", [KEY_KP_7, KEY_Y]],
	["ne", "Move north-east", [KEY_KP_9, KEY_U]],
	["sw", "Move south-west", [KEY_KP_1, KEY_B]],
	["se", "Move south-east", [KEY_KP_3, KEY_N]],
	["wait", "Wait / brake", [KEY_PERIOD, KEY_KP_5, KEY_SPACE]],
	["up", "Up (stairs, lift off)", [KEY_LESS, KEY_PAGEUP, KEY_BRACKETLEFT]],
	["down", "Down (stairs, descend)", [KEY_GREATER, KEY_PAGEDOWN, KEY_BRACKETRIGHT]],
	["talk", "Talk", [KEY_T]],
	["pay", "Pay debt", [KEY_P]],
	["pickup", "Pick up", [KEY_G, KEY_COMMA]],
	["fire", "Fire", [KEY_F]],
	["aim", "Aim", [KEY_A]],
	["reload", "Reload", [KEY_R]],
	["firemode", "Fire mode", [KEY_V]],
	["ammo", "Next ammo kind", [KEY_X]],
	["target", "Cycle target", [KEY_TAB]],
	["gunsmith", "Gunsmith", [KEY_F4]],
	["steal", "Pickpocket", [KEY_S]],
	["crouch", "Crouch", [KEY_C]],
	["crawl", "Crawl", [KEY_Z]],
	["strike", "Strike (then direction)", [KEY_W]],
	["shove", "Shove (then direction)", [KEY_O]],
	["turn", "Turn to look (then direction, no time)", [KEY_COMMA]],
	["swap", "Swap weapon", [KEY_BACKSLASH]],
	["jump", "Jump (then direction)", [KEY_Q]],
	["vehicle", "Enter / leave vehicle (Shift: service)", [KEY_E]],
	["service", "Vehicle service: engines, repairs", [KEY_F6]],
	["drop", "Drop wielded", [KEY_D]],
	["inventory", "Inventory", [KEY_I]],
	["implants", "Implants screen", [KEY_F3]],
	["map", "Island map", [KEY_M]],
	["help", "Help", [KEY_QUESTION]],
]

var path: String = "user://trilobit_settings.json"
var binds: Dictionary = {}          # action -> Array of keycodes
var sound_on: bool = true
var volume: float = 0.7
var tileset: int = 0

func _init() -> void:
	reset_keys()

func reset_keys() -> void:
	binds = {}
	for a in ACTIONS:
		binds[a[0]] = (a[2] as Array).duplicate()

func label(action: String) -> String:
	for a in ACTIONS:
		if a[0] == action:
			return a[1]
	return action

## which action does this key press trigger (only the plain, un-modified key)?  "" if none
func action_for(keycode: int) -> String:
	for a in binds:
		if keycode in binds[a]:
			return a
	return ""

func key_text(action: String) -> String:
	var ks: Array = binds.get(action, [])
	var out := []
	for k in ks:
		out.append(OS.get_keycode_string(k))
	return ", ".join(out) if not out.is_empty() else "(unbound)"

## bind a key to an action: it replaces whatever the action had, and is taken away from any other action that used it
func rebind(action: String, keycode: int) -> void:
	for a in binds:
		binds[a] = (binds[a] as Array).filter(func(k): return k != keycode)
	binds[action] = [keycode]

func to_dict() -> Dictionary:
	return {"binds": binds, "sound": sound_on, "volume": volume, "tileset": tileset}

func from_dict(d: Dictionary) -> void:
	var b: Dictionary = d.get("binds", {})
	for a in b:
		if binds.has(a):
			binds[a] = (b[a] as Array).map(func(k): return int(k))
	sound_on = bool(d.get("sound", true))
	volume = clampf(float(d.get("volume", 0.7)), 0.0, 1.0)
	tileset = int(d.get("tileset", 0))

func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(to_dict()))

func load_file() -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		from_dict(d)
