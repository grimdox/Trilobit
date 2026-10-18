#!/usr/bin/env python3
"""Trilobit's gun table: 50 guns from seven fictional makers, authored for Trilobit.

This is the only source of gun data.  tools/export_items.py turns it into records in data/items.json, and
tools/content/t64_guns.py draws each gun's icon from its id and class.  Nothing here is copied from any other game:
there are no base guns, no borrowed ids and no imported stats.

Makers (the four-country rule: Russia, China, Japan, USA; all working placeholders):
  H Hoshikawa Arms (JP)   S Sakurada Precision (JP)   V Volkov Works (RU)   Z Zarya Combine (RU)
  G Granite Arms (US)     L Longhai Ordnance (CN)     F Feng-Xu Arms (CN)

CLASS holds what a whole class shares: caliber, fire modes, natural range, max aim, aim loss, report, reload, pellets, mod slots, jam chance
and length.  Each gun then sets its own accuracy and magazine size (damage belongs to the bullet).  Edit a gun's row to change that gun.
"""

MAKERS = {"H": "Hoshikawa Arms", "S": "Sakurada Precision", "V": "Volkov Works", "Z": "Zarya Combine",
          "G": "Granite Arms", "L": "Longhai Ordnance", "F": "Feng-Xu Arms"}

# range: natural range [near, far] in tiles (each shot rolls a distance in the band and loses 1 point per tile you are away from it);
# max_aim: the most aim points a steady hand can bank; aim_loss: aim points lost per bullet fired without re-aiming; acc: a flat bonus or penalty, -2 to +2, to the 2d10 roll; cal: caliber; modes: [name, shots]; noise: report radius in tiles; reload: turns; pellets per shot; slots: mod slots; jam: percent per trigger pull; length_mm: overall length
CLASS = {
    "SMG":      {"range": [4, 9], "max_aim": 2, "cal": "9mm",  "modes": [["single", 1], ["burst", 3], ["auto", 6]], "aim_loss": 1.0, "noise": 16, "reload": 1, "pellets": 1,
                 "slots": ["optic", "muzzle", "mag", "under", "stock"], "jam": 1.0, "length_mm": 450},
    "Pistol":   {"range": [3, 7], "max_aim": 2, "cal": "9mm",  "modes": [["single", 1]], "aim_loss": 1.0, "noise": 14, "reload": 1, "pellets": 1,
                 "slots": ["optic", "muzzle", "mag", "under"], "jam": 0.6, "length_mm": 200},
    "Revolver": {"range": [3, 7], "max_aim": 2, "cal": ".357", "modes": [["single", 1]], "aim_loss": 1.0, "noise": 18, "reload": 3, "pellets": 1,
                 "slots": ["optic", "muzzle", "under"], "jam": 0.1, "length_mm": 220},
    "Rifle":    {"range": [10, 15], "max_aim": 3, "cal": "5.56", "modes": [["single", 1], ["burst", 3]], "aim_loss": 1.0, "noise": 20, "reload": 2, "pellets": 1,
                 "slots": ["optic", "muzzle", "barrel", "mag", "under", "stock"], "jam": 0.8, "length_mm": 900},
    "Shotgun":  {"range": [3, 7], "max_aim": 2,  "cal": "12ga", "modes": [["single", 1]], "aim_loss": 1.0, "noise": 22, "reload": 3, "pellets": 8,
                 "slots": ["optic", "barrel", "under", "stock"], "jam": 0.8, "length_mm": 950},
    "Sniper":   {"range": [20, 30], "max_aim": 5, "cal": ".338", "modes": [["single", 1]], "aim_loss": 1.0, "noise": 24, "reload": 2, "pellets": 1,
                 "slots": ["optic", "muzzle", "barrel", "under", "stock"], "jam": 0.5, "length_mm": 1100},
    "MG":       {"range": [9, 13], "max_aim": 2, "cal": "7.62", "modes": [["burst", 4], ["auto", 8]], "aim_loss": 1.0, "noise": 22, "reload": 4, "pellets": 1,
                 "slots": ["optic", "muzzle", "under", "stock"], "jam": 1.5, "length_mm": 1000},
    "Heavy MG": {"range": [12, 18], "max_aim": 2, "cal": "12.7", "modes": [["burst", 5], ["auto", 10]], "aim_loss": 1.0, "noise": 26, "reload": 5, "pellets": 1,
                 "slots": ["optic", "muzzle"], "jam": 1.5, "length_mm": 1300},
    "Launcher": {"range": [8, 14], "max_aim": 2, "cal": "40mm", "modes": [["single", 1]], "aim_loss": 1.0, "noise": 24, "reload": 2, "pellets": 1,
                 "slots": ["optic", "under"], "jam": 0.5, "length_mm": 800},
    "Laser":    {"range": [8, 13], "max_aim": 3, "cal": "cell", "modes": [["single", 1], ["burst", 2]], "aim_loss": 0.5, "noise": 8, "reload": 1, "pellets": 1,
                 "slots": ["optic", "under"], "jam": 0.0, "length_mm": 700},
}

