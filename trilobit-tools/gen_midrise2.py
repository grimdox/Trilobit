#!/usr/bin/env python3
"""Generate 30 function-specific Trilobit mid-rises (government, business, personal, slum, criminal).
Run AFTER gen_midrise.py.  usage: gen_midrise2.py <mod dir>"""
import json, os, random, sys
MOD = sys.argv[1]
sys.argv = [sys.argv[0], MOD]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_midrise as mr
from gen_midrise import gp, T, F, FLOORS, WALLS, nfur, NEW_F, NEW_T
from gen_places import SOLID, SURF
OLD_F, OLD_T = set(NEW_F), set(NEW_T)

# ------------------------------------------------------------------ furniture for the new functions
def f2(*a, **k): nfur(*a, **k)
f2("hospital_bed", "hospital bed", "A rail-sided bed with a thin mattress and a clipboard.", "B", "light_cyan", flags=SOLID, comfort=2)
f2("iv_stand", "drip stand", "A tall stand hung with an empty fluid bag.", "i", "white", flags=SOLID, passable=True)
f2("exam_couch", "exam couch", "A padded examination couch covered in paper sheet.", "E", "light_gray", flags=SURF)
f2("med_cabinet", "medicine cabinet", "A locked glass cabinet of boxes and vials.", "H", "white", flags=SOLID + ["FLAT_SURF"])
f2("surgical_table", "surgical table", "A steel table under a ring of hard white lamps.", "S", "light_cyan", 12, flags=SURF)
f2("scanner", "diagnostic scanner", "A humming arch scanner with a blue status panel.", "C", "light_blue", 9, flags=SOLID)
f2("judge_bench", "judge's bench", "A tall dark bench with a nameplate.", "J", "brown", flags=SOLID)
f2("witness_box", "witness box", "A small enclosed stand with a worn rail.", "w", "brown", flags=SOLID)
f2("cell_bars", "cell bars", "Floor-to-ceiling steel bars.", "#", "dark_gray", flags=["TRANSPARENT"])
f2("evidence_shelf", "evidence shelf", "A steel shelf of bagged and numbered items.", "H", "light_gray", flags=SOLID + ["FLAT_SURF"])
f2("gun_locker", "armoury locker", "A grey locker with a heavy lock.", "L", "dark_gray", flags=SOLID)
f2("safe_big", "heavy safe", "A floor-bolted safe the size of a wardrobe.", "Z", "light_gray", flags=SOLID)
f2("teller_desk", "teller desk", "A counter with a glass screen and a cash drawer.", "T", "light_gray", flags=SURF)
f2("vault_stack", "deposit boxes", "Walls of numbered steel deposit boxes.", "V", "light_gray", flags=SOLID)
f2("queue_post", "queue post", "A stanchion with a retractable tape.", "|", "light_red", flags=SOLID, passable=True)
f2("checkout", "checkout lane", "A belt, scanner and card reader.", "C", "light_gray", flags=SURF)
f2("produce_bin", "produce bin", "A tilted bin of vegetables.", "p", "light_green", flags=SOLID + ["FLAT_SURF"])
f2("freezer_case", "freezer case", "A glass-fronted freezer, faintly lit.", "F", "light_blue", 6, flags=SOLID)
f2("fire_pole", "fire pole", "A brass pole polished by hands.", "|", "yellow", flags=SOLID, passable=True)
f2("hose_rack", "hose rack", "A drum of fire hose on a red rack.", "h", "light_red", flags=SOLID)
f2("school_desk", "school desk", "A small desk with a flip-up lid.", "d", "brown", flags=SURF)
f2("blackboard", "classroom board", "A wall board half-wiped.", "=", "dark_gray", flags=SOLID, passable=True)
f2("library_shelf", "library shelf", "A tall shelf of faded spines.", "H", "brown", flags=SOLID + ["FLAT_SURF"])
f2("hotel_bed", "hotel bed", "A made double bed with a neat fold at the corner.", "b", "white", flags=SOLID, comfort=3)
f2("minibar", "minibar", "A little fridge of overpriced bottles.", "m", "light_gray", flags=SOLID + ["FLAT_SURF"])
f2("gym_bench", "gym bench", "A padded bench with a loaded bar.", "g", "light_gray", flags=SOLID)
f2("press_machine", "printing press", "A big inked press with a stack of fresh sheets.", "P", "dark_gray", flags=SOLID)
f2("paper_stack", "paper stack", "A knee-high stack of printed sheets.", "=", "white", flags=SOLID + ["FLAT_SURF"])
f2("washer_row", "industrial washer", "A bank of drum washers.", "W", "light_blue", flags=SOLID)
f2("implant_chair", "implant chair", "A reclining chair with clamps, arms and a lamp.", "I", "light_cyan", 7, flags=SOLID)
f2("dice_table", "gaming table", "A felted table with a cracked-bone dice cup.", "D", "green", flags=SURF)
f2("ledger_desk", "ledger desk", "A scarred desk and a thick book of debts.", "L", "brown", flags=SURF)
f2("chop_lift", "vehicle lift", "A hydraulic lift with cut sections of a stolen bike.", "Y", "dark_gray", flags=SOLID)
f2("parts_bin", "parts bin", "A bin of mixed salvage and unmarked parts.", "O", "brown", flags=SOLID + ["FLAT_SURF"])
f2("stall_awning", "stall awning", "A patched awning over a plank counter.", "^", "yellow", flags=SOLID, passable=True)
f2("departure_board", "departure board", "A big board of scrolling times and platforms.", "D", "light_green", 10, flags=SOLID)
f2("ticket_gate", "ticket gate", "A waist-high gate with a card reader.", "g", "light_gray", flags=SOLID)
f2("water_cooler", "water cooler", "A bubbling water cooler.", "w", "light_blue", flags=SOLID)
f2("flag_pole", "flag pole", "A flag pole with a limp banner.", "f", "light_red", flags=SOLID, passable=True)
f2("cash_cage", "cash cage", "A barred cashier window.", "c", "yellow", flags=SOLID)
f2("cubicle_wall", "cubicle partition", "A shoulder-high fabric partition.", "|", "light_gray", flags=SOLID)
f2("roof_dish", "roof dish", "A satellite dish pointed at the clouds.", "Y", "light_gray", flags=SOLID)
f2("gurney", "gurney", "A wheeled stretcher with a crumpled sheet.", "g", "light_gray", flags=SURF)
f2("bath_basin", "bath basin", "A steaming tiled basin.", "O", "light_blue", 5, flags=SOLID)
f2("locker_gym", "gym locker", "A battered gym locker.", "H", "light_blue", flags=SOLID + ["FLAT_SURF"])

