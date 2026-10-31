extends RefCounted
## Player settings: key bindings, sound, tileset.  Stored in user://trilobit_settings.json.

## action id -> [label, default keycodes]
const ACTIONS := [
	["north", "Move north", [KEY_UP, KEY_KP_8]],
	["south", "Move south", [KEY_DOWN, KEY_KP_2]],
	["west", "Move west", [KEY_LEFT, KEY_KP_4]],
	["east", "Move east", [KEY_RIGHT, KEY_KP_6]],
	["nw", "Move north-west", [KEY_KP_7]],
	["ne", "Move north-east", [KEY_KP_9]],
	["sw", "Move south-west", [KEY_KP_1]],
	["se", "Move south-east", [KEY_KP_3]],
	["wait", "Wait one turn / brake", [KEY_PERIOD, KEY_KP_5, KEY_SPACE]],
	["waitmenu", "Wait for a chosen time", [KEY_ENTER, KEY_KP_ENTER]],
	["up", "Up (stairs, lift off)", [KEY_LESS, KEY_PAGEUP, KEY_BRACKETLEFT]],
	["down", "Down (stairs, descend)", [KEY_GREATER, KEY_PAGEDOWN, KEY_BRACKETRIGHT]],
	["talk", "Talk", [KEY_T]],
	["pickup", "Pick up", [KEY_G, KEY_COMMA]],
	["fire", "Fire", [KEY_F]],
	["aim", "Aim", [KEY_A]],
	["reload", "Reload", [KEY_R]],
	["firemode", "Fire mode", [KEY_V]],
	["ammo", "Next ammo kind", [KEY_Z]],
	["target", "Cycle target", [KEY_TAB]],
	["mtarget", "Manual target (pick anyone or a light with the cursor)", [KEY_SLASH]],
	["interact", "Interact: doors, terminals, chargers, tables", [KEY_X]],
	["viewtarget", "Switch the view to the target and back", [KEY_QUOTELEFT]],
	["steal", "Pickpocket", [KEY_S]],
	["siphon", "Draw power from a downed person", [KEY_MINUS]],
	["movement", "Movement select: crawl, crouch, walk or run", [KEY_C]],
	["strike", "Strike (then direction)", [KEY_W]],
	["shove", "Shove (then direction)", []],
	["peek", "Peek: lean out a tile to look round a corner (then direction, half a turn)", [KEY_K]],
	["turn", "Turn to look (then direction, no time)", [KEY_SEMICOLON, KEY_KP_SUBTRACT]],
	["swap", "Swap weapon", [KEY_BACKSLASH]],
	["jump", "Jump (then direction)", [KEY_Q]],
	["vehicle", "Enter / leave vehicle", [KEY_E]],
	["useitem", "Use an item (food, medical) or swap gear", [KEY_U]],
	["drop", "Drop (opens the inventory)", [KEY_D]],
	["inventory", "Equipment & inventory screen", [KEY_I]],
	["skills", "Attributes & skills screen", [KEY_O]],
	["implants", "Implants screen", [KEY_P]],
	["map", "Island map", [KEY_M]],
	["look", "Look (move the cursor, Esc ends)", [KEY_L]],
	["consume", "Consume food or drink", [KEY_F8, KEY_APOSTROPHE]],
	["nano", "Nanohack menu", [KEY_N]],
	["zoom", "Zoom: close, middle or far", [KEY_EQUAL, KEY_KP_ADD]],
	["fullscreen", "Toggle fullscreen", [KEY_F11]],
	["keysscreen", "Key bindings screen", [KEY_QUESTION]],
]

## keys that cannot be rebound but belong to an action, shown after its own keys
const FIXED_KEYS := {"fullscreen": ["Alt+Enter"], "shove": ["Shift+O"]}

## display modes and the window sizes offered for the windowed mode
const WINDOW_MODES := ["Windowed", "Borderless fullscreen", "Fullscreen"]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]

var path: String = "user://trilobit_settings.json"
var binds: Dictionary = {}          # action -> Array of keycodes
var sound_on: bool = true
var volume: float = 0.7
var tileset: int = 0
## false: arrows move forward/back and turn, the numpad steps without turning.  true: every move key turns you the way you go (the old scheme)
var view_follows_move := false
var lighting := true                    # day and night light on the map
var weather_fx := true                  # rain, fog and storms drawn on the map
var zoom := 1                          # 0 close (10 tiles either side), 1 middle (15), 2 far (20)
var window_mode: int = 0                # index into WINDOW_MODES
var resolution: Vector2i = Vector2i(1920, 1080)

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
	for f in FIXED_KEYS.get(action, []):
		out.append(f)
	return ", ".join(out) if not out.is_empty() else "(unbound)"

