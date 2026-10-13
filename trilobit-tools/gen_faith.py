#!/usr/bin/env python3
"""Russian Orthodox churches and Shinto shrines (design doc M12).
  - 8 multi-tile city buildings: church_a..d and shrine_a..d, of 1, 2, 3 and 4 overmap tiles.  The overmap generator (src/overmap.cpp,
    faith_for) places them on the outskirts of cities; churches only in poor (Bratva) districts, shrines anywhere.
  - religious items, furniture, terrain, priests, dialogue, loot groups.
  - church.json-style truce: the C++ (src/trl_aware.cpp, church_truce) keeps the Bratva from fighting in a church.
usage: gen_faith.py <mod dir> -> <mod>/faith.json"""
import json, os, random, sys
MOD = sys.argv[1]
out = []

# ======================================================================= terrain
TER = {  # key: (id, name, desc, symbol, color, copy_from, extra)
    "wall_chapel": ("t_trl_wall_chapel", "whitewashed wall", "A thick whitewashed brick wall.", "#", "white", "t_concrete_wall", {}),
    "wall_cypress": ("t_trl_wall_cypress", "unpainted cypress wall", "A wall of pale, close-fitted cypress boards.", "#", "yellow", "t_concrete_wall", {}),
    "wall_vermilion": ("t_trl_wall_vermilion", "vermilion-lacquered wall", "A wall of dark timber lacquered a deep vermilion.", "#", "red", "t_concrete_wall", {}),
    "window_church": ("t_trl_window_church", "narrow arched window", "A tall, narrow window of leaded glass in pale blue and gold.", "\"", "light_blue", "t_window_no_curtains", {}),
    "floor_church": ("t_trl_floor_church", "worn flagstone floor", "Pale flagstones, worn smooth and hollowed by centuries of feet.", ".", "light_gray", "t_floor", {}),
    "floor_hinoki": ("t_trl_floor_hinoki", "pale hinoki boards", "Fine pale wooden boards, swept and faintly scented.", ".", "yellow", "t_floor", {}),
    "cobble": ("t_trl_cobble", "cobblestones", "Rounded cobbles set in damp earth.", ".", "dark_gray", "t_sidewalk", {}),
    "fence_iron": ("t_trl_fence_iron", "wrought-iron fence", "A tall fence of black wrought-iron bars with gilded finials.", "#", "dark_gray", "t_chainfence", {}),
    "fence_wood": ("t_trl_fence_wood", "low wooden fence", "A low fence of unpainted wooden rails.", "#", "brown", "t_fence", {}),
}
DOORS = {  # key: (closed id, open id, name, open name, desc, colour, base closed, base open)
    "door_church": ("t_trl_door_church_c", "t_trl_door_church_o", "heavy church doors", "open church doors", "Tall double doors of dark oak with iron hinges.", "brown", "t_door_c", "t_door_o"),
    "door_shrine": ("t_trl_door_shrine_c", "t_trl_door_shrine_o", "lattice door", "open lattice door", "A sliding door of wooden lattice and paper.", "yellow", "t_door_c", "t_door_o"),
}
for k, (i, n, d, s, c, base, ex) in TER.items():
    out.append({"type": "terrain", "id": i, "copy-from": base, "name": n, "description": d, "symbol": s, "color": c})
for k, (ci, oi, n, on, d, c, bc, bo) in DOORS.items():
    out.append({"type": "terrain", "id": ci, "copy-from": bc, "name": n, "description": d, "color": c, "open": oi})
    out.append({"type": "terrain", "id": oi, "copy-from": bo, "name": on, "description": d, "color": c, "close": ci})
K = {  # layout key -> terrain id
    "grass": "t_grass", "pave": "t_trl_pave", "gravel": "t_trl_gravel", "road": "t_pavement", "walk": "t_sidewalk", "floor_wood": "t_trl_floor_wood",
    "tree_birch": "t_tree_birch", "tree_pine": "t_tree_pine", "shrub": "t_shrub", "window": "t_trl_window",
}
for k, v in TER.items():
    K[k] = v[0]
for k, v in DOORS.items():
    K[k] = v[0]

# ======================================================================= furniture
FUR = {}   # key -> furniture dict
EOC = []


def fur(key, name, desc, sym, color, light=0, passable=False, eoc=None, flags=None):
    d = {"type": "furniture", "id": f"f_trl_{key}", "name": name, "description": desc, "symbol": sym, "color": color,
         "move_cost_mod": 0 if passable else -1, "coverage": 0 if passable else 40, "required_str": -1,
         "flags": flags or ["TRANSPARENT"], "bash": {"str_min": 8, "str_max": 40, "sound": "smash!", "sound_fail": "whump."}}
    if light:
        d["light_emitted"] = light
    if eoc:
        d["examine_action"] = {"type": "effect_on_condition", "effect_on_conditions": [eoc]}
    FUR[key] = d
    out.append(d)


def eoc(eid, msg, bonus=3, price=0):
    eff = []
    if price:
        eff.append({"u_consume_item": "trl_yen", "count": price})
    eff += [{"u_message": msg, "type": "good"},
            {"u_add_morale": "morale_feeling_good", "bonus": bonus, "max_bonus": bonus * 2, "duration": "3 hours", "decay_start": "40 minutes"}]
    e = {"type": "effect_on_condition", "id": eid, "effect": eff}
    if price:
        e["condition"] = {"math": ["u_item_count('trl_yen') >= %d" % price]}
        e["false_effect"] = [{"u_message": "You do not have the coins to spare.", "type": "info"}]
    EOC.append(e)
    return eid


