extends Node
## Entry point: title screen, menus, then the game, its view and HUD; turns keys into actions.
const GP = preload("res://src/gunplay.gd")
const GameScript = preload("res://src/game.gd")
const WorldScript = preload("res://src/world.gd")
const TilesetScript = preload("res://src/tileset.gd")
const ViewScript = preload("res://src/view.gd")
const SettingsScript = preload("res://src/settings.gd")
const SfxScript = preload("res://src/sfx.gd")
const ScreenScript = preload("res://src/screen_view.gd")
const IMP = preload("res://src/implants.gd")
const SK = preload("res://src/skills.gd")
const CR = preload("res://src/creation.gd")
const CLK = preload("res://src/clock.gd")
const MS = preload("res://src/missions.gd")
const BarterUIScript = preload("res://src/barter_ui.gd")
const GearScript = preload("res://src/gear_ui.gd")
const LOG_LINES := 10        # messages shown in the panel along the bottom
const UI_S := 1.5          # the interface is laid out for 1280x720 and drawn at 1.5x on the 1920x1080 canvas
const TILESETS := ["Trilobit64"]      # Trilobit's own 64px art (tools/content/gen_tiles64.py); more sets can be added here
const SLOTS := 3
const SCREEN_MODES := ["title", "loading", "pause", "options", "visuals", "keys", "saves", "loads", "equipment", "implants", "skills", "map", "create", "terminal", "barter", "elevator", "test"]
const MOUSE_MODES := ["title", "pause", "options", "visuals", "keys", "saves", "loads", "create", "test"]
const TAB_MODES := ["equipment", "implants", "skills", "map"]       # the paused character screens, one tab each (< and > step through them)

var tm: Dictionary = {}                # the open mission terminal: {cell, offers, sel, msg}
var game
var tileset
var view
var status: Label
var zoom_btn: Button
var logbox: RichTextLabel
var log_bg: ColorRect
var panel: RichTextLabel
var mode: String = "title"           # title, play, garage, inventory, talk, mods, jump, strike, shove, turn, look, waitmenu, movemenu, waiting, consume, pause, options, visuals, keys, saves, loads, implants, skills, map, loading
var menu_sel: int = 0                 # the highlighted line of the wait menu
var consume_list: Array = []          # what the consume menu offers (see Game.consumables)
var key_unicode: int = 0              # the character of the key being handled (the creation screen's name line reads it)
var pick_list: Array = []             # the things around you when several can be used: [{kind, cell, label}]
var look_off := Vector2i.ZERO         # the look cursor, in tiles from the player
var menu: Dictionary = {}
var ts_index: int = 0
var inv_map: Dictionary = {}
var gear = GearScript.new()            # the equipment and implants tabs (gear_ui.gd)
var elev_sel: int = 0                    # the floor highlighted in the elevator list (mode "elevator")
var elev_list: Array = []
var elev_typed: String = ""
var clock_cell: int = -1                 # the station clock being read (mode "clock")
var bt = BarterUIScript.new()          # the barter screen (barter_ui.gd)
var gear_base = null                   # item icons: the Trilobit64 set
var gear_items = null
var tab_from: String = "play"          # where Esc on a tab goes: "play" or "pause"
var settings
var sfx
var screen
var play_nodes: Array = []
var screen_back: String = "title"     # where Esc on a sub-screen goes
var rebinding: String = ""            # action waiting for a key
var key_scroll_items: Array = []
var pending_seed: int = -1
var cc: Dictionary = {}               # the character being created: {app, attrs} (creation.gd)
var cc_sel: int = 0                   # the highlighted row of the creation screen
var cc_tileset = null                 # tileset for the doll preview on that screen
var world = null                      # the island (zone games); null for a stand-alone city
var map_tex: ImageTexture = null
var map_seed: int = -1
var save_prefix: String = "user://trilobit_save_"
var settings_path: String = "user://trilobit_settings.json"

func _ready() -> void:
	settings = SettingsScript.new()
	settings.path = settings_path
	settings.load_file()
	ts_index = clampi(settings.tileset, 0, TILESETS.size() - 1)
	sfx = SfxScript.new()
	add_child(sfx)
	apply_audio()
	apply_window()
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.scale = Vector2(UI_S, UI_S)
	add_child(layer)
	screen = ScreenScript.new()
	screen.visible = false
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.position = Vector2.ZERO
	screen.size = Vector2(1280, 720)
	layer.add_child(screen)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--seed="):
			pending_seed = int(a.substr(7))
	if "--newgame" in args or pending_seed >= 0:
		begin_new(pending_seed if pending_seed >= 0 else int(Time.get_unix_time_from_system()) % 100000)
	else:
		open_screen("title")

## The window: windowed at a chosen size, borderless fullscreen (a screen-sized window, so alt-tab and the taskbar behave) or exclusive fullscreen
## (which on Windows takes over the whole monitor).  F11 or Alt+Enter flips between windowed and fullscreen from any screen; the choice is remembered.
func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var scr: int = DisplayServer.window_get_current_screen()
	var plan: Dictionary = settings.window_plan(DisplayServer.screen_get_size(scr), "--fullscreen" in OS.get_cmdline_args())
	DisplayServer.window_set_mode(plan["mode"])
	if plan["mode"] == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(plan["size"])
		var at: Vector2i = DisplayServer.screen_get_position(scr) + (DisplayServer.screen_get_size(scr) - Vector2i(plan["size"])) / 2
		DisplayServer.window_set_position(at)
	DisplayServer.window_set_title("とりろびつ")

func toggle_fullscreen() -> void:
	settings.window_mode = 2 if settings.window_mode == 0 else 0
	settings.save()
	apply_window()
	if screen != null and (mode == "visuals"):
		_fill_visuals()

func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and rebinding == "":
		if settings.action_for(ev.keycode) == "fullscreen" or (ev.alt_pressed and (ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER)):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()

func apply_audio() -> void:
	sfx.enabled = settings.sound_on
	sfx.volume = settings.volume

func begin_new(seed: int, profile: Dictionary = {}) -> void:
	open_screen("loading")
	await get_tree().process_frame
	await get_tree().process_frame
	world = WorldScript.new()
	world.start(seed, WorldScript.CITY_PEOPLE)
	if not profile.is_empty():
		CR.apply(world.game, profile)          # the attributes and look chosen on the creation screen
	start_play(world.game)

## the TEST--- scenarios: a stand-alone game (no island) with a generic, randomised character.  Large City: a city 3072 tiles a side, twice the island city's
## width and length (and so four times the area); it takes minutes to build and several GB of memory.
func begin_scenario(id: String) -> void:
	var size := 512
	match id:
		"large_city":
			size = 3072
		"city_2560":
			size = 2560
	open_screen("loading")
	screen.subtitle = "Generating a %d x %d city (this takes a few minutes)..." % [size, size]
	await get_tree().process_frame
	await get_tree().process_frame
	world = null
	var g = GameScript.new(int(Time.get_unix_time_from_system()) % 100000)
	g.test_size = size
	g.setup(WorldScript.CITY_PEOPLE)
	var r := RandomNumberGenerator.new()
	r.randomize()
	CR.apply(g, CR.randomized(r, CR.new_profile()))
	start_play(g)

## hand the view the lighting and weather switches from the options
func _view_flags() -> void:
	if view != null and is_instance_valid(view):
		view.lighting_on = settings.lighting
		view.weather_on = settings.weather_fx
		view.queue_redraw()

func begin_load(slot: int) -> void:
	var d := read_slot(slot)
	if d.is_empty():
		return
	open_screen("loading")
	await get_tree().process_frame
	await get_tree().process_frame
	if d.has("island") and int(d["island"]) >= 0 and d.has("zones"):
		world = WorldScript.new()
		world.load_dict(d)
		start_play(world.game)
	else:
		world = null
		var g = GameScript.new(int(d["seed"]))
		g.load_dict(d)
		start_play(g)
	game.say("Game loaded (slot %d)." % slot)
	refresh()

func start_play(g) -> void:
	for c in play_nodes:
		if is_instance_valid(c):
			c.queue_free()
	play_nodes = []
	tileset = TilesetScript.new()
	_load_tileset()
	game = g
	view = ViewScript.new()
	view.game = game
	view.tileset = tileset
	view.lighting_on = settings.lighting
	view.weather_on = settings.weather_fx
	view.set_zoom(settings.zoom)
	add_child(view)
	play_nodes.append(view)
	var layer := CanvasLayer.new()
	layer.scale = Vector2(UI_S, UI_S)
	add_child(layer)
	play_nodes.append(layer)
	zoom_btn = Button.new()
	zoom_btn.position = Vector2(905, 534)
	zoom_btn.size = Vector2(118, 22)
	zoom_btn.focus_mode = Control.FOCUS_NONE
	zoom_btn.add_theme_font_size_override("font_size", 12)
	zoom_btn.pressed.connect(cycle_zoom)
	layer.add_child(zoom_btn)
	_zoom_label()
	status = Label.new()
	status.position = Vector2(8, 4)
	status.add_theme_font_size_override("font_size", 16)
	layer.add_child(status)
	logbox = RichTextLabel.new()
	logbox.position = Vector2(8, 560)
	logbox.size = Vector2(1264, 158)
	logbox.add_theme_font_size_override("normal_font_size", 11)
	logbox.add_theme_font_size_override("bold_font_size", 11)
	logbox.bbcode_enabled = true
	logbox.scroll_following = true
	layer.add_child(logbox)
	log_bg = ColorRect.new()
	var bg := log_bg
	bg.color = Color(0, 0, 0, 0.92)
	bg.position = Vector2(0, 558)
	bg.size = Vector2(1280, 162)
	bg.z_index = -1
	layer.add_child(bg)
	panel = RichTextLabel.new()
	panel.position = Vector2(200, 60)
	panel.size = Vector2(880, 520)
	panel.bbcode_enabled = true
	panel.visible = false
	panel.add_theme_color_override("default_color", Color.WHITE)
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(0.05, 0.06, 0.1, 0.95)
	pbg.set_border_width_all(2)
	pbg.border_color = Color(0.3, 0.9, 1)
	panel.add_theme_stylebox_override("normal", pbg)
	layer.add_child(panel)
	# none of the play layer's controls may swallow a mouse click: the menus and the creation screen are drawn over it and read clicks themselves
	# (a dead character's BEGIN and BACK buttons sat under the message bar and did nothing)
	for ctl in layer.get_children():
		if ctl is Control:
			ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode = "play"
	screen.visible = false
	refresh()

# ---------------------------------------------------------------- saves
func slot_path(n: int) -> String:
	return "%s%d.json" % [save_prefix, n]

