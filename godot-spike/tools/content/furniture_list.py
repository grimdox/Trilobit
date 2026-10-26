"""The new furniture and floors (placeholders until real sprites are drawn).  One row: id, label, category, walkable (seats, rails), low cover, colour.
Tile names are the ids; sprites are f_trl_<id> (furniture) and t_trl_<id> (floors).  None of them has stats or a function yet: they are scenery."""

FLOORS = [
    ("floor_concrete", "Bare concrete floor", "floor", "#8c8c90"), ("floor_dance", "Lit dance floor", "floor", "#3a1f5c"),
    ("floor_rubber", "Rubber gym floor", "floor", "#2c3138"), ("floor_mat", "Training mat", "floor", "#b8553c"),
    ("floor_carpet_grey", "Grey office carpet", "floor", "#6f7480"), ("floor_tile", "White bathroom tile", "floor", "#d9e4e8"),
    ("floor_lino", "Apartment linoleum", "floor", "#b9a98a"), ("floor_parquet", "Parquet flooring", "floor", "#a8794a"),
]

# (id, label, category, walk, cover, colour)
FURN = [
    # food and drink
    ("coffee_bar", "Coffee bar counter", "food", 0, 1, "#7a4a2a"), ("cafe_table", "Small cafe table", "food", 0, 1, "#c9a36a"),
    ("cafe_chair", "Cafe chair", "food", 1, 0, "#8a5a32"), ("coffee_machine", "Espresso machine", "food", 0, 0, "#6c7480"),
    ("bar_counter", "Bar counter", "food", 0, 1, "#5a3420"), ("booth_seat", "Booth seat", "food", 1, 0, "#7a2630"),
    ("jukebox", "Jukebox", "food", 0, 0, "#c0486a"), ("pool_table", "Pool table", "food", 0, 1, "#2f6a46"),
    ("card_table", "Card table", "food", 0, 1, "#3c5a40"), ("barrel", "Barrel", "food", 0, 1, "#6a4a2a"),
    ("crate_stack", "Stack of crates", "food", 0, 1, "#8a6a3a"), ("lounge_sofa", "Lounge sofa", "food", 1, 0, "#5a2a6a"),
    ("dj_booth", "DJ booth", "food", 0, 1, "#2a2f3a"), ("speaker_stack", "Speaker stack", "food", 0, 0, "#202226"),
    ("bakery_case", "Bakery display case", "food", 0, 1, "#d8b080"), ("bread_rack", "Bread rack", "food", 0, 1, "#b88a52"),
    ("karaoke_booth", "Karaoke booth", "food", 0, 1, "#d04a9a"),
    # retail
    ("clothing_rack", "Clothing rack", "retail", 0, 1, "#9a5a8a"), ("mannequin", "Mannequin", "retail", 0, 0, "#d8d0c4"),
    ("shoe_wall", "Shoe wall", "retail", 0, 0, "#7a6a5a"), ("mirror", "Standing mirror", "retail", 0, 0, "#a8c8d8"),
    ("display_case", "Glass display case", "retail", 0, 1, "#8ab0c0"), ("electronics_shelf", "Electronics shelf", "retail", 0, 1, "#3a4a5a"),
    ("tv_wall", "Wall of screens", "retail", 0, 0, "#16202a"), ("office_shelf", "Stationery shelf", "retail", 0, 1, "#9aa6b0"),
    ("copier", "Copier", "retail", 0, 0, "#c8ccd2"), ("filing_cabinet", "Filing cabinet", "retail", 0, 1, "#7a8088"),
    ("weapon_rack", "Practice-weapon rack", "retail", 0, 1, "#6a4a30"), ("training_dummy", "Training dummy", "retail", 0, 1, "#b08a58"),
    ("punching_bag", "Punching bag", "retail", 0, 0, "#8a2a2a"), ("pawn_cage", "Pawn counter cage", "retail", 0, 1, "#6a6a70"),
    ("safe", "Safe", "retail", 0, 1, "#3a3d44"), ("gun_rack", "Gun rack", "retail", 0, 0, "#2a2a2e"),
    ("hardware_rack", "Hardware rack", "retail", 0, 1, "#7a7a60"), ("tool_wall", "Pegboard tool wall", "retail", 0, 0, "#9a8a6a"),
    ("lumber_stack", "Lumber stack", "retail", 0, 1, "#b08a50"), ("pharmacy_shelf", "Pharmacy shelf", "retail", 0, 1, "#d8e8e0"),
    ("scale", "Parcel scale", "retail", 0, 0, "#9aa0a8"), ("bookshelf", "Bookshelf", "retail", 0, 1, "#6a4428"),
    ("armchair", "Armchair", "retail", 1, 0, "#6a4a3a"), ("car_plinth", "Car display plinth", "retail", 1, 0, "#aab0b8"),
    ("tire_rack", "Tyre rack", "retail", 0, 1, "#25262a"), ("desk", "Desk", "retail", 0, 1, "#8a7a68"),
    ("lift_hoist", "Vehicle lift", "retail", 0, 1, "#d0a020"), ("tool_chest", "Tool chest", "retail", 0, 1, "#b0302a"),
    ("workbench", "Workbench", "retail", 0, 1, "#7a6a50"),
    # services
    ("teller_window", "Teller window", "service", 0, 1, "#8a9aa8"), ("queue_rail", "Queue rail", "service", 1, 0, "#a8a8b0"),
    ("deposit_boxes", "Safe-deposit boxes", "service", 0, 0, "#9a8a50"), ("atm", "Cash machine", "service", 0, 0, "#3a5a7a"),
    ("vault_door", "Vault door", "service", 0, 0, "#4a4e56"), ("police_desk", "Front desk (police)", "service", 0, 1, "#3a4a6a"),
    ("holding_cell", "Holding cell bars", "service", 0, 0, "#5a5e66"), ("evidence_locker", "Evidence lockers", "service", 0, 0, "#6a7078"),
    ("notice_board", "Notice board", "service", 0, 0, "#a8864a"), ("service_window", "Service window", "service", 0, 1, "#7a9a9a"),
    ("waiting_bench", "Waiting bench", "service", 1, 0, "#6a6e78"), ("parcel_shelf", "Parcel shelf", "service", 0, 1, "#a8946a"),
    ("mail_sorter", "Mail sorter", "service", 0, 1, "#7a8a9a"), ("parcel_trolley", "Parcel trolley", "service", 0, 1, "#8a8a90"),
    ("key_rack", "Key rack", "service", 0, 0, "#8a6a30"), ("luggage_cart", "Luggage cart", "service", 0, 1, "#c0a040"),
    ("lobby_sofa", "Lobby sofa", "service", 1, 0, "#4a5a6a"), ("capsule_bed", "Capsule bed", "service", 1, 0, "#d8dce0"),
    ("treadmill", "Treadmill", "service", 0, 1, "#30343c"), ("weight_bench", "Weight bench", "service", 1, 0, "#4a4a52"),
    ("squat_rack", "Squat rack", "service", 0, 1, "#2a2a30"), ("dumbbell_rack", "Dumbbell rack", "service", 0, 0, "#40444c"),
    ("locker", "Lockers", "service", 0, 0, "#6a8aa0"), ("shoe_shelf", "Shoe shelf", "service", 0, 0, "#8a7a68"),
    ("barber_chair", "Barber chair", "service", 0, 1, "#a02a3a"), ("salon_sink", "Salon sink", "service", 0, 0, "#d8e0e8"),
    ("salon_mirror", "Salon mirror wall", "service", 0, 0, "#b0d0e0"), ("hair_dryer", "Hair-dryer chair", "service", 0, 1, "#c880a0"),
    ("washing_machine", "Washing machine", "service", 0, 1, "#d8dde2"), ("dryer", "Tumble dryer", "service", 0, 1, "#c8ccd2"),
    ("folding_table", "Folding table", "service", 0, 1, "#b8b8c0"), ("arcade_cabinet", "Arcade cabinet", "service", 0, 0, "#2a2a6a"),
    ("pachinko_machine", "Pachinko machine", "service", 0, 0, "#c04aa0"), ("claw_machine", "Claw machine", "service", 0, 1, "#40a0c0"),
    # industry
    ("pallet_rack", "Pallet rack", "industry", 0, 1, "#d08a20"), ("pallet_stack", "Stacked pallets", "industry", 0, 1, "#a8844a"),
    ("conveyor", "Conveyor belt", "industry", 0, 1, "#4a4e56"), ("parts_bin", "Parts bin", "industry", 0, 1, "#5a7a9a"),
    ("lathe", "Lathe", "industry", 0, 1, "#5a6a5a"), ("mill", "Milling machine", "industry", 0, 1, "#6a7a6a"),
    ("scrap_pile", "Pile of scrap", "industry", 0, 1, "#7a5a40"), ("baler", "Scrap baler", "industry", 0, 1, "#8a3a2a"),
    ("shredder", "Metal shredder", "industry", 0, 1, "#4a3a3a"), ("press_machine", "Stamping press", "industry", 0, 1, "#3a5a6a"),
    # homes
    ("bed_single", "Single bed", "home", 1, 0, "#b0c0d8"), ("bed_double", "Double bed", "home", 1, 0, "#c8a0b8"),
    ("bunk_bed", "Bunk bed", "home", 1, 0, "#8a9ab0"), ("wardrobe", "Wardrobe", "home", 0, 1, "#7a5a40"),
    ("dresser", "Chest of drawers", "home", 0, 1, "#8a6a48"), ("sofa", "Sofa", "home", 1, 0, "#6a7a8a"),
    ("coffee_table", "Coffee table", "home", 0, 1, "#9a7a58"), ("tv_stand", "TV on a stand", "home", 0, 0, "#2a2e36"),
    ("kitchen_counter", "Kitchen counter", "home", 0, 1, "#b8b4a8"), ("kitchen_sink", "Kitchen sink", "home", 0, 1, "#c0c8d0"),
    ("toilet", "Toilet", "home", 0, 0, "#e8eef0"), ("shower", "Shower stall", "home", 0, 0, "#a8d0e0"),
    ("bathtub", "Bathtub", "home", 0, 1, "#e0eaf0"), ("kotatsu", "Kotatsu table", "home", 0, 1, "#a05a3a"),
    ("futon", "Futon", "home", 1, 0, "#d0c8b8"), ("home_shrine", "Household altar", "home", 0, 0, "#6a4a2a"),
    ("shoe_rack", "Shoe rack by the door", "home", 0, 0, "#8a7a6a"),
    # offices
    ("desk_workstation", "Workstation desk", "office", 0, 1, "#9aa0a8"), ("desk_executive", "Executive desk", "office", 0, 1, "#5a3a28"),
    ("office_chair", "Office chair", "office", 1, 0, "#3a3e46"), ("meeting_table", "Meeting table", "office", 0, 1, "#8a7a68"),
    ("server_rack", "Server rack", "office", 0, 1, "#22262c"), ("cubicle_divider", "Cubicle divider", "office", 0, 1, "#8a9ab0"),
    ("whiteboard", "Whiteboard", "office", 0, 0, "#e8ecf0"), ("mailboxes", "Wall of mailboxes", "office", 0, 0, "#8a8e96"),
    ("directory_board", "Lobby directory", "office", 0, 0, "#2a3a4a"),
]