# --- Orthodox
fur("iconostasis", "iconostasis", "A tall carved and gilded screen of painted icons that divides the nave from the altar: saints and angels in gold and deep red.  Examine it to venerate the icons.",
    "I", "yellow", 6, eoc=eoc("trl_f_icons", "You stand before the icons, cross yourself and bow.  The gold glows in the candlelight, and for a moment the noise of the city is far away."))
fur("candle_stand", "candle stand", "A brass stand filled with sand, with thin beeswax candles burning in it.  Examine it to light a candle.",
    "i", "yellow", 8, eoc=eoc("trl_f_candle", "You light a thin beeswax candle, set it among the others and say a short, quiet prayer.", 2))
fur("altar_table", "altar table", "A square altar table covered in a white cloth, with a gospel book and a cross.", "T", "white", 3, flags=["TRANSPARENT", "FLAT_SURF"])
fur("analoy", "analoy", "A tall wooden lectern with a slanted top, holding an icon of the saint of the day.  Examine it to kiss the icon.",
    "a", "brown", 3, eoc=eoc("trl_f_analoy", "You kiss the icon on the lectern.  The painted face looks back at you, calm and patient.", 2))
fur("church_bell", "church bell", "A bronze bell hung in a timber frame, its rope worn smooth.  Examine it to ring it.",
    "B", "yellow", eoc="trl_f_bell")
out.append({"type": "effect_on_condition", "id": "trl_f_bell", "effect": [
    {"u_message": "You pull the rope.  A deep note rolls out over the roofs.", "type": "info"},
    {"u_make_sound": "A church bell rings out across the district.", "volume": 40, "type": "alarm"}]})
fur("baptismal_font", "baptismal font", "A wide stone font with a gilded cross above it, filled with clear water.", "u", "light_gray", 2, flags=["TRANSPARENT"])
fur("church_bench", "church bench", "A plain wooden bench along the wall for the old and the tired.", "=", "brown", flags=["TRANSPARENT", "MOUNTABLE", "CAN_SIT", "EASY_DECONSTRUCT"])
fur("worship_cross", "stone cross", "A tall stone cross on a stepped base, carved with a small roof and an eight-pointed arm.  Candle stubs sit at its foot.", "+", "light_gray", 2)
# --- Shinto
fur("shinto_torii", "torii gate", "A vermilion gate of two round pillars and two crossbeams, marking the way to a shrine.", "n", "red", passable=True)
fur("hokora", "small shrine", "A small raised wooden shrine with a lacquered door and a thick rope of rice straw above it, set on a stone plinth.  Examine it to bow before it.",
    "A", "light_red", 5, eoc=eoc("trl_f_hokora", "You stop, bow twice, clap twice and bow once more before the little shrine.  A breeze moves the paper streamers.", 3))
fur("komainu", "guardian lion-dog statue", "A weathered stone lion-dog on a plinth, sitting upright with its mouth open or shut to guard the shrine.", "f", "light_gray", 2)
fur("ema_rack", "ema rack", "A wooden frame hung with small wooden prayer plaques, each painted and written on with a wish.  Examine it to read some.",
    "e", "brown", eoc=eoc("trl_f_ema", "You read the plaques, each a small, private wish: a good harvest, an exam, a safe return, a long life.", 2))
fur("saisen_box", "offering box", "A slatted wooden offering box with a rope hanging in front.  Examine it to make an offering of a hundred yen.",
    "O", "brown", eoc=eoc("trl_f_saisen", "You drop a coin in the box, ring the bell, bow twice, clap twice and bow once more.  You feel lighter somehow.", 4, 100))
fur("chozuya", "purification basin", "A stone water basin under a small roof, with a few bamboo ladles laid across it.  Examine it to wash your hands.",
    "u", "light_blue", eoc=eoc("trl_f_chozuya", "You rinse your left hand, then your right, then your mouth.  The cold water clears your head.", 2))
fur("shimenawa_pole", "sacred rope", "Two posts with a thick rope of rice straw and white paper streamers hung between them.", "|", "white", passable=True)
fur("offering_table", "offering table", "A low wooden table with dishes of rice, salt and sake set out for the spirits.", "t", "brown", flags=["TRANSPARENT", "FLAT_SURF"])
fur("charm_counter", "charm counter", "A lacquered counter with rows of small brocade charms, paper talismans and wooden plaques for sale.", "C", "yellow", 4, flags=["TRANSPARENT", "FLAT_SURF"])
fur("hall_lamp", "hanging lamp", "A round paper lamp hung from a bracket, glowing a warm amber.", "o", "yellow", 12, passable=True)
# furniture from earlier generators reused: lantern_stone, bench_park, planter, vase_*, table_low, cushion, samovar, fountain

# ======================================================================= items
ITEM_BASE = {"type": "ITEM", "subtypes": ["GENERIC"], "category": "other", "price_postapoc": "1 USD", "flags": ["TRADER_AVOID"]}


def item(iid, name, desc, weight, volume, price, color="white", sym="?", material=None, **kw):
    d = dict(ITEM_BASE, id=iid, name={"str": name, "str_pl": kw.pop("plural", name + "s")}, description=desc, weight=weight, volume=volume,
             price=f"{price} USD", symbol=sym, color=color, material=material or ["paper"])
    d.update(kw)
    out.append(d)


# --- Shinto
item("trl_omamori", "omamori charm", "A small brocade pouch on a cord, stitched shut, with a prayer inside.  Sold at shrines for luck and safety.  Carrying it is a comfort.",
     "25 g", "30 ml", 800, "red", "o", ["cotton"], plural="omamori charms", use_action={"type": "effect_on_conditions", "menu_text": "Hold it and make a wish", "description": "A moment of quiet.", "effect_on_conditions": ["trl_use_omamori"]})