# code, name, maker, class, weight g, price (yen), gun accuracy, a flat -2..+2 on the shot roll (was a 53-74 percentage: one point per 5 away from 65), magazine, rare (scarce in loot), description
# Guns carry no damage of their own: damage lives on the bullet (tools/export_items.py BULLETS).
GUNS = [
    # submachine guns and machine pistols (9mm)
    ("hx9",   "HX-9 Fuji",          "H", "SMG",       2600,  2600, -1, 29, False, "A smooth, balanced submachine gun issued to tower security."),
    ("sm9",   "SM-9 Kagero",        "S", "SMG",       2300,  3400, -1, 29, False, "A sleek SMG with a buffered bolt that barely climbs in a burst."),
    ("vs45",  "VS-45 Buran",        "V", "SMG",       3400,   900, 0, 25, False, "Stamped steel and a wire stock.  Cheap, crude, and it always fires."),
    ("zp19",  "ZP-19 Vikhr",        "Z", "SMG",       2000,  1200, -1, 27, False, "A short, loud bullet hose for clearing a room in one breath."),
    ("gk7",   "GK-7 Grizzly",       "G", "SMG",       4300,  2800, -1, 27, False, "A heavy SMG with a wooden fore-end.  It sits still when it fires."),
    ("ls5",   "LS-5 Panda",         "L", "SMG",       2300,  2200, 0, 23, False, "A compact carbine with a deep magazine, popular with couriers."),
    ("fs9",   "FS-9 Needle",        "F", "SMG",       1300,  1500, 0, 27, False, "A palm-sized machine pistol that hides under a jacket."),
    # pistols (9mm) and revolvers (.357)
    ("sp45",  "SP-45 Hayabusa",     "S", "Pistol",    1000,  2400, +1, 14, False, "A slim competition pistol with a crisp, light trigger."),
    ("zp9",   "ZP-9 Gnezdo",        "Z", "Pistol",      700,   380, +1, 10, False, "A small, blunt pistol: ugly, reliable and everywhere in the slums."),
    ("fp7",   "FP-7 Lotus",         "F", "Pistol",      650,  1700, +1, 12, False, "A polymer pistol with a long grip and a high-capacity magazine."),
    ("hp40",  "HP-40 Sagi",         "H", "Revolver",  1000,  1400, +1, 4, False, "A snub six-shot revolver that points itself."),
    ("gp10",  "GP-10 Mustang",      "G", "Pistol",    1900,  3000, +2, 12, False, "An oversized chrome pistol.  It is as loud as it looks."),
    ("lp22",  "LP-22 Sparrow",      "L", "Pistol",      500,   300, +1, 14, False, "A light, quiet target pistol that thieves like."),
    ("vr38",  "VR-38 Kolokol",      "V", "Revolver",    900,   450, +1, 4, False, "A plain six-shooter built to be dropped, kicked and fired again."),
    ("sr44",  "SR-44 Okami",        "S", "Revolver",  1500,  2100, +2, 7, False, "A long-barrelled revolver for patient, accurate shots."),
    ("gr500", "GR-500 Thunderhead", "G", "Revolver",  2100,  2900, +2, 4, False, "A massive revolver with a ported barrel: slow, heavy and brutal."),
    # rifles and carbines (5.56)
    ("ha5",   "HA-5 Kaede",         "H", "Rifle",     2900,  3000, +1, 28, False, "A short, light carbine for patrols in tower corridors."),
    ("sa14",  "SA-14 Zuiun",        "S", "Rifle",     3400,  3500, +1, 28, False, "A long-barrelled rifle with fine sights and a three-round burst."),
    ("vk74",  "VK-74 Granit",       "V", "Rifle",     3300,  1400, +2, 30, False, "A mid-weight rifle with a slab-sided receiver, tough and honest."),
    ("zk15",  "ZK-15 Taiga",        "Z", "Rifle",     3500,  2100, +2, 28, False, "A rail-covered assault rifle with a short tactical barrel."),
    ("ga10",  "GA-10 Ironwood",     "G", "Rifle",     4200,  3300, +1, 28, False, "A heavy battle rifle with a fluted steel barrel."),
    ("lk95",  "LK-95 Jade",         "L", "Rifle",     3200,  2500, +2, 30, False, "A light bullpup rifle with an ambidextrous receiver."),
    ("fk9",   "FK-9 Lantern",       "F", "Rifle",     3800,  3200, +2, 32, False, "A long bullpup rifle with a folding stock and a glowing optic rail."),
    ("gm14",  "GM-14 Patriot",      "G", "Rifle",     4500,  3000, +2, 30, False, "A blocky, accurate rifle that has served three generations of guards."),
    ("vs44",  "VS-44 Kholod",       "V", "Rifle",     3800,   700, +1, 28, False, "A long, simple carbine with a wooden stock and a fixed magazine."),
    ("lc30",  "LC-30 Dragonfly",    "L", "Rifle",     2400,   900, +2, 34, False, "A light carbine with a skeleton stock, easy to carry all day."),
    # shotguns (12 gauge)
    ("hs10",  "HS-10 Raiden",       "H", "Shotgun",   3600,  1400, +2, 8, False, "A self-loading shotgun with a quick follow-up shot."),
    ("zs20",  "ZS-20 Kabanchik",    "Z", "Shotgun",   3800,  1100, +2, 4, False, "A boxy shotgun fed from a big detachable box."),
    ("gs12",  "GS-12 Warden",       "G", "Shotgun",   3500,  1100, +2, 7, False, "A riot shotgun with a long tube and a pistol grip."),
    ("ls12",  "LS-12 Pagoda",       "L", "Shotgun",   3100,  1700, +2, 7, False, "A compact pump gun with two magazine tubes and a selector."),
    ("ss12",  "SS-12 Tsubame",      "S", "Shotgun",   2500,  1600, +2, 7, False, "A stubby breaching shotgun with a standoff muzzle for doors."),
    ("fs410", "FS-410 Quail",       "F", "Shotgun",     600,   500, +2, 5, False, "A pocket shotgun for close, ugly encounters."),
    # precision rifles (.338)
    ("sd7",   "SD-7 Kiri",          "S", "Sniper",    5000,  4800, +2, 6, False, "A scoped self-loading marksman rifle in a grey composite chassis."),
    ("vd62",  "VD-62 Ruchey",       "V", "Sniper",    4200,   900, +2, 6, False, "An old bolt-action rifle wearing a modern scope.  Still deadly."),
    ("zd54",  "ZD-54 Filin",        "Z", "Sniper",  11000,  9000, +2, 5, True ,  "A huge bolt-action rifle on a bipod.  It reaches across districts."),
    ("fd338", "FD-338 Heron",       "F", "Sniper",    6100,  7000, +2, 3, True ,  "A folding precision rifle with a thick, damped barrel."),
    ("hd308", "HD-308 Tanuki",      "H", "Sniper",    4300,  1800, +2, 6, False, "A dependable bolt-action hunting rifle set up for the city."),
    ("gd300", "GD-300 Longshot",    "G", "Sniper",    5700,  3800, +2, 7, False, "A chassis rifle with a hand-lapped barrel and an adjustable cheek."),
    ("ld10",  "LD-10 Pale Horse",   "L", "Sniper",    6000,  6400, +2, 6, True ,  "A long magnum rifle with a built-in suppressor."),
    # machine guns (7.62) and heavy machine guns (12.7)
    ("vm12",  "VM-12 Tundra",       "V", "Heavy MG", 38000, 12000, -2, 65, True ,  "A tripod heavy machine gun.  It needs a strong back or a vehicle."),
    ("zm74",  "ZM-74 Rokot",        "Z", "MG",        9500,  4500, -2, 46, False, "A belt-fed support gun for patient shooters."),
    ("gm134", "GM-134 Hornet",      "G", "Heavy MG", 19000, 28000, -2, 55, True ,  "A motor-driven rotary gun on a harness.  Do not run out of ammunition."),
    ("hm5",   "HM-5 Kujira",        "H", "MG",        9800,  4800, -1, 42, False, "A heavy belt-fed machine gun with a quick-change barrel."),
    ("lm7",   "LM-7 Tiger",         "L", "MG",        8800,  3600, -2, 54, False, "A long automatic rifle with a bipod, built for suppressing fire."),
    # launchers (40mm)
    ("gl40",  "GL-40 Pumpkin",      "G", "Launcher",  2700,  2400, +1, 1, False, "A fat break-open grenade launcher with a flip-up sight."),
    ("zl40",  "ZL-40 Gvozd",        "Z", "Launcher",  1600,  2000, 0, 1, False, "A short grenade launcher with a folding grip."),
    ("fl80",  "FL-80 Cloud",        "F", "Launcher",  6500,  8000, 0, 1, True ,  "A shoulder launcher that fills a street with fire."),
    # energy weapons (charge cells)
    ("he3",   "HE-3 Kitsune",       "H", "Laser",     1000,  5500, +2, 12, False, "A silent laser pistol with a rotating heat sink."),
    ("se9",   "SE-9 Prism",         "S", "Laser",     2600,  8000, +2, 13, True ,  "A mid-range laser carbine with a precise cooling jacket."),
    ("fe7",   "FE-7 Needle Beam",   "F", "Laser",     3400, 12000, +2, 12, True ,  "A thin-beam laser rifle for long, patient shots."),
]
assert len(GUNS) == 50, len(GUNS)
assert len({g[0] for g in GUNS}) == 50
assert all(g[2] in MAKERS and g[3] in CLASS for g in GUNS)


def records():
    """The guns as item records for data/items.json."""
    out = []
    for code, name, mk, cls, wt, price, acc, mag, rare, text in GUNS:
        c = CLASS[cls]
        gun = {"range": list(c["range"]), "acc": acc, "cal": c["cal"], "mag": mag, "modes": [list(m) for m in c["modes"]],
               "max_aim": c["max_aim"], "aim_loss": c["aim_loss"], "noise": c["noise"], "reload": c["reload"], "pellets": c["pellets"], "slots": list(c["slots"]), "jam": c["jam"]}
        out.append({"id": "trl_gun_" + code, "name": name, "desc": "%s  Made by %s." % (text, MAKERS[mk]), "weight_g": wt,
                    "volume_ml": wt // 2, "length_mm": c["length_mm"], "price": price, "tags": ["gun", cls.lower().replace(" ", "_")],
                    "maker": MAKERS[mk], "rare": rare, "gun": gun})
    return out
