"""The catalogue as data: garments (parts, layer group, level, colour slots) and outfits (garments plus colours).

Garment levels inside each layer group: 0 underwear, 1 legwear, 2 footwear, 3 shirt / suit, 4 jacket / coat,
5 armour, 6 straps and harness, 7 headwear.  Colour slots are the palette materials a garment uses; an outfit or the
creator picks the colour of each slot, so one garment serves many looks.

Game ids: every DollSpec layer of the game (outfits thug, nap, nasim, suit, labcoat, chef, priest, kannushi, overalls,
courier, jacket_0..5 and worn items coat, vest, vest_heavy, vest_corp, jacket, bracers, bracers_heavy, greaves,
greaves_heavy, kneepads, backpack, holster, helmet_ball, visor, helm_tac, balaclava) has an outfit or garment here.
"""

G = {}


def g(id, name, level, parts, fem=None, male=None, back=False, hides_hair=False, hides_face=False, tags=()):
    G[id] = dict(id=id, name=name, level=level, parts=parts, fem=fem, male=male, back=back, hides_hair=hides_hair,
                 hides_face=hides_face, tags=list(tags))


# --------------------------------------------------------------------------------------------- underwear
g('under', 'Underwear', 0, [dict(type='legs', mat='under', t=0.22, len='short', top='hip')],
  fem=[dict(type='legs', mat='under', t=0.2, len='short', top='hip'),
       dict(type='torso', mat='under', t=0.22, top='crew', bottom='chest', arms=False)])

# --------------------------------------------------------------------------------------------- base layer
g('bodysuit', 'Tactical bodysuit', 3, [dict(type='torso', mat='cloth1', t=0.2, top='high', bottom='crotch', seam=True),
                                       dict(type='sleeves', mat='cloth1', t=0.18, len='long'),
                                       dict(type='legs', mat='cloth1', t=0.25, len='long', top='hip')], tags=('base', 'tactical'))
g('tank', 'Tank top', 3, [dict(type='torso', mat='cloth1', t=0.24, top='scoop', bottom='hip', arms=False)], tags=('base',))
g('tee', 'T-shirt', 3, [dict(type='torso', mat='cloth1', t=0.3, top='crew', bottom='hip'),
                        dict(type='sleeves', mat='cloth1', t=0.3, len='short')], tags=('base',))
g('turtleneck', 'Turtleneck', 3, [dict(type='torso', mat='cloth1', t=0.3, top='high', bottom='hip'),
                                  dict(type='sleeves', mat='cloth1', t=0.28, len='long', cuff='cloth1')], tags=('base',))
g('shirt', 'Shirt', 3, [dict(type='torso', mat='cloth1', t=0.32, top='v', bottom='hip', seam=True),
                        dict(type='sleeves', mat='cloth1', t=0.3, len='long', cuff='cloth1'),
                        dict(type='collar', mat='cloth1', h=1.0, t=0.3, open=True)], tags=('base',))
g('cargo', 'Cargo trousers', 1, [dict(type='legs', mat='cloth3', t=0.45, len='long', loose=0.5),
                                 dict(type='pocket', mat='cloth3', at='thigh_r'), dict(type='pocket', mat='cloth3', at='thigh_l'),
                                 dict(type='belt', mat='leather', y='waist', buckle='metal')], tags=('legs',))
g('slacks', 'Slacks', 1, [dict(type='legs', mat='cloth3', t=0.35, len='long', loose=0.15), dict(type='belt', mat='leather', y='waist', w=1.0)],
  tags=('legs',))
g('leggings', 'Leggings', 1, [dict(type='legs', mat='cloth3', t=0.18, len='long', top='waist')], tags=('legs',))
g('shorts', 'Shorts', 1, [dict(type='legs', mat='cloth3', t=0.4, len='knee', loose=0.6)], tags=('legs',))
g('skirt', 'Skirt', 1, [dict(type='skirt', mat='cloth3', t=0.4, len='thigh', flare=0.8, open=False)], tags=('legs',))

g('boots', 'Combat boots', 2, [dict(type='boots', mat='leather', t=0.55, height='mid', sole='dark')], tags=('feet',))
g('boots_high', 'High boots', 2, [dict(type='boots', mat='leather', t=0.45, height='knee', sole='dark')], tags=('feet',))
g('sneakers', 'Trainers', 2, [dict(type='boots', mat='cloth4', t=0.45, height='ankle', sole='under')], tags=('feet',))