func read_slot(n: int) -> Dictionary:
	if not FileAccess.file_exists(slot_path(n)):
		return {}
	var f := FileAccess.open(slot_path(n), FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary and d.has("world"):
		var w: Dictionary = d["world"]
		var gd: Dictionary = (w["game"] as Dictionary).duplicate()
		gd["island"] = w["island"]
		gd["zones"] = w["zones"]
		gd["layout"] = w.get("layout", 1)
		gd["visited"] = w.get("visited", [])
		gd["switches"] = w.get("switches", 0)
		return gd
	if d is Dictionary and d.has("game"):
		return d["game"]
	return {}

func slot_meta(n: int) -> String:
	if not FileAccess.file_exists(slot_path(n)):
		return "(empty)"
	var f := FileAccess.open(slot_path(n), FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	if d is Dictionary and d.has("meta"):
		var m: Dictionary = d["meta"]
		return "%s   Body %s   ¥%s   %s" % [m.get("where", "?"), m.get("hp", "?"), m.get("yen", "?"), m.get("saved", "")]
	return "(unreadable)"

func save_slot(n: int) -> bool:
	if game == null:
		return false
	var meta := {"where": game.zname(game.pc), "hp": game.body.total(), "yen": game.yen, "turn": game.turn, "saved": Time.get_datetime_string_from_system(false, true)}
	var f := FileAccess.open(slot_path(n), FileAccess.WRITE)
	if f == null:
		return false
	if world != null:
		world.game = game
		f.store_string(JSON.stringify({"meta": meta, "world": world.save_dict()}))
	else:
		f.store_string(JSON.stringify({"meta": meta, "game": game.save_dict()}))
	return true

# ---------------------------------------------------------------- screens (title, pause, options, keys, saves, implants)
func open_screen(kind: String) -> void:
	if kind in TAB_MODES:
		open_tab(kind)
		return
	mode = kind
	screen.kind = kind
	screen.visible = true
	screen.overlay = game != null and kind != "title" and kind != "loading" and screen_back != "title"
	screen.prompt = ""
	screen.sel = 0
	screen.scroll = 0
	screen.title = ""
	screen.subtitle = ""
	screen.footer = "Up / Down  -  Enter selects  -  Esc goes back"
	screen.game = game
	screen.loading = false
	match kind:
		"title":
			screen_back = "title"
			screen.overlay = false
			screen.items = [{"label": "New Game", "id": "new"}, {"label": "Load Game", "id": "load"}, {"label": "Options", "id": "options"}, {"label": "TEST---", "id": "test"}, {"label": "Exit", "id": "exit"}]
			screen.footer = "Up / Down  -  Enter"
		"loading":
			screen.overlay = false
			screen.items = []
			screen.kind = "title"
			screen.loading = true
			screen.subtitle = "Generating the world..."
			screen.footer = ""
		"pause":
			screen.overlay = true
			screen.title = "PAUSED"
			screen.items = [{"label": "Resume", "id": "resume"}, {"label": "Save Game", "id": "save"}, {"label": "Load Game", "id": "load"}, {"label": "Character & Map", "id": "character"},
				{"label": "Options", "id": "options"}, {"label": "Quit to Title", "id": "title"}, {"label": "Exit to Desktop", "id": "exit"}]
		"test":
			screen_back = "title"
			screen.title = "TEST---"
			screen.subtitle = "Scenarios for trying out specific pieces.  Not part of the finished game."
			screen.items = [{"label": "Large City  (3072 x 3072)", "id": "scn:large_city"}, {"label": "Large City  (2560 x 2560)", "id": "scn:city_2560"}, {"label": "Back", "id": "back"}]
		"options":
			screen.title = "OPTIONS"
			_fill_options()
		"visuals":
			screen.title = "VISUALS"
			_fill_visuals()
		"keys":
			screen.title = "KEY BINDINGS"
			screen.subtitle = "Enter on an action, then press the new key.  Esc cancels."
			_fill_keys()
		"saves", "loads":
			screen.title = "SAVE GAME" if kind == "saves" else "LOAD GAME"
			_fill_slots()
		"create":
			screen.overlay = false
			screen.cc = cc
			screen.cc_sel = cc_sel
			screen.cc_tileset = cc_tileset
		"terminal":
			screen.overlay = true
			screen.tm = tm
	_scroll_fix()

## bumping a mission terminal: its board (kept per terminal: free first batch, free each new day, ¥100 on demand, free when all five are done)
func open_terminal(cell: int) -> void:
	var b: Dictionary = game.board_open(cell)
	tm = {"cell": cell, "sel": 0, "msg": "", "foc": 0, "sw_sel": 0}
	_tm_sync()
	game.terminal_hit = -1
	open_screen("terminal")
	sfx.play("select")

## the terminal's view of the board it stands at (call again after anything changes it)
func _tm_sync() -> void:
	var b: Dictionary = game.board_open(int(tm["cell"]))
	tm["offers"] = b["offers"]
	tm["sw"] = b["sw"]
	tm["used"] = b["used"]
	tm["gen"] = int(b["gen"])
	tm["day"] = int(b["day"])
	tm["sel"] = clampi(int(tm.get("sel", 0)), 0, maxi(0, b["offers"].size() - 1))

func _tm_set_switch(si: int, v: int) -> void:
	var b: Dictionary = game.board_open(int(tm["cell"]))
	if int(b["sw"][si]) == v:
		return
	b["sw"][si] = v
	tm["sw_sel"] = si
	_tm_sync()
	tm["msg"] = "%s: %s.  Applies to the next batch (R, ¥%d)." % [String(MS.SWITCHES[si]["name"]).capitalize(), MS.switch_label(si, v), MS.NEW_BATCH_COST]
	sfx.play("blip")

func _tm_regen() -> void:
	if game.board_regen(int(tm["cell"])):
		tm["sel"] = 0
		_tm_sync()
		tm["msg"] = "A new batch is posted.  ¥%d paid." % MS.NEW_BATCH_COST
	else:
		tm["msg"] = "A new batch costs ¥%d, and you have ¥%d." % [MS.NEW_BATCH_COST, game.yen]
		sfx.play("blip")

func _tm_accept() -> void:
	var o: Dictionary = tm["offers"][int(tm["sel"])]
	if not game.portal.is_empty():
		tm["msg"] = "A portal is already open.  Finish that contract, or press C to scrap it."
		sfx.play("blip")
	elif game.portal_open(o, int(tm["cell"])):
		resume_play()
	else:
		tm["msg"] = "That contract is already done." if game.done_contracts.has(String(o["id"])) else "No room for a portal beside this terminal."
		sfx.play("blip")

func _terminal_key(k: int) -> void:
	var n: int = tm["offers"].size()
	var foc: int = int(tm.get("foc", 0))
	if k == KEY_ESCAPE or k == KEY_E:
		resume_play()
	elif k == KEY_TAB:
		tm["foc"] = 1 - foc
		sfx.play("blip")
	elif k == KEY_UP or k == KEY_K or settings.action_for(k) == "north":
		if foc == 0:
			tm["sel"] = (int(tm["sel"]) + n - 1) % n
		else:
			tm["sw_sel"] = (int(tm["sw_sel"]) + 3) % 4
		tm["msg"] = ""
		sfx.play("blip")
	elif k == KEY_DOWN or k == KEY_J or settings.action_for(k) == "south":
		if foc == 0:
			tm["sel"] = (int(tm["sel"]) + 1) % n
		else:
			tm["sw_sel"] = (int(tm["sw_sel"]) + 1) % 4
		tm["msg"] = ""
		sfx.play("blip")
	elif k == KEY_LEFT or k == KEY_RIGHT or k == KEY_H or k == KEY_L or settings.action_for(k) == "west" or settings.action_for(k) == "east":
		var right: bool = k == KEY_RIGHT or k == KEY_L or settings.action_for(k) == "east"
		var si: int = int(tm["sw_sel"])
		var cur: int = int(tm["sw"][si])
		_tm_set_switch(si, clampi(cur + (1 if right else -1), 0, 2))
	elif k >= KEY_1 and k < KEY_1 + n:
		tm["sel"] = k - KEY_1
		tm["foc"] = 0
		tm["msg"] = ""
		sfx.play("blip")
	elif k == KEY_R:
		_tm_regen()
	elif k == KEY_C:
		if game.portal.is_empty():
			tm["msg"] = "No portal is open."
		else:
			game.portal_close()
			game.say("You scrap the contract at the terminal.  The portal collapses.")
			tm["msg"] = "Contract scrapped.  The portal is closed."
			sfx.play("blip")
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		_tm_accept()

func _term_mouse(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h: Dictionary = screen.tm_hit(ev.position / UI_S)
		if h.get("kind", "") == "row" and int(h["i"]) != int(tm["sel"]):
			tm["sel"] = int(h["i"])
			tm["foc"] = 0
			sfx.play("blip")
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			resume_play()
			return
		if ev.button_index != MOUSE_BUTTON_LEFT:
			return
		var h: Dictionary = screen.tm_hit(ev.position / UI_S)
		match String(h.get("kind", "")):
			"row":
				tm["sel"] = int(h["i"])
				tm["foc"] = 0
				if ev.double_click:
					_tm_accept()
			"switch":
				tm["foc"] = 1
				tm["sw_sel"] = int(h["i"])
				if int(h["v"]) >= 0:
					_tm_set_switch(int(h["i"]), int(h["v"]))
			"regen":
				_tm_regen()
			"accept":
				_tm_accept()

## the player stepped into an open portal, or out through a site's exit: hand over to the world, which swaps the game
func _mission_transfer() -> void:
	var entering: bool = game.mission_enter_request
	var forced: String = game.mission_leave_request
	game.mission_enter_request = false
	game.mission_leave_request = ""
	if entering:
		if not world.enter_mission():
			return
	elif world.leave_mission("blast" if forced == "blast" else "").is_empty():
		return
	game = world.game
	view.game = game
	screen.game = game
	sfx.play("select")

func _make_map() -> void:
	if world == null:
		screen.map_tex = null
		return
	if map_tex == null or map_seed != world.seed_value:
		map_tex = ImageTexture.create_from_image(world.island.overview_image(8))
		map_seed = world.seed_value
	screen.map_tex = map_tex

func _fill_options() -> void:
	screen.items = [
		{"label": "Sound", "value": "ON" if settings.sound_on else "OFF", "id": "sound"},
		{"label": "Volume", "value": "%d%%" % int(settings.volume * 100.0), "id": "volume"},
		{"label": "Tileset", "value": TILESETS[ts_index].replace("_TopDown", ""), "id": "tileset"},
		{"label": "Toggle view changes with move direction", "value": "ON" if settings.view_follows_move else "OFF", "id": "vfm"},
		{"label": "Visuals...", "id": "visuals"},
		{"label": "Key bindings...", "id": "keys"},
		{"label": "Back", "id": "back"}]
	screen.footer = "Left / Right changes a value  -  Enter selects  -  Esc goes back"

func _fill_visuals() -> void:
	screen.items = [
		{"label": "Display mode", "value": settings.WINDOW_MODES[settings.window_mode], "id": "wmode"},
		{"label": "Window size", "value": settings.resolution_text() + ("" if settings.window_mode == 0 else "  (used when windowed)"), "id": "res"},
		{"label": "Day / night light", "value": "on" if settings.lighting else "off", "id": "lighting"},
		{"label": "Weather effects", "value": "on" if settings.weather_fx else "off", "id": "weatherfx"},
		{"label": "Back", "id": "back"}]
	screen.footer = "Left / Right changes a value  -  Alt+Enter or F11 toggles fullscreen  -  Esc goes back"

func _fill_keys() -> void:
	var items := []
	for a in settings.ACTIONS:
		items.append({"label": a[1], "value": settings.key_text(a[0]), "id": "key:" + a[0]})
	items.append({"label": "Reset all to defaults", "id": "keys_reset"})
	items.append({"label": "Back", "id": "back"})
	screen.items = items

func _fill_slots() -> void:
	var items := []
	for n in range(1, SLOTS + 1):
		var meta := slot_meta(n)
		items.append({"label": "Slot %d" % n, "value": meta, "id": "slot:%d" % n, "disabled": (screen.kind == "loads" and meta == "(empty)")})
	items.append({"label": "Back", "id": "back"})
	screen.items = items
	screen.footer = "Enter picks a slot  -  Esc goes back"

func _scroll_fix() -> void:
	var rows := 14
	screen.sel = clampi(screen.sel, 0, maxi(0, screen.items.size() - 1))
	if screen.sel < screen.scroll:
		screen.scroll = screen.sel
	if screen.sel >= screen.scroll + rows:
		screen.scroll = screen.sel - rows + 1

func back_from_screen() -> void:
	match mode:
		"options", "visuals", "keys", "saves", "loads":
			if mode == "keys" and screen_back == "play":
				resume_play()
				return
			var prev := "options" if (mode == "keys" or mode == "visuals") else screen_back
			if prev == "pause" and game != null:
				open_screen("pause")
			elif prev == "options":
				open_screen("options")
			else:
				open_screen("title")
		"create", "test":
			open_screen("title")
		"equipment", "implants", "skills", "map":
			gear.close()
			if tab_from == "pause" and game != null:
				open_screen("pause")
			else:
				resume_play()
		"terminal", "elevator":
			resume_play()
		"pause":
			resume_play()
		"title":
			pass

func resume_play() -> void:
	mode = "play"
	screen.visible = false
	refresh()

func activate(id: String) -> void:
	sfx.play("select")
	if id.begins_with("key:"):
		rebinding = id.substr(4)
		screen.prompt = "Press a key for  %s" % settings.label(rebinding)
		return
	if id.begins_with("slot:"):
		var n := int(id.substr(5))
		if mode == "saves":
			if save_slot(n):
				game.say("Game saved (slot %d)." % n)
			_fill_slots()
			screen.footer = "Saved to slot %d." % n
		elif mode == "loads":
			begin_load(n)
		return
	if id.begins_with("scn:"):
		begin_scenario(id.substr(4))
		return
	match id:
		"new": open_creation()
		"test": open_screen("test")
		"load":
			screen_back = "pause" if mode == "pause" else "title"
			open_screen("loads")
		"save":
			screen_back = "pause"
			open_screen("saves")
		"options":
			screen_back = "pause" if mode == "pause" else "title"
			open_screen("options")
		"vfm":
			settings.view_follows_move = not settings.view_follows_move
			settings.save()
			_fill_options()
		"lighting":
			settings.lighting = not settings.lighting
			settings.save()
			_view_flags()
			_fill_visuals()
		"weatherfx":
			settings.weather_fx = not settings.weather_fx
			settings.save()
			_view_flags()
			_fill_visuals()
		"keys": open_screen("keys")
		"visuals": open_screen("visuals")
		"wmode":
			settings.window_mode = (settings.window_mode + 1) % settings.WINDOW_MODES.size()
			settings.save()
			apply_window()
			_fill_visuals()
		"res":
			var before: Vector2i = settings.resolution
			settings.step_resolution(1)
			if settings.resolution == before:
				settings.resolution = settings.RESOLUTIONS[0]
			settings.save()
			apply_window()
			_fill_visuals()
		"character":
			tab_from = "pause"
			open_tab("equipment")
		"resume": resume_play()
		"title":
			game = null
			world = null
			screen_back = "title"
			for c in play_nodes:
				if is_instance_valid(c):
					c.queue_free()
			play_nodes = []
			open_screen("title")
		"exit": get_tree().quit()
		"back": back_from_screen()
		"sound":
			settings.sound_on = not settings.sound_on
			apply_audio()
			settings.save()
			_fill_options()
		"tileset": _cycle_tileset(1)
		"keys_reset":
			settings.reset_keys()
			settings.save()
			_fill_keys()

## the chosen tileset (the first one if it cannot be loaded)
func _load_tileset() -> void:
	tileset.fallback = null
	if not tileset.load_dir("res://gfx/" + TILESETS[ts_index]):
		tileset.load_dir("res://gfx/" + TILESETS[0])

func _cycle_tileset(dir: int) -> void:
	ts_index = (ts_index + dir + TILESETS.size()) % TILESETS.size()
	settings.tileset = ts_index
	settings.save()
	if tileset != null:
		tileset.clear()
		_load_tileset()
	_fill_options()

## New Game: the creation screen first; Begin builds the world and applies the choices
func open_creation() -> void:
	cc = CR.new_profile()
	cc_sel = 0
	if cc_tileset == null:
		cc_tileset = TilesetScript.new()
		if not cc_tileset.load_dir("res://gfx/" + TILESETS[ts_index]):
			cc_tileset.load_dir("res://gfx/" + TILESETS[0])
	open_screen("create")

## rows of the creation screen: the name, appearance, attributes, Randomize, Begin, Back
func cc_rows() -> Array:
	var rows: Array = [{"kind": "name", "id": "name"}]
	for r in CR.LOOK_ROWS:
		rows.append({"kind": "look", "id": r["id"]})
	for a in SK.ATTRS:
		rows.append({"kind": "attr", "id": a["id"]})
	rows.append({"kind": "random", "id": "random"})
	rows.append({"kind": "begin", "id": "begin"})
	rows.append({"kind": "back", "id": "back"})
	return rows

func _cc_sync() -> void:
	screen.cc = cc
	screen.cc_sel = cc_sel

## change the highlighted row one step (dir -1 / +1): an appearance row steps its option, an attribute row moves a point
func cc_step(dir: int) -> void:
	var row: Dictionary = cc_rows()[cc_sel]
	if row["kind"] == "name" or row["kind"] == "random" or row["kind"] == "begin" or row["kind"] == "back":
		return
	if row["kind"] == "look":
		cc["app"] = CR.cycle(cc["app"], row["id"], dir)
		sfx.play("blip")
	elif row["kind"] == "attr":
		var before: Dictionary = cc["attrs"]
		cc["attrs"] = CR.change(before, row["id"], dir)
		if cc["attrs"] == before:
			screen.prompt = "%s cannot go %s: %s" % [SK.attr(row["id"])["name"], "up" if dir > 0 else "down", ("no free points (lower another attribute first)" if (dir > 0 and int(before[row["id"]]) < CR.ATTR_MAX) else ("it is at %d" % (CR.ATTR_MAX if dir > 0 else CR.ATTR_MIN)))]
			sfx.play("hit")
		else:
			screen.prompt = ""
			sfx.play("blip")
	_cc_sync()

## the Randomize button: new appearance and attributes (the name stays), a fresh roll each press
func cc_randomize() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	cc = CR.randomized(r, cc)
	screen.prompt = "Randomized.  Change anything you like, or press Randomize again."
	sfx.play("pick")
	_cc_sync()

## the name row takes typed text: letters, digits, spaces and punctuation add, Backspace deletes
func cc_type(k: int, uc: int) -> bool:
	var s: String = String(cc.get("name", ""))
	if k == KEY_BACKSPACE:
		cc["name"] = s.substr(0, maxi(0, s.length() - 1))
		return true
	if uc >= 32 and uc < 127 and s.length() < CR.NAME_MAX:
		cc["name"] = s + char(uc)
		return true
	return uc >= 32 and uc < 127

func cc_begin() -> void:
	if not CR.profile_valid(cc):
		screen.prompt = "Spend your %d free point%s first." % [CR.free_points(cc["attrs"]), "" if CR.free_points(cc["attrs"]) == 1 else "s"]
		sfx.play("hit")
		return
	begin_new(int(Time.get_unix_time_from_system()) % 100000, cc)

func _cc_key(k: int) -> void:
	var n: int = cc_rows().size()
	var act: String = settings.action_for(k)
	if cc_rows()[cc_sel]["kind"] == "name" and k != KEY_ESCAPE and k != KEY_UP and k != KEY_DOWN and k != KEY_TAB and k != KEY_ENTER and k != KEY_KP_ENTER and cc_type(k, key_unicode):
		screen.prompt = ""
		_cc_sync()
		return
	if k == KEY_ESCAPE:
		back_from_screen()
	elif k == KEY_UP or k == KEY_K or act == "north":
		cc_sel = (cc_sel + n - 1) % n
		screen.prompt = ""
		sfx.play("blip")
	elif k == KEY_DOWN or k == KEY_J or act == "south":
		cc_sel = (cc_sel + 1) % n
		screen.prompt = ""
		sfx.play("blip")
	elif k == KEY_TAB:
		# jump between the appearance block, the attributes and the buttons
		var nl: int = 1 + CR.LOOK_ROWS.size()
		var na: int = SK.ATTRS.size()
		cc_sel = nl if cc_sel < nl else (nl + na if cc_sel < nl + na else 0)
		sfx.play("blip")
	elif k == KEY_LEFT or k == KEY_H or act == "west" or k == KEY_MINUS or k == KEY_KP_SUBTRACT:
		cc_step(-1)
	elif k == KEY_RIGHT or k == KEY_L or act == "east" or k == KEY_EQUAL or k == KEY_KP_ADD:
		cc_step(1)
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		var kind: String = cc_rows()[cc_sel]["kind"]
		if kind == "begin":
			cc_begin()
		elif kind == "back":
			back_from_screen()
		elif kind == "random":
			cc_randomize()
		elif kind == "name":
			cc_sel = 1
		else:
			cc_step(1)
	_cc_sync()

## open a tab of the paused character screens
## the barter screen with merchant `who` (vendors, grocers, ripperdocs, doctors); the text menu stays for everybody else
func open_barter(who: int) -> void:
	_gear_icons()
	var m: Dictionary = game.eco.menu_for(who)
	bt.open(game, gear_items, who, m)
	mode = "barter"
	screen.kind = "barter"
	screen.visible = true
	screen.overlay = false
	screen.prompt = ""
	screen.game = game
	screen.bt = bt
	panel.visible = false

func _barter_key(k: int) -> void:
	if k == KEY_ESCAPE:
		if bt.cancel():
			return
		bt.close()
		resume_play()
		return
	var act: String = settings.action_for(k)
	var dv := Vector2i.ZERO
	match act:
		"north": dv = Vector2i(0, -1)
		"south": dv = Vector2i(0, 1)
		"west": dv = Vector2i(-1, 0)
		"east": dv = Vector2i(1, 0)
		"nw": dv = Vector2i(-1, -1)
		"ne": dv = Vector2i(1, -1)
		"sw": dv = Vector2i(-1, 1)
		"se": dv = Vector2i(1, 1)
	match k:
		KEY_KP_7: dv = Vector2i(-1, -1)
		KEY_KP_9: dv = Vector2i(1, -1)
		KEY_KP_1: dv = Vector2i(-1, 1)
		KEY_KP_3: dv = Vector2i(1, 1)
		KEY_UP: dv = Vector2i(0, -1)
		KEY_DOWN: dv = Vector2i(0, 1)
		KEY_LEFT: dv = Vector2i(-1, 0)
		KEY_RIGHT: dv = Vector2i(1, 0)
	if dv != Vector2i.ZERO:
		if bt.move(dv):
			sfx.play("blip")
	elif k == KEY_CTRL:
		bt.auto()
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		if Input.is_key_pressed(KEY_CTRL):
			bt.auto()
		else:
			bt.press(ev_shift())
	if game != null:
		view.queue_redraw()

func ev_shift() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)

func _barter_mouse(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		if bt.hover(ev.position / UI_S):
			sfx.play("blip")
		return
	if not (ev is InputEventMouseButton) or not ev.pressed:
		return
	var pos: Vector2 = ev.position / UI_S
	if ev.button_index == MOUSE_BUTTON_LEFT:
		bt.click(pos, false, ev.shift_pressed)
	elif ev.button_index == MOUSE_BUTTON_RIGHT:
		bt.click(pos, true)
	elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
		bt.scroll(-1, pos)
	elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		bt.scroll(1, pos)

func open_tab(kind: String, from: String = "") -> void:
	if from != "":
		tab_from = from
	gear.close()
	var was_tab: bool = mode in TAB_MODES
	mode = kind
	screen.kind = kind
	screen.visible = true
	screen.overlay = false
	screen.prompt = ""
	screen.game = game
	screen.gear = gear
	var keys := {}
	for pair in [["equipment", "inventory"], ["implants", "implants"], ["skills", "skills"], ["map", "map"]]:
		var ks: Array = settings.binds.get(pair[1], [])
		keys[pair[0]] = OS.get_keycode_string(ks[0]) if not ks.is_empty() else ""
	screen.tab_keys = keys
	match kind:
		"equipment", "implants":
			_gear_icons()
			gear.open(game, gear_items, kind)
		"skills":
			if not was_tab:
				screen.sk_sel = 0
		"map":
			screen.world = world
			_make_map()
			screen.map_pan = Vector2i.ZERO
			_make_local_map()

## item icons for the equipment tabs: the item set, then the Trilobit64 set, then whatever tileset is loaded
func _gear_icons() -> void:
	if gear_base == null:
		gear_base = TilesetScript.new()
		gear_base.load_dir("res://gfx/Trilobit64")
		gear_items = TilesetScript.new()
		if gear_items.load_dir("res://gfx/tiles_items"):
			for k in gear_items.index.keys():                  # (the Trilobit set has the real icons for implants and nanohack chips; the items set only holds grey stand-ins)
				if String(k).begins_with("trl_imp_") or String(k).begins_with("trl_nano_"):
					gear_items.index.erase(k)
			gear_items.fallback = gear_base
		else:
			gear_items = gear_base
	gear_base.fallback = tileset

## step to the next (dir = 1) or previous tab
func step_tab(dir: int) -> void:
	var i: int = TAB_MODES.find(mode)
	open_tab(TAB_MODES[(i + dir + TAB_MODES.size()) % TAB_MODES.size()])
	sfx.play("blip")

const LOCAL_R := 190                  # the local map is charted this far round you (the screen shows 141 x 141 of it and scrolls)
const LOCAL_VIEW_R := 70

## the colour of a map tile on the local map (transparent: not drawn)
func _local_color(t: int) -> Color:
	var CG = preload("res://src/citygen.gd")
	if t == 7:
		return Color(0, 0, 0, 0)
	if t == 2 or t == 17 or t == 27 or t == 28:
		return Color(1.0, 0.25, 0.65)
	if t == 10 or t == 20 or t == CG.TID["window_broken"]:
		return Color(0.55, 0.9, 1.0)
	if t == 4 or t == 22 or t == CG.TID["door_closed"]:
		return Color(1.0, 0.8, 0.25)
	if t == 8 or t == 9 or t == 19:
		return Color(1.0, 0.65, 0.1)
	if t == 1 or t == 14:
		return Color(0.1, 0.14, 0.32)
	if t == 0 or t == 13 or t == 26:
		return Color(0.24, 0.3, 0.5)
	if t == 5 or t == 16:
		return Color(0.05, 0.12, 0.5)
	if t == 6 or t == 31 or t == 32 or t == 29:
		return Color(0.06, 0.3, 0.26) if t != 29 else Color(0.08, 0.45, 0.36)
	if t == 23 or t == 24 or t == 25 or t == 21:
		return Color(0.62, 0.68, 0.8)
	if t >= CG.EXTRA0:
		return Color(0.62, 0.68, 0.8) if int(CG.WALK[t]) == 0 else Color(0.07, 0.2, 0.28)
	return Color(0.07, 0.2, 0.28)

const MINI_RX := 31                    # tiles either side of you across the minimap, and
const MINI_RY := 19                    # up and down: 63 x 39 tiles, drawn 4 HUD units to the tile (as wide as the HUD bar)

## the minimap (bottom right of the HUD, under the HUD bar and as wide): a Trilobit, fitted and powered, charts the tiles round you; the message log gives up the space it uses
func _make_mini() -> void:
	var g = game
	var on: bool = g != null and g.nano_ok()
	view.mini_on = on
	logbox.size.x = 1264.0 - (268.0 if on else 0.0)
	if log_bg != null:
		log_bg.size.x = 1028.0 if on else 1280.0          # the message backdrop must not dim the minimap
	if not on:
		view.mini_tex = null
		return
	var nx: int = MINI_RX * 2 + 1
	var ny: int = MINI_RY * 2 + 1
	var img := Image.create(nx, ny, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.09, 0.16))
	var base: int = (g.pc / g.s2) * g.s2
	var px: int = g.lx(g.pc)
	var py: int = g.ly(g.pc)
	for dy in range(-MINI_RY, MINI_RY + 1):
		var y: int = py + dy
		if y < 0 or y >= g.size:
			continue
		for dx in range(-MINI_RX, MINI_RX + 1):
			var x: int = px + dx
			if x < 0 or x >= g.size:
				continue
			var c: int = base + y * g.size + x
			if g.fov.explored[c] == 0:
				continue
			var col: Color = _local_color(g.city.tiles[c])
			if col.a > 0.0:
				col = Color(minf(1.0, col.r * 2.3 + 0.16), minf(1.0, col.g * 2.3 + 0.16), minf(1.0, col.b * 2.3 + 0.16))
				img.set_pixel(dx + MINI_RX, dy + MINI_RY, col if g.fov.visible[c] == 1 else col * Color(0.75, 0.75, 0.75))
	for k in g.sim.near_list.size():                                  # people you can see
		var pi: int = g.sim.near_list[k]
		var pc2: int = g.sim.pos[pi]
		if pc2 / g.s2 != base / g.s2 or g.fov.visible[pc2] == 0:
			continue
		var ex: int = pc2 % g.size - px + MINI_RX
		var ey: int = (pc2 / g.size) % g.size - py + MINI_RY
		if ex >= 0 and ey >= 0 and ex < nx and ey < ny:
			img.set_pixel(ex, ey, Color(1.0, 0.9, 0.2))
	img.set_pixel(MINI_RX, MINI_RY, Color.WHITE)
	view.mini_tex = ImageTexture.create_from_image(img)

func _pan_local(d: Vector2i) -> void:
	var lim: int = LOCAL_R - LOCAL_VIEW_R
	screen.map_pan = Vector2i(clampi(screen.map_pan.x + d.x, -lim, lim), clampi(screen.map_pan.y + d.y, -lim, lim))
	sfx.play("blip")

## the picture of everything seen within LOCAL_R tiles of the player on this level
func _make_local_map() -> void:
	var g = game
	var n: int = LOCAL_R * 2 + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.02, 0.03, 0.06))
	if g != null:
		var base: int = (g.pc / g.s2) * g.s2
		var px: int = g.lx(g.pc)
		var py: int = g.ly(g.pc)
		for dy in range(-LOCAL_R, LOCAL_R + 1):
			var y: int = py + dy
			if y < 0 or y >= g.size:
				continue
			for dx in range(-LOCAL_R, LOCAL_R + 1):
				var x: int = px + dx
				if x < 0 or x >= g.size:
					continue
				var c: int = base + y * g.size + x
				if g.fov.explored[c] == 0:
					continue
				var col: Color = _local_color(g.city.tiles[c])
				if col.a > 0.0:
					img.set_pixel(dx + LOCAL_R, dy + LOCAL_R, col)
	screen.local_tex = ImageTexture.create_from_image(img)
	var gp: Vector2i = g.global_pos() if g != null and g.island != null else Vector2i(g.lx(g.pc), g.ly(g.pc))
	screen.local_info = {"n": LOCAL_VIEW_R * 2 + 1, "full": n, "level": g.z_of(g.pc) if g != null else 0, "gx": gp.x, "gy": gp.y, "labels": local_labels(), "labor": nearest_labor_text()}

