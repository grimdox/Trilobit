extends RefCounted
## What a merchant has to sell, as tiles, and the rules of trading (the barter screen is barter_ui.gd).
##  - A merchant's stock is a row of tiles, made the first time you trade and kept until the next day, when it is made afresh: anything you
##    sold them goes, anything they have sold is back.  Buying takes tiles out of their stock, selling puts yours into it.
##  - The seller's price is the shop's list price less your haggling (Economy.haggle); a merchant pays 40% of an item's value for it, up to
##    55% for a good haggler.  Merchants have all the yen they need and take anything but job items.
##  - Loose ammunition is not a tile: an ammunition box you buy goes straight into your rounds, and rounds cannot be sold here.
const CLK = preload("res://src/clock.gd")
const ItemScript = preload("res://src/item.gd")

var g                                       # the Game
var shops: Dictionary = {}                  # agent -> {day, tiles: [{item, base, hag}]}

func _init(game) -> void:
	g = game

## does agent i trade from a counter?  (cooks, priests, fixers and the rest talk through menus)
func trades(i: int) -> bool:
	return g.eco != null and int(g.eco.role[i]) in [g.eco.VENDOR, g.eco.GROCER, g.eco.RIPPER, g.eco.DOCTOR]

func today() -> int:
	return CLK.day_of(g.sim.tick)

## the shop of agent i, stocked afresh when the day has turned
func shop(i: int) -> Dictionary:
	var s: Dictionary = shops.get(i, {})
	if s.is_empty() or int(s["day"]) != today():
		s = {"day": today(), "tiles": _stock(i)}
		shops[i] = s
	return s

## [{item, base, hag}] for a merchant: the lines Economy lists, a few of the cheap staples in quantity
func _stock(i: int) -> Array:
	var lines: Array = []
	var r: int = int(g.eco.role[i])
	if r == g.eco.VENDOR:
		lines = g.eco._stock(i)
	elif r == g.eco.GROCER:
		lines = g.eco._grocery_stock(i)
	elif r == g.eco.RIPPER:
		var rv: Dictionary = g.eco.venue_of.get(i, {})
		var cheap: bool = g.z_of(g.sim.pos[i]) < 0 or (not rv.is_empty() and int(rv["tier"]) == 0)
		lines.append(["trl_medkit", "trauma patch", 40])
		for iid in g.eco.ripper_stock(i):
			if not g.implants.get(iid, false) and not g.carries_id("trl_imp_" + String(iid)):
				lines.append(["trl_imp_" + String(iid), g.IMP.get_def(String(iid))["name"], g.IMP.price(iid, cheap), false])
	elif r == g.eco.DOCTOR:
		lines.append(["trl_medkit", "trauma patch", 35])
	var out: Array = []
	for e in lines:
		var it = g._new_item(e[0])
		if it == null:
			continue
		var hag: bool = e.size() < 4 or bool(e[3])
		if it.stackable():
			it.count = 4 if it.has_tag("food") else (2 if it.has_tag("ammo") else 3)
			out.append({"item": it, "base": int(e[2]), "hag": hag})
		else:
			var qty: int = 3 if e[0] == "trl_water_bottle" else 1
			for n in qty:
				var copy = it if n == 0 else g._new_item(e[0])
				if e[0] == "trl_water_bottle":
					copy.fill = 500
				out.append({"item": copy, "base": int(e[2]), "hag": hag})
	return out

# ---------------------------------------------------------------- prices
## what the merchant asks for ONE of a tile's item
func unit_price(i: int, tile: Dictionary) -> int:
	return g.eco.haggle(i, int(tile["base"])) if bool(tile["hag"]) else int(tile["base"])

## what the merchant pays for ONE of this item
func offer(i: int, it) -> int:
	var v: int = int(it.def.get("price", 0))
	if it.has_tag("job") or v <= 0:
		return 0
	var base: float = 0.4 + minf(0.15, 0.5 * (1.0 - float(g.eco.haggle(i, 1000)) / 1000.0))
	return maxi(1, int(round(float(v) * base)))

func can_sell(it) -> bool:
	return not it.has_tag("job") and not it.has_tag("ammo") and not it.has_tag("money")