eoc("trl_use_omamori", "You close your hand around the charm and make a wish.  It helps, a little.")
item("trl_ofuda", "ofuda talisman", "A strip of paper stamped with the name of a shrine's spirit in black and red ink, kept on a household shelf.",
     "5 g", "10 ml", 600, "white", "|", ["paper"], plural="ofuda talismans")
item("trl_ema", "ema prayer plaque", "A small wooden plaque with a painted picture and a handwritten wish on the back.", "40 g", "60 ml", 500, "brown", "e", ["wood"], plural="ema prayer plaques")
item("trl_omikuji", "omikuji fortune slip", "A narrow strip of paper from a shrine, with a fortune on it.  Use it to read.",
     "2 g", "2 ml", 100, "white", "|", ["paper"], plural="omikuji fortune slips",
     use_action={"type": "effect_on_conditions", "menu_text": "Read the fortune", "description": "Read your fortune.", "effect_on_conditions": ["trl_use_omikuji"]})
out.append({"type": "effect_on_condition", "id": "trl_use_omikuji", "effect": [
    {"u_message": "You unfold the slip and read.  Great blessing: patience will bring what haste cannot.", "type": "good"}]})
item("trl_gohei", "gohei wand", "A short wooden wand with two zigzag paper streamers, waved by a shrine priest to purify.  It is a flimsy club.",
     "250 g", "500 ml", 1200, "white", "/", ["wood", "paper"], plural="gohei wands", melee_damage={"bash": 3})
item("trl_kannushi_robe", "shrine priest robe", "A white ceremonial robe and pale hakama trousers, as worn by a shrine priest.", "900 g", "5 L", 9000, "white", "[", ["cotton"],
     plural="shrine priest robes", **{"copy-from": "robe", "subtypes": ["ARMOR"], "type": "ITEM"})
# --- Orthodox
item("trl_icon", "icon", "A small hand-painted icon on a wooden panel: a saint's face in gold leaf, dark paint and a deep red border.  Examine one in your hand to venerate it.",
     "300 g", "400 ml", 4500, "yellow", "I", ["wood"], plural="icons",
     use_action={"type": "effect_on_conditions", "menu_text": "Venerate", "description": "A quiet moment before the icon.", "effect_on_conditions": ["trl_use_icon"]})
eoc("trl_use_icon", "You hold the icon and look into the painted face.  A quiet, steady calm settles over you.")
item("trl_chotki", "prayer rope", "A loop of black wool knots with a small cross, used to count prayers.", "30 g", "40 ml", 700, "dark_gray", "o", ["wool"], plural="prayer ropes")
item("trl_censer", "censer", "A brass censer on three short chains with little bells, used to carry fragrant smoke before the icons.", "400 g", "700 ml", 3800, "yellow", "c", ["brass"], plural="censers")
item("trl_church_candle", "beeswax candle", "A thin, tall beeswax candle, bought at the church door.", "30 g", "60 ml", 150, "yellow", "i", ["wood"], plural="beeswax candles")
item("trl_gospel", "gospel book", "A heavy gospel book with a silver-gilt cover and ribbon markers, set in Church Slavonic and Russian.", "1500 g", "1500 ml", 9000, "yellow", "B", ["paper"], plural="gospel books")
# edibles: prosphora bread and holy water
out.append({"type": "ITEM", "subtypes": ["COMESTIBLE"], "id": "trl_prosphora", "copy-from": "bread", "name": {"str": "prosphora loaf", "str_pl": "prosphora loaves"},
            "description": "A small round loaf of leavened bread stamped with a cross, baked for the liturgy and given out afterwards.  Soft, plain and filling.",
            "price": "300 USD", "flags": ["TRADER_AVOID"], "color": "white"})
out.append({"type": "ITEM", "subtypes": ["COMESTIBLE"], "id": "trl_holy_water", "copy-from": "water_clean", "name": {"str": "blessed water"},
            "description": "Clean water blessed by a priest and given out in plain bottles.  It tastes of nothing, but you feel a little steadier after drinking it.",
            "price": "300 USD", "flags": ["TRADER_AVOID"]})

# ======================================================================= item groups
out.append({"type": "item_group", "id": "trl_loot_shinto", "subtype": "distribution", "entries": [
    {"item": "trl_omamori", "prob": 30}, {"item": "trl_ofuda", "prob": 25}, {"item": "trl_ema", "prob": 25}, {"item": "trl_omikuji", "prob": 30},
    {"item": "trl_gohei", "prob": 6}, {"item": "trl_kannushi_robe", "prob": 6}, {"item": "sake_filtered", "prob": 14}, {"item": "rice_cooked", "prob": 10}]})
out.append({"type": "item_group", "id": "trl_loot_orthodox", "subtype": "distribution", "entries": [
    {"item": "trl_church_candle", "prob": 40}, {"item": "trl_chotki", "prob": 18}, {"item": "trl_icon", "prob": 12}, {"item": "trl_censer", "prob": 6},
    {"item": "trl_gospel", "prob": 6}, {"item": "trl_prosphora", "prob": 22}, {"item": "trl_holy_water", "prob": 18}, {"item": "holybook_orthodox", "prob": 5},
    {"item": "holybook_bible2", "prob": 7}, {"item": "cassock", "prob": 5}]})
out.append({"type": "item_group", "id": "trl_worn_priest_orth", "subtype": "collection", "entries": [{"item": "cassock"}, {"item": "hat_cotton"}, {"item": "boots_dress" if False else "dress_shoes"}]})
out.append({"type": "item_group", "id": "trl_worn_priest_shinto", "subtype": "collection", "entries": [{"item": "trl_kannushi_robe"}, {"item": "dress_shoes"}]})
out.append({"type": "item_group", "id": "trl_carry_priest", "subtype": "collection", "entries": [{"item": "wallet"}]})
out.append({"type": "item_group", "id": "trl_weapon_priest", "subtype": "distribution", "entries": [{"item": "trl_gohei", "prob": 1}]})
out.append({"type": "item_group", "id": "trl_weapon_priest_orth", "subtype": "distribution", "entries": [{"item": "trl_censer", "prob": 1}]})

