#!/usr/bin/env python3
"""Flowers native to eastern China, Japan and the Kamchatka region of Russia (design doc M16).  Display names and descriptions only:
every stock flower keeps its id, so recipes, harvests and mapgen are untouched.  usage: gen_flowers.py <mod dir> -> <mod>/flowers.json"""
import json, os, sys
MOD = sys.argv[1]
F = [  # (type, id, new name, description)
    ("furniture", "f_dandelion", "Japanese dandelion", "A bright yellow Taraxacum japonicum, the common dandelion of Japan's fields and roadsides."),
    ("furniture", "f_flower_tulip", "peony", "A big, ruffled Chinese peony in pink and white, the flower of the Luoyang gardens."),
    ("furniture", "f_flower_spurge", "Amur adonis", "A shining yellow spring flower of Manchuria and Japan that blooms through the last of the snow."),
    ("furniture", "f_lily", "tiger lily", "An orange Lilium lancifolium with dark freckles, native to eastern China and Japan."),
    ("furniture", "f_sunflower", "fireweed", "A tall spike of magenta flowers, the first colour to return to burned ground across Kamchatka.  Its seeds are good food."),
    ("furniture", "f_bluebell", "Japanese bellflower", "A star-shaped blue-violet Platycodon grandiflorus, long grown in China and Japan."),
    ("furniture", "f_mutpoppy", "mutated Kamchatka poppy", "A yellow arctic poppy of the Kamchatka tundra, changed into something stranger."),
    ("terrain", "t_shrub_rose", "Japanese rose bush", "A fat bush of crimson Rosa rugosa, the beach rose of Japan and the Russian Far East.  Watch out for its thorns."),
    ("terrain", "t_shrub_lilac", "Manchurian lilac bush", "A wide bush of pale pinkish-purple Syringa, native to Manchuria and northern China."),
    ("ITEM", "sunflower", "fireweed", "The top of a fireweed stalk, with magenta petals and some seeds that have yet to be eaten by animals."),
    ("ITEM", "poppy_bud", "Kamchatka poppy bud", "A bud of the Kamchatka poppy.  Contains some substances commonly produced by a mutated poppy flower."),
]
out = []
for t, i, n, d in F:
    o = {"type": t, "id": i, "copy-from": i, "name": {"str": n}, "description": d}
    out.append(o)
out.append({"type": "ITEM", "id": "bouquet", "copy-from": "bouquet", "name": {"str_sp": "withered chrysanthemum bouquet"},
            "description": "A mixed bunch of chrysanthemums, peonies and bellflowers.  Unfortunately, they have all withered with time."})
json.dump(out, open(os.path.join(MOD, "flowers.json"), "w"), indent=1)
print("flowers renamed:", len(out))
