#!/usr/bin/env python3
"""The second gun set: 50 original guns from seven makers (Milestone 22).
usage: gen_gunset.py <mod dir> -> <mod>/gunset.json
Each gun borrows a stock base gun's mechanics (so ammo and magazines stay inside the existing ~20 ammo types) and gets its own
name, maker, weight and a small stat shift for its class.  Makers (the four-country rule: Russia, China, Japan, USA):
  Hoshikawa Arms (JP)   Sakurada Precision (JP)   Volkov Works (RU)   Zarya Combine (RU)
  Granite Arms (US)     Longhai Ordnance (CN)     Feng-Xu Arms (CN)
All names and makers are working placeholders.
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
MOD = sys.argv[1]

MAKERS = {"H": "Hoshikawa Arms", "S": "Sakurada Precision", "V": "Volkov Works", "Z": "Zarya Combine",
          "G": "Granite Arms", "L": "Longhai Ordnance", "F": "Feng-Xu Arms"}
# code, name, maker, base gun, class, description, weight, relative stat shift, price
GUNS = [
    # submachine guns and machine pistols
    ("hx9",   "HX-9 Fuji",           "H", "colt_ro635",           "SMG",      "A smooth, balanced 9mm submachine gun carried by city security.", "2600 g", {"dispersion": -15}, 2600),
    ("sm9",   "SM-9 Kagero",         "S", "TDI",                  "SMG",      "A vertical-magazine 9mm SMG with almost no felt recoil.", "2300 g", {"dispersion": -25}, 3400),
    ("vs45",  "VS-45 Buran",         "V", "greasegun",            "SMG",      "A crude, cheap .45 submachine gun that never seems to jam.", "3400 g", {"dispersion": 10}, 900),
    ("zp19",  "ZP-19 Vikhr",         "Z", "mac_10",               "SMG",      "A short, loud, fast-firing SMG for room fights.", "2000 g", {"dispersion": 25}, 1200),
    ("gk7",   "GK-7 Grizzly",        "G", "tommygun",             "SMG",      "A drum-fed .45 submachine gun with a heavy, steady hit.", "4300 g", {}, 2800),
    ("ls5",   "LS-5 Panda",          "L", "calico",               "SMG",      "A high-capacity helical-magazine carbine, quiet and compact.", "2300 g", {}, 2200),
    ("fs9",   "FS-9 Needle",         "F", "mac_11",               "SMG",      "A tiny machine pistol that fits under a coat.", "1300 g", {"dispersion": 30}, 1500),
    # pistols and revolvers
    ("sp45",  "SP-45 Hayabusa",      "S", "m1911_10",             "Pistol",   "A slim target-grade .45 with a crisp trigger.", "1000 g", {"dispersion": -20}, 2400),
    ("zp9",   "ZP-9 Gnezdo",         "Z", "makarov",              "Pistol",   "A small, blunt 9mm pistol: ugly, reliable and everywhere in the slums.", "700 g", {}, 380),
    ("fp7",   "FP-7 Lotus",          "F", "ruger_57",             "Pistol",   "A slim 20-round pistol firing a small, fast, armor-piercing round.", "650 g", {}, 1700),
    ("hp40",  "HP-40 Sagi",          "H", "sw_610",               "Revolver", "A six-shot revolver in 10mm with a short, quick-pointing barrel.", "1000 g", {}, 1400),
    ("gp10",  "GP-10 Mustang",       "G", "modular_deagle",       "Pistol",   "A huge gas-operated hand cannon.  It is as loud as it looks.", "1900 g", {"loudness": 10}, 3000),
    ("lp22",  "LP-22 Sparrow",       "L", "sr22",                 "Pistol",   "A quiet little .22 target pistol that thieves like.", "500 g", {"loudness": -12}, 300),
    ("vr38",  "VR-38 Kolokol",       "V", "model_10_revolver",    "Revolver", "A plain six-shooter built to be dropped, kicked and fired again.", "900 g", {}, 450),
    ("sr44",  "SR-44 Okami",         "S", "colt_anaconda_6",      "Revolver", "A long-barrel .44 revolver for patient, accurate shots.", "1500 g", {"dispersion": -15}, 2100),
    ("gr500", "GR-500 Thunderhead",  "G", "sw_500",               "Revolver", "A five-shot .500 revolver: slow, heavy and devastating.", "2100 g", {"loudness": 8}, 2900),
    # rifles and carbines
    ("ha5",   "HA-5 Kaede",          "H", "modular_m4_carbine",   "Rifle",    "A short, light carbine for patrols in corridors.", "2900 g", {}, 3000),
    ("sa14",  "SA-14 Zuiun",         "S", "modular_m16a4",        "Rifle",    "A burst-fire rifle with a long barrel and fine sights.", "3400 g", {"dispersion": -15}, 3500),
    ("vk74",  "VK-74 Granit",        "V", "ak74_semi",            "Rifle",    "A mid-weight semi-automatic rifle, tough and honest.", "3300 g", {}, 1400),
    ("zk15",  "ZK-15 Taiga",         "Z", "kord",                 "Rifle",    "A modernised AK-pattern rifle with a short tactical barrel.", "3500 g", {}, 2100),
    ("ga10",  "GA-10 Ironwood",      "G", "ar10",                 "Rifle",    "A full-power battle rifle with a steel barrel.", "4200 g", {}, 3300),
    ("lk95",  "LK-95 Jade",          "L", "rdb_223",              "Rifle",    "A light bullpup rifle with an ambidextrous receiver.", "3200 g", {}, 2500),
    ("fk9",   "FK-9 Lantern",        "F", "rfb_308",              "Rifle",    "A long-range bullpup rifle with a folding stock.", "3800 g", {}, 3200),
    ("gm14",  "GM-14 Patriot",       "G", "m1a",                  "Rifle",    "A blocky, accurate battle rifle that has seen three generations.", "4500 g", {}, 3000),
    ("vs44",  "VS-44 Kholod",        "V", "sks",                  "Rifle",    "A simple, long semi-automatic carbine with a fixed magazine.", "3800 g", {}, 700),
    ("lc30",  "LC-30 Dragonfly",     "L", "m1carbine",            "Rifle",    "A light carbine with a thin stock, easy to carry all day.", "2400 g", {}, 900),
    # shotguns
    ("hs10",  "HS-10 Raiden",        "H", "mossberg_930",         "Shotgun",  "A semi-automatic shotgun with a quick follow-up shot.", "3600 g", {}, 1400),
    ("zs20",  "ZS-20 Kabanchik",     "Z", "saiga_12",             "Shotgun",  "A boxy semi-automatic with a big detachable magazine.", "3800 g", {}, 1100),
    ("gs12",  "GS-12 Warden",        "G", "remington_870_express","Shotgun",  "A riot shotgun with a long magazine tube.", "3500 g", {}, 1100),
    ("ls12",  "LS-12 Pagoda",        "L", "ksg",                  "Shotgun",  "A compact twin-tube pump that holds a lot of shells.", "3100 g", {}, 1700),
    ("ss12",  "SS-12 Tsubame",       "S", "m26_mass",             "Shotgun",  "A clip-on and standalone door-breaker shotgun.", "2500 g", {}, 1600),
    ("fs410", "FS-410 Quail",        "F", "bond_410",             "Shotgun",  "A two-barrel pocket shotgun for close, ugly encounters.", "600 g", {}, 500),
    # precision rifles
    ("sd7",   "SD-7 Kiri",           "S", "m14ebr",               "Sniper",   "A scoped semi-automatic marksman rifle.", "5000 g", {"dispersion": -20}, 4800),
    ("vd62",  "VD-62 Ruchey",        "V", "mosin91_30",           "Sniper",   "An ancient bolt-action rifle with a modern scope: still deadly.", "4200 g", {}, 900),
    ("zd54",  "ZD-54 Filin",         "Z", "tac50",                "Sniper",   "A heavy bolt-action rifle that shoots a huge round very far.", "11000 g", {}, 9000),
    ("fd338", "FD-338 Heron",        "F", "mrad_smr",             "Sniper",   "A folding precision rifle with a thick, damped barrel.", "6100 g", {}, 7000),
    ("hd308", "HD-308 Tanuki",       "H", "remington_700_308",    "Sniper",   "A dependable bolt-action hunting rifle set up for the city.", "4300 g", {}, 1800),
    ("gd300", "GD-300 Longshot",     "G", "ruger_pr",             "Sniper",   "A chassis rifle with a hand-lapped barrel.", "5700 g", {}, 3800),
    ("ld10",  "LD-10 Pale Horse",    "L", "m2010",                "Sniper",   "A long-range magnum rifle with an integral suppressor.", "6000 g", {"loudness": -10}, 6400),
    # heavy weapons
    ("vm12",  "VM-12 Tundra",        "V", "m2browning",           "Heavy MG", "A tripod-mounted heavy machine gun.  It needs a strong back or a vehicle.", "38000 g", {}, 12000),
    ("zm74",  "ZM-74 Rokot",         "Z", "m60_semi",             "MG",       "A semi-auto belt-fed support gun for patient shooters.", "9500 g", {}, 4500),
    ("gm134", "GM-134 Hornet",       "G", "m134",                 "Heavy MG", "A six-barrel minigun on a harness.  Do not run out of ammunition.", "19000 g", {}, 28000),
    ("hm5",   "HM-5 Kujira",         "H", "m60",                  "MG",       "A heavy belt-fed machine gun with a quick-change barrel.", "9800 g", {}, 4800),
    ("lm7",   "LM-7 Tiger",          "L", "m1918",                "MG",       "An automatic battle rifle with a bipod, good for suppressing fire.", "8800 g", {}, 3600),
    # launchers
    ("gl40",  "GL-40 Pumpkin",       "G", "m79",                  "Launcher", "A break-open single-shot grenade launcher.", "2700 g", {}, 2400),
    ("zl40",  "ZL-40 Gvozd",         "Z", "m203",                 "Launcher", "A grenade launcher that clips under a rifle.", "1600 g", {}, 2000),
    ("fl80",  "FL-80 Cloud",         "F", "m202_flash",           "Launcher", "A four-tube rocket launcher that fills a street with fire.", "6500 g", {}, 8000),
    # energy weapons
    ("he3",   "HE-3 Kitsune",        "H", "laser_rifle",          "Laser",    "A silent laser pistol with a rotating heat sink.", "1000 g", {"range": -4}, 5500),
    ("se9",   "SE-9 Prism",          "S", "laser_rifle",          "Laser",    "A mid-range laser carbine with a precise cooling jacket.", "2600 g", {"range": 6}, 8000),
    ("fe7",   "FE-7 Needle Beam",    "F", "laser_rifle",          "Laser",    "A thin-beam laser rifle for long, patient shots.", "3400 g", {"range": 22}, 12000),
]
assert len(GUNS) == 50, len(GUNS)
assert len({g[0] for g in GUNS}) == 50

out = []
for code, name, mk, base, cls, text, weight, rel, price in GUNS:
    o = {"type": "ITEM", "subtypes": ["GUN"], "id": "trl_gun_" + code, "copy-from": base, "looks_like": base,
         "name": {"str": name}, "description": f"{text}  Made by {MAKERS[mk]}.", "weight": weight,
         "price": f"{price} USD", "price_postapoc": f"{max(price // 20, 10)} USD"}
    if rel:
        o["relative"] = dict(rel)
    out.append(o)

rare = {"zd54", "gm134", "vm12", "fe7", "se9", "fl80", "ld10", "fd338"}
out.append({"type": "item_group", "id": "trl_loot_guns", "subtype": "distribution",
            "extend": {"entries": [{"item": "trl_gun_" + g[0], "prob": 1 if g[0] in rare else 6} for g in GUNS]}})
json.dump(out, open(os.path.join(MOD, "gunset.json"), "w"), indent=1)
print(len(GUNS), "guns,", len(MAKERS), "makers")
