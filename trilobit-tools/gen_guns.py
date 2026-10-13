#!/usr/bin/env python3
"""Gun origins and removal list (Milestone 22, section I1).
usage: gen_guns.py <mod dir> <stock cdda dir>
Writes <mod>/gun_origins.csv (every stock gun: maker, country, keep/remove) and <mod>/guns_blacklist.json.
Rule: keep a gun only if its original maker is in Russia, China, Japan or America.  Unknown or mixed -> removed.
Primitive, improvised and fantasy guns are removed too (section J).  Bows and modern crossbows are kept (section I5).
"""
import json, glob, csv, os, sys

KEEP = {  # id: (maker, country)
 # --- America
 "sw_610": ("Smith & Wesson", "US"), "m1911_10": ("Colt", "US"), "marlin_9a": ("Marlin", "US"),
 "ruger_1022": ("Ruger", "US"), "ruger_1022_auto": ("Ruger", "US"), "ruger_lcr_22": ("Ruger", "US"),
 "ruger_mk4": ("Ruger", "US"), "rough_rider_pistol": ("Heritage", "US"), "rough_rider_pistol_9": ("Heritage", "US"),
 "1911_22": ("Colt design", "US"), "henry_golden_boy": ("Henry", "US"), "marlin60": ("Marlin", "US"),
 "sw617": ("Smith & Wesson", "US"), "sr22": ("Ruger", "US"), "savage_rascal": ("Savage", "US"),
 "mp_15_22": ("Smith & Wesson", "US"), "modular_ar15": ("Colt/ArmaLite", "US"), "modular_ar_pistol": ("Colt/ArmaLite", "US"),
 "modular_m4_carbine": ("Colt", "US"), "modular_m16a4": ("Colt", "US"), "modular_m16_auto_rifle": ("Colt", "US"),
 "ruger_mini": ("Ruger", "US"), "mdrx": ("Desert Tech", "US"), "rdb_223": ("Kel-Tec", "US"), "mp_15": ("Smith & Wesson", "US"),
 "remington700_270": ("Remington", "US"), "m2010": ("Remington", "US"), "weatherby_5": ("Weatherby", "US"),
 "win70": ("Winchester", "US"), "ruger_pr": ("Ruger", "US"), "browning_blr": ("Browning", "US"), "garand": ("Springfield Armory", "US"),
 "m1903": ("Springfield Armory", "US"), "m1918": ("Colt/Browning", "US"), "remington_700": ("Remington", "US"),
 "ruger_m77": ("Ruger", "US"), "m134": ("General Electric", "US"), "m14ebr": ("Springfield Armory", "US"), "m1a": ("Springfield Armory", "US"),
 "m60": ("Saco Defense", "US"), "m60_semi": ("Saco Defense", "US"), "savage_111f": ("Savage", "US"), "M24": ("Remington", "US"),
 "ar10": ("ArmaLite", "US"), "rfb_308": ("Kel-Tec", "US"), "remington_700_308": ("Remington", "US"),
 "m1carbine": ("Winchester/Inland", "US"), "m2carbine": ("Winchester/Inland", "US"), "kp32": ("Kel-Tec", "US"),
 "lws32": ("Seecamp", "US"), "savage112": ("Savage", "US"), "mrad_smr": ("Barrett", "US"), "colt_navy": ("Colt", "US"),
 "model_10_revolver": ("Smith & Wesson", "US"), "ruger_lcr_38": ("Ruger", "US"), "colt_python": ("Colt", "US"),
 "sw_619": ("Smith & Wesson", "US"), "sw642": ("Smith & Wesson", "US"), "mac_11": ("Ingram/RPB", "US"), "rugerlcp": ("Ruger", "US"),
 "hptcf380": ("Hi-Point", "US"), "hpt3895": ("Hi-Point", "US"), "swbodyguard": ("Smith & Wesson", "US"),
 "m1911a1_38super": ("Colt", "US"), "hptjcp": ("Hi-Point", "US"), "m79": ("Springfield Armory", "US"), "pseudo_m203": ("Colt/AAI", "US"),
 "mark19": ("Saco Defense", "US"), "shotgun_410": ("Winchester", "US"), "modular_deagle": ("Magnum Research", "US"),
 "henry_big_boy": ("Henry", "US"), "sw629": ("Smith & Wesson", "US"), "colt_anaconda_8": ("Colt", "US"), "colt_anaconda_6": ("Colt", "US"),
 "colt_anaconda_4": ("Colt", "US"), "colt_army": ("Colt", "US"), "TDI": ("Kriss", "US"), "m1911": ("Colt", "US"), "mac_10": ("Ingram/RPB", "US"),
 "tommygun": ("Auto-Ordnance", "US"), "hptjhp": ("Hi-Point", "US"), "greasegun": ("Guide Lamp", "US"), "ruger_arr": ("Ruger", "US"),
 "1895sbl": ("Marlin", "US"), "bfr": ("Magnum Research", "US"), "sharps": ("Sharps", "US"), "win70_458": ("Winchester", "US"),
 "bond_410": ("Bond Arms", "US"), "colt_saa": ("Colt", "US"), "460_xvr": ("Smith & Wesson", "US"), "m107a1": ("Barrett", "US"),
 "m2browning": ("Colt/Browning", "US"), "tac50": ("McMillan", "US"), "bfg50": ("Barrett", "US"), "sw_500": ("Smith & Wesson", "US"),
 "mk47": ("Kalashnikov USA", "US"), "ruger_57": ("Ruger", "US"), "m202_flash": ("Northrop", "US"), "calico": ("Calico", "US"),
 "ksub2000": ("Kel-Tec", "US"), "hptc9": ("Hi-Point", "US"), "colt_ro635": ("Colt", "US"), "rugerpcc": ("Ruger", "US"),
 "tec9": ("Intratec", "US"), "atgm_launcher": ("Hughes", "US"), "flamethrower": ("US Army", "US"), "ksg": ("Kel-Tec", "US"),
 "mossberg_500": ("Mossberg", "US"), "mossberg_590": ("Mossberg", "US"), "mossberg_590m": ("Mossberg", "US"), "mossberg_930": ("Mossberg", "US"),
 "remington_870": ("Remington", "US"), "ithaca37": ("Ithaca", "US"), "remington_1100": ("Remington", "US"),
 "remington_870_breacher": ("Remington", "US"), "remington_870_express": ("Remington", "US"), "winchester_1897": ("Winchester", "US"),
 "srm_1216": ("SRM Arms", "US"), "m26_mass_standalone": ("C-More", "US"), "m203": ("Colt/AAI", "US"), "masterkey": ("Ithaca", "US"),
 "m26_mass": ("C-More", "US"), "LAW": ("Hesse Eastern", "US"),
 # --- Russia (and USSR)
 "ak74_semi": ("Izhmash", "RU"), "kord": ("Degtyarev Plant", "RU"), "ak47": ("Izhmash", "RU"), "sks": ("Tula", "RU"),
 "aksemi": ("Izhmash", "RU"), "mosin44": ("Tula/Izhevsk", "RU"), "mosin91_30": ("Tula/Izhevsk", "RU"), "tokarev": ("Tula", "RU"),
 "makarov": ("Izhevsk", "RU"), "saiga_12": ("Izhmash", "RU"),
 # --- Japan
 "type99": ("Nagoya Arsenal", "JP"), "type99_sniper": ("Nagoya Arsenal", "JP"),
 # --- mech weapons (not guns players buy; mechs need them)
 "gatling_mech_laser": ("mech weapon", "n/a"), "gatling_mech_laser_single": ("mech weapon", "n/a"),
 "recon_mech_laser": ("mech weapon", "n/a"), "recon_mech_laser_single": ("mech weapon", "n/a"),
 # --- bionic and mutation attacks are not guns; kept
 "bio_shotgun_gun": ("bionic", "n/a"), "bio_emp_gun": ("bionic", "n/a"), "bio_laser_gun": ("bionic", "n/a"),
 "bio_lightning": ("bionic", "n/a"), "mut_quills": ("mutation", "n/a"), "mut_longpull": ("mutation", "n/a"),
 # --- bows and modern crossbows (section I5)
 "shortbow": ("bow", "n/a"), "compbow": ("bow", "n/a"), "compbow_high": ("bow", "n/a"), "compbow_low": ("bow", "n/a"),
 "compositebow": ("bow", "n/a"), "reflexbow": ("bow", "n/a"), "recurbow": ("bow", "n/a"), "takedown_recurbow": ("bow", "n/a"),
 "takedown_recurbow_folded": ("bow", "n/a"), "longbow": ("bow", "n/a"), "reflexrecurvebow": ("bow", "n/a"),
 "compcrossbow": ("crossbow", "n/a"), "hand_crossbow": ("crossbow", "n/a"), "compositecrossbow": ("crossbow", "n/a"),
 "rep_crossbow": ("crossbow", "n/a"),
}
REASON = {"gun/artisan_guns": "homemade", "gun/flintlock": "primitive", "gun/blunderbuss": "primitive", "ranged/slings": "primitive",
          "ranged/atlatl": "primitive", "ranged/ballista": "primitive", "ranged/spearguns": "improvised", "gun/exodii": "fantasy",
          "gun/robofac_gun": "fantasy", "ranged/yrax_guns": "fantasy", "gun/ups": "fictional laser (replaced by section I originals)"}