# ------------------------------------------------------------------ extra layout kinds
def plaza(g, S, z):
    for k, n in S["items"]: g.scatter(k, 3, 3, 20, 20, n)
    if S.get("back"): g.line(S["back"], 3, 3, 20, 3)
    for x in S.get("wall_x", ()):
        g.vwall(x, 3, 20, S.get("wall", "wall_part"))
        g.t[S.get("door_y", 8)][x] = "door_wood"; g.t[S.get("door_y2", 17)][x] = "door_wood"
def classes(g, S, z):
    rows = S.get("rows", (6, 9))
    for y in rows:
        for x in range(4, 20, 2):
            g.f_(S.get("desk", "school_desk"), x, y)
    for y in (16, 19):
        for x in range(4, 20, 2): g.f_(S.get("desk", "school_desk"), x, y)
    g.line("blackboard", 4, 3, 19, 3); g.line("blackboard", 4, 20, 19, 20)
    for k, n in S.get("deco", []): g.scatter(k, 3, 3, 20, 20, n)
mr.KINDS.update({"plaza": plaza, "classes": classes})

B2 = []
def c(id, name, sym, color, stories, wall_g, wall_u, window, floor_g, floor_u, ground, upper, loot_g, loot_u, **kw):
    B2.append(dict(id=f"trl_fn{len(B2)+1:02d}_{id}", name=name, theme="fn", sym=sym, color=color, stories=stories,
                   wall_g=wall_g, wall_u=wall_u, window=window, floor_g=floor_g, floor_u=floor_u,
                   ground=ground, upper=upper, loot_g=loot_g, loot_u=loot_u, **kw))
