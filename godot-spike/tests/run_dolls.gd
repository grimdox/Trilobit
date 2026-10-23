extends SceneTree
## The layered dolls in the game: both sets load, every kind of person the game describes becomes a doll that draws,
## the colours the creation screen offers reach the doll, and the view uses the new dolls.  Run: godot --headless -s tests/run_dolls.gd
const DS = preload("res://src/dollspec.gd")
const CR = preload("res://src/creation.gd")
const DIMG = preload("res://addons/trilobit_doll/doll_image.gd")
const ADAPT = preload("res://addons/trilobit_doll/trilobit_adapter.gd")
const ViewScript = preload("res://src/view.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool, detail := "") -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name + ("" if cond or detail == "" else "  -- " + detail))

func _opaque(img: Image) -> int:
	var c := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				c += 1
	return c

func _initialize() -> void:
	var w = DIMG.for_library("res://gfx/dolls32")
	var c = DIMG.for_library("res://gfx/dolls")
	check("the 32 px world set and the 64 px creation set load", w.ok() and c.ok() and int(w.lib.man["lod"]) == 32 and int(c.lib.man["lod"]) == 64)
	# every faction's outfit, worn items and implants, with every weapon kind
	var sets := [[0, ["jacket_0"]], [0, ["jacket_5", "backpack"]], [0, ["suit"]], [0, ["overalls", "helmet_ball"]], [0, ["coat"]],
		[1, ["thug", "vest", "bracers", "balaclava"]], [2, ["nap", "visor", "vest_heavy", "greaves"]], [2, ["nap", "helmet_ball", "vest"]],
		[3, ["nasim", "imp_reflex", "imp_optics", "imp_mantis", "imp_cortex", "imp_legs"]], [4, ["jacket_3", "bracers", "balaclava", "vest"]]]
	var weapons := ["", "trl_gun_sp45", "trl_gun_vk74", "trl_mel_katana", "trl_mel_kastet", "trl_kit_repair"]
	var unmapped := []
	var empty := []
	var no_item := []
	for s in sets:
		for wp in weapons:
			var lk := DS.look(7919 * (sets.find(s) + 1) + weapons.find(wp), sets.find(s) % 2 == 1, int(s[0]))
			var ds = ADAPT.spec_from_game(s[1], lk, wp, String(lk["size"]), "res://gfx/dolls32")
			for l in s[1]:
				var id := String(l)
				var m: Dictionary = w.lib.man
				if not (m["outfits"].has(id) or m["worn"].has(id) or (id.begins_with("imp_") and m["implant_game"].has(id.substr(4)))):
					if not (id in unmapped):
						unmapped.append(id)
			if wp != "" and ds.item != wp:
				no_item.append(wp)
			var img: Image = w.image(ds, "%s/idle/0" % ds.grip(w.lib))
			if _opaque(img) < 150:
				empty.append(str(s[1]) + " " + wp)
	check("every game outfit, worn item and implant used here has a doll part", unmapped.is_empty(), str(unmapped))
	check("every weapon kind is held (pistol, rifle, one- and two-handed melee, tool)", no_item.is_empty(), str(no_item))
	check("every faction's people draw a whole doll in every stance", empty.is_empty(), str(empty.slice(0, 3)))
	# the creation screen's choices reach the doll: every skin and eye colour gives a different doll
	var seen := {}
	for si in CR.count("skin"):
		var lk2 := {"fem": false, "skin_i": si, "hair_i": 0, "eye_i": 0, "style": "buzz", "eye_shape": "round"}
		var ds2 = ADAPT.spec_from_game([], lk2, "", "m", "res://gfx/dolls")
		seen[c.image(ds2, "unarmed/idle/0").get_data()] = true
	check("all %d creation skin tones make different dolls" % CR.count("skin"), seen.size() == CR.count("skin"), "%d different" % seen.size())
	seen = {}
	for ei in CR.count("eyes"):
		var lk3 := {"fem": true, "skin_i": 0, "hair_i": 0, "eye_i": ei, "style": "bob", "eye_shape": "almond"}
		seen[c.image(ADAPT.spec_from_game([], lk3, "", "m", "res://gfx/dolls"), "unarmed/idle/0").get_data()] = true
	check("all %d creation eye colours make different dolls" % CR.count("eyes"), seen.size() == CR.count("eyes"), "%d different" % seen.size())
	var v = ViewScript.new()
	check("the view draws people with the layered dolls", v._dolls() != null and v.doll_ready())
	v.free()
	var t0 := Time.get_ticks_usec()
	for k in 40:
		var lk4 := DS.look(104729 * (k + 3), k % 2 == 0, k % 5)
		w.texture(ADAPT.spec_from_game(["jacket_%d" % (k % 6)], lk4, "", String(lk4["size"]), "res://gfx/dolls32"), "unarmed/idle/0")
	var per := (Time.get_ticks_usec() - t0) / 40000.0
	check("a new look composes fast enough for crowds (%.1f ms each)" % per, per < 25.0)
	print("DOLLS %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
