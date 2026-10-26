extends RefCounted
## The Equipment and Implants tabs: a generic doll with nine slots, the inventory grid under it, an item card on the right.
## Everything here is layout, drawing and the bookkeeping of the item held on the cursor; Inventory (inventory.gd) and Game do the real work.
##  - Equipment tab: click (or Enter) picks an item up; click a tile to put it down (a slot equips it, a grid tile stows it, a full tile swaps);
##    right-click (or Ctrl) equips a carried piece or takes a worn one off.
##  - Implants tab: the same doll, a spot per body part.  A carried implant is fitted by Enter, click, right-click or Ctrl; the spot's list on the
##    right fits carried ones and takes fitted ones out.
const INV = preload("res://src/inventory.gd")
const IMP = preload("res://src/implants.gd")
const GP = preload("res://src/gunplay.gd")

const CYAN := Color(0.3, 0.9, 1.0)
const MAGENTA := Color(1.0, 0.25, 0.65)
const YELLOW := Color(1.0, 0.8, 0.25)
const TILE_BG := Color(0.17, 0.18, 0.22)
const TILE_EDGE := Color(0.38, 0.42, 0.52)

const TAB_H := 44.0
const T := 48.0                          # a tile
const PITCH := 54.0
const DOLL_X := 365.0                    # the figure's centre line
const DOLL_COL := 140.0                  # slot columns sit this far either side of it
const GRID_X := 40.0
const GRID_Y := 396.0
const POCKET_X := 368.0
const CARD := Rect2(730.0, 56.0, 520.0, 612.0)
const DROP_RECT := Rect2(1064.0, 612.0, 172.0, 44.0)       # the DROP button, bottom right (equipment tab)

## slot -> [side (-1 left of the figure, +1 right), tile centre y].  Left: Head, Chest, Arms, Left Hand, Legs.  Right: Eyes, Back, Belt, Right Hand.
const SPOTS := {"head": Vector2(-1, 86), "eyes": Vector2(1, 86), "chest": Vector2(-1, 152), "back": Vector2(1, 152), "arms": Vector2(-1, 218),
	"belt": Vector2(1, 218), "lhand": Vector2(-1, 284), "rhand": Vector2(1, 284), "legs": Vector2(-1, 350)}
## where each leader line meets the body (x from the centre line, y on the figure)
const ANCHOR := {"head": Vector2(-15, 74), "eyes": Vector2(9, 82), "chest": Vector2(-30, 160), "back": Vector2(42, 148), "arms": Vector2(-65, 172),
	"belt": Vector2(29, 222), "lhand": Vector2(-69, 278), "rhand": Vector2(69, 278), "legs": Vector2(-28, 286)}
## the implant part each doll spot stands for (the belt carries none)
const SPOT_PART := {"head": "head", "eyes": "eyes", "back": "spine", "chest": "chest", "arms": "arms", "lhand": "hands", "rhand": "hands", "legs": "legs"}

var game = null
var ts = null                            # Tileset for item icons
var font: Font = ThemeDB.fallback_font
var tab: String = "equipment"            # "equipment" or "implants"
var cur: String = "s:head"               # the highlighted target: "s:<slot>", "g:<group>:<i>" or "r:<row>" (an implant row)
var held = null                          # the item on the cursor
var held_from: Dictionary = {}           # where it came from (a ref of Inventory.find), to put it back
var mouse := Vector2(-100, -100)
var use_mouse := false                   # true once the mouse moved last (the item follows it), false for the keyboard (it follows the highlight)
var msg: String = ""
var msg_t: float = 0.0
var drop_mode := false                   # opened by the drop key: choosing an item drops it
var row_focus := false                   # implants tab: the keys move over the part's list
var _rows: Array = []                    # the implant rows of the highlighted spot, rebuilt each draw / key

func open(g, tileset, which: String) -> void:
	game = g
	ts = tileset
	tab = which
	if held != null:
		give_back()
	set_tab(which)
	drop_mode = false
	msg = ""

func set_tab(which: String) -> void:
	if held != null:
		give_back()
	tab = which
	row_focus = false
	cur = "s:head"

func close() -> void:
	if held != null:
		give_back()

func say(s: String) -> void:
	msg = s
	msg_t = 4.0

# ---------------------------------------------------------------- layout
func slot_rect(slot: String) -> Rect2:
	var s: Vector2 = SPOTS[slot]
	return Rect2(DOLL_X + s.x * DOLL_COL - T * 0.5, s.y - T * 0.5, T, T)

## [group, origin, columns] for every group of grid tiles, in the order they are drawn
func group_layout() -> Array:
	var out: Array = []
	var inv = game.inv
	out.append(["base", Vector2(GRID_X, GRID_Y + 12.0), INV.BASE_COLS])
	var y: float = GRID_Y - 6.0
	for g in inv.groups():
		if g == "base":
			continue
		var cols: int = inv.group_cols(g)
		var rows: int = (inv.group_size(g) + cols - 1) / cols
		out.append([g, Vector2(POCKET_X, y + 18.0), cols])
		y += 18.0 + rows * PITCH + 12.0
	return out

func grid_rect(origin: Vector2, cols: int, i: int) -> Rect2:
	return Rect2(origin.x + (i % cols) * PITCH, origin.y + (i / cols) * PITCH, T, T)

## every place the highlight can rest: [{key, rect}]
func targets() -> Array:
	var out: Array = []
	for slot in SPOTS:
		if tab == "implants" and not SPOT_PART.has(slot):
			continue
		out.append({"key": "s:" + slot, "rect": slot_rect(slot)})
	for gl in group_layout():
		var g: String = gl[0]
		for i in game.inv.group_size(g):
			out.append({"key": "g:%s:%d" % [g, i], "rect": grid_rect(gl[1], gl[2], i)})
	if tab == "equipment":
		out.append({"key": "d:drop", "rect": DROP_RECT})
	if tab == "implants" and (cur.begins_with("s:") or cur.begins_with("r:")):
		for k in _rows.size():
			out.append({"key": "r:%d" % k, "rect": row_rect(k)})
	return out

