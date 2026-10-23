"""Colour: OKLab ramps (shared with the doll workshop's materials.py, so dolls and tiles light alike) and the
glow ramp for emissive neon."""
import math


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
