"""Materials and palettes.

Every sprite pixel is stored as one byte: material * 8 + shade.  Shades 0-5 are a lit ramp (0 = line / core shadow,
5 = highlight), 6 is the rim light (the cold city light from behind), 7 the specular glint.  A palette is 32 rows of
8 colours; the runtime shader looks the byte up in the doll's palette, so skin, hair, eyes, cloth and implant colours
change per character without new sprites.

Ramps are built in OKLab: shadows lean toward a cool violet, lights toward a warm pale, and chroma falls off at both
ends, which gives the Ghost in the Shell look: neutral, cold-lit, skin that still reads warm.
"""
import math

# material ids --------------------------------------------------------------------------------------------------
NONE, INK, SKIN, LIP, HAIR, SCLERA, IRIS, DARK = 0, 1, 2, 3, 4, 5, 6, 7
CLOTH1, CLOTH2, CLOTH3, CLOTH4 = 8, 9, 10, 11          # base layer / outer layer / legwear / accent
LEATHER, LEATHER2 = 12, 13                             # boots, belts, straps / gloves, holsters
METAL, POLY, SYNTH = 14, 15, 16                        # chrome, graphite polymer, synthetic shell
GLOW, GLOW2 = 17, 18                                   # implant light (cyan family), secondary (amber family)
UNDER = 19                                             # underwear
LENS = 20                                              # optics glass
NAMES = {NONE: 'none', INK: 'ink', SKIN: 'skin', LIP: 'lip', HAIR: 'hair', SCLERA: 'sclera', IRIS: 'iris', DARK: 'dark',
         CLOTH1: 'cloth1', CLOTH2: 'cloth2', CLOTH3: 'cloth3', CLOTH4: 'cloth4', LEATHER: 'leather', LEATHER2: 'leather2',
         METAL: 'metal', POLY: 'poly', SYNTH: 'synth', GLOW: 'glow', GLOW2: 'glow2', UNDER: 'under', LENS: 'lens'}
ROWS = 32
SHADES = 8

# how each material is lit: levels used, gloss (specular), rim strength, how hard the bands sit
LIGHT = {
    SKIN: dict(gloss=0.0, rim=1.0, ao=1.0), LIP: dict(gloss=0.0, rim=0.6, ao=1.0),
    HAIR: dict(gloss=0.55, rim=1.0, ao=1.1), CLOTH1: dict(gloss=0.0, rim=0.8, ao=1.0), CLOTH2: dict(gloss=0.0, rim=0.8, ao=1.0),
    CLOTH3: dict(gloss=0.0, rim=0.8, ao=1.0), CLOTH4: dict(gloss=0.15, rim=0.8, ao=1.0), LEATHER: dict(gloss=0.45, rim=0.9, ao=1.0),
    LEATHER2: dict(gloss=0.4, rim=0.9, ao=1.0), METAL: dict(gloss=1.0, rim=1.0, ao=0.8), POLY: dict(gloss=0.6, rim=1.0, ao=0.9),
    SYNTH: dict(gloss=0.7, rim=1.0, ao=0.9), UNDER: dict(gloss=0.0, rim=0.6, ao=1.0), LENS: dict(gloss=1.0, rim=0.0, ao=0.0),
}


# OKLab --------------------------------------------------------------------------------------------------------
def _srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _lin_to_srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def hex_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def rgb_hex(c):
    # half-up rounding (not Python's round-half-even) so the runtime's port gives identical colours
    return '#%02x%02x%02x' % tuple(int(math.floor(max(0.0, min(1.0, x)) * 255.0 + 0.5)) for x in c)


def to_oklab(rgb):
    r, g, b = (_srgb_to_lin(x) for x in rgb)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(x) ** (1 / 3), x) for x in (l, m, s))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def from_oklab(lab):
    L, a, b = lab
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return tuple(_lin_to_srgb(x) for x in (r, g, bb))


def lch(hexc):
    L, a, b = to_oklab(hex_rgb(hexc))
    return L, math.hypot(a, b), math.atan2(b, a)


def from_lch(L, C, h):
    return rgb_hex(from_oklab((L, C * math.cos(h), C * math.sin(h))))


SHADOW_HUE = math.radians(290.0)     # cool violet-blue
LIGHT_HUE = math.radians(75.0)       # warm pale yellow
RIM = '#7fe3ee'                      # the city's cyan back light


def _hue_toward(h, target, t):
    d = (target - h + math.pi) % (2 * math.pi) - math.pi
    return h + d * t