# --------------------------------------------------------------------------------------------- outer layer
g('bomber', 'Bomber jacket', 4, [dict(type='torso', mat='cloth2', t=0.7, top='crew', bottom='hip', open=2.6, loose=0.35),
                                 dict(type='sleeves', mat='cloth2', t=0.6, len='long', cuff='cloth4', loose=0.3),
                                 dict(type='collar', mat='cloth4', h=1.4, t=0.5, open=True)], tags=('outer',))
g('trench', 'Trench coat', 4, [dict(type='torso', mat='cloth2', t=0.75, top='v', bottom='hip', open=2.2, loose=0.3),
                               dict(type='sleeves', mat='cloth2', t=0.65, len='long', loose=0.35),
                               dict(type='skirt', mat='cloth2', t=0.6, len='knee', flare=2.2, open=True, gap=1.8),
                               dict(type='collar', mat='cloth2', h=2.6, t=0.6, open=True),
                               dict(type='belt', mat='cloth2', y='waist', w=1.2)], tags=('outer',))
g('suit_jacket', 'Suit jacket', 4, [dict(type='torso', mat='cloth2', t=0.6, top='v', bottom='hip', open=1.4, loose=0.2),
                                    dict(type='sleeves', mat='cloth2', t=0.55, len='long', loose=0.2),
                                    dict(type='collar', mat='cloth2', h=1.2, t=0.5, open=True)], tags=('outer',))
g('hoodie', 'Hoodie', 4, [dict(type='torso', mat='cloth2', t=0.65, top='crew', bottom='hip', loose=0.5),
                          dict(type='sleeves', mat='cloth2', t=0.6, len='long', cuff='cloth2', loose=0.4),
                          dict(type='hood', mat='cloth2', up=False)], tags=('outer',))
g('hood_up', 'Hood (up)', 7, [dict(type='hood', mat='cloth2', t=0.7, up=True)], hides_hair=True, tags=('head',))
g('labcoat', 'Lab coat', 4, [dict(type='torso', mat='cloth2', t=0.6, top='v', bottom='hip', open=2.0, loose=0.3),
                             dict(type='sleeves', mat='cloth2', t=0.55, len='long', loose=0.3),
                             dict(type='skirt', mat='cloth2', t=0.5, len='knee', flare=1.6, open=True, gap=1.6),
                             dict(type='collar', mat='cloth2', h=1.2, t=0.4, open=True), dict(type='pocket', mat='cloth2', at='chest_r')],
  tags=('outer',))
g('robe', 'Robe', 4, [dict(type='torso', mat='cloth2', t=0.7, top='v', bottom='hip', loose=0.4),
                      dict(type='sleeves', mat='cloth2', t=0.8, len='long', loose=1.0),
                      dict(type='skirt', mat='cloth2', t=0.6, len='calf', flare=1.8, open=False),
                      dict(type='belt', mat='cloth4', y='waist', w=1.6)], tags=('outer',))
g('apron', 'Apron', 4, [dict(type='torso', mat='cloth4', t=0.55, top='scoop', bottom='hip', arms=False),
                        dict(type='skirt', mat='cloth4', t=0.5, len='knee', flare=0.8, open=True, gap=0.4)], tags=('outer',))
g('overalls', 'Coverall', 4, [dict(type='torso', mat='cloth2', t=0.5, top='crew', bottom='hip', open=0.8, loose=0.3),
                              dict(type='sleeves', mat='cloth2', t=0.5, len='elbow', cuff='cloth2', loose=0.3),
                              dict(type='legs', mat='cloth2', t=0.5, len='long', loose=0.4),
                              dict(type='belt', mat='leather', y='waist', buckle='metal'), dict(type='pocket', mat='cloth2', at='thigh_r')],
  tags=('outer',))
g('poncho', 'Poncho', 4, [dict(type='torso', mat='cloth2', t=1.1, top='crew', bottom='crotch', loose=1.4)], tags=('outer',))

# --------------------------------------------------------------------------------------------- armour and straps
g('vest', 'Vest', 5, [dict(type='plate', mat='cloth4', at='chest', t=0.7)], tags=('armor',))
g('vest_heavy', 'Plate carrier', 5, [dict(type='plate', mat='poly', at='chest', t=1.0, size=1.05), dict(type='plate', mat='poly', at='back', t=1.0),
                                     dict(type='plate', mat='poly', at='shoulders', t=0.8, size=0.9),
                                     dict(type='pocket', mat='cloth4', at='chest_l')], tags=('armor',))