OFFICE_R = [("desk_corp", 1), ("chair_office", 1), ("desk_lamp", 1), ("shelf_clean", 1)]

# ---- government / civic
c("district_office", "district government office", "G", "light_gray", 3, "wall_concrete", "wall_concrete", "window", "floor_corp", "floor_corp",
  ("hall", dict(row="desk_corp", seat="chair_office", rows=(6,), rows2=(18,), deco=[("flag_pole", 2), ("queue_post", 6), ("fern", 2), ("water_cooler", 1), ("ticket_machine", 1)], back="reception")),
  ("apts", dict(room=OFFICE_R, hall=[("water_cooler", 1), ("queue_post", 2)])),
  "tool", "decor", signs=["flag_pole", "neon_cyan"])
c("precinct", "police precinct", "P", "blue", 3, "wall_concrete", "wall_concrete", "window_bars", "floor_corp", "slab",
  ("hall", dict(row="desk_corp", seat="chair_office", rows=(6,), rows2=(18,), deco=[("gun_locker", 2), ("cell_bars", 6), ("evidence_shelf", 2), ("console", 2)], back="locker_mil")),
  ("apts", dict(room=[("cell_bars", 3), ("bunk_steel", 1), ("evidence_shelf", 1)], hall=[("gun_locker", 1)])),
  "mil", "mil", door="door_steel", signs=["neon_cyan", "sentry_lamp"])
c("fire_station", "fire and rescue station", "F", "light_red", 3, "wall_brick", "wall_concrete", "window", "slab", "floor_corp",
  ("plaza", dict(items=[("hose_rack", 3), ("fire_pole", 2), ("crate", 3), ("locker_mil", 3), ("workbench", 1)], back="locker_mil")),
  ("apts", dict(room=[("bunk_steel", 2), ("locker_mil", 1), ("desk_lamp", 1)], hall=[("fire_pole", 1), ("hose_rack", 1)])),
  "tool", "tool", door="door_steel", signs=["neon_red", "neon_red"])
c("clinic", "public clinic and pharmacy", "+", "white", 3, "wall_tile", "wall_tile", "window", "floor_corp", "floor_corp",
  ("hall", dict(row="chair_lounge", seat=None, rows=(7,), rows2=(17,), deco=[("med_cabinet", 4), ("exam_couch", 2), ("reception", 1), ("fern", 2)], back="med_cabinet")),
  ("apts", dict(room=[("exam_couch", 1), ("med_cabinet", 1), ("desk_lamp", 1), ("scanner", 1)], hall=[("gurney", 1)])),
  "med", "med", signs=["neon_green", "neon_cyan"])
c("courthouse", "municipal court and archive", "C", "light_gray", 4, "wall_concrete", "wall_concrete", "window", "carpet_red", "floor_corp",
  ("hall", dict(row="chair_lounge", seat=None, rows=(8, 11), rows2=(16,), deco=[("judge_bench", 1), ("witness_box", 1), ("flag_pole", 2), ("fern", 2)], back="cabinet_lacquer")),
  ("apts", dict(room=[("shelf_clean", 3), ("desk_corp", 1), ("desk_lamp", 1)], hall=[("trash", 1)])),
  "decor", "decor", signs=["flag_pole", "lantern_stone"])
c("bank", "bank branch", "$", "yellow", 3, "wall_corp", "wall_corp", "window", "floor_corp", "floor_corp",
  ("hall", dict(row="teller_desk", seat="chair_office", rows=(6,), rows2=(18,), deco=[("queue_post", 6), ("safe_big", 1), ("vault_stack", 4), ("fern", 2)], back="vault_stack")),
  ("apts", dict(room=OFFICE_R + [("safe_big", 1)], hall=[("fern", 1)])),
  "tech", "tech", door="door_steel", signs=["neon_amber", "neon_cyan"])