def ramp(mid, contrast=1.0, shadow_shift=0.32, light_shift=0.18, rim_mix=0.42, chroma_keep=1.0, spec=None, rim=RIM):
    """eight colours from a mid tone (shade 3): five steps around it, a line shade, rim and specular"""
    L, C, h = lch(mid)
    C *= chroma_keep
    steps = [-0.40, -0.275, -0.145, 0.0, 0.125, 0.23]         # L offsets for shades 0..5
    out = []
    for i, dl in enumerate(steps):
        dl *= contrast
        Li = max(0.05, min(0.97, L + dl))
        if dl < 0:
            t = min(1.0, -dl / 0.36) * shadow_shift
            hi = _hue_toward(h, SHADOW_HUE, t)
            Ci = C * (1.0 - 0.45 * min(1.0, -dl / 0.36)) + 0.012 * t
        else:
            t = min(1.0, dl / 0.2) * light_shift
            hi = _hue_toward(h, LIGHT_HUE, t)
            Ci = C * (1.0 - 0.25 * min(1.0, dl / 0.2))
        out.append(from_lch(Li, Ci, hi))
    # rim: the shade-2 colour mixed toward the cyan light in linear RGB (mixing hue in LCh would pass through green)
    r0, r1 = hex_rgb(out[2]), hex_rgb(rim)
    lin = [(_srgb_to_lin(x) * (1 - rim_mix) + _srgb_to_lin(y) * rim_mix) for x, y in zip(r0, r1)]
    out.append(rgb_hex([_lin_to_srgb(x) for x in lin]))
    out.append(spec or from_lch(min(0.97, L + 0.3), C * 0.35, _hue_toward(h, LIGHT_HUE, 0.5)))
    return out


def glow_ramp(core):
    """emissive: no lighting, shade 0 = dim housing edge up to a white-hot centre"""
    L, C, h = lch(core)
    return [from_lch(0.25, C * 0.5, h), from_lch(0.4, C * 0.8, h), from_lch(0.55, C, h), from_lch(L, C, h),
            from_lch(min(0.96, L + 0.1), C * 0.7, h), from_lch(0.97, C * 0.25, h), from_lch(L, C, h), '#ffffff']


# presets ------------------------------------------------------------------------------------------------------
SKIN_PRESETS = {      # human skin, warm mid tones lit coldly
    'porcelain': '#d2a796', 'fair': '#c8987c', 'olive': '#ad8a64', 'tan': '#a87356', 'brown': '#81533a', 'deep': '#573628',
    # prosthetic bodies
    'pearl': '#c9ccd2', 'graphite': '#4a4f5a', 'ceramic': '#a9bccb', 'bone': '#c8bba4',
}
SKIN_CONTRAST = {'pearl': 0.85, 'graphite': 1.0, 'ceramic': 0.85, 'bone': 0.9}
HAIR_PRESETS = {
    'black': '#26232d', 'violet black': '#2e2638', 'dark brown': '#3e2c24', 'chestnut': '#6a4026', 'ash blond': '#a9997a',
    'platinum': '#c9ccd0', 'grey': '#7c7e86', 'teal dye': '#2c7f86', 'cyan dye': '#3fb5c8', 'violet dye': '#6a4a96', 'wine dye': '#6a2a3c',
}
EYE_PRESETS = {'brown': '#5a3a22', 'hazel': '#7a5a2a', 'green': '#4a7a4a', 'blue': '#4a6e9e', 'grey': '#7a8288', 'violet': '#6e5a9a',
               'amber': '#b07a2a'}
CLOTH_PRESETS = {     # restrained city colours: olive drab, gunmetal, slate, ink navy, oxblood, bone, teal, black
    'black': '#24262c', 'gunmetal': '#3c4450', 'slate': '#56606a', 'ink navy': '#27304a', 'olive': '#4f5638', 'drab': '#6a6448',
    'oxblood': '#5a2830', 'bone': '#b9b2a0', 'teal': '#2f5a5e', 'rust': '#7a4a2e', 'khaki': '#8a7e5e', 'white': '#c8cdd2',
    'police blue': '#2c3e5e', 'red coat': '#7a2a2a',
}
METAL_PRESETS = {'chrome': '#8e98a4', 'gunmetal': '#5a626e', 'brass': '#9a7c3e', 'black chrome': '#3a3e46'}
GLOW_PRESETS = {'cyan': '#3fd8f0', 'teal': '#36e0b4', 'amber': '#ffb54a', 'violet': '#a77cff', 'white': '#dff4ff'}


