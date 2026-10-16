extends Node
## Entry point: title screen, menus, then the game, its view and HUD; turns keys into actions.
const GameScript = preload("res://src/game.gd")
const WorldScript = preload("res://src/world.gd")
const TilesetScript = preload("res://src/tileset.gd")
const ViewScript = preload("res://src/view.gd")
const SettingsScript = preload("res://src/settings.gd")
const SfxScript = preload("res://src/sfx.gd")
const ScreenScript = preload("res://src/screen_view.gd")
const IMP = preload("res://src/implants.gd")
const TILESETS := ["Bouma_TopDown", "Mokuhanga_TopDown"]
const SLOTS := 3

var game
var tileset
var view
var status: Label
var logbox: RichTextLabel
var panel: RichTextLabel
var mode: String = "title"           # title, play, garage, inventory, help, talk, mods, jump, strike, shove, pause, options, keys, saves, loads, implants, loading
var menu: Dictionary = {}
var ts_index: int = 0
var inv_map: Dictionary = {}
var settings
var sfx
var screen
var play_nodes: Array = []
var screen_back: String = "title"     # where Esc on a sub-screen goes
var rebinding: String = ""            # action waiting for a key
var key_scroll_items: Array = []
var pending_seed: int = -1
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
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	screen = ScreenScript.new()
	screen.visible = false
	layer.add_child(screen)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--seed="):
			pending_seed = int(a.substr(7))
	if "--newgame" in args or pending_seed >= 0:
		begin_new(pending_seed if pending_seed >= 0 else int(Time.get_unix_time_from_system()) % 100000)
	else:
		open_screen("title")

func apply_audio() -> void:
	sfx.enabled = settings.sound_on
	sfx.volume = settings.volume

func begin_new(seed: int) -> void:
	open_screen("loading")
	await get_tree().process_frame
	await get_tree().process_frame
	world = WorldScript.new()
	world.start(seed, 1500)
	start_play(world.game)

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
	tileset.load_dir("res://gfx/" + TILESETS[ts_index])
	game = g
	view = ViewScript.new()
	view.game = game
	view.tileset = tileset
	add_child(view)
	play_nodes.append(view)
	var layer := CanvasLayer.new()
	add_child(layer)
	play_nodes.append(layer)
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
		return "%s   HP %s   ¥%s   %s" % [m.get("where", "?"), m.get("hp", "?"), m.get("yen", "?"), m.get("saved", "")]
	return "(unreadable)"

func save_slot(n: int) -> bool:
	if game == null:
		return false
	var meta := {"where": game.zname(game.pc), "hp": game.hp, "yen": game.yen, "turn": game.turn, "saved": Time.get_datetime_string_from_system(false, true)}
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
	match kind:
		"title":
			screen_back = "title"
			screen.overlay = false
			screen.subtitle = "A cyberpunk roguelike  -  Hokkaido-Sakhalin Freeport, 2088"
			screen.items = [{"label": "New Game", "id": "new"}, {"label": "Load Game", "id": "load"}, {"label": "Options", "id": "options"}, {"label": "Exit", "id": "exit"}]
			screen.footer = "Up / Down  -  Enter"
		"loading":
			screen.overlay = false
			screen.items = []
			screen.kind = "title"
			screen.subtitle = "Generating the world..."
			screen.footer = ""
		"pause":
			screen.overlay = true
			screen.title = "PAUSED"
			screen.items = [{"label": "Resume", "id": "resume"}, {"label": "Save Game", "id": "save"}, {"label": "Load Game", "id": "load"}, {"label": "Implants", "id": "implants"},
				{"label": "Options", "id": "options"}, {"label": "Quit to Title", "id": "title"}, {"label": "Exit to Desktop", "id": "exit"}]
		"options":
			screen.title = "OPTIONS"
			_fill_options()
		"keys":
			screen.title = "KEY BINDINGS"
			screen.subtitle = "Enter on an action, then press the new key.  Esc cancels."
			_fill_keys()
		"saves", "loads":
			screen.title = "SAVE GAME" if kind == "saves" else "LOAD GAME"
			_fill_slots()
		"implants":
			screen.overlay = false
			screen.part_sel = 0
		"map":
			screen.overlay = false
			screen.world = world
			_make_map()
	_scroll_fix()

func _make_map() -> void:
	if world == null:
		screen.map_tex = null
		return
	if map_tex == null or map_seed != world.seed_value:
		map_tex = ImageTexture.create_from_image(world.island.overview_image(3))
		map_seed = world.seed_value
	screen.map_tex = map_tex