c("transit_hub", "transit hub office", "T", "light_cyan", 3, "wall_corp", "wall_concrete", "window", "slab", "floor_corp",
  ("plaza", dict(items=[("ticket_gate", 4), ("departure_board", 2), ("bench_park", 4), ("vending", 2), ("ticket_machine", 3)], back="departure_board")),
  ("apts", dict(room=[("bunk_steel", 1), ("console", 1), ("locker_mil", 1), ("desk_lamp", 1)], hall=[("departure_board", 1)])),
  "tool", "tool", signs=["neon_cyan", "departure_board"])
# ---- business
c("corp_office", "corporate regional office", "O", "light_blue", 4, "wall_corp", "wall_corp", "window", "floor_corp", "floor_corp",
  ("hall", dict(row="desk_corp", seat="chair_office", dense=True, rows=(5, 8), rows2=(16, 19), deco=[("cubicle_wall", 6), ("water_cooler", 2), ("holo_ad", 1), ("fern", 3)], back="reception")),
  ("hall", dict(row="desk_corp", seat="chair_office", rows=(5, 8), rows2=(16, 19), deco=[("console", 3), ("cubicle_wall", 4), ("fern", 2), ("holo_ad", 1)])),
  "tech", "tech", signs=["neon_cyan", "holo_ad"])
c("telecom", "telecom and network exchange", "N", "light_cyan", 4, "wall_steel", "wall_steel", "window_bars", "floor_steel", "floor_steel",
  ("hall", dict(row="server_rack", seat=None, dense=True, rows=(5, 8), rows2=(16, 19), deco=[("console", 3), ("cable_tray", 0)] if False else [("console", 3), ("crystal_lamp", 2)])),
  ("hall", dict(row="server_rack", seat="chair_office", rows=(6,), rows2=(17,), deco=[("console", 3), ("crystal_lamp", 2)])),
  "tech", "tech", door="door_steel", signs=["neon_cyan", "roof_dish"], roof=[("roof_dish", 3), ("pipes", 2), ("crate", 2)])
c("hotel", "city hotel", "H", "yellow", 4, "wall_corp", "wall_concrete", "window", "carpet_red", "carpet_red",
  ("hall", dict(row="chair_lounge", seat="table_low", rows=(6,), rows2=(18,), deco=[("fern", 3), ("vase_white", 2), ("neon_amber", 2), ("bar_stool", 4)], back="reception")),
  ("apts", dict(room=[("hotel_bed", 1), ("minibar", 1), ("floor_lamp", 1), ("console", 1)], hall=[("vase_white", 2)])),
  "decor", "decor", signs=["neon_amber", "neon_pink_big"])
c("capsule_hotel", "capsule hotel", "c", "light_cyan", 4, "wall_steel", "wall_steel", "window", "floor_steel", "floor_steel",
  ("hall", dict(row="capsule", seat=None, dense=True, rows=(5, 8), rows2=(16, 19), deco=[("locker_mil", 4), ("vending", 2), ("neon_cyan", 2)], back="reception")),
  ("hall", dict(row="capsule", seat=None, dense=True, rows=(5, 8), rows2=(16, 19), deco=[("locker_mil", 3), ("neon_cyan", 2)])),
  "decor", "dingy", signs=["neon_cyan", "neon_cyan"])
c("department_store", "department store", "S", "light_green", 4, "wall_corp", "wall_corp", "window", "floor_corp", "floor_corp",
  ("hall", dict(row="shelf_clean", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("mannequin", 4), ("checkout", 3), ("lightbox", 2), ("neon_pink", 2)])),
  ("hall", dict(row="lightbox", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("mannequin", 4), ("shelf_clean", 4), ("checkout", 2)])),
  "decor", "decor", signs=["neon_pink_big", "neon_cyan"])
c("supermarket", "supermarket with flats above", "m", "green", 3, "wall_corp", "wall_concrete", "window", "floor_corp", "floor_wood",
  ("hall", dict(row="shelf_clean", seat=None, dense=True, rows=(6, 9), rows2=(16, 19), deco=[("freezer_case", 3), ("produce_bin", 4), ("checkout", 3)])),
  ("apts", dict(room=[("futon", 1), ("table_low", 1), ("desk_lamp", 1), ("hotplate", 1)], hall=[("laundry", 2)])),
  "food", "food", signs=["neon_green", "neon_amber"])
