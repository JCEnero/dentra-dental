"""Builds Rabi's rig (assets/images/mascot/rabi_rig.webp) from his one render.

Nothing is redrawn. The render is cut into the parts that move: the body,
both ears, the near arm, the far arm and the eyes. The app puts them back
together and moves them (`lib/shared/widgets/dentra_mascot.dart`), so he can
wave, point, blink and look around instead of swapping still pictures.

    python tool/mascot_rig.py <render.png> <cutout.png> [--preview out.png]

<render.png>  the 2048px render (assets/images/treatments/mascot.png)
<cutout.png>  the same picture with a transparent background, any size
Needs numpy and opencv-python-headless.

Writes the sprite sheet and `lib/shared/widgets/mascot_rig.g.dart`, which
says where each part sits on the sheet and on Rabi.
"""
import math
import os
import sys

import cv2
import numpy as np

S = 1024

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, 'assets', 'images', 'mascot', 'rabi_rig.webp')
DART = os.path.join(ROOT, 'lib', 'shared', 'widgets', 'mascot_rig.g.dart')


def load_base(render, cutout):
    """The render at 1024px with the cutout's transparency."""
    rgb = cv2.resize(cv2.imread(render, cv2.IMREAD_UNCHANGED)[:, :, :3], (S, S),
                     interpolation=cv2.INTER_AREA)
    a = cv2.resize(cv2.imread(cutout, cv2.IMREAD_UNCHANGED)[:, :, 3], (S, S),
                   interpolation=cv2.INTER_CUBIC)
    a = cv2.GaussianBlur(a, (0, 0), 0.8).astype(np.float32) / 255
    # Tightened a touch so no pale halo of the backdrop shows.
    a = np.clip((a - 0.5) * 2.2 + 0.5 - 0.08, 0, 1)
    return np.dstack([rgb.astype(np.float32) / 255, a])


yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)


def interp(points, v, axis='y'):
    """Piecewise-linear x(y) (or y(x)) through points."""
    pts = np.array(points, np.float32)
    if axis == 'y':
        return np.interp(v, pts[:, 1], pts[:, 0])
    return np.interp(v, pts[:, 0], pts[:, 1])


def soft(d, w=1.2):
    """0→1 ramp across signed distance d (px)."""
    return np.clip(d / w * 0.5 + 0.5, 0, 1)


# ── Part masks (1 = belongs to the part) ───────────────────────────────
# Near arm (the waving one): everything left of the body's edge.
ARM_EDGE = [(288, 500), (288, 522), (291, 545), (294, 570), (299, 600),
            (305, 630), (311, 660), (318, 690), (324, 712), (326, 720)]


def arm_mask(inset=0.0):
    """inset > 0 moves the cut into the body, where the arm's contact
    shadow sits; it eases in and out at the ends of the join."""
    ease = np.clip((yy - 512) / 22, 0, 1) * np.clip((722 - yy) / 14, 0, 1)
    ex = interp(ARM_EDGE, yy) + inset * ease
    m = soft(ex - xx)
    m *= soft(yy - 498) * soft(722 - yy) * soft(332 - xx)
    return m


# Far arm (hangs behind the body, lower right).
def far_arm_mask():
    ex = np.where(yy < 804, 742.5 + (yy - 690) * (700 - 742.5) / (804 - 690), 700.5)
    # slight bow of the body edge
    ex = ex - 2.5 * np.clip(1 - ((yy - 745) / 55) ** 2, 0, 1)
    m = soft(xx - ex)
    m *= soft(yy - 686) * soft(845 - yy)
    return m


# Ears: above the body's top contour.
L_TOP = [(250, 361), (380, 361), (400, 354), (420, 349), (440, 347), (460, 346),
         (480, 347.5), (502, 351), (506, 352)]
R_TOP = [(563, 377), (565, 377.5), (585, 381), (605, 380), (625, 378),
         (645, 378), (665, 379), (685, 382.5), (850, 382.5)]


def ear_l_mask():
    ty = interp(L_TOP, xx, 'x')
    return soft(ty - yy) * soft(507 - xx)


def ear_r_mask():
    ty = interp(R_TOP, xx, 'x')
    return soft(ty - yy) * soft(xx - 563)


def split(img, m):
    part = img.copy(); part[..., 3] *= m
    rest = img.copy(); rest[..., 3] *= (1 - m)
    return part, rest


def over(dst, src):
    a = src[..., 3:4]; b = dst[..., 3:4]
    out_a = a + b * (1 - a)
    rgb = (src[..., :3] * a + dst[..., :3] * b * (1 - a)) / np.maximum(out_a, 1e-6)
    return np.dstack([rgb, out_a])


