extends RefCounted
## The businesses of the city: 40 types, each in 3 to 5 versions of different size and quality.
## A type is DATA (see TYPES): where it likes to stand (zone), who works there, what fills it.  `stamp` builds one into a rectangle of the map:
## walls, a door on the street side (and a glass storefront for shops), a floor, furniture laid out by the type's archetype, and the cells where its
## people stand.  The six older kinds (restaurant, grocery, implant shop, doctor's office, church, shrine) are drawn by venues.gd and listed here so that
## they share the catalogue; everything else is built by the generic builder below.
## No furniture here has stats or functions yet: it is scenery (see tools/content/furniture_list).
const CG = preload("res://src/citygen.gd")
const VN = preload("res://src/venues.gd")

## zone: where the type is likely to stand.  core = downtown, mid = the ring round it, edge = the outskirts, ind = industrial districts, any
## role: "vendor" (a keeper who trades, like the existing merchants) or "staff" (ordinary employees)
## legacy: built by venues.gd (kind name)
## L (layout): floor = floor tile per tier; counter = counter prop; cu = depth of the counter line; body = rows | tables | bench | open | cells | rooms;
##   row / seat / wall = props for the body, the seats and the back wall; front = corner props at the door; decor = corner props at the back; glass = storefront
## versions: [width, depth, tier, tag] (outer size, tier 0 poor / 1 middle / 2 rich)
const TYPES := {
	# ------------------------------------------------------------------ food and drink
	"restaurant": {"name": "Restaurant", "cat": "food", "zone": "core", "w": 10, "role": "vendor", "legacy": "restaurant", "jobs": ["cook", "waiter", "dishwasher"],
		"versions": [[12, 13, 0, "diner"], [14, 13, 1, "family"], [16, 14, 1, "bistro"], [20, 14, 2, "fine dining"]]},
	"noodle_stall": {"name": "Noodle stall", "cat": "food", "zone": "any", "w": 3, "role": "staff", "jobs": ["cook", "server"],
		"names": ["Nagi Noodles", "Late Night Ramen", "Tanuki Stall", "Steam & Soy", "Corner Udon"],
		"L": {"floor": ["floor_concrete", "floor_wood", "floor_wood"], "counter": "noodle_counter", "cu": 3, "body": "open", "row": "bar_stool", "wall": "hot_plate", "front": ["neon"], "decor": ["fridge"], "glass": false},
		"versions": [[8, 8, 0, "stall"], [10, 9, 0, "stand"], [12, 10, 1, "shop"]]},
	"cafe": {"name": "Cafe", "cat": "food", "zone": "core", "w": 7, "role": "staff", "jobs": ["barista", "baker"],
		"names": ["Blue Crane Coffee", "Kissaten Yuki", "Cafe Aurora", "Black Samovar", "Morning Glass", "Hearth & Bean"],
		"L": {"floor": ["floor_wood", "floor_wood", "floor_carpet"], "counter": "coffee_bar", "cu": 4, "body": "tables", "row": "cafe_table", "seat": "cafe_chair", "wall": "coffee_machine", "front": ["fern"], "decor": ["fern"], "glass": true},
		"versions": [[10, 10, 0, "kiosk"], [12, 11, 1, "cafe"], [14, 12, 1, "roastery"], [18, 13, 2, "salon"]]},
	"bar": {"name": "Bar", "cat": "food", "zone": "mid", "w": 7, "role": "staff", "jobs": ["bartender", "bouncer"],
		"names": ["The Rusty Crane", "Sakhalin Arms", "Two Lanterns", "Harbor Light", "Gin & Gyoza", "The Low Tide"],
		"L": {"floor": ["floor_wood", "floor_wood", "floor_carpet"], "counter": "bar_counter", "cu": 5, "body": "tables", "row": "dining_table", "seat": "booth_seat", "wall": "liquor_shelf", "front": ["neon"], "decor": ["jukebox", "pool_table"], "glass": false},
		"versions": [[11, 11, 0, "pub"], [13, 12, 1, "bar"], [16, 13, 1, "lounge"], [20, 14, 2, "cocktail bar"]]},
	"shady_bar": {"name": "Dive bar", "cat": "food", "zone": "edge", "w": 5, "role": "staff", "jobs": ["bartender", "enforcer"],
		"names": ["The Back Room", "Nine Lives", "Smoke & Mirrors", "The Pit", "Last Orders", "Red Door"],
		"L": {"floor": ["floor_concrete", "floor_concrete", "floor_wood"], "counter": "bar_counter", "cu": 4, "body": "tables", "row": "card_table", "seat": "stool", "wall": "liquor_shelf", "front": ["barrel"], "decor": ["crate_stack", "barrel"], "glass": false},
		"versions": [[10, 10, 0, "dive"], [12, 11, 0, "den"], [14, 12, 1, "speakeasy"]]},
	"nightclub": {"name": "Nightclub", "cat": "food", "zone": "core", "w": 5, "role": "staff", "jobs": ["bartender", "dj", "bouncer"],
		"names": ["Neon Koi", "Static", "Club Nine", "Afterimage", "Voltage", "The Chrome Orchid"],
		"L": {"floor": ["floor_dance", "floor_dance", "floor_dance"], "counter": "bar_counter", "cu": 3, "body": "open", "row": "lounge_sofa", "wall": "speaker_stack", "front": ["neon", "neon"], "decor": ["dj_booth", "speaker_stack"], "glass": false},
		"versions": [[16, 14, 0, "basement club"], [18, 16, 1, "club"], [22, 18, 2, "superclub"]]},
	"bakery": {"name": "Bakery", "cat": "food", "zone": "mid", "w": 6, "role": "staff", "jobs": ["baker", "counter clerk"],
		"names": ["Hakubai Bakery", "Daily Loaf", "Pan-ya", "Golden Crumb", "Kolokol Bread"],
		"L": {"floor": ["floor_clean", "floor_clean", "floor_checker"], "counter": "bakery_case", "cu": 3, "body": "rows", "row": "bread_rack", "wall": "pizza_oven", "front": ["fern"], "decor": ["fridge"], "glass": true},
		"versions": [[9, 10, 0, "stand"], [11, 11, 1, "bakery"], [13, 12, 1, "patisserie"]]},
	"karaoke": {"name": "Karaoke parlour", "cat": "food", "zone": "core", "w": 4, "role": "staff", "jobs": ["host", "bartender"],
		"names": ["Sing Out", "Mic Check", "Big Echo", "Utagoe", "Rainbow Room"],
		"L": {"floor": ["floor_carpet", "floor_carpet", "floor_carpet"], "counter": "reception", "cu": 3, "body": "cells", "row": "karaoke_booth", "wall": "liquor_shelf", "front": ["neon"], "decor": ["fern"], "glass": false},
		"versions": [[12, 12, 0, "booths"], [16, 13, 1, "parlour"], [20, 14, 2, "lounge"]]},
	"convenience": {"name": "Convenience store", "cat": "retail", "zone": "any", "w": 7, "role": "vendor", "jobs": ["clerk", "stocker"],
		"names": ["24h Mart", "Lawn Station", "Corner Pantry", "Konbini One", "Night Owl Mart", "Quick Basket"],
		"L": {"floor": ["floor_clean", "floor_clean", "floor_clean"], "counter": "checkout", "cu": 2, "body": "rows", "row": "shelf", "wall": "freezer_case", "front": ["vending"], "decor": ["water_cooler"], "glass": true},
		"versions": [[9, 10, 0, "kiosk"], [11, 11, 0, "corner store"], [13, 12, 1, "mart"], [16, 13, 1, "supermart"]]},
	"liquor_store": {"name": "Liquor store", "cat": "retail", "zone": "mid", "w": 5, "role": "vendor", "jobs": ["clerk"],
		"names": ["Bottle Shop", "Sake & Spirits", "Vodka Row", "The Cellar", "Amber Barrel"],
		"L": {"floor": ["floor_concrete", "floor_wood", "floor_wood"], "counter": "counter", "cu": 2, "body": "rows", "row": "liquor_shelf", "wall": "freezer_case", "front": ["barrel"], "decor": ["cabinet"], "glass": true},
		"versions": [[9, 10, 0, "off-licence"], [11, 11, 1, "store"], [14, 12, 2, "cellar shop"]]},
	# ------------------------------------------------------------------ retail
	"clothing": {"name": "Clothing store", "cat": "retail", "zone": "core", "w": 9, "role": "vendor", "jobs": ["sales clerk", "tailor"],
		"names": ["Kuro Threads", "Fashion Row", "Second Skin", "Sakura Wear", "Drab & Fab", "Tailor Nine"],
		"L": {"floor": ["floor_concrete", "floor_wood", "floor_carpet"], "counter": "counter", "cu": 2, "body": "rows", "row": "clothing_rack", "wall": "shoe_wall", "front": ["mannequin", "mannequin"], "decor": ["mirror"], "glass": true},
		"versions": [[10, 10, 0, "thrift"], [12, 11, 1, "boutique"], [16, 13, 1, "department"], [20, 14, 2, "couture"]]},
	"electronics": {"name": "Electronics store", "cat": "retail", "zone": "core", "w": 8, "role": "vendor", "jobs": ["sales clerk", "technician"],
		"names": ["Akiba Parts", "Volt & Wire", "Circuit City East", "Gadget Alley", "Bright Screens"],
		"L": {"floor": ["floor_steel", "floor_clean", "floor_steel"], "counter": "counter", "cu": 2, "body": "rows", "row": "electronics_shelf", "wall": "tv_wall", "front": ["display_case"], "decor": ["display_case"], "glass": true},
		"versions": [[10, 10, 0, "parts stall"], [12, 11, 1, "shop"], [16, 13, 1, "megastore"], [20, 14, 2, "flagship"]]},
	"office_supply": {"name": "Office supply store", "cat": "retail", "zone": "core", "w": 6, "role": "vendor", "jobs": ["clerk", "stocker"],
		"names": ["Desk & Co", "OfficeWorks", "Stationer Row", "Corp Supply", "Paperless?"],
		"L": {"floor": ["floor_clean", "floor_clean", "floor_carpet"], "counter": "counter", "cu": 2, "body": "rows", "row": "office_shelf", "wall": "office_shelf", "front": ["copier"], "decor": ["filing_cabinet"], "glass": true},
		"versions": [[10, 10, 0, "small shop"], [13, 12, 1, "store"], [18, 13, 1, "warehouse store"]]},
	"martial_shop": {"name": "Martial arts store", "cat": "retail", "zone": "mid", "w": 5, "role": "vendor", "jobs": ["shopkeeper", "instructor"],
		"names": ["Iron Fist Supply", "Budo-ya", "The Bamboo Blade", "Dragon Gear", "Kata & Kit"],
		"L": {"floor": ["floor_wood", "floor_wood", "floor_hinoki"], "counter": "counter", "cu": 2, "body": "open", "row": "weapon_rack", "wall": "weapon_rack", "front": ["punching_bag"], "decor": ["training_dummy"], "glass": true},
		"versions": [[10, 10, 0, "supply"], [12, 11, 1, "store"], [15, 12, 2, "pro shop"]]},
	"pawn_shop": {"name": "Pawn shop", "cat": "retail", "zone": "edge", "w": 7, "role": "vendor", "jobs": ["pawnbroker", "appraiser"],
		"names": ["Lucky Loan", "Gold & Gadgets", "Three Balls", "Cash Now", "Old Wares"],
		"L": {"floor": ["floor_concrete", "floor_wood", "floor_wood"], "counter": "pawn_cage", "cu": 3, "body": "rows", "row": "display_case", "wall": "cabinet", "front": ["neon"], "decor": ["safe"], "glass": false},
		"versions": [[9, 10, 0, "stall"], [11, 11, 0, "shop"], [14, 12, 1, "emporium"]]},
	"gun_dealer": {"name": "Black-market gun dealer", "cat": "retail", "zone": "edge", "w": 4, "role": "vendor", "jobs": ["dealer", "guard"],
		"names": ["Parts Counter", "Back Alley Arms", "The Quiet Room", "Uncle Misha's", "No Questions"],
		"L": {"floor": ["floor_concrete", "floor_concrete", "floor_steel"], "counter": "counter", "cu": 3, "body": "bench", "row": "gunsmith_table", "seat": "crate_stack", "wall": "gun_rack", "front": ["crate_stack"], "decor": ["safe"], "glass": false},
		"versions": [[9, 10, 0, "back room"], [11, 11, 0, "workshop"], [13, 12, 1, "front shop"]]},
	"hardware": {"name": "Hardware store", "cat": "retail", "zone": "mid", "w": 7, "role": "vendor", "jobs": ["clerk", "stocker"],
		"names": ["Nuts & Bolts", "Hardware Hokkaido", "Handy Depot", "Iron Works Supply", "Tool Barn"],
		"L": {"floor": ["floor_concrete", "floor_concrete", "floor_clean"], "counter": "counter", "cu": 2, "body": "rows", "row": "hardware_rack", "wall": "tool_wall", "front": ["lumber_stack"], "decor": ["barrel"], "glass": true},
		"versions": [[10, 10, 0, "stall"], [13, 12, 1, "store"], [18, 14, 1, "depot"], [22, 15, 2, "superstore"]]},
	"pharmacy": {"name": "Pharmacy", "cat": "retail", "zone": "mid", "w": 7, "role": "vendor", "jobs": ["pharmacist", "clerk"],
		"names": ["Green Cross", "Aoki Pharmacy", "Remedy Row", "Night Chemist", "Pill & Poultice"],
		"L": {"floor": ["floor_clean", "floor_clean", "floor_clean"], "counter": "counter", "cu": 3, "body": "rows", "row": "pharmacy_shelf", "wall": "med_cabinet", "front": ["scale"], "decor": ["water_cooler"], "glass": true},
		"versions": [[9, 10, 0, "dispensary"], [12, 11, 1, "pharmacy"], [16, 12, 2, "drugstore"]]},
	"bookshop": {"name": "Bookshop", "cat": "retail", "zone": "core", "w": 5, "role": "vendor", "jobs": ["bookseller"],
		"names": ["Jimbocho Books", "Dog-Ear", "The Quiet Shelf", "Samizdat", "Page & Ink"],
		"L": {"floor": ["floor_wood", "floor_wood", "floor_carpet"], "counter": "counter", "cu": 2, "body": "rows", "row": "bookshelf", "wall": "bookshelf", "front": ["armchair"], "decor": ["fern"], "glass": true},
		"versions": [[9, 10, 0, "used books"], [12, 11, 1, "bookshop"], [16, 12, 2, "bookstore"]]},
	"car_dealer": {"name": "Car dealership", "cat": "retail", "zone": "edge", "w": 7, "role": "staff", "jobs": ["salesperson", "manager", "detailer"],
		"names": ["Hakone Motors", "Tsubasa Auto", "Northern Wheels", "Drive Nine", "City Motors", "Lada & Sons"],
		"L": {"floor": ["floor_concrete", "floor_clean", "floor_marble"], "counter": "reception", "cu": 3, "body": "open", "row": "car_plinth", "wall": "tire_rack", "front": ["fern"], "decor": ["desk"], "glass": true},
		"versions": [[14, 12, 0, "used lot"], [18, 14, 1, "dealership"], [24, 16, 2, "showroom"]]},
	"auto_garage": {"name": "Auto garage", "cat": "industry", "zone": "ind", "w": 8, "role": "staff", "jobs": ["mechanic", "service writer"],
		"names": ["Quick Lube", "Grease Monkey", "Torque Works", "Kobayashi Repair", "Oil & Iron"],
		"L": {"floor": ["floor_concrete", "floor_concrete", "floor_concrete"], "counter": "counter", "cu": 2, "body": "bench", "row": "lift_hoist", "seat": "tool_chest", "wall": "tire_rack", "front": ["barrel"], "decor": ["workbench"], "glass": false},
		"versions": [[12, 12, 0, "backyard"], [15, 13, 0, "garage"], [18, 14, 1, "service centre"], [22, 15, 1, "workshop"]]},
	# ------------------------------------------------------------------ services
	"clinic": {"name": "Doctor's office", "cat": "service", "zone": "mid", "w": 8, "role": "vendor", "legacy": "clinic", "jobs": ["doctor", "nurse", "receptionist"],
		"versions": [[12, 13, 0, "walk-in"], [14, 13, 1, "practice"], [16, 14, 1, "surgery"], [20, 14, 2, "private clinic"]]},
	"implant_shop": {"name": "Implant shop", "cat": "service", "zone": "core", "w": 6, "role": "vendor", "legacy": "implant", "jobs": ["technician", "surgeon"],
		"versions": [[12, 13, 0, "back alley"], [14, 13, 1, "shop"], [18, 14, 2, "boutique"]]},
	"bank": {"name": "Bank", "cat": "service", "zone": "core", "w": 6, "role": "staff", "jobs": ["teller", "manager", "guard"],
		"names": ["Hokkai Savings", "First Sakhalin", "Union Trust", "Tsugaru Bank", "Meridian Credit"],
		"L": {"floor": ["floor_clean", "floor_marble", "floor_marble"], "counter": "teller_window", "cu": 5, "body": "open", "row": "queue_rail", "wall": "deposit_boxes", "front": ["atm", "atm"], "decor": ["vault_door"], "glass": true, "line": true},
		"versions": [[12, 13, 0, "credit union"], [16, 14, 1, "branch"], [20, 16, 2, "main branch"]]},
	"police": {"name": "Police station", "cat": "service", "zone": "mid", "w": 4, "role": "staff", "jobs": ["officer", "desk sergeant", "detective"],
		"names": ["Precinct 4", "Harbor Precinct", "Central Station", "North Ward Police", "Precinct 9"],
		"L": {"floor": ["floor_clean", "floor_clean", "floor_clean"], "counter": "police_desk", "cu": 4, "body": "cells", "row": "holding_cell", "wall": "evidence_locker", "front": ["notice_board"], "decor": ["desk"], "glass": false, "line": true, "booths": 1},
		"versions": [[14, 13, 0, "substation"], [18, 14, 1, "precinct"], [24, 16, 1, "headquarters"]]},
	"gov_office": {"name": "Government office", "cat": "service", "zone": "core", "w": 6, "role": "staff", "jobs": ["clerk", "inspector", "supervisor"],
		"names": ["Ward Office", "Permits & Licences", "Harbor Authority", "Housing Bureau", "Civil Registry", "Tax Office"],
		"L": {"floor": ["floor_clean", "floor_carpet_grey", "floor_marble"], "counter": "service_window", "cu": 5, "body": "open", "row": "waiting_bench", "wall": "filing_cabinet", "front": ["notice_board"], "decor": ["queue_rail"], "glass": false, "line": true, "booths": 2},
		"versions": [[12, 13, 0, "branch office"], [16, 14, 1, "ward office"], [20, 15, 1, "bureau"], [24, 16, 2, "ministry annex"]]},
	"labor_center": {"name": "Labor Center", "cat": "civic", "zone": "mid", "w": 3, "role": "staff", "jobs": ["case officer", "clerk", "security"], "wealth_max": 1,
		"names": ["Ward Labor Center", "Day Labor Hall", "Dockworkers' Hall", "Workers' Employment Exchange", "Hokkai Job Center", "Union Hiring Hall"],
		"L": {"floor": ["floor_clean", "floor_clean", "floor_carpet_grey"], "counter": "service_window", "cu": 4, "body": "open", "row": "waiting_bench", "wall": "notice_board", "front": ["notice_board", "vending"], "decor": ["queue_rail"], "glass": false, "line": true, "booths": 3},
		"versions": [[9, 9, 0, "hiring window"], [11, 10, 0, "job office"], [14, 13, 0, "day-labor hall"], [18, 14, 1, "employment center"], [22, 15, 1, "labor exchange"]]},
	"post_depot": {"name": "Post and courier depot", "cat": "service", "zone": "mid", "w": 5, "role": "staff", "jobs": ["clerk", "sorter", "courier"],
		"names": ["Hokkai Post", "Swift Courier", "Parcel Point", "North Express", "Ward Post Office"],
		"L": {"floor": ["floor_clean", "floor_concrete", "floor_clean"], "counter": "counter", "cu": 3, "body": "rows", "row": "parcel_shelf", "wall": "mail_sorter", "front": ["parcel_trolley"], "decor": ["scale"], "glass": true},
		"versions": [[10, 10, 0, "post box"], [14, 12, 1, "post office"], [20, 14, 1, "sorting depot"]]},
	"hotel": {"name": "Hotel", "cat": "service", "zone": "core", "w": 8, "role": "staff", "jobs": ["desk clerk", "porter", "housekeeper"],
		"names": ["Capsule Inn Nine", "Harbor Hotel", "Hotel Koi", "The Northern Rest", "Grand Tsubame", "Sleep Box"],
		"L": {"floor": ["floor_concrete", "floor_carpet", "floor_carpet"], "counter": "reception", "cu": 3, "body": "rooms", "row": "capsule_bed", "seat": "bed_single", "wall": "key_rack", "front": ["luggage_cart"], "decor": ["lobby_sofa"], "glass": true},
		"versions": [[14, 14, 0, "capsule hotel"], [18, 15, 0, "inn"], [22, 16, 1, "hotel"], [26, 18, 2, "grand hotel"]]},
	"gym": {"name": "Gym", "cat": "service", "zone": "mid", "w": 7, "role": "staff", "jobs": ["trainer", "front desk"],
		"names": ["Iron Temple", "FitBox", "Heavy Metal Gym", "Peak Fitness", "Bear Pit"],
		"L": {"floor": ["floor_rubber", "floor_rubber", "floor_rubber"], "counter": "reception", "cu": 2, "body": "open", "row": "treadmill", "seat": "weight_bench", "wall": "dumbbell_rack", "front": ["water_cooler"], "decor": ["squat_rack", "locker"], "glass": true},
		"versions": [[12, 12, 0, "basement gym"], [16, 13, 1, "gym"], [20, 14, 1, "fitness club"], [24, 16, 2, "health club"]]},
	"dojo": {"name": "Dojo", "cat": "service", "zone": "mid", "w": 5, "role": "staff", "jobs": ["sensei", "student"],
		"names": ["Seiryu Dojo", "Iron Crane Kwoon", "Bear Style Academy", "Shinkage-ryu", "North Wind Dojo"],
		"L": {"floor": ["floor_mat", "floor_mat", "floor_hinoki"], "counter": "", "cu": 2, "body": "open", "row": "training_dummy", "wall": "weapon_rack", "front": ["shoe_shelf"], "decor": ["punching_bag"], "glass": false},
		"versions": [[12, 12, 0, "backroom dojo"], [15, 13, 1, "dojo"], [20, 14, 2, "academy"]]},
	"salon": {"name": "Salon", "cat": "service", "zone": "core", "w": 7, "role": "staff", "jobs": ["stylist", "receptionist"],
		"names": ["Cut Above", "Kami Studio", "Shear Luck", "Neon Lashes", "The Razor's Edge", "Mirror Mirror"],
		"L": {"floor": ["floor_checker", "floor_clean", "floor_marble"], "counter": "reception", "cu": 2, "body": "bench", "row": "barber_chair", "seat": "salon_sink", "wall": "salon_mirror", "front": ["fern"], "decor": ["hair_dryer"], "glass": true},
		"versions": [[9, 10, 0, "barber"], [12, 11, 1, "salon"], [16, 12, 2, "studio"]]},
	"laundromat": {"name": "Laundromat", "cat": "service", "zone": "mid", "w": 7, "role": "staff", "jobs": ["attendant"],
		"names": ["Suds & Duds", "Coin Wash", "Clean Slate", "Wash-ya", "Spin Cycle"],
		"L": {"floor": ["floor_clean", "floor_clean", "floor_steel"], "counter": "", "cu": 2, "body": "bench", "row": "washing_machine", "seat": "waiting_bench", "wall": "dryer", "front": ["vending"], "decor": ["folding_table"], "glass": true},
		"versions": [[9, 10, 0, "coin laundry"], [12, 11, 0, "laundromat"], [16, 12, 1, "wash & fold"]]},
	"arcade": {"name": "Arcade and pachinko parlour", "cat": "service", "zone": "core", "w": 7, "role": "staff", "jobs": ["attendant", "prize clerk"],
		"names": ["Game Over", "Pachinko Paradise", "Joystick Alley", "Lucky Seven", "High Score", "Coin-Op"],
		"L": {"floor": ["floor_carpet", "floor_carpet", "floor_carpet"], "counter": "counter", "cu": 2, "body": "rows", "row": "arcade_cabinet", "wall": "pachinko_machine", "front": ["neon", "claw_machine"], "decor": ["vending"], "glass": false},
		"versions": [[11, 11, 0, "arcade"], [14, 12, 1, "game centre"], [20, 14, 1, "pachinko parlour"], [24, 15, 2, "grand parlour"]]},
	"church": {"name": "Church", "cat": "civic", "zone": "mid", "w": 3, "role": "vendor", "legacy": "church", "jobs": ["priest", "sexton"],
		"versions": [[12, 13, 0, "chapel"], [14, 13, 1, "church"], [16, 14, 2, "cathedral annex"]]},
	"shrine": {"name": "Shrine", "cat": "civic", "zone": "mid", "w": 3, "role": "vendor", "legacy": "temple", "jobs": ["miko", "caretaker"],
		"versions": [[12, 13, 0, "roadside shrine"], [14, 13, 1, "shrine"], [16, 14, 2, "great shrine"]]},
	"grocery": {"name": "Grocery", "cat": "retail", "zone": "any", "w": 10, "role": "vendor", "legacy": "grocery", "jobs": ["cashier", "stocker"],
		"versions": [[12, 13, 0, "corner grocer"], [14, 13, 1, "grocery"], [18, 14, 1, "market"]]},
	# ------------------------------------------------------------------ industry
	"warehouse": {"name": "Warehouse", "cat": "industry", "zone": "ind", "w": 12, "role": "staff", "jobs": ["stocker", "forklift driver", "dispatcher"],
		"names": ["Hokkai Freight", "Dock 9 Storage", "Northern Logistics", "Bulk & Co", "Sakhalin Cold Store", "Harbor Goods"],
		"L": {"floor": ["floor_concrete", "floor_concrete", "floor_concrete"], "counter": "desk", "cu": 2, "body": "rows", "row": "pallet_rack", "wall": "pallet_stack", "front": ["pallet_stack"], "decor": ["crate_stack"], "glass": false},
		"versions": [[14, 12, 0, "lock-up"], [18, 14, 0, "warehouse"], [24, 16, 1, "depot"], [30, 18, 1, "distribution hall"], [34, 20, 2, "cold store"]]},
	"workshop": {"name": "Light-industry workshop", "cat": "industry", "zone": "ind", "w": 10, "role": "staff", "jobs": ["assembler", "foreman", "packer"],
		"names": ["Kita Assembly", "Small Parts Co", "Tsubame Works", "Union Fabrication", "Eight Hands Factory"],
		"L": {"floor": ["floor_concrete", "floor_concrete", "floor_steel"], "counter": "desk", "cu": 2, "body": "bench", "row": "workbench", "seat": "parts_bin", "wall": "conveyor", "front": ["crate_stack"], "decor": ["tool_chest"], "glass": false},
		"versions": [[12, 12, 0, "sweatshop"], [16, 13, 0, "workshop"], [20, 14, 1, "assembly line"], [26, 16, 1, "small factory"]]},
	"machine_shop": {"name": "Machine shop", "cat": "industry", "zone": "ind", "w": 7, "role": "staff", "jobs": ["machinist", "foreman"],
		"names": ["Precision Iron", "Lathe & Mill", "Kuroda Machining", "Steel Bear", "Tolerance Ltd"],
		"L": {"floor": ["floor_concrete", "floor_concrete", "floor_steel"], "counter": "desk", "cu": 2, "body": "bench", "row": "lathe", "seat": "tool_chest", "wall": "mill", "front": ["barrel"], "decor": ["workbench"], "glass": false},
		"versions": [[12, 12, 0, "garage shop"], [16, 13, 1, "machine shop"], [20, 14, 1, "job shop"]]},
	"scrap_yard": {"name": "Scrap and recycling yard", "cat": "industry", "zone": "ind", "w": 8, "role": "staff", "jobs": ["sorter", "baler operator", "weigher"],
		"names": ["Tetsu Scrap", "Rust & Bone", "Second Life Metals", "Harbor Salvage", "Bear Recycling"],
		"L": {"floor": ["floor_concrete", "floor_concrete", "floor_concrete"], "counter": "desk", "cu": 2, "body": "open", "row": "scrap_pile", "wall": "baler", "front": ["barrel"], "decor": ["shredder"], "glass": false},
		"versions": [[12, 12, 0, "scrapper"], [16, 14, 0, "yard"], [22, 16, 1, "recycling plant"]]},
}

