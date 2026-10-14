"""Upgraded NPC, player, hostile and android figures for Bouma and its restyles (Milestone 23).
32x36 front-view figures: coat with collar and belt, boots, four hair styles, accessories (cyber eye, headset, hood, visor),
and an android with a smooth faceplate, a visor strip, neck conduit, segmented plating, joints and a chest light.
The role colour stays on the coat trim so friend, neutral and foe still read at a glance."""
import random
from iso import Canvas, shade, mix

SKIN = [(236, 200, 170), (212, 164, 124), (168, 116, 82), (116, 76, 54)]
HAIR = [(24, 24, 32), (70, 44, 30), (190, 160, 90), (150, 40, 60), (60, 90, 170), (210, 210, 220)]
COAT = [(54, 60, 84), (84, 66, 58), (60, 82, 70), (92, 92, 104), (70, 52, 84), (120, 90, 54)]
TRIM = {"player": (40, 220, 255), "npc": (255, 170, 60), "hostile": (235, 70, 80), "android": (90, 245, 255)}
PANTS = [(34, 38, 52), (52, 46, 40), (40, 56, 56), (60, 60, 70)]
EYE = (20, 20, 24)


def p_human(role, seed, female=False):
    if role == "android":
        return p_android(seed, female)
    r = random.Random(seed * 7919 + (3 if female else 0))
    cv = Canvas(32, 36)
    trim = TRIM[role]
    coat = COAT[r.randrange(len(COAT))] if role != "hostile" else mix(COAT[r.randrange(3)], (60, 30, 36), 0.4)
    if role == "player":
        coat = mix(COAT[0], (40, 90, 120), 0.5)
    sk = SKIN[seed % 4]
    hair = HAIR[r.randrange(len(HAIR))] if role != "player" else HAIR[0]
    pants = PANTS[r.randrange(len(PANTS))]
    cv.ellipse((8, 28, 24, 34), (0, 0, 0, 110))
    # legs and boots
    cv.rect((12, 21, 15, 29), pants); cv.rect((17, 21, 20, 29), pants)
    cv.rect((12, 21, 15, 22), shade(pants, 1.3)); cv.rect((17, 21, 20, 22), shade(pants, 1.3))
    cv.rect((11, 28, 15, 31), (24, 24, 30)); cv.rect((17, 28, 21, 31), (24, 24, 30))
    cv.rect((11, 30, 15, 31), shade(trim, 0.6)); cv.rect((17, 30, 21, 31), shade(trim, 0.6))
    # coat: long hem for npc/player, short jacket for hostile
    hem = 24 if role == "hostile" else 26
    cv.rect((10, 12, 22, hem), coat)
    cv.rect((10, 12, 22, 14), shade(coat, 1.25))
    cv.rect((15, 12, 17, hem), shade(coat, 0.55))
    cv.rect((10, hem - 1, 22, hem), shade(coat, 0.7))
    cv.rect((10, 19, 22, 20), shade(coat, 0.45))             # belt
    cv.rect((15, 19, 17, 20), (220, 200, 120))
    cv.rect((10, 13, 11, hem - 2), trim)                      # role trim down the left edge
    cv.rect((21, 13, 22, hem - 2), shade(trim, 0.7))
    # arms and hands
    cv.rect((7, 13, 10, 22), shade(coat, 0.8)); cv.rect((22, 13, 25, 22), shade(coat, 0.8))
    cv.rect((7, 21, 10, 23), sk); cv.rect((22, 21, 25, 23), sk)
    cv.rect((7, 21, 10, 22), shade(trim, 0.8)); cv.rect((22, 21, 25, 22), shade(trim, 0.8))   # cuffs
    # head
    cv.rect((14, 10, 18, 13), shade(sk, 0.8))                  # neck
    cv.rect((10, 11, 22, 13), shade(coat, 1.35))              # collar
    cv.ellipse((12, 2, 20, 12), sk)
    style = r.randrange(4) if not female else 1 + r.randrange(3)
    if role == "hostile":
        style = 3
    if style == 0:                                             # short crop
        cv.ellipse((11, 1, 21, 8), hair)
    elif style == 1:                                           # long hair
        cv.ellipse((11, 1, 21, 8), hair); cv.rect((10, 5, 12, 16), hair); cv.rect((20, 5, 22, 16), hair)
    elif style == 2:                                           # bun / tied back
        cv.ellipse((11, 1, 21, 7), hair); cv.ellipse((14, -1, 18, 3), hair); cv.rect((11, 5, 12, 9), hair); cv.rect((20, 5, 21, 9), hair)
    else:                                                      # mohawk or hood
        if role == "hostile":
            cv.rect((14, 0, 18, 7), hair if hair != HAIR[0] else (200, 40, 70)); cv.rect((12, 5, 20, 7), shade(hair, 0.6))
        else:
            cv.ellipse((10, 0, 22, 9), coat); cv.rect((10, 4, 12, 12), coat); cv.rect((20, 4, 22, 12), coat)
            cv.ellipse((12, 3, 20, 12), sk)
    cv.rect((14, 7, 15, 8), EYE); cv.rect((17, 7, 18, 8), EYE)
    cv.rect((15, 10, 17, 10), shade(sk, 0.6))                  # mouth
    # accessories
    acc = r.randrange(5)
    if role == "hostile":
        cv.rect((12, 6, 20, 8), (24, 24, 30)); cv.rect((12, 7, 20, 8), (255, 70, 80))      # glowing visor
        cv.rect((8, 12, 11, 15), (50, 50, 60)); cv.rect((21, 12, 24, 15), (50, 50, 60))   # pauldrons
    elif acc == 0:
        cv.rect((17, 7, 19, 9), (80, 240, 255))                # cyber eye
    elif acc == 1:
        cv.rect((11, 7, 13, 8), (60, 60, 70)); cv.rect((10, 8, 11, 10), (60, 60, 70)); cv.rect((10, 10, 13, 11), (60, 60, 70))   # headset
    elif acc == 2:
        cv.rect((12, 6, 20, 8), (30, 30, 40)); cv.rect((13, 7, 19, 8), (120, 200, 255))  # shades
    elif acc == 3:
        cv.rect((22, 14, 25, 20), (110, 80, 50)); cv.rect((22, 14, 25, 15), (150, 110, 70))  # shoulder bag strap and bag
    return cv.done(seed, 0)


