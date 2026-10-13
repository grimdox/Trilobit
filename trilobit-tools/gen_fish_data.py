"""Data for gen_fish.py and shopdata.py: West Pacific fish, portable tanks, display themes, pets."""
# id, common name, latin, colour, price (yen), description
FISH = [
    ("clownfish", "ocellaris clownfish", "Amphiprion ocellaris", "light_red", 2400, "An orange fish with three white bands edged in black, and a habit of nosing every hand that comes near the glass."),
    ("blue_tang", "regal blue tang", "Paracanthurus hepatus", "light_blue", 5200, "A royal-blue disc with a black palette marking and a yellow tail.  Restless and graceful."),
    ("mandarinfish", "mandarinfish", "Synchiropus splendidus", "light_cyan", 9800, "A small, slow bottom-dweller in swirls of blue, orange and green.  Very hard to feed, very beautiful."),
    ("yellow_tang", "yellow tang", "Zebrasoma flavescens", "yellow", 3600, "A flat, bright-yellow grazer that glows under tank lights and patrols the same stretch of glass all day."),
    ("moorish_idol", "moorish idol", "Zanclus cornutus", "white", 14000, "A disc banded in black, white and yellow, with a long trailing dorsal fin.  Elegant and famously fragile."),
    ("emperor_angel", "emperor angelfish", "Pomacanthus imperator", "light_blue", 28000, "An adult emperor in blue and yellow stripes, with a dark mask over the eyes.  A show piece."),
    ("copperband", "copperband butterflyfish", "Chelmon rostratus", "light_red", 8400, "A silver-white fish with copper bands and a long snout for picking food from crevices."),
    ("longnose_bf", "longnose butterflyfish", "Forcipiger flavissimus", "yellow", 6200, "A yellow butterflyfish with a very long, narrow snout and a black cap."),
    ("lionfish", "red lionfish", "Pterois volitans", "red", 11500, "Banded in maroon and white, trailing venomous spines like feathers.  Handle only by the net."),
    ("chromis", "blue-green chromis", "Chromis viridis", "light_green", 1200, "A shimmering, pale-green schooling fish that stays tight to the reef."),
    ("blue_devil", "blue devil damselfish", "Chrysiptera cyanea", "blue", 1500, "An electric-blue damselfish with a bold, territorial streak."),
    ("tuskfish", "harlequin tuskfish", "Choerodon fasciatus", "light_red", 36000, "Orange-and-turquoise bands and bright blue teeth.  Intelligent, and prized by collectors."),
    ("pajama_cardinal", "pajama cardinalfish", "Sphaeramia nematoptera", "yellow", 2800, "A silvery, spotted fish with a black band, like an old-fashioned pair of pyjamas."),
    ("banggai", "Banggai cardinalfish", "Pterapogon kauderni", "white", 4600, "A silver fish with black stripes and a long, spined tail.  Gentle, and endangered in the wild."),
    ("flame_angel", "flame angelfish", "Centropyge loricula", "light_red", 9200, "A small flame-red dwarf angelfish barred in black, with blue edging on the fins."),
    ("lemonpeel", "lemonpeel angelfish", "Centropyge flavissima", "yellow", 5600, "A little, lemon-yellow angelfish with a blue ring around each eye."),
    ("bicolor_angel", "bicolor angelfish", "Centropyge bicolor", "light_blue", 3900, "A dwarf angelfish with a blue back half and a yellow front."),
    ("hawkfish", "longnose hawkfish", "Oxycirrhites typus", "light_red", 13500, "A slim, red-checked fish that perches on corals like a hawk on a branch."),
    ("clown_trigger", "clown triggerfish", "Balistoides conspicillum", "light_gray", 32000, "A bold black body spotted white, with a yellow mouth and orange lips.  Aggressive and magnificent."),
    ("picasso_trigger", "Picasso triggerfish", "Rhinecanthus aculeatus", "light_cyan", 7600, "A painted-looking triggerfish in strokes of blue, black and gold."),
    ("boxfish", "yellow boxfish", "Ostracion cubicus", "yellow", 6900, "A bright-yellow cube with black spots when young, fading to a calm blue-green in age."),
    ("sixline_wrasse", "six-line wrasse", "Pseudocheilinus hexataenia", "light_green", 2100, "A tiny orange wrasse with six blue-violet stripes, always darting between rocks."),
    ("ribbon_eel", "ribbon eel", "Rhinomuraena quaesita", "light_blue", 26000, "A long blue-and-yellow ribbon with flared nostrils.  It spends the day half out of its burrow."),
    ("seahorse", "spotted seahorse", "Hippocampus kuda", "brown", 18000, "A slow, tail-gripping seahorse with a dotted body that holds on to anything in the tank."),
]
FISH_IDX = {f[0]: i for i, f in enumerate(FISH)}
NAME = {f[0]: f[1] for f in FISH}

# portable tanks: id, name, capacity, price, volume (litres), description
TANKS = [
    ("bowl", "fish bowl", 1, 1800, "2 L", "A round glass bowl with a pebble floor and a tiny glowing plant.  Room for one fish."),
    ("cube", "cube aquarium", 2, 6500, "8 L", "A neat glass cube with a built-in blue light and filter.  Room for two fish."),
    ("long", "reef aquarium", 3, 19000, "20 L", "A slim reef aquarium with a coral rock and a glowing cyan light strip.  Room for three fish."),
]
# display themes: id, name, fish list
SMALL = [
    ("reef", "reef nano aquarium", ["clownfish", "chromis"]),
    ("mandarin", "mandarinfish aquarium", ["mandarinfish"]),
    ("hawk", "rock-pool aquarium", ["hawkfish", "sixline_wrasse"]),
    ("horse", "seahorse aquarium", ["seahorse", "pajama_cardinal"]),
    ("cardinal", "cardinalfish aquarium", ["banggai", "blue_devil", "clownfish"]),
    ("lemon", "angelfish aquarium", ["lemonpeel"]),
]
WIDE = [
    ("tang", "tang aquarium", ["blue_tang", "yellow_tang", "clownfish"]),
    ("emperor", "angelfish aquarium", ["emperor_angel", "copperband", "moorish_idol"]),
    ("lion", "lionfish aquarium", ["lionfish"]),
    ("trigger", "triggerfish aquarium", ["clown_trigger", "picasso_trigger", "boxfish"]),
    ("dwarf", "dwarf angelfish aquarium", ["flame_angel", "bicolor_angel", "lemonpeel"]),
    ("tusk", "deep reef aquarium", ["tuskfish", "ribbon_eel", "longnose_bf"]),
]


PETS = [("dog", "mon_trl_dog", "dog", 36000, "A well-bred, collared house dog with its papers.", "light_gray"),
        ("cat", "mon_trl_cat", "cat", 24000, "A sleek, vaccinated house cat with its papers.", "light_gray"),
        ("rabbit", "mon_trl_rabbit", "rabbit", 9000, "A soft, quiet house rabbit with its papers.", "white")]