## the Labor Centers are public knowledge: the map says where the nearest one is, seen or not
func nearest_labor_text() -> String:
	return nearest_business_text("labor_center", "Labor Center")

func nearest_business_text(btype: String, label: String) -> String:
	var g = game
	if g == null or g.city == null or g.city.businesses.is_empty():
		return ""
	var px: int = g.lx(g.pc)
	var py: int = g.ly(g.pc)
	var best: Dictionary = {}
	var bd := 1 << 30
	for b in g.city.businesses:
		if b["type"] != btype:
			continue
		var d: int = absi(int(b["door"].x) - px) + absi(int(b["door"].y) - py)
		if d < bd:
			bd = d
			best = b
	if best.is_empty():
		return "No %s in this district." % label
	var dx: int = int(best["door"].x) - px
	var dy: int = int(best["door"].y) - py
	var ew: String = "" if dx == 0 else "%d %s" % [absi(dx), "east" if dx > 0 else "west"]
	var ns: String = "" if dy == 0 else "%d %s" % [absi(dy), "south" if dy > 0 else "north"]
	return "Nearest %s: %s (%s)." % [label, ", ".join([ew, ns].filter(func(t): return t != "")), String(best.get("name", label))]

## names of buildings to print above their middle tile on the local map: [{dx, dy, text}] relative to the player.  None are named yet.
func local_labels() -> Array:
	var out: Array = []
	var g = game
	if g == null or g.city == null or (g.pc / g.s2) != 0:
		return out
	var SG = preload("res://src/signage.gd")
	var CG = preload("res://src/citygen.gd")
	var px: int = g.lx(g.pc)
	var py: int = g.ly(g.pc)
	for sg in g.city.signs:                                      # one pictogram per building, at its middle, once you have seen its door
		var d: int = int(sg["door"])
		var m: int = int(sg["mid"])
		var dx: int = m % g.size - px
		var dy: int = m / g.size - py
		if absi(dx) > LOCAL_R or absi(dy) > LOCAL_R or g.fov.explored[d] == 0:
			continue
		var kind: String = String(sg["kind"])
		out.append({"dx": dx, "dy": dy, "glyph": sg["glyph"], "col": sg["col"], "small": kind == "house", "text": ""})
	var tt: int = CG.TID["terminal"]
	for dy2 in range(-LOCAL_R, LOCAL_R + 1):                    # the mission terminals
		var y: int = py + dy2
		if y < 0 or y >= g.size:
			continue
		for dx2 in range(-LOCAL_R, LOCAL_R + 1):
			var x: int = px + dx2
			if x < 0 or x >= g.size:
				continue
			var c: int = y * g.size + x
			if g.city.tiles[c] == tt and g.fov.explored[c] == 1:
				out.append({"dx": dx2, "dy": dy2, "glyph": "terminal", "col": SG.COL_TERMINAL, "small": false, "text": ""})
	return out

