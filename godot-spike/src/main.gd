extends Node
## Entry point: builds the game, the view and the HUD, and turns keys into actions.
const GameScript = preload("res://src/game.gd")
const TilesetScript = preload("res://src/tileset.gd")
const ViewScript = preload("res://src/view.gd")
const TILESETS := ["Bouma_TopDown", "Mokuhanga_TopDown"]
const SAVE_PATH := "user://trilobit_spike_save.json"

var game
var tileset
var view
var status: Label
var logbox: RichTextLabel
var panel: RichTextLabel
var mode: String = "play"           # play, inventory, help, talk
var menu: Dictionary = {}
var ts_index: int = 0
var inv_map: Dictionary = {}

func _ready() -> void:
	var seed := int(Time.get_unix_time_from_system()) % 100000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed = int(a.substr(7))
	new_game(seed)

func new_game(seed: int) -> void:
	for c in get_children():
		c.queue_free()
	tileset = TilesetScript.new()
	tileset.load_dir("res://gfx/" + TILESETS[ts_index])
	game = GameScript.new(seed)
	game.setup(1500)
	view = ViewScript.new()
	view.game = game
	view.tileset = tileset
	add_child(view)
	var layer := CanvasLayer.new()
	add_child(layer)
	status = Label.new()
	status.position = Vector2(8, 4)
	status.add_theme_font_size_override("font_size", 16)
	layer.add_child(status)
	logbox = RichTextLabel.new()
	logbox.position = Vector2(8, 620)
	logbox.size = Vector2(1264, 96)
	logbox.bbcode_enabled = true
	logbox.scroll_following = true
	layer.add_child(logbox)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.position = Vector2(0, 616)
	bg.size = Vector2(1280, 104)
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
	mode = "play"
	refresh()

func refresh() -> void:
	view.queue_redraw()
	var g = game
	var wield_txt: String = g.wield.def["name"] if g.wield != null else "bare hands"
	var line1 := "HP %d/%d   ¥%d   Heat %d   Ammo %d   %s%s   %s   Turn %d   Carry %.1f kg%s" % [g.hp, g.hp_max, g.yen, g.heat, g.ammo, wield_txt,
		"  [crouching]" if g.crouch else "", g.time_text(), g.turn, g.total_weight_kg(), "  [IN CAR %d%%]" % g.vehicles[g.in_vehicle]["charge"] if g.in_vehicle >= 0 else ""]
	var tw: Dictionary = g.tower_at(g.pc) if g.z_of(g.pc) > 0 else {}
	var where: String = g.zname(g.pc) + (" of %d" % tw["h"] if not tw.is_empty() else "")
	var line2: String = "%s   |   %s" % [where, g.eco.status_text()]
	if g.z_of(g.pc) == -1 and g.transit.active():
		var na: Dictionary = g.transit.next_arrival()
		line2 += "   |   Train: %s %s in %d" % ["boarding at" if na["dwelling"] else "next stop", na["name"], na["turns"]]
	if g.transit.riding >= 0:
		line2 += "   [ON THE TRAIN]"
	var jt: String = g.eco.job_text()
	status.text = line1 + "\n" + line2 + ("\n" + jt if jt != "" else "")
	var lines: Array = g.log.slice(-5)
	logbox.text = "\n".join(lines)
	status.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if g.hp < g.hp_max / 3 else Color.WHITE)
	if mode == "inventory":
		show_inventory()
	elif mode == "talk":
		show_talk()

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

func show_inventory() -> void:
	inv_map.clear()
	var t := "[b]Inventory[/b]   (a-z wields a gun, i or Esc closes)   ¥%d   ammo %d\n\n" % [game.yen, game.ammo]
	var k := 0
	for e in game.inventory_list():
		var key := char(97 + k) if k < 26 else "?"
		var it = e["item"]
		var vol := " %.1f L" % (it.volume() / 1000.0)
		t += "%s%s) %s   [color=#8899aa]%s, %d g,%s[/color]\n" % ["    ".repeat(e["depth"]), key, game.item_label(it), e["where"], it.weight(), vol]
		inv_map[key] = it
		k += 1
	panel.text = t
	panel.visible = true