func row_rect(k: int) -> Rect2:
	return Rect2(CARD.position.x + 14.0, CARD.position.y + 66.0 + k * 104.0, CARD.size.x - 28.0, 98.0)

func target_at(p: Vector2) -> String:
	for tg in targets():
		if (tg["rect"] as Rect2).has_point(p):
			return tg["key"]
	return ""

## the item a key points at (or null)
func item_at(key: String):
	var inv = game.inv
	if key.begins_with("s:"):
		return inv.equip.get(key.substr(2))
	if key.begins_with("g:"):
		var p: PackedStringArray = key.split(":")
		if inv.grid.has(p[1]):
			var a: Array = inv.grid[p[1]]
			var i: int = int(p[2])
			return a[i] if i < a.size() else null
	return null

func ref_of(key: String) -> Dictionary:
	if key.begins_with("s:"):
		return {"t": "eq", "slot": key.substr(2)}
	var p: PackedStringArray = key.split(":")
	return {"t": "grid", "g": p[1], "i": int(p[2])}

## the part the highlighted spot stands for ("" when it is not a spot)
func cur_part() -> String:
	if cur.begins_with("s:"):
		return String(SPOT_PART.get(cur.substr(2), ""))
	return ""

## what the implant list of a part holds: fitted ones first, then the ones in the pack  [{id, def, item, fitted}]
func part_rows(part: String) -> Array:
	var out: Array = []
	if part == "" or game == null:
		return out
	for d in IMP.for_part(part):
		if game.implants.get(d["id"], false):
			out.append({"id": d["id"], "def": d, "item": null, "fitted": true})
	for it in game.inv.grid_items():
		if it.def.has("implant") and String(it.def.get("part", "")) == part and not game.implants.get(String(it.def["implant"]), false):
			out.append({"id": String(it.def["implant"]), "def": IMP.get_def(String(it.def["implant"])), "item": it, "fitted": false})
	return out

func _sync_rows() -> void:
	if cur.begins_with("s:") and cur_part() != "":
		cur_part_for_rows = cur_part()
	_rows = part_rows(cur_part_for_rows) if tab == "implants" else []
	if cur.begins_with("r:") and int(cur.substr(2)) >= _rows.size():
		cur = "s:" + _spot_of(cur_part_for_rows)
		row_focus = false

var cur_part_for_rows := "head"

func _spot_of(part: String) -> String:
	for slot in SPOT_PART:
		if SPOT_PART[slot] == part:
			return slot
	return "head"

# ---------------------------------------------------------------- moving the highlight
func move(dir: Vector2i) -> bool:
	_sync_rows()
	var tg: Array = targets()
	var from := Rect2()
	var found := false
	for e in tg:
		if e["key"] == cur:
			from = e["rect"]
			found = true
	if not found:
		cur = "s:head"
		return true
	var c: Vector2 = from.get_center()
	var best: String = ""
	var bs := 1.0e9
	var band: float = 22.0
	for pass_i in 2:
		for e in tg:
			if e["key"] == cur:
				continue
			var k: String = e["key"]
			if tab == "implants":
				if row_focus != k.begins_with("r:"):
					continue
			var d: Vector2 = (e["rect"] as Rect2).get_center() - c
			var along: float = d.x * dir.x + d.y * dir.y
			if along < 6.0:
				continue
			var across: float = absf(d.y) if dir.x != 0 else absf(d.x)
			if pass_i == 0 and across > band:
				continue
			var score: float = along + 3.0 * across
			if score < bs:
				bs = score
				best = k
		if best != "":
			break
	if best == "":
		return false
	cur = best
	use_mouse = false
	if cur.begins_with("s:") and cur_part() != "":
		cur_part_for_rows = cur_part()
	return true

func hover(p: Vector2) -> bool:
	mouse = p
	use_mouse = true
	_sync_rows()
	var k: String = target_at(p)
	if k != "" and k != cur:
		if tab == "implants" and k.begins_with("r:") != cur.begins_with("r:"):
			row_focus = k.begins_with("r:")
		cur = k
		if cur.begins_with("s:") and cur_part() != "":
			cur_part_for_rows = cur_part()
		return true
	return false

# ---------------------------------------------------------------- doing things
## Enter, or a left click on the highlight
func press() -> void:
	_sync_rows()
	if tab == "implants":
		_press_implants()
		return
	if cur == "d:drop":
		if held != null:
			drop_held()
		else:
			say("Move an item here to drop it.")
		return
	if held == null:
		if drop_mode:
			drop_at(cur)
		else:
			pick_up(cur)
	else:
		put_down(cur)

## Ctrl, or a right click on the highlight
func auto() -> void:
	_sync_rows()
	if held != null:
		return
	if tab == "implants":
		var it = item_at(cur)
		if it != null and it.def.has("implant"):
			_fit(it)
		elif cur.begins_with("r:"):
			_press_implants()
		return
	var it2 = item_at(cur)
	if it2 == null:
		return
	var ref: Dictionary = ref_of(cur)
	var inv = game.inv
	if ref["t"] == "eq":
		if inv.auto_unequip(ref["slot"]):
			game.say("You take off the %s." % it2.def["name"])
			game.sfx("pick")
		else:
			say(inv.last_err)
	else:
		if not INV.is_equipment(it2):
			say("The %s is not equipment." % it2.def["name"])
		elif inv.auto_equip(it2):
			game.say("You put on the %s." % it2.def["name"])
			game.sfx("pick")
		else:
			say(inv.last_err)

## drop the item a key points at onto the floor at your feet (the whole stack; free, no turn)
func drop_at(key: String) -> void:
	var it = item_at(key)
	if it == null:
		return
	if not game.inv.remove(it):
		say(game.inv.last_err if game.inv.last_err != "" else "You cannot drop that right now.")
		return
	_to_floor(it)

## the held item goes onto the floor
func drop_held() -> void:
	if held == null:
		return
	var it = held
	held = null
	held_from = {}
	_to_floor(it)

