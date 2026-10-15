extends RefCounted
## Spike test 2: the pocket model.  run(): returns [passed, total, log]
const ItemScript = preload("res://src/item.gd")
const DB = preload("res://src/item_db.gd")

func run() -> Array:
	var db = DB.new()
	db.load_file("res://data/items.json")
	var log := []
	var st := [0, 0]
	var check = func(name: String, cond: bool) -> void:
		st[1] += 1
		if cond:
			st[0] += 1
		log.append(("  PASS " if cond else "  FAIL ") + name)
	var N = func(id: String, n: int = 1):
		return ItemScript.new(db.defs[id], n)

	var pack = N.call("trl_backpack")
	check.call("backpack empty volume is its own (1500 ml)", pack.volume() == 1500)
	var duf = N.call("trl_duffel")
	check.call("an empty duffel is small, a full one is large", duf.volume() == 1800)
	var rifle = N.call("trl_gun_ha5")
	check.call("a 900 mm rifle goes into the backpack's flexible pocket", pack.insert(rifle) and pack.contents_volume(0) > 0)
	check.call("rifle does not fit the rigid 300 mm side pocket", pack.why_not(1, rifle) in ["restricted", "too long"])
	var holster = N.call("trl_holster")
	var pistol = N.call("trl_gun_sp45")
	var smg = N.call("trl_gun_hx9")
	check.call("pistol fits the holster", holster.insert(pistol))
	check.call("SMG is refused by the holster (restricted)", holster.why_not(0, smg) == "restricted")
	var bottle = N.call("trl_water_bottle")
	var water = N.call("trl_water", 400)
	check.call("water goes into a watertight bottle", bottle.insert(water))
	check.call("water is refused by the backpack's main pocket (not watertight)", pack.why_not(0, N.call("trl_water", 100)) == "not watertight")
	check.call("a bottle goes into the backpack's side pocket (tag rule)", pack.insert(bottle) and pack.pockets[1].size() == 1)
	var w0: int = pack.weight()
	check.call("backpack weight includes everything nested (700 + 2900 rifle + 80 bottle + 400 water)", w0 == 4080)
	# nesting: pouch in coat, rations in pouch
	var coat = N.call("trl_coat")
	var pouch = N.call("trl_pouch")
	check.call("pouch goes into the coat", coat.insert(pouch))
	var filled := 0
	while coat.insert(N.call("trl_ration", 1)):
		filled += 1
		if filled > 200:
			break
	check.call("the coat's own pockets fill up and refuse more", filled > 10 and not coat.insert(N.call("trl_ration", 1)))
	check.call("insert_deep then falls through into the nested pouch", coat.insert_deep(N.call("trl_ration", 1)) and pouch.contents_volume(0) == 80)
	check.call("cycle: a coat cannot go inside the pouch it contains", pouch.why_not(0, coat) == "cycle")
	# capacity
	var small = N.call("trl_pouch")
	var cnt := 0
	while small.insert(N.call("trl_ration", 1)):
		cnt += 1
		if cnt > 100:
			break
	check.call("pouch fills up and refuses more (volume limit hit)", cnt > 5 and cnt < 20)
	# stacking
	var p2 = N.call("trl_pouch")
	p2.insert(N.call("trl_ration", 2))
	p2.insert(N.call("trl_ration", 3))
	check.call("identical items stack inside a pocket", p2.pockets[0].size() == 1 and p2.pockets[0][0].count == 5)
	# serialisation
	var s = JSON.stringify(pack.to_dict())
	var back = ItemScript.from_dict(JSON.parse_string(s), db)
	check.call("save and load round-trips volume and weight", back.volume() == pack.volume() and back.weight() == pack.weight())
	# removal
	check.call("remove takes an item out of any depth", coat.remove(pouch) and not coat.contains_item(pouch))
	# all 50 guns loaded
	var guns := 0
	for k in db.defs:
		if "gun" in db.defs[k].get("tags", []):
			guns += 1
	check.call("all 50 Trilobit guns exported from the CDDA tables are loaded", guns == 50)
	return [st[0], st[1], log]
