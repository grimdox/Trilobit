extends SceneTree
## Ammunition is an Item: one stack per round type (count = rounds), reloaded from the pack, nothing carried loose.
## Run: godot --headless -s tests/run_ammo.gd
const MainScript = preload("res://src/main.gd")
var ok := 0
var n := 0

func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _initialize() -> void:
	var m = MainScript.new()
	m.save_prefix = "user://test_save_"
	m.settings_path = "user://test_settings.json"
	root.add_child(m)
	await process_frame
	m.begin_new(5)
	for i in 30:
		await process_frame
	var g = m.game
	var stacks: Array = g.inv.all_items().filter(func(it): return it.has_tag("ammo"))
	check("a new game starts with one stack of 36 9mm ball rounds in the pack", stacks.size() == 1 and stacks[0].id() == "trl_ammo_9mm_fmj" and stacks[0].count == 36)
	check("there is no loose-round pool any more", not ("ammo_pool" in g))
	check("every round type is its own item", g.ammo_item_id("9mm", "fmj") != g.ammo_item_id("9mm", "ap") and g.ammo_item_id("9mm", "ap") != g.ammo_item_id(".357", "ap") and g.ammo_item_id("9mm", "hp") != "")
	g.pool_add("9mm", "ap", 12)
	var ap_stack: Array = g.inv.all_items().filter(func(it): return it.id() == "trl_ammo_9mm_ap")
	check("armor-piercing rounds are a separate stack of 12", ap_stack.size() == 1 and ap_stack[0].count == 12 and g.pool_get("9mm", "fmj") == 36 and g.pool_get("9mm", "ap") == 12)
	g.pool_add("9mm", "fmj", 10)
	check("more rounds of a type join the same stack (46)", g.inv.all_items().filter(func(it): return it.id() == "trl_ammo_9mm_fmj").size() == 1 and g.pool_get("9mm", "fmj") == 46)
	g.wield.loaded = 0
	g.wield.kind = ""
	g.want_kind = {}
	var mag: int = int(g.gun_stats()["mag"])
	var t0: int = g.pool_get("9mm", "fmj")
	check("a reload takes the rounds out of the stack", g.act_reload() and g.wield.loaded == mag and g.pool_get("9mm", "fmj") == t0 - mag)
	g.pool_add("9mm", "fmj", -g.pool_get("9mm", "fmj"))
	check("an empty stack leaves the pack", g.pool_get("9mm", "fmj") == 0 and g.inv.all_items().filter(func(it): return it.id() == "trl_ammo_9mm_fmj").is_empty())
	# a save from the loose-round days comes in as items
	g._legacy_ammo({"ammo": {"9mm|hp": 20, ".357|fmj": 6}})
	check("rounds from an old save's loose pool become stacks in the pack", g.pool_get("9mm", "hp") == 20 and g.pool_get(".357", "fmj") == 6)
	# no room: they fall at your feet
	for t in g.inv.free_tiles():
		g.inv.stow(g._new_item("trl_gun_zp9"))
	var here0: int = (g.items_at.get(g.pc, []) as Array).size()
	g.pool_add("12ga", "slug", 8)
	check("with no free tile new rounds fall at your feet", (g.items_at.get(g.pc, []) as Array).size() == here0 + 1 and g.pool_get("12ga", "slug") == 0)
	print("AMMO %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