func _to_floor(it) -> void:
	game._put(game.pc, it)
	game.say("You drop the %s%s." % [it.def["name"], (" x%d" % it.count) if it.count > 1 else ""])
	game.sfx("pick")
	say("Dropped the %s." % it.def["name"])

func pick_up(key: String) -> void:
	var it = item_at(key)
	if it == null:
		return
	var ref: Dictionary = ref_of(key)
	if not game.inv.remove(it):
		say(game.inv.last_err if game.inv.last_err != "" else "You cannot take that out right now.")
		return
	held = it
	held_from = ref
	game.sfx("pick")

func put_down(key: String) -> void:
	var inv = game.inv
	var ref: Dictionary = ref_of(key)
	if ref["t"] == "eq":
		var r: Dictionary = inv.put_equip(ref["slot"], held)
		if not r["ok"]:
			say(inv.last_err)
			return
		held = r["back"]
	else:
		var r2: Dictionary = inv.put_grid(ref["g"], ref["i"], held)
		if not r2["ok"]:
			say(inv.last_err)
			return
		held = r2["back"]
	held_from = ref
	game.sfx("pick")

## the held item goes back where it came from, or into any free tile, or onto the floor
func give_back() -> void:
	if held == null or game == null:
		held = null
		return
	var inv = game.inv
	var it = held
	held = null
	if held_from.get("t", "") == "grid":
		var g: String = held_from["g"]
		if inv.grid.has(g) and int(held_from["i"]) < (inv.grid[g] as Array).size() and inv.grid[g][held_from["i"]] == null:
			inv.grid[g][held_from["i"]] = it
			return
	if inv.stow(it):
		return
	game._put(game.pc, it)
	game.say("No room: you drop the %s." % it.def["name"])

## Esc: true if it only put the held item back
func cancel() -> bool:
	if held != null:
		give_back()
		return true
	if row_focus:
		row_focus = false
		return true
	return false

func _fit(it) -> void:
	if game.act_install_implant(it):
		say("")
	else:
		say("You cannot fit that.")

func _press_implants() -> void:
	var it = item_at(cur)
	if it != null:
		if it.def.has("implant"):
			_fit(it)
		else:
			say("The %s is not an implant." % it.def["name"])
		return
	if cur.begins_with("r:"):
		var k: int = int(cur.substr(2))
		if k < _rows.size():
			var row: Dictionary = _rows[k]
			if row["fitted"]:
				game.act_remove_implant(row["id"])
			else:
				_fit(row["item"])
			_sync_rows()
			if _rows.is_empty():
				row_focus = false
		return
	if cur.begins_with("s:"):
		if not _rows.is_empty():
			row_focus = true
			cur = "r:0"
		else:
			say("Nothing for that part in your pack.")

func click(p: Vector2, right: bool, alt: bool = false) -> void:
	_sync_rows()
	hover(p)
	var k: String = target_at(p)
	if alt and not right and tab == "equipment" and held == null:
		if k != "" and k != "d:drop":
			drop_at(k)
		return
	if right:
		if k != "" and k != "d:drop":
			auto()
		return
	if k == "":
		if held != null:
			say("Drop it on a tile.")
		return
	press()