func _tab_key(k: int) -> void:
	if k == KEY_ESCAPE:
		if (mode == "equipment" or mode == "implants") and gear.cancel():
			return
		back_from_screen()
		return
	if k == KEY_LESS or k == KEY_COMMA or key_unicode == 60:
		step_tab(-1)
		return
	if k == KEY_GREATER or k == KEY_PERIOD or key_unicode == 62:
		step_tab(1)
		return
	var act: String = settings.action_for(k)
	var want := ""
	match act:
		"inventory": want = "equipment"
		"implants": want = "implants"
		"skills": want = "skills"
		"map": want = "map"
	if want != "":
		if want == mode:
			back_from_screen()
		else:
			open_tab(want)
		return
	var dv := Vector2i.ZERO
	match act:
		"north": dv = Vector2i(0, -1)
		"south": dv = Vector2i(0, 1)
		"west": dv = Vector2i(-1, 0)
		"east": dv = Vector2i(1, 0)
	if mode == "skills":
		if k == KEY_TAB:
			dv = Vector2i(1, 0)
		if dv != Vector2i.ZERO and screen.sk_move(dv):
			sfx.play("blip")
		elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			_spend_selected()
		return
	if mode == "map":
		if k == KEY_TAB or k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			screen.map_local = not screen.map_local
			sfx.play("blip")
		elif screen.map_local:
			var pd: Vector2i = dir_of(k)
			if k == KEY_HOME or k == KEY_5 or k == KEY_KP_5:
				screen.map_pan = Vector2i.ZERO
				sfx.play("blip")
			elif k == KEY_UP:
				pd = Vector2i(0, -1)
			elif k == KEY_DOWN:
				pd = Vector2i(0, 1)
			elif k == KEY_LEFT:
				pd = Vector2i(-1, 0)
			elif k == KEY_RIGHT:
				pd = Vector2i(1, 0)
			if pd != Vector2i.ZERO:
				_pan_local(pd * (40 if Input.is_key_pressed(KEY_SHIFT) else 10))
		return
	# equipment and implants
	if dv != Vector2i.ZERO:
		if gear.move(dv):
			sfx.play("blip")
	elif k == KEY_CTRL:
		gear.auto()
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		if Input.is_key_pressed(KEY_CTRL):
			gear.auto()
		else:
			gear.press()
	_after_gear()