## what the window should be: the DisplayServer mode and size for the chosen display mode on a screen of this size
func window_plan(screen: Vector2i, force_fullscreen: bool = false) -> Dictionary:
	var m: int = 2 if force_fullscreen else window_mode
	if m == 1:
		return {"mode": DisplayServer.WINDOW_MODE_FULLSCREEN, "size": screen}
	if m == 2:
		return {"mode": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, "size": screen}
	return {"mode": DisplayServer.WINDOW_MODE_WINDOWED, "size": Vector2i(mini(resolution.x, screen.x), mini(resolution.y, screen.y))}

func resolution_index() -> int:
	return RESOLUTIONS.find(resolution)

func resolution_text() -> String:
	return "%d x %d" % [resolution.x, resolution.y]

## the next (dir = 1) or previous window size on the list; a size not on the list steps to the nearest one in that direction
func step_resolution(dir: int) -> void:
	var i: int = resolution_index()
	if i < 0:
		i = 0
		for k in RESOLUTIONS.size():
			if RESOLUTIONS[k].x * RESOLUTIONS[k].y <= resolution.x * resolution.y:
				i = k
		resolution = RESOLUTIONS[i]
		return
	resolution = RESOLUTIONS[clampi(i + dir, 0, RESOLUTIONS.size() - 1)]

## bind a key to an action: it replaces whatever the action had, and is taken away from any other action that used it
func rebind(action: String, keycode: int) -> void:
	for a in binds:
		binds[a] = (binds[a] as Array).filter(func(k): return k != keycode)
	binds[action] = [keycode]

func to_dict() -> Dictionary:
	return {"keys_v": KEYS_VERSION, "binds": binds, "sound": sound_on, "volume": volume, "tileset": tileset, "view_follows_move": view_follows_move, "zoom": zoom, "lighting": lighting, "weather_fx": weather_fx, "window_mode": window_mode, "resolution": [resolution.x, resolution.y]}

## version 2: Z is the ammo key and X interacts (they were X and P), C is the movement prompt (crouch and crawl keys are gone)
## version 3: the screens are tabs: P equipment & inventory, I implants, O attributes & skills, M map; shove is Shift+O (fixed)
## version 4: the turn-to-look key gains the keypad minus on older saves, and D opens the inventory to drop
const KEYS_VERSION := 5

func from_dict(d: Dictionary) -> void:
	var b: Dictionary = d.get("binds", {}).duplicate()
	if int(d.get("keys_v", 1)) < 2:
		for moved in ["ammo", "interact"]:
			b.erase(moved)
	if int(d.get("keys_v", 1)) < 3:
		for moved3 in ["inventory", "implants", "skills", "shove"]:
			b.erase(moved3)
	if int(d.get("keys_v", 1)) < 5:
		for moved5 in ["inventory", "implants", "skills", "north", "south", "west", "nw", "sw", "ne"]:
			b.erase(moved5)                   # the character screens moved to I, O, P and the vi keys went
	if int(d.get("keys_v", 1)) < 4:
		b.erase("turn")                           # so the keypad minus joins the turn key on saves that only had ;
	for a in b:
		if binds.has(a):
			binds[a] = (b[a] as Array).map(func(k): return int(k))
	# an action added since this file was written keeps its default keys: they are taken away from whatever the old file gave them to
	for ac in ACTIONS:
		if not b.has(ac[0]):
			for k in ac[2]:
				for other in binds:
					if other != ac[0]:
						binds[other] = (binds[other] as Array).filter(func(x): return x != k)
	sound_on = bool(d.get("sound", true))
	volume = clampf(float(d.get("volume", 0.7)), 0.0, 1.0)
	tileset = int(d.get("tileset", 0))
	view_follows_move = bool(d.get("view_follows_move", false))
	zoom = clampi(int(d.get("zoom", 1)), 0, 2)
	lighting = bool(d.get("lighting", true))
	weather_fx = bool(d.get("weather_fx", true))
	window_mode = clampi(int(d.get("window_mode", 2 if bool(d.get("fullscreen", false)) else 0)), 0, WINDOW_MODES.size() - 1)
	var r = d.get("resolution", [1920, 1080])
	if r is Array and r.size() == 2:
		resolution = Vector2i(clampi(int(r[0]), 640, 7680), clampi(int(r[1]), 360, 4320))

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