def p_android(seed, female=False):
    r = random.Random(seed * 104729)
    cv = Canvas(32, 36)
    hull = (196, 204, 220)
    dark = (92, 100, 120)
    glow = (80, 245, 255)
    cv.ellipse((8, 28, 24, 34), (0, 0, 0, 110))
    # legs: thigh, knee joint, shin, foot
    for x0 in (12, 17):
        cv.rect((x0, 21, x0 + 3, 25), hull); cv.ellipse((x0 - 1, 24, x0 + 4, 27), dark)
        cv.rect((x0, 26, x0 + 3, 29), shade(hull, 0.85)); cv.rect((x0 - 1, 29, x0 + 4, 31), dark)
        cv.rect((x0 + 1, 21, x0 + 2, 25), shade(hull, 1.15))
    # torso plating
    cv.rect((10, 12, 22, 22), hull); cv.rect((10, 12, 22, 14), shade(hull, 1.2))
    cv.rect((10, 17, 22, 18), dark); cv.rect((10, 21, 22, 22), dark)
    cv.rect((15, 12, 17, 22), shade(hull, 0.7))
    cv.ellipse((14, 14, 18, 17), glow); cv.rect((15, 15, 17, 16), (230, 255, 255))      # chest light
    if female:
        cv.rect((11, 14, 13, 16), shade(hull, 1.1)); cv.rect((19, 14, 21, 16), shade(hull, 1.1)); cv.rect((11, 19, 21, 20), shade(hull, 0.9))
    # shoulder joints and arms
    cv.ellipse((7, 11, 12, 16), dark); cv.ellipse((20, 11, 25, 16), dark)
    cv.rect((8, 15, 10, 22), shade(hull, 0.85)); cv.rect((22, 15, 24, 22), shade(hull, 0.85))
    cv.rect((8, 18, 10, 19), dark); cv.rect((22, 18, 24, 19), dark)
    cv.rect((7, 22, 10, 24), dark); cv.rect((22, 22, 25, 24), dark)
    # neck conduit and head
    cv.rect((14, 10, 18, 13), dark); cv.rect((15, 10, 16, 13), glow)
    cv.ellipse((11, 1, 21, 12), hull); cv.ellipse((12, 2, 20, 8), shade(hull, 1.2))
    cv.rect((12, 5, 20, 8), (24, 30, 44)); cv.rect((13, 6, 19, 7), glow)                  # visor strip
    cv.rect((10, 5, 11, 9), dark); cv.rect((21, 5, 22, 9), dark)                           # ear modules
    cv.rect((15, 9, 17, 10), shade(hull, 0.6))
    top = r.randrange(3)
    if top == 0:
        cv.rect((15, 0, 17, 2), dark)                                                       # antenna
        cv.rect((15, -1, 17, 0), glow)
    elif top == 1:
        cv.rect((11, 1, 21, 3), (60, 68, 88))                                               # crest plate
    return cv.done(seed, 0)
