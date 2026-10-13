"""The five special mid-towers: palace, power/telecom station, police station, two fabrication plants."""
from gt_recipes import *
import gt_recipes

# ============================================================================ extra room kinds
def kp_tea(lf, w, h, ud):
    lf.floor("tatami")
    for u in range(1, w - 1, 2): lf.f("gilt_screen", u, 0)
    for u in range(2, w - 2, 4):
        for v in range(2, h - 2, 3):
            lf.f("table_low", u, v); lf.f("cushion", u - 1, v); lf.f("cushion", u + 1, v)
    lf.f("bonsai", 0, h - 2); lf.f("bonsai", w - 1, h - 2); lf.f("vase_white", w - 1, 1); lf.f("koi_lantern", 0, 1)
    lf.loot("trl_loot_palace", 35, 2)
def kp_banquet(lf, w, h, ud):
    lf.floor("carpet_red")
    for u in range(1, w - 1, 2): lf.f("gilt_screen", u, 0) if u % 4 == 1 else lf.f("vase_tall", u, 0)
    for v in range(2, h - 2, 3):
        for u in range(2, w - 2): lf.f("banquet_table", u, v)
        for u in range(2, w - 2, 2): lf.f("chair", u, v - 1); lf.f("chair", u, v + 1) if v + 1 < h - 1 else None
    lf.f("statue_gilt", 0, h - 2); lf.f("statue_gilt", w - 1, h - 2); lf.f("chandelier", w // 2, h // 2)
    lf.loot("trl_loot_palace", 45, 3); lf.loot("trl_loot_drink", 50, 3)
def kp_throne(lf, w, h, ud):
    lf.floor("marble")
    for v in range(0, h): lf.t("carpet_red", w // 2, v); lf.t("carpet_red", w // 2 - 1, v) if w > 6 else None
    lf.f("throne", w // 2, 0)
    for u in range(1, w - 1, 3): lf.f("statue_gilt", u, 2) if u not in (w // 2, w // 2 - 1) else None
    lf.f("gilt_screen", w // 2 - 2, 0); lf.f("gilt_screen", w // 2 + 2, 0)
    for v in range(2, h - 1, 3): lf.f("lantern_stone", 1, v); lf.f("lantern_stone", w - 2, v)
    lf.f("chandelier", w // 2, h // 2); lf.f("vase_blue", 0, 0); lf.f("vase_red", w - 1, 0)
    lf.loot("trl_loot_palace", 40, 3)
def kp_gallery(lf, w, h, ud):
    lf.floor("marble")
    for u in range(1, w - 1, 3):
        lf.f("scroll", u, 0)
        lf.f(["vase_blue", "vase_white", "vase_red", "vase_tall"][u % 4], u + 1, 2) if h > 5 else None
        lf.f("displaycase", u, 4) if h > 7 else None
    lf.f("gilt_screen", w // 2, h // 2); lf.f("statue_gilt", w - 1, h - 2); lf.f("bonsai", 0, h - 2)
    lf.loot("trl_loot_palace", 55, 4); lf.loot("trl_loot_decor", 50, 3)
def kp_bath(lf, w, h, ud):
    lf.floor("tile_bath")
    for u in range(2, w - 2):
        for v in range(2, h - 3): lf.t("shallow", u, v)
    for u in range(w): lf.f("shower", u, 0) if u % 2 == 0 else lf.f("sink", u, 0)
    lf.f("bench", 0, h // 2); lf.f("bench", w - 1, h // 2); lf.f("koi_lantern", 1, 1); lf.f("lantern_stone", w - 2, h - 2)
    lf.loot("trl_loot_apt", 35, 2)
def kp_kitchen(lf, w, h, ud):
    lf.floor("checker")
    for u in range(w): lf.f(["oven", "fridge", "sink", "counter", "oven", "counter"][u % 6], u, 0)
    for u in range(1, w - 1, 2): lf.f("counter", u, 3) if u != w // 2 else None
    for u in range(2, w - 2, 3): lf.f("table", u, h - 3); lf.f("stool_plastic", u, h - 2)
    lf.f("glass_fridge", w - 1, 2); lf.f("floodlight", 0, h - 2) if False else None
    lf.loot("trl_loot_conv", 65, 4); lf.loot("trl_loot_drink", 40, 2)
def kp_guard(lf, w, h, ud):
    lf.floor("slab")
    for u in range(1, w - 1, 2): lf.f("weapon_rack" if u % 4 == 1 else "locker", u, 0)
    for v in range(3, h - 2, 3): lf.f("table_plastic", w // 2, v); lf.f("bench", w // 2 - 1, v); lf.f("bench", w // 2 + 1, v)
    lf.f("console", 0, h - 2); lf.f("bunk_bed", w - 1, 2); lf.f("bunk_bed", w - 1, 4)
    lf.loot("trl_loot_police", 50, 3); lf.loot("trl_loot_armory", 20, 1)
def kp_library(lf, w, h, ud):
    lf.floor("floor_wood")
    for u in range(w): lf.f("bookcase", u, 0)
    for v in range(2, h - 2, 3):
        for u in range(1, w - 1): lf.f("bookcase", u, v) if u % 5 != 0 else None
    lf.f("armchair", w - 1, h - 3); lf.f("armchair", 0, h - 3); lf.f("desk_lamp", w - 2, h - 3); lf.f("piano", w // 2, h - 2) if w > 8 else None
    lf.f("vase_tall", 0, 1); lf.f("scroll", w - 1, 1)
    lf.loot("trl_loot_books", 65, 5)
def kp_vault(lf, w, h, ud):
    lf.floor("epoxy")
    for u in range(1, w - 1): lf.f("safe", u, 0)
    for v in range(2, h - 2, 2): lf.f("displaycase", 1, v); lf.f("displaycase", w - 2, v)
    lf.f("lightbox", w // 2, h // 2); lf.f("statue_gilt", w // 2, 1)
    lf.loot("trl_loot_palace", 90, 6)
def kp_master(lf, w, h, ud):
    lf.floor("floor_wood")
    lf.f("silk_bed", w // 2, 1); lf.f("silk_bed", w // 2 + 1, 1); lf.f("dresser", w // 2 - 2, 0); lf.f("dresser", w // 2 + 3, 0)
    for u in range(1, w - 1, 3): lf.f("gilt_screen", u, h // 2)
    lf.f("sofa", 2, h - 3); lf.f("sofa", 4, h - 3); lf.f("table_low", 3, h - 4); lf.f("aquarium", w - 1, h // 2)
    lf.f("chandelier", w // 2, h // 2); lf.f("vase_blue", 0, 0); lf.f("vase_red", w - 1, 0); lf.f("piano", w - 3, h - 3)
    lf.loot("trl_loot_palace", 60, 4); lf.loot("trl_loot_apt", 40, 2)
def kp_shrine(lf, w, h, ud):
    lf.floor("tatami")
    lf.f("shrine", w // 2, 0); lf.f("torii", w // 2, h // 2)
    for u in range(1, w - 1, 3): lf.f("lantern_stone", u, 2); lf.f("cushion", u, h - 3)
    lf.f("statue_fox", 1, 1); lf.f("statue_fox", w - 2, 1); lf.f("bonsai", 0, h - 2); lf.f("bonsai", w - 1, h - 2)
    lf.loot("trl_loot_palace", 30, 2)
def kp_lounge(lf, w, h, ud):
    lf.floor("floor_wood")
    for u in range(1, w - 1, 3):
        lf.f("sofa", u, h - 3); lf.f("armchair", u + 1, h - 5) if h > 6 else None; lf.f("table_low", u, h - 4)
    lf.f("aquarium", w // 2, 0); lf.f("vase_white", 0, 0); lf.f("bonsai", w - 1, 0)
    lf.loot("trl_loot_palace", 30, 2)
# ---- police
def kc_cells(lf, w, h, ud):
    """Cell block in local frame: cells (3 wide, 4 deep) along the back wall, corridor in front."""
    lf.floor("slab")
    for i in range((w + 1) // 4):
        u0 = i * 4
        if u0 + 2 >= w: break
        for v in range(0, 4): lf.t("bars", u0 + 3, v)
        for u in range(u0, u0 + 3): lf.t("bars", u, 4)
        lf.t("cell_door", u0 + 1, 4)
        lf.f("cell_bench", u0, 0); lf.f("toilet", u0 + 2, 0)
    lf.loot("trl_loot_police", 20, 1)
def kc_interrogation(lf, w, h, ud):
    lf.floor("floor_plain")
    lf.f("interrogation_table", w // 2, h // 2); lf.f("chair_office", w // 2, h // 2 - 1); lf.f("chair_office", w // 2, h // 2 + 1)
    lf.f("console", 0, 0); lf.f("aquarium", w - 1, 0) if False else None
    lf.loot("trl_loot_police", 25, 1)
def kc_bullpen(lf, w, h, ud):
    lf.floor("carpet_grey")
    for v in range(1, h - 2, 3):
        for u in range(1, w - 1, 4):
            lf.f("desk_corp", u, v); lf.f("console", u + 1, v); lf.f("chair_office", u, v + 1)
    lf.f("filing", 0, 0); lf.f("filing", w - 1, 0); lf.f("vending", w - 1, h - 2)
    lf.loot("trl_loot_police", 55, 5); lf.loot("trl_loot_office", 45, 3)
def kc_records(lf, w, h, ud):
    lf.floor("carpet_grey")
    for v in range(0, h - 2, 2):
        for u in range(1, w - 1): lf.f("filing", u, v) if u % 3 else None
    lf.f("desk_corp", w - 1, h - 2); lf.f("console", w - 2, h - 2)
    lf.loot("trl_loot_office", 60, 4)
def kc_evidence(lf, w, h, ud):
    lf.floor("slab")
    for u in range(1, w - 1): lf.f("evidence_locker", u, 0)
    for v in range(2, h - 2, 2):
        for u in range(1, w - 2): lf.f("evidence_locker", u, v) if u % 4 else None
    lf.f("desk_corp", w - 1, h - 2)
    lf.loot("trl_loot_evidence", 75, 6)
def kc_armory(lf, w, h, ud):
    lf.floor("epoxy")
    for u in range(w): lf.f("weapon_rack", u, 0)
    for v in range(2, h - 1, 2): lf.f("locker", 0, v); lf.f("locker", w - 1, v)
    lf.f("safe", w // 2, 2); lf.f("workbench", w // 2, h - 3)
    lf.loot("trl_loot_armory", 85, 5)
def kc_briefing(lf, w, h, ud):
    lf.floor("carpet_grey")
    for v in range(3, h - 1, 2):
        for u in range(1, w - 1): lf.f("chair", u, v) if u % 5 else None
    lf.f("desk_corp", w // 2, 0); lf.f("console", w // 2 + 1, 0); lf.f("holo_ad", 1, 0); lf.f("holo_ad", w - 2, 0)
    lf.loot("trl_loot_office", 30, 2)
def kc_dispatch(lf, w, h, ud):
    lf.floor("carpet_grey")
    for u in range(1, w - 1, 3): lf.f("dispatch_desk", u, 1); lf.f("chair_office", u, 2)
    for u in range(2, w - 2, 3): lf.f("dispatch_desk", u, 4) if h > 7 else None
    lf.f("server_rack", 0, 0); lf.f("server_rack", w - 1, 0); lf.f("holo_ad", w // 2, 0)
    lf.loot("trl_loot_police", 35, 2)
def kc_office(lf, w, h, ud):
    lf.floor("carpet_teal")
    lf.f("desk_corp", w // 2, 1); lf.f("chair_office", w // 2, 2); lf.f("filing", 0, 0); lf.f("filing", 1, 0)
    lf.f("sofa", w - 2, h - 3); lf.f("fern", w - 1, 0); lf.f("bookcase", w - 1, 2)
    lf.loot("trl_loot_office", 50, 3)
def kc_lockers(lf, w, h, ud):
    lf.floor("tile_bath")
    for u in range(1, w - 1): lf.f("locker", u, 0)
    for v in range(2, h - 2, 3):
        for u in range(1, w - 1): lf.f("locker", u, v) if u % 3 else None
        lf.f("bench", w // 2, v + 1)
    lf.f("shower", w - 1, h - 2)
    lf.loot("trl_loot_police", 40, 3)
def kc_gym(lf, w, h, ud):
    lf.floor("epoxy")
    for u in range(1, w - 1, 2): lf.f("bench", u, 1); lf.f("rack", u, 0)
    lf.f("shower", w - 1, 0); lf.f("fern", 0, h - 2)
    lf.loot("trl_loot_police", 20, 1)
def kc_garage(lf, w, h, ud):
    lf.floor("hazard")
    lf.f("floodlight", 0, 0); lf.f("floodlight", w - 1, 0); lf.f("workbench", 1, 1); lf.f("tool_cabinet", 2, 1); lf.f("tool_cabinet", w - 2, 1)
    lf.f("bike_rack", w // 2, 2); lf.f("charging_pod", w // 2 + 2, 2); lf.f("charging_pod", w // 2 - 2, 2)
    lf.loot("trl_loot_tool", 60, 4)
# ---- power / telecom
def kw_generators(lf, w, h, ud):
    lf.floor("epoxy")
    for v in range(3, h - 3, 7):
        for u in range(2, w - 4, 7):
            lf.f("generator", u, v); lf.f("generator", u + 1, v); lf.f("cable_trunk", u, v + 1); lf.f("cable_trunk", u + 1, v + 1)
            lf.f("transformer", u + 3, v)
        for u in range(0, w): lf.t("hazard", u, v + 3) if v + 3 < h - 1 else None
    for u in range(1, w - 1, 4): lf.f("switchgear", u, 0)
    for v in range(3, h - 3, 7):
        for u in range(1, w - 1): lf.f("cable_trunk", u, v + 2) if u % 3 else None
    for v in range(2, h - 2, 5): lf.f("pipes", w - 1, v); lf.f("pipes", 0, v)
    lf.f("floodlight", 0, h - 2); lf.f("floodlight", w - 1, h - 2); lf.f("status_panel", w // 2, 0)
    lf.loot("trl_loot_power", 60, 6)
def kw_switchgear(lf, w, h, ud):
    lf.floor("epoxy")
    for v in range(1, h - 2, 3):
        for u in range(1, w - 1): lf.f("switchgear" if u % 2 else "capacitor_bank", u, v) if u % 5 else None
        for u in range(1, w - 1): lf.t("hazard", u, v + 1)
    lf.f("status_panel", w // 2, 0)
    lf.loot("trl_loot_power", 55, 5)
def kw_batteries(lf, w, h, ud):
    lf.floor("epoxy")
    for v in range(1, h - 2, 3):
        for u in range(1, w - 1): lf.f("battery_bank", u, v) if u % 6 else None
        for u in range(1, w - 1): lf.t("hazard", u, v + 1) if (v + u) % 2 == 0 else None
    lf.f("fire_drum", w - 1, h - 2) if False else None
    lf.f("status_panel", 1, 0); lf.f("status_panel", w - 2, 0)
    lf.loot("trl_loot_power", 55, 5)
def kw_control(lf, w, h, ud):
    lf.floor("carpet_grey")
    for u in range(1, w - 1): lf.f("status_panel", u, 0) if u % 3 == 0 else lf.f("console", u, 0)
    for v in (3, 6):
        for u in range(1, w - 1, 3): lf.f("dispatch_desk", u, v); lf.f("chair_office", u, v + 1)
    lf.f("holo_ad", w // 2, h - 2); lf.f("vending", w - 1, h - 2); lf.f("fern", 0, h - 2)
    lf.loot("trl_loot_power", 35, 3); lf.loot("trl_loot_office", 30, 2)
def kw_serverhall(lf, w, h, ud):
    lf.floor("grating")
    for v in range(1, h - 2, 3):
        for u in range(1, w - 1): lf.f("server_rack", u, v) if u % 6 else None
        for u in range(0, w): lf.t("neon_cyan", u, v + 1) if u % 3 == 0 else None
    lf.f("status_panel", 0, 0); lf.f("status_panel", w - 1, 0); lf.f("cable_trunk", w // 2, h - 2)
    lf.loot("trl_loot_telecom", 65, 6)
def kw_cablevault(lf, w, h, ud):
    lf.floor("epoxy")
    for v in range(1, h - 2, 2):
        for u in range(1, w - 1): lf.f("cable_trunk", u, v)
    for u in range(1, w - 1, 4): lf.f("switchgear", u, 0)
    lf.f("status_panel", w // 2, 0)
    lf.loot("trl_loot_telecom", 50, 4)
def kw_cooling(lf, w, h, ud):
    lf.floor("epoxy")
    for v in range(1, h - 2, 4):
        for u in range(1, w - 1, 3): lf.f("ac_unit", u, v)
        for u in range(0, w): lf.f("pipes", u, v + 1) if u % 2 else None
    lf.f("status_panel", w // 2, 0)
    lf.loot("trl_loot_power", 40, 3)
def kw_radio(lf, w, h, ud):
    lf.floor("grating")
    for u in range(1, w - 1, 2): lf.f("server_rack", u, 0)
    for v in range(3, h - 2, 4):
        for u in range(1, w - 1, 3): lf.f("capacitor_bank", u, v); lf.f("console", u + 1, v)
    lf.f("status_panel", w // 2, 2)
    lf.loot("trl_loot_telecom", 55, 5)
# ---- factories
def kf_receiving(lf, w, h, ud):
    lf.floor("hazard")
    for v in range(1, h - 2, 3):
        for u in range(1, w - 1, 3): lf.f("pallet", u, v); lf.f("crate", u + 1, v) if (u + v) % 2 else None
    lf.f("floodlight", 0, h - 2); lf.f("floodlight", w - 1, h - 2); lf.f("tool_cabinet", w - 1, 0)
    lf.loot("trl_loot_implant", 40, 4); lf.loot("trl_loot_fmetal", 40, 3)
def kf_stores(lf, w, h, ud):
    lf.floor("slab")
    for v in range(0, h - 2, 3):
        for u in range(1, w - 1): lf.f("parts_bin", u, v) if u % 4 else None
    lf.f("workbench", w - 1, h - 2)
    lf.loot("trl_loot_fmetal", 60, 5); lf.loot("trl_loot_implant", 50, 4)
def kf_cleanline(lf, w, h, ud):
    lf.floor("floor_clean")
    for v in range(1, h - 2, 5):
        for u in range(1, w - 1, 3): lf.f("implant_printer", u, v); lf.f("robot_arm", u + 1, v + 1)
        for u in range(0, w): lf.f("assembly_line", u, v + 2) if u % 5 else None
    for u in range(0, w, 4): lf.f("fume_hood", u, h - 1) if False else None
    lf.loot("trl_loot_implant", 70, 6)
def kf_qc(lf, w, h, ud):
    lf.floor("floor_clean")
    for u in range(1, w - 1, 3): lf.f("cleanroom_bench", u, 0); lf.f("chair_office", u, 1)
    for u in range(1, w - 1, 3): lf.f("fume_hood", u, 3) if h > 6 else None
    lf.f("console", w - 1, h - 2); lf.f("lightbox", 0, h - 2)
    lf.loot("trl_loot_implant", 55, 4)
def kf_lab(lf, w, h, ud):
    lf.floor("floor_clean")
    for v in range(1, h - 2, 3):
        for u in range(1, w - 1, 3): lf.f("cleanroom_bench", u, v); lf.f("console", u + 1, v)
    for u in range(w): lf.f("fume_hood", u, 0) if u % 4 == 0 else None
    lf.f("implant_printer", w - 1, h - 2); lf.f("holo_ad", w // 2, h - 2)
    lf.loot("trl_loot_implant", 65, 5); lf.loot("trl_loot_telecom", 30, 2)
def kf_canteen(lf, w, h, ud):
    lf.floor("checker")
    for u in range(w): lf.f(["oven", "counter", "sink", "fridge"][u % 4], u, 0)
    for v in range(3, h - 2, 3):
        for u in range(1, w - 1, 3): lf.f("table_plastic", u, v); lf.f("stool_plastic", u, v + 1); lf.f("stool_plastic", u + 1, v)
    lf.f("vending", w - 1, h - 2)
    lf.loot("trl_loot_conv", 50, 3)
def kf_machine(lf, w, h, ud):
    lf.floor("epoxy")
    for v in range(2, h - 3, 5):
        for u in range(2, w - 2, 5):
            k = ["lathe", "press", "lathe", "workbench"][(u + v) % 4]
            lf.f(k, u, v); lf.f("parts_bin", u + 1, v) if (u + v) % 3 == 0 else None
        for u in range(0, w): lf.t("hazard", u, v + 2) if u % 3 else None
    for u in range(1, w - 1, 4): lf.f("tool_cabinet", u, 0)
    lf.f("floodlight", 0, h - 2); lf.f("floodlight", w - 1, h - 2)
    lf.loot("trl_loot_fmetal", 70, 8)
def kf_polymer(lf, w, h, ud):
    lf.floor("epoxy")
    for v in range(2, h - 3, 6):
        for u in range(2, w - 3, 8):
            lf.f("polymer_vat", u, v); lf.f("extruder", u + 2, v); lf.f("extruder", u + 3, v); lf.f("sheet_roll", u + 5, v)
        for u in range(0, w): lf.f("assembly_line", u, v + 2) if u % 7 else None
    for u in range(1, w - 1, 5): lf.f("pipes", u, 0)
    lf.f("floodlight", 0, h - 2); lf.f("floodlight", w - 1, h - 2)
    lf.loot("trl_loot_fpoly", 70, 8)
def kf_stamping(lf, w, h, ud):
    lf.floor("hazard")
    for v in range(2, h - 3, 5):
        for u in range(2, w - 3, 5): lf.f("press", u, v); lf.f("parts_bin", u + 1, v); lf.f("robot_arm", u + 2, v)
    for u in range(0, w): lf.f("assembly_line", u, h - 3) if u % 6 else None
    lf.f("floodlight", 0, 0); lf.f("floodlight", w - 1, 0)
    lf.loot("trl_loot_fmetal", 65, 6)
def kf_packing(lf, w, h, ud):
    lf.floor("slab")
    for v in range(1, h - 2, 3):
        for u in range(1, w - 1, 3): lf.f("pallet", u, v)
    for u in range(w): lf.f("assembly_line", u, h - 2) if u % 4 else None
    lf.f("sheet_roll", 0, 0); lf.f("sheet_roll", w - 1, 0)
    lf.loot("trl_loot_fpoly", 50, 4); lf.loot("trl_loot_fmetal", 40, 3)
def kf_office(lf, w, h, ud): kc_office(lf, w, h, ud)

gt_recipes.KIND.update({k[0:]: v for k, v in globals().items() if False})
for _n, _f in list(globals().items()):
    if _n.startswith(("kp_", "kc_", "kw_", "kf_")) and callable(_f):
        gt_recipes.KIND[_n[1:]] = _f   # e.g. "p_tea", "c_cells"

def room(L, x0, y0, x1, y1, side, kind, wall="wall_concrete", off=None, dk="wdoor"):
    return shop(L, x0, y0, x1, y1, side, kind, wall, off=off, door_key=dk)

def extra_door(L, key, x, y): L.door(key, x, y)

def rows_box(L, x0, y0, x1, y1, wall, floor, doors=()):
    L.rect(x0, y0, x1, y1, wall, floor)
    for k, x, y in doors: L.door(k, x, y)

# ============================================================================ the buildings
def register(bld, G):
    shell_ring = None
    roof_level = G["roof_level"]

    # ------------------------------------------------------------------- mt11 palace
    @bld("mt11", "gilded palace", 2, 2, 4, "P", "yellow", "wall_lacquer", 300, min_city=3, kind="palace")
    def mt11(L):
        z = L.z; wl = "wall_lacquer"; wg = "wall_gilt"
        L.shell(wl, "marble")
        strips = ((2, 11, 45, 14), (2, 33, 45, 36), (11, 15, 14, 32), (33, 15, 36, 32))
        sfl = "pave" if z == 0 else "carpet_red"
        for (a, b_, c, d) in strips: L.fill(a, b_, c, d, sfl)
        if z == 0:
            L.fill(15, 15, 32, 32, "pave")
            L.fill(17, 17, 30, 30, "pave"); L.fill(19, 19, 28, 28, "water"); L.fill(23, 19, 24, 28, "floor_wood"); L.fill(19, 23, 28, 24, "floor_wood")
            for (x, y) in ((18, 18), (29, 18), (18, 29), (29, 29)): L.f_("koi_lantern", x, y)
            for (x, y) in ((16, 20), (31, 20), (16, 27), (31, 27), (22, 16), (25, 31)): L.f_("lantern_stone", x, y)
            for (x, y) in ((17, 17), (30, 17), (17, 30), (30, 30)): L.f_("bonsai", x, y)
            L.f_("torii", 23, 17); L.f_("statue_fox", 21, 16); L.f_("statue_fox", 26, 16)
        else:
            L.fill(16, 16, 31, 31, "air")
            for x in range(15, 33): L.put("rail", x, 15); L.put("rail", x, 32)
            for y in range(15, 33): L.put("rail", 15, y); L.put("rail", 32, y)
        fl = "marble" if z == 0 else "carpet_red"
        L.fill(20, 6, 27, 10, fl); L.fill(20, 37, 27, 45, fl)
        # per-floor wings: (x0,y0,x1,y1, side, kind, wall)
        PL = {
         0: [(1, 1, 19, 10, "s", "p_tea", wg), (28, 1, 46, 10, "s", "p_gallery", wg),
             (1, 37, 19, 46, "n", "p_guard", wl), (28, 37, 46, 46, "n", "p_kitchen", wl),
             (1, 15, 10, 23, "e", "p_bath", wl), (1, 23, 10, 32, "e", "p_lounge", wl),
             (37, 15, 46, 23, "w", "p_library", wl), (37, 23, 46, 32, "w", "p_tea", wl)],
         1: [(1, 1, 19, 10, "s", "p_banquet", wg), (28, 1, 46, 10, "s", "p_throne", wg),
             (1, 37, 10, 46, "n", "F:lux", wl), (10, 37, 19, 46, "n", "F:lux", wl), (28, 37, 46, 46, "n", "p_library", wl),
             (1, 15, 10, 23, "e", "F:lux", wl), (1, 23, 10, 32, "e", "F:lux", wl),
             (37, 15, 46, 23, "w", "p_lounge", wl), (37, 23, 46, 32, "w", "p_tea", wl)],
         2: [(1, 1, 19, 10, "s", "p_master", wg), (28, 1, 46, 10, "s", "p_gallery", wg),
             (1, 37, 19, 46, "n", "p_lounge", wl), (28, 37, 46, 46, "n", "p_banquet", wg),
             (1, 15, 10, 23, "e", "F:lux", wl), (1, 23, 10, 32, "e", "F:lux", wl),
             (37, 15, 46, 23, "w", "p_gallery", wl), (37, 23, 46, 32, "w", "p_bath", wl)],
         3: [(1, 1, 19, 10, "s", "p_lounge", wg), (28, 1, 46, 10, "s", "p_shrine", wg),
             (1, 37, 10, 46, "n", "p_vault", wl), (10, 37, 19, 46, "n", "p_library", wl), (28, 37, 46, 46, "n", "p_master", wg),
             (1, 15, 10, 23, "e", "F:lux", wl), (1, 23, 10, 32, "e", "p_tea", wl),
             (37, 15, 46, 23, "w", "p_gallery", wl), (37, 23, 46, 32, "w", "F:lux", wl)]}[z]
        for (x0, y0, x1, y1, side, kind, wk) in PL:
            if kind.startswith("F:"): flat(L, x0, y0, x1, y1, side, kind[2:], wk)
            else:
                dk = "mdoor_l" if kind == "p_vault" else "wdoor"
                room(L, x0, y0, x1, y1, side, kind, wk, dk=dk)
        # lobby / foyer dressing
        for (x, y) in ((21, 40), (26, 40)): L.f_("statue_gilt", x, y)
        L.f_("chandelier", 23, 41); L.f_("chandelier", 24, 8); L.f_("gilt_screen", 22, 44); L.f_("gilt_screen", 25, 44)
        L.f_("vase_blue", 20, 37); L.f_("vase_white", 27, 37); L.f_("vase_red", 20, 10); L.f_("vase_blue", 27, 10)
        if z == 0:
            L.hline(23, 24, 46, "door_c"); L.f_("neon_amber", 21, 45); L.f_("neon_amber", 26, 45)
        L.windows(5)
        if z > 0: L.put("window", 23, 46); L.put("window", 24, 46)
        L.core(21, 2, ("s", 2))
        L.roof_void = (16, 16, 31, 31)

    def roof_palace(L):
        roof_level(L, (21, 2), void=(16, 16, 31, 31))
        # terrace garden, lanterns and a tea pavilion
        for (x0, y0, x1, y1) in ((3, 3, 8, 10), (39, 3, 44, 10), (3, 37, 8, 44), (39, 37, 44, 44)): L.fill(x0, y0, x1, y1, "grass")
        L.rect(10, 38, 17, 44, "wall_lacquer", "tatami"); L.door("screen_c", 13, 38); L.door("screen_c", 14, 38)
        L.f_("table_low", 13, 42); L.f_("cushion", 12, 42); L.f_("cushion", 14, 42); L.f_("bonsai", 11, 40); L.f_("vase_white", 16, 40)
        for (x, y) in ((4, 4), (7, 9), (41, 5), (43, 9), (4, 38), (7, 43), (41, 38), (43, 43)): L.f_("bonsai", x, y)
        for (x, y) in ((9, 6), (38, 6), (9, 40), (38, 41), (22, 12), (25, 36)): L.f_("lantern_stone", x, y)
        L.f_("fountain", 22, 5) if False else None
    BUILD_RS = {"trl_mt11": roof_palace}

    # ------------------------------------------------------------------- mt12 power and telecom
    @bld("mt12", "power and telecom station", 2, 2, 3, "E", "light_blue", "wall_pipes", 300, min_city=3, kind="power")
    def mt12(L):
        z = L.z; wp = "wall_pipes"
        L.shell(wp, "epoxy")
        if z == 0:
            room(L, 1, 1, 17, 11, "s", "w_control", wp)
            room(L, 17, 1, 29, 11, "s", "c_office", wp)
            L.rect(29, 1, 46, 11, wp, "checker")
            room(L, 1, 11, 28, 46, "n", "w_generators", wp, off=9, dk="mdoor")
            room(L, 28, 11, 46, 28, "w", "w_switchgear", wp, dk="mdoor")
            room(L, 28, 28, 46, 46, "w", "w_batteries", wp, dk="mdoor")
            L.door("mdoor", 22, 11); L.door("door_c", 37, 11)
            L.hline(14, 15, 46, "shutter_c")
            L.door("door_c", 36, 1)
            for u in range(31, 45, 3): L.f_("bench_waiting", u, 8)
            L.f_("reception", 33, 4); L.f_("reception", 34, 4); L.f_("beacon", 36, 3)
            L.sign("neon_cyan", 33, 0); L.sign("neon_amber", 40, 0)
            L.core(40, 2, ("s", 2), wall=wp)
        elif z == 1:
            room(L, 1, 1, 17, 11, "s", "c_dispatch", wp)
            room(L, 17, 1, 29, 11, "s", "c_briefing", wp)
            L.rect(29, 1, 46, 11, wp, "carpet_grey")
            for u in range(31, 45, 3): L.f_("sofa", u, 9)
            L.f_("holo_ad", 34, 6)
            room(L, 1, 11, 28, 46, "n", "w_serverhall", wp, off=9)
            room(L, 28, 11, 46, 28, "w", "w_cablevault", wp)
            room(L, 28, 28, 46, 46, "w", "w_serverhall", wp)
            L.door("wdoor", 22, 11); L.door("wdoor", 37, 11)
            L.core(40, 2, ("s", 2), wall=wp)
        else:
            room(L, 1, 1, 17, 11, "s", "c_office", wp)
            room(L, 17, 1, 29, 11, "s", "c_lockers", wp)
            L.rect(29, 1, 46, 11, wp, "carpet_grey")
            for u in range(31, 45, 3): L.f_("table_low", u, 9); L.f_("cushion", u, 8)
            L.f_("holo_ad", 34, 6)
            room(L, 1, 11, 28, 46, "n", "w_cooling", wp, off=9)
            room(L, 28, 11, 46, 46, "w", "w_radio", wp, off=30)
            L.door("wdoor", 22, 11); L.door("wdoor", 37, 11)
            L.core(40, 2, ("s", 2), wall=wp)
        L.windows(6)
        if z == 0:
            for (x, y) in ((2, 12), (26, 12), (2, 44), (26, 44)): L.f_("floodlight", x, y)
    def roof_power(L):
        roof_level(L, (40, 2), extra=("antenna_mast",) * 4)
        for v in range(14, 40, 4):
            for u in range(4, 24, 2): L.f_("solar_array", u, v)
        for (x, y) in ((6, 6), (42, 40), (30, 22)): L.f_("antenna_mast", x, y)
    BUILD_RS["trl_mt12"] = roof_power

    # ------------------------------------------------------------------- mt13 police
    @bld("mt13", "metropolitan police station", 2, 2, 3, "p", "light_blue", "wall_concrete", 300, min_city=3, kind="police")
    def mt13(L):
        z = L.z; w_ = "wall_concrete"
        L.shell(w_, "carpet_grey" if z else "marble")
        if z == 0:
            room(L, 1, 1, 14, 13, "e", "c_office", w_, off=7)
            room(L, 14, 1, 24, 13, "s", "c_records", w_, off=19)
            room(L, 24, 1, 34, 13, "s", "c_dispatch", w_, off=29)
            room(L, 34, 1, 46, 13, "w", "c_armory", w_, off=7, dk="mdoor_l")
            room(L, 1, 13, 14, 19, "e", "c_interrogation", w_, off=16)
            room(L, 1, 19, 14, 25, "e", "c_interrogation", w_, off=22)
            room(L, 14, 13, 34, 25, "s", "c_bullpen", w_, off=24)
            room(L, 34, 13, 46, 25, "w", "c_evidence", w_, off=19, dk="ldoor")
            room(L, 1, 25, 14, 37, "e", "c_cells", w_, off=31, dk="mdoor")
            room(L, 1, 37, 14, 46, "e", "c_lockers", w_, off=41)
            room(L, 34, 25, 46, 37, "w", "c_gym", w_, off=31)
            room(L, 34, 37, 46, 46, "w", "c_garage", w_, off=41)
            L.door("wdoor", 14, 7)
            L.hline(39, 40, 46, "shutter_c")
            L.hline(23, 24, 46, "door_c")
            # open lobby x15..33, y26..45 : front desk, benches, detector
            L.fill(15, 26, 33, 45, "marble")
            for u in range(19, 30): L.f_("reception", u, 38)
            for u in range(16, 21): L.f_("bench_waiting", u, 42)
            for u in range(27, 32): L.f_("bench_waiting", u, 42)
            L.f_("console", 20, 37); L.f_("console", 28, 37); L.f_("beacon", 23, 44); L.f_("beacon", 24, 44)
            L.f_("vending", 33, 30); L.f_("holo_ad", 25, 30); L.f_("lightbox", 16, 36); L.f_("fern", 16, 44); L.f_("fern", 33, 44)
            L.sign("neon_cyan", 20, 47) if False else None
            L.sign("neon_cyan", 21, L.H - 1); L.sign("neon_cyan", 26, L.H - 1)
            L.windows(6)
            L.core(15, 26, ("s", 2))
        elif z == 1:
            room(L, 1, 1, 14, 13, "e", "c_office", w_, off=7)
            room(L, 14, 1, 24, 13, "s", "c_briefing", w_, off=19)
            room(L, 24, 1, 34, 13, "s", "c_dispatch", w_, off=29)
            room(L, 34, 1, 46, 13, "s", "f_qc", w_, off=40)
            room(L, 1, 13, 14, 25, "e", "c_bullpen", w_, off=19)
            room(L, 14, 13, 34, 25, "s", "c_briefing", w_, off=24)
            room(L, 34, 13, 46, 25, "w", "c_records", w_, off=19)
            room(L, 1, 25, 14, 37, "e", "c_lockers", w_, off=31)
            room(L, 34, 25, 46, 37, "w", "f_canteen", w_, off=31)
            room(L, 1, 37, 14, 46, "e", "c_gym", w_, off=41)
            room(L, 34, 37, 46, 46, "w", "w_serverhall", w_, off=41)
            L.fill(15, 26, 33, 45, "carpet_grey")
            for v in (30, 34, 38, 42): L.f_("bench_waiting", 20, v); L.f_("bench_waiting", 28, v)
            L.f_("holo_ad", 24, 36); L.f_("fern", 16, 44); L.f_("fern", 33, 44)
            L.windows(6); L.put("window", 23, 46); L.put("window", 24, 46)
            L.core(15, 26, ("s", 2))
        else:
            # dormitory + cots + roof access
            styles = ["dorm", "dorm", "capsule", "dorm"]
            i = 0
            for (x0, y0, x1, y1, side) in ((1, 1, 14, 13, "e"), (14, 1, 24, 13, "s"), (24, 1, 34, 13, "s"), (34, 1, 46, 13, "w"),
                                           (1, 13, 14, 25, "e"), (34, 13, 46, 25, "w"), (1, 25, 14, 37, "e"), (34, 25, 46, 37, "w"),
                                           (1, 37, 14, 46, "e"), (34, 37, 46, 46, "w")):
                if side in "sn": flat(L, x0, y0, x1, y1, side, styles[i % 4], w_)
                else: flat(L, x0, y0, x1, y1, side, styles[i % 4], w_)
                i += 1
            room(L, 14, 13, 34, 25, "s", "c_gym", w_, off=24)
            L.fill(15, 26, 33, 45, "carpet_grey")
            for v in (30, 36, 42): L.f_("sofa", 20, v); L.f_("table_low", 22, v); L.f_("armchair", 26, v)
            L.windows(6); L.put("window", 23, 46); L.put("window", 24, 46)
            L.core(15, 26, ("s", 2))
    def roof_police(L):
        roof_level(L, (15, 26))
        L.fill(17, 4, 30, 17, "hazard")
        for (x, y) in ((17, 4), (30, 4), (17, 17), (30, 17)): L.f.append(("beacon", x, y)); L.occ.add((x, y))
    BUILD_RS["trl_mt13"] = roof_police

    # ------------------------------------------------------------------- mt14 implant fab
    @bld("mt14", "cyberware fabrication plant", 2, 2, 3, "F", "light_cyan", "wall_clean", 300, min_city=3, kind="factory")
    def mt14(L):
        z = L.z; wc = "wall_clean"
        L.shell(wc, "floor_clean" if z else "hazard")
        if z == 0:
            room(L, 1, 1, 17, 16, "s", "f_stores", wc, off=9)
            room(L, 31, 1, 46, 16, "s", "f_stores", wc, off=38)
            L.fill(18, 2, 30, 15, "checker")
            L.door("door_c", 27, 1); L.f_("reception", 26, 7); L.f_("reception", 27, 7); L.f_("beacon", 28, 3)
            room(L, 1, 16, 46, 31, "n", "f_cleanline", wc, off=24, dk="door_c")
            room(L, 1, 31, 46, 46, "n", "f_receiving", wc, off=12, dk="door_c")
            L.door("door_c", 36, 31)
            L.hline(8, 9, 46, "shutter_c"); L.hline(38, 39, 46, "shutter_c")
            L.sign("neon_cyan", 27, 0); L.sign("neon_cyan", 20, 0)
            L.core(19, 2, ("s", 2), wall=wc)
        elif z == 1:
            room(L, 1, 1, 17, 16, "s", "f_qc", wc, off=9)
            room(L, 31, 1, 46, 16, "s", "f_qc", wc, off=38)
            L.fill(18, 2, 30, 15, "floor_clean")
            room(L, 1, 16, 46, 31, "n", "f_cleanline", wc, off=24, dk="door_c")
            room(L, 1, 31, 46, 46, "n", "f_packing", wc, off=12, dk="door_c")
            L.door("door_c", 36, 31)
            L.core(19, 2, ("s", 2), wall=wc)
        else:
            room(L, 1, 1, 17, 16, "s", "f_office", wc, off=9)
            room(L, 31, 1, 46, 16, "s", "f_canteen", wc, off=38)
            L.fill(18, 2, 30, 15, "carpet_teal")
            room(L, 1, 16, 46, 31, "n", "f_lab", wc, off=24, dk="door_c")
            room(L, 1, 31, 23, 46, "n", "w_serverhall", wc, off=12, dk="door_c")
            room(L, 23, 31, 46, 46, "n", "f_lab", wc, off=36, dk="door_c")
            L.core(19, 2, ("s", 2), wall=wc)
        L.windows(7)
    def roof_fab(L):
        roof_level(L, (19, 2), extra=("ac_unit",) * 6)
        for (x, y) in ((6, 20), (6, 26), (40, 20), (40, 26)): L.f_("beacon", x, y)
    BUILD_RS["trl_mt14"] = roof_fab

    # ------------------------------------------------------------------- mt15 bulk fab
    @bld("mt15", "polymer and hardware works", 2, 1, 3, "F", "brown", "wall_rust", 300, min_city=3, kind="factory")
    def mt15(L):
        z = L.z; wr = "wall_rust"
        L.shell(wr, "epoxy")
        stk = {0: ("c_office", "f_stores", "f_stores", "f_canteen"), 1: ("c_office", "f_stores", "f_stores", "f_canteen"),
               2: ("c_office", "f_office", "f_stores", "f_canteen")}[z]
        room(L, 1, 1, 10, 10, "s", stk[0], wr, off=5)
        room(L, 10, 1, 19, 10, "s", stk[1], wr, off=14)
        room(L, 28, 1, 37, 10, "s", stk[2], wr, off=32)
        room(L, 37, 1, 46, 10, "s", stk[3], wr, off=41)
        L.fill(20, 6, 27, 10, "checker" if z == 0 else "carpet_grey")
        big = {0: "f_machine", 1: "f_polymer", 2: "f_stamping"}[z]
        room(L, 1, 10, 46, 23, "n", big, wr, off=23, dk="door_c")
        L.door("door_c", 14, 10) if False else None
        L.door("wdoor", 5, 10); L.door("wdoor", 14, 10); L.door("wdoor", 32, 10); L.door("wdoor", 41, 10)
        L.door("door_c", 23, 10); L.door("door_c", 24, 10)
        if z == 0:
            L.hline(12, 13, 22, "shutter_c"); L.hline(34, 35, 22, "shutter_c")
            L.door("door_c", 27, 1); L.f_("beacon", 25, 3)
            L.sign("neon_amber", 24, 0)
        L.windows(6)
        L.core(21, 2, ("s", 2), wall=wr)
    def roof_works(L):
        roof_level(L, (21, 2), extra=("ac_unit",) * 3)
        for x in (6, 14, 34, 42): L.f_("pipes", x, 12); L.f_("water_tank", x, 16)
    BUILD_RS["trl_mt15"] = roof_works

    G["ROOF_FNS"] = BUILD_RS