## the order the types are listed in (the 40 of them)
static func type_ids() -> Array:
	return TYPES.keys()

## the furniture and floor names a type draws with (for the furniture list)
static func props_of(id: String) -> Array:
	var out: Array = []
	var t: Dictionary = TYPES[id]
	if t.has("L"):
		var L: Dictionary = t["L"]
		for f in L["floor"]:
			if not out.has(f):
				out.append(f)
		for k in ["counter", "row", "seat", "wall"]:
			if L.get(k, "") != "" and not out.has(L[k]):
				out.append(L[k])
		for k in ["front", "decor"]:
			for p in L.get(k, []):
				if not out.has(p):
					out.append(p)
		if int(L.get("booths", 0)) > 0 and not out.has("terminal"):
			out.append("terminal")
	return out

# ------------------------------------------------------------------------------------------------ the layout frame
class BLay:
	## (u, v) -> map cells for a door on side 0 N / 1 S / 2 W / 3 E: u counts inward from the door wall, v runs along it
	var c
	var bx0: int
	var by0: int
	var bx1: int
	var by1: int
	var side: int
	var wi: int
	var di: int
	var floor_id: int = 3
	func _init(cg, x0: int, y0: int, x1: int, y1: int, sd: int) -> void:
		c = cg
		bx0 = x0; by0 = y0; bx1 = x1; by1 = y1; side = sd
		if sd < 2:
			wi = x1 - x0 - 1
			di = y1 - y0 - 1
		else:
			wi = y1 - y0 - 1
			di = x1 - x0 - 1
	func cell(u: int, v: int) -> Vector2i:
		match side:
			0: return Vector2i(bx0 + 1 + v, by0 + 1 + u)
			1: return Vector2i(bx0 + 1 + v, by1 - 1 - u)
			2: return Vector2i(bx0 + 1 + u, by0 + 1 + v)
			_: return Vector2i(bx1 - 1 - u, by0 + 1 + v)
	func idx(u: int, v: int) -> int:
		var p := cell(u, v)
		return p.y * c.size + p.x
	func inside(u: int, v: int) -> bool:
		return u >= 0 and v >= 0 and u < di and v < wi
	func floor_all(f: int) -> void:
		floor_id = f
		for u in di:
			for v in wi:
				c.tiles[idx(u, v)] = f
				c.under[idx(u, v)] = f
	func put(u: int, v: int, name: String) -> bool:
		if not inside(u, v) or not CG.TID.has(name):
			return false
		var i: int = idx(u, v)
		if c.tiles[i] != floor_id:
			return false
		c.tiles[i] = CG.TID[name]
		c.under[i] = floor_id
		return true
	func row(u: int, v0: int, v1: int, name: String, skip: Array = []) -> void:
		for v in range(v0, v1 + 1):
			if not (v in skip):
				put(u, v, name)
	func col(v: int, u0: int, u1: int, name: String, skip: Array = []) -> void:
		for u in range(u0, u1 + 1):
			if not (u in skip):
				put(u, v, name)
	## a wall cell (u = -1 is the door wall, u = di the back wall) made into something else
	func wall_set(u: int, v: int, t: int) -> void:
		var p: Vector2i
		match side:
			0: p = Vector2i(bx0 + 1 + v, by0 + 1 + u)
			1: p = Vector2i(bx0 + 1 + v, by1 - 1 - u)
			2: p = Vector2i(bx0 + 1 + u, by0 + 1 + v)
			_: p = Vector2i(bx1 - 1 - u, by0 + 1 + v)
		if p.x < 0 or p.y < 0 or p.x >= c.size or p.y >= c.size:
			return
		c.tiles[p.y * c.size + p.x] = t
	func is_free(u: int, v: int) -> bool:
		return inside(u, v) and c.tiles[idx(u, v)] == floor_id

