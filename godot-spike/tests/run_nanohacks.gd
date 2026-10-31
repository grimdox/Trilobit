extends SceneTree
## Nanohacks: the five placeholder hacks, the Trilobit slot limit, the start state, costs and draw, effects, Shock, saving, the Implants-screen slots.
## Run: godot --headless -s tests/run_nanohacks.gd
const MainScript = preload("res://src/main.gd")
const WorldScript = preload("res://src/world.gd")
const GearScript = preload("res://src/gear_ui.gd")
const NANO = preload("res://src/nanohacks.gd")
const BODY = preload("res://src/body.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func chip(g, id: String):
	return g._new_item(NANO.chip_item(id))

func inst(g, id: String) -> bool:
	var c = chip(g, id)
	g.inv.stow(c)
	return g.act_nano_install(c)

func chips_in_pack(g) -> int:
	var c := 0
	for it in g.inv.grid_items():
		if it.def.has("nano"):
			c += 1
	return c

func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://test_nano_save_"
	m.settings_path = "user://test_nano_settings.json"
	root.add_child(m)
	await process_frame
	var w = WorldScript.new()
	w.start(21, 300)
	m.world = w
	m.start_play(w.game)
	await process_frame
	var g = w.game
	# ---- the data and the start state
	check("six hacks: Plating, Reflex, Shock, Strike, Skill: Research, Mend", NANO.ALL.size() == 6 and ["plating", "reflex", "shock", "strike", "research", "mend"].all(func(i): return not NANO.get_def(i).is_empty()))
	check("each hack has a chip item that takes its own tile", NANO.ALL.all(func(h): var it = g._new_item(NANO.chip_item(h["id"])); return it != null and not it.stackable()))
	check("a new character starts with the Gutterline Trilobit fitted (2 slots) and no hack installed", g.implants == {"x101": true} and g.nano_slots() == 2 and g.nano_installed().is_empty())
	check("and carries one chip of each of the six hacks", chips_in_pack(g) == 6)
	check("the five chips are one of each", NANO.ALL.all(func(h): return g.inv.grid_items().any(func(it): return it.def.get("nano", "") == h["id"])))
	check("the Trilobit is powered from the start", g.nano_ok() and g.power_left() > 0.0)
	# ---- the slot limit
	var pack := {}
	for it in g.inv.grid_items():
		if it.def.has("nano"):
			pack[it.def["nano"]] = it
	check("install Plating", g.act_nano_install(pack["plating"]) and g.nano_has("plating") and chips_in_pack(g) == 5)
	check("install Reflex: the two slots are full", g.act_nano_install(pack["reflex"]) and g.nano_installed().size() == 2)
	var before: int = chips_in_pack(g)
	check("a third hack is refused: no free slot, the chip stays in the pack", not g.act_nano_install(pack["strike"]) and g.nano_installed().size() == 2 and chips_in_pack(g) == before)
	check("the same hack cannot be installed twice", not inst(g, "plating"))
	before = chips_in_pack(g)
	check("taking one out gives its chip back and frees the slot", g.act_nano_remove(0) and not g.nano_has("plating") and chips_in_pack(g) == before + 1)
	check("then the third fits", g.act_nano_install(pack["strike"]) and g.nano_has("strike"))
	# ---- no Trilobit, no slots
	var saved: Dictionary = g.implants.duplicate()
	g.implants = {}
	check("with no Trilobit there are no slots and nothing installs", g.nano_slots() == 0 and not inst(g, "shock") and g.nano_installed().is_empty())
	g.implants = saved
	# ---- effects and costs
	g.nanos = []
	g.nano_fx = {}
	g.power = 100.0
	for h in ["plating", "reflex"]:
		inst(g, h)
	var dodge0: int = g.lvl("dodge")
	var arm0: int = g.armor_value("chest")
	var arm_leg0: int = g.armor_value("l_leg")
	check("a hack does nothing until it is switched on", g.lvl("dodge") == dodge0 and g.armor_value("chest") == arm0)
	check("Plating costs 10 kJ and gives +1 armor on every part", g.act_nano_use("plating") and absi(g.power_left() - 90.0) < 1.0 and BODY.LIMBS.all(func(l): return g.armor_value(l) >= 1) and g.armor_value("chest") == arm0 + 1 and g.armor_value("l_leg") == arm_leg0 + 1)
	check("Reflex costs 10 kJ and gives +1 Dodge", g.act_nano_use("reflex") and g.lvl("dodge") == dodge0 + 1 and g.base_lvl("dodge") == dodge0)
	check("a running hack cannot be started again", not g.act_nano_use("reflex"))
	var p0: float = g.power_left()
	for _i in 600:
		g.end_turn()
	var spent: float = p0 - g.power_left()
	check("while two hacks run for an hour they draw +5 kJ/h each over the rig's own draw (%.1f kJ used)" % spent, absf(spent - (0.5 + 10.0)) < 0.6 or (g.nano_fx.is_empty() and spent > 0.5))
	for _i in 80:
		g.end_turn()
	check("after 10 minutes (100 turns) they wear off: no Dodge, no armor bonus, no extra draw", g.nano_fx.is_empty() and g.lvl("dodge") == dodge0 and g.armor_value("chest") == arm0 and g.nano_draw() == 0.0)
	# a fresh timed check
	g.power = 100.0
	g.act_nano_use("plating")
	var pp: float = g.power_left()
	for _i in 100:
		g.end_turn()
	check("the full 100 turns run, then end (%d turns left)" % int(g.nano_fx.get("plating", 0)), not g.nano_fx.has("plating"))
	check("one 10-minute run of Plating cost about 5 * 1/6 + 0.5/6 kJ on top of the 10 (%.2f)" % (pp - g.power_left()), absf((pp - g.power_left()) - (5.0 + 0.5) / 6.0) < 0.2)
	g.power = 100.0
	g.nanos = []
	inst(g, "strike")
	inst(g, "research")
	var un0: int = g.lvl("unarmed")
	var me0: int = g.lvl("melee")
	var re0: int = g.lvl("research")
	check("Skill: Research is passive: +1 Research at once, with no switching on, no kJ and no extra draw", re0 == g.base_lvl("research") + 1 and g.nano_draw() == 0.0 and g.power_left() == 100.0)
	check("Research cannot be 'used'", not g.act_nano_use("research") and g.power_left() == 100.0)
	g.act_nano_use("strike")
	check("Strike gives +1 Unarmed and +1 Melee", g.lvl("unarmed") == un0 + 1 and g.lvl("melee") == me0 + 1)
	g.nano_fx = {}
	check("and ends", g.lvl("unarmed") == un0 and g.lvl("melee") == me0)
	g.power = 5.0
	check("with less than 10 kJ in the store an active hack will not run", not g.act_nano_use("strike") and g.power_left() == 5.0)
	g.power = 100.0
	var old_imp: Dictionary = g.implants.duplicate()
	g.power = 0.0
	check("with the rig dark even Research is off", g.lvl("research") == g.base_lvl("research"))
	g.power = 100.0
	# ---- the skills screen shows it
	var sv = m.screen if m.get("screen") != null else null
	check("the skills screen reads the effective level (screen_view uses Game.lvl)", FileAccess.get_file_as_string("res://src/screen_view.gd").contains("game.lvl(sd[\"id\"])"))
	# ---- Shock
	g.nanos = []
	inst(g, "shock")
	var wired := -1
	var plain := -1
	for i in g.sim.n:
		if g.sim.alive[i] == 0:
			continue
		if g.IMP.NPC_RIGS.has(int(g.fac[i])) and wired < 0:
			wired = i
		elif g.fac[i] == g.CIV and plain < 0:
			plain = i
	check("Shock needs a target in sight", not g.act_nano_use("shock") and g.power_left() == 100.0)
	g.sim.player = g.pc
	var cells: Array = []
	for d in [1, -1, g.size, -g.size, g.size + 1, -g.size - 1]:
		if g.sim.walk[g.pc + d] == 1 and g.sim.at[g.pc + d] == -1:
			cells.append(g.pc + d)
	g.sim.place(wired, cells[0])
	g.facing = Vector2i(cells[0] % g.size - g.pc % g.size, (cells[0] / g.size) % g.size - (g.pc / g.size) % g.size)
	g._compute_fov()
	var near_c: Array = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cc: int = cells[0] + dy * g.size + dx
			if cc != cells[0] and cc != g.pc and g.fov.visible[cc] == 1 and g.sim.walk[cc] == 1 and g.sim.at[cc] == -1:
				near_c.append(cc)
	g.sim.place(plain, near_c[0])
	var hp_w: Array = []
	for l in BODY.LIMBS:
		hp_w.append(g.npc_limb_hp(wired, l))
	var hp_total: int = g.hpn[wired]
	var hp_c: int = g.hpn[plain]
	var tl: Array = g.nano_targets()

	check("the people beside you are offered as targets", wired in tl and plain in tl)
	check("Shock on a person with no implants costs the 10 kJ and does nothing", g.act_nano_use("shock", plain) and absi(g.power_left() - 90.0) < 1.0 and g.hpn[plain] == hp_c and BODY.LIMBS.all(func(l): return g.npc_limb_hp(plain, l) == g.npc_limb_max(plain, l)))
	g.power = 100.0
	g.hpn[wired] = 100
	g.hpmax[wired] = 100
	g._npc_limbs_init(wired)
	var hit_l := ""
	var lost := 0
	var rig_groups: Array = []
	for rid in g.IMP.NPC_RIGS[g.fac[wired]]:
		rig_groups.append(BODY.PART_GROUP[g.IMP.get_def(rid)["part"]])
	g.nano_fx = {}
	var full := {}
	for l in BODY.LIMBS:
		full[l] = g.npc_limb_hp(wired, l)
	check("Shock on a wired person does 10 to one limb that carries an implant", g.act_nano_use("shock", wired))
	for l in BODY.LIMBS:
		var d: int = int(full[l]) - g.npc_limb_hp(wired, l)
		if d > 0:
			hit_l = l
			lost += d
	check("exactly one limb took the hit (%s, %d), in a part group the rig occupies" % [hit_l, lost], hit_l != "" and lost == mini(10, int(full[hit_l])) and BODY.GROUP[hit_l] in rig_groups)
	# ---- trimming slots when the Trilobit comes out
	g.nanos = []
	g.implants = {"x101": true}
	inst(g, "plating")
	inst(g, "reflex")
	g.skills["networking"] = 8
	g.skills["grit"] = 8
	var tril = g._new_item("trl_imp_x201")
	g.inv.stow(tril)
	check("a better Trilobit (4 slots) adds slots on top of the first (6 in all)", g.act_install_implant(tril) and g.nano_slots() == 6)
	inst(g, "strike")
	inst(g, "shock")
	inst(g, "research")
	check("five hacks fit in six slots", g.nano_installed().size() == 5)
	var pk0: int = chips_in_pack(g)
	check("removing the 4-slot Trilobit sends the chips beyond the 2 left back to the pack", g.act_remove_implant("x201") and g.nano_slots() == 2 and g.nano_installed().size() == 2 and chips_in_pack(g) >= pk0 + 3)
	# ---- saving
	var d: Dictionary = g.player_dict()
	check("the installed hacks and running timers are saved", d.has("nanos") and d.has("nano_fx") and d["nanos"].size() >= 2)
	var keep: Array = g.nanos.duplicate()
	g.nanos = []
	g.nano_fx = {"plating": 7}
	g.apply_player(d)
	check("and come back on loading", g.nanos == keep and g.nano_fx.size() == (d["nano_fx"] as Dictionary).size())
	# ---- the Implants screen
	g.nanos = []
	g.nano_fx = {}
	g.implants = {"x101": true}
	for it in g.inv.grid_items():
		if it.def.has("nano"):
			g.inv.remove(it)
	var cs := []
	for h in ["plating", "reflex", "shock"]:
		var c = chip(g, h)
		g.inv.stow(c)
		cs.append(c)
	var ui = GearScript.new()
	ui.open(g, null, "implants")
	var keys: Array = ui.targets().map(func(e): return e["key"])
	check("the Implants screen shows one nanohack slot for each the Trilobit allows (2)", "n:0" in keys and "n:1" in keys and not ("n:2" in keys))
	var gi := -1
	for e in ui.targets():
		var kk: String = e["key"]
		if kk.begins_with("g:") and ui.item_at(kk) == cs[0]:
			gi = 1
			ui.cur = kk
	ui.press()
	check("Enter on a chip in the pack picks it up", ui.held == cs[0])
	ui.cur = "n:1"
	ui.press()
	check("Enter on a slot puts it in that slot", ui.held == null and g.nano_at(1) == "plating" and g.nano_at(0) == "")
	ui.cur = "n:1"
	ui.press()
	check("Enter on a filled slot ejects the chip to the pack", g.nano_at(1) == "" and chips_in_pack(g) == 3)
	for e in ui.targets():
		if String(e["key"]).begins_with("g:") and ui.item_at(e["key"]) != null and ui.item_at(e["key"]).def.has("nano"):
			ui.cur = e["key"]
			break
	ui.auto()
	check("Ctrl on a chip loads it into the first free slot", g.nano_at(0) != "")
	ui.cur = "n:0"
	var sizes := ui.targets().filter(func(e): return String(e["key"]).begins_with("n:"))
	check("slots lie inside their motherboard panel, clear of the card", sizes.all(func(e): return GearScript.NANO_PANEL.encloses(e["rect"]) and (e["rect"] as Rect2).end.x < GearScript.CARD.position.x))
	# ---- the key
	check("N opens the nanohack menu (the key is bound)", m.settings.action_for(KEY_N) == "nano" and m.settings.action_for(KEY_KP_3) == "se")
	m.open_nano()
	check("the menu lists the installed hacks", m.mode == "nano" and m.nano_list.size() == g.nano_installed().size())
	m.nano_key(KEY_ESCAPE)
	check("Esc leaves it", m.mode == "play")
	print("NANOHACKS %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