# ======================================================================= priests and dialogue
for who, title, worn, weapon, chat in (("orth", "Orthodox priest", "trl_worn_priest_orth", "trl_weapon_priest_orth", "TRL_PRIEST_ORTH"),
                                       ("shinto", "Shinto priest", "trl_worn_priest_shinto", "trl_weapon_priest", "TRL_PRIEST_SHINTO")):
    out.append({"type": "npc_class", "id": f"trl_nc_priest_{who}", "name": {"str": title}, "job_description": f"I keep this {'church' if who == 'orth' else 'shrine'}.",
                "common": False, "worn_override": worn, "carry_override": "trl_carry_priest", "weapon_override": weapon,
                "traits": [{"trait": "trl_resident"}], "skills": [{"skill": "ALL", "level": {"constant": 1}}]})
    out.append({"type": "npc", "id": f"trl_nc_priest_{who}", "class": f"trl_nc_priest_{who}", "attitude": 0, "mission": 7, "chat": chat, "faction": "no_faction",
                "temp_suffix": title})
BACK = {"text": "Thank you.", "topic": "TALK_DONE"}
out.append({"type": "talk_topic", "id": "TRL_PRIEST_ORTH",
            "dynamic_line": "Peace to you.  Come in, come in: the doors are open to everyone, whoever you are and whoever you work for.  Fighting is left at the door here.",
            "responses": [
                {"text": "Could I light a candle?", "topic": "TRL_PRIEST_ORTH_CANDLE", "effect": {"u_add_morale": "morale_feeling_good", "bonus": 3, "max_bonus": 6, "duration": "3 hours", "decay_start": "40 minutes"}},
                {"text": "Tell me about this church.", "topic": "TRL_PRIEST_ORTH_ABOUT"},
                {"text": "Is it really safe here, with the syndicate about?", "topic": "TRL_PRIEST_ORTH_SAFE"},
                BACK]})
out.append({"type": "talk_topic", "id": "TRL_PRIEST_ORTH_CANDLE", "dynamic_line": "Of course.  Take one from the box and set it in the sand, and say whatever you need to say.  God hears the short prayers as well as the long.",
            "responses": [{"text": "Thank you.", "topic": "TRL_PRIEST_ORTH"}]})
out.append({"type": "talk_topic", "id": "TRL_PRIEST_ORTH_ABOUT", "dynamic_line": "Our parish is old, and poor, and stubborn.  The icons came from the old country with the first families.  The bell still rings, the candles still burn, and on a feast day the whole street comes.",
            "responses": [{"text": "I see.", "topic": "TRL_PRIEST_ORTH"}]})
out.append({"type": "talk_topic", "id": "TRL_PRIEST_ORTH_SAFE", "dynamic_line": "Inside these walls, yes.  The men from the syndicate bring their mothers here, and they keep the peace, as long as no one breaks it.  If someone does break it, I would not like to be standing in the way.",
            "responses": [{"text": "I understand.", "topic": "TRL_PRIEST_ORTH"}]})
out.append({"type": "talk_topic", "id": "TRL_PRIEST_SHINTO",
            "dynamic_line": "Welcome.  Please wash your hands at the basin, bow at the gate, and walk at the edge of the path, for the middle belongs to the spirits.",
            "responses": [
                {"text": "How do I pray here?", "topic": "TRL_PRIEST_SHINTO_HOW"},
                {"text": "Tell me about this shrine.", "topic": "TRL_PRIEST_SHINTO_ABOUT"},
                {"text": "Any charms for sale?", "topic": "TRL_PRIEST_SHINTO_CHARM"},
                BACK]})
out.append({"type": "talk_topic", "id": "TRL_PRIEST_SHINTO_HOW", "dynamic_line": "Bow twice, clap twice, and bow once more.  Say what you wish for, and leave a coin in the box.  It is the manner, not the amount, that matters.",
            "responses": [{"text": "I see.", "topic": "TRL_PRIEST_SHINTO"}]})
out.append({"type": "talk_topic", "id": "TRL_PRIEST_SHINTO_ABOUT", "dynamic_line": "A shrine has stood on this ground longer than the towers.  People come to ask for a safe road, a healthy child, a good exam.  Few of them stay, but most of them return.",
            "responses": [{"text": "I see.", "topic": "TRL_PRIEST_SHINTO"}]})
out.append({"type": "talk_topic", "id": "TRL_PRIEST_SHINTO_CHARM", "dynamic_line": "There are charms and fortune slips at the counter, left out for anyone who needs them.  Please take what you need, and leave a coin if you can.",
            "responses": [{"text": "Thank you.", "topic": "TRL_PRIEST_SHINTO"}]})
out += [e for e in EOC if isinstance(e, dict)]