func show_help() -> void:
	panel.text = "[b]Keys[/b]\n\nMove: arrows, numpad, h j k l y u b n (n is also 'new life' when dead)\n.  or  Space   wait / brake\n<  or  PgUp  go up (stairs, elevator, ladder)      >  or  PgDn  go down.  An elevator rides up to three floors.\nt   talk to the nearest person (vendors, fixers, ripperdocs)      p   pay 100 on the debt (Shift+P: 1000)\nWalk into a locked door to pick it.  Step onto a carriage while the train doors are open to ride; step onto a platform to get off.\ng   pick up        i   inventory (a-z wields a gun)\nf   fire at the nearest hostile in sight  (Shift+F: at anyone)\ns   pickpocket an adjacent person (stealth and theft skill)\nc   crouch (harder to notice)        e   get in or out of a car\nd   drop the wielded weapon\nF2   switch tileset        F5  save        F9  load        Esc  close\n\n[b]Tips[/b]\nThe bar over a person's head fills as they notice you.  ? = looking, ! = hunting.  Crouch and approach from behind for a triple-damage strike.\nThugs (red coats) are hostile.  Officers turn on you when your heat reaches 30.  Cars are electric: watch the battery."
	panel.visible = true

func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed:
		return
	var k: int = ev.keycode
	if mode == "inventory":
		if k == KEY_ESCAPE or k == KEY_I:
			mode = "play"
			panel.visible = false
		else:
			var key: String = OS.get_keycode_string(k).to_lower()
			if inv_map.has(key):
				game.act_wield(inv_map[key])
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
	if mode == "help":
		mode = "play"
		panel.visible = false
		refresh()
		return
	if k == KEY_QUESTION or (k == KEY_SLASH and ev.shift_pressed):
		mode = "help"
		show_help()
		return
	var g = game
	if g.game_over:
		if k == KEY_N:
			new_game(randi() % 100000)
		return
	var acted := true
	match k:
		KEY_UP, KEY_KP_8, KEY_K: g.act_move(0, -1)
		KEY_DOWN, KEY_KP_2, KEY_J: g.act_move(0, 1)
		KEY_LEFT, KEY_KP_4, KEY_H: g.act_move(-1, 0)
		KEY_RIGHT, KEY_KP_6, KEY_L: g.act_move(1, 0)
		KEY_KP_7, KEY_Y: g.act_move(-1, -1)
		KEY_KP_9, KEY_U: g.act_move(1, -1)
		KEY_KP_1, KEY_B: g.act_move(-1, 1)
		KEY_KP_3, KEY_N: g.act_move(1, 1)
		KEY_PERIOD, KEY_KP_5:
			if ev.shift_pressed:
				g.act_vertical(-1)
			else:
				g.act_wait()
		KEY_LESS, KEY_PAGEUP, KEY_BRACKETLEFT: g.act_vertical(1)
		KEY_GREATER, KEY_PAGEDOWN, KEY_BRACKETRIGHT: g.act_vertical(-1)
		KEY_T:
			var who: int = g.talk_target()
			if who < 0:
				g.say("Nobody close enough to talk to.")
			else:
				menu = g.eco.menu_for(who)
				mode = "talk"
		KEY_P: g.act_pay(1000 if ev.shift_pressed else 100)
		KEY_SPACE:
			if g.in_vehicle >= 0:
				g.drive(0, 0)
			else:
				g.act_wait()
		KEY_COMMA:
			if ev.shift_pressed:
				g.act_vertical(1)
			else:
				g.act_pickup()
		KEY_G: g.act_pickup()
		KEY_F: g.act_fire(ev.shift_pressed)
		KEY_S: g.act_steal()
		KEY_C: g.act_crouch()
		KEY_E: g.act_vehicle()
		KEY_D: g.act_drop_wield()
		KEY_I:
			mode = "inventory"
		KEY_F2:
			ts_index = (ts_index + 1) % TILESETS.size()
			tileset.textures.clear()
			tileset.sheets.clear()
			tileset.index.clear()
			tileset.load_dir("res://gfx/" + TILESETS[ts_index])
		KEY_F5:
			var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
			f.store_string(JSON.stringify(g.save_dict()))
			g.say("Game saved.")
		KEY_F9:
			if FileAccess.file_exists(SAVE_PATH):
				var d = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
				game.load_dict(d)
				view.game = game
				game.say("Game loaded.")
			else:
				g.say("No saved game.")
		_:
			acted = false
	if acted:
		refresh()