def warp(img, M):
    pm = img.copy(); pm[..., :3] *= pm[..., 3:4]
    out = cv2.warpAffine(pm, M, (S, S), flags=cv2.INTER_CUBIC,
                         borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    out = np.clip(out, 0, 1)
    a = out[..., 3:4]
    out[..., :3] = np.where(a > 1e-4, out[..., :3] / np.maximum(a, 1e-4), 0)
    return np.clip(out, 0, 1)


def rotate(img, deg, pivot, shift=(0, 0), scale=1.0):
    M = cv2.getRotationMatrix2D(pivot, deg, scale)
    M[0, 2] += shift[0]; M[1, 2] += shift[1]
    return warp(img, M)


def flip_x(img, axis_x):
    M = np.array([[-1, 0, 2 * axis_x], [0, 1, 0]], np.float32)
    return warp(img, M)


def heal(img, mask, radius=7, blur=0.0):
    """Fill mask (uint8 0/255) from the surrounding shading."""
    bgr = (img[..., :3] * 255).astype(np.uint8)
    fixed = cv2.inpaint(bgr, mask, radius, cv2.INPAINT_TELEA).astype(np.float32) / 255
    if blur:
        sm = cv2.GaussianBlur(fixed, (0, 0), blur)
        w = cv2.GaussianBlur((mask > 0).astype(np.float32), (0, 0), 2.5)[..., None]
        w = np.clip(w * 1.6, 0, 1)
        fixed = fixed * (1 - w) + sm * w
    out = img.copy(); out[..., :3] = fixed
    return out


def ellipse_mask(c, axes, angle=0):
    m = np.zeros((S, S), np.uint8)
    cv2.ellipse(m, (int(round(c[0])), int(round(c[1]))),
                (int(round(axes[0])), int(round(axes[1]))), angle, 0, 360, 255, -1)
    return m


def feathered(c, axes, angle, feather):
    """An ellipse as a 0–1 mask with a soft edge."""
    m = ellipse_mask(c, axes, angle).astype(np.float32) / 255
    return cv2.GaussianBlur(m, (0, 0), feather)


def shadow_of(layer, dx, dy, sigma, strength, tint=(120, 112, 160)):
    a = cv2.GaussianBlur(layer[..., 3], (0, 0), sigma)
    M = np.float32([[1, 0, dx], [0, 1, dy]])
    a = cv2.warpAffine(a, M, (S, S))
    sh = np.zeros_like(layer)
    sh[..., :3] = np.array(tint[::-1], np.float32) / 255
    sh[..., 3] = a * strength
    return sh


def clip_to(layer, alpha):
    out = layer.copy(); out[..., 3] *= alpha
    return out


# ── The face ───────────────────────────────────────────────────────────
TILT = 7.5              # the face's lean in the 3/4 view

# What gets painted out under each eye and the mouth: centre, half-axes.
EYE_L = ((412, 540), (56, 58))
EYE_R = ((652, 573), (56, 56))
MOUTH_C = (526, 626)

# The glassy part of each eye, inside its lid line: centre, half-axes, lean.
IRIS_L = ((413, 540), (43, 44), 12)
IRIS_R = ((653, 573), (45, 41), 8)


def clear_eyes(img):
    m = ellipse_mask(EYE_L[0], EYE_L[1], TILT) | ellipse_mask(EYE_R[0], EYE_R[1], TILT)
    return heal(img, m, 9, blur=5)


def clear_mouth(img):
    m = ellipse_mask((523, 622), (80, 60), TILT)
    return heal(img, m, 11, blur=7)


def looking_away(img, iris):
    """The eye with its glassy part mirrored, so it looks the other way."""
    c, axes, lean = iris
    inside = feathered(c, (axes[0] - 3, axes[1] - 3), lean, 2.2)
    # Mirrored across the eye's own upright axis.
    a = math.radians(lean)
    ca, sa = math.cos(2 * a), math.sin(2 * a)
    M = np.float32([[-ca, -sa, 0], [-sa, ca, 0]])
    M[:, 2] = np.float32(c) - M[:, :2] @ np.float32(c)
    turned = warp(img, M)
    out = img.copy()
    w = inside[..., None]
    out[..., :3] = img[..., :3] * (1 - w) + turned[..., :3] * w
    return out


# ── Parts ──────────────────────────────────────────────────────────────
ARM_PIVOT = (322, 702)
EAR_L_ROOT = (446, 362)
EAR_R_ROOT = (626, 392)
MIRROR_X = 537           # the body's centre line, for his second raised arm

# The hand-on-chin arm, as placed in front of the body.
THINK_DEG = -58
THINK_SHIFT = (100, 138)


def build_parts(base):
    arm, _ = split(base, arm_mask(-1.0))
    _, body = split(base, arm_mask(3.2))

    def front_arm(feather=24, base_fade=70):
        """The arm for use in front of the body: its cut side and root
        melt away."""
        ex = interp(ARM_EDGE, yy)
        f = np.clip((ex - xx) / feather, 0, 1)
        f = f * f * (3 - 2 * f)
        g = np.clip((716 - yy) / base_fade, 0, 1)
        g = g * g * (3 - 2 * g)
        out = arm.copy(); out[..., 3] *= f * g
        return out

    ear_l, body = split(body, ear_l_mask())
    ear_r, body = split(body, ear_r_mask())
    far_arm, body = split(body, far_arm_mask())

    # Eyes: the body keeps smooth lids; the eyes are their own parts.
    blank = clear_eyes(body)

    def eye(src, spec):
        c, axes = spec
        m = feathered(c, (axes[0] - 4, axes[1] - 4), TILT, 2.0)
        part = src.copy(); part[..., 3] *= m
        return part

    eye_l = eye(body, EYE_L)
    eye_r = eye(body, EYE_R)
    eye_l_away = eye(looking_away(body, IRIS_L), EYE_L)
    eye_r_away = eye(looking_away(body, IRIS_R), EYE_R)

    # The mouth painted out, for the small drawn mouths.
    healed = clear_mouth(blank)
    lips = healed.copy()
    lips[..., 3] *= feathered((523, 622), (86, 66), TILT, 3.0)

    # The chin arm's soft shadow on the body, where it rests when thinking.
    front = front_arm()
    placed = rotate(front, THINK_DEG, ARM_PIVOT, shift=THINK_SHIFT)
    shade = clip_to(shadow_of(placed, 4, 9, 8, 0.6), body[..., 3])

    return {
        'farArm': far_arm,
        'arm': arm,
        'earL': ear_l,
        'earR': ear_r,
        'body': blank,
        'lips': lips,
        'eyeL': eye_l,
        'eyeR': eye_r,
        'eyeLAway': eye_l_away,
        'eyeRAway': eye_r_away,
        'chinShade': shade,
        'armFront': front,
    }


# ── Sprite sheet ───────────────────────────────────────────────────────
FRAME = (97, 82, 880)   # x, y, side: the square Rabi stands in
SCALE = 640 / 880       # sheet pixels per render pixel
PAD = 3                 # clear pixels round each sprite


def bounds(part):
    ys, xs = np.where(part[..., 3] > 0.004)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def pack(parts):
    """Shelf-packs the parts. Returns the sheet and, per part, its place
    on the sheet (px) and on Rabi (fractions of his square)."""
    fx, fy, side = FRAME
    sprites = {}
    for name, part in parts.items():
        x0, y0, x1, y1 = bounds(part)
        crop = part[y0:y1, x0:x1]
        w = max(1, round((x1 - x0) * SCALE)); h = max(1, round((y1 - y0) * SCALE))
        pm = crop.copy(); pm[..., :3] *= pm[..., 3:4]
        pm = cv2.resize(pm, (w, h), interpolation=cv2.INTER_AREA)
        a = pm[..., 3:4]
        pm[..., :3] = np.where(a > 1e-4, pm[..., :3] / np.maximum(a, 1e-4), 1.0)
        sprites[name] = (np.clip(pm, 0, 1), (x0, y0, x1, y1))

    width = 1024
    order = sorted(sprites, key=lambda n: -sprites[n][0].shape[0])
    x = y = PAD; shelf = 0; places = {}
    for name in order:
        h, w = sprites[name][0].shape[:2]
        if x + w + PAD > width:
            x = PAD; y += shelf + PAD; shelf = 0
        places[name] = (x, y, w, h)
        x += w + PAD; shelf = max(shelf, h)
    height = y + shelf + PAD
    sheet = np.zeros((height, width, 4), np.float32)
    sheet[..., :3] = 1.0
    for name, (x, y, w, h) in places.items():
        sheet[y:y + h, x:x + w] = sprites[name][0]

    layout = {}
    for name in parts:                       # draw order
        x, y, w, h = places[name]
        x0, y0, x1, y1 = sprites[name][1]
        layout[name] = (
            (x, y, w, h),
            ((x0 - fx) / side, (y0 - fy) / side, (x1 - x0) / side, (y1 - y0) / side),
        )
    return sheet, layout


def unit(p):
    fx, fy, side = FRAME
    return ((p[0] - fx) / side, (p[1] - fy) / side)


def write_dart(sheet, layout):
    h, w = sheet.shape[:2]
    f = lambda v: f'{v:.5f}'.rstrip('0').rstrip('.')
    pt = lambda p: 'Offset({}, {})'.format(*map(f, unit(p)))
    ln = lambda v: f(v / FRAME[2])
    lines = [
        '// GENERATED by tool/mascot_rig.py. Do not edit by hand.',
        '//',
        "// Where each part of Rabi sits on the sprite sheet, and on Rabi. Places",
        '// on Rabi are fractions of the square he stands in.',
        "import 'dart:ui';",
        '',
        'abstract final class MascotRig {',
        "  static const asset = 'assets/images/mascot/rabi_rig.webp';",
        f'  static const sheetSize = Size({w}, {h});',
        '',
    ]
    for name, (src, dst) in layout.items():
        lines.append(f'  static const {name} = MascotPart(')
        lines.append('    Rect.fromLTWH({}, {}, {}, {}),'.format(*src))
        lines.append('    Rect.fromLTWH({}, {}, {}, {}),'.format(*map(f, dst)))
        lines.append('  );')
    lines += [
        '',
        '  // Joints.',
        f'  static const armPivot = {pt(ARM_PIVOT)};',
        f'  static const earLRoot = {pt(EAR_L_ROOT)};',
        f'  static const earRRoot = {pt(EAR_R_ROOT)};',
        f'  static const mirrorX = {f(unit((MIRROR_X, 0))[0])};',
        '',
        '  // The face. Half-sizes are (across, down).',
        f'  static const faceTilt = {f(math.radians(TILT))};',
        f'  static const eyeLCentre = {pt(EYE_L[0])};',
        f'  static const eyeRCentre = {pt(EYE_R[0])};',
        f'  static const eyeLHalf = Size({ln(EYE_L[1][0])}, {ln(EYE_L[1][1])});',
        f'  static const eyeRHalf = Size({ln(EYE_R[1][0])}, {ln(EYE_R[1][1])});',
        f'  static const mouth = {pt(MOUTH_C)};',
        '',
        '  // The chin arm: turned and moved this far to rest on the chin.',
        f'  static const thinkTurn = {f(math.radians(-THINK_DEG))};',
        f'  static const thinkShift = Offset({ln(THINK_SHIFT[0])}, {ln(THINK_SHIFT[1])});',
        '}',
        '',
        '/// One sprite: [src] on the sheet in pixels, [dst] on Rabi.',
        'class MascotPart {',
        '  const MascotPart(this.src, this.dst);',
        '',
        '  final Rect src;',
        '  final Rect dst;',
        '}',
        '',
    ]
    with open(DART, 'w') as out:
        out.write('\n'.join(lines))


def save(img, path):
    cv2.imwrite(path, (np.clip(img, 0, 1) * 255).astype(np.uint8),
                [cv2.IMWRITE_WEBP_QUALITY, 92])


def preview(parts, path):
    """The parts put back as rendered, beside two checks of the cuts."""
    def stack(names):
        out = np.zeros((S, S, 4), np.float32)
        for n in names:
            out = over(out, parts[n])
        return out

    rest = stack(['farArm', 'arm', 'earL', 'earR', 'body', 'eyeL', 'eyeR'])
    away = stack(['farArm', 'arm', 'earL', 'earR', 'body', 'eyeLAway', 'eyeR'])
    shut = stack(['farArm', 'earL', 'earR', 'body', 'lips', 'chinShade'])
    x, y, side = FRAME
    tiles = []
    for img in (rest, away, shut):
        crop = img[y:y + side, x:x + side]
        bg = np.empty_like(crop[..., :3]); bg[:] = (247 / 255, 248 / 255, 232 / 255)
        a = crop[..., 3:4]
        tiles.append(crop[..., :3] * a + bg * (1 - a))
    cv2.imwrite(path, (np.clip(np.hstack(tiles), 0, 1) * 255).astype(np.uint8))


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) < 2:
        sys.exit(__doc__)
    parts = build_parts(load_base(args[0], args[1]))
    if '--preview' in sys.argv:
        preview(parts, sys.argv[sys.argv.index('--preview') + 1])
    sheet, layout = pack(parts)
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    save(sheet, SHEET)
    write_dart(sheet, layout)
    print('wrote', os.path.relpath(SHEET, ROOT), sheet.shape[1], 'x', sheet.shape[0])
    print('wrote', os.path.relpath(DART, ROOT))