c("food_court", "food-court tower", "f", "light_red", 3, "wall_slat", "wall_concrete", "window", "floor_wood", "floor_corp",
  ("hall", dict(row="counter_noodle", seat="bar_stool", rows=(5, 8), rows2=(16, 19), deco=[("table_plastic", 6), ("stool_plastic", 8), ("neon_red", 3), ("lantern", 4)])),
  ("hall", dict(row="table_plastic", seat="stool_plastic", rows=(6,), rows2=(17,), deco=[("freezer_case", 2), ("neon_amber", 2), ("vending", 2)])),
  "food", "food", signs=["neon_red", "neon_amber"])
c("print_shop", "print shop and newspaper office", "p", "light_gray", 3, "wall_brick", "wall_concrete", "window", "slab", "floor_corp",
  ("hall", dict(row="press_machine", seat=None, rows=(6,), rows2=(17,), deco=[("paper_stack", 6), ("workbench", 2), ("crate", 3)])),
  ("apts", dict(room=[("desk_corp", 1), ("chair_office", 1), ("paper_stack", 1), ("desk_lamp", 1)], hall=[("paper_stack", 1)])),
  "tool", "decor", signs=["neon_amber", "lantern"])
c("tailor", "tailor and laundry block", "t", "light_green", 3, "wall_brick", "wall_concrete", "window", "floor_wood", "floor_wood",
  ("hall", dict(row="sewing_table", seat=None, rows=(6,), rows2=(17,), deco=[("washer_row", 4), ("mannequin", 3), ("laundry", 3)])),
  ("apts", dict(room=[("futon", 1), ("table_low", 1), ("sewing_table", 1), ("desk_lamp", 1)], hall=[("laundry", 2)])),
  "decor", "decor", signs=["neon_green", "lantern"])
c("gym_bath", "gym and bathhouse", "g", "light_blue", 3, "wall_tile", "wall_tile", "window", "floor_wood", "floor_corp",
  ("hall", dict(row="gym_bench", seat=None, rows=(6,), rows2=(17,), deco=[("locker_gym", 4), ("bath_basin", 3), ("fern", 2)])),
  ("apts", dict(room=[("locker_gym", 2), ("gym_bench", 1), ("bath_basin", 1), ("floor_lamp", 1)], hall=[("bath_basin", 1)])),
  "decor", "decor", signs=["neon_cyan", "lantern"])
c("cyber_clinic", "licensed cybernetics clinic", "k", "light_cyan", 3, "wall_corp", "wall_corp", "window", "floor_corp", "floor_steel",
  ("hall", dict(row="implant_chair", seat=None, rows=(7,), rows2=(17,), deco=[("assembly_arm", 2), ("med_cabinet", 3), ("holo_ad", 2), ("reception", 1)], back="limb_bin")),
  ("apts", dict(room=[("surgical_table", 1), ("assembly_arm", 1), ("test_bench", 1), ("med_cabinet", 1)], hall=[("scanner", 1)])),
  "android", "med", signs=["neon_cyan", "holo_ad"])
# ---- personal / education / health
c("library_school", "public library and school annex", "L", "light_green", 3, "wall_brick", "wall_concrete", "window", "floor_wood", "floor_wood",
  ("hall", dict(row="library_shelf", seat=None, rows=(5, 8), rows2=(16, 19), deco=[("table_plastic", 3), ("chair_wicker", 4), ("fern", 2)])),
  ("classes", dict(deco=[("fern", 1), ("desk_lamp", 2)])),
  "decor", "decor", signs=["lantern", "flag_pole"])
