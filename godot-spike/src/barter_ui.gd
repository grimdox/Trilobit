extends RefCounted
## The barter screen.  Top: the merchant's face and name (left) and their wares in a scrollable block of tiles, 10 across and 3 rows showing.
## Bottom: your pack in the same shape.  Click an item to pick it up, click (drop it) on the other side to trade it; right-click or Ctrl trades the
## item under the highlight straight away.  Arrows or numpad move the yellow highlight, Enter picks up and puts down, Shift picks up one of a stack.
## Prices come from barter.gd; your yen sit at the top right.
const GearScript = preload("res://src/gear_ui.gd")
const INV = preload("res://src/inventory.gd")
const DS = preload("res://src/dollspec.gd")
const DIMG = preload("res://addons/trilobit_doll/doll_image.gd")
const ADAPT = preload("res://addons/trilobit_doll/trilobit_adapter.gd")
const DOLLS := "res://gfx/dolls"

const CYAN := Color(0.3, 0.9, 1.0)
const MAGENTA := Color(1.0, 0.25, 0.65)
const YELLOW := Color(1.0, 0.8, 0.25)
const T := 56.0
const PITCH := 62.0
const COLS := 10
const ROWS := 3
const M_ORIGIN := Vector2(316.0, 84.0)             # the merchant's tiles
const P_ORIGIN := Vector2(316.0, 330.0)            # yours
const FACE := Rect2(30.0, 56.0, 262.0, 250.0)
const TALK := Rect2(30.0, 372.0, 262.0, 150.0)
const CARD := Rect2(960.0, 56.0, 290.0, 616.0)
const LOG := Rect2(316.0, 548.0, 620.0, 124.0)

var game = null
var who: int = -1                         # the merchant (agent index)
var menu: Dictionary = {}                 # Economy.menu_for(who): its title and text lines, and the service options
var gear = GearScript.new()               # borrowed for tiles, icons and the item card
var lines: Array = []                     # what the merchant says
var cur: String = "m:0"                   # "m:<n>" a wares tile in view, "p:<n>" one of yours, "s:<k>" a service button
var held: Dictionary = {}                 # {item, src: "m" or "p", tile (for "m"), g, i (for "p")}
var m_scroll: int = 0
var p_scroll: int = 0
var mouse := Vector2(-100, -100)
var use_mouse := false
var msg: String = ""
var msg_t: float = 0.0
var trail: Array = []                     # the last transactions, newest last
var _doll_lib = null
var _services: Array = []                 # [{label, k}] option indices of the menu that are not wares

func open(g, tileset, agent: int, m: Dictionary) -> void:
	game = g
	who = agent
	menu = m
	gear.game = g
	gear.ts = tileset
	held = {}
	m_scroll = 0
	p_scroll = 0
	cur = "m:0"
	msg = ""
	trail = []
	_refresh_services()
	lines = []
	var tx: Array = m.get("text", [])
	for k in mini(2, tx.size()):
		lines.append(String(tx[k]))
	if lines.size() < 2:
		lines.append("\"What can I offer you today?\"")

func _refresh_services() -> void:
	_services = []
	var opts: Array = menu.get("options", [])
	for k in opts.size():
		var op: String = String(opts[k]["op"])
		if not (op in ["buy", "implant", "close"]):
			_services.append({"label": String(opts[k]["label"]), "k": k})

func say(s: String, reply: Array = []) -> void:
	msg = s
	msg_t = 5.0
	if s != "":
		trail.append(s)
		if trail.size() > 6:
			trail.pop_front()
	if not reply.is_empty():
		lines = [String(reply[(who * 7 + trail.size()) % reply.size()])]

# ---------------------------------------------------------------- the two blocks of tiles
func shop_tiles() -> Array:
	return game.barter.shop(who)["tiles"]

func m_rows() -> int:
	return maxi(ROWS, (shop_tiles().size() + COLS - 1) / COLS)

## the pack as one list of [group, index], base first, then the pockets
func flow() -> Array:
	var out: Array = []
	for grp in game.inv.groups():
		for i in game.inv.group_size(grp):
			out.append([grp, i])
	return out

func p_rows() -> int:
	return maxi(ROWS, (flow().size() + COLS - 1) / COLS)

func m_rect(v: int) -> Rect2:
	return Rect2(M_ORIGIN.x + (v % COLS) * PITCH, M_ORIGIN.y + (v / COLS) * PITCH, T, T)