g('vest_corp', 'Corp liner', 5, [dict(type='plate', mat='synth', at='chest', t=0.55, size=0.95), dict(type='plate', mat='synth', at='abdomen', t=0.5)],
  tags=('armor',))
g('riot', 'Riot jacket', 5, [dict(type='plate', mat='poly', at='chest', t=1.0), dict(type='plate', mat='poly', at='shoulders', t=1.0, size=1.1),
                             dict(type='plate', mat='poly', at='forearms', t=0.8), dict(type='plate', mat='poly', at='abdomen', t=0.7)],
  tags=('armor',))
g('bracers', 'Arm guards', 5, [dict(type='plate', mat='leather', at='forearms', t=0.6)], tags=('armor',))
g('bracers_heavy', 'Arm armour', 5, [dict(type='plate', mat='poly', at='forearms', t=0.9), dict(type='plate', mat='poly', at='shoulders', t=0.8, size=0.8)],
  tags=('armor',))
g('greaves', 'Shin guards', 5, [dict(type='plate', mat='leather', at='shins', t=0.6)], tags=('armor',))
g('greaves_heavy', 'Leg armour', 5, [dict(type='plate', mat='poly', at='shins', t=0.9), dict(type='plate', mat='poly', at='thighs', t=0.7)],
  tags=('armor',))
g('kneepads', 'Knee pads', 5, [dict(type='plate', mat='poly', at='knees', t=0.8)], tags=('armor',))
g('harness', 'Harness', 6, [dict(type='strap', mat='leather', **{'from': 'sh_r', 'to': 'hip_l'}), dict(type='strap', mat='leather', **{'from': 'sh_l', 'to': 'hip_r'}),
                            dict(type='belt', mat='leather', y='hip', w=1.0, buckle='metal')], tags=('straps',))
g('sling', 'Gun sling', 6, [dict(type='strap', mat='leather2', **{'from': 'sh_l', 'to': 'hip_r'}, w=0.55)], tags=('straps',))
g('holster', 'Holster', 6, [dict(type='belt', mat='leather2', y='hip', w=0.9), dict(type='pocket', mat='leather2', at='thigh_r')], tags=('straps',))
g('backpack', 'Backpack', 6, [dict(type='plate', mat='cloth4', at='back', t=1.6), dict(type='strap', mat='cloth4', **{'from': 'sh_r', 'to': 'waist_r'}, w=0.6),
                              dict(type='strap', mat='cloth4', **{'from': 'sh_l', 'to': 'waist_l'}, w=0.6)], back=True, tags=('straps',))

# --------------------------------------------------------------------------------------------- hands and head
g('gloves', 'Gloves', 3, [dict(type='gloves', mat='leather2', t=0.28)], tags=('hands',))
g('helmet_ball', 'Helmet', 7, [dict(type='helmet', mat='poly', t=1.1, rim=0.6, brim=True)], hides_hair=True, tags=('head',))
g('helm_tac', 'Tactical helmet', 7, [dict(type='helmet', mat='poly', t=1.2, rim=-0.4, visor='lens')], hides_hair=True, hides_face=True, tags=('head',))
g('visor', 'Riot visor', 7, [dict(type='helmet', mat='poly', t=1.1, rim=1.1, visor='lens')], hides_hair=True, tags=('head',))
g('balaclava', 'Balaclava', 7, [dict(type='mask', mat='cloth1', cover='full')], hides_hair=True, tags=('head',))
g('facemask', 'Face mask', 7, [dict(type='mask', mat='cloth4', cover='lower')], tags=('head',))


def garment_parts(gid, fem):
    spec = G[gid]
    if fem and spec['fem'] is not None:
        return dict(spec, parts=spec['fem'])
    if not fem and spec['male'] is not None:
        return dict(spec, parts=spec['male'])
    return spec


# --------------------------------------------------------------------------------------------- outfits (game ids)
# colours are palette presets per material slot (materials.CLOTH_PRESETS / METAL_PRESETS)
O = {}


def o(id, name, garments, colours, tags=()):
    O[id] = dict(id=id, name=name, garments=garments, colours=colours, tags=list(tags))


JACKETS = ['olive', 'gunmetal', 'oxblood', 'ink navy', 'drab', 'teal']
for i, c in enumerate(JACKETS):
    o('jacket_%d' % i, 'Resident jacket %d' % i, ['tee', 'slacks', 'sneakers', 'bomber'],
      {'cloth1': 'slate', 'cloth2': c, 'cloth3': 'black', 'cloth4': 'bone', 'leather': 'black'}, ('resident',))
