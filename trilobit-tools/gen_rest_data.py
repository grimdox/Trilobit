#!/usr/bin/env python3
"""Data for the 36 restaurants (design doc section M13).  Every dish is an existing craftable game item, so the player can make the same
food at home.  Prices are in yen and always above the grocery counterpart: the reference price is the grocery price when the grocery sells
the item, otherwise the item's game value (cents / 8), and the restaurant multiplies it by its tier (poor 1.6, middle 2.4, rich 4.5)."""
import glob, json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
ITEMS = os.path.join(HERE, "..", "data", "json", "items")
MULT = {"p": 1.6, "m": 2.4, "r": 4.5}

_items = None
def items():
    global _items
    if _items is None:
        _items = {}
        for fn in glob.glob(os.path.join(ITEMS, "**", "*.json"), recursive=True):
            try:
                data = json.load(open(fn))
            except Exception:
                continue
            for o in data if isinstance(data, list) else []:
                if isinstance(o, dict) and "id" in o and isinstance(o["id"], str):
                    _items.setdefault(o["id"], o)
                    if o.get("abstract"):
                        _items.setdefault(o["abstract"], o)
    return _items


def parse_price(v):
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return int(v)
    c = 0
    for n, u in re.findall(r"(\d+(?:\.\d+)?)\s*(USD|cent)", str(v)):
        c += float(n) * (100 if u == "USD" else 1)
    return int(c)


def cents(iid):
    seen = 0
    o = items().get(iid)
    while o is not None and seen < 12:
        p = parse_price(o.get("price"))
        if p is not None:
            return p
        o = items().get(o.get("copy-from"))
        seen += 1
    return None


def exists(iid):
    return iid in items()


def ref_yen(iid, grocery):
    if iid in grocery:
        return grocery[iid]
    c = cents(iid)
    if not c:
        c = 400
    return int(min(320, max(8, round(c / 8))))


def price(iid, tier, grocery):
    r = ref_yen(iid, grocery)
    p = int(round(r * MULT[tier] / 5.0) * 5)
    return max(p, int(r) + 5)


# ---------------------------------------------------------------- drink lists
SOFT = ["water_clean", "tea_green", "cola", "lemonade", "coffee", "milk_tea", "juice", "oj_fresh", "hot_chocolate", "milkshake", "herbal_tea", "chai_tea",
        "milk", "energy_drink", "soy_milk", "horchata", "apple_cider", "tea"]
BOOZE = ["beer", "sake_filtered", "whiskey", "vodka", "gin", "rum", "brandy", "tequila", "fruit_wine", "belgian_ale", "india_pale_ale", "dandelion_wine",
         "drink_martini", "drink_gintonic", "drink_tequilasunrise", "drink_screwdriver", "drink_rumcola", "drink_pinacolada", "drink_bloody_mary",
         "drink_wsour", "drink_beeknees", "drink_kalimotxo", "long_island", "irish_coffee", "moonshine", "drink_gunfire"]