static func _tid(name: String, fallback: String = "floor_concrete") -> int:
	return CG.TID[name] if CG.TID.has(name) else CG.TID[fallback]

## which versions of a type fit a rectangle of w x h
static func fitting(id: String, w: int, h: int) -> Array:
	var out: Array = []
	var vs: Array = TYPES[id]["versions"]
	for k in vs.size():
		var v: Array = vs[k]
		if (int(v[0]) <= w and int(v[1]) <= h) or (int(v[1]) <= w and int(v[0]) <= h):
			out.append(k)
	return out

## the versions of a type that fit a w x h rectangle with the door on this side (a side door turns the building round)
static func fitting_side(id: String, w: int, h: int, side: int) -> Array:
	var out: Array = []
	var vs: Array = TYPES[id]["versions"]
	var eff: int = side if not TYPES[id].has("legacy") else (side % 2)
	for k in vs.size():
		var v: Array = vs[k]
		var bw: int = int(v[0]) if eff < 2 else int(v[1])
		var bh: int = int(v[1]) if eff < 2 else int(v[0])
		if bw <= w and bh <= h:
			out.append(k)
	return out

## the outer size (w, h) of version `ver` once the door faces `side`
static func size_of(id: String, ver: int, side: int) -> Vector2i:
	var v: Array = TYPES[id]["versions"][ver]
	var eff: int = side if not TYPES[id].has("legacy") else (side % 2)
	return Vector2i(int(v[0]), int(v[1])) if eff < 2 else Vector2i(int(v[1]), int(v[0]))

