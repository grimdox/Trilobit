#!/usr/bin/env python3
"""Trilobit's gun table: 50 guns from seven fictional makers, authored for Trilobit.

This is the only source of gun data.  tools/export_items.py turns it into records in data/items.json, and
tools/content/t64_guns.py draws each gun's icon from its id and class.  Nothing here is copied from any other game:
there are no base guns, no borrowed ids and no imported stats.

Makers (the four-country rule: Russia, China, Japan, USA; all working placeholders):
  H Hoshikawa Arms (JP)   S Sakurada Precision (JP)   V Volkov Works (RU)   Z Zarya Combine (RU)
  G Granite Arms (US)     L Longhai Ordnance (CN)     F Feng-Xu Arms (CN)

CLASS holds what a whole class shares: caliber, fire modes, recoil, report, reload, pellets, mod slots, jam chance, range and
length.  Each gun then sets its own accuracy, damage range and magazine size.  Edit a gun's row to change that gun.
"""

MAKERS = {"H": "Hoshikawa Arms", "S": "Sakurada Precision", "V": "Volkov Works", "Z": "Zarya Combine",
          "G": "Granite Arms", "L": "Longhai Ordnance", "F": "Feng-Xu Arms"}

# range: effective range in tiles; acc: base accuracy (percent); cal: caliber; modes: [name, shots]; recoil: lost accuracy per extra shot in a
# burst; noise: report radius in tiles; reload: turns; pellets per shot; slots: mod slots; jam: percent per trigger pull; length_mm: overall length
CLASS = {
    "SMG":      {"range": 12, "cal": "9mm",  "modes": [["single", 1], ["burst", 3], ["auto", 6]], "recoil": 4, "noise": 16, "reload": 1, "pellets": 1,
                 "slots": ["optic", "muzzle", "mag", "under", "stock"], "jam": 1.0, "length_mm": 450},
    "Pistol":   {"range": 10, "cal": "9mm",  "modes": [["single", 1]], "recoil": 3, "noise": 14, "reload": 1, "pellets": 1,
                 "slots": ["optic", "muzzle", "mag", "under"], "jam": 0.6, "length_mm": 200},
    "Revolver": {"range": 10, "cal": ".357", "modes": [["single", 1]], "recoil": 5, "noise": 18, "reload": 3, "pellets": 1,
                 "slots": ["optic", "muzzle", "under"], "jam": 0.1, "length_mm": 220},
    "Rifle":    {"range": 18, "cal": "5.56", "modes": [["single", 1], ["burst", 3]], "recoil": 4, "noise": 20, "reload": 2, "pellets": 1,
                 "slots": ["optic", "muzzle", "barrel", "mag", "under", "stock"], "jam": 0.8, "length_mm": 900},
    "Shotgun":  {"range": 6,  "cal": "12ga", "modes": [["single", 1]], "recoil": 6, "noise": 22, "reload": 3, "pellets": 8,
                 "slots": ["optic", "barrel", "under", "stock"], "jam": 0.8, "length_mm": 950},
    "Sniper":   {"range": 30, "cal": ".338", "modes": [["single", 1]], "recoil": 6, "noise": 24, "reload": 2, "pellets": 1,
                 "slots": ["optic", "muzzle", "barrel", "under", "stock"], "jam": 0.5, "length_mm": 1100},
    "MG":       {"range": 16, "cal": "7.62", "modes": [["burst", 4], ["auto", 8]], "recoil": 3, "noise": 22, "reload": 4, "pellets": 1,
                 "slots": ["optic", "muzzle", "under", "stock"], "jam": 1.5, "length_mm": 1000},
    "Heavy MG": {"range": 20, "cal": "12.7", "modes": [["burst", 5], ["auto", 10]], "recoil": 3, "noise": 26, "reload": 5, "pellets": 1,
                 "slots": ["optic", "muzzle"], "jam": 1.5, "length_mm": 1300},
    "Launcher": {"range": 14, "cal": "40mm", "modes": [["single", 1]], "recoil": 0, "noise": 24, "reload": 2, "pellets": 1,
                 "slots": ["optic", "under"], "jam": 0.5, "length_mm": 800},
    "Laser":    {"range": 15, "cal": "cell", "modes": [["single", 1], ["burst", 2]], "recoil": 1, "noise": 8, "reload": 1, "pellets": 1,
                 "slots": ["optic", "under"], "jam": 0.0, "length_mm": 700},
}