c("university", "university lecture block", "U", "light_blue", 4, "wall_concrete", "wall_concrete", "window", "floor_corp", "floor_corp",
  ("hall", dict(row="chair_lounge", seat=None, rows=(6, 9), rows2=(16, 19), deco=[("blackboard", 0), ("console", 2), ("fern", 2)] if False else [("console", 2), ("fern", 2), ("vending", 2)], back="blackboard")),
  ("classes", dict(rows=(6, 9), deco=[("console", 2), ("desk_lamp", 2)])),
  "tech", "tech", signs=["neon_cyan", "flag_pole"])
c("apts_family", "apartment block (working families)", "A", "light_gray", 4, "wall_concrete", "wall_concrete", "window", "floor_wood", "floor_wood",
  ("apts", dict(room=[("futon", 1), ("table_low", 1), ("hotplate", 1), ("laundry", 1), ("desk_lamp", 1)], hall=[("bike_rack", 1), ("laundry", 1)], lobby_items=[("fern", 2), ("vending", 1)])),
  ("apts", dict(room=[("futon", 2), ("table_low", 1), ("hotplate", 1), ("tv_static", 1), ("desk_lamp", 1)], hall=[("laundry", 2)])),
  "dingy", "food", signs=["neon_green", "lantern"])
c("apts_salaried", "apartment block (salaried workers)", "A", "light_blue", 4, "wall_corp", "wall_corp", "window", "carpet_red", "floor_corp",
  ("apts", dict(room=[("futon", 1), ("desk_corp", 1), ("chair_office", 1), ("floor_lamp", 1), ("console", 1)], hall=[("fern", 2)], lobby_items=[("reception", 1), ("fern", 2), ("neon_cyan", 1)])),
  ("apts", dict(room=[("futon", 1), ("desk_corp", 1), ("chair_office", 1), ("floor_lamp", 1)], hall=[("fern", 1)])),
  "decor", "tech", signs=["neon_cyan", "holo_ad"])
c("dorm", "student dormitory", "D", "light_green", 4, "wall_brick", "wall_concrete", "window", "floor_wood", "floor_wood",
  ("hall", dict(row="bench_park", seat=None, rows=(6,), rows2=(17,), deco=[("vending", 3), ("bike_rack", 2), ("fern", 2)], back="locker_mil")),
  ("apts", dict(room=[("bunk_steel", 1), ("desk_corp", 1), ("chair_office", 1), ("desk_lamp", 1)], hall=[("laundry", 1)])),
  "dingy", "dingy", signs=["lantern", "neon_green"])
c("hospital", "hospital wing", "+", "white", 4, "wall_tile", "wall_tile", "window", "floor_corp", "floor_corp",
  ("hall", dict(row="chair_lounge", seat=None, rows=(7,), rows2=(17,), deco=[("gurney", 3), ("scanner", 1), ("reception", 1), ("med_cabinet", 3)], back="reception")),
  ("apts", dict(room=[("hospital_bed", 2), ("iv_stand", 2), ("med_cabinet", 1), ("floor_lamp", 1)], hall=[("gurney", 1), ("iv_stand", 1)])),
  "med", "med", signs=["neon_green", "neon_red"])
# ---- slum-like (3)
c("derelict", "abandoned half-squatted block", "x", "dark_gray", 3, "wall_rust", "wall_rust", "window_bars", "floor_dirty", "floor_dirty",
  ("ruin", dict(deco=[("trash", 6), ("pipes", 4), ("mattress", 3), ("fire_drum", 1), ("tv_static", 1)])),
  ("ruin", dict(deco=[("trash", 5), ("mattress", 3), ("crate", 3), ("water_barrel", 1)])),
  "dingy", "dingy", door="shutter_c", signs=["fire_drum", "neon_red"])
c("flophouse", "dormitory flophouse", "f", "brown", 3, "wall_rust", "wall_rust", "window_bars", "floor_dirty", "floor_dirty",
  ("hall", dict(row="bunk_rust", seat=None, dense=True, rows=(5, 8), rows2=(16, 19), deco=[("trash", 3), ("fire_drum", 1), ("water_barrel", 2)])),
  ("hall", dict(row="bunk_rust", seat=None, dense=True, rows=(5, 8), rows2=(16, 19), deco=[("laundry", 3), ("trash", 3)])),
  "dingy", "dingy", door="shutter_c", signs=["fire_drum", "neon_amber"])