## the world around may have changed (a weapon wielded, armor on): redraw it and the HUD
## spend an earned attribute point on the attribute the Attributes & Skills cursor is on
func _spend_selected() -> void:
	if game == null or screen.sk_sel >= SK.ATTRS.size():
		return
	if game.spend_point(SK.ATTRS[screen.sk_sel]["id"]):
		sfx.play("pick")
	else:
		sfx.play("blip")

func _after_gear() -> void:
	if game != null:
		view.queue_redraw()

var map_drag: bool = false
var map_drag_acc: Vector2 = Vector2.ZERO

func _tab_mouse(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		map_drag = false
	if ev is InputEventMouseMotion and map_drag and mode == "map" and screen.map_local:
		map_drag_acc -= ev.relative / UI_S / maxf(1.0, screen.map_lpx)         # the map follows the cursor
		var step := Vector2i(int(map_drag_acc.x), int(map_drag_acc.y))
		if step != Vector2i.ZERO:
			map_drag_acc -= Vector2(step)
			var lim: int = LOCAL_R - LOCAL_VIEW_R
			screen.map_pan = Vector2i(clampi(screen.map_pan.x + step.x, -lim, lim), clampi(screen.map_pan.y + step.y, -lim, lim))
		return
	if ev is InputEventMouseMotion:
		var p: Vector2 = ev.position / UI_S
		if mode == "skills":
			var si: int = screen.sk_at_mouse(p)
			if si >= 0 and si != screen.sk_sel:
				screen.sk_sel = si
				sfx.play("blip")
		elif mode == "equipment" or mode == "implants":
			if gear.hover(p):
				sfx.play("blip")
		return
	if not (ev is InputEventMouseButton) or not ev.pressed:
		return
	var pos: Vector2 = ev.position / UI_S
	if mode == "map" and screen.map_local and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		return                                                  # (the wheel no longer scrolls the local map: click and drag)
	if ev.button_index == MOUSE_BUTTON_LEFT:
		if mode == "map" and screen.map_local and screen.tab_at(pos) == -9 and screen.map_button_at(pos) < 0:
			map_drag = true
			map_drag_acc = Vector2.ZERO
			return
		var ti: int = screen.tab_at(pos)
		if ti >= 0:
			if screen.TAB_KINDS[ti] != mode:
				open_tab(screen.TAB_KINDS[ti])
				sfx.play("blip")
			return
		if ti == -1 or ti == -2:
			step_tab(-1 if ti == -1 else 1)
			return
		if mode == "skills":
			var si: int = screen.sk_at_mouse(pos)
			if si >= 0:
				screen.sk_sel = si
				_spend_selected()
		elif mode == "map":
			var b: int = screen.map_button_at(pos)
			if b >= 0:
				screen.map_local = b == 1
				sfx.play("blip")
		elif mode == "equipment" or mode == "implants":
			gear.click(pos, false, ev.alt_pressed)
			_after_gear()
	elif ev.button_index == MOUSE_BUTTON_RIGHT:
		if mode == "equipment" or mode == "implants":
			gear.click(pos, true)
			_after_gear()
		else:
			back_from_screen()

func screen_key(k: int) -> void:
	# waiting for a new key binding
	if rebinding != "":
		if k != KEY_ESCAPE:
			settings.rebind(rebinding, k)
			settings.save()
			sfx.play("pick")
		rebinding = ""
		screen.prompt = ""
		var keep: int = screen.sel
		var sc: int = screen.scroll
		_fill_keys()
		screen.sel = keep
		screen.scroll = sc
		return
	if mode in TAB_MODES:
		_tab_key(k)
		return
	if mode == "barter":
		_barter_key(k)
		return
	if mode == "create":
		_cc_key(k)
		return
	if mode == "terminal":
		_terminal_key(k)
		return
	if mode == "elevator":
		_elevator_key(k)
		return
	match k:
		KEY_ESCAPE:
			if mode != "title":
				back_from_screen()
		KEY_UP, KEY_K:
			screen.sel = (screen.sel + screen.items.size() - 1) % screen.items.size()
			sfx.play("blip")
		KEY_DOWN, KEY_J:
			screen.sel = (screen.sel + 1) % screen.items.size()
			sfx.play("blip")
		KEY_LEFT, KEY_RIGHT, KEY_H, KEY_L:
			var step: int = -1 if (k == KEY_LEFT or k == KEY_H) else 1
			var id: String = screen.items[screen.sel].get("id", "")
			if id == "volume":
				settings.volume = clampf(settings.volume + 0.1 * step, 0.0, 1.0)
				apply_audio()
				settings.save()
				_fill_options()
				sfx.play("shot")
			elif id == "sound":
				activate("sound")
			elif id == "vfm" or id == "lighting" or id == "weatherfx":
				activate(id)
			elif id == "tileset":
				_cycle_tileset(step)
			elif id == "wmode":
				settings.window_mode = (settings.window_mode + step + settings.WINDOW_MODES.size()) % settings.WINDOW_MODES.size()
				settings.save()
				apply_window()
				_fill_visuals()
				sfx.play("blip")
			elif id == "res":
				settings.step_resolution(step)
				settings.save()
				apply_window()
				_fill_visuals()
				sfx.play("blip")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var it: Dictionary = screen.items[screen.sel]
			if not it.get("disabled", false):
				activate(it["id"])
	_scroll_fix()

func _cc_mouse(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h: Dictionary = screen.cc_hit(ev.position / UI_S)
		if h["row"] >= 0 and h["row"] != cc_sel:
			cc_sel = h["row"]
			sfx.play("blip")
			_cc_sync()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			back_from_screen()
		elif ev.button_index == MOUSE_BUTTON_LEFT or ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var h: Dictionary = screen.cc_hit(ev.position / UI_S)
			if h["row"] < 0:
				return
			cc_sel = h["row"]
			var kind: String = cc_rows()[cc_sel]["kind"]
			if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
				cc_step(1)
			elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				cc_step(-1)
			elif kind == "begin":
				cc_begin()
			elif kind == "back":
				back_from_screen()
			elif kind == "random":
				cc_randomize()
			elif h["dir"] != 0:
				cc_step(h["dir"])
			_cc_sync()

func _elev_mouse(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h: int = screen.elev_at(ev.position / UI_S)
		if h >= 0 and h != elev_sel:
			elev_sel = h
			sfx.play("blip")
			_elev_sync()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			var h: int = screen.elev_at(ev.position / UI_S)
			if h >= 0:
				elev_sel = h
				_elev_ride()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			resume_play()

func _unhandled_input(ev: InputEvent) -> void:
	if mode in TAB_MODES:
		_tab_mouse(ev)
		return
	if mode == "barter":
		_barter_mouse(ev)
		return
	if mode == "create":
		_cc_mouse(ev)
		return
	if mode == "elevator":
		_elev_mouse(ev)
		return
	if mode == "terminal":
		_term_mouse(ev)
		return
	if not (mode in MOUSE_MODES):
		return
	# menus: hover highlights, left click chooses, right click goes back, wheel scrolls
	if ev is InputEventMouseMotion and rebinding == "":
		var h: int = screen.item_at_mouse(ev.position / UI_S)
		if h >= 0 and h != screen.sel:
			screen.sel = h
			sfx.play("blip")
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if rebinding == "":
				var h: int = screen.item_at_mouse(ev.position / UI_S)
				if h >= 0:
					screen.sel = h
					var it: Dictionary = screen.items[h]
					if it.get("disabled", false):
						return
					if it.get("id", "") == "volume":
						settings.volume = snappedf(settings.volume + 0.1, 0.1) if settings.volume < 0.95 else 0.0
						apply_audio()
						settings.save()
						_fill_options()
						sfx.play("shot")
					else:
						activate(it["id"])
		elif ev.button_index == MOUSE_BUTTON_RIGHT and mode != "title" and rebinding == "":
			back_from_screen()
		elif (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN) and screen.items.size() > 0:
			var d: int = -1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			screen.sel = clampi(screen.sel + d, 0, screen.items.size() - 1)
			_scroll_fix()
			sfx.play("blip")

## a wait under way: spend turns for a few milliseconds a frame so the screen stays alive and Esc can stop it
func _process(_delta: float) -> void:
	if mode != "waiting" or game == null:
		return
	var t0: int = Time.get_ticks_usec()
	while game.waiting() and Time.get_ticks_usec() - t0 < 12000:
		game.wait_step(8)
	if not game.waiting():
		mode = "play"
		refresh()
		return
	refresh()
	var done: int = game.wait_total - game.wait_left
	logbox.text = "Waiting...  %d%%   (%s of %s)   it is %s     [any key stops]" % [100 * done / maxi(1, game.wait_total), CLK.span_text(done), CLK.span_text(game.wait_total), game.time_text()]

func refresh() -> void:
	if world != null and world.game == game and world.poll():
		game = world.game
		view.game = game
		screen.game = game
		sfx.play("select")
	elif world != null and world.game == game and (game.mission_enter_request or game.mission_leave_request != ""):
		_mission_transfer()
	view.queue_redraw()
	var g = game
	var extra := ""
	if g.in_vehicle >= 0:
		var vv: Dictionary = g.vehicles[g.in_vehicle]
		extra = "  [%s  batt %d%%  speed %s  %s%s]" % [g.vs.KINDS[vv["kind"]]["name"].to_upper(), vv["charge"], ("%d km/h" % g.vs.kph(vv)) if g.vs.is_g8(String(vv["kind"])) else str(absi(int(vv["spd"]))), g.vs.status_text(g.in_vehicle), "  AIRBORNE" if g.airborne() else ""]
	if g.flying:
		extra += "  [FLYING fuel %d]" % g.fuel
	elif g.has_implant("jets") and g.fuel < g.FUEL_MAX:
		extra += "  [jets %d]" % g.fuel
	if view.focus_cell >= 0:
		var ft: int = g.current_target()
		if ft < 0:
			view.focus_cell = -1
		else:
			view.focus_cell = g.sim.pos[ft]
			extra += "  [VIEW: target]"
	view.hud_extra = extra
	_make_mini()
	var tw: Dictionary = g.tower_at(g.pc) if g.z_of(g.pc) > 0 else {}
	var line2: String = g.eco.status_text()
	if g.transit.active():
		var na: Dictionary = g.transit.next_arrival()
		if g.transit.riding >= 0 or int(na.get("dist", 99)) < 30:
			line2 += "   |   Train: %s %s in %d" % ["boarding at" if na["dwelling"] else "next stop", na["name"], na["turns"]]
	if g.transit.riding >= 0:
		line2 += "   [ON THE TRAIN]"
	var tgt: int = g.current_target()
	if tgt >= 0:
		var cov: int = g.cover_vs(g.pc, g.sim.pos[tgt], false) + int(g.shield_vs(g.pc, g.sim.pos[tgt])["pct"])
		line2 += "   |   Target: %s, %d tiles, %d%%%s" % [g.name_of(tgt), g.cheb(g.sim.pos[tgt], g.pc), g.hit_chance_on(tgt), (" (in cover)" if cov > 0 else "")]
	var jt: String = g.eco.job_text()
	var mt: String = MS.status_text(g)
	if mt == "" and not g.portal.is_empty():
		mt = "Portal open: %s  -  step in to begin" % g.portal["offer"]["title"]
	status.text = line2 + ("\n" + jt if jt != "" else "") + ("\n" + mt if mt != "" else "")
	var lines: Array = g.log.slice(-LOG_LINES)
	logbox.text = "\n".join(lines)
	status.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if g.body.frac("chest") < 0.34 or g.body.frac("head") < 0.34 else Color.WHITE)
	_drain_sfx()
	if mode == "talk":
		show_talk()
	elif mode == "clock":
		show_clock()
	elif mode == "pick":
		show_pick()
	elif mode == "mods":
		show_mods()
	elif mode == "waitmenu":
		show_wait()
	elif mode == "consume":
		show_consume()
	elif mode == "nano":
		show_nano()

## the elevator: a pad of floor buttons (highest at the top), one per floor the shaft serves.  Arrows or the numpad move over it, Enter rides, digits jump to a floor.
func open_elevator() -> void:
	var fl: Array = game.elevator_floors(game.elev_hit)
	game.elev_hit = -1
	fl.reverse()                                       # highest first, as on a real panel
	elev_list = fl
	elev_sel = 0
	for q in fl.size():
		if int(fl[q]["cell"]) == game.pc:
			elev_sel = q
	elev_typed = ""
	open_screen("elevator")
	screen.overlay = true
	_elev_sync()
	sfx.play("select")

func _elev_sync() -> void:
	var here := -1
	for q in elev_list.size():
		if int(elev_list[q]["cell"]) == game.pc:
			here = q
	var labels: Array = []
	for f in elev_list:
		labels.append(game.floor_button(int(f["z"])))
	screen.ev = {"labels": labels, "sel": elev_sel, "here": here, "typed": elev_typed, "name": game.floor_label(game.z_of(game.pc))}

func _elevator_key(k: int) -> void:
	var n: int = elev_list.size()
	var cols: int = screen.elev_cols(n)
	var act: String = settings.action_for(k)
	if k == KEY_ESCAPE:
		resume_play()
		return
	elif k == KEY_UP or act == "north":
		elev_sel = elev_sel - cols if elev_sel - cols >= 0 else elev_sel
	elif k == KEY_DOWN or act == "south":
		elev_sel = elev_sel + cols if elev_sel + cols < n else elev_sel
	elif k == KEY_LEFT or act == "west":
		elev_sel = maxi(0, elev_sel - 1) if elev_sel % cols > 0 else elev_sel
	elif k == KEY_RIGHT or act == "east":
		elev_sel = elev_sel + 1 if (elev_sel % cols < cols - 1 and elev_sel + 1 < n) else elev_sel
	elif k == KEY_HOME:
		elev_sel = 0
	elif k == KEY_END:
		elev_sel = n - 1
	elif k >= KEY_0 and k <= KEY_9 and elev_typed.length() < 2:
		elev_typed += str(k - KEY_0)
		for q in n:
			if int(elev_list[q]["z"]) == int(elev_typed):
				elev_sel = q
	elif k == KEY_BACKSPACE:
		elev_typed = elev_typed.substr(0, maxi(0, elev_typed.length() - 1))
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE or act == "interact":
		_elev_ride()
		return
	else:
		return
	sfx.play("blip")
	_elev_sync()

func _elev_ride() -> void:
	var z: int = int(elev_list[elev_sel]["z"])
	resume_play()
	game.act_elevator_to(z)
	refresh()

## the station clock: the time and the countdown to the next train, live while it is open
func show_clock() -> void:
	var info: Dictionary = game.station_clock_info(clock_cell)
	var t := "[b]STATION CLOCK[/b]   %s   (Esc leaves)\n\n" % info["name"]
	t += "Time now:   %s\n\n" % CLK.text(game.sim.tick)
	if info["dwelling"]:
		t += "A train is at the platform: doors open, boarding now."
	else:
		var turns: int = int(info["turns"])
		var secs: int = turns * CLK.TURN_SEC
		t += "Next train:  %d min %02d s   (%d turns)" % [secs / 60, secs % 60, turns]
	panel.text = t
	panel.visible = true

func show_pick() -> void:
	var t := "[b]Use which?[/b]   (1-9 chooses, Esc cancels)\n\n"
	for k in mini(9, pick_list.size()):
		var it: Dictionary = pick_list[k]
		t += "%d) %s   [color=#8899aa]%s[/color]\n" % [k + 1, it["label"], _dir_word(int(it["cell"]))]
	panel.text = t
	panel.visible = true

## where a cell lies from the player, in words
func _dir_word(c: int) -> String:
	var dx: int = signi(c % game.size - game.pc % game.size)
	var dy: int = signi((c / game.size) % game.size - (game.pc / game.size) % game.size)
	var ns: String = "north" if dy < 0 else ("south" if dy > 0 else "")
	var ew: String = "west" if dx < 0 else ("east" if dx > 0 else "")
	return (ns + ew) if ns + ew != "" else "here"

## switch the camera to the current target (and back): for shooting at someone outside the screen around you
func toggle_target_view() -> void:
	if view.focus_cell >= 0:
		view.focus_cell = -1
		game.say("The view returns to you.")
		return
	var tgt: int = game.current_target()
	if tgt < 0:
		game.say("No target to look at.  [Tab] picks one.")
		return
	view.focus_cell = game.sim.pos[tgt]
	game.say("The view moves to %s.  The same key returns it." % game.name_of(tgt))

func show_talk() -> void:
	var t := "[b]%s[/b]   (1-9 chooses, Esc leaves)   ¥%d\n\n" % [menu["title"], game.yen]
	for line in menu["text"]:
		t += "%s\n" % line
	t += "\n"
	var k := 1
	for o in menu["options"]:
		t += "%d) %s\n" % [k, o["label"]]
		k += 1
	panel.text = t
	panel.visible = true

func show_mods() -> void:
	inv_map.clear()
	var g = game
	var st: Dictionary = g.gun_stats()
	if st.is_empty():
		panel.text = "[b]Gunsmithing[/b]\n\nWield a gun first."
		panel.visible = true
		return
	var t := "[b]%s[/b]  (1-9 removes the mod in that slot, a-z fits a carried mod, Esc closes)\n" % g.wield.def["name"]
	t += GP.stat_line(st, g.aim_rate()) + "\n\n"
	var k := 1
	for slot in st["slots"]:
		var cur := "(empty)"
		for m in g.wield.mods:
			if m.def["mod"]["slot"] == slot:
				cur = m.def["name"] + "  [color=#8899aa]" + m.def.get("desc", "") + "[/color]"
		t += "%d) %-7s %s\n" % [k, slot, cur]
		inv_map[str(k)] = slot
		k += 1
	t += "\n[b]Carried mods[/b]\n"
	var j := 0
	for m in g.mods_carried():
		var key := char(97 + j)
		var fits: bool = g.mod_fits(m)
		t += "%s) %s  [color=#8899aa]%s slot%s[/color]\n" % [key, m.def["name"], m.def["mod"]["slot"], "" if fits else ", does not fit"]
		inv_map[key] = m
		j += 1
	panel.text = t
	panel.visible = true

## the wait menu: fixed spans and "until" times (see clock.gd)
const MOVE_ROWS := ["Crawl   [color=#8899aa](slow, hard to see or hear)[/color]", "Crouch   [color=#8899aa](quiet, steadier aim, cover)[/color]", "Walk", "Run   [color=#8899aa](fast and loud; costs stamina)[/color]"]

func show_move() -> void:
	var t := "[b]Movement[/b]   (1-4 or Up / Down and Enter chooses, Esc leaves)   now: %s\n\n" % ("running" if game.run_mode else game.stance_name())
	for i in MOVE_ROWS.size():
		var line: String = "%d) %s" % [i + 1, MOVE_ROWS[i]]
		t += ("[color=#4de6ff]> %s[/color]\n" % line) if i == menu_sel else ("  %s\n" % line)
	panel.text = t
	panel.visible = true

func choose_move(i: int) -> void:
	game.set_movement(i)
	mode = "play"
	panel.visible = false
	_after_act()

func show_wait() -> void:
	var g = game
	var t := "[b]Wait[/b]   (1-9 or Up / Down and Enter chooses, Esc leaves)   it is %s\n\n" % CLK.text(g.sim.tick)
	var rows: Array = wait_rows()
	for i in rows.size():
		var line := "%d) %s" % [i + 1, rows[i]["label"]]
		if rows[i].has("hour"):
			line += "   [color=#8899aa](%s)[/color]" % CLK.span_text(rows[i]["turns"])
		t += ("[color=#4de6ff]> %s[/color]\n" % line) if i == menu_sel else ("  %s\n" % line)
	t += "\nWaiting stops early if you are hurt, get hungry or thirsty, or a hostile you can see is on to you.  Any key stops a wait under way."
	panel.text = t
	panel.visible = true

func wait_rows() -> Array:
	var rows: Array = []
	for w in CLK.WAITS:
		rows.append({"label": w[0], "turns": w[1]})
	for w in CLK.WAIT_UNTIL:
		rows.append({"label": w[0], "turns": CLK.turns_until(game.sim.tick, w[1]), "hour": w[1]})
	rows.append({"label": "Sleep until 6am (from 8pm; heals bio health)", "turns": CLK.turns_until(game.sim.tick, 6), "hour": 6, "sleep": true})
	return rows

func choose_wait(i: int) -> void:
	var rows: Array = wait_rows()
	if i < 0 or i >= rows.size():
		return
	panel.visible = false
	if rows[i].get("sleep", false):
		mode = "waiting" if game.sleep_until(int(rows[i]["hour"])) else "play"
		refresh()
		return
	if game.wait_for(rows[i]["turns"]):
		if rows[i].has("hour"):
			game.say("(until %02d:00)" % rows[i]["hour"])
		mode = "waiting"
	else:
		mode = "play"
	refresh()

## the consume menu: food and drink in your pack or within one tile
func show_consume() -> void:
	var g = game
	var t := "[b]Consume[/b]   (a-z chooses, Esc leaves)\nFood %s of 24h   Water %s of 4h\n\n" % [CLK.span_text(g.food_left()), CLK.span_text(g.drink_left())]
	for k in consume_list.size():
		var e: Dictionary = consume_list[k]
		t += "%s) %s   [color=#8899aa]%s[/color]\n" % [char(97 + k) if k < 26 else "?", g.consumable_label(e), e["where"]]
	panel.text = t
	panel.visible = true

func open_consume() -> void:
	consume_list = game.consumables()
	if consume_list.is_empty():
		game.say("You have nothing to eat or drink, and nothing edible within one tile.")
		return
	mode = "consume"
	show_consume()

## the nanohack menu (N): the hacks your Trilobit runs.  Choosing Shock asks for a target in sight.
var nano_list: Array = []
var nano_pick: Array = []              # the targets offered while Shock waits for one (empty otherwise)
var nano_pending: String = ""

func show_nano() -> void:
	var g = game
	var t := ""
	if nano_pending != "":
		t = "[b]%s[/b]   choose a target in sight  (a-z chooses, Esc goes back)\n\n" % g.NANO.get_def(nano_pending)["name"]
		for k in nano_pick.size():
			var j: int = nano_pick[k]
			t += "%s) %s   [color=#8899aa]%d tiles[/color]\n" % [char(97 + k) if k < 26 else "?", g.name_of(j), g.cheb(g.sim.pos[j], g.pc)]
		panel.text = t
		panel.visible = true
		return
	t = "[b]NANOHACKS[/b]   (a-z runs one, Esc leaves)\nBattery %d kJ   each use costs %d kJ   %d of %d slots used\n\n" % [int(g.power_left()), int(g.NANO.USE_KJ), g.nano_installed().size(), g.nano_slots()]
	for k in nano_list.size():
		var e: Dictionary = nano_list[k]
		var st: String = "always on" if e["kind"] == "passive" else ("running, %s left" % CLK.span_text(int(e["left"])) if int(e["left"]) > 0 else "ready")
		t += "%s) %s   [color=#8899aa]%s.  %s[/color]\n" % [char(97 + k) if k < 26 else "?", e["name"], st, e["text"]]
	if nano_list.is_empty():
		t += "[color=#8899aa]No nanohacks installed.  Fit chips on the Implants screen.[/color]\n"
	panel.text = t
	panel.visible = true

func open_nano() -> void:
	if game.nano_slots() <= 0:
		game.say("You have no Trilobit fitted: no nanohacks to run.")
		return
	nano_list = game.nano_menu()
	nano_pick = []
	nano_pending = ""
	mode = "nano"
	show_nano()

func nano_key(k: int) -> void:
	if k == KEY_ESCAPE or settings.action_for(k) == "nano":
		if nano_pending != "":
			nano_pending = ""
			nano_pick = []
			show_nano()
			return
		mode = "play"
		panel.visible = false
		refresh()
		return
	var ck: String = OS.get_keycode_string(k).to_lower()
	var ci: int = ck.unicode_at(0) - 97 if ck.length() == 1 else -1
	if nano_pending != "":
		if ci >= 0 and ci < nano_pick.size():
			var hid: String = nano_pending
			var tg: int = nano_pick[ci]
			mode = "play"
			panel.visible = false
			nano_pending = ""
			nano_pick = []
			game.act_nano_use(hid, tg)
			refresh()
		return
	if ci >= 0 and ci < nano_list.size():
		var e: Dictionary = nano_list[ci]
		if e["id"] == "shock":
			nano_pick = game.nano_targets()
			if nano_pick.is_empty():
				game.say("Nobody in sight to shock.")
				mode = "play"
				panel.visible = false
				refresh()
				return
			nano_pending = "shock"
			show_nano()
			return
		mode = "play"
		panel.visible = false
		game.act_nano_use(String(e["id"]))
		refresh()

## the look cursor, as a cell on the player's level; the view re-centres on it
var look_aim := false                    # the look cursor is picking a target

func look_cell() -> int:
	var g = game
	var base: int = (g.pc / g.s2) * g.s2
	return base + (g.ly(g.pc) + look_off.y) * g.size + (g.lx(g.pc) + look_off.x)

func look_move(d: Vector2i, steps: int) -> void:
	var g = game
	var n: Vector2i = look_off + d * steps
	var x: int = g.lx(g.pc) + n.x
	var y: int = g.ly(g.pc) + n.y
	if x < 0 or y < 0 or x >= g.size or y >= g.size or not g.look_cell_ok(n.x, n.y):
		g.say("That is as far as you can see.")
		return
	look_off = n
	look_refresh()

func look_refresh() -> void:
	view.look_on = true
	view.look_off = look_off
	var d: String = game.describe_at(look_cell())
	if look_aim:
		logbox.text = "[b]MANUAL TARGET[/b]  %s\n[color=#8899aa]Move the cursor (Shift: 5 tiles).  Enter targets what is under it - a person, or a light to shoot out.  Esc cancels.[/color]" % d
	else:
		logbox.text = "[b]LOOK[/b]  %s\n[color=#8899aa]Move the cursor (Shift: 5 tiles).  Enter logs this.  L or Esc ends.  You see %d tiles.[/color]" % [d, game.sight_radius()]
	view.queue_redraw()

func look_end() -> void:
	look_aim = false
	look_off = Vector2i.ZERO
	view.look_on = false
	view.look_off = Vector2i.ZERO
	mode = "play"
	refresh()

## the arrow keys and the numpad on foot (unless "view changes with move direction" is on): Up/Down walk forward/back along the view,
## Left/Right turn it, numpad keys step in a compass direction without turning.  True if the key was handled here.
func _scheme_key(k: int, act: String, run: bool) -> bool:
	var g = game
	if settings.view_follows_move or g.in_vehicle >= 0 or g.transit.riding >= 0 or g.flying:
		return false
	if not act in ["north", "south", "west", "east", "nw", "ne", "sw", "se"]:
		return false
	match k:
		KEY_UP: g.act_move(g.facing.x, g.facing.y, run, false)
		KEY_DOWN: g.act_move(-g.facing.x, -g.facing.y, run, false)
		KEY_LEFT: g.turn_step(-1)
		KEY_RIGHT: g.turn_step(1)
		KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9:
			var d := dir_of(k)
			g.act_move(d.x, d.y, run, false)
		_:
			return false
	return true

func _zoom_label() -> void:
	if zoom_btn != null:
		zoom_btn.text = "Zoom: %s [=]" % view.ZOOM_NAMES[settings.zoom]

## close -> middle -> far -> close
func cycle_zoom() -> void:
	settings.zoom = (settings.zoom + 1) % 3
	settings.save()
	view.set_zoom(settings.zoom)
	_zoom_label()

func dir_of(k: int) -> Vector2i:
	match settings.action_for(k):
		"north": return Vector2i(0, -1)
		"south": return Vector2i(0, 1)
		"west": return Vector2i(-1, 0)
		"east": return Vector2i(1, 0)
		"nw": return Vector2i(-1, -1)
		"ne": return Vector2i(1, -1)
		"sw": return Vector2i(-1, 1)
		"se": return Vector2i(1, 1)
	return Vector2i(0, 0)

func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed:
		return
	var k: int = ev.keycode
	key_unicode = ev.unicode
	if mode in SCREEN_MODES:
		if mode != "loading":
			screen_key(k)
		return
	if game == null:
		return
	if mode == "pick":
		if k == KEY_ESCAPE:
			mode = "play"
			panel.visible = false
		elif k >= KEY_1 and k < KEY_1 + mini(9, pick_list.size()):
			var chosen: Dictionary = pick_list[k - KEY_1]
			mode = "play"
			panel.visible = false
			game.act_interact_with(chosen)
			_after_act()
			return
		refresh()
		return
	if mode == "mods":
		if k == KEY_ESCAPE or k == KEY_M:
			mode = "play"
			panel.visible = false
		else:
			var key2: String = OS.get_keycode_string(k).to_lower()
			if inv_map.has(key2):
				var v = inv_map[key2]
				if v is String:
					game.act_mod_remove(v)
				else:
					game.act_mod_install(v)
		refresh()
		return
	if mode == "jump" or mode == "strike" or mode == "shove" or mode == "turn":
		var was: String = mode
		mode = "play"
		var jd := dir_of(k)
		if jd != Vector2i(0, 0):
			game.tracers.clear()
			if was == "jump":
				game.act_jump(jd.x, jd.y)
			elif was == "shove":
				game.act_shove(jd.x, jd.y)
			elif was == "turn":
				game.turn_to(jd.x, jd.y)
			else:
				game.act_strike(jd.x, jd.y)
		refresh()
		return
	if mode == "clock":
		if k == KEY_ESCAPE or k == KEY_E or k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			mode = "play"
			panel.visible = false
		refresh()
		return
	if mode == "talk":
		if k == KEY_ESCAPE:
			mode = "play"
			panel.visible = false
		elif k >= KEY_1 and k <= KEY_9:
			menu = game.eco.choose(menu, k - KEY_1)
			if menu.is_empty():
				mode = "play"
				panel.visible = false
		refresh()
		return
	if mode == "waiting":
		if true:                                       # any key stops a wait
			game.wait_cancel("You stop waiting.")
			mode = "play"
			refresh()
		return
	if mode == "movemenu":
		if k == KEY_ESCAPE:
			mode = "play"
			panel.visible = false
		elif k >= KEY_1 and k < KEY_1 + MOVE_ROWS.size():
			choose_move(k - KEY_1)
			return
		elif k == KEY_UP or k == KEY_K:
			menu_sel = (menu_sel + MOVE_ROWS.size() - 1) % MOVE_ROWS.size()
		elif k == KEY_DOWN or k == KEY_J:
			menu_sel = (menu_sel + 1) % MOVE_ROWS.size()
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			choose_move(menu_sel)
			return
		show_move()
		refresh()
		return
	if mode == "waitmenu":
		var rows_n: int = wait_rows().size()
		if k == KEY_ESCAPE:
			mode = "play"
			panel.visible = false
		elif k >= KEY_1 and k < KEY_1 + rows_n:
			choose_wait(k - KEY_1)
			return
		elif k == KEY_UP or k == KEY_K:
			menu_sel = (menu_sel + rows_n - 1) % rows_n
		elif k == KEY_DOWN or k == KEY_J:
			menu_sel = (menu_sel + 1) % rows_n
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			choose_wait(menu_sel)
			return
		refresh()
		return
	if mode == "nano":
		nano_key(k)
		return
	if mode == "consume":
		if k == KEY_ESCAPE or settings.action_for(k) == "consume":
			mode = "play"
			panel.visible = false
		else:
			var ck: String = OS.get_keycode_string(k).to_lower()
			var ci: int = ck.unicode_at(0) - 97 if ck.length() == 1 else -1
			if ci >= 0 and ci < consume_list.size():
				var e: Dictionary = consume_list[ci]
				mode = "play"
				panel.visible = false
				game.act_consume(e)
		refresh()
		return
	if mode == "look":
		var act_l: String = settings.action_for(k)
		if k == KEY_ESCAPE or (act_l == "look" and not look_aim) or (look_aim and act_l == "mtarget"):
			look_end()
			return
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			if look_aim:
				var lc: int = look_cell()
				look_end()
				game.act_manual_target(lc)
				refresh()
				return
			game.say("You look: " + game.describe_at(look_cell()))
			look_refresh()
			return
		var ld := dir_of(k)
		if ld != Vector2i.ZERO:
			look_move(ld, 5 if ev.shift_pressed else 1)
		return
	if k == KEY_ESCAPE:
		open_screen("pause")
		return
	var g = game
	if g.game_over:
		if k == KEY_N:
			open_creation()          # a new character starts at the creation screen too
		return
	var act: String = settings.action_for(k)
	if k == KEY_SLASH and ev.shift_pressed:
		act = "keysscreen"
	if k == KEY_O and ev.shift_pressed:
		act = "shove"
	var acted := true
	g.tracers.clear()
	var run: bool = ev.shift_pressed or g.run_mode
	if _scheme_key(k, act, run):
		_after_act()
		return
	match act:
		"north": g.act_move(0, -1, run)
		"south": g.act_move(0, 1, run)
		"west": g.act_move(-1, 0, run)
		"east": g.act_move(1, 0, run)
		"nw": g.act_move(-1, -1, run)
		"ne": g.act_move(1, -1, run)
		"sw": g.act_move(-1, 1, run)
		"se": g.act_move(1, 1, run)
		"wait":
			if g.in_vehicle >= 0 and k == KEY_SPACE:
				g.drive(0, 0)
			elif ev.shift_pressed and k == KEY_PERIOD:
				g.act_vertical(-1)
			else:
				g.act_wait()
		"up": g.act_vertical(1)
		"down": g.act_vertical(-1)
		"talk":
			var who: int = g.talk_target()
			if who < 0:
				g.say("Nobody close enough to talk to.")
			elif g.barter.trades(who):
				open_barter(who)
				return
			else:
				menu = g.eco.menu_for(who)
				mode = "talk"
		"zoom":
			cycle_zoom()
			acted = false
		"siphon": g.act_siphon()
		"pickup":
			if ev.shift_pressed and k == KEY_COMMA:
				g.act_vertical(1)
			else:
				g.act_pickup()
		"fire": g.act_fire(ev.shift_pressed)
		"aim": g.act_aim(ev.shift_pressed)
		"reload": g.act_reload()
		"firemode": g.act_fire_mode()
		"ammo": g.act_cycle_kind()
		"target": g.act_cycle_target(ev.shift_pressed)
		"interact":
			var near: Array = g.interactables()
			if near.is_empty():
				g.say("Nothing here to use.")
			elif near.size() == 1:
				g.act_interact_with(near[0])
			else:
				pick_list = near
				mode = "pick"
		"viewtarget": toggle_target_view()
		"steal": g.act_steal()
		"movement":
			mode = "movemenu"
			menu_sel = 3 if g.run_mode else g.stance
			show_move()
			return
		"strike":
			mode = "strike"
			g.say("Strike which way?  (direction key; a long weapon reaches further)")
		"turn":
			mode = "turn"
			g.say("Turn which way?  You only see 180 degrees in front of you.  (direction key, Esc cancels)")
		"shove":
			mode = "shove"
			g.say("Shove which way?  (direction key; people go over railings and off roofs)")
		"swap": g.act_swap()
		"jump":
			mode = "jump"
			g.say("Jump which way?  (direction key, Esc cancels)")
		"vehicle": g.act_vehicle()
		"drop":
			open_tab("equipment", "play")
			gear.drop_mode = true
			return
		"inventory":
			open_tab("equipment", "play")
			return
		"implants":
			open_tab("implants", "play")
			return
		"skills":
			open_tab("skills", "play")
			return
		"map":
			open_tab("map", "play")
			return
		"keysscreen":
			screen_back = "play"
			open_screen("keys")
			return
		"look":
			look_aim = false
			mode = "look"
			look_off = Vector2i.ZERO
			look_refresh()
			return
		"mtarget":
			if game.gun_stats().is_empty():
				game.say("You have no gun wielded.")
				refresh()
				return
			look_aim = true
			mode = "look"
			look_off = Vector2i.ZERO
			look_refresh()
			return
		"consume":
			open_consume()
			return
		"nano":
			open_nano()
			return
		"waitmenu":
			mode = "waitmenu"
			menu_sel = 0
			show_wait()
			return
		"fullscreen":
			pass
		_:
			match k:
				KEY_F2: _cycle_tileset(1)
				KEY_F5:
					if save_slot(1):
						g.say("Game saved (slot 1).")
				KEY_F9:
					if FileAccess.file_exists(slot_path(1)):
						begin_load(1)
						return
					g.say("No saved game in slot 1.")
				_:
					acted = false
	if acted:
		_after_act()

## what using something asks the front end for: a menu, a screen, the gun bench
func _after_act() -> void:
	if mode == "play" and game.elev_hit >= 0:
		open_elevator()
	elif mode == "play" and game.clock_hit >= 0:
		clock_cell = game.clock_hit
		game.clock_hit = -1
		mode = "clock"
	elif mode == "play" and game.charger_hit >= 0:
		menu = game.eco.charger_menu(game.charger_hit)
		game.charger_hit = -1
		mode = "talk"
	elif mode == "play" and game.ev_hit >= 0:
		menu = game.eco.ev_menu(game.ev_hit)
		game.ev_hit = -1
		mode = "talk"
	elif mode == "play" and game.smith_hit >= 0:
		game.smith_hit = -1
		mode = "mods"
	elif mode == "play" and game.terminal_hit >= 0:
		open_terminal(game.terminal_hit)
		return
	refresh()

func _drain_sfx() -> void:
	if game == null:
		return
	for n in game.sfx_queue:
		sfx.play(n)
	game.sfx_queue.clear()