# ======================================================================= layout canvas
class C:
    def __init__(self, tw, th):
        self.w, self.h = tw * 24, th * 24
        self.t = [["grass"] * self.w for _ in range(self.h)]
        self.f = []        # (key, x, y)
        self.npcs = []     # (class, x, y)
        self.nested = []   # (chunk id, chance, x, y)
        self.occ = set()
        self.items = []    # (group, x0, y0, x1, y1, chance, repeat)

    def fill(self, x0, y0, x1, y1, k):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.t[y][x] = k

    def box(self, x0, y0, x1, y1, wall, floor):
        self.fill(x0, y0, x1, y1, wall)
        self.fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, floor)

    def put(self, k, x, y):
        self.t[y][x] = k

    def fence(self, x0, y0, x1, y1, k, gaps=()):
        for x in range(x0, x1 + 1):
            for y in (y0, y1):
                if (x, y) not in gaps:
                    self.t[y][x] = k
        for y in range(y0, y1 + 1):
            for x in (x0, x1):
                if (x, y) not in gaps:
                    self.t[y][x] = k

    def path(self, x0, y0, x1, y1, k):
        self.fill(x0, y0, x1, y1, k)

    def is_floor(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.t[y][x] in ("floor_church", "floor_hinoki", "floor_wood", "pave", "cobble", "gravel", "grass") and (x, y) not in self.occ

    def F(self, key, x, y):
        if self.is_floor(x, y):
            self.f.append((key, x, y))
            self.occ.add((x, y))
            return True
        return False

    def row(self, key, x0, x1, y):
        for x in range(x0, x1 + 1):
            self.F(key, x, y)

    def col(self, key, x, y0, y1):
        for y in range(y0, y1 + 1):
            self.F(key, x, y)

    def npc(self, cls, x, y):
        self.npcs.append((cls, x, y))
        self.occ.add((x, y))

    def trees(self, kind, pts):
        for x, y in pts:
            if 0 <= x < self.w and 0 <= y < self.h and self.t[y][x] == "grass":
                self.t[y][x] = kind

    def loot(self, group, x0, y0, x1, y1, chance=50, repeat=2):
        self.items.append((group, x0, y0, x1, y1, chance, repeat))


def gate_path(c, x0, x1, y_from, y_to, k="pave"):
    c.path(x0, y_from, x1, y_to, k)


# ------------------------------------------------------------------ churches
def church_nave(c, x0, y0, x1, y1, door_x, icons=True, apse=True):
    """a nave box with a door at the south, windows, an iconostasis near the north end and an altar behind it"""
    c.box(x0, y0, x1, y1, "wall_chapel", "floor_church")
    c.put("door_church", door_x, y1)
    c.put("door_church", door_x + 1, y1)
    for x in range(x0 + 3, x1 - 2, 4):
        if x not in (door_x - 1, door_x, door_x + 1, door_x + 2):
            c.put("window_church", x, y1)
    for y in range(y0 + 3, y1 - 1, 3):
        c.put("window_church", x0, y)
        c.put("window_church", x1, y)
    iy = y0 + 3
    if icons:
        for x in range(x0 + 2, x1 - 1):
            c.F("iconostasis", x, iy)
        # a gap in the screen (royal doors) in the middle
        mid = (x0 + x1) // 2
        c.f = [e for e in c.f if not (e[0] == "iconostasis" and e[1] == mid and e[2] == iy)]
        c.occ.discard((mid, iy))
        c.F("altar_table", mid, iy - 1)
    # candle stands, lectern and wall benches
    c.F("candle_stand", x0 + 2, y1 - 3)
    c.F("candle_stand", x1 - 2, y1 - 3)
    c.F("analoy", (x0 + x1) // 2 - 3, iy + 3)
    for y in range(iy + 3, y1 - 1, 3):
        c.F("church_bench", x0 + 1, y)
        c.F("church_bench", x1 - 1, y)


def church_yard(c, x0, y0, x1, y1, gap_x, gaps=()):
    c.fence(x0, y0, x1, y1, "fence_iron", gaps={(gap_x, y1), (gap_x + 1, y1)} | set(gaps))
    c.path(gap_x, y1 - 6, gap_x + 1, y1, "pave")


def churches():
    res = {}
    # ---- A: 1 tile chapel
    c = C(1, 1)
    church_yard(c, 1, 1, 22, 22, 11)
    c.fill(2, 2, 21, 21, "grass")
    church_yard(c, 1, 1, 22, 22, 11)
    church_nave(c, 6, 5, 17, 15, 11)
    c.path(11, 16, 12, 21, "pave")
    c.trees("tree_birch", [(3, 3), (20, 3), (3, 20), (20, 20), (4, 12), (19, 12)])
    c.F("church_bell", 4, 17); c.F("worship_cross", 15, 18); c.F("church_bench", 18, 19); c.F("church_bench", 5, 19)
    c.npc("trl_nc_priest_orth", 11, 8)
    c.nested += [("trl_pres_bratva_thug", 40, 8, 12), ("trl_pres_bratva_enforcer", 20, 14, 11), ("trl_pres_bratva_thug", 25, 10, 13)]
    c.loot("trl_loot_orthodox", 8, 6, 15, 14, 45, 3)
    res["a"] = c
    # ---- B: 2x1 parish church with bell tower
    c = C(2, 1)
    church_yard(c, 1, 1, 46, 22, 23)
    c.fill(2, 2, 45, 21, "grass")
    church_yard(c, 1, 1, 46, 22, 23)
    church_nave(c, 11, 4, 34, 16, 22)
    c.path(23, 17, 24, 21, "pave")
    # bell tower with a door and open arches
    c.box(38, 5, 43, 11, "wall_chapel", "floor_church")
    c.put("door_church", 40, 11)
    c.put("window_church", 38, 8); c.put("window_church", 43, 8)
    c.F("church_bell", 40, 7)
    c.path(40, 12, 41, 21, "pave")
    c.trees("tree_birch", [(3, 3), (3, 20), (8, 12), (36, 20), (44, 3), (44, 20), (5, 8), (6, 18)])
    c.F("worship_cross", 7, 17); c.F("church_bench", 27, 19); c.F("church_bench", 17, 19)
    c.npc("trl_nc_priest_orth", 22, 7)
    c.nested += [("trl_pres_bratva_thug", 45, 18, 9), ("trl_pres_bratva_thug", 30, 26, 12), ("trl_pres_bratva_enforcer", 25, 20, 13), ("trl_pres_bratva_enforcer", 15, 28, 9)]
    c.loot("trl_loot_orthodox", 12, 5, 33, 15, 40, 4)
    res["b"] = c
    # ---- C: 3x1 church, bell tower and parish hall
    c = C(3, 1)
    church_yard(c, 1, 1, 70, 22, 35)
    c.fill(2, 2, 69, 21, "grass")
    church_yard(c, 1, 1, 70, 22, 35)
    church_nave(c, 22, 3, 49, 16, 35)
    c.path(35, 17, 36, 21, "pave")
    c.box(7, 4, 14, 12, "wall_chapel", "floor_church")
    c.put("door_church", 10, 12); c.put("window_church", 7, 8); c.put("window_church", 14, 8)
    c.F("church_bell", 10, 7); c.path(10, 13, 11, 21, "pave")
    # parish hall with long tables, a samovar and a stove corner
    c.box(54, 4, 66, 16, "wall_chapel", "floor_wood")
    c.put("door_church", 59, 16); c.put("window", 54, 8); c.put("window", 66, 8); c.put("window", 60, 4)
    for x in (57, 60, 63):
        c.F("table_low", x, 9); c.F("cushion", x, 8); c.F("cushion", x, 10)
        c.F("table_low", x, 12); c.F("cushion", x, 11); c.F("cushion", x, 13)
    c.F("samovar", 56, 6); c.F("reception", 64, 6)
    c.path(59, 17, 60, 21, "pave")
    c.trees("tree_birch", [(3, 3), (3, 20), (17, 18), (51, 18), (69, 3), (69, 20), (18, 8), (4, 12)])
    c.F("worship_cross", 29, 19); c.F("church_bench", 40, 19); c.F("church_bench", 31, 19)
    c.npc("trl_nc_priest_orth", 35, 7)
    c.nested += [("trl_pres_bratva_thug", 45, 28, 10), ("trl_pres_bratva_thug", 35, 40, 12), ("trl_pres_bratva_enforcer", 25, 33, 13),
                 ("trl_pres_bratva_thug", 40, 58, 10), ("trl_pres_bratva_enforcer", 20, 61, 12)]
    c.loot("trl_loot_orthodox", 23, 4, 48, 15, 40, 4); c.loot("trl_loot_food", 55, 5, 65, 15, 30, 2)
    res["c"] = c
    # ---- D: 2x2 cathedral with transept and bell tower
    c = C(2, 2)
    church_yard(c, 1, 1, 46, 46, 23)
    c.fill(2, 2, 45, 45, "grass")
    church_yard(c, 1, 1, 46, 46, 23)
    church_nave(c, 12, 4, 35, 30, 23)
    # transept wings north and south of the middle
    c.box(6, 14, 41, 24, "wall_chapel", "floor_church")
    c.fill(13, 15, 34, 23, "floor_church")
    c.fill(12, 14, 12, 15, "wall_chapel"); c.fill(35, 14, 35, 15, "wall_chapel")
    c.F("candle_stand", 8, 19); c.F("candle_stand", 39, 19)
    c.F("analoy", 8, 16); c.F("baptismal_font", 39, 22)
    c.path(23, 31, 24, 45, "pave")
    # bell tower at the south-east corner of the yard
    c.box(38, 33, 44, 39, "wall_chapel", "floor_church")
    c.put("door_church", 41, 39); c.put("window_church", 38, 36); c.put("window_church", 44, 36)
    c.F("church_bell", 41, 35); c.path(41, 40, 42, 45, "pave")
    c.trees("tree_birch", [(3, 3), (3, 44), (44, 3), (8, 34), (8, 40), (14, 38), (32, 38), (3, 20), (44, 12), (44, 25), (6, 6)])
    c.F("worship_cross", 18, 34); c.F("church_bench", 18, 42); c.F("church_bench", 30, 42); c.F("church_bench", 27, 34)
    c.npc("trl_nc_priest_orth", 23, 7)
    c.nested += [("trl_pres_bratva_thug", 45, 18, 10), ("trl_pres_bratva_thug", 35, 28, 12), ("trl_pres_bratva_enforcer", 30, 20, 18), ("trl_pres_bratva_enforcer", 25, 30, 20),
                 ("trl_pres_bratva_thug", 40, 20, 26), ("trl_pres_bratva_thug", 35, 34, 14)]
    c.loot("trl_loot_orthodox", 13, 5, 34, 29, 40, 6)
    res["d"] = c
    return res


# ------------------------------------------------------------------ shrines
def shrine_court(c, x0, y0, x1, y1, gate_x, torii=True):
    c.fence(x0, y0, x1, y1, "fence_wood", gaps={(gate_x, y1), (gate_x + 1, y1)})
    c.fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, "gravel")
    if torii:
        c.F("shinto_torii", gate_x, y1 - 1)
        c.F("shinto_torii", gate_x + 1, y1 - 1)


def lantern_line(c, xs, y0, y1, step=3):
    for y in range(y0, y1, step):
        c.F("lantern_stone", xs[0], y)
        c.F("lantern_stone", xs[1], y)


def shrines():
    res = {}
    # ---- A: 1 tile neighbourhood shrine
    c = C(1, 1)
    shrine_court(c, 1, 1, 22, 22, 11)
    c.path(11, 7, 12, 22, "pave")
    c.F("hokora", 11, 5); c.F("hokora", 12, 5)
    c.F("komainu", 9, 12); c.F("komainu", 14, 12)
    lantern_line(c, (9, 14), 8, 21)
    c.F("saisen_box", 11, 8); c.F("saisen_box", 12, 8)
    c.F("shimenawa_pole", 10, 4); c.F("shimenawa_pole", 13, 4)
    c.F("chozuya", 5, 15); c.F("ema_rack", 18, 11); c.F("ema_rack", 18, 14); c.F("offering_table", 15, 8)
    c.trees("tree_pine", [(3, 3), (20, 3), (3, 20), (20, 20), (5, 9), (18, 6)])
    c.npc("trl_nc_priest_shinto", 13, 14)
    c.loot("trl_loot_shinto", 8, 6, 15, 13, 40, 3)
    res["a"] = c
    # ---- B: 2x1 shrine with haiden hall
    c = C(2, 1)
    shrine_court(c, 1, 1, 46, 22, 23)
    c.path(23, 14, 24, 22, "pave")
    c.box(15, 4, 32, 13, "wall_vermilion", "floor_hinoki")
    c.put("door_shrine", 23, 13); c.put("door_shrine", 24, 13)
    for x in (18, 28):
        c.put("door_shrine", x, 13)
    c.F("hokora", 23, 5); c.F("hokora", 24, 5)
    c.F("saisen_box", 23, 9); c.F("saisen_box", 24, 9)
    c.F("offering_table", 20, 6); c.F("offering_table", 27, 6); c.F("hall_lamp", 17, 5); c.F("hall_lamp", 30, 5)
    c.F("cushion", 19, 11); c.F("cushion", 28, 11)
    lantern_line(c, (20, 27), 14, 21)
    c.F("komainu", 21, 15); c.F("komainu", 26, 15)
    c.F("chozuya", 8, 14); c.F("chozuya", 39, 14); c.F("ema_rack", 8, 8); c.F("ema_rack", 39, 8)
    c.F("shimenawa_pole", 21, 3); c.F("shimenawa_pole", 26, 3)
    c.trees("tree_pine", [(3, 3), (44, 3), (3, 20), (44, 20), (10, 18), (36, 18), (12, 5), (35, 5)])
    c.npc("trl_nc_priest_shinto", 24, 11)
    c.loot("trl_loot_shinto", 16, 5, 31, 12, 40, 4)
    res["b"] = c
    # ---- C: 3x1 shrine: central hall, charm office, dance stage
    c = C(3, 1)
    shrine_court(c, 1, 1, 70, 22, 35)
    c.path(35, 14, 36, 22, "pave")
    c.box(26, 4, 45, 13, "wall_vermilion", "floor_hinoki")
    c.put("door_shrine", 35, 13); c.put("door_shrine", 36, 13)
    c.F("hokora", 35, 5); c.F("hokora", 36, 5)
    c.F("saisen_box", 35, 9); c.F("saisen_box", 36, 9)
    c.F("offering_table", 30, 6); c.F("offering_table", 41, 6); c.F("hall_lamp", 28, 5); c.F("hall_lamp", 43, 5)
    # charm office on the east
    c.box(52, 5, 66, 13, "wall_cypress", "floor_hinoki")
    c.put("door_shrine", 58, 13); c.put("door_shrine", 59, 13); c.put("window", 52, 9)
    c.F("charm_counter", 56, 8); c.F("charm_counter", 57, 8); c.F("charm_counter", 58, 8); c.F("charm_counter", 59, 8)
    c.F("shelf_clean", 54, 6); c.F("shelf_clean", 64, 6); c.F("hall_lamp", 62, 6)
    # open dance stage on the west
    c.fill(7, 5, 20, 12, "floor_hinoki"); c.fill(6, 4, 21, 4, "wall_vermilion"); c.fill(6, 13, 21, 13, "fence_wood"); c.fill(6, 4, 6, 13, "fence_wood"); c.fill(21, 4, 21, 13, "fence_wood")
    c.put("gravel", 13, 13); c.put("gravel", 14, 13)
    c.F("hall_lamp", 9, 6); c.F("hall_lamp", 18, 6)
    lantern_line(c, (31, 40), 14, 21)
    c.F("komainu", 32, 16); c.F("komainu", 39, 16)
    c.F("shinto_torii", 35, 18); c.F("shinto_torii", 36, 18)
    c.F("chozuya", 28, 17); c.F("ema_rack", 44, 17); c.F("ema_rack", 46, 17)
    c.F("shimenawa_pole", 33, 3); c.F("shimenawa_pole", 38, 3)
    c.trees("tree_pine", [(3, 3), (68, 3), (3, 20), (68, 20), (12, 16), (60, 17), (23, 8), (50, 16)])
    c.npc("trl_nc_priest_shinto", 36, 11); c.npc("trl_nc_priest_shinto", 58, 10)
    c.loot("trl_loot_shinto", 27, 5, 44, 12, 40, 4); c.loot("trl_loot_shinto", 53, 6, 65, 12, 60, 4)
    res["c"] = c
    # ---- D: 2x2 great shrine: two gates, courtyard, haiden, honden, shamusho
    c = C(2, 2)
    shrine_court(c, 1, 1, 46, 46, 23)
    c.path(23, 25, 24, 46, "pave")
    # inner wall with the second gate
    c.fence(8, 24, 39, 24, "fence_wood", gaps={(23, 24), (24, 24)})
    c.F("shinto_torii", 23, 25); c.F("shinto_torii", 24, 25)
    c.F("shinto_torii", 23, 40); c.F("shinto_torii", 24, 40)
    lantern_line(c, (20, 27), 26, 44)
    c.F("komainu", 21, 28); c.F("komainu", 26, 28)
    c.F("chozuya", 12, 30); c.F("chozuya", 36, 30)
    c.F("ema_rack", 12, 36); c.F("ema_rack", 36, 36); c.F("ema_rack", 14, 36); c.F("ema_rack", 34, 36)
    # haiden (worship hall) and honden (inner sanctuary) behind it
    c.box(14, 13, 33, 22, "wall_vermilion", "floor_hinoki")
    c.put("door_shrine", 23, 22); c.put("door_shrine", 24, 22)
    c.F("saisen_box", 23, 18); c.F("saisen_box", 24, 18); c.F("offering_table", 18, 16); c.F("offering_table", 29, 16)
    c.F("hall_lamp", 16, 15); c.F("hall_lamp", 31, 15); c.F("cushion", 19, 20); c.F("cushion", 28, 20)
    c.box(19, 4, 28, 10, "wall_cypress", "floor_hinoki")
    c.put("door_shrine", 23, 10); c.put("door_shrine", 24, 10)
    c.F("hokora", 23, 6); c.F("hokora", 24, 6); c.F("offering_table", 21, 8); c.F("offering_table", 26, 8)
    c.path(23, 11, 24, 12, "pave")
    # shamusho (office) with the charm counter
    c.box(38, 28, 45, 36, "wall_cypress", "floor_hinoki")
    c.put("door_shrine", 38, 32); c.put("window", 45, 31)
    c.F("charm_counter", 41, 31); c.F("charm_counter", 42, 31); c.F("charm_counter", 43, 31); c.F("shelf_clean", 40, 29); c.F("shelf_clean", 43, 29)
    c.F("shimenawa_pole", 21, 12); c.F("shimenawa_pole", 26, 12)
    c.trees("tree_pine", [(3, 3), (44, 3), (3, 44), (44, 44), (6, 12), (42, 12), (8, 20), (40, 20), (10, 42), (36, 42), (4, 28), (44, 20)])
    c.npc("trl_nc_priest_shinto", 24, 20); c.npc("trl_nc_priest_shinto", 41, 33); c.npc("trl_nc_priest_shinto", 24, 8)
    c.loot("trl_loot_shinto", 15, 14, 32, 21, 40, 4); c.loot("trl_loot_shinto", 39, 29, 44, 35, 60, 4); c.loot("trl_loot_shinto", 20, 5, 27, 9, 40, 3)
    res["d"] = c
    return res


# ======================================================================= emit mapgens, overmap terrain, city buildings
pool = [ch for ch in "0123456789@#$%^&*()-=+[]{}|;<>?/~`abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"]
CH = {}


def ch(key):
    if key not in CH:
        CH[key] = pool[len(CH)]
    return CH[key]


def emit(prefix, name, sym, color, variants):
    for v, c in variants.items():
        tw, th = c.w // 24, c.h // 24
        sid = f"{prefix}_{v}"
        ovs = []
        for ty in range(th):
            for tx in range(tw):
                tid = f"{sid}_{tx}_{ty}"
                out.append({"type": "overmap_terrain", "id": tid, "name": name, "sym": sym, "color": color, "see_cost": "full_high",
                            "vision_levels": "large_city_building", "flags": []})
                ovs.append({"point": [tx, ty, 0], "overmap": tid + "_north"})
                x0, y0 = tx * 24, ty * 24
                rows = ["".join(ch(c.t[y0 + y][x0 + x]) for x in range(24)) for y in range(24)]
                terr = {ch(k): K[k] for k in {c.t[y0 + y][x0 + x] for y in range(24) for x in range(24)}}
                obj = {"fill_ter": "t_grass", "rows": rows, "terrain": terr, "place_furniture": [], "place_items": [], "place_nested": [], "place_npcs": []}
                for key, fx, fy in c.f:
                    if x0 <= fx < x0 + 24 and y0 <= fy < y0 + 24:
                        obj["place_furniture"].append({"furn": FUR[key]["id"] if key in FUR else "f_trl_" + key, "x": fx - x0, "y": fy - y0})
                for cls, nx, ny in c.npcs:
                    if x0 <= nx < x0 + 24 and y0 <= ny < y0 + 24:
                        obj["place_npcs"].append({"class": cls, "x": nx - x0, "y": ny - y0})
                for cid, chance, nx, ny in c.nested:
                    if x0 <= nx < x0 + 24 and y0 <= ny < y0 + 24 and (nx, ny) not in c.occ:
                        obj["place_nested"].append({"chunks": [[cid, chance], ["null", 100 - chance]], "x": nx - x0, "y": ny - y0})
                for grp, ax0, ay0, ax1, ay1, chance, rep in c.items:
                    ix0, ix1 = max(ax0, x0), min(ax1, x0 + 23)
                    iy0, iy1 = max(ay0, y0), min(ay1, y0 + 23)
                    if ix0 <= ix1 and iy0 <= iy1:
                        obj["place_items"].append({"item": grp, "x": [ix0 - x0, ix1 - x0], "y": [iy0 - y0, iy1 - y0], "chance": chance, "repeat": rep})
                for k in ("place_nested", "place_npcs", "place_items", "place_furniture"):
                    if not obj[k]:
                        del obj[k]
                out.append({"type": "mapgen", "om_terrain": [tid], "object": obj})
        out.append({"type": "city_building", "id": sid, "locations": ["land"], "overmaps": ovs, "city_sizes": [1, -1]})


emit("trl_church", "Orthodox church", "+", "yellow", churches())
emit("trl_shrine", "Shinto shrine", "^", "light_red", shrines())
json.dump(out, open(os.path.join(MOD, "faith.json"), "w"), indent=1)
print("faith: items", sum(1 for o in out if o.get("type") == "ITEM"), "furniture", len(FUR), "mapgens", sum(1 for o in out if o.get("type") == "mapgen"))