func _fill_options() -> void:
	screen.items = [
		{"label": "Sound", "value": "ON" if settings.sound_on else "OFF", "id": "sound"},
		{"label": "Volume", "value": "%d%%" % int(settings.volume * 100.0), "id": "volume"},
		{"label": "Tileset", "value": TILESETS[ts_index].replace("_TopDown", ""), "id": "tileset"},
		{"label": "Key bindings...", "id": "keys"},
		{"label": "Back", "id": "back"}]
	screen.footer = "Left / Right changes a value  -  Enter selects  -  Esc goes back"

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
		"options", "keys", "saves", "loads":
			var prev := "options" if mode == "keys" else screen_back
			if prev == "pause" and game != null:
				open_screen("pause")
			elif prev == "options":
				open_screen("options")
			else:
				open_screen("title")
		"implants":
			open_screen("pause")
		"map":
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
	match id:
		"new": begin_new(int(Time.get_unix_time_from_system()) % 100000)
		"load":
			screen_back = "pause" if mode == "pause" else "title"
			open_screen("loads")
		"save":
			screen_back = "pause"
			open_screen("saves")
		"options":
			screen_back = "pause" if mode == "pause" else "title"
			open_screen("options")
		"keys": open_screen("keys")
		"implants": open_screen("implants")
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

func _cycle_tileset(dir: int) -> void:
	ts_index = (ts_index + dir + TILESETS.size()) % TILESETS.size()
	settings.tileset = ts_index
	settings.save()
	if tileset != null:
		tileset.textures.clear()
		tileset.sheets.clear()
		tileset.index.clear()
		tileset.load_dir("res://gfx/" + TILESETS[ts_index])
	_fill_options()

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
	if mode == "map":
		if k == KEY_ESCAPE or k == KEY_M or k == settings.binds["map"][0]:
			back_from_screen()
		return
	if mode == "implants":
		var n := IMP.PARTS.size()
		if k == KEY_ESCAPE or k == settings.binds["implants"][0]:
			back_from_screen()
		elif k == KEY_UP or k == KEY_LEFT or k == KEY_K or k == KEY_H:
			screen.part_sel = (screen.part_sel + n - 1) % n
			sfx.play("blip")
		elif k == KEY_DOWN or k == KEY_RIGHT or k == KEY_J or k == KEY_L or k == KEY_TAB:
			screen.part_sel = (screen.part_sel + 1) % n
			sfx.play("blip")
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
			elif id == "tileset":
				_cycle_tileset(step)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var it: Dictionary = screen.items[screen.sel]
			if not it.get("disabled", false):
				activate(it["id"])
	_scroll_fix()

func _unhandled_input(ev: InputEvent) -> void:
	# the mouse picks body parts on the implants screen
	if mode == "implants" and ev is InputEventMouseMotion:
		var i: int = screen.part_at_mouse(ev.position)
		if i >= 0 and i != screen.part_sel:
			screen.part_sel = i
			sfx.play("blip")

func refresh() -> void:
	if world != null and world.game == game and world.poll():
		game = world.game
		view.game = game
		screen.game = game
		sfx.play("select")
	view.queue_redraw()
	var g = game
	var extra := ""
	if g.in_vehicle >= 0:
		var vv: Dictionary = g.vehicles[g.in_vehicle]
		extra = "  [%s  batt %d%%  speed %d  %s%s]" % [g.vs.KINDS[vv["kind"]]["name"].to_upper(), vv["charge"], absi(int(vv["spd"])), g.vs.status_text(g.in_vehicle), "  AIRBORNE" if g.airborne() else ""]
	if g.flying:
		extra += "  [FLYING fuel %d]" % g.fuel
	elif g.has_implant("jets") and g.fuel < g.FUEL_MAX:
		extra += "  [jets %d]" % g.fuel
	var line1 := "HP %d/%d   ¥%d   Heat %d   %s%s   %s   Turn %d   Carry %.1f kg%s" % [g.hp, g.hp_max, g.yen, g.heat, g.gun_line(),
		"  [%s %d]" % [g.stance_name(), g.stamina] if g.stance != 2 or g.stamina < 30 else "", g.time_text(), g.turn, g.total_weight_kg(), extra]
	var tw: Dictionary = g.tower_at(g.pc) if g.z_of(g.pc) > 0 else {}
	var where: String = g.zname(g.pc) + (" of %d" % tw["h"] if not tw.is_empty() else "")
	var line2: String = "%s   |   %s" % [where, g.eco.status_text()]
	if g.z_of(g.pc) == -1 and g.transit.active():
		var na: Dictionary = g.transit.next_arrival()
		line2 += "   |   Train: %s %s in %d" % ["boarding at" if na["dwelling"] else "next stop", na["name"], na["turns"]]
	if g.transit.riding >= 0:
		line2 += "   [ON THE TRAIN]"
	var tgt: int = g.current_target()
	if tgt >= 0:
		var cov: int = g.cover_vs(g.pc, g.sim.pos[tgt], false)
		line2 += "   |   Target: %s, %d tiles, %d%%%s" % [g.name_of(tgt), g.cheb(g.sim.pos[tgt], g.pc), g.hit_chance_on(tgt), (" (in cover)" if cov > 0 else "")]
	var jt: String = g.eco.job_text()
	status.text = line1 + "\n" + line2 + ("\n" + jt if jt != "" else "")
	var lines: Array = g.log.slice(-5)
	logbox.text = "\n".join(lines)
	status.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if g.hp < g.hp_max / 3 else Color.WHITE)
	_drain_sfx()
	if mode == "inventory":
		show_inventory()
	elif mode == "talk":
		show_talk()
	elif mode == "mods":
		show_mods()
	elif mode == "garage":
		show_garage()

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

