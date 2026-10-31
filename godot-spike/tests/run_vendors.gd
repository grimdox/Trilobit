extends SceneTree
## Vendor variety: each kind of shop sells only its own goods.  Run: TRL_STREET=1 godot --headless --path . -s tests/run_vendors.gd
const GameScript = preload("res://src/game.gd")
const BZ = preload("res://src/business.gd")
var ok := 0
var n := 0
func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _all(s: Array, g, tag: String, pre: String = "") -> bool:
	if s.is_empty():
		return false
	for e in s:
		var id: String = String(e[0])
		if pre != "" and not id.begins_with(pre):
			return false
		if tag != "" and not (tag in g.db.defs[id].get("tags", [])):
			return false
	return true

func _initialize() -> void:
	var g = GameScript.new(5)
	g.setup(300)
	g.eco.shop_tier[3] = 2
	g.eco.shop_kind[3] = "armor_shop"
	var a: Array = g.eco._stock(3)
	check("the armor shop sells armor (and the holster belt)", a.size() >= 20 and a.all(func(x): return String(x[0]).begins_with("trl_armor_") or x[0] == "trl_holster_belt"))
	g.eco.shop_kind[3] = "gun_dealer"
	var gs: Array = g.eco._stock(3)
	check("the gun store sells guns and bullets only", gs.any(func(x): return String(x[0]).begins_with("trl_gun_")) and gs.any(func(x): return String(x[0]).begins_with("trl_ammo")) and gs.all(func(x): return String(x[0]).begins_with("trl_gun_") or String(x[0]).begins_with("trl_ammo")))
	g.eco.shop_kind[3] = "nano_shop"
	var ns: Array = g.eco._stock(3)
	check("the nanohack store sells all six chips and nothing else", ns.size() == 6 and _all(ns, g, "nanohack"))
	g.eco.shop_kind[3] = "pharmacy"
	check("a pharmacy sells healing items", g.eco._stock(3).all(func(x): return String(x[0]).begins_with("trl_heal_") or x[0] == "trl_medkit"))
	g.eco.shop_kind.erase(3)
	var st: Array = g.eco._stock(3)
	check("a street vendor sells no clothes, armor, guns, ammo, blades or chips", not st.any(func(x): var id := String(x[0]); return id.begins_with("trl_cl_") or id.begins_with("trl_armor_") or id.begins_with("trl_gun_") or id.begins_with("trl_ammo") or id.begins_with("trl_mel_") or id.begins_with("trl_nano_")))
	var gr: Array = g.eco._grocery_stock(3)
	check("grocery stores sell bandages, water and food", gr.any(func(x): return x[0] == "trl_heal_bandage") and gr.any(func(x): return x[0] == "trl_water_bottle") and gr.any(func(x): return String(x[0]).begins_with("trl_food_")))
	check("the gun and blade stores stand in the lower districts only", int(BZ.TYPES["gun_dealer"].get("wealth_max", 9)) <= 1 and int(BZ.TYPES["martial_shop"].get("wealth_max", 9)) <= 1)
	check("there is an armor shop and a nanohack store type", BZ.TYPES.has("armor_shop") and BZ.TYPES.has("nano_shop"))
	var kinds := {}
	for i in g.sim.n:
		if g.eco.shop_kind.has(i):
			kinds[g.eco.shop_kind[i]] = true
	check("shop keepers in the city carry their shop kind (%d kinds)" % kinds.size(), kinds.size() >= 4)
	print("VENDORS %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