func p_rect(v: int) -> Rect2:
	return Rect2(P_ORIGIN.x + (v % COLS) * PITCH, P_ORIGIN.y + (v / COLS) * PITCH, T, T)

func s_rect(k: int) -> Rect2:
	return Rect2(TALK.position.x, TALK.end.y + 14.0 + k * 42.0, TALK.size.x, 34.0)

func m_index(v: int) -> int:
	return m_scroll * COLS + v

func p_index(v: int) -> int:
	return p_scroll * COLS + v

func m_tile_at(v: int):
	var idx: int = m_index(v)
	var t: Array = shop_tiles()
	return t[idx] if idx < t.size() else null

## the item of one of your tiles in view, or null; also false for tiles beyond your capacity
func p_item_at(v: int):
	var f: Array = flow()
	var idx: int = p_index(v)
	if idx >= f.size():
		return null
	return game.inv.grid[f[idx][0]][f[idx][1]]

func p_exists(v: int) -> bool:
	return p_index(v) < flow().size()

func targets() -> Array:
	var out: Array = []
	for v in COLS * ROWS:
		out.append({"key": "m:%d" % v, "rect": m_rect(v)})
	for v in COLS * ROWS:
		if p_exists(v):
			out.append({"key": "p:%d" % v, "rect": p_rect(v)})
	for k in _services.size():
		out.append({"key": "s:%d" % k, "rect": s_rect(k)})
	return out

func target_at(p: Vector2) -> String:
	for e in targets():
		if (e["rect"] as Rect2).has_point(p):
			return e["key"]
	return ""

## the tile and the item under a key: {item, tile} (tile only for the merchant's)
func at_key(key: String) -> Dictionary:
	if key.begins_with("m:"):
		var t = m_tile_at(int(key.substr(2)))
		return {} if t == null else {"item": t["item"], "tile": t}
	if key.begins_with("p:"):
		var it = p_item_at(int(key.substr(2)))
		return {} if it == null else {"item": it}
	return {}

# ---------------------------------------------------------------- moving about
func move(dir: Vector2i) -> bool:
	var tg: Array = targets()
	var from := Rect2()
	var found := false
	for e in tg:
		if e["key"] == cur:
			from = e["rect"]
			found = true
	if not found:
		cur = "m:0"
		return true
	var c: Vector2 = from.get_center()
	var best := ""
	var bs := 1.0e9
	for pass_i in 2:
		for e in tg:
			if e["key"] == cur:
				continue
			var d: Vector2 = (e["rect"] as Rect2).get_center() - c
			var diag: bool = dir.x != 0 and dir.y != 0
			var along: float = (d.x * dir.x + d.y * dir.y) * (0.7071 if diag else 1.0)
			if along < 6.0:
				continue
			var across: float = absf(d.x * dir.y - d.y * dir.x) * 0.7071 if diag else (absf(d.y) if dir.x != 0 else absf(d.x))
			if pass_i == 0 and across > (60.0 if diag else 24.0):
				continue
			var score: float = along + 3.0 * across
			if score < bs:
				bs = score
				best = e["key"]
		if best != "":
			break
	if best == "":
		# off the edge of a block: scroll it if there is more
		if cur.begins_with("m:"):
			if dir.y > 0 and m_scroll < m_rows() - ROWS and int(cur.substr(2)) / COLS == ROWS - 1:
				m_scroll += 1
				return true
			if dir.y < 0 and m_scroll > 0 and int(cur.substr(2)) / COLS == 0:
				m_scroll -= 1
				return true
		elif cur.begins_with("p:"):
			if dir.y > 0 and p_scroll < p_rows() - ROWS and int(cur.substr(2)) / COLS == ROWS - 1:
				p_scroll += 1
				return true
			if dir.y < 0 and p_scroll > 0 and int(cur.substr(2)) / COLS == 0:
				p_scroll -= 1
				return true
		return false
	cur = best
	use_mouse = false
	return true

func hover(p: Vector2) -> bool:
	mouse = p
	use_mouse = true
	var k: String = target_at(p)
	if k != "" and k != cur:
		cur = k
		return true
	return false