func show_garage() -> void:
	inv_map.clear()
	var g = game
	var vi: int = g.vs.near_vehicle()
	if vi < 0 or g.in_vehicle >= 0:
		panel.text = "[b]Vehicle service[/b]\n\nStand next to a vehicle (and be out of it) to open its engine bay."
		panel.visible = true
		return
	var v: Dictionary = g.vehicles[vi]
	var ed: Dictionary = g.vs.eng_def(v)
	var t := "[b]%s[/b]  %s   (a-z fits an engine, 1-4 patches a part with a repair kit, Esc closes)\n" % [g.vs.KINDS[v["kind"]]["name"].capitalize(), "[color=#ff6666]WRECK[/color]" if v["wreck"] else ""]
	t += "engine: %s   power %s  battery use 1 per %s turns   battery %d%%\n\n" % [g.db.defs[v["eng"]["id"]]["name"], str(ed.get("power", "?")), str(ed.get("drain", "?")), v["charge"]]
	var k := 1
	for part in ["engine", "body", "drive", "cabin"]:
		var pct: int = g.vs.part_pct(v, part)
		var bar := "#".repeat(pct / 5) + "-".repeat(20 - pct / 5)
		var label: String = g.vs.KINDS[v["kind"]]["drive"] if part == "drive" else part
		t += "%d) %-8s [%s] %3d%%  (%d/%d)\n" % [k, label, bar, pct, v["parts"][part], v["pmax"][part]]
		inv_map[str(k)] = part
		k += 1
	t += "\nrepair kits: %d\n\n[b]Engines you can fit[/b]\n" % g.repair_kits().size()
	var j := 0
	for e in g.engines_available():
		var it = e["item"]
		var d: Dictionary = it.def["engine"]
		var fits: bool = v["kind"] in d["fits"]
		var key := char(97 + j)
		t += "%s) %s  [color=#8899aa]power %d, %d hp%s%s%s[/color]\n" % [key, it.def["name"], d["power"], d["hp"], ", worn to %d" % it.cond if it.cond >= 0 else "", ", on the ground" if e["ground"] else "", "" if fits else ", does not fit"]
		inv_map[key] = e
		j += 1
	if j == 0:
		t += "(none carried or lying at your feet)\n"
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
	t += "dmg %d-%d   range %d   accuracy %d%%   mag %d   recoil %.1f   report %d   reload %d   ammo %s %s\n\n" % [st["dmg"][0], st["dmg"][1], st["range"], st["acc"], st["mag"], st["recoil"], st["noise"], st["reload"], st["cal"], st["label"]]
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