# (tier, name, theme, style, dishes, soft drinks, alcohol, worker, greeting)
# styles: counter (stools along a counter), tables (dining room), bar (bar and booths), stall (open stall, few seats), formal (white-cloth hall)
R = [
    # ----- poor (10)
    ("p", "back-alley ramen stall", "ramen", "stall",
     ["noodles_fast", "soup_meat", "soup_veggy", "broth_meat", "tofu_stirfry", "chicken_rice_hianese", "onigiri", "fried_mozzarella_sticks"],
     ["water_clean", "tea_green", "cola"], ["beer", "sake_filtered"], "ramen cook", "Hot noodles.  Sit anywhere."),
    ("p", "cheap conveyor sushi", "sushi", "counter",
     ["sushi_fishroll", "sushi_veggyroll", "sushi_meatroll", "onigiri", "sashimi", "soup_fish", "tofu_rice"],
     ["water_clean", "tea_green", "cola"], ["beer", "sake_filtered"], "sushi cook", "Take what you like off the belt.  Plates are counted at the end."),
    ("p", "pizza slice counter", "pizza", "stall",
     ["pizza_cheese", "pizza_meat", "pizza_veggy", "bread_garlic", "cheese_fries", "fried_mozzarella_sticks"],
     ["water_clean", "cola", "lemonade"], ["beer"], "pizza cook", "Slices are hot.  Whole pies on request."),
    ("p", "burger shack", "burger", "stall",
     ["hamburger", "cheeseburger", "cheese_fries", "onion_rings", "hotdogs_cooked", "chilidogs", "fish_sandwich"],
     ["water_clean", "cola", "milkshake", "energy_drink"], ["beer"], "grill cook", "Burgers, fries, no waiting."),
    ("p", "taco cart", "taco", "stall",
     ["taco", "ndn_taco", "homemade_burrito", "quesadilla_cheese", "nachosc", "chili", "beansnrice"],
     ["water_clean", "cola", "horchata", "lemonade"], ["beer", "tequila"], "taquero", "Three for a coin.  Salsa is free."),
    ("p", "fried chicken shop", "chicken", "counter",
     ["chicken_fried", "chicken_fried_buttermilk", "chicken_sandwich", "cheese_grits", "cornbread", "succotash", "fried_mozzarella_sticks"],
     ["water_clean", "cola", "lemonade", "tea"], ["beer"], "fry cook", "Crispy, hot and cheap."),
    ("p", "hot dog and sandwich stand", "deli", "stall",
     ["hotdogs_cooked", "chilidogs", "sloppyjoe", "blt", "sandwich_cheese_grilled", "sandwich_egg_salad", "currywurst"],
     ["water_clean", "cola", "coffee"], ["beer"], "counterman", "What'll it be?"),
    ("p", "rice bowl canteen", "donburi", "counter",
     ["chicken_rice_hianese", "tofu_rice", "curry_meat", "curry_veggy", "deluxe_rice", "beansnrice", "soup_veggy", "onigiri"],
     ["water_clean", "tea_green", "herbal_tea"], ["sake_filtered", "beer"], "canteen cook", "Rice, a topping, and soup.  Pay first."),
    ("p", "pelmeni house", "russian", "tables",
     ["pelmeni", "manti", "sarma", "soup_meat", "potato_baked", "sauerkraut_onions", "sausagegravy"],
     ["water_clean", "tea", "apple_cider"], ["vodka", "beer", "moonshine"], "kitchen hand", "Dumplings with sour cream.  The vodka is cold."),
    ("p", "dive bar kitchen", "dive", "bar",
     ["cheese_fries", "onion_rings", "chili", "chilidogs", "nachosm", "fish_fried", "cracklins", "sloppyjoe"],
     ["water_clean", "cola", "energy_drink"], ["beer", "whiskey", "vodka", "rum", "moonshine", "sake_filtered"], "barkeep", "Drinks are cheap.  The food is what it is."),
    # ----- middle (16)
    ("m", "neighborhood sushi bar", "sushi", "counter",
     ["sushi_fishroll", "sushi_veggyroll", "sushi_meatroll", "sashimi", "sushi_rice", "soup_fish", "tofu_fried", "fish_sandwich"],
     ["water_clean", "tea_green", "milk_tea"], ["beer", "sake_filtered", "whiskey"], "sushi chef", "Welcome in.  Order at the counter."),
    ("m", "sushi train", "sushi", "counter",
     ["sushi_fishroll", "sushi_meatroll", "sushi_veggyroll", "sashimi", "onigiri", "soup_fish", "tofu_rice", "caviar_egg_sandwich"],
     ["water_clean", "tea_green", "cola", "lemonade"], ["beer", "sake_filtered"], "sushi chef", "Plates roll by on the belt.  Grab what you want."),
    ("m", "corner pizzeria", "pizza", "tables",
     ["pizza_cheese", "pizza_meat", "pizza_veggy", "bread_garlic", "eggplant_parmigiana", "fried_mozzarella_sticks", "veggy_salad", "tiramisu"],
     ["water_clean", "cola", "lemonade", "coffee"], ["beer", "fruit_wine", "india_pale_ale"], "pizzaiolo", "Fresh dough, hot oven."),
    ("m", "family trattoria", "italian", "tables",
     ["spaghetti_bolognese", "pasta_carbonara", "amatriciana_pasta", "lasagne", "chicken_parm", "eggplant_parmigiana", "bread_garlic", "tiramisu"],
     ["water_clean", "coffee", "lemonade", "milk"], ["fruit_wine", "beer", "brandy"], "waiter", "Sit, sit.  The pasta is made this morning."),
    ("m", "burger grill", "burger", "tables",
     ["hamburger", "cheeseburger", "chicken_sandwich", "cheese_fries", "onion_rings", "poutine", "veggy_salad", "milkshake"],
     ["water_clean", "cola", "milkshake", "coffee"], ["beer", "india_pale_ale", "whiskey"], "grill cook", "Grill's hot.  Pick a table."),
    ("m", "all-night diner", "diner", "counter",
     ["pancakes", "waffles", "frenchtoast", "hamburger", "sandwich_deluxe", "sandwich_reuben", "pie", "chili", "cheese_grits"],
     ["water_clean", "coffee", "milkshake", "cola", "oj_fresh"], ["beer", "irish_coffee"], "short-order cook", "Coffee's fresh.  Sit anywhere."),
    ("m", "curry house", "curry", "tables",
     ["curry_meat", "curry_veggy", "chicken_tandoori", "samosa_veggy", "chicken_rice_hianese", "deluxe_veggy_rice", "flatbread", "soup_three_sisters"],
     ["water_clean", "chai_tea", "milk_tea", "lemonade"], ["beer", "india_pale_ale", "whiskey"], "curry cook", "Mild, medium or hot?"),
    ("m", "roast house", "roast", "tables",
     ["glazed_tenderloin", "confit_meat", "potato_baked", "carrot_roasted", "gravy_prepared", "cornbread", "soup_mushroom", "pie_meat"],
     ["water_clean", "coffee", "tea"], ["whiskey", "beer", "fruit_wine", "brandy"], "carver", "Roast of the day, carved at your table."),
    ("m", "bakery cafe", "cafe", "tables",
     ["brioche", "sourdough_bread", "sandwich_veggy", "sandwich_cucumber", "crepe", "pie_maple", "cookies", "gateau_st_honore", "religieuse_au_chocolat"],
     ["coffee", "tea", "milk_coffee", "hot_chocolate", "oj_fresh", "chai_tea"], ["fruit_wine", "irish_coffee"], "barista", "Everything is baked this morning."),
    ("m", "pancake house", "breakfast", "tables",
     ["pancakes", "waffles", "choc_waffles", "fruit_waffles", "frenchtoast", "deluxe_eggs", "oatmeal_deluxe", "bacon", "sausagegravy"],
     ["coffee", "oj_fresh", "milk", "hot_chocolate", "tea"], ["irish_coffee"], "short-order cook", "Breakfast all day."),
    ("m", "izakaya", "izakaya", "bar",
     ["bratwurst_sausage", "tofu_fried", "fish_fried", "fried_mozzarella_sticks", "onigiri", "sashimi", "soup_veggy", "chicken_fried", "edamame_roasted"],
     ["water_clean", "tea_green", "cola"], ["beer", "sake_filtered", "whiskey", "gin", "drink_gintonic", "fruit_wine"], "izakaya master", "Sit.  Drink.  Order as you go."),
    ("m", "seafood grill", "seafood", "tables",
     ["fish_fried", "fish_bagel", "soup_fish", "soup_cullenskink", "lutefisk", "sushi_fishroll", "escargot", "paella_valenciana"],
     ["water_clean", "lemonade", "tea_green", "coffee"], ["beer", "fruit_wine", "sake_filtered", "gin"], "fish cook", "Today's catch is on the board."),
    ("m", "cantina", "mexican", "bar",
     ["taco", "homemade_burrito", "quesadilla_cheese", "nachosmc", "chili", "beansnrice", "succotash_deluxe", "iskender"],
     ["water_clean", "horchata", "lemonade", "cola"], ["beer", "tequila", "drink_tequilasunrise", "rum", "drink_pinacolada"], "cantina cook", "Tacos, tequila, and good company."),
    ("m", "sandwich deli", "deli", "counter",
     ["sandwich_reuben", "sandwich_deluxe", "blt", "sandwich_veggy_cheese", "sandwich_cheese_grilled", "sandwich_egg_salad", "sandwich_t", "veggy_salad", "pie"],
     ["water_clean", "coffee", "tea", "lemonade", "cola"], ["beer"], "deli man", "Cut to order."),
    ("m", "kebab and meze house", "turkish", "tables",
     ["iskender", "lahmacun", "kiymali_pide", "manti", "melitzanosalata", "sarma", "baklava", "flatbread"],
     ["water_clean", "tea", "milk", "lemonade"], ["beer", "brandy", "fruit_wine"], "grill master", "Hot from the fire."),
    ("m", "tea house and dessert parlor", "dessert", "tables",
     ["donut_holes", "baklava", "cookies", "icecream", "smores", "pie_maple", "gateau_st_honore", "cheese_fries"],
     ["tea_green", "tea", "chai_tea", "milk_tea", "herbal_tea", "hot_chocolate", "milkshake"], ["fruit_wine", "irish_coffee"], "tea server", "A quiet table and something sweet."),
    # ----- rich (10)
    ("r", "omakase counter", "sushi", "formal",
     ["sushi_fishroll", "sushi_meatroll", "sashimi", "sushi_rice", "caviar_egg_sandwich", "soup_fish", "tofu_fried", "royal_beef"],
     ["water_clean", "tea_green", "milk_tea"], ["sake_filtered", "whiskey", "fruit_wine", "brandy"], "sushi master", "The chef decides.  You enjoy."),
    ("r", "ginza-style sushi salon", "sushi", "formal",
     ["sushi_fishroll", "sushi_veggyroll", "sushi_meatroll", "sashimi", "lobster_platter", "caviar_egg_sandwich", "soup_lobsterstew", "tofu_fried"],
     ["water_clean", "tea_green", "tea"], ["sake_filtered", "whiskey", "gin", "fruit_wine"], "sushi master", "Welcome.  Your table is ready."),
    ("r", "wood-fired pizza house", "pizza", "formal",
     ["pizza_cheese", "pizza_meat", "pizza_veggy", "mozzarella_cheese", "bread_garlic", "eggplant_parmigiana", "tiramisu", "veggy_salad"],
     ["water_clean", "lemonade", "coffee", "milk"], ["fruit_wine", "belgian_ale", "brandy", "drink_martini"], "pizzaiolo", "Fired in the old oven."),
    ("r", "fine Italian ristorante", "italian", "formal",
     ["spaghetti_pesto", "pasta_carbonara", "lasagne", "chicken_parm", "glazed_tenderloin", "tiramisu", "sauce_pesto", "eggplant_parmigiana"],
     ["water_clean", "coffee", "tea"], ["fruit_wine", "brandy", "gin", "drink_martini", "dandelion_wine"], "maitre d'", "Good evening.  Your table is by the window."),
    ("r", "French bistro", "french", "formal",
     ["coqauvin", "escargot", "foie_gras", "crepe", "confit_meat", "gateau_st_honore", "religieuse_au_chocolat", "brioche"],
     ["water_clean", "coffee", "tea", "oj_fresh"], ["fruit_wine", "brandy", "drink_martini", "dandelion_wine", "gin"], "maitre d'", "Bonsoir.  Follow me."),
    ("r", "steakhouse", "steak", "formal",
     ["royal_beef", "glazed_tenderloin", "potato_baked", "carrot_glazed", "onion_sauteed", "soup_mushroom", "pie_meat", "veggy_salad"],
     ["water_clean", "coffee", "tea"], ["whiskey", "brandy", "fruit_wine", "drink_martini", "belgian_ale"], "maitre d'", "How would you like it done?"),
    ("r", "lobster and oyster house", "seafood", "formal",
     ["lobster_platter", "soup_lobsterstew", "lazy_lobster_casserole", "fish_fried", "caviar_egg_sandwich", "escargot", "paella_valenciana", "soup_cullenskink"],
     ["water_clean", "lemonade", "tea_green"], ["fruit_wine", "gin", "drink_martini", "sake_filtered", "drink_gintonic"], "maitre d'", "The tank is fresh this morning."),
    ("r", "tapas and paella bar", "spanish", "bar",
     ["paella_valenciana", "escargot", "fried_mozzarella_sticks", "melitzanosalata", "homemade_burrito", "quesadilla_cheese", "potato_baked", "tiramisu"],
     ["water_clean", "lemonade", "horchata", "coffee"], ["fruit_wine", "drink_kalimotxo", "brandy", "rum", "drink_pinacolada", "belgian_ale"], "barkeep", "Small plates, big night."),
    ("r", "skyline cocktail lounge", "lounge", "bar",
     ["caviar_egg_sandwich", "fried_mozzarella_sticks", "onion_rings", "cheese_fries", "sandwich_deluxe", "crepe", "icecream", "baklava"],
     ["water_clean", "tea_green", "coffee", "oj_fresh"], ["drink_martini", "drink_gintonic", "drink_tequilasunrise", "drink_wsour", "long_island", "drink_pinacolada",
                                                       "whiskey", "brandy", "gin", "vodka", "rum", "sake_filtered", "irish_coffee"], "bartender", "Take a seat by the glass.  The city looks good tonight."),
    ("r", "kaiseki banquet hall", "kaiseki", "formal",
     ["sashimi", "sushi_fishroll", "tofu_fried", "tofu_stirfry", "soup_fish", "chicken_rice_hianese", "honey_glassed", "royal_beef", "onigiri"],
     ["water_clean", "tea_green", "herbal_tea"], ["sake_filtered", "whiskey", "fruit_wine"], "kaiseki chef", "Seven courses, in season."),
]
assert len(R) == 36 and sum(1 for r in R if r[0] == "p") == 10 and sum(1 for r in R if r[0] == "m") == 16 and sum(1 for r in R if r[0] == "r") == 10
assert sum(1 for r in R if r[3 - 1 + 0] and r[2] == "sushi") == 5 and sum(1 for r in R if r[2] == "pizza") == 3


def kinds():
    """-> list of (kind name, tier letter, index in tier, record)"""
    seen = {"p": 0, "m": 0, "r": 0}
    out = []
    for rec in R:
        t = rec[0]
        seen[t] += 1
        out.append((f"rest{t}{seen[t]:02d}", t, seen[t], rec))
    return out
