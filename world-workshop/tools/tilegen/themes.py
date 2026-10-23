"""The five tilesets as data: each theme maps material roles to a mid colour and how the material takes light, and
sets how worn, planted and lit its world is.  Builders (terrain.py, walls.py, furniture.py, props.py) only ever name
roles ('wall', 'trim', 'walk', 'road', 'metal', 'neon_a'), so one builder draws a counter in brass and marble
downtown and in chipped laminate in the slums.

Material keys: mid (shade 3), contrast (ramp spread), gloss (glints), rough (texture noise), rim (cyan back light on
object edges), bias (shade offset for flat surfaces), glow (emissive).  Adding a sixth theme: copy one, change it, add
it to THEMES; every tile id is drawn for it by the next bake.
"""
import color

# materials every theme shares unless it overrides them
COMMON = {
    'ink': dict(mid='#2a2433', contrast=0.6),
    'steel': dict(mid='#7c8592', gloss=0.8, rim=1.0),
    'chrome': dict(mid='#a9b3bf', gloss=1.0, rim=1.0, contrast=1.3),
    'dark_steel': dict(mid='#4a505c', gloss=0.6, rim=1.0),
    'rubber': dict(mid='#2e2f36', contrast=0.7, rim=0.6),
    'plastic_w': dict(mid='#c9ccd2', gloss=0.4, rim=0.8),
    'plastic_r': dict(mid='#a8404a', gloss=0.4, rim=0.8),
    'plastic_b': dict(mid='#3a5f8e', gloss=0.4, rim=0.8),
    'screen': dict(mid='#1d2a38', gloss=0.9, rim=0.4),
    'glass': dict(mid='#5f8fa8', gloss=1.0, rim=1.0, contrast=0.8),
    'wood': dict(mid='#8a5a36', rough=0.3, rim=0.6),
    'wood_dark': dict(mid='#4e3324', rough=0.3, rim=0.6),
    'wood_light': dict(mid='#c69a64', rough=0.25, rim=0.6),
    'lacquer_red': dict(mid='#9a2e2a', gloss=0.7, rim=0.8),
    'lacquer_black': dict(mid='#2a2228', gloss=0.7, rim=0.9),
    'paper': dict(mid='#e2dccb', contrast=0.6, rim=0.3),
    'fabric_r': dict(mid='#8e2f3a', rim=0.5),
    'fabric_b': dict(mid='#34507a', rim=0.5),
    'fabric_g': dict(mid='#4f6e4a', rim=0.5),
    'linen': dict(mid='#d8d6d0', contrast=0.7, rim=0.4),
    'stone': dict(mid='#8d8a86', rough=0.5, rim=0.5),
    'stone_dark': dict(mid='#5b5a5d', rough=0.5, rim=0.5),
    'brass': dict(mid='#b08a3e', gloss=0.9, rim=0.8),
    'gold': dict(mid='#c9a13a', gloss=1.0, rim=0.8),
    'copper': dict(mid='#a5623a', gloss=0.8, rim=0.8),
    'leaf': dict(mid='#4f7a3a', rough=0.6, rim=0.7),
    'leaf_dark': dict(mid='#2f5230', rough=0.6, rim=0.7),
    'blossom': dict(mid='#e3a3b8', rough=0.5, rim=0.6),
    'bark': dict(mid='#5a3f2c', rough=0.5, rim=0.5),
    'soil': dict(mid='#5b4434', rough=0.6),
    'grass': dict(mid='#4f7d3a', rough=0.25),
    'grass_dry': dict(mid='#8a8146', rough=0.7),
    'sand': dict(mid='#c8b080', rough=0.5),
    'gravel': dict(mid='#8a8682', rough=0.8),
    'rock': dict(mid='#77736f', rough=0.6, rim=0.6),
    'rock_red': dict(mid='#9a5a3e', rough=0.6, rim=0.6),
    'water': dict(mid='#2f6a8a', gloss=1.0, contrast=0.8),
    'water_murk': dict(mid='#3d4a36', gloss=0.7, contrast=0.7),
    'foam': dict(mid='#b9c4b8', contrast=0.5),
    'paint_y': dict(mid='#d6b23a', rim=0.4),
    'paint_w': dict(mid='#d9dadc', contrast=0.6, rim=0.4),
    'hazard_y': dict(mid='#d6a82a', rim=0.6),
    'hazard_k': dict(mid='#2c2a2e', rim=0.6),
    'rust': dict(mid='#8a4a2a', rough=0.8, rim=0.5),
    'moss': dict(mid='#4e6a34', rough=0.8, rim=0.4),
    'grime': dict(mid='#4a4640', rough=0.6),
    'oil': dict(mid='#22232a', gloss=1.0, contrast=0.6),
    'spill_g': dict(mid='#6fae3a', gloss=0.9, contrast=0.7),
    'red_cross': dict(mid='#c03a3a', rim=0.3),
    'icon_gold': dict(mid='#c69a3a', gloss=0.9, rim=0.6),
    'tatami': dict(mid='#b8b073', rough=0.4),
    'carpet_red': dict(mid='#8e2a30', rough=0.4),
    'checker_w': dict(mid='#d8d8d6', contrast=0.6, gloss=0.4),
    'checker_k': dict(mid='#2c2c30', contrast=0.6, gloss=0.4),
    'container_r': dict(mid='#9a3a2e', rim=0.8),
    'container_b': dict(mid='#2e5a86', rim=0.8),
    'container_g': dict(mid='#3e6e48', rim=0.8),
    'container_o': dict(mid='#c06a2a', rim=0.8),
    'tank_w': dict(mid='#c8ccd0', gloss=0.5, rim=1.0),
    'rail': dict(mid='#6a6460', gloss=0.6, rim=0.6),
    'sleeper': dict(mid='#5a4636', rough=0.4),
    'fur_dog': dict(mid='#8a6440', rim=0.6),
    'fur_cat': dict(mid='#6e6a66', rim=0.6),
    # food and goods (item icons)
    'rice': dict(mid='#e6e2d6', contrast=0.55, rim=0.4),
    'noodle': dict(mid='#dcbc6a', contrast=0.7, rim=0.4),
    'broth': dict(mid='#b0783a', gloss=0.7, contrast=0.7),
    'broth_red': dict(mid='#9a2a3a', gloss=0.7, contrast=0.7),
    'meat': dict(mid='#8a4a2e', rough=0.4, rim=0.5),
    'meat_fried': dict(mid='#c08a3e', rough=0.5, rim=0.5),
    'fish_pink': dict(mid='#e2846e', gloss=0.4, rim=0.5),
    'fish_silver': dict(mid='#9aa6b0', gloss=0.8, rim=0.7),
    'eel': dict(mid='#6a3a1e', gloss=0.8, rim=0.5),
    'egg': dict(mid='#eebc3e', gloss=0.4, rim=0.4),
    'nori': dict(mid='#1e2a24', contrast=0.6, rim=0.5),
    'dough': dict(mid='#e8d4a8', contrast=0.6, rim=0.4),
    'crust': dict(mid='#b8783a', rough=0.4, rim=0.5),
    'bread_dark': dict(mid='#5a3a26', rough=0.5, rim=0.5),
    'lettuce': dict(mid='#6aa040', rough=0.4, rim=0.5),
    'tomato': dict(mid='#c83a2a', gloss=0.5, rim=0.5),
    'cheese': dict(mid='#e8c050', rim=0.4),
    'chocolate': dict(mid='#4e2c20', gloss=0.4, rim=0.6),
    'cream': dict(mid='#ece2cc', contrast=0.6, rim=0.4),
    'caviar': dict(mid='#2e1a1a', gloss=1.0, contrast=0.6),
    'beet': dict(mid='#8a2044', rim=0.5),
    'apple_r': dict(mid='#b8302a', gloss=0.6, rim=0.6),
    'orange_f': dict(mid='#e88a2a', rough=0.3, rim=0.6),
    'banana_y': dict(mid='#e6cc48', rim=0.5),
    'milk': dict(mid='#eeeeea', contrast=0.55, rim=0.4),
    'tea_green': dict(mid='#9aac58', gloss=0.6),
    'tea_amber': dict(mid='#b87a3a', gloss=0.6),
    'coffee': dict(mid='#4e3220', gloss=0.6),
    'cola_d': dict(mid='#3a1a14', gloss=0.8),
    'beer_a': dict(mid='#d4983a', gloss=0.8, contrast=0.8),
    'kvass_b': dict(mid='#6a3a1e', gloss=0.8),
    'berry': dict(mid='#8a2a4a', gloss=0.7),
    'clear': dict(mid='#c8dce4', gloss=1.0, contrast=0.6),
    'gel_b': dict(mid='#4ab0d8', gloss=0.9),
    'glucose': dict(mid='#f2f0ea', contrast=0.5, rim=0.4),
    'protein': dict(mid='#8a7a5a', rough=0.3, rim=0.5),
    'card_k': dict(mid='#2a2f3c', gloss=0.8, rim=1.0),
    'note_g': dict(mid='#6a9a6a', rim=0.4),
    'brass_case': dict(mid='#c09a42', gloss=1.0, rim=0.7),
    'copper_tip': dict(mid='#b8683a', gloss=0.9, rim=0.6),
    'shell_red': dict(mid='#b03a32', gloss=0.5, rim=0.6),
    'olive_d': dict(mid='#56603a', rim=0.6),
    'kraft': dict(mid='#b98a52', rough=0.3, rim=0.5),
    'canvas_bag': dict(mid='#5a6248', rough=0.3, rim=0.6),
    'kevlar': dict(mid='#3e4436', rough=0.2, rim=0.8),
    'wax': dict(mid='#e8dcb8', contrast=0.6, rim=0.4),
    'silk_r': dict(mid='#b83a3a', gloss=0.5, rim=0.6),
    'silk_b': dict(mid='#3a5aa8', gloss=0.5, rim=0.6),
    # light
    'neon_cyan': dict(mid='#3fd8f0', glow=True),
    'neon_pink': dict(mid='#f04aa8', glow=True),
    'neon_violet': dict(mid='#9a5af0', glow=True),
    'neon_green': dict(mid='#4af07a', glow=True),
    'neon_amber': dict(mid='#f0a83a', glow=True),
    'neon_red': dict(mid='#f04a4a', glow=True),
    'lamp': dict(mid='#ffe3a0', glow=True),
    'lamp_cold': dict(mid='#cfefff', glow=True),
    'lamp_dead': dict(mid='#4a4c52', gloss=0.6, rim=0.6),
    'screen_glow': dict(mid='#3fbfe0', glow=True),
    'portal_glow': dict(mid='#8a6af0', glow=True),
    'fire': dict(mid='#f08a2a', glow=True),
}