# ---------------------------------------------------------------- drawing
func _txt(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color) -> void:
	c.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _rtxt(c: CanvasItem, s: String, right_x: float, y: float, size: int, col: Color) -> void:
	var w: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(font, Vector2(right_x - w, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _fit_txt(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, max_w: float) -> void:
	var sz: int = size
	while sz > 11 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > max_w:
		sz -= 1
	var out: String = s
	while out.length() > 1 and font.get_string_size(out, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > max_w:
		out = out.substr(0, out.length() - 1)
	c.draw_string(font, pos, out, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

## word-wrap to a pixel width
func wrap_text(s: String, size: int, max_w: float) -> Array:
	var lines: Array = []
	for para in s.split("\n"):
		var line := ""
		for w in para.split(" "):
			var trial: String = w if line == "" else line + " " + w
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w and line != "":
				lines.append(line)
				line = w
			else:
				line = trial
		lines.append(line)
	return lines

func icon_id(it) -> String:
	var id: String = it.def["id"]
	if ts != null and ts.has(id):
		return id
	return "trl_parcel"

func draw_icon(c: CanvasItem, id: String, r: Rect2, mod: Color = Color.WHITE) -> void:
	if ts == null:
		return
	var sp: Array = ts.sprite(id)
	if sp.is_empty():
		sp = ts.sprite("trl_parcel")
		if sp.is_empty():
			return
	var rr: Rect2 = sp[1]
	var k: float = float(sp[3]) * r.size.x / 64.0
	c.draw_texture_rect_region(sp[0], Rect2(r.position + sp[2] * k, rr.size * k), rr, mod)

## a tile: grey square, the item (or nothing), a count for stacks
func draw_tile(c: CanvasItem, r: Rect2, it, mod: Color = Color.WHITE, edge: Color = TILE_EDGE) -> void:
	c.draw_rect(r, TILE_BG)
	c.draw_rect(r, edge, false, 1.5)
	if it == null:
		return
	draw_icon(c, icon_id(it), r, mod)
	if it.count > 1:
		_rtxt(c, "x%d" % it.count, r.end.x - 3.0, r.end.y - 4.0, 13, Color(YELLOW.r, YELLOW.g, YELLOW.b, mod.a))

func _installed_in(part: String) -> Array:
	var out: Array = []
	for d in IMP.for_part(part):
		if game.implants.get(d["id"], false):
			out.append(d)
	return out

func draw(c: CanvasItem, W: float, H: float, t: float, dt: float) -> void:
	msg_t = maxf(0.0, msg_t - dt)
	_sync_rows()
	if cur.begins_with("s:") and cur_part() != "":
		cur_part_for_rows = cur_part()
	_figure(c)
	_leaders(c, tab == "implants")
	var inv = game.inv
	var on_imp: bool = tab == "implants"
	# the doll
	for slot in SPOTS:
		var r: Rect2 = slot_rect(slot)
		var key: String = "s:" + slot
		var isspot: bool = SPOT_PART.has(slot)
		var lab: String = INV.NAMES[slot] if not on_imp else (String(IMP.PARTS[_part_index(SPOT_PART[slot])]["name"]).split(" /")[0] if isspot else INV.NAMES[slot])
		_txt(c, lab, Vector2(r.position.x + (T - font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) * 0.5, r.position.y - 4.0), 12, Color(0.55, 0.65, 0.78, 0.55 if (on_imp and not isspot) else 1.0))
		if not on_imp:
			var it = inv.equip.get(slot)
			if it == null and slot == "lhand" and inv.equip.has("rhand") and INV.hands(inv.equip["rhand"]) == 2:
				c.draw_rect(r, TILE_BG)
				c.draw_rect(r, TILE_EDGE, false, 1.5)
				draw_icon(c, icon_id(inv.equip["rhand"]), r, Color(1, 1, 1, 0.3))
			else:
				draw_tile(c, r, it)
		else:
			if isspot:
				var inst: Array = _installed_in(SPOT_PART[slot])
				c.draw_rect(r, TILE_BG)
				c.draw_rect(r, YELLOW if not inst.is_empty() else TILE_EDGE, false, 1.5)
				if not inst.is_empty():
					draw_icon(c, "trl_imp_" + String(inst[0]["id"]), r)
					if inst.size() > 1:
						_rtxt(c, "x%d" % inst.size(), r.end.x - 3.0, r.end.y - 4.0, 13, YELLOW)
			else:
				c.draw_rect(r, Color(TILE_BG.r, TILE_BG.g, TILE_BG.b, 0.45))
				c.draw_rect(r, Color(TILE_EDGE.r, TILE_EDGE.g, TILE_EDGE.b, 0.3), false, 1.0)
		if key == cur:
			_cursor(c, r, t)
	# the grid
	var used: int = inv.used()
	var cap: int = inv.capacity()
	for gl in group_layout():
		var g: String = gl[0]
		var origin: Vector2 = gl[1]
		var cols: int = gl[2]
		var label: String = inv.group_label(g)
		if g == "base":
			label += "   %d / %d" % [used, cap]
		_txt(c, label, Vector2(origin.x, origin.y - 6.0), 14, CYAN)
		for i in inv.group_size(g):
			var r2: Rect2 = grid_rect(origin, cols, i)
			var it2 = inv.grid[g][i]
			var mod := Color.WHITE
			var edge: Color = TILE_EDGE
			if on_imp and it2 != null:
				if it2.def.has("implant"):
					mod = Color(1.15, 1.15, 1.15)
					edge = YELLOW
				else:
					mod = Color(1, 1, 1, 0.3)
			draw_tile(c, r2, it2, mod, edge)
			if cur == "g:%s:%d" % [g, i]:
				_cursor(c, r2, t)
	_card_panel(c, t)
	if tab == "equipment":
		var db: Rect2 = DROP_RECT
		var hot: bool = cur == "d:drop"
		var armed: bool = held != null or drop_mode
		c.draw_rect(db, Color(1.0, 0.25, 0.65, 0.28 if armed else 0.12))
		c.draw_rect(db, MAGENTA if (hot or armed) else Color(0.55, 0.3, 0.45), false, 2.0 if hot else 1.5)
		var dw: float = font.get_string_size("DROP", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		_txt(c, "DROP", Vector2(db.position.x + (db.size.x - dw) * 0.5, db.position.y + 30.0), 22, Color.WHITE if (hot or armed) else Color(0.8, 0.6, 0.72))
		if hot:
			_cursor(c, db, t)
	# the held item follows the mouse, or the highlight when the keys are driving
	if held != null:
		var hp: Vector2 = mouse - Vector2(T, T) * 0.5
		if not use_mouse:
			for e in targets():
				if e["key"] == cur:
					hp = (e["rect"] as Rect2).position + Vector2(10, 10)
		var hr := Rect2(hp, Vector2(T, T))
		c.draw_rect(hr, Color(0.17, 0.18, 0.22, 0.9))
		c.draw_rect(hr, MAGENTA, false, 2.0)
		draw_icon(c, icon_id(held), hr)
	# the footer
	var hint: String
	if on_imp:
		hint = "Arrows / numpad / mouse move  -  Enter, Ctrl or click fits a carried implant  -  Enter on a spot opens its list  -  Esc closes"
	elif held != null:
		hint = "Holding the %s  -  Enter or click puts it down, on DROP drops it  -  Esc puts it back" % held.def["name"]
	elif drop_mode:
		hint = "DROP: Enter or click an item to drop it onto the floor  -  Esc closes"
	else:
		hint = "Arrows / numpad / mouse move  -  Enter or click picks up  -  Ctrl or right-click equips / takes off  -  Alt-click drops  -  Esc closes"
	_txt(c, hint, Vector2(40, H - 12.0), 14, Color(0.6, 0.72, 0.85))

func _part_index(part: String) -> int:
	for i in IMP.PARTS.size():
		if IMP.PARTS[i]["id"] == part:
			return i
	return 0

func _cursor(c: CanvasItem, r: Rect2, t: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(t * 6.0)
	c.draw_rect(r.grow(2.0), Color(YELLOW.r, YELLOW.g, YELLOW.b, 0.18 + 0.12 * pulse))
	c.draw_rect(r.grow(2.0), YELLOW, false, 3.0)

## a point on the figure: x from the centre line, y in "figure units" (head top 62, feet 394), squeezed a little to clear the pocket labels
func _fp(x: float, y: float) -> Vector2:
	return Vector2(DOLL_X + x, 60.0 + (y - 62.0) * 0.97)

## the smooth outline (Catmull-Rom) through points given in figure units, in screen pixels
func _sample(pts: Array, closed: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = pts.size()
	var last: int = n if closed else n - 1
	for i in last:
		var p0: Vector2 = pts[(i - 1 + n) % n] if (closed or i > 0) else pts[0]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % n]
		var p3: Vector2 = pts[(i + 2) % n] if (closed or i + 2 < n) else pts[n - 1]
		for k in 8:
			var u: float = float(k) / 8.0
			var u2: float = u * u
			var u3: float = u2 * u
			var q: Vector2 = 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3)
			out.append(_fp(q.x, q.y))
	if not closed:
		out.append(_fp((pts[n - 1] as Vector2).x, (pts[n - 1] as Vector2).y))
	return out

func _spline(c: CanvasItem, pts: Array, col: Color, w: float, closed: bool = false) -> void:
	var out: PackedVector2Array = _sample(pts, closed)
	if closed:
		out.append(out[0])
	c.draw_polyline(out, col, w, true)

func _mirror(pts: Array) -> Array:
	var m: Array = []
	for p in pts:
		m.append(Vector2(-(p as Vector2).x, (p as Vector2).y))
	return m

## the line and its mirror image across the centre line
func _pair(c: CanvasItem, pts: Array, col: Color, w: float) -> void:
	_spline(c, pts, col, w)
	_spline(c, _mirror(pts), col, w)

const PLATE_LIGHT := Color(0.88, 0.93, 1.0, 0.8)
const PLATE_DARK := Color(0.42, 0.5, 0.65, 0.62)
const EDGE := Color(0.3, 0.9, 1.0, 0.88)
const PINK := Color(1.0, 0.25, 0.65, 0.85)
const JOINT_DARK := Color(0.04, 0.06, 0.12, 0.97)

## a closed plate: shaded grey (light from the upper left), glowing cyan edge
func _plate(c: CanvasItem, pts: Array, fill_dark: Color = PLATE_DARK, fill_light: Color = PLATE_LIGHT, edge: Color = EDGE) -> void:
	var ring: PackedVector2Array = _sample(pts, true)
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	var top: float = 1.0e9
	var bot: float = -1.0e9
	for p in ring:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
		top = minf(top, p.y)
		bot = maxf(bot, p.y)
	var cols := PackedColorArray()
	for p in ring:
		var tx: float = (p.x - lo) / maxf(hi - lo, 1.0)
		var ty: float = (p.y - top) / maxf(bot - top, 1.0)
		cols.append(fill_light.lerp(fill_dark, clampf(tx * 0.75 + ty * 0.25, 0.0, 1.0)))
	c.draw_polygon(ring, cols)
	var loop := PackedVector2Array(ring)
	loop.append(ring[0])
	c.draw_polyline(loop, Color(edge.r, edge.g, edge.b, 0.14), 5.0, true)
	c.draw_polyline(loop, edge, 1.4, true)

## a plate on the right side and its mirror on the left
func _both(c: CanvasItem, pts: Array, fill_dark: Color = PLATE_DARK, fill_light: Color = PLATE_LIGHT, edge: Color = EDGE) -> void:
	_plate(c, pts, fill_dark, fill_light, edge)
	_plate(c, _mirror(pts), fill_dark, fill_light, edge)

## a centred plate given as its right half from the top centre line down to the bottom centre line
func _sym(c: CanvasItem, half: Array, fill_dark: Color = PLATE_DARK, fill_light: Color = PLATE_LIGHT, edge: Color = EDGE) -> void:
	var full: Array = half.duplicate()
	var back: Array = _mirror(half)
	back.reverse()
	for i in range(1, back.size() - 1):
		full.append(back[i])
	_plate(c, full, fill_dark, fill_light, edge)

## an android ball joint: dark socket, cyan rim, yellow ring and pin
func _joint(c: CanvasItem, x: float, y: float, r: float, both: bool = true) -> void:
	for sg in ([1.0, -1.0] if both else [1.0]):
		var p: Vector2 = _fp(x * sg, y)
		c.draw_circle(p, r, JOINT_DARK)
		c.draw_arc(p, r, 0, TAU, 24, Color(0.3, 0.9, 1.0, 0.6), 1.3, true)
		c.draw_arc(p, r * 0.6, 0, TAU, 20, Color(1.0, 0.8, 0.25, 0.9), 1.4, true)
		c.draw_circle(p, 1.4, Color(1.0, 0.8, 0.25, 0.95))

## The generic figure, an android in the manner of the Vitruvian Man (one pair of arms and legs, arms down): grey shaded plates joined by dark
## ball joints, a glowing core, with the circle of the canon and the eighths of the height behind.  Only blue, pink, yellow and grey.
func _figure(c: CanvasItem) -> void:
	var line := Color(0.3, 0.9, 1.0, 0.07)
	var faint := Color(0.3, 0.9, 1.0, 0.16)
	var fine := Color(0.75, 0.9, 1.0, 0.5)
	var navel: Vector2 = _fp(0, 200)
	c.draw_arc(navel, 150.0, 0, TAU, 128, Color(0.3, 0.9, 1.0, 0.22), 1.5, true)
	c.draw_arc(navel, 145.0, 0, TAU, 128, Color(1.0, 0.25, 0.65, 0.12), 1.0, true)
	for k in range(0, 9):
		var yy: float = 62.0 + 332.0 * float(k) / 8.0
		c.draw_line(_fp(-112, yy), _fp(112, yy), line, 1.0)
		c.draw_line(_fp(-112, yy), _fp(-104, yy), faint, 1.0)
		c.draw_line(_fp(112, yy), _fp(104, yy), faint, 1.0)
	c.draw_line(_fp(0, 52), _fp(0, 404), Color(0.3, 0.9, 1.0, 0.12), 1.0)
	# legs, then arms (behind the torso)
	_both(c, [Vector2(11, 252), Vector2(31, 256), Vector2(31, 270), Vector2(28, 292), Vector2(24, 314), Vector2(10, 314), Vector2(8, 292), Vector2(7, 270)])           # thighs
	_both(c, [Vector2(10, 326), Vector2(24, 326), Vector2(25, 342), Vector2(22, 362), Vector2(18, 378), Vector2(11, 378), Vector2(9, 362), Vector2(9, 342)])            # shins
	_both(c, [Vector2(10, 314), Vector2(24, 314), Vector2(25, 322), Vector2(17, 331), Vector2(9, 322)])                                                                   # knee plates
	_both(c, [Vector2(8, 384), Vector2(21, 384), Vector2(24, 391), Vector2(23, 395), Vector2(5, 395), Vector2(5, 390)])                                                  # feet
	_pair(c, [Vector2(29, 262), Vector2(27, 290), Vector2(24, 310)], PINK, 1.1)
	_pair(c, [Vector2(23, 334), Vector2(21, 358)], PINK, 1.1)
	_both(c, [Vector2(50, 146), Vector2(63, 146), Vector2(66, 160), Vector2(65, 176), Vector2(63, 187), Vector2(53, 187), Vector2(50, 172), Vector2(48, 158)])        # upper arms
	_both(c, [Vector2(52, 200), Vector2(65, 200), Vector2(68, 214), Vector2(69, 234), Vector2(67, 250), Vector2(58, 250), Vector2(56, 234), Vector2(53, 214)])        # forearms
	_both(c, [Vector2(57, 258), Vector2(67, 258), Vector2(70, 268), Vector2(71, 280), Vector2(68, 288), Vector2(63, 291), Vector2(58, 288), Vector2(56, 278), Vector2(55, 268)])   # hands
	_both(c, [Vector2(55, 262), Vector2(52, 268), Vector2(52, 277), Vector2(55, 279)])                                                                                     # thumbs
	_pair(c, [Vector2(60, 277), Vector2(60, 288)], fine, 1.0)
	_pair(c, [Vector2(64, 277), Vector2(64, 289)], fine, 1.0)
	_pair(c, [Vector2(65, 150), Vector2(65, 182)], PINK, 1.1)
	_pair(c, [Vector2(67, 206), Vector2(68, 246)], PINK, 1.1)
	# the pelvis, waist, chest, neck and head
	_sym(c, [Vector2(0, 203), Vector2(16, 203), Vector2(26, 209), Vector2(30, 221), Vector2(28, 236), Vector2(21, 246), Vector2(11, 252), Vector2(0, 254)])
	_pair(c, [Vector2(1, 214), Vector2(16, 215), Vector2(29, 213)], PINK, 1.2)
	_pair(c, [Vector2(8, 218), Vector2(12, 232), Vector2(8, 246)], fine, 1.0)
	_sym(c, [Vector2(0, 187), Vector2(19, 187), Vector2(18, 196), Vector2(17, 205), Vector2(0, 205)], JOINT_DARK, Color(0.1, 0.13, 0.22, 0.97), Color(0.3, 0.9, 1.0, 0.5))
	for ry in [191.0, 195.0, 199.0, 203.0]:
		c.draw_line(_fp(-17, ry), _fp(17, ry), Color(0.75, 0.9, 1.0, 0.3), 1.0)
	_sym(c, [Vector2(0, 118), Vector2(20, 118), Vector2(38, 121), Vector2(49, 127), Vector2(51, 136), Vector2(47, 152), Vector2(41, 170), Vector2(33, 184), Vector2(20, 189), Vector2(0, 190)])
	_pair(c, [Vector2(10, 120), Vector2(28, 126), Vector2(47, 130)], PINK, 1.2)
	_pair(c, [Vector2(3, 138), Vector2(20, 145), Vector2(40, 140)], fine, 1.1)
	_pair(c, [Vector2(3, 168), Vector2(20, 173), Vector2(36, 166)], fine, 1.1)
	c.draw_line(_fp(0, 122), _fp(0, 186), fine, 1.1)
	var core: Vector2 = _fp(0, 150)
	c.draw_circle(core, 11.0, Color(1.0, 0.25, 0.65, 0.16))
	c.draw_circle(core, 7.0, Color(1.0, 0.25, 0.65, 0.3))
	c.draw_circle(core, 4.4, Color(1.0, 0.5, 0.8, 0.95))
	c.draw_arc(core, 7.0, 0, TAU, 20, Color(0.3, 0.9, 1.0, 0.85), 1.2, true)
	_sym(c, [Vector2(0, 104), Vector2(6, 105), Vector2(6.5, 112), Vector2(8, 120), Vector2(0, 120)], JOINT_DARK, Color(0.1, 0.13, 0.22, 0.97), Color(0.3, 0.9, 1.0, 0.5))
	_sym(c, [Vector2(0, 62), Vector2(12, 64), Vector2(17, 74), Vector2(18, 86), Vector2(14, 98), Vector2(7, 105), Vector2(0, 107)])
	_sym(c, [Vector2(0, 77), Vector2(12, 77), Vector2(14, 81), Vector2(12, 86), Vector2(0, 86)], Color(0.1, 0.45, 0.6, 0.85), Color(0.3, 0.9, 1.0, 0.8), Color(0.3, 0.9, 1.0, 0.95))     # the visor
	_pair(c, [Vector2(2, 94), Vector2(7, 95)], fine, 1.0)
	_pair(c, [Vector2(10, 66), Vector2(13, 72)], fine, 1.0)
	for sg in [1.0, -1.0]:
		c.draw_circle(_fp(18.5 * sg, 88), 3.4, Color(0.55, 0.62, 0.74, 0.9))
		c.draw_arc(_fp(18.5 * sg, 88), 3.4, 0, TAU, 14, EDGE, 1.1, true)
	# shoulder caps and the joints, over everything
	_both(c, [Vector2(42, 122), Vector2(55, 121), Vector2(63, 127), Vector2(64, 135), Vector2(55, 139), Vector2(46, 135)])
	_joint(c, 56, 141, 7.5)
	_joint(c, 58.5, 194, 6.0)
	_joint(c, 62, 254, 4.2)
	_joint(c, 21, 253, 8.0)
	_joint(c, 17, 321, 6.5)
	_joint(c, 14.5, 381, 4.2)

## dotted lines from the slot tiles to the body part each stands for
func _leaders(c: CanvasItem, on_imp: bool) -> void:
	for slot in SPOTS:
		if on_imp and not SPOT_PART.has(slot):
			continue
		var r: Rect2 = slot_rect(slot)
		var side: float = (SPOTS[slot] as Vector2).x
		var a: Vector2 = Vector2(r.end.x if side < 0 else r.position.x, r.get_center().y)
		var b: Vector2 = _fp((ANCHOR[slot] as Vector2).x, (ANCHOR[slot] as Vector2).y)
		var active: bool = cur == "s:" + slot
		var col: Color = Color(1.0, 0.8, 0.25, 0.9) if active else Color(0.3, 0.9, 1.0, 0.32)
		var dist: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / maxf(dist, 1.0)
		var d := 0.0
		while d < dist - 3.0:
			c.draw_line(a + dir * d, a + dir * minf(d + 4.0, dist), col, 1.4 if active else 1.0)
			d += 8.0
		c.draw_circle(b, 3.0 if active else 2.2, col)

# ---------------------------------------------------------------- the card
func _panel(c: CanvasItem, r: Rect2) -> void:
	c.draw_rect(r, Color(0.04, 0.06, 0.11, 0.92))
	c.draw_rect(r, CYAN, false, 1.5)
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3), MAGENTA)

func _card_panel(c: CanvasItem, t: float) -> void:
	_panel(c, CARD)
	var x: float = CARD.position.x + 18.0
	var maxw: float = CARD.size.x - 36.0
	if tab == "implants" and (cur_part_for_rows != "" ) and (cur.begins_with("s:") or cur.begins_with("r:")) and item_at(cur) == null:
		_implant_list(c, x, maxw, t)
	else:
		var it = item_at(cur) if (cur.begins_with("s:") or cur.begins_with("g:")) else null
		if it != null:
			_item_card(c, it, x, CARD.position.y + 40.0, maxw)
		elif cur.begins_with("s:"):
			var slot: String = cur.substr(2)
			_txt(c, String(INV.NAMES[slot]).to_upper(), Vector2(x, CARD.position.y + 40.0), 26, Color.WHITE)
			_txt(c, "Empty", Vector2(x, CARD.position.y + 68.0), 16, Color(0.6, 0.7, 0.8))
		else:
			_txt(c, "Empty tile", Vector2(x, CARD.position.y + 40.0), 22, Color(0.6, 0.7, 0.8))
	# purse and message at the foot of the card
	var fy: float = CARD.end.y - 14.0
	if game != null:
		_txt(c, "¥%d     loose rounds %d" % [game.yen, game.ammo_total()], Vector2(x, fy), 16, YELLOW)
	if msg != "" and msg_t > 0.0:
		var lines: Array = wrap_text(msg, 16, maxw - (190.0 if tab == "equipment" else 0.0))
		var my: float = fy - 28.0 - (lines.size() - 1) * 20.0
		for ln in lines:
			_txt(c, ln, Vector2(x, my), 16, MAGENTA)
			my += 20.0

func _kv(c: CanvasItem, y: float, k: String, v: String, x: float, maxw: float) -> float:
	_txt(c, k, Vector2(x, y), 16, Color(0.6, 0.72, 0.85))
	var kw: float = minf(150.0, maxw * 0.4)
	_fit_txt(c, v, Vector2(x + kw, y), 17, Color.WHITE, maxw - kw)
	return y + 23.0

func _item_card(c: CanvasItem, it, x: float, y0: float, maxw: float) -> void:
	var d: Dictionary = it.def
	var name: String = String(d["name"]) + (" x%d" % it.count if it.count > 1 else "")
	_fit_txt(c, name.to_upper(), Vector2(x, y0), 26, Color.WHITE, maxw)
	var y: float = y0 + 30.0
	var eq: String = INV.equip_text(it)
	if d.has("implant"):
		eq = "Implant: %s" % String(IMP.PARTS[_part_index(String(d.get("part", "head")))]["name"]).split(" /")[0].to_lower()
	_fit_txt(c, eq, Vector2(x, y), 17, YELLOW if INV.is_equipment(it) or d.has("implant") else Color(0.6, 0.7, 0.8), maxw)
	y += 12.0
	var desc: String = String(d.get("desc", ""))
	if desc != "":
		for ln in wrap_text(desc, 16, maxw):
			y += 20.0
			_txt(c, ln, Vector2(x, y), 16, Color(0.75, 0.86, 0.95))
	y += 22.0
	c.draw_line(Vector2(x, y - 8.0), Vector2(x + maxw, y - 8.0), Color(0.3, 0.9, 1.0, 0.3), 1.0)
	y += 12.0
	if d.has("gun"):
		y = _gun_lines(c, it, x, y, maxw)
	elif d.has("melee"):
		y = _melee_lines(c, it, x, y, maxw)
	if d.has("armor"):
		var left: int = game.item_armor_left(it)
		y = _kv(c, y, "Armor", "%d   (%s)" % [int(d["armor"]["phys"]), "BROKEN" if left <= 0 else "%d%% left" % (100 * left / maxi(1, int(d["armor"]["dur"])))], x, maxw)
	if d.has("pocket"):
		y = _kv(c, y, "Pockets", "+%d tiles" % int(d["pocket"]["tiles"]), x, maxw)
	if d.has("bottle"):
		y = _kv(c, y, "Water", "%d / %d mL" % [it.fill, int(d["bottle"]["ml"])], x, maxw)
	if d.has("food"):
		var f: Dictionary = d["food"]
		y = _kv(c, y, "Restores", "%d hp, %d stamina, %d kcal" % [int(f.get("hp", 0)), int(f.get("stam", 0)), int(f.get("kcal", 0))], x, maxw)
	if d.has("implant"):
		var idf: Dictionary = IMP.get_def(String(d["implant"]))
		if not idf.is_empty():
			y = _kv(c, y, "Grade", str(int(idf.get("grade", 1))), x, maxw)
			if idf.has("armor"):
				y = _kv(c, y, "Armor", "%d  (plating %d)" % [int(idf["armor"]), int(idf["dur"])], x, maxw)
			if not idf.get("live", true):
				y = _kv(c, y, "Status", "no effect yet", x, maxw)
	if d.has("mod"):
		y = _kv(c, y, "Mod slot", String(d["mod"]["slot"]), x, maxw)
	if d.has("price") and int(d["price"]) > 0:
		y = _kv(c, y, "Value", "¥%d" % int(d["price"]), x, maxw)

func _gun_lines(c: CanvasItem, it, x: float, y: float, maxw: float) -> float:
	var s: Dictionary = GP.stats(it)
	if s.is_empty():
		return y
	y = _kv(c, y, "Class", "%s   %s" % [String(s["cls"]), String(s["cal"])], x, maxw)
	y = _kv(c, y, "Hands", "%d" % int(INV.hands(it)), x, maxw)
	y = _kv(c, y, "Damage", "%d - %d  (%s)" % [int(s["dmg"][0]), int(s["dmg"][1]), String(s["label"])], x, maxw)
	y = _kv(c, y, "Range", "natural %d - %d,  effective %d tiles" % [int(s["range_lo"]), int(s["range_hi"]), int(s["eff_range"])], x, maxw)
	y = _kv(c, y, "Magazine", "%d / %d" % [it.loaded, int(s["mag"])], x, maxw)
	var modes: Array = []
	for m in s["modes"]:
		modes.append("%s %d" % [String(m[0]), int(m[1])] if int(m[1]) > 1 else String(m[0]))
	y = _kv(c, y, "Fire modes", ", ".join(modes), x, maxw)
	y = _kv(c, y, "Reload", "%d turns" % int(s["reload"]), x, maxw)
	y = _kv(c, y, "Accuracy", "%+d   max aim %d" % [GP.acc_points(s), int(s["max_aim"])], x, maxw)
	y = _kv(c, y, "Noise", "%d" % int(s["noise"]), x, maxw)
	if int(s["pellets"]) > 1:
		y = _kv(c, y, "Pellets", "%d" % int(s["pellets"]), x, maxw)
	if float(s["jam"]) > 0.0:
		y = _kv(c, y, "Jam chance", "%.1f%% per shot" % float(s["jam"]), x, maxw)
	var slots: Array = []
	for sl in s["slots"]:
		var cur_mod := "-"
		for m in it.mods:
			if m.def["mod"]["slot"] == sl:
				cur_mod = String(m.def["name"])
		slots.append("%s: %s" % [String(sl), cur_mod])
	if not slots.is_empty():
		y = _kv(c, y, "Mod slots", "; ".join(slots), x, maxw)
	return y

func _melee_lines(c: CanvasItem, it, x: float, y: float, maxw: float) -> float:
	var m: Dictionary = it.def["melee"]
	y = _kv(c, y, "Hands", "%d" % int(INV.hands(it)), x, maxw)
	y = _kv(c, y, "Damage", "%d - %d" % [int(m["dmg"][0]), int(m["dmg"][1])], x, maxw)
	y = _kv(c, y, "Reach", "%d tile%s" % [int(m["reach"]), "" if int(m["reach"]) == 1 else "s"], x, maxw)
	y = _kv(c, y, "Accuracy", "%+d" % int(m.get("acc", 0)), x, maxw)
	var bits: Array = []
	for k in ["fast", "parry", "stun", "sneak", "trip"]:
		if m.has(k):
			bits.append("%s %s" % [k, str(m[k])])
	if m.get("bleed", false):
		bits.append("bleeds")
	if m.get("slow", false):
		bits.append("slow")
	if not bits.is_empty():
		y = _kv(c, y, "Qualities", ", ".join(bits), x, maxw)
	return y

func _implant_list(c: CanvasItem, x: float, maxw: float, t: float) -> void:
	var part: String = cur_part_for_rows
	var pname: String = String(IMP.PARTS[_part_index(part)]["name"])
	_txt(c, pname.to_upper(), Vector2(x, CARD.position.y + 40.0), 26, Color.WHITE)
	if _rows.is_empty():
		_txt(c, "No implant for this part in your pack, and none fitted.", Vector2(x, CARD.position.y + 80.0), 16, Color(0.6, 0.7, 0.8))
		return
	for k in _rows.size():
		var row: Dictionary = _rows[k]
		var r: Rect2 = row_rect(k)
		var d: Dictionary = row["def"]
		var fitted: bool = row["fitted"]
		var on: bool = cur == "r:%d" % k
		c.draw_rect(r, Color(0.3, 0.9, 1.0, 0.16) if on else Color(1, 1, 1, 0.04))
		if on:
			c.draw_rect(r, MAGENTA, false, 2.0)
		draw_icon(c, "trl_imp_" + String(row["id"]), Rect2(r.position.x + 6.0, r.position.y + 22.0, 52.0, 52.0))
		var tx: float = r.position.x + 68.0
		_fit_txt(c, String(d["name"]), Vector2(tx, r.position.y + 24.0), 22, Color.WHITE, r.size.x - 82.0)
		var status: String = "grade %d   " % int(d.get("grade", 1))
		var col: Color = YELLOW
		if fitted:
			status += "FITTED  -  Enter takes it out"
			if not game.has_implant(d["id"]):
				status = "grade %d   OFFLINE - the %s is disabled" % [int(d.get("grade", 1)), game.BODY.PART_GROUP.get(d["part"], "limb")]
			elif d.has("armor"):
				status += "   plating %d/%d" % [int(game.imp_dur.get(d["id"], int(d["dur"]))), int(d["dur"])]
		else:
			status += "in your pack  -  Enter fits it"
			col = Color(0.5, 1.0, 0.7)
		_fit_txt(c, status, Vector2(tx, r.position.y + 48.0), 16, col, r.size.x - 82.0)
		_fit_txt(c, String(d["desc"]), Vector2(tx, r.position.y + 72.0), 15, Color(0.7, 0.82, 0.92), r.size.x - 82.0)
