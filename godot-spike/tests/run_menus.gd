extends SceneTree
## Title screen, options, key rebinding, sound toggle, save slots, load, implants screen.  Run: godot --headless -s tests/run_menus.gd
const MainScript = preload("res://src/main.gd")
var passed := 0
var total := 0

func check(name: String, cond: bool) -> void:
	total += 1
	if cond:
		passed += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func key(m, k: int) -> void:
	m.screen_key(k)

func _initialize() -> void:
	preload("res://tests/legacy_implants.gd").install()
	var m = MainScript.new()
	m.save_prefix = "user://test_save_"
	m.settings_path = "user://test_settings.json"
	for n in 4:
		DirAccess.remove_absolute("user://test_save_%d.json" % n)
	DirAccess.remove_absolute("user://test_settings.json")
	root.add_child(m)
	await process_frame
	check("the game starts on the title screen", m.mode == "title" and m.screen.visible)
	var ids = m.screen.items.map(func(i): return i["label"])
	check("title offers New Game, Load Game, Options, TEST---, Exit", ids == ["New Game", "Load Game", "Options", "TEST---", "Exit"])
	# options
	key(m, KEY_DOWN); key(m, KEY_DOWN)
	key(m, KEY_ENTER)
	check("Options opens", m.mode == "options")
	check("sound starts on", m.settings.sound_on)
	key(m, KEY_ENTER)
	check("Enter on Sound toggles it off", not m.settings.sound_on and not m.sfx.enabled)
	key(m, KEY_ENTER)
	check("and back on", m.settings.sound_on)
	key(m, KEY_DOWN)
	var v0: float = m.settings.volume
	key(m, KEY_LEFT)
	check("Left lowers the volume", m.settings.volume < v0)
	# key bindings
	key(m, KEY_DOWN); key(m, KEY_DOWN); key(m, KEY_DOWN); key(m, KEY_DOWN); key(m, KEY_ENTER)
	check("key bindings list opens", m.mode == "keys" and m.screen.items.size() > 30)
	check("fire is F by default", m.settings.action_for(KEY_F) == "fire")
	key(m, KEY_ESCAPE)
	check("Esc goes back to options", m.mode == "options")
	key(m, KEY_DOWN); key(m, KEY_DOWN)
	# go to keys again and rebind "fire" (index of fire)
	m.open_screen("keys")
	var fi := -1
	for i in m.screen.items.size():
		if m.screen.items[i]["id"] == "key:fire":
			fi = i
	m.screen.sel = fi
	key(m, KEY_ENTER)
	check("rebinding waits for a key", m.rebinding == "fire" and m.screen.prompt != "")
	key(m, KEY_B)
	check("B now fires, and no longer moves south-west", m.settings.action_for(KEY_B) == "fire" and m.settings.action_for(KEY_F) == "" and not (KEY_B in m.settings.binds["sw"]))
	check("settings are written to disk", FileAccess.file_exists("user://test_settings.json"))
	key(m, KEY_ENTER); key(m, KEY_ESCAPE)       # start a rebind then cancel
	check("Esc cancels a rebind", m.rebinding == "" and m.settings.action_for(KEY_B) == "fire")
	var s2 = load("res://src/settings.gd").new()
	s2.path = "user://test_settings.json"
	s2.load_file()
	check("rebinds survive a restart", s2.action_for(KEY_B) == "fire" and not s2.sound_on == false)
	m.settings.reset_keys()
	check("reset restores defaults", m.settings.action_for(KEY_F) == "fire")
	# new game
	m.open_screen("title")
	m.begin_new(5)
	for i in 30:
		await process_frame
		if m.mode == "play":
			break
	check("New Game starts play", m.mode == "play" and m.game != null and not m.screen.visible)
	var pc0: int = m.game.pc
	m.game.yen = 4321
	m.game.implants["legs"] = true
	# pause menu
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	m._unhandled_key_input(ev)
	check("Esc opens the pause menu", m.mode == "pause" and m.screen.visible)
	var pl = m.screen.items.map(func(i): return i["label"])
	check("pause offers Save, Load, Character & Map, Options", "Save Game" in pl and "Load Game" in pl and "Character & Map" in pl and "Options" in pl)
	key(m, KEY_DOWN); key(m, KEY_ENTER)
	check("Save Game shows the slots", m.mode == "saves" and m.screen.items.size() == 4)
	key(m, KEY_DOWN); key(m, KEY_ENTER)
	check("saving to slot 2 writes the file", FileAccess.file_exists("user://test_save_2.json") and m.slot_meta(2).contains("Body"))
	key(m, KEY_ESCAPE)
	check("Esc returns to the pause menu", m.mode == "pause")
	# the character tabs: equipment, implants, skills, map
	m.tab_from = "pause"
	m.open_screen("equipment")
	check("the equipment tab opens", m.mode == "equipment" and m.screen.kind == "equipment")
	key(m, KEY_PERIOD)
	check("> steps to the implants tab", m.mode == "implants")
	key(m, KEY_PERIOD)
	check("> steps to the skills tab", m.mode == "skills" and m.screen.sk_sel == 0)
	key(m, KEY_RIGHT)
	check("Right moves along the attributes", m.screen.sk_sel == 1)
	key(m, KEY_KP_2)
	check("numpad 2 moves down into the skills", m.screen.sk_sel >= 5)
	var sel0: int = m.screen.sk_sel
	key(m, KEY_DOWN)
	check("Down moves to the next skill", m.screen.sk_sel == sel0 + 1)
	var rc: Rect2 = m.screen.sk_rects(1280.0, 720.0 - m.screen.TAB_H)[12]
	var mm := InputEventMouseMotion.new()
	mm.position = (rc.get_center() + Vector2(0, m.screen.TAB_H)) * m.UI_S
	m._unhandled_input(mm)
	check("the mouse highlights a line", m.screen.sk_sel == 12)
	await process_frame
	key(m, KEY_PERIOD)
	check("> steps to the map tab", m.mode == "map")
	check("the map tab opens on the local map", m.screen.map_local and m.screen.local_tex != null)
	key(m, KEY_TAB)
	check("Tab switches to the island map", not m.screen.map_local)
	key(m, KEY_TAB)
	key(m, KEY_PERIOD)
	check("> wraps round to the equipment tab", m.mode == "equipment")
	key(m, KEY_COMMA)
	check("< steps back to the map tab", m.mode == "map")
	key(m, KEY_ESCAPE)
	check("Esc leaves the tabs back to the pause menu", m.mode == "pause")
	m.resume_play()
	for pair in [[KEY_P, "equipment"], [KEY_I, "implants"], [KEY_O, "skills"], [KEY_M, "map"]]:
		var kev := InputEventKey.new()
		kev.keycode = pair[0]
		kev.pressed = true
		if m.mode != "play" and m.mode != pair[1]:
			m._unhandled_key_input(kev)
		else:
			m._unhandled_key_input(kev)
		check("%s opens the %s tab" % [OS.get_keycode_string(pair[0]), pair[1]], m.mode == pair[1])
	var kev2 := InputEventKey.new()
	kev2.keycode = KEY_M
	kev2.pressed = true
	m._unhandled_key_input(kev2)
	check("the tab's own key closes it, back into the game", m.mode == "play")
	var so := InputEventKey.new()
	so.keycode = KEY_O
	so.shift_pressed = true
	so.pressed = true
	m._unhandled_key_input(so)
	check("Shift+O is shove, not the skills screen", m.mode == "shove")
	var esc0 := InputEventKey.new()
	esc0.keycode = KEY_ESCAPE
	esc0.pressed = true
	m._unhandled_key_input(esc0)
	check("Esc cancels the shove", m.mode == "play")
	check("the old function keys are free: F3 and F7 are not bound", m.settings.action_for(KEY_F3) == "" and m.settings.action_for(KEY_F7) == "")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	m._unhandled_key_input(esc)
	check("Esc in play opens the pause menu again", m.mode == "pause")
	# change the world, then load slot 2
	m.game.yen = 1
	m.game.pc = pc0
	key(m, KEY_ESCAPE)
	check("Esc resumes play", m.mode == "play")
	m.begin_load(2)
	for i in 60:
		await process_frame
		if m.mode == "play" and m.game.yen == 4321:
			break
	check("loading slot 2 restores the game", m.mode == "play" and m.game.yen == 4321 and m.game.has_implant("legs"))
	# a real key press still moves with the new binding
	m.settings.rebind("fire", KEY_F)
	var before: int = m.game.turn
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_PERIOD
	ev2.pressed = true
	m._unhandled_key_input(ev2)
	check("keys still act in play", m.game.turn == before + 1)
	# sounds queued by the game reach the player
	m.game.sfx("shot")
	m.refresh()
	check("sound events are drained", m.game.sfx_queue.is_empty())
	print("MENUS %d/%d" % [passed, total])
	quit(0 if passed == total else 1)
