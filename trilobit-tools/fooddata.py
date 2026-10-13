#!/usr/bin/env python3
"""Trilobit food: 50 Japanese, Russian and Chinese items, plus cyber rations.  Pure data, imported by gen_food and gen_shops.
Prices are yen (10 to 200).  tier = quality class: 0 cheap, 1 ordinary, 2 premium."""

# (id, name, culture, kind, kcal, quench, fun, weight_g, volume_ml, price, tier, spoils, hot, description, color)
F = [
 # ---- Japanese (17)
 ("onigiri", "onigiri", "J", "FOOD", 190, 0, 3, 110, 200, 12, 0, "2 days", False, "A triangle of pressed rice around a salted plum, wrapped in a strip of seaweed.", "white"),
 ("miso_soup", "miso soup", "J", "FOOD", 60, 22, 3, 250, 250, 15, 0, "1 day", True, "A cup of miso broth with tofu cubes and green onion.", "brown"),
 ("cup_ramen", "tonkotsu cup ramen", "J", "FOOD", 420, 6, 5, 90, 450, 20, 0, "360 days", True, "Instant noodles in a pork-bone broth.  Add hot water.", "yellow"),
 ("tamagoyaki", "tamagoyaki", "J", "FOOD", 150, 0, 6, 100, 150, 25, 1, "2 days", False, "A rolled omelette, slightly sweet, cut in thick slices.", "yellow"),
 ("yakitori", "yakitori skewers", "J", "FOOD", 280, 0, 7, 140, 200, 35, 1, "1 day", True, "Four skewers of grilled chicken glazed in a sweet soy tare.", "brown"),
 ("gyoza", "gyoza tray", "J", "FOOD", 320, 0, 7, 190, 300, 40, 1, "1 day", True, "Six pan-fried pork and cabbage dumplings with a dipping sauce.", "light_gray"),
 ("okonomiyaki", "okonomiyaki", "J", "FOOD", 450, 0, 8, 260, 400, 50, 1, "1 day", True, "A thick cabbage pancake with pork, brushed with sauce and mayonnaise.", "brown"),
 ("takoyaki", "takoyaki", "J", "FOOD", 330, 0, 8, 180, 250, 45, 1, "1 day", True, "Eight crisp batter balls with a piece of octopus in each.", "brown"),
 ("katsu_bento", "katsu curry bento", "J", "FOOD", 780, 5, 9, 450, 700, 70, 1, "2 days", False, "A breaded pork cutlet over rice with a pot of thick curry sauce.", "brown"),
 ("unagi_don", "unagi rice bowl", "J", "FOOD", 650, 0, 12, 330, 450, 150, 2, "1 day", False, "Grilled freshwater eel glazed in kabayaki sauce over steamed rice.", "brown"),
 ("natto", "natto pack", "J", "FOOD", 100, 0, -2, 45, 80, 14, 0, "6 days", False, "Fermented soybeans in a stringy, pungent paste.  An acquired taste.", "brown"),
 ("mochi", "mochi", "J", "FOOD", 130, 0, 7, 60, 80, 22, 1, "3 days", False, "Soft rice cakes filled with sweet red bean paste.", "white"),
 ("dorayaki", "dorayaki", "J", "FOOD", 240, 0, 8, 90, 140, 25, 1, "10 days", False, "Two small pancakes sandwiching sweet bean paste.", "brown"),
 ("sencha", "sencha tea", "J", "DRINK", 5, 60, 4, 250, 250, 12, 0, "1 day", True, "A bottle of lightly grassy green tea.", "green"),
 ("mugicha", "barley tea", "J", "DRINK", 3, 70, 3, 300, 300, 10, 0, "30 days", False, "A cold, roasted, caffeine-free barley tea.", "brown"),
 ("kan_coffee", "canned coffee", "J", "DRINK", 40, 40, 4, 190, 190, 14, 0, "360 days", False, "A small can of sweet milky coffee from a vending machine.", "brown"),
 ("sashimi", "sashimi platter", "J", "FOOD", 280, 0, 14, 220, 400, 190, 2, "12 hours", False, "Thin slices of tuna, salmon and yellowtail on shaved radish.", "light_red"),
 # ---- Russian (17)
 ("borscht", "borscht", "R", "FOOD", 220, 30, 5, 350, 350, 28, 0, "2 days", True, "A deep red beet soup with cabbage, potato and a spoon of sour cream.", "red"),
 ("pelmeni", "pelmeni", "R", "FOOD", 520, 0, 7, 300, 350, 35, 0, "5 days", True, "Small meat dumplings boiled and served with butter and vinegar.", "light_gray"),
 ("blini", "blini stack", "R", "FOOD", 360, 0, 7, 180, 300, 30, 0, "2 days", False, "A stack of thin pancakes, served with sour cream.", "yellow"),
 ("kasha", "buckwheat kasha pack", "R", "FOOD", 330, 0, 3, 250, 300, 15, 0, "10 days", True, "A plain pouch of boiled buckwheat groats.", "brown"),
 ("piroshki", "piroshki", "R", "FOOD", 310, 0, 6, 120, 180, 22, 0, "2 days", False, "Baked buns filled with cabbage and egg.", "brown"),
 ("olivier", "olivier salad", "R", "FOOD", 300, 0, 5, 200, 250, 30, 1, "2 days", False, "Diced potato, pickle, peas and egg in mayonnaise.", "white"),
 ("shchi", "shchi", "R", "FOOD", 140, 30, 4, 350, 350, 20, 0, "2 days", True, "A thin soup of sour cabbage and potato.", "green"),
 ("kotleta", "kotleta with mash", "R", "FOOD", 640, 0, 7, 380, 500, 60, 1, "2 days", True, "Pan-fried meat patties with buttery mashed potato.", "brown"),
 ("black_bread", "black rye loaf", "R", "FOOD", 520, 0, 3, 350, 500, 18, 0, "6 days", False, "A dense, sour rye loaf with a hard crust.", "dark_gray"),
 ("herring", "smoked herring", "R", "FOOD", 240, 0, 6, 150, 200, 38, 1, "8 days", False, "A whole smoked herring wrapped in paper.", "light_cyan"),
 ("kvass", "kvass", "R", "DRINK", 60, 55, 5, 330, 330, 12, 0, "6 days", False, "A fizzy, faintly sour drink fermented from rye bread.", "brown"),
 ("solyanka", "solyanka", "R", "FOOD", 260, 25, 7, 350, 350, 45, 1, "2 days", True, "A thick, tangy soup of mixed meats, pickles and olives.", "light_red"),
 ("syrniki", "syrniki", "R", "FOOD", 340, 0, 8, 200, 250, 32, 1, "2 days", False, "Pan-fried cottage cheese pancakes with jam.", "yellow"),
 ("tushonka", "tushonka tin", "R", "FOOD", 590, 0, 5, 340, 300, 55, 0, "720 days", False, "A tin of stewed beef in its own fat, the staple of every pantry.", "dark_gray"),
 ("vobla", "dried vobla", "R", "FOOD", 200, 0, 4, 100, 150, 28, 0, "180 days", False, "Salted and dried roach, eaten in strips.", "light_gray"),
 ("kompot", "kompot", "R", "DRINK", 90, 65, 5, 330, 330, 14, 0, "6 days", False, "A sweet drink of stewed fruit and its juice.", "light_red"),
 ("caviar_blini", "caviar blini tin", "R", "FOOD", 240, 0, 15, 120, 200, 200, 2, "30 days", False, "Imported black caviar with a stack of tiny blini and cream.", "dark_gray"),
 # ---- Chinese (16)
 ("congee", "congee bowl", "C", "FOOD", 170, 25, 3, 350, 350, 14, 0, "2 days", True, "A bowl of thin rice porridge with pickled vegetables.", "white"),
 ("baozi", "baozi buns", "C", "FOOD", 380, 0, 7, 200, 300, 24, 0, "2 days", True, "Two steamed buns filled with pork and cabbage.", "white"),
 ("jiaozi", "jiaozi", "C", "FOOD", 420, 0, 8, 240, 350, 38, 1, "2 days", True, "Boiled dumplings stuffed with pork and chives.", "light_gray"),
 ("mapo_tofu", "mapo tofu with rice", "C", "FOOD", 520, 5, 9, 400, 500, 48, 1, "2 days", True, "Soft tofu in a numbing, spicy bean sauce, over rice.", "red"),
 ("kung_pao", "kung pao chicken box", "C", "FOOD", 580, 0, 9, 380, 500, 55, 1, "2 days", True, "Diced chicken, peanuts and dried chilli in a sweet-sour sauce.", "red"),
 ("chow_mein", "chow mein box", "C", "FOOD", 600, 0, 7, 400, 600, 40, 0, "2 days", True, "Stir-fried noodles with vegetables and pork.", "yellow"),
 ("fried_rice", "egg fried rice box", "C", "FOOD", 540, 0, 6, 350, 500, 32, 0, "2 days", True, "Rice fried with egg, peas and spring onion.", "yellow"),
 ("century_egg", "century egg", "C", "FOOD", 110, 0, 2, 60, 60, 26, 1, "90 days", False, "A preserved egg with a dark, jelly-like white.  Strong smell.", "dark_gray"),
 ("hotpot_tin", "self-heating hot pot", "C", "FOOD", 480, 20, 9, 450, 600, 85, 1, "360 days", True, "A sealed tray of broth, beef, mushrooms and noodles that heats itself.", "light_red"),
 ("zongzi", "zongzi", "C", "FOOD", 360, 0, 6, 180, 250, 28, 1, "6 days", False, "Sticky rice and pork wrapped in a bamboo leaf and boiled.", "green"),
 ("mooncake", "mooncake", "C", "FOOD", 420, 0, 8, 150, 140, 42, 1, "30 days", False, "A dense pastry with lotus seed paste and a salted yolk.", "brown"),
 ("dandan", "dan dan noodles", "C", "FOOD", 540, 0, 8, 380, 500, 44, 1, "2 days", True, "Noodles in a fiery sesame and chilli sauce with minced pork.", "red"),
 ("tangyuan", "tang yuan soup", "C", "FOOD", 230, 20, 7, 300, 300, 26, 1, "2 days", True, "Sweet glutinous rice balls in ginger syrup.", "white"),
 ("jianbing", "jianbing crepe", "C", "FOOD", 340, 0, 7, 220, 350, 20, 0, "1 day", True, "A street crepe with egg, crackling wafer, sauce and herbs.", "yellow"),
 ("soy_milk", "soy milk bottle", "C", "DRINK", 90, 60, 4, 330, 330, 10, 0, "6 days", False, "A bottle of lightly sweetened soy milk.", "white"),
 ("oolong", "premium oolong", "C", "DRINK", 3, 60, 8, 250, 250, 60, 2, "360 days", True, "A bottle of high-mountain oolong, smooth and floral.", "light_green"),
]
assert len(F) == 50, len(F)
assert all(10 <= f[9] <= 200 for f in F)
assert len({f[0] for f in F}) == 50