def default_palette():
    """a full 32 x 8 palette (hex strings) for the default doll"""
    pal = [['#000000'] * SHADES for _ in range(ROWS)]
    pal[INK] = ['#0b0c12'] * SHADES
    pal[DARK] = ['#0f0d14', '#14121b', '#1c1a24', '#26232f', '#34303d', '#45404f', '#26232f', '#45404f']
    set_skin(pal, SKIN_PRESETS['tan'])
    pal[HAIR] = ramp(HAIR_PRESETS['black'], contrast=0.8)
    pal[SCLERA] = ramp('#c9c6c4', contrast=0.6)
    pal[IRIS] = ramp(EYE_PRESETS['brown'], contrast=0.9)
    pal[CLOTH1] = ramp(CLOTH_PRESETS['gunmetal'])
    pal[CLOTH2] = ramp(CLOTH_PRESETS['olive'])
    pal[CLOTH3] = ramp(CLOTH_PRESETS['black'])
    pal[CLOTH4] = ramp(CLOTH_PRESETS['teal'])
    pal[LEATHER] = ramp('#2e2a2a', contrast=0.9)
    pal[LEATHER2] = ramp('#3a302a', contrast=0.9)
    pal[METAL] = ramp(METAL_PRESETS['chrome'], contrast=1.35, chroma_keep=0.6, spec='#ffffff')
    pal[POLY] = ramp('#3a3f48', contrast=1.0, spec='#c9d6e6')
    pal[SYNTH] = ramp(SKIN_PRESETS['pearl'], contrast=0.85, spec='#ffffff')
    pal[GLOW] = glow_ramp(GLOW_PRESETS['cyan'])
    pal[GLOW2] = glow_ramp(GLOW_PRESETS['amber'])
    pal[UNDER] = ramp('#3a3d46', contrast=0.9)
    pal[LENS] = ['#08121a', '#0d2230', '#123448', '#1a4a62', '#2a6a86', '#5ab0cc', '#7fe3ee', '#ffffff']
    return pal


def set_skin(pal, mid, contrast=1.0):
    pal[SKIN] = ramp(mid, contrast=contrast)
    L, C, h = lch(mid)
    pal[LIP] = ramp(from_lch(L - 0.07, C * 1.25 + 0.01, _hue_toward(h, math.radians(15), 0.35)), contrast=0.8)


# the canonical spec -> palette mapping (the runtime's DollPalette is a line-by-line port; tests compare them) ----------
DEFAULT_COLOURS = {'skin': 'tan', 'hair': 'black', 'eyes': 'brown', 'cloth1': 'gunmetal', 'cloth2': 'olive', 'cloth3': 'black', 'cloth4': 'teal',
                   'leather': '#2e2a2a', 'leather2': '#3a302a', 'metal': 'chrome', 'poly': '#3a3f48', 'synth': 'pearl', 'glow': 'cyan',
                   'glow2': 'amber', 'under': '#3a3d46'}


def _pick(name, table):
    """a preset name or a #rrggbb colour"""
    if isinstance(name, str) and name.startswith('#'):
        return name
    return table[name]


def palette_for(colours):
    """32 x 8 palette for a colour choice dict (missing keys take DEFAULT_COLOURS)"""
    c = dict(DEFAULT_COLOURS)
    c.update({k: v for k, v in (colours or {}).items() if v})
    pal = default_palette()
    sk = c['skin']
    set_skin(pal, _pick(sk, SKIN_PRESETS), SKIN_CONTRAST.get(sk, 1.0) if not sk.startswith('#') else 1.0)
    pal[HAIR] = ramp(_pick(c['hair'], HAIR_PRESETS), contrast=0.85)
    pal[IRIS] = ramp(_pick(c['eyes'], EYE_PRESETS))
    for key, row in (('cloth1', CLOTH1), ('cloth2', CLOTH2), ('cloth3', CLOTH3), ('cloth4', CLOTH4)):
        pal[row] = ramp(_pick(c[key], CLOTH_PRESETS))
    pal[LEATHER] = ramp(_pick(c['leather'], CLOTH_PRESETS), contrast=0.9)
    pal[LEATHER2] = ramp(_pick(c['leather2'], CLOTH_PRESETS), contrast=0.9)
    pal[METAL] = ramp(_pick(c['metal'], METAL_PRESETS), contrast=1.35, chroma_keep=0.6, spec='#ffffff')
    pal[POLY] = ramp(_pick(c['poly'], CLOTH_PRESETS), contrast=1.0, spec='#c9d6e6')
    pal[SYNTH] = ramp(_pick(c['synth'], SKIN_PRESETS), contrast=0.85, spec='#ffffff')
    pal[GLOW] = glow_ramp(_pick(c['glow'], GLOW_PRESETS))
    pal[GLOW2] = glow_ramp(_pick(c['glow2'], GLOW_PRESETS))
    pal[UNDER] = ramp(_pick(c['under'], CLOTH_PRESETS), contrast=0.9)
    return pal
