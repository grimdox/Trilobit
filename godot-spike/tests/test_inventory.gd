extends RefCounted
## The tile inventory: grid and pockets, the nine slots, hands, auto equip, saves, implants as items, bottles, and the Equipment / Implants tabs' logic (gear_ui.gd).
const GameScript = preload("res://src/game.gd")
const INV = preload("res://src/inventory.gd")
const IMP = preload("res://src/implants.gd")
const GearScript = preload("res://src/gear_ui.gd")
const SettingsScript = preload("res://src/settings.gd")

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
	# a clean slate: nothing worn, nothing carried
	g.inv = INV.new()
	var inv = g.inv
	check.call("a bare pack is 15 tiles", inv.capacity() == 15 and inv.free_tiles() == 15 and inv.groups() == ["base"])
	var ration = g._new_item("trl_ration", 3)
	inv.stow(ration)
	inv.stow(g._new_item("trl_ration", 2))
	check.call("a stack of identical items is one tile", inv.used() == 1 and ration.count == 5)
	for i in 14:
		inv.stow(g._new_item("trl_mel_kama"))
	check.call("fourteen blades fill the rest: 15 tiles used, none free", inv.used() == 15 and inv.free_tiles() == 0)
	check.call("a sixteenth object has nowhere to go", not inv.stow(g._new_item("trl_mel_kama")))
	inv = INV.new()
	g.inv = inv
	var pack = g._new_item("trl_backpack")
	inv.stow(pack)
	check.call("a backpack is Back equipment", INV.slot_options(pack) == ["back"] and INV.is_equipment(pack))
	check.call("wearing it adds 12 tiles", inv.auto_equip(pack) and inv.capacity() == 27 and inv.groups() == ["base", "back"])
	var coat = g._new_item("trl_coat")
	inv.stow(coat)
	check.call("a coat is Chest, +4 tiles", INV.slot_options(coat) == ["chest"] and inv.auto_equip(coat) and inv.capacity() == 31)
	var vest = g._new_item("trl_vest")
	inv.stow(vest)
	check.call("a vest takes the Chest from the coat (they exclude each other) and the coat goes to the pack", inv.auto_equip(vest) and inv.equip["chest"] == vest and inv.capacity() == 27 and inv.find(coat)["t"] == "grid")
	var fanny = g._new_item("trl_fanny")
	var pouch = g._new_item("trl_pouch")
	inv.stow(fanny)
	inv.stow(pouch)
	check.call("the fanny pack (3) and belt pouch (4) share the Belt, one at a time", inv.auto_equip(fanny) and inv.capacity() == 30 and inv.auto_equip(pouch) and inv.capacity() == 31 and inv.equip["belt"] == pouch and inv.find(fanny)["t"] == "grid")
	# a worn pocket's contents are rehomed on removal, or removal is refused when there is no room
	var carry = g._new_item("trl_ration")
	inv.put_grid("back", 0, carry)
	check.call("an item can sit in the backpack's tiles", inv.find(carry)["g"] == "back")
	check.call("taking the backpack off moves its contents into free tiles", inv.auto_unequip("back") and inv.find(carry)["g"] == "base" and inv.capacity() == 19)
	# two hands
	inv = INV.new()
	g.inv = inv
	var pistol = g._new_item("trl_gun_zp9")
	var rifle = g._new_item("trl_gun_ha5")
	var blade = g._new_item("trl_mel_kama")
	for it in [pistol, rifle, blade]:
		if it != null:
			inv.stow(it)
	check.call("a pistol and a short blade are one-handed, a rifle two", pistol != null and INV.hands(pistol) == 1 and INV.hands(blade) == 1 and INV.hands(rifle) == 2)
	check.call("a one-hander goes right then left", inv.auto_equip(pistol) and inv.equip["rhand"] == pistol and inv.auto_equip(blade) and inv.equip["lhand"] == blade)
	check.call("a rifle takes both hands: it sits in the Right Hand, the others go to the pack", inv.auto_equip(rifle) and inv.equip["rhand"] == rifle and not inv.equip.has("lhand") and inv.find(pistol)["t"] == "grid" and inv.find(blade)["t"] == "grid")
	check.call("nothing can go in the Left Hand while a rifle is held", inv.why_not("lhand", blade) != "")
	check.call("Game.wield reads the Right Hand", g.wield == rifle)
	# what never goes in a slot
	var food = g._new_item("trl_ration")
	var bottle = g.new_bottle(300)
	var kit = g._new_item("trl_kit_repair")
	check.call("food, a bottle and a repair kit are grid-only", not INV.is_equipment(food) and not INV.is_equipment(bottle) and not INV.is_equipment(kit))
	# every equipable item definition lands in a slot
	var bad: Array = []
	for id in g.db.defs:
		var it2 = g._new_item(id)
		var d: Dictionary = it2.def
		if d.has("armor") or d.has("pocket") or d.has("gun") or d.has("melee"):
			var o: Array = INV.slot_options(it2)
			if o.is_empty() or not (o[0] in INV.SLOTS):
				bad.append(id)
		if d.has("engine"):
			bad.append(id) if false else null
	check.call("every weapon, armor and pocket item has a slot (%s)" % ",".join(bad), bad.is_empty())
	# saving
	inv = INV.new()
	g.inv = inv
	inv.stow(pack)
	inv.auto_equip(pack)
	inv.put_grid("back", 3, g._new_item("trl_ration", 4))
	var d2: Dictionary = JSON.parse_string(JSON.stringify(inv.to_dict()))
	var inv2 = INV.new()
	inv2.load_dict(d2, g.db)
	check.call("a save round-trips the slots, the pocket tiles and a stack", inv2.equip["back"].id() == "trl_backpack" and inv2.capacity() == 27 and inv2.grid["back"][3].count == 4)
	# implants are items
	inv = INV.new()
	g.inv = inv
	g.implants = {}
	var imp = g._new_item("trl_imp_optics")
	inv.stow(imp)
	check.call("an implant item is carried in the grid and is not equipment", imp != null and imp.def["implant"] == "optics" and not INV.is_equipment(imp))
	check.call("installing moves it into the body", g.act_install_implant(imp) and g.implants.get("optics", false) and inv.used() == 0)
	check.call("taking it out brings the item back", g.act_remove_implant("optics") and not g.implants.get("optics", false) and inv.used() == 1 and inv.grid_items()[0].id() == "trl_imp_optics")
	var ids_ok := true
	for dd in IMP.ALL:
		if not g.db.defs.has("trl_imp_" + String(dd["id"])) or String(g.db.defs["trl_imp_" + String(dd["id"])]["part"]) != String(dd["part"]):
			ids_ok = false
	check.call("every implant in implants.gd has an item with the same part (tools/export_items.py is in step)", ids_ok)
	# bottles
	var b2 = g.new_bottle(500)
	check.call("a bottle holds a stack of water and is one tile", b2.fill == 500 and not b2.stackable())
	# settings
	var st = SettingsScript.new()
	check.call("P equipment, I implants, O skills, M map", st.action_for(KEY_P) == "inventory" and st.action_for(KEY_I) == "implants" and st.action_for(KEY_O) == "skills" and st.action_for(KEY_M) == "map")
	check.call("shove has no rebindable key but Shift+O is shown", (st.binds["shove"] as Array).is_empty() and st.key_text("shove") == "Shift+O")
	var old := SettingsScript.new()
	old.from_dict({"keys_v": 2, "binds": {"inventory": [KEY_I], "implants": [KEY_F3], "skills": [KEY_F7], "shove": [KEY_O]}})
	check.call("an old settings file moves to the new keys", old.action_for(KEY_I) == "implants" and old.action_for(KEY_O) == "skills" and old.action_for(KEY_P) == "inventory" and old.action_for(KEY_F3) == "")
	# the equipment tab's logic
	inv = INV.new()
	g.inv = inv
	g.implants = {}
	var gear = GearScript.new()
	gear.open(g, null, "equipment")
	var gun = g._new_item("trl_gun_zp9")
	var vest2 = g._new_item("trl_vest")
	inv.stow(gun)
	inv.stow(vest2)
	gear.cur = "g:base:0"
	gear.press()
	check.call("Enter picks the item up off its tile", gear.held == gun and inv.find(gun).is_empty())
	gear.cur = "s:chest"
	gear.press()
	check.call("a gun cannot be put on the Chest: it stays on the cursor", gear.held == gun and gear.msg != "")
	gear.cur = "s:rhand"
	gear.press()
	check.call("dropping it on the Right Hand equips it", gear.held == null and inv.equip["rhand"] == gun)
	gear.cur = "g:base:1"
	gear.auto()
	check.call("Ctrl (right-click) equips a carried vest", inv.equip.get("chest") == vest2)
	gear.cur = "s:chest"
	gear.auto()
	check.call("and takes it off again", not inv.equip.has("chest") and inv.find(vest2)["t"] == "grid")
	gear.cur = "s:rhand"
	gear.press()
	gear.cur = "g:base:7"
	gear.press()
	check.call("a worn item dropped on an empty tile is unequipped there", gear.held == null and inv.grid["base"][7] == gun and not inv.equip.has("rhand"))
	gear.cur = "g:base:7"
	gear.press()
	gear.close()
	check.call("closing with an item on the cursor puts it back", gear.held == null and inv.grid["base"][7] == gun)
	# dropping
	var tg: Array = gear.targets()
	var floor0: int = (g.items_at[g.pc].size() if g.items_at.has(g.pc) else 0)
	gear.cur = "g:base:7"
	gear.press()
	gear.cur = "d:drop"
	gear.press()
	check.call("moving the held item onto DROP puts it on the floor", gear.held == null and inv.find(gun).is_empty() and g.items_at.has(g.pc) and g.items_at[g.pc].size() == floor0 + 1)
	var vest_b = g._new_item("trl_vest")
	inv.stow(vest_b)
	var idx: int = inv.find(vest_b)["i"]
	var r2: Rect2 = gear.grid_rect(gear.group_layout()[0][1], gear.group_layout()[0][2], idx)
	gear.click(r2.get_center(), false, true)
	check.call("alt-click drops the item under the mouse", inv.find(vest_b).is_empty() and g.items_at[g.pc].size() == floor0 + 2)
	var vest3 = g._new_item("trl_vest")
	inv.stow(vest3)
	inv.auto_equip(vest3)
	gear.cur = "s:chest"
	gear.click(gear.slot_rect("chest").get_center(), false, true)
	check.call("alt-click drops a worn item too", not inv.equip.has("chest") and inv.find(vest3).is_empty())
	gear.drop_mode = true
	var jar = g._new_item("trl_ration", 2)
	inv.stow(jar)
	gear.cur = "g:base:%d" % inv.find(jar)["i"]
	gear.press()
	check.call("in drop mode choosing an item drops it (the whole stack)", inv.find(jar).is_empty())
	gear.drop_mode = false
	check.call("a target for DROP exists in the equipment tab only", tg.any(func(e): return e["key"] == "d:drop") and gear.DROP_RECT.end.x <= 1280.0 and gear.DROP_RECT.end.y <= 720.0)
	var oldt := SettingsScript.new()
	oldt.from_dict({"keys_v": 3, "binds": {"turn": [KEY_SEMICOLON]}})
	check.call("an older save gets the keypad minus on turn-to-look", oldt.action_for(KEY_KP_SUBTRACT) == "turn" and oldt.action_for(KEY_SEMICOLON) == "turn")
	# click targets
	tg = gear.targets()
	check.call("the tabs have a target for each slot and tile (9 + 15 + DROP)", tg.size() == 9 + 15 + 1)
	var r0: Rect2 = gear.slot_rect("head")
	check.call("a point on a slot finds it", gear.target_at(r0.get_center()) == "s:head")
	var overlap := false
	for i in tg.size():
		for j in range(i + 1, tg.size()):
			if (tg[i]["rect"] as Rect2).intersects(tg[j]["rect"]):
				overlap = true
	check.call("no two targets overlap", not overlap)
	var fits := true
	for e in tg:
		var rr: Rect2 = e["rect"]
		if e["key"] == "d:drop":
			continue
		if rr.position.x < 0 or rr.end.x > GearScript.CARD.position.x or rr.end.y > 700:
			fits = false
	check.call("every tile sits left of the item card and above the footer", fits)
	var seen := {}
	var cur0: String = "s:head"
	gear.cur = cur0
	for k in 40:
		gear.move(Vector2i(0, 1))
		seen[gear.cur] = true
	check.call("the highlight walks down the doll and into the grid (%s)" % ",".join(seen.keys()), seen.size() >= 7)
	# the implants tab
	var imp2 = g._new_item("trl_imp_cortex")
	inv.stow(imp2)
	gear.open(g, null, "implants")
	gear.cur = "s:head"
	gear.press()
	check.call("Enter on a spot opens its list of carried implants", gear.row_focus and gear.cur == "r:0")
	gear.press()
	check.call("Enter on a row fits it", g.implants.get("cortex", false) and inv.find(imp2).is_empty())
	gear.cur = "s:head"
	gear.row_focus = false
	gear.press()
	gear.press()
	check.call("and on a fitted one takes it out", not g.implants.get("cortex", false) and inv.used() >= 1)
	var it3 = null
	for cand in inv.grid_items():
		if cand.id() == "trl_imp_cortex":
			it3 = cand
	gear.cur = "g:base:%d" % inv.grid["base"].find(it3)
	gear.auto()
	check.call("Ctrl on a carried implant fits it", g.implants.get("cortex", false))
	return [cnt[0], cnt[1], log]