c("rooftop_shanty", "rooftop-shanty block", "s", "brown", 3, "wall_pipes", "wall_rust", "window_bars", "slab", "floor_dirty",
  ("plaza", dict(items=[("stall_awning", 4), ("crate", 4), ("noodle_cart", 2), ("lantern", 4), ("trash", 4)])),
  ("apts", dict(room=[("mattress", 1), ("hotplate", 1), ("crate", 1), ("tv_static", 1)], hall=[("laundry", 2), ("trash", 2)])),
  "dingy", "dingy", door="shutter_c", signs=["neon_amber", "fire_drum"], roof=[("stall_awning", 4), ("crate", 4), ("water_barrel", 3), ("laundry", 3), ("fire_drum", 1)])
# ---- criminal (3)
c("syndicate_front", "syndicate front office", "$", "red", 4, "wall_corp", "wall_lacquer", "window", "floor_corp", "carpet_red",
  ("hall", dict(row="desk_corp", seat="chair_office", rows=(6,), rows2=(18,), deco=[("fern", 2), ("cabinet_lacquer", 2), ("neon_cyan", 1)], back="reception")),
  ("apts", dict(room=[("safe_big", 1), ("ledger_desk", 1), ("chair_lounge", 2), ("weapon_rack", 1), ("floor_lamp", 1)], hall=[("vase_red", 2)])),
  "tech", "mil", door="door_steel", signs=["neon_cyan", "neon_red"])
c("chop_clinic", "black-market clinic and chop shop", "c", "red", 3, "wall_rust", "wall_tile", "window_bars", "slab", "floor_dirty",
  ("hall", dict(row="chop_lift", seat=None, rows=(6,), rows2=(17,), deco=[("parts_bin", 5), ("workbench", 2), ("fire_drum", 1), ("limb_bin", 2)])),
  ("apts", dict(room=[("surgical_table", 1), ("limb_bin", 1), ("med_cabinet", 1), ("parts_bin", 1), ("floor_lamp", 1)], hall=[("gurney", 1)])),
  "android", "med", door="shutter_c", signs=["neon_red", "neon_green"])
c("gambling_den", "gambling den and loan shark", "d", "magenta", 3, "wall_lacquer", "wall_lacquer", "window", "carpet_red", "carpet_red",
  ("hall", dict(row="dice_table", seat="chair_lounge", rows=(6, 9), rows2=(16, 19), deco=[("cash_cage", 2), ("neon_pink", 3), ("mirror_ball", 1), ("pachinko", 3)], back="neon_violet")),
  ("apts", dict(room=[("ledger_desk", 1), ("safe_big", 1), ("chair_lounge", 1), ("table_card", 1), ("floor_lamp", 1)], hall=[("neon_pink", 1)])),
  "drink", "drink", signs=["neon_pink_big", "neon_red"])
assert len(B2) == 30, len(B2)

def main():
    gp.assign_chars()
    mr_roof_default = [("neon_pink_big", 2), ("pipes", 3), ("vending", 1), ("crate", 3)]
    loot = {
      "office": ["paper", "pen", "pencil", "cash_card", "small_lcd_screen", "cable", "radio"],
    }
    mr.emit(B2, "midrise2", new_t=NEW_T - OLD_T, new_f=NEW_F - OLD_F - {"parts_bin"}, write_loot=False)
    # extra loot groups used by nothing new: none needed (tags reuse existing groups)
    print("B2 done")

if __name__ == "__main__":
    main()
    pv = os.environ.get("PREVIEW")
    if pv:
        for S in B2:
            if pv in S["id"]:
                for z, g in enumerate(S["_g"]):
                    print(f"--- {S['id']} z{z}")
                    inv = {(x, y): F[k]["sym"] for k, x, y in g.f}
                    for y in range(24):
                        print("".join(inv.get((x, y), T[g.t[y][x]]["sym"] or ("." if g.t[y][x] in FLOORS else "?")) if g.t[y][x] != "air" else " " for x in range(24)))