o('thug', 'Bratva', ['tee', 'cargo', 'boots', 'bomber'], {'cloth1': 'black', 'cloth2': 'red coat', 'cloth3': 'black', 'cloth4': 'black', 'leather': 'black'},
  ('faction',))
o('nap', 'NAP officer', ['shirt', 'slacks', 'boots', 'gloves'], {'cloth1': 'police blue', 'cloth3': 'ink navy', 'cloth4': 'gunmetal', 'leather': 'black',
                                                                 'leather2': 'black'}, ('faction',))
o('nasim', 'Nasim runner', ['bodysuit', 'boots', 'gloves'], {'cloth1': 'black', 'cloth4': 'teal', 'leather': 'black', 'leather2': 'black'}, ('faction',))
o('suit', 'Suit', ['shirt', 'slacks', 'boots', 'suit_jacket'], {'cloth1': 'white', 'cloth2': 'gunmetal', 'cloth3': 'gunmetal', 'leather': 'black'},
  ('resident',))
o('labcoat', 'Lab coat', ['turtleneck', 'slacks', 'sneakers', 'labcoat'], {'cloth1': 'slate', 'cloth2': 'white', 'cloth3': 'black', 'cloth4': 'slate'},
  ('resident',))
o('chef', 'Chef', ['tee', 'slacks', 'sneakers', 'apron'], {'cloth1': 'white', 'cloth3': 'black', 'cloth4': 'white'}, ('resident',))
o('priest', 'Priest', ['shirt', 'slacks', 'boots', 'robe'], {'cloth1': 'black', 'cloth2': 'black', 'cloth3': 'black', 'cloth4': 'white', 'leather': 'black'},
  ('resident',))
o('kannushi', 'Shrine robe', ['shirt', 'slacks', 'sneakers', 'robe'], {'cloth1': 'white', 'cloth2': 'white', 'cloth3': 'teal', 'cloth4': 'teal'},
  ('resident',))
o('overalls', 'Coverall', ['tee', 'boots', 'overalls'], {'cloth1': 'slate', 'cloth2': 'rust', 'leather': 'black'}, ('resident',))
o('courier', 'Courier', ['tee', 'shorts', 'sneakers', 'hoodie', 'backpack'], {'cloth1': 'bone', 'cloth2': 'teal', 'cloth3': 'black', 'cloth4': 'drab'},
  ('resident',))
o('coat', 'Long coat', ['turtleneck', 'slacks', 'boots', 'trench'], {'cloth1': 'black', 'cloth2': 'drab', 'cloth3': 'black', 'leather': 'black'},
  ('resident',))
o('tactical', 'Tactical operative', ['bodysuit', 'boots_high', 'gloves', 'harness', 'holster'], {'cloth1': 'gunmetal', 'leather': 'black', 'leather2': 'black',
                                                                                                'cloth4': 'olive'}, ('cast',))
o('runner', 'Netrunner', ['tank', 'leggings', 'sneakers', 'hoodie'], {'cloth1': 'black', 'cloth2': 'gunmetal', 'cloth3': 'black', 'cloth4': 'teal'},
  ('cast',))
o('detective', 'Detective', ['shirt', 'slacks', 'boots', 'trench'], {'cloth1': 'bone', 'cloth2': 'khaki', 'cloth3': 'gunmetal', 'leather': 'black'},
  ('cast',))
o('enforcer', 'Enforcer', ['tee', 'cargo', 'boots', 'riot', 'kneepads'], {'cloth1': 'black', 'cloth3': 'olive', 'leather': 'black'}, ('cast',))
o('android', 'Android (bare)', [], {}, ('cast',))

# the game's worn items map one to one onto garments
WORN = {'coat': 'trench', 'vest': 'vest', 'vest_heavy': 'vest_heavy', 'vest_corp': 'vest_corp', 'jacket': 'riot', 'bracers': 'bracers',
        'bracers_heavy': 'bracers_heavy', 'greaves': 'greaves', 'greaves_heavy': 'greaves_heavy', 'kneepads': 'kneepads', 'backpack': 'backpack',
        'holster': 'holster', 'helmet_ball': 'helmet_ball', 'visor': 'visor', 'helm_tac': 'helm_tac', 'balaclava': 'balaclava'}