THEMES = {
    # ------------------------------------------------------------------------------------------------ 1 downtown
    'rich': dict(
        name='Downtown (rich)', desc='white marble and sleek metal, glass everywhere, trees and planting, spotless',
        wear=0.0, cracks=0.0, grime=0.0, litter=0.0, moss=0.0, rust=0.0, plants=0.9, lights=1.0, neon=('neon_cyan', 'lamp_cold'),
        mats={
            'walk': dict(mid='#cfcbc4', contrast=0.55, rough=0.15, bias=0),
            'walk2': dict(mid='#b4b0aa', contrast=0.55, rough=0.15),
            'inlay': dict(mid='#3fb5c8', gloss=0.6, contrast=0.7),
            'road': dict(mid='#3c4150', contrast=0.6, rough=0.2),
            'kerb': dict(mid='#d9d6d0', contrast=0.6, gloss=0.4, rim=0.8),
            'floor': dict(mid='#dcd9d4', contrast=0.5, gloss=0.6),
            'floor2': dict(mid='#c2beb8', contrast=0.5, gloss=0.6),
            'vein': dict(mid='#b9b7b6', contrast=0.4),
            'wall': dict(mid='#eceae6', contrast=0.6, gloss=0.4, rim=1.0, bias=1),
            'wall_side': dict(mid='#4a505c', contrast=0.8, gloss=0.6, rim=1.0),
            'trim': dict(mid='#a9b3bf', gloss=1.0, rim=1.0, contrast=1.2),
            'roof': dict(mid='#8e97a6', gloss=0.5, rim=0.8),
            'door': dict(mid='#3a3530', gloss=0.6, rim=1.0),
            'door_trim': dict(mid='#c9a13a', gloss=1.0, rim=0.8),
            'body': dict(mid='#d6d3ce', gloss=0.5, rim=1.0),
            'body2': dict(mid='#3a3d46', gloss=0.6, rim=1.0),
            'top': dict(mid='#e8e5e0', gloss=0.7, rim=1.0),
            'accent': dict(mid='#c9a13a', gloss=1.0, rim=0.8),
            'grass': dict(mid='#4e8a3e', rough=0.25),
            'water': dict(mid='#2f8aa0', gloss=1.0, contrast=0.8),
            'concrete': dict(mid='#c4c1bc', contrast=0.55, rough=0.15),
            'metalfloor': dict(mid='#8e98a6', gloss=0.7),
        }),
    # ------------------------------------------------------------------------------------------------ 2 mid-town
    'mid': dict(
        name='Mid-town', desc='clean functional concrete and mixed stone, neon and working lights, pruned trees',
        wear=0.25, cracks=0.15, grime=0.08, litter=0.02, moss=0.02, rust=0.03, plants=0.5, lights=1.0, neon=('neon_pink', 'neon_cyan', 'lamp'),
        mats={
            'walk': dict(mid='#9a9894', contrast=0.65, rough=0.3),
            'walk2': dict(mid='#85837f', contrast=0.65, rough=0.3),
            'inlay': dict(mid='#7a6a5a', contrast=0.6),
            'road': dict(mid='#3a3b42', contrast=0.65, rough=0.35),
            'kerb': dict(mid='#a8a6a2', contrast=0.6, rim=0.8),
            'floor': dict(mid='#a3a09a', contrast=0.6, rough=0.2),
            'floor2': dict(mid='#8f8c86', contrast=0.6, rough=0.2),
            'vein': dict(mid='#7a7874', contrast=0.5),
            'wall': dict(mid='#a8a59f', contrast=0.65, rough=0.25, rim=1.0, bias=1),
            'wall_side': dict(mid='#76736f', contrast=0.65, rim=1.0),
            'trim': dict(mid='#5e646e', gloss=0.6, rim=1.0),
            'roof': dict(mid='#6a6e76', rough=0.3, rim=0.8),
            'door': dict(mid='#5a6270', gloss=0.4, rim=1.0),
            'door_trim': dict(mid='#8e98a6', gloss=0.8, rim=0.8),
            'body': dict(mid='#8e939c', gloss=0.4, rim=1.0),
            'body2': dict(mid='#4a4f5a', gloss=0.4, rim=1.0),
            'top': dict(mid='#a8aab0', gloss=0.4, rim=1.0),
            'accent': dict(mid='#3fb5c8', gloss=0.6, rim=0.8),
            'grass': dict(mid='#4f7d3a', rough=0.25),
            'water': dict(mid='#3a6a7e', gloss=0.9, contrast=0.8),
            'concrete': dict(mid='#8f8d89', contrast=0.6, rough=0.3),
            'metalfloor': dict(mid='#757c88', gloss=0.6),
        }),
    # ------------------------------------------------------------------------------------------------ 3 slums
    'slum': dict(
        name='Slums', desc='old concrete and rickety sheet metal, cracks, stains, spills, weak or broken lights, neon',
        wear=0.85, cracks=0.7, grime=0.45, litter=0.25, moss=0.15, rust=0.5, plants=0.25, lights=0.45,
        neon=('neon_pink', 'neon_green', 'neon_violet', 'neon_red'),
        mats={
            'walk': dict(mid='#77736c', contrast=0.7, rough=0.6),
            'walk2': dict(mid='#65615a', contrast=0.7, rough=0.6),
            'inlay': dict(mid='#5a544c', contrast=0.6),
            'road': dict(mid='#34343a', contrast=0.7, rough=0.6),
            'kerb': dict(mid='#7e7a72', contrast=0.65, rough=0.5, rim=0.6),
            'floor': dict(mid='#7a7166', contrast=0.65, rough=0.5),
            'floor2': dict(mid='#686056', contrast=0.65, rough=0.5),
            'vein': dict(mid='#4e4a44', contrast=0.5),
            'wall': dict(mid='#857868', contrast=0.7, rough=0.6, rim=0.8, bias=1),
            'wall_side': dict(mid='#5a5048', contrast=0.7, rim=0.8),
            'trim': dict(mid='#6a4a36', rough=0.7, rim=0.6),
            'roof': dict(mid='#6e5a4a', rough=0.7, rim=0.6),
            'door': dict(mid='#4e6a5a', rough=0.6, rim=0.8),
            'door_trim': dict(mid='#8a4a2a', rough=0.8, rim=0.6),
            'body': dict(mid='#7d8a86', rough=0.5, rim=0.8),
            'body2': dict(mid='#4e4842', rough=0.5, rim=0.8),
            'top': dict(mid='#8e8476', rough=0.5, rim=0.8),
            'accent': dict(mid='#c0507a', rim=0.6),
            'grass': dict(mid='#6e7a3e', rough=0.25),
            'water': dict(mid='#3e5048', gloss=0.7, contrast=0.7),
            'concrete': dict(mid='#6e6a64', contrast=0.7, rough=0.6),
            'metalfloor': dict(mid='#6a645e', rough=0.6, gloss=0.3),
        }),
    # ------------------------------------------------------------------------------------------------ 4 rural
    'rural': dict(
        name='Rural', desc='outside the city: timber and plaster houses, dirt roads, wild grass, pines and birches',
        wear=0.4, cracks=0.2, grime=0.1, litter=0.0, moss=0.35, rust=0.15, plants=0.8, lights=0.5, neon=('lamp',),
        mats={
            'walk': dict(mid='#8a7458', contrast=0.65, rough=0.7),
            'walk2': dict(mid='#9a9086', contrast=0.6, rough=0.5),
            'inlay': dict(mid='#6e6a5e', contrast=0.6),
            'road': dict(mid='#7a6248', contrast=0.65, rough=0.8),
            'kerb': dict(mid='#8a8478', contrast=0.6, rough=0.5),
            'floor': dict(mid='#b08a5a', contrast=0.6, rough=0.3),
            'floor2': dict(mid='#9a7448', contrast=0.6, rough=0.3),
            'vein': dict(mid='#7a5a3a', contrast=0.5),
            'wall': dict(mid='#d8cfbc', contrast=0.6, rough=0.3, rim=0.6),
            'wall_side': dict(mid='#4a3426', contrast=0.65, rim=0.6),
            'trim': dict(mid='#4a3426', rough=0.4, rim=0.6),
            'roof': dict(mid='#4e5258', rough=0.4, rim=0.6),
            'door': dict(mid='#8a6038', rough=0.3, rim=0.6),
            'door_trim': dict(mid='#4a3426', rough=0.3, rim=0.6),
            'body': dict(mid='#8a6038', rough=0.3, rim=0.6),
            'body2': dict(mid='#4a3426', rough=0.3, rim=0.6),
            'top': dict(mid='#a47a4a', rough=0.3, rim=0.6),
            'accent': dict(mid='#9a2e2a', gloss=0.6, rim=0.6),
            'grass': dict(mid='#5a8040', rough=0.25),
            'water': dict(mid='#3a7080', gloss=0.9, contrast=0.8),
            'concrete': dict(mid='#8a857c', contrast=0.65, rough=0.6),
            'metalfloor': dict(mid='#6e6a64', rough=0.5),
        }),
    # ------------------------------------------------------------------------------------------------ 5 industry, port, sewers
    'industry': dict(
        name='Industry and sewers', desc='steel plate, bulkheads and bars, tanks, containers, machinery, hazard paint, rust, moss, murky water',
        wear=0.6, cracks=0.35, grime=0.35, litter=0.05, moss=0.3, rust=0.55, plants=0.1, lights=0.85, neon=('neon_amber', 'neon_cyan', 'lamp_cold'),
        mats={
            'walk': dict(mid='#6e7178', contrast=0.65, gloss=0.4, rough=0.3),
            'walk2': dict(mid='#5e6168', contrast=0.65, gloss=0.4, rough=0.3),
            'inlay': dict(mid='#d6a82a', contrast=0.6),
            'road': dict(mid='#4a4a4c', contrast=0.65, rough=0.5),
            'kerb': dict(mid='#d6a82a', contrast=0.6, rim=0.6),
            'floor': dict(mid='#6a6e74', contrast=0.65, gloss=0.4),
            'floor2': dict(mid='#5a5e64', contrast=0.65, gloss=0.4),
            'vein': dict(mid='#3e4046', contrast=0.5),
            'wall': dict(mid='#6a7078', contrast=0.7, gloss=0.4, rim=1.0, bias=1),
            'wall_side': dict(mid='#41454c', contrast=0.7, rim=1.0),
            'trim': dict(mid='#d6a82a', rim=0.8),
            'roof': dict(mid='#50555c', gloss=0.3, rim=0.8),
            'door': dict(mid='#4a5058', gloss=0.6, rim=1.0),
            'door_trim': dict(mid='#d6a82a', rim=0.8),
            'body': dict(mid='#5e646c', gloss=0.5, rim=1.0),
            'body2': dict(mid='#3a3e44', gloss=0.5, rim=1.0),
            'top': dict(mid='#6e747c', gloss=0.5, rim=1.0),
            'accent': dict(mid='#d6a82a', rim=0.8),
            'grass': dict(mid='#56663a', rough=0.25),
            'water': dict(mid='#3e4a34', gloss=0.7, contrast=0.7),
            'concrete': dict(mid='#6a6864', contrast=0.65, rough=0.5),
            'metalfloor': dict(mid='#60666e', gloss=0.6),
        }),
}

ORDER = ['rich', 'mid', 'slum', 'rural', 'industry']


class Mats:
    """material lookup for one theme: name -> {ramp (8 hex colours), gloss, rough, rim, bias, glow}"""

    def __init__(self, theme):
        self.theme = theme
        self.cache = {}

    def __call__(self, name):
        if name in self.cache:
            return self.cache[name]
        spec = THEMES[self.theme]['mats'].get(name) or COMMON.get(name)
        if spec is None:
            raise KeyError('material %r is not defined for theme %r' % (name, self.theme))
        if spec.get('glow'):
            r = color.glow_ramp(spec['mid'])
        else:
            r = color.ramp(spec['mid'], contrast=spec.get('contrast', 1.0))
        d = dict(spec, ramp=r)
        self.cache[name] = d
        return d


def style(theme):
    return THEMES[theme]