func show_inventory() -> void:
	inv_map.clear()
	var t := "[b]Inventory[/b]   (a-z wields a gun, i or Esc closes)   ¥%d   loose rounds %d\n\n" % [game.yen, game.ammo_total()]
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
	panel.text = "[b]Keys[/b]\n\nMove: arrows, numpad, h j k l y u b n (n is also 'new life' when dead)\n.  or  Space   wait / brake\n<  or  PgUp  go up (stairs, elevator, ladder; with jump jets, lift off or climb through open air)      >  or  PgDn  go down (or descend and land).  An elevator rides up to three floors.  Hunters follow you up and down stairs.\ne  get into or out of cars, gyros (flying) and mechs (armoured walkers).  Leap off an edge and you fall: 5 damage a floor.\nt   talk to the nearest person (vendors, fixers, ripperdocs)      p   pay 100 on the debt (Shift+P: 1000)\nWalk into a locked door to pick it.  Step onto a carriage while the train doors are open to ride; step onto a platform to get off.\ng   pick up        i   inventory (a-z wields a gun)\nf   fire at the target (Shift+F: at anyone)      Tab  cycle targets      a  aim (up to 3 turns, each steadier)\nr   reload / clear a jam      v  fire mode (single, burst, auto)      x  choose the next ammunition kind\nF4  gunsmith: fit scopes, suppressors, magazines, grips, stocks, barrels (a scope helps at range, hurts up close)\ns   pickpocket an adjacent person (stealth and theft skill)\nw + direction   strike (reach weapons hit up to 2 away; they also strike hunters 2 cells off when you step toward them)      o + direction   shove (off an edge, too)      \\   swap to your previous weapon\nc   crouch      z   crawl (half speed, nearly invisible and silent)      Shift+direction   run two cells (noisy, tiring)      q + direction   jump (2 cells, 3 after a run)        e   get in or out of a car\nd   drop the wielded weapon\nLimbs: each has its own health (top right).  A disabled leg slows you, a disabled arm rules out two-handed weapons; head or chest at 0 is death.  Armor is worn from the inventory and soaks damage until it breaks.  Trauma patches mend limbs; ripperdocs rebuild them.\nEsc  menu: save, load, options (rebind keys, sound), implants        F3  implants        M  island map        F2  switch tileset        F5  quick save        F9  quick load\n\n[b]Tips[/b]\nThe bar over a person's head fills as they notice you.  ? = looking, ! = hunting.  People see in a cone in front of them and hear footsteps by stance.  Strike an unaware person from behind for a quiet kill.  Crates, dumpsters, planters, railings and cars give cover; crouch behind them.\nThugs (red coats) are hostile.  Officers turn on you when your heat reaches 30.  Cars are electric: watch the battery."
	panel.visible = true

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
	if mode in ["title", "loading", "pause", "options", "keys", "saves", "loads", "implants", "map"]:
		if mode != "loading":
			screen_key(k)
		return
	if game == null:
		return
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
	if mode == "mods":
		if k == KEY_ESCAPE or k == KEY_M or k == KEY_F4:
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
	if mode == "garage":
		if k == KEY_ESCAPE:
			mode = "play"
			panel.visible = false
		else:
			var gk: String = OS.get_keycode_string(k).to_lower()
			var gvi: int = game.vs.near_vehicle()
			if inv_map.has(gk) and gvi >= 0:
				var tgt = inv_map[gk]
				if tgt is String:
					game.act_repair(gvi, tgt)
				else:
					game.act_fit_engine(gvi, tgt["item"], tgt["ground"])
		refresh()
		return
	if mode == "jump" or mode == "strike" or mode == "shove":
		var was: String = mode
		mode = "play"
		var jd := dir_of(k)
		if jd != Vector2i(0, 0):
			game.tracers.clear()
			if was == "jump":
				game.act_jump(jd.x, jd.y)
			elif was == "shove":
				game.act_shove(jd.x, jd.y)
			else:
				game.act_strike(jd.x, jd.y)
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
	if k == KEY_ESCAPE:
		open_screen("pause")
		return
	var g = game
	if g.game_over:
		if k == KEY_N:
			begin_new(randi() % 100000)
		return
	var act: String = settings.action_for(k)
	if k == KEY_QUESTION or (k == KEY_SLASH and ev.shift_pressed):
		act = "help"
	var acted := true
	g.tracers.clear()
	var run: bool = ev.shift_pressed
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
			else:
				menu = g.eco.menu_for(who)
				mode = "talk"
		"pay": g.act_pay(1000 if ev.shift_pressed else 100)
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
		"gunsmith": mode = "mods"
		"steal": g.act_steal()
		"crouch": g.act_crouch()
		"crawl": g.act_crawl()
		"strike":
			mode = "strike"
			g.say("Strike which way?  (direction key; a long weapon reaches further)")
		"shove":
			mode = "shove"
			g.say("Shove which way?  (direction key; people go over railings and off roofs)")
		"swap": g.act_swap()
		"jump":
			mode = "jump"
			g.say("Jump which way?  (direction key, Esc cancels)")
		"vehicle":
			if ev.shift_pressed:
				mode = "garage"
			else:
				g.act_vehicle()
		"service": mode = "garage"
		"drop": g.act_drop_wield()
		"inventory": mode = "inventory"
		"implants":
			screen_back = "pause"
			open_screen("implants")
			return
		"map":
			open_screen("map")
			return
		"help":
			mode = "help"
			show_help()
			return
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
		refresh()

func _drain_sfx() -> void:
	if game == null:
		return
	for n in game.sfx_queue:
		sfx.play(n)
	game.sfx_queue.clear()
