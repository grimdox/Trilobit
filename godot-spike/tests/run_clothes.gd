extends SceneTree
## Clothes: little armor, +1 to social skills while worn (not in a pack), sold by vendors.  Run: TRL_STREET=1 godot --headless --path . -s tests/run_clothes.gd
const GameScript = preload("res://src/game.gd")
const DS = preload("res://src/dollspec.gd")
const ADAPT = preload("res://addons/trilobit_doll/trilobit_adapter.gd")
const LIB = preload("res://addons/trilobit_doll/doll_library.gd")
var ok := 0
var n := 0
func check(name: String, cond: bool) -> void:
	n += 1
	if cond:
		ok += 1
	print(("  PASS " if cond else "  FAIL ") + name)

func _initialize() -> void:
	var g = GameScript.new(5)
	g.setup(300)
	var ids: Array = []
	for k in g.db.defs:
		if String(k).begins_with("trl_cl_"):
			ids.append(k)
	check("there is a wardrobe of at least 15 pieces (%d)" % ids.size(), ids.size() >= 15)
	var cool := 0
	var social := 0
	var armored := 0
	var rich_ok := true
	for k in ids:
		var d: Dictionary = g.db.defs[k]
		var ar: int = int(d["armor"]["phys"])
		if d.has("social"):
			social += 1
		else:
			cool += 1
		if ar > 0:
			armored += 1
		if ar > 2:
			rich_ok = false
		if ar == 2 and not (d.has("social") and int(d["price"]) >= 500):
			rich_ok = false
	check("some clothes only look cool (%d), most help with social skills (%d), a few carry armor (%d); none above 2, and 2 is high-end with social" % [cool, social, armored], cool >= 3 and social >= 8 and armored >= 4 and rich_ok)
	var e0: int = g.lvl("etiquette")
	var n0: int = g.lvl("negotiation")
	var sw0: int = g.lvl("streetwise")
	var blazer = g._new_item("trl_cl_blazer")
	g.inv.stow(blazer)
	check("a blazer in the pack does nothing", g.lvl("etiquette") == e0)
	check("wearing it adds +1 Etiquette", g.act_wear(blazer) and g.lvl("etiquette") == e0 + 1 and g.lvl("negotiation") == n0)
	g.inv.auto_unequip("chest")
	var suit = g._new_item("trl_cl_armored_suit")
	g.inv.stow(suit)
	g.act_wear(suit)
	check("the armored business suit gives +1 Etiquette and Negotiation and armor 2 on the chest", g.lvl("etiquette") == e0 + 1 and g.lvl("negotiation") == n0 + 1 and g.armor_value("chest") == 2)
	var shades = g._new_item("trl_cl_shades")
	g.inv.stow(shades)
	g.act_wear(shades)
	check("shades add Streetwise on top", g.lvl("streetwise") == sw0 + 1 and g.lvl("etiquette") == e0 + 1)
	g.eco.shop_kind[3] = "clothing"
	g.eco.shop_tier[3] = 2
	var cs: Array = g.eco._stock(3)
	check("a clothing store sells clothes and nothing but (%d lines)" % cs.size(), cs.size() >= 15 and cs.all(func(x): return String(x[0]).begins_with("trl_cl_")))
	g.eco.shop_tier[3] = 0
	check("a poor store only sells the cheap pieces", g.eco._stock(3).all(func(x): return int(x[2]) <= 90))
	# the doll: every piece is drawn on the player, in its own colours
	var lib = LIB.shared("res://gfx/dolls")
	var missing: Array = []
	for k in ids:
		var layer: String = String(DS.ARMOR_LAYER.get(k, ""))
		var ok2: bool = layer != "" and lib.man.get("clothes", {}).has(layer)
		if ok2:
			for gid in lib.man["clothes"][layer]["garments"]:
				ok2 = ok2 and lib.man["garments"].has(gid)
		if not ok2:
			missing.append(k)
	check("every piece of clothing has doll garments in the baked set (%s)" % str(missing), missing.is_empty())
	var pd: Dictionary = DS.for_player(g)
	var spec = ADAPT.spec_from_game(pd["layers"], pd["look"], "", "m", "res://gfx/dolls")
	check("the player wearing the armored suit and shades shows them (%s)" % str(spec.garments),
		"suit_armored" in spec.garments and "tie" in spec.garments and "shades" in spec.garments and spec.colours.get("cloth2", "") == "charcoal")
	print("CLOTHES %d/%d" % [ok, n])
	quit(0 if ok == n else 1)