## build business `id`, version `ver`, into the rectangle whose top-left is (x0, y0); the door faces `side` (0 N, 1 S, 2 W, 3 E).  Returns the record.
static func stamp(c, id: String, ver: int, x0: int, y0: int, side: int, tier_hint: int = -1) -> Dictionary:
	var T: Dictionary = TYPES[id]
	var V: Array = T["versions"][ver]
	if T.has("legacy") and side >= 2:
		side -= 2                                   # the older venues only have a door on the north or the south wall
	var w: int = int(V[0])
	var h: int = int(V[1])
	if side >= 2:
		var t0: int = w
		w = h
		h = t0
	# the rectangle is oriented so the door wall is always the "front": swap the two sizes for a side door
	var bx0: int = x0
	var by0: int = y0
	var bx1: int = x0 + w - 1
	var by1: int = y0 + h - 1
	if side >= 2:
		bx1 = x0 + int(V[1]) - 1
		by1 = y0 + int(V[0]) - 1
	var tier: int = int(V[2])
	if T.has("legacy"):
		return _stamp_legacy(c, id, T, V, bx0, by0, bx1, by1, side)
	if c.under.size() != c.size * c.size:
		c.under = PackedByteArray()
		c.under.resize(c.size * c.size)
	var rng: RandomNumberGenerator = c.rng
	var L: Dictionary = T["L"]
	# shell
	for y in range(by0, by1 + 1):
		for x in range(bx0, bx1 + 1):
			c.tiles[y * c.size + x] = CG.FLOOR
	for x in range(bx0, bx1 + 1):
		c.tiles[by0 * c.size + x] = CG.WALL
		c.tiles[by1 * c.size + x] = CG.WALL
	for y in range(by0, by1 + 1):
		c.tiles[y * c.size + bx0] = CG.WALL
		c.tiles[y * c.size + bx1] = CG.WALL
	c.buildings += 1
	var B := BLay.new(c, bx0, by0, bx1, by1, side)
	var floors: Array = L["floor"]
	B.floor_all(_tid(floors[mini(tier, floors.size() - 1)]))
	var wi: int = B.wi
	var di: int = B.di
	var mid: int = wi / 2
	# door and storefront
	var door := B.cell(-1, mid)
	c.tiles[door.y * c.size + door.x] = CG.DOOR
	if bool(L.get("glass", false)):
		for v in range(1, wi - 1):
			if absi(v - mid) >= 2:
				B.wall_set(-1, v, CG.GLASS)
	var fr: Array = L.get("front", [])
	if fr.size() > 0:
		B.put(0, 0, fr[0])
		B.put(0, wi - 1, fr[1] if fr.size() > 1 else fr[0])
	var cu: int = int(L.get("cu", 2))
	var counter: String = String(L.get("counter", ""))
	var keeper := Vector2i(-1, -1)
	var line: bool = bool(L.get("line", false))
	# the counter: a full line with a gap at one end (service desks), else a short segment by one side
	if counter != "":
		var cl: int = wi - 2 if line else mini(wi - 3, 5)
		B.row(cu, 0, cl - 1 + (1 if line else 0), counter)
		keeper = B.cell(cu + 1, 1 if not line else mid)
	var body: String = String(L.get("body", "open"))
	var row_p: String = String(L.get("row", ""))
	var seat_p: String = String(L.get("seat", ""))
	var u0: int = cu + 2 if counter != "" else 1
	match body:
		"rows":
			var u: int = u0 + 1
			while u < di - 2:
				B.row(u, 1, wi - 2, row_p, [mid, mid + 1])
				u += 3
		"tables":
			var u: int = u0 + 1
			while u < di - 2:
				var v: int = 1
				while v < wi - 1:
					B.put(u, v, row_p)
					B.put(u - 1, v, seat_p)
					B.put(u + 1, v, seat_p)
					v += 3
				u += 4
		"bench":
			for u in range(u0, di - 1, 2):
				B.put(u, 0, row_p)
				B.put(u, wi - 1, row_p)
				B.put(u + 1, 0, seat_p)
				B.put(u + 1, wi - 1, seat_p)
			if wi >= 11:
				for u in range(u0 + 1, di - 2, 4):
					for v in range(3, wi - 3, 3):
						B.put(u, v, row_p)
		"open":
			# machines or fittings in two ranks at the sides and the back, a clear floor in the middle
			if row_p != "":
				for u in range(u0, di - 1, 3):
					for v in [1, wi - 2]:
						B.put(u, v, row_p)
				if wi >= 14:
					for u in range(u0 + 1, di - 2, 4):
						for v in range(4, wi - 4, 4):
							B.put(u, v, row_p)
		"cells":
			# the back part is cut into little rooms: a row of cell fittings with a seat each, off a corridor
			var wall_u: int = maxi(u0 + 2, di - 5)
			for v in range(1, wi - 3, 5):
				B.put(wall_u + 1, v, row_p)
				B.put(wall_u + 2, v, seat_p if seat_p != "" else "stool")
				B.put(wall_u + 1, v + 1, row_p)
		"rooms":
			# a lobby, then a corridor along the back with sleeping rooms off it
			var ru: int = maxi(u0 + 2, di - 6)
			for v in range(0, wi):
				if v % 5 != 2:
					c.tiles[B.idx(ru, v)] = CG.WALL
			for v in range(5, wi - 1, 5):
				for u in range(ru + 1, di):
					c.tiles[B.idx(u, v)] = CG.WALL
			for v in range(0, wi - 4, 5):
				var cr: String = row_p if tier == 0 else seat_p
				B.put(ru + 1, v + 1, cr)
				B.put(ru + 3, v + 3, "fern") if tier >= 2 else null
				if tier >= 1:
					B.put(ru + 1, v + 3, "dresser")
			for v in range(0, wi - 4, 5):
				var dv: int = v + 2
				if dv < wi:
					c.tiles[B.idx(ru, dv)] = CG.DOOR
	# the back wall
	var wall_p: String = String(L.get("wall", ""))
	if wall_p != "":
		for v in range(0, wi):
			if v % 6 != 3:
				B.put(di - 1, v, wall_p)
	# and along the side walls of a room big enough, a fitting every third cell where the floor beside it stays clear
	# (the view turns each to face away from its wall)
	if wall_p != "" and wi >= 7 and di >= 7:
		for u in range(u0 + 1, di - 2, 3):
			if B.is_free(u, 0) and B.is_free(u, 1):
				B.put(u, 0, wall_p)
			if B.is_free(u, wi - 1) and B.is_free(u, wi - 2):
				B.put(u, wi - 1, wall_p)
	for d in L.get("decor", []):
		B.put(di - 1, 0, d)
		break
	if L.get("decor", []).size() > 1:
		B.put(di - 1, wi - 1, L["decor"][1])
	# mission booths (the mission terminals of missions.gd) in a row along the wall beside the door, where people wait their turn
	var nb: int = int(L.get("booths", 0))
	if nb > 0:
		var placed := 0
		for v in range(wi - 2, 0, -3 if wi >= 9 else -2):         # (closer together in a small office)
			if placed >= nb:
				break
			if B.is_free(1, v):
				B.put(1, v, "terminal")
				placed += 1
	# the people: the keeper behind the counter, the rest of the staff on free floor
	var free: Array = []
	for u in range(maxi(cu + 1, 1), di):
		for v in wi:
			if B.is_free(u, v):
				free.append(B.cell(u, v))
	var nstaff: int = clampi(int(w * h / 70) + 1, 1, 7)
	var staff: Array = []
	if keeper.x >= 0 and c.tiles[keeper.y * c.size + keeper.x] == B.floor_id:
		staff.append(keeper.y * c.size + keeper.x)
	else:
		keeper = Vector2i(-1, -1)
	while staff.size() < nstaff and not free.is_empty():
		var q: int = rng.randi() % free.size()
		var cc: Vector2i = free[q]
		free.remove_at(q)
		var ci: int = cc.y * c.size + cc.x
		if not staff.has(ci):
			staff.append(ci)
	for sc in staff:
		c.works.append(sc)                               # people go to work where the staff stand
	var near_door: int = 0
	for u in range(0, mini(di, 4)):
		for v in range(wi):
			if near_door < 3 and B.is_free(u, v) and (u + v) % 3 == 0:
				c.shops.append(B.idx(u, v))                # and shop on the floor by the door
				near_door += 1
	var names: Array = T.get("names", ["Shop"])
	var rec := {"type": id, "ver": ver, "tag": String(V[3]), "tier": tier, "name": names[rng.randi() % names.size()], "cat": T["cat"],
		"x0": bx0, "y0": by0, "x1": bx1, "y1": by1, "door": door, "side": side, "role": T["role"], "jobs": T["jobs"], "staff": staff,
		"keeper": (keeper.y * c.size + keeper.x) if keeper.x >= 0 else -1}
	c.businesses.append(rec)
	return rec

static func _stamp_legacy(c, id: String, T: Dictionary, V: Array, bx0: int, by0: int, bx1: int, by1: int, side: int) -> Dictionary:
	var vs_side: int = 0 if side == 0 or side >= 2 else 1
	var rec: Dictionary = VN.stamp(c, String(T["legacy"]), bx0, by0, bx1, by1, vs_side, 1 if int(V[2]) >= 1 else 0)
	var biz := {"type": id, "ver": 0, "tag": String(V[3]), "tier": int(V[2]), "name": rec["name"], "cat": T["cat"], "x0": bx0, "y0": by0, "x1": bx1, "y1": by1,
		"door": rec["door"], "side": vs_side, "role": T["role"], "jobs": T["jobs"], "staff": [], "keeper": rec["keeper"], "legacy": true}
	c.businesses.append(biz)
	return biz
