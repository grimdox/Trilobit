extends SceneTree
## Headless checks of the baked set and the runtime.  godot --headless --path . -s tests/run_tests.gd
## Prints one line per check and "DOLLS passed/total"; exit code 0 only when all pass.

const LIB = preload("res://addons/trilobit_doll/doll_library.gd")
const PAL = preload("res://addons/trilobit_doll/doll_palette.gd")
const SPEC = preload("res://addons/trilobit_doll/doll_spec.gd")
const GEN = preload("res://addons/trilobit_doll/doll_generator.gd")
const RIG = preload("res://addons/trilobit_doll/doll_rig.gd")
const ADAPT = preload("res://addons/trilobit_doll/trilobit_adapter.gd")

var passed := 0
var total := 0

func check(name: String, ok: bool, detail := "") -> void:
	total += 1
	if ok:
		passed += 1
	print(("  PASS " if ok else "  FAIL ") + name + ("" if ok or detail == "" else "  -- " + detail))

func _initialize() -> void:
	# the set to check: res://dolls (64 px) by default, or the first user argument (res://dolls32)
	var args := OS.get_cmdline_user_args()
	var set_path: String = args[0] if args.size() > 0 else "res://dolls"
	print("set ", set_path)
	var lib = LIB.new(set_path)
	check("the baked set loads (manifest, index pages, colour pages)", lib.ok and lib.idx_pages.size() > 0 and lib.rgba_pages.size() > 0, lib.error)
	if not lib.ok:
		_end()
		return
	var man: Dictionary = lib.man
	# ---------------------------------------------------------------- palette port
	var pt: Dictionary = man["palette"]
	var bad := []
	for c in pt["ramp_checks"]:
		var mine := PAL.ramp(c)
		if Array(mine) != Array(pt["ramp_checks"][c]):
			bad.append("%s: %s vs %s" % [c, mine, pt["ramp_checks"][c]])
	for c in pt["ramp_checks_glow"]:
		if Array(PAL.glow_ramp(c)) != Array(pt["ramp_checks_glow"][c]):
			bad.append("glow " + c)
	check("the OKLab ramp port matches the generator exactly", bad.is_empty(), str(bad.slice(0, 2)))
	bad = []
	for pc in pt["palette_checks"]:
		var rows := PAL.palette_rows(pc[0], pt)
		for r in rows.size():
			if Array(rows[r]) != Array(pc[1][r]):
				bad.append("row %d of %s" % [r, pc[0]])
	check("whole palettes match the generator for every reference colour choice", bad.is_empty(), str(bad.slice(0, 3)))
	var tex: ImageTexture = PAL.texture_for({}, pt)
	check("the palette texture is 8 x 32 with an empty index 0", tex.get_width() == 8 and tex.get_height() == 32 and tex.get_image().get_pixel(0, 0).a == 0.0)
	# ---------------------------------------------------------------- coverage
	var bodies: Array = man["bodies"].keys()
	var missing := []
	var nframes := 0
	for b in bodies:
		for fid in man["frames"][b]:
			nframes += 1
			for layer in ["body", "near", "hands"]:
				for pre in ["b", "a"]:
					if not lib.sprites.has("%s/%s/%s/%s" % [pre, b, fid, layer]):
						missing.append("%s/%s/%s/%s" % [pre, b, fid, layer])
	check("every frame of every body has its body, near-arm and hand layers (human and android)", missing.is_empty(), str(missing.slice(0, 4)))
	missing = []
	for b in bodies:
		for sh in man["eye_shapes"]:
			for ex in man["expressions"]:
				if not lib.sprites.has("f/%s/%s/%s" % [b, sh, ex]):
					missing.append("f/%s/%s/%s" % [b, sh, ex])
	check("every body has every eye shape in every expression", missing.is_empty(), str(missing.slice(0, 4)))
	missing = []
	var holds := 0
	for b in bodies:
		for fid in man["frames"][b]:
			var fm: Dictionary = man["frames"][b][fid]
			if not fm.has("hold"):
				continue
			var grip := String(fid).split("/")[0]
			for it in man["items"]:
				if man["items"][it] == grip:
					holds += 1
					if not lib.sprites.has("held/%s/%s" % [it, fm["hold"]]):
						missing.append("held/%s/%s" % [it, fm["hold"]])
	check("every item has a sprite for every hold its stance uses (%d checked)" % holds, missing.is_empty() and holds > 0, str(missing.slice(0, 4)))
	missing = []
	for b in bodies:
		for st in man["hair"]:
			if st == "bald":
				continue
			var any := false
			for fid in man["frames"][b]:
				if lib.sprites.has("h/%s/%s/%s/head" % [b, fid, st]):
					any = true
					break
			if not any:
				missing.append("%s %s" % [b, st])
	check("every hair style draws on every body", missing.is_empty(), str(missing.slice(0, 4)))
	missing = []
	for b in bodies:
		for gid in man["garments"]:
			var any2 := false
			for fid in man["frames"][b]:
				for grp in man["groups"]:
					if lib.sprites.has("g/%s/%s/%s/%s" % [b, fid, gid, grp]):
						any2 = true
				if any2:
					break
			if not any2:
				missing.append("%s %s" % [b, gid])
	check("every garment draws on every body", missing.is_empty(), str(missing.slice(0, 4)))
	missing = []
	for b in bodies:
		for iid in man["implants"]:
			var any3 := false
			for fid in man["frames"][b]:
				for grp in man["groups"]:
					if lib.sprites.has("i/%s/%s/%s/%s" % [b, fid, iid, grp]):
						any3 = true
				if any3:
					break
			if not any3:
				missing.append("%s %s" % [b, iid])
	check("every implant draws on every body", missing.is_empty(), str(missing.slice(0, 4)))
	var anim_ok := true
	for an in man["anims"]:
		var a: Dictionary = man["anims"][an]
		if a["dur"].size() != int(a["frames"]):
			anim_ok = false
	check("every animation has a duration per frame", anim_ok and man["down"]["dur"].size() == int(man["down"]["frames"]))
	# ---------------------------------------------------------------- composition
	var s = SPEC.from_dict({"body": bodies[0], "garments": ["under", "bodysuit", "boots", "trench", "vest_heavy"], "hair": "bob", "implants": ["optic_r", "mantis"],
		"item": "trl_gun_vk74" if man["items"].has("trl_gun_vk74") else ""})
	var fid0: String = man["frames"][bodies[0]].keys()[0]
	var c1 := lib.compose(s, fid0)
	var c2 := lib.compose(s, fid0)
	var sorted_ok := true
	for i in range(1, c1.size()):
		if c1[i]["order"] < c1[i - 1]["order"]:
			sorted_ok = false
	var same := c1.size() == c2.size()
	for i in c1.size():
		if same and c1[i]["key"] != c2[i]["key"]:
			same = false
	check("composition is sorted back to front and deterministic (%d sprites)" % c1.size(), sorted_ok and same and c1.size() > 8)
	var keys := []
	for e in c1:
		keys.append(e["key"])
	var ib := keys.find("b/%s/%s/body" % [bodies[0], fid0])
	var ic := -1
	var ih := -1
	for i in keys.size():
		if String(keys[i]).begins_with("g/") and "/trench/body" in String(keys[i]):
			ic = i
		if String(keys[i]).begins_with("h/") and String(keys[i]).ends_with("/head"):
			ih = i
	check("skin under the coat, the coat under the hair", ib >= 0 and ic > ib and ih > ic, "%d %d %d" % [ib, ic, ih])
	var hood = SPEC.from_dict({"body": bodies[0], "garments": ["under", "tee", "hood_up"], "hair": "long"})
	var ch := lib.compose(hood, fid0)
	var hair_drawn := false
	for e in ch:
		if String(e["key"]).begins_with("h/"):
			hair_drawn = true
	check("a hood (hides hair) hides the hair", not hair_drawn)
	# ---------------------------------------------------------------- generator
	var gen = GEN.new(lib)
	var det := true
	var valid := true
	var fallbacks := 0
	var repairs := 0
	var reasons := {}
	var arch_seen := {}
	var problems := []
	for seed_value in range(1, 401):
		var g1 = gen.generate(seed_value)
		var g2 = gen.generate(seed_value)
		if g1.look_key() != g2.look_key():
			det = false
		arch_seen[g1.meta["archetype"]] = true
		var v: Array = gen.validate(g1, GEN.ARCH[g1.meta["archetype"]])
		if not v.is_empty():
			valid = false
			problems.append([seed_value, v])
		for l in g1.meta["log"]:
			repairs += 1
			var r := String(l).split(":")[0]
			reasons[r] = reasons.get(r, 0) + 1
			if String(l).begins_with("fallback"):
				fallbacks += 1
	check("generation is deterministic (400 seeds, generated twice)", det)
	check("every generated doll passes every rule after repair", valid, str(problems.slice(0, 2)))
	check("no generated doll needed the fallback look", fallbacks == 0, "%d fallbacks" % fallbacks)
	check("all seven archetypes come up", arch_seen.size() == GEN.ARCH.size(), str(arch_seen.keys()))
	print("    repairs in 400 dolls: %d %s" % [repairs, reasons])
	var by_arch := true
	for a in GEN.ARCH:
		var g3 = gen.generate(7, a)
		if g3.meta["archetype"] != a or not gen.validate(g3, GEN.ARCH[a]).is_empty():
			by_arch = false
	check("each archetype can be asked for by name", by_arch)
	var conflict = SPEC.from_dict({"body": bodies[0], "garments": ["under", "tee", "shirt"], "implants": ["optic_r", "optic_twin"], "colours": {"cloth2": "red coat"}})
	var vv: Array = gen.validate(conflict, GEN.ARCH["resident"])
	var rules := {}
	for x in vv:
		rules[x[0]] = true
	check("the validator catches two tops (R1), two optics in one eye (R2), danger red on a resident (R4)", rules.has("R1") and rules.has("R2") and rules.has("R4"), str(vv))
	# ---------------------------------------------------------------- adapter (the game's current look data)
	var gs = ADAPT.spec_from_game(["jacket_3", "vest", "helmet_ball", "imp_optics", "imp_mantis"], {"fem": true, "skin_i": 2, "hair_i": 6, "eye_i": 3, "style": "bob",
		"eye_shape": "almond"}, "trl_gun_sp45", "m", set_path)
	check("the game adapter maps outfits, worn items, implants, colours and the weapon", "bomber" in gs.garments and "vest" in gs.garments and "helmet_ball" in gs.garments
		and "optic_r" in gs.implants and "mantis" in gs.implants and gs.body.begins_with("f_") and gs.colours.get("hair") == "cyan dye" and gs.item == "trl_gun_sp45",
		str(gs.to_dict()))
	# ---------------------------------------------------------------- rig
	var rig = RIG.new()
	rig.lib = lib
	rig.set_spec(s)
	root.add_child(rig)
	await process_frame
	var want := []
	for e in lib.compose(s, rig.fid):
		want.append(e["key"])
	check("the rig draws exactly what compose() lists", rig.drawn_keys() == want and want.size() > 0)
	var ev := [0]
	rig.anim_event.connect(func(_a): ev[0] += 1)
	var fin := [0]
	rig.anim_finished.connect(func(_a): fin[0] += 1)
	rig.play("act")
	var start := Time.get_ticks_msec()
	while fin[0] == 0 and Time.get_ticks_msec() - start < 3000:
		await process_frame
	check("a one-shot action fires its strike event once and then finishes", ev[0] == 1 and fin[0] == 1, "events %d finished %d" % [ev[0], fin[0]])
	rig.facing_left = true
	check("facing left mirrors around the feet", rig.scale.x < 0 and rig.scale.y > 0)
	_end()

func _end() -> void:
	print("DOLLS %d/%d" % [passed, total])
	quit(0 if passed == total else 1)