# ---------------------------------------------------------------- moving tiles
## take a tile (or one unit of a stack) out of the shop; returns the tile {item, base, hag} that is now off the shelf, or {}
func take(i: int, idx: int, single: bool) -> Dictionary:
	var tiles: Array = shop(i)["tiles"]
	if idx < 0 or idx >= tiles.size():
		return {}
	var t: Dictionary = tiles[idx]
	var it = t["item"]
	if single and it.count > 1:
		var one = g._new_item(it.id())
		one.count = 1
		it.count -= 1
		return {"item": one, "base": t["base"], "hag": t["hag"]}
	tiles.remove_at(idx)
	return t

## put a tile on the shelf: it joins an identical stack, else it goes at the end
func shelve(i: int, tile: Dictionary) -> void:
	var tiles: Array = shop(i)["tiles"]
	var it = tile["item"]
	if it.stackable():
		for t in tiles:
			if t["item"].id() == it.id() and t["item"].stackable() and int(t["base"]) == int(tile["base"]):
				t["item"].count += it.count
				return
	tiles.append(tile)

## you pay for a tile that left the shelf and it goes to your pack (or your rounds); {ok, msg}.  The caller puts the tile back on failure.
func buy(i: int, tile: Dictionary, at_g: String = "", at_i: int = -1) -> Dictionary:
	var it = tile["item"]
	var cost: int = unit_price(i, tile) * it.count
	if g.yen < cost:
		return {"ok": false, "msg": "You can't afford that: ¥%d, and you have ¥%d." % [cost, g.yen]}
	if it.has_tag("ammo"):
		var am: Dictionary = it.def["ammo"]
		g.pool_add(am["cal"], am["kind"], it.count * int(am["rounds"]))
	else:
		var placed := false
		if at_g != "" and g.inv.grid.has(at_g) and at_i >= 0 and at_i < (g.inv.grid[at_g] as Array).size() and g.inv.grid[at_g][at_i] == null and not it.stackable():
			g.inv.grid[at_g][at_i] = it
			placed = true
		if not placed and not g.inv.stow(it):
			return {"ok": false, "msg": "No room in your pockets: make a tile free first."}
	g.yen -= cost
	g.eco._haggle_xp({"who": i}, cost)
	g.say("You buy the %s%s (¥%d)." % [it.def["name"], (" x%d" % it.count) if it.count > 1 else "", cost])
	g.sfx("pick")
	return {"ok": true, "msg": "Bought for ¥%d." % cost, "cost": cost}

## the merchant pays for an item that left your pack and shelves it; {ok, msg}
func sell(i: int, it) -> Dictionary:
	if not can_sell(it):
		return {"ok": false, "msg": "They won't take the %s." % it.def["name"]}
	var each: int = offer(i, it)
	if each <= 0:
		return {"ok": false, "msg": "They won't take the %s." % it.def["name"]}
	var pay: int = each * it.count
	g.yen += pay
	var base: int = maxi(1, int(it.def.get("price", 1)) * 3 / 2)
	shelve(i, {"item": it, "base": base, "hag": true})
	g.say("You sell the %s%s (¥%d)." % [it.def["name"], (" x%d" % it.count) if it.count > 1 else "", pay])
	g.sfx("pick")
	return {"ok": true, "msg": "Sold for ¥%d." % pay, "pay": pay}

# ---------------------------------------------------------------- saving
func to_dict() -> Dictionary:
	var out := {}
	for i in shops:
		var tiles: Array = []
		for t in shops[i]["tiles"]:
			tiles.append({"item": t["item"].to_dict(), "base": t["base"], "hag": t["hag"]})
		out[str(i)] = {"day": shops[i]["day"], "tiles": tiles}
	return out

func load_dict(d: Dictionary) -> void:
	shops = {}
	for k in d:
		var tiles: Array = []
		for t in d[k]["tiles"]:
			if g.db.defs.has(String(t["item"]["id"])):
				tiles.append({"item": ItemScript.from_dict(t["item"], g.db), "base": int(t["base"]), "hag": bool(t["hag"])})
		shops[int(k)] = {"day": int(d[k]["day"]), "tiles": tiles}