# ---- cyber rations: only a cyberstomach can digest them.  (id, name, kcal, quench, morale, power kJ, stamina, price, description)
CYBER = [
 ("nutrient_paste", "nutrient paste tube", 900, 20, 5, 30, 0, 120, "A squeeze tube of dense engineered paste.  Bland and complete."),
 ("hydration_gel", "hydration gel pack", 100, 260, 5, 10, 0, 130, "Isotonic gel that rehydrates you very thoroughly."),
 ("protein_brick", "synth-protein brick", 1400, 0, 6, 40, 0, 190, "A dense block of lab-grown protein with every vitamin in it."),
 ("cell_ramen", "cell-cultured ramen", 1000, 30, 12, 60, 0, 260, "Noodles and broth from a cultured-cell kitchen.  It tastes like the real thing, only better."),
 ("glucose_cube", "glucose cell cube", 400, 0, 4, 300, 0, 300, "A candy-sized cube of fuel-grade sugar that a cyberstomach turns almost straight into power."),
 ("marrow_ampoule", "marrow broth ampoule", 700, 100, 10, 80, 60, 350, "A heated ampoule of engineered broth that leaves you feeling rested."),
 ("ghost_sashimi", "ghost-grade sashimi pack", 1200, 40, 20, 120, 0, 450, "Cultured tuna so good that rich people weep.  Only a cyberstomach can take it."),
 ("overclock_chow", "overclock chow", 1500, 60, 15, 500, 100, 600, "A hot, spiced, dense meal that dumps power into your cells and wakes you up."),
]
CYBER_TIER = {"p": ["nutrient_paste", "hydration_gel"], "m": ["nutrient_paste", "hydration_gel", "protein_brick", "cell_ramen", "glucose_cube"],
              "r": ["protein_brick", "cell_ramen", "glucose_cube", "marrow_ampoule", "ghost_sashimi", "overclock_chow"]}

# plain staples from the stock game that every grocery carries as well
STAPLES = [("water_clean", 6, "water"), ("cola", 12, "cola"), ("tea_green", 14, "tea"), ("noodles_fast", 16, "noodles"), ("rice_cooked", 9, "rice"),
           ("energy_drink", 22, "energy drink")]