def main(mod, stock):
    guns = {}
    for f in glob.glob(os.path.join(stock, "data/json/items/**/*.json"), recursive=True):
        try:
            d = json.load(open(f))
        except Exception:
            continue
        if not isinstance(d, list):
            continue
        for o in d:
            if isinstance(o, dict) and (o.get("type") == "GUN" or "GUN" in (o.get("subtypes") or [])) and o.get("id") and not o.get("abstract"):
                n = o.get("name")
                n = (n.get("str") or n.get("str_sp") or "") if isinstance(n, dict) else (n or "")
                guns[o["id"]] = (n, f.split("items/")[1].replace(".json", ""))
    rows, remove = [], []
    for gid, (name, src) in sorted(guns.items()):
        if gid in KEEP:
            mk, cn = KEEP[gid]
            rows.append((gid, name, mk, cn, "keep", ""))
        else:
            why = REASON.get(src, "maker not in RU/CN/JP/US, or unknown")
            rows.append((gid, name, "", "", "remove", why))
            remove.append(gid)
    with open(os.path.join(mod, "gun_origins.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["id", "name", "maker", "country", "decision", "reason"])
        w.writerows(rows)
    json.dump([{"type": "ITEM_BLACKLIST", "whitelist": False, "items": remove}], open(os.path.join(mod, "guns_blacklist.json"), "w"), indent=1)
    missing = [k for k in KEEP if k not in guns]
    print(len(guns), "stock guns;", len(KEEP) - len(missing), "kept;", len(remove), "removed; keep ids not in stock:", missing)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
