"""polish-pass: pixel-art upscaler used to put background art on the characters'
pixel grid (no mixels).

Scale2x / Scale3x (AdvMAME2x/3x) enlarge pixel art by 2 or 3 without blur or new
colours: each pixel becomes a 2x2 / 3x3 block whose corners follow diagonal edges,
so outlines get finer steps instead of fat staircases. Changed here so that only
real diagonals are smoothed: square corners (windows, rooftops) stay square. 4x = 2x twice, 6x = 3x then
2x, and so on. The game then draws these images at exactly one character pixel per
image pixel (see Scripts/Level/pixel_match.gd and city_depth.gd).

Usage:  python tools/pixel_upscale.py <in.png> <out.png> <factor>
        python tools/pixel_upscale.py --all      (regenerates every file the game uses)
Needs Pillow and numpy.
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load(path):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.uint32)
    packed = (a[..., 0] << 24) | (a[..., 1] << 16) | (a[..., 2] << 8) | a[..., 3]
    packed[a[..., 3] == 0] = 0  # all fully transparent pixels count as the same colour
    return packed


def _save(packed, path):
    a = np.stack([(packed >> 24) & 255, (packed >> 16) & 255, (packed >> 8) & 255, packed & 255], -1).astype(np.uint8)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(a, "RGBA").save(path, optimize=True)


def _neighbours(p):
    q = np.pad(p, 1, mode="edge")
    h, w = p.shape
    A = q[0:h, 0:w]; B = q[0:h, 1:w + 1]; C = q[0:h, 2:w + 2]
    D = q[1:h + 1, 0:w]; E = q[1:h + 1, 1:w + 1]; F = q[1:h + 1, 2:w + 2]
    G = q[2:h + 2, 0:w]; H = q[2:h + 2, 1:w + 1]; I = q[2:h + 2, 2:w + 2]
    return A, B, C, D, E, F, G, H, I


def _corner_rules(A, B, C, D, E, F, G, H, I):
    # Standard Scale2x/3x corner tests, plus a guard: a corner is only cut when the
    # edge continues as a diagonal staircase (the next step sits beside it), so true
    # square corners (windows, building edges) stay square instead of turning round.
    tl = (D == B) & (B != F) & (D != H) & ((C == E) | (G == E))
    tr = (B == F) & (B != D) & (F != H) & ((A == E) | (I == E))
    bl = (D == H) & (D != B) & (H != F) & ((A == E) | (I == E))
    br = (H == F) & (D != H) & (B != F) & ((C == E) | (G == E))
    return tl, tr, bl, br


def scale2x(p):
    A, B, C, D, E, F, G, H, I = _neighbours(p)
    # B = up, D = left, F = right, H = down
    tl, tr, bl, br = _corner_rules(A, B, C, D, E, F, G, H, I)
    e0 = np.where(tl, D, E)
    e1 = np.where(tr, F, E)
    e2 = np.where(bl, D, E)
    e3 = np.where(br, F, E)
    h, w = p.shape
    out = np.empty((h * 2, w * 2), p.dtype)
    out[0::2, 0::2] = e0; out[0::2, 1::2] = e1
    out[1::2, 0::2] = e2; out[1::2, 1::2] = e3
    return out


def scale3x(p):
    A, B, C, D, E, F, G, H, I = _neighbours(p)
    c1, c2, c3, c4 = _corner_rules(A, B, C, D, E, F, G, H, I)
    e0 = np.where(c1, D, E)
    e1 = np.where((c1 & (E != C)) | (c2 & (E != A)), B, E)
    e2 = np.where(c2, F, E)
    e3 = np.where((c1 & (E != G)) | (c3 & (E != A)), D, E)
    e5 = np.where((c2 & (E != I)) | (c4 & (E != C)), F, E)
    e6 = np.where(c3, D, E)
    e7 = np.where((c3 & (E != I)) | (c4 & (E != G)), H, E)
    e8 = np.where(c4, F, E)
    h, w = p.shape
    out = np.empty((h * 3, w * 3), p.dtype)
    for (dy, dx), e in {(0, 0): e0, (0, 1): e1, (0, 2): e2, (1, 0): e3, (1, 1): E,
                        (1, 2): e5, (2, 0): e6, (2, 1): e7, (2, 2): e8}.items():
        out[dy::3, dx::3] = e
    return out


def upscale(p, factor):
    while factor > 1:
        if factor % 3 == 0:
            p = scale3x(p); factor //= 3
        elif factor % 2 == 0:
            p = scale2x(p); factor //= 2
        else:
            raise ValueError("factor must be made of 2s and 3s")
    return p


def upscale_frames(p, factor, frames):
    # Animation strips are upscaled frame by frame so frames don't bleed together
    if frames <= 1:
        return upscale(p, factor)
    w = p.shape[1] // frames
    return np.concatenate([upscale(p[:, i * w:(i + 1) * w], factor) for i in range(frames)], axis=1)


# Every file the game uses: (source, factor, animation frames)
JOBS = [
    # City depth layers (Scripts/Level/city_depth.gd)
    ("Sprites/Background/CityPack/Night/3-background.png", 2, 1),
    ("Sprites/Background/CityPack/Night/4-middleground.png", 2, 1),
    ("Sprites/Background/CityPack/Night/5-middleground.png", 2, 1),
    ("Sprites/Background/CityPack/Night/5-middleground-train.png", 2, 1),
    ("Sprites/Background/CityPack/Night/6-middleground-buildings.png", 3, 1),
    ("Sprites/Background/CityPack/Night/10-foreground-buildings.png", 3, 1),
    ("Sprites/Background/CityPack/Night/10-foreground-buildings.png", 4, 1),
    ("Sprites/Background/CityPack/Night/7-foreground-lane.png", 3, 1),
    ("Sprites/Background/CityPack/Night/7-foreground-lane.png", 4, 1),
    ("Sprites/Background/CityPack/Night/8-foreground-cars.png", 3, 1),
    ("Sprites/Background/CityPack/Night/8b-foreground-cars.png", 3, 1),
    ("Sprites/Background/CityPack/Night/8b-foreground-cars.png", 4, 1),
    ("Sprites/Background/CityPack/Night/7-lights.png", 3, 1),
    ("Sprites/Background/CityPack/Night/7-lights.png", 4, 1),
    ("Sprites/Background/CityPack/Night/11-foreground.png", 3, 1),
    ("Sprites/Background/CityPack/Sunset/3-middleground.png", 2, 1),
    ("Sprites/Background/CityPack/Sunset/4-middleground.png", 2, 1),
    ("Sprites/Background/CityPack/Sunset/viaduct.png", 2, 1),
    ("Sprites/Background/CityPack/Sunset/viaduct-train.png", 2, 1),
    ("Sprites/Background/CityPack/Sunset/5-middleground-buildings.png", 3, 1),
    ("Sprites/Background/CityPack/Sunset/7-foreground-lane.png", 2, 1),
    ("Sprites/Background/CityPack/Sunset/6-foreground-cars.png", 2, 1),
    ("Sprites/Background/CityPack/Sunset/6b-foreground-cars.png", 2, 1),
    ("Sprites/Background/CityPack/Sunset/8-foreground.png", 2, 1),
    ("Sprites/Background/CityPack/Sunset/8-foreground-billboard.png", 2, 15),
    ("Sprites/Background/CityPack/Sunset/9-foreground-lane.png", 2, 1),
    ("Sprites/Background/CityPack/Sunset/9-foreground-lane.png", 4, 1),
    ("Sprites/Background/CityPack/Sunset/10-foreground-cars.png", 2, 1),
    ("Sprites/Background/CityPack/Sunset/10b-foreground-cars.png", 2, 1),
    ("Sprites/Background/CityPack/Sunset/10b-foreground-cars.png", 4, 1),
    ("Sprites/Background/CityPack/Sunset/front-buildings.png", 4, 1),
    ("Sprites/Background/CityPack/Sunset/poles.png", 3, 1),
]


def out_path(src, factor):
    base, ext = os.path.splitext(src)
    return base + "@%dx" % factor + ext


def run_all(extra=()):
    for src, factor, frames in list(JOBS) + list(extra):
        dst = out_path(src, factor)
        p = _load(os.path.join(ROOT, src))
        _save(upscale_frames(p, factor, frames), os.path.join(ROOT, dst))
        print(dst)


# ── Glow ─────────────────────────────────────────────────────────────────────
# For layers with lit windows, lamps, signs and billboards, a soft halo image is
# written next to the enlarged one ("<name>@<n>x.glow.png"). The game draws it
# additively over the layer so those lights actually shine. Only bright, lit
# pixels on a dark image count, so sunset skies and pale walls don't glow.

def _blur(a, sigma):
    # Separable gaussian blur on a float image (h, w, c)
    r = max(1, int(sigma * 3))
    x = np.arange(-r, r + 1, dtype=np.float32)
    k = np.exp(-(x * x) / (2 * sigma * sigma)); k /= k.sum()
    out = a
    for axis in (0, 1):
        pad = [(0, 0)] * a.ndim; pad[axis] = (r, r)
        q = np.pad(out, pad, mode="constant")
        acc = np.zeros_like(out)
        for i, kv in enumerate(k):
            sl = [slice(None)] * a.ndim
            sl[axis] = slice(i, i + out.shape[axis])
            acc += kv * q[tuple(sl)]
        out = acc
    return out


def glow_image(packed, factor, frames=1):
    rgba = np.stack([(packed >> 24) & 255, (packed >> 16) & 255, (packed >> 8) & 255, packed & 255], -1).astype(np.float32)
    rgb, alpha = rgba[..., :3], rgba[..., 3]
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    solid = alpha > 200
    if solid.sum() == 0:
        return None
    dark_share = (lum[solid] < 110).mean()
    lit = solid & (lum > 150) & (rgb.max(-1) > 200)
    # Only images that are mostly dark with a sprinkling of lights (night scenes, billboards)
    is_sign = lit.mean() > 0.0 and lit.sum() / solid.sum() > 0.5   # a billboard: all lit
    if lit.sum() < 4 or (dark_share < 0.6 and not is_sign):
        return None
    src = rgb * lit[..., None] / 255.0
    w = src.shape[1] // max(1, frames)
    parts = []
    for i in range(max(1, frames)):
        s = src[:, i * w:(i + 1) * w]
        g = 0.85 * _blur(s, 1.4 * factor) + 0.55 * _blur(s, 4.5 * factor)
        parts.append(g)
    g = np.concatenate(parts, axis=1)
    g = np.clip(g / max(1e-6, np.percentile(g[g > 0.02], 99) if (g > 0.02).any() else 1.0), 0, 1)
    a = np.clip(g.max(-1), 0, 1)
    col = np.where(a[..., None] > 0, g / np.maximum(a[..., None], 1e-6), 0)
    out = np.concatenate([col * 255, a[..., None] * 255], -1).astype(np.uint8)
    return out


# Glow only for city art (lit windows, lamps, headlights, signs, billboards);
# skies and clouds would just wash out.
GLOW_ONLY = ("Sprites/Background/CityPack/", "Sprites/Background/City/")
GLOW_SKIP = ("Sunset/3-middleground", "City/3.png")


def write_glows(jobs):
    for src, factor, frames in jobs:
        big0 = os.path.join(ROOT, out_path(src, factor)) if factor > 1 else os.path.join(ROOT, src)
        if not src.startswith(GLOW_ONLY) or any(k in src for k in GLOW_SKIP):
            dst0 = os.path.splitext(big0)[0] + ".glow.png"
            if os.path.exists(dst0):
                os.remove(dst0)
            continue
        big = os.path.join(ROOT, out_path(src, factor)) if factor > 1 else os.path.join(ROOT, src)
        p = _load(big)
        g = glow_image(p, factor, frames)
        dst = os.path.splitext(big)[0] + ".glow.png"
        if g is None:
            if os.path.exists(dst):
                os.remove(dst)
            continue
        Image.fromarray(g, "RGBA").save(dst, optimize=True)
        print(os.path.relpath(dst, ROOT))


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "--all":
        import importlib.util
        spec = importlib.util.spec_from_file_location("bgjobs", os.path.join(ROOT, "tools", "pixel_upscale_backgrounds.py"))
        extra = []
        if os.path.exists(spec.origin):
            m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); extra = m.JOBS
        run_all(extra)
        write_glows(list(JOBS) + list(extra))
    elif len(sys.argv) == 4:
        _save(upscale(_load(sys.argv[1]), int(sys.argv[3])), sys.argv[2])
    else:
        print(__doc__)