func scroll(delta: int, p: Vector2) -> void:
	if p.y < 290.0:
		m_scroll = clampi(m_scroll + delta, 0, m_rows() - ROWS)
	else:
		p_scroll = clampi(p_scroll + delta, 0, p_rows() - ROWS)

# ---------------------------------------------------------------- trading
func _split(it, n: int):
	var one = game._new_item(it.id())
	one.count = n
	one.fill = it.fill
	it.count -= n
	return one

## pick up what the highlight is on (one unit of a stack with `single`)
func pick(key: String, single: bool = false) -> void:
	if key.begins_with("s:"):
		return
	if key.begins_with("m:"):
		var idx: int = m_index(int(key.substr(2)))
		var t: Dictionary = game.barter.take(who, idx, single)
		if t.is_empty():
			return
		held = {"item": t["item"], "src": "m", "tile": t}
		return
	var f: Array = flow()
	var pi: int = p_index(int(key.substr(2)))
	if pi >= f.size():
		return
	var grp: String = f[pi][0]
	var i: int = f[pi][1]
	var it = game.inv.grid[grp][i]
	if it == null:
		return
	if single and it.stackable() and it.count > 1:
		held = {"item": _split(it, 1), "src": "p", "g": grp, "i": i}
		return
	game.inv.grid[grp][i] = null
	held = {"item": it, "src": "p", "g": grp, "i": i}

## put the held item back where it came from
func give_back() -> void:
	if held.is_empty():
		return
	if held["src"] == "m":
		game.barter.shelve(who, held["tile"])
	else:
		var it = held["item"]
		var grp: String = held["g"]
		if game.inv.grid.has(grp) and game.inv.grid[grp][held["i"]] == null:
			game.inv.grid[grp][held["i"]] = it
		elif not game.inv.stow(it):
			game._put(game.pc, it)
			game.say("No room: you drop the %s." % it.def["name"])
	held = {}

func close() -> void:
	give_back()

## Esc: true if it only put the held item back
func cancel() -> bool:
	if not held.is_empty():
		give_back()
		return true
	return false

func drop(key: String) -> void:
	if held.is_empty() or key.begins_with("s:"):
		return
	if held["src"] == "m":
		if key.begins_with("p:"):
			var f: Array = flow()
			var pi: int = p_index(int(key.substr(2)))
			var at_g := ""
			var at_i := -1
			if pi < f.size():
				at_g = f[pi][0]
				at_i = f[pi][1]
			var r: Dictionary = game.barter.buy(who, held["tile"], at_g, at_i)
			if r["ok"]:
				held = {}
				say(String(r["msg"]), ["\"Good choice.\"", "\"Pleasure doing business.\"", "\"That won't let you down.\""])
			else:
				game.barter.shelve(who, held["tile"])
				held = {}
				say(String(r["msg"]), ["\"Come back when you can pay.\"", "\"Your pockets say otherwise.\""])
		else:
			give_back()
		return
	# something of yours
	if key.begins_with("m:"):
		var it = held["item"]
		var r2: Dictionary = game.barter.sell(who, it)
		if r2["ok"]:
			held = {}
			say(String(r2["msg"]), ["\"Fair enough.\"", "\"I can move that.\"", "\"It will not sit on my shelf long.\""])
		else:
			give_back()
			say(String(r2["msg"]), ["\"Not touching that.\""])
		return
	var f2: Array = flow()
	var ti: int = p_index(int(key.substr(2)))
	if ti >= f2.size():
		return
	var res: Dictionary = game.inv.put_grid(f2[ti][0], f2[ti][1], held["item"])
	if res["ok"]:
		var back = res["back"]
		if back != null:
			held = {"item": back, "src": "p", "g": f2[ti][0], "i": f2[ti][1]}
		else:
			held = {}

## Enter, or a left click on the highlight
func press(single: bool = false) -> void:
	if cur.begins_with("s:"):
		_service(int(cur.substr(2)))
		return
	if held.is_empty():
		pick(cur, single)
	else:
		drop(cur)

## Ctrl or a right click: buy the tile, or sell the item, at once
func auto() -> void:
	if not held.is_empty():
		return
	if cur.begins_with("m:"):
		if at_key(cur).is_empty():
			return
		pick(cur, false)
		if not held.is_empty():
			drop("p:-1")
	elif cur.begins_with("p:"):
		if at_key(cur).is_empty():
			return
		pick(cur, false)
		if not held.is_empty():
			drop("m:0")

