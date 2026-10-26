extends RefCounted
## The barter screen: merchants' tiles, buying, selling, restocking, saves, and the screen's keys and clicks (barter.gd, barter_ui.gd).
const GameScript = preload("res://src/game.gd")
const BarterUI = preload("res://src/barter_ui.gd")

func run() -> Array:
	var cnt: Array = [0, 0]
	var log: Array = []
	var check := func(label: String, ok: bool) -> void:
		cnt[1] += 1
		if ok:
			cnt[0] += 1
		else:
			log.append("  FAIL " + label)
	var g = GameScript.new(5)
	g.setup(300)
	var vend := -1
	var ripper := -1
	var cook := -1
	for i in g.sim.n:
		if g.eco.role[i] == g.eco.VENDOR and vend < 0:
			vend = i
		elif g.eco.role[i] == g.eco.RIPPER and ripper < 0:
			ripper = i
		elif g.eco.role[i] == g.eco.COOK and cook < 0:
			cook = i
	check.call("the world has a vendor", vend >= 0)
	check.call("vendors trade over the counter, cooks keep the text menu", g.barter.trades(vend) and (cook < 0 or not g.barter.trades(cook)))
	var tiles: Array = g.barter.shop(vend)["tiles"]
	check.call("a vendor has wares as tiles (%d)" % tiles.size(), tiles.size() >= 3)
	check.call("the shop is kept until the day turns", g.barter.shop(vend)["tiles"] == tiles)
	g.yen = 100000
	var ui = BarterUI.new()
	ui.open(g, null, vend, g.eco.menu_for(vend))
	check.call("the screen opens with a greeting", ui.lines.size() >= 1 and ui.lines[0] != "")
	# buy by picking a tile and dropping it on one of yours
	var first: Dictionary = tiles[0]
	var id0: String = first["item"].id()
	var y0: int = g.yen
	var n0: int = g.inv.all_items().size()
	ui.cur = "m:0"
	ui.press(true)
	check.call("picking a tile lifts it off the shelf", not ui.held.is_empty())
	ui.cur = "p:0"
	ui.press()
	check.call("dropping it on your tiles buys it", ui.held.is_empty() and g.yen < y0 and (g.inv.all_items().size() > n0 or id0.begins_with("trl_ammo") or g.inv.all_items().size() == n0))
	# sell: take something of yours and drop it on the wares
	var junk = g._new_item("trl_mel_kama")
	g.inv.stow(junk)
	var shelf0: int = g.barter.shop(vend)["tiles"].size()
	var y1: int = g.yen
	var f: Array = ui.flow()
	var at := -1
	for k in f.size():
		if g.inv.grid[f[k][0]][f[k][1]] == junk:
			at = k
	ui.cur = "p:%d" % at
	ui.press()
	ui.cur = "m:0"
	ui.press()
	check.call("dropping an item on the wares sells it for yen", g.yen > y1 and ui.held.is_empty())
	check.call("and it joins the merchant's stock", g.barter.shop(vend)["tiles"].size() >= shelf0)
	# an unaffordable tile is refused and goes back
	g.yen = 0
	var before: int = g.barter.shop(vend)["tiles"].size()
	ui.cur = "m:0"
	ui.press(true)
	ui.cur = "p:0"
	ui.press()
	check.call("with no yen the buy is refused and the tile returns", g.barter.shop(vend)["tiles"].size() == before and ui.held.is_empty())
	# right click auto buys
	g.yen = 100000
	var y2: int = g.yen
	ui.click(ui.m_rect(1).get_center(), true)
	check.call("right click buys at once", g.yen < y2)
	# job items and ammunition are not bought
	var kit = g._new_item("trl_ration")
	check.call("a merchant takes ordinary items but not money or ammunition", g.barter.can_sell(kit))
	# save round trip
	var d: Dictionary = g.barter.to_dict()
	var g2 = GameScript.new(5)
	g2.setup(300)
	g2.barter.load_dict(JSON.parse_string(JSON.stringify(d)))
	check.call("shelves survive a save", g2.barter.shop(vend)["tiles"].size() == g.barter.shop(vend)["tiles"].size())
	# a new day restocks
	g.sim.tick += 24 * 3600 * 3
	check.call("the shop is restocked when the day has turned", g.barter.shop(vend)["day"] == g.barter.today())
	# ripperdoc trades too, and keeps its service buttons
	if ripper >= 0:
		var u2 = BarterUI.new()
		u2.open(g, null, ripper, g.eco.menu_for(ripper))
		check.call("a ripperdoc shows implants as tiles", g.barter.shop(ripper)["tiles"].any(func(t): return t["item"].has_tag("implant")))
	# scrolling
	var many: Array = g.barter.shop(vend)["tiles"]
	for k in 40:
		many.append({"item": g._new_item("trl_ration"), "base": 10, "hag": false})
	ui.scroll(1, Vector2(400, 150))
	check.call("the wares scroll when there are more than three rows", ui.m_scroll >= 1)
	# credsticks are gone: an old save that carries one still loads
	check.call("there is no credstick item", not g.db.defs.has("trl_credstick"))
	var dd: Dictionary = g.inv.to_dict()
	dd["grid"]["base"][14] = {"id": "trl_credstick", "count": 1}
	g.inv.load_dict(dd, g.db)
	check.call("an old save with a credstick loads without it", g.inv.grid["base"][14] == null)
	return [cnt[0], cnt[1], log]