# code, name, maker, class, weight g, price (yen), accuracy %, damage [min, max], magazine, rare (scarce in loot), description
GUNS = [
    # submachine guns and machine pistols (9mm)
    ("hx9",   "HX-9 Fuji",          "H", "SMG",       2600,  2600, 59, [7, 11],  29, False, "A smooth, balanced submachine gun issued to tower security."),
    ("sm9",   "SM-9 Kagero",        "S", "SMG",       2300,  3400, 60, [8, 12],  29, False, "A sleek SMG with a buffered bolt that barely climbs in a burst."),
    ("vs45",  "VS-45 Buran",        "V", "SMG",       3400,   900, 66, [7, 11],  25, False, "Stamped steel and a wire stock.  Cheap, crude, and it always fires."),
    ("zp19",  "ZP-19 Vikhr",        "Z", "SMG",       2000,  1200, 58, [7, 11],  27, False, "A short, loud bullet hose for clearing a room in one breath."),
    ("gk7",   "GK-7 Grizzly",       "G", "SMG",       4300,  2800, 61, [8, 11],  27, False, "A heavy SMG with a wooden fore-end.  It sits still when it fires."),
    ("ls5",   "LS-5 Panda",         "L", "SMG",       2300,  2200, 63, [8, 12],  23, False, "A compact carbine with a deep magazine, popular with couriers."),
    ("fs9",   "FS-9 Needle",        "F", "SMG",       1300,  1500, 65, [6, 10],  27, False, "A palm-sized machine pistol that hides under a jacket."),
    # pistols (9mm) and revolvers (.357)
    ("sp45",  "SP-45 Hayabusa",     "S", "Pistol",    1000,  2400, 72, [11, 15],  14, False, "A slim competition pistol with a crisp, light trigger."),
    ("zp9",   "ZP-9 Gnezdo",        "Z", "Pistol",      700,   380, 72, [11, 15],  10, False, "A small, blunt pistol: ugly, reliable and everywhere in the slums."),
    ("fp7",   "FP-7 Lotus",         "F", "Pistol",      650,  1700, 71, [11, 17],  12, False, "A polymer pistol with a long grip and a high-capacity magazine."),
    ("hp40",  "HP-40 Sagi",         "H", "Revolver",  1000,  1400, 70, [13, 21],   4, False, "A snub six-shot revolver that points itself."),
    ("gp10",  "GP-10 Mustang",      "G", "Pistol",    1900,  3000, 74, [9, 16],  12, False, "An oversized chrome pistol.  It is as loud as it looks."),
    ("lp22",  "LP-22 Sparrow",      "L", "Pistol",      500,   300, 68, [11, 17],  14, False, "A light, quiet target pistol that thieves like."),
    ("vr38",  "VR-38 Kolokol",      "V", "Revolver",    900,   450, 70, [15, 23],   4, False, "A plain six-shooter built to be dropped, kicked and fired again."),
    ("sr44",  "SR-44 Okami",        "S", "Revolver",  1500,  2100, 76, [13, 23],   7, False, "A long-barrelled revolver for patient, accurate shots."),
    ("gr500", "GR-500 Thunderhead", "G", "Revolver",  2100,  2900, 76, [15, 23],   4, False, "A massive revolver with a ported barrel: slow, heavy and brutal."),
    # rifles and carbines (5.56)
    ("ha5",   "HA-5 Kaede",         "H", "Rifle",     2900,  3000, 71, [16, 24],  28, False, "A short, light carbine for patrols in tower corridors."),
    ("sa14",  "SA-14 Zuiun",        "S", "Rifle",     3400,  3500, 70, [16, 24],  28, False, "A long-barrelled rifle with fine sights and a three-round burst."),
    ("vk74",  "VK-74 Granit",       "V", "Rifle",     3300,  1400, 74, [16, 23],  30, False, "A mid-weight rifle with a slab-sided receiver, tough and honest."),
    ("zk15",  "ZK-15 Taiga",        "Z", "Rifle",     3500,  2100, 73, [17, 25],  28, False, "A rail-covered assault rifle with a short tactical barrel."),
    ("ga10",  "GA-10 Ironwood",     "G", "Rifle",     4200,  3300, 71, [16, 25],  28, False, "A heavy battle rifle with a fluted steel barrel."),
    ("lk95",  "LK-95 Jade",         "L", "Rifle",     3200,  2500, 76, [15, 23],  30, False, "A light bullpup rifle with an ambidextrous receiver."),
    ("fk9",   "FK-9 Lantern",       "F", "Rifle",     3800,  3200, 73, [17, 23],  32, False, "A long bullpup rifle with a folding stock and a glowing optic rail."),
    ("gm14",  "GM-14 Patriot",      "G", "Rifle",     4500,  3000, 75, [15, 25],  30, False, "A blocky, accurate rifle that has served three generations of guards."),
    ("vs44",  "VS-44 Kholod",       "V", "Rifle",     3800,   700, 71, [15, 25],  28, False, "A long, simple carbine with a wooden stock and a fixed magazine."),
    ("lc30",  "LC-30 Dragonfly",    "L", "Rifle",     2400,   900, 73, [16, 24],  34, False, "A light carbine with a skeleton stock, easy to carry all day."),
    # shotguns (12 gauge)
    ("hs10",  "HS-10 Raiden",       "H", "Shotgun",   3600,  1400, 80, [19, 34],   8, False, "A self-loading shotgun with a quick follow-up shot."),
    ("zs20",  "ZS-20 Kabanchik",    "Z", "Shotgun",   3800,  1100, 83, [20, 34],   4, False, "A boxy shotgun fed from a big detachable box."),
    ("gs12",  "GS-12 Warden",       "G", "Shotgun",   3500,  1100, 76, [21, 34],   7, False, "A riot shotgun with a long tube and a pistol grip."),
    ("ls12",  "LS-12 Pagoda",       "L", "Shotgun",   3100,  1700, 76, [19, 35],   7, False, "A compact pump gun with two magazine tubes and a selector."),
    ("ss12",  "SS-12 Tsubame",      "S", "Shotgun",   2500,  1600, 76, [20, 33],   7, False, "A stubby breaching shotgun with a standoff muzzle for doors."),
    ("fs410", "FS-410 Quail",       "F", "Shotgun",     600,   500, 81, [21, 34],   5, False, "A pocket shotgun for close, ugly encounters."),
    # precision rifles (.338)
    ("sd7",   "SD-7 Kiri",          "S", "Sniper",    5000,  4800, 82, [29, 47],   6, False, "A scoped self-loading marksman rifle in a grey composite chassis."),
    ("vd62",  "VD-62 Ruchey",       "V", "Sniper",    4200,   900, 81, [30, 47],   6, False, "An old bolt-action rifle wearing a modern scope.  Still deadly."),
    ("zd54",  "ZD-54 Filin",        "Z", "Sniper",  11000,  9000, 85, [31, 48],   5, True ,  "A huge bolt-action rifle on a bipod.  It reaches across districts."),
    ("fd338", "FD-338 Heron",       "F", "Sniper",    6100,  7000, 85, [30, 48],   3, True ,  "A folding precision rifle with a thick, damped barrel."),
    ("hd308", "HD-308 Tanuki",      "H", "Sniper",    4300,  1800, 85, [29, 48],   6, False, "A dependable bolt-action hunting rifle set up for the city."),
    ("gd300", "GD-300 Longshot",    "G", "Sniper",    5700,  3800, 82, [31, 49],   7, False, "A chassis rifle with a hand-lapped barrel and an adjustable cheek."),
    ("ld10",  "LD-10 Pale Horse",   "L", "Sniper",    6000,  6400, 85, [31, 49],   6, True ,  "A long magnum rifle with a built-in suppressor."),
    # machine guns (7.62) and heavy machine guns (12.7)
    ("vm12",  "VM-12 Tundra",       "V", "Heavy MG", 38000, 12000, 53, [16, 23],  65, True ,  "A tripod heavy machine gun.  It needs a strong back or a vehicle."),
    ("zm74",  "ZM-74 Rokot",        "Z", "MG",        9500,  4500, 53, [13, 18],  46, False, "A belt-fed support gun for patient shooters."),
    ("gm134", "GM-134 Hornet",      "G", "Heavy MG", 19000, 28000, 57, [15, 23],  55, True ,  "A motor-driven rotary gun on a harness.  Do not run out of ammunition."),
    ("hm5",   "HM-5 Kujira",        "H", "MG",        9800,  4800, 59, [13, 19],  42, False, "A heavy belt-fed machine gun with a quick-change barrel."),
    ("lm7",   "LM-7 Tiger",         "L", "MG",        8800,  3600, 54, [11, 17],  54, False, "A long automatic rifle with a bipod, built for suppressing fire."),
    # launchers (40mm)
    ("gl40",  "GL-40 Pumpkin",      "G", "Launcher",  2700,  2400, 68, [40, 70],   1, False, "A fat break-open grenade launcher with a flip-up sight."),
    ("zl40",  "ZL-40 Gvozd",        "Z", "Launcher",  1600,  2000, 64, [40, 70],   1, False, "A short grenade launcher with a folding grip."),
    ("fl80",  "FL-80 Cloud",        "F", "Launcher",  6500,  8000, 64, [39, 71],   1, True ,  "A shoulder launcher that fills a street with fire."),
    # energy weapons (charge cells)
    ("he3",   "HE-3 Kitsune",       "H", "Laser",     1000,  5500, 81, [15, 23],  12, False, "A silent laser pistol with a rotating heat sink."),
    ("se9",   "SE-9 Prism",         "S", "Laser",     2600,  8000, 74, [15, 23],  13, True ,  "A mid-range laser carbine with a precise cooling jacket."),
    ("fe7",   "FE-7 Needle Beam",   "F", "Laser",     3400, 12000, 81, [13, 22],  12, True ,  "A thin-beam laser rifle for long, patient shots."),
]
assert len(GUNS) == 50, len(GUNS)
assert len({g[0] for g in GUNS}) == 50
assert all(g[2] in MAKERS and g[3] in CLASS for g in GUNS)


def records():
    """The guns as item records for data/items.json."""
    out = []
    for code, name, mk, cls, wt, price, acc, dmg, mag, rare, text in GUNS:
        c = CLASS[cls]
        gun = {"dmg": list(dmg), "range": c["range"], "acc": acc, "cal": c["cal"], "mag": mag, "modes": [list(m) for m in c["modes"]],
               "recoil": c["recoil"], "noise": c["noise"], "reload": c["reload"], "pellets": c["pellets"], "slots": list(c["slots"]), "jam": c["jam"]}
        out.append({"id": "trl_gun_" + code, "name": name, "desc": "%s  Made by %s." % (text, MAKERS[mk]), "weight_g": wt,
                    "volume_ml": wt // 2, "length_mm": c["length_mm"], "price": price, "tags": ["gun", cls.lower().replace(" ", "_")],
                    "maker": MAKERS[mk], "rare": rare, "gun": gun})
    return out