func _service(k: int) -> void:
	if k >= _services.size():
		return
	var idx: int = int(_services[k]["k"])
	var before: int = game.yen
	var next: Dictionary = game.eco.choose(menu, idx)
	if next.is_empty():
		say("", ["\"Anything else, come back.\""])
		return
	menu = next
	_refresh_services()
	if game.yen != before:
		say("You pay ¥%d." % (before - game.yen))
	var tx: Array = menu.get("text", [])
	if not tx.is_empty():
		lines = [String(tx[0])]

func click(p: Vector2, right: bool, single: bool = false) -> void:
	hover(p)
	var k: String = target_at(p)
	if right:
		if k != "":
			auto()
		return
	if k == "":
		return
	press(single)

# ---------------------------------------------------------------- drawing
func _txt(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	c.draw_string(gear.font, pos, s, align, width, size, col)

func _rtxt(c: CanvasItem, s: String, right_x: float, y: float, size: int, col: Color) -> void:
	gear._rtxt(c, s, right_x, y, size, col)

func draw(c: CanvasItem, W: float, H: float, t: float, dt: float) -> void:
	msg_t = maxf(0.0, msg_t - dt)
	if game == null or who < 0:
		return
	var title: String = String(menu.get("title", game.name_of(who)))
	_txt(c, "BARTER", Vector2(30, 36), 26, Color.WHITE)
	_txt(c, "YEN", Vector2(W - 250.0, 28.0), 14, Color(0.6, 0.72, 0.85))
	_rtxt(c, "¥ %s" % _commas(game.yen), W - 30.0, 40.0, 34, YELLOW)
	c.draw_line(Vector2(30, 48), Vector2(W - 30.0, 48), Color(0.3, 0.9, 1.0, 0.3), 1.0)
	_face(c, title, t)
	# the wares
	_txt(c, "WARES", Vector2(M_ORIGIN.x, M_ORIGIN.y - 10.0), 14, CYAN)
	var tiles: Array = shop_tiles()
	for v in COLS * ROWS:
		var r: Rect2 = m_rect(v)
		var tile = m_tile_at(v)
		var it = null if tile == null else tile["item"]
		gear.draw_tile(c, r, it)
		if tile != null:
			var price: int = game.barter.unit_price(who, tile)
			var afford: bool = game.yen >= price
			c.draw_rect(Rect2(r.position.x + 1, r.end.y - 14.0, r.size.x - 2, 13.0), Color(0.02, 0.03, 0.06, 0.78))
			_txt(c, "¥%d" % price, Vector2(r.position.x + 3.0, r.end.y - 3.0), 11, YELLOW if afford else Color(0.9, 0.4, 0.4))
		if cur == "m:%d" % v:
			gear._cursor(c, r, t)
	_scrollbar(c, M_ORIGIN, m_scroll, m_rows())
	# your pack
	c.draw_line(Vector2(M_ORIGIN.x, 300.0), Vector2(M_ORIGIN.x + COLS * PITCH - 6.0, 300.0), Color(0.3, 0.9, 1.0, 0.25), 1.0)
	_txt(c, "YOUR PACK   %d / %d" % [game.inv.used(), game.inv.capacity()], Vector2(P_ORIGIN.x, P_ORIGIN.y - 10.0), 14, CYAN)
	for v in COLS * ROWS:
		var r2: Rect2 = p_rect(v)
		if not p_exists(v):
			c.draw_rect(r2, Color(0.1, 0.11, 0.14, 0.5))
			c.draw_rect(r2, Color(0.25, 0.28, 0.35, 0.35), false, 1.0)
			continue
		var it2 = p_item_at(v)
		gear.draw_tile(c, r2, it2)
		if it2 != null and game.barter.can_sell(it2):
			c.draw_rect(Rect2(r2.position.x + 1, r2.end.y - 14.0, r2.size.x - 2, 13.0), Color(0.02, 0.03, 0.06, 0.6))
			_txt(c, "¥%d" % (game.barter.offer(who, it2) * it2.count), Vector2(r2.position.x + 3.0, r2.end.y - 3.0), 11, Color(0.5, 1.0, 0.7))
		if cur == "p:%d" % v:
			gear._cursor(c, r2, t)
	_scrollbar(c, P_ORIGIN, p_scroll, p_rows())
	_log(c)
	_card(c)
	# the held item follows the mouse, or the highlight when the keys are driving
	if not held.is_empty():
		var hp: Vector2 = mouse - Vector2(T, T) * 0.5
		if not use_mouse:
			for e in targets():
				if e["key"] == cur:
					hp = (e["rect"] as Rect2).position + Vector2(10, 10)
		var hr := Rect2(hp, Vector2(T, T))
		c.draw_rect(hr, Color(0.17, 0.18, 0.22, 0.92))
		c.draw_rect(hr, MAGENTA, false, 2.0)
		gear.draw_icon(c, gear.icon_id(held["item"]), hr)
		if held["item"].count > 1:
			_rtxt(c, "x%d" % held["item"].count, hr.end.x - 3.0, hr.end.y - 4.0, 13, YELLOW)
	var hint: String
	if not held.is_empty():
		hint = "Holding the %s  -  click or Enter on the other side trades it, on your own pack moves it  -  Esc puts it back" % held["item"].def["name"]
	else:
		hint = "Arrows / numpad / mouse move  -  Enter or click picks up  -  Ctrl or right-click trades at once  -  Shift takes one of a stack  -  Wheel scrolls  -  Esc leaves"
	_txt(c, hint, Vector2(30, H - 12.0), 14, Color(0.6, 0.72, 0.85))

func _commas(n: int) -> String:
	var s: String = str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

func _scrollbar(c: CanvasItem, origin: Vector2, scroll_v: int, rows: int) -> void:
	if rows <= ROWS:
		return
	var x: float = origin.x + COLS * PITCH - 2.0
	var h: float = ROWS * PITCH - 6.0
	c.draw_rect(Rect2(x, origin.y, 6.0, h), Color(1, 1, 1, 0.08))
	var th: float = maxf(24.0, h * float(ROWS) / float(rows))
	var ty: float = origin.y + (h - th) * float(scroll_v) / float(rows - ROWS)
	c.draw_rect(Rect2(x, ty, 6.0, th), CYAN)

## the merchant: a head-and-shoulders portrait from their own paper doll, their name, what they say, and any services
func _face(c: CanvasItem, title: String, t: float) -> void:
	c.draw_rect(FACE, Color(0.03, 0.05, 0.1))
	for gy in range(int(FACE.position.y) + 12, int(FACE.end.y), 12):
		c.draw_line(Vector2(FACE.position.x, gy), Vector2(FACE.end.x, gy), Color(0.3, 0.9, 1.0, 0.05), 1.0)
	c.draw_circle(FACE.get_center() + Vector2(0, 20), 96.0, Color(1.0, 0.25, 0.65, 0.06))
	c.draw_arc(FACE.get_center() + Vector2(0, 20), 96.0, 0, TAU, 64, Color(1.0, 0.25, 0.65, 0.35), 1.5, true)
	_doll_head(c)
	c.draw_rect(FACE, CYAN, false, 1.5)
	c.draw_rect(Rect2(FACE.position.x, FACE.position.y, FACE.size.x, 3.0), MAGENTA)
	var name_line: String = title
	var sub := ""
	var cut: int = title.find(" - ")
	if cut > 0:
		name_line = title.substr(0, cut)
		sub = title.substr(cut + 3)
	gear._fit_txt(c, name_line.to_upper(), Vector2(TALK.position.x, FACE.end.y + 28.0), 22, Color.WHITE, TALK.size.x)
	if sub != "":
		gear._fit_txt(c, sub, Vector2(TALK.position.x, FACE.end.y + 48.0), 15, Color(0.6, 0.75, 0.9), TALK.size.x)
	# the speech
	c.draw_rect(TALK, Color(0.04, 0.06, 0.11, 0.92))
	c.draw_rect(TALK, CYAN, false, 1.5)
	var y: float = TALK.position.y + 26.0
	for ln in lines:
		for w in gear.wrap_text(String(ln), 16, TALK.size.x - 28.0):
			_txt(c, w, Vector2(TALK.position.x + 14.0, y), 16, Color(0.85, 0.93, 1.0))
			y += 21.0
		y += 6.0
	for k in _services.size():
		var r: Rect2 = s_rect(k)
		var on: bool = cur == "s:%d" % k
		c.draw_rect(r, Color(0.3, 0.9, 1.0, 0.2) if on else Color(1, 1, 1, 0.05))
		c.draw_rect(r, YELLOW if on else Color(0.35, 0.45, 0.55), false, 2.0 if on else 1.0)
		gear._fit_txt(c, String(_services[k]["label"]), Vector2(r.position.x + 8.0, r.position.y + 22.0), 14, Color.WHITE, r.size.x - 16.0)

func _doll_head(c: CanvasItem) -> void:
	if _doll_lib == null:
		_doll_lib = DIMG.for_library(DOLLS)
	if not _doll_lib.ok():
		return
	var spec: Dictionary = DS.for_person(game, who)
	var lk: Dictionary = spec["look"]
	var ds = ADAPT.spec_from_game(spec["layers"], lk, "", String(lk.get("size", "m")), DOLLS)
	if bool(lk.get("hid", false)):
		ds.hair = "bald"
	var tex: Texture2D = _doll_lib.texture(ds, "unarmed/idle/0")
	if tex == null:
		return
	# head and shoulders: the top 34% of the figure's opaque area, as wide as the shoulders
	var used: Rect2i = tex.get_image().get_used_rect()
	if used.size.x <= 0:
		return
	var src := Rect2(float(used.position.x) - 2.0, float(used.position.y) - 2.0, float(used.size.x) + 4.0, float(used.size.y) * 0.34)
	var k: float = minf(FACE.size.x / src.size.x, FACE.size.y / src.size.y) * 0.94
	var dst := Rect2(FACE.get_center().x - src.size.x * k * 0.5, FACE.position.y + 8.0, src.size.x * k, src.size.y * k)
	c.draw_texture_rect_region(tex, dst, src)

func _log(c: CanvasItem) -> void:
	c.draw_rect(LOG, Color(0.04, 0.06, 0.11, 0.9))
	c.draw_rect(LOG, Color(0.3, 0.9, 1.0, 0.5), false, 1.0)
	_txt(c, "RECEIPTS", Vector2(LOG.position.x + 12.0, LOG.position.y + 20.0), 13, Color(0.6, 0.72, 0.85))
	var y: float = LOG.position.y + 42.0
	var shown: Array = trail.slice(maxi(0, trail.size() - 4))
	for k in shown.size():
		var fresh: bool = k == shown.size() - 1 and msg_t > 0.0
		gear._fit_txt(c, String(shown[k]), Vector2(LOG.position.x + 12.0, y), 15, MAGENTA if fresh else Color(0.7, 0.8, 0.9), LOG.size.x - 24.0)
		y += 21.0

func _card(c: CanvasItem) -> void:
	gear._panel(c, CARD)
	var x: float = CARD.position.x + 16.0
	var maxw: float = CARD.size.x - 32.0
	var e: Dictionary = at_key(cur)
	if e.is_empty():
		var hint := "Pick something up to see what it is."
		var y0: float = CARD.position.y + 40.0
		for w in gear.wrap_text(hint, 16, maxw):
			_txt(c, w, Vector2(x, y0), 16, Color(0.6, 0.7, 0.8))
			y0 += 21.0
		return
	var it = e["item"]
	gear._item_card(c, it, x, CARD.position.y + 40.0, maxw)
	var fy: float = CARD.end.y - 20.0
	if e.has("tile"):
		var each: int = game.barter.unit_price(who, e["tile"])
		var total: int = each * it.count
		_txt(c, "PRICE", Vector2(x, fy - 54.0), 13, Color(0.6, 0.72, 0.85))
		_txt(c, "¥%d" % total, Vector2(x, fy - 20.0), 34, YELLOW if game.yen >= total else Color(0.9, 0.4, 0.4))
		if it.count > 1:
			_txt(c, "¥%d each, %d in the stack" % [each, it.count], Vector2(x, fy + 2.0), 14, Color(0.7, 0.8, 0.9))
	else:
		var pay: int = game.barter.offer(who, it) * it.count
		if game.barter.can_sell(it) and pay > 0:
			_txt(c, "THEY PAY", Vector2(x, fy - 54.0), 13, Color(0.6, 0.72, 0.85))
			_txt(c, "¥%d" % pay, Vector2(x, fy - 20.0), 34, Color(0.5, 1.0, 0.7))
		else:
			_txt(c, "Not for sale to them.", Vector2(x, fy - 20.0), 16, Color(0.9, 0.5, 0.5))
