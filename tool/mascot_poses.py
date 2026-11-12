"""Builds Rabi's pose sprites (assets/images/mascot/) from his one render.

Nothing is redrawn. The near arm, the far arm and the ears are cut from the
render and moved; the eyes and mouth are patched with the body's own shading
and a few strokes in the render's own line colours.

    python tool/mascot_poses.py <render.png> <cutout.png> [out_dir]

<render.png>  the 2048px render (assets/images/treatments/mascot.png)
<cutout.png>  the same picture with a transparent background, any size
Needs numpy and opencv-python-headless.
"""
import math
import os
import sys

import cv2
import numpy as np

S = 1024


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


if len(sys.argv) < 3:
    sys.exit(__doc__)
base = load_base(sys.argv[1], sys.argv[2])
OUT_DIR = sys.argv[3] if len(sys.argv) > 3 else 'assets/images/mascot'

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
    cv2.ellipse(m, (int(c[0]), int(c[1])), (int(axes[0]), int(axes[1])), angle, 0, 360, 255, -1)
    return m

def stroke(img, pts, color_rgb, width, alpha=1.0, blur=0.0, closed=False):
    """Smooth round-capped stroke through pts, clipped to the body."""
    K = 4
    canvas = np.zeros((S * K, S * K), np.uint8)
    p = (np.array(pts, np.float32) * K).astype(np.int32).reshape(-1, 1, 2)
    cv2.polylines(canvas, [p], closed, 255, int(width * K), cv2.LINE_AA)
    r = max(1, int(width * K / 2))
    for q in (p[0, 0], p[-1, 0]):
        cv2.circle(canvas, (int(q[0]), int(q[1])), r, 255, -1, cv2.LINE_AA)
    m = cv2.resize(canvas, (S, S), interpolation=cv2.INTER_AREA).astype(np.float32) / 255
    if blur:
        m = cv2.GaussianBlur(m, (0, 0), blur)
    m = (m * alpha)[..., None]
    col = np.array(color_rgb[::-1], np.float32) / 255
    out = img.copy()
    out[..., :3] = out[..., :3] * (1 - m) + col * m
    return out

def curve(p0, p1, p2, n=28):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2 = (np.array(p, np.float32) for p in (p0, p1, p2))
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t ** 2 * p2

def rot_pts(pts, deg, c):
    a = math.radians(deg); ca, sa = math.cos(a), math.sin(a)
    p = np.array(pts, np.float32) - c
    return np.stack([p[:, 0] * ca - p[:, 1] * sa, p[:, 0] * sa + p[:, 1] * ca], 1) + c

LID = (52, 48, 92)      # the render's eyelid line
MOUTH = (104, 62, 72)   # the render's mouth shadow
TILT = 7.5              # the face's lean in the 3/4 view

EYE_L = ((412, 540), (56, 58))
EYE_R = ((652, 573), (56, 56))
MOUTH_C = (526, 626)

def clear_eyes(img):
    m = ellipse_mask(EYE_L[0], EYE_L[1], TILT) | ellipse_mask(EYE_R[0], EYE_R[1], TILT)
    return heal(img, m, 9, blur=5)

def clear_mouth(img):
    m = ellipse_mask((523, 622), (80, 60), TILT)
    return heal(img, m, 11, blur=7)

def happy_eyes(img):
    img = clear_eyes(img)
    for (c, w, h, t) in ((EYE_L[0], 78, 40, 11.5), (EYE_R[0], 70, 36, 10.5)):
        cx, cy = c
        pts = curve((cx - w / 2, cy + h * 0.45), (cx, cy - h * 1.15), (cx + w / 2, cy + h * 0.45))
        pts = rot_pts(pts, TILT, np.array(c, np.float32))
        img = stroke(img, pts + np.array([0, 3]), (178, 172, 205), t + 6, alpha=0.5, blur=3.5)
        img = stroke(img, pts, LID, t)
    return img

def worried_brows(img):
    # Inner ends lifted, outer ends dropped.
    for (a, b, t) in (((372, 476), (438, 456), 9.5), ((690, 508), (628, 492), 8.5)):
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 - 5)
        pts = curve(a, mid, b)
        img = stroke(img, pts + np.array([0, 2.5]), (178, 172, 205), t + 5, alpha=0.45, blur=3)
        img = stroke(img, pts, LID, t)
    return img

def line_mouth(img, kind):
    img = clear_mouth(img)
    cx, cy = MOUTH_C
    if kind == 'worried':     # a small wobbly frown
        pts = np.concatenate([curve((cx - 30, cy + 12), (cx - 16, cy - 10), (cx, cy + 2)),
                              curve((cx, cy + 2), (cx + 16, cy - 8), (cx + 30, cy + 12))])
        w = 8.5
    elif kind == 'hmm':       # a small thoughtful mouth, off to one side
        pts = curve((cx - 6, cy + 4), (cx + 14, cy + 12), (cx + 34, cy - 2))
        w = 8.5
    pts = rot_pts(pts, TILT, np.array(MOUTH_C, np.float32))
    img = stroke(img, pts + np.array([0, 3]), (190, 180, 205), w + 5, alpha=0.45, blur=3)
    return stroke(img, pts, MOUTH, w)

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

# ── Parts ──────────────────────────────────────────────────────────────
ARM_PIVOT = (322, 702)
arm, _ = split(base, arm_mask(-1.0))
_, no_arm_clean = split(base, arm_mask(3.2))

def front_arm(feather=24, base_fade=70):
    """The arm for use in front of the body: its cut side and root melt away."""
    ex = interp(ARM_EDGE, yy)
    f = np.clip((ex - xx) / feather, 0, 1)
    f = f * f * (3 - 2 * f)
    g = np.clip((716 - yy) / base_fade, 0, 1)
    g = g * g * (3 - 2 * g)
    out = arm.copy(); out[..., 3] *= f * g
    return out

def with_ears(body, l_deg=0, r_deg=0):
    """Body with its ears swung about their roots (they sit behind it)."""
    ml, mr = ear_l_mask(), ear_r_mask()
    ear_l, rest = split(body, ml)
    ear_r, rest = split(rest, mr)
    # Roots tucked a little into the body so no gap opens when they swing.
    out = np.zeros_like(body)
    out = over(out, rotate(ear_l, l_deg, (446, 362), shift=(0, 6)))
    out = over(out, rotate(ear_r, r_deg, (626, 392), shift=(0, 6)))
    return over(out, rest)

def pose_wave():
    return base.copy()

def pose_point():
    out = np.zeros_like(base)
    out = over(out, rotate(arm, 50, ARM_PIVOT, shift=(16, -10)))
    return over(out, no_arm_clean)

def pose_cheer():
    body = happy_eyes(no_arm_clean)
    far, body = split(body, far_arm_mask())
    out = np.zeros_like(base)
    out = over(out, rotate(arm, 14, ARM_PIVOT, shift=(-2, -22)))
    mirrored = flip_x(arm, 537)
    out = over(out, rotate(mirrored, -18, (2 * 537 - ARM_PIVOT[0], ARM_PIVOT[1]), shift=(0, -24)))
    return over(out, body)

def pose_worried():
    body = line_mouth(worried_brows(no_arm_clean), 'worried')
    body = with_ears(body, 34, -38)
    out = np.zeros_like(base)
    out = over(out, rotate(arm, 104, ARM_PIVOT, shift=(14, -26)))
    return over(out, body)

def pose_think():
    body = line_mouth(no_arm_clean, 'hmm')
    # The arm comes round the front, hand up to the chin.
    front = rotate(front_arm(), -58, ARM_PIVOT, shift=(100, 138))
    shade = clip_to(shadow_of(front, 4, 9, 8, 0.6), body[..., 3])
    return over(over(body, shade), front)

POSES = {'wave': pose_wave, 'point': pose_point, 'cheer': pose_cheer,
         'worried': pose_worried, 'think': pose_think}

FRAME = (97, 82, 880)   # x, y, side: one frame for every pose
OUT = 640

def export(img, path):
    x, y, side = FRAME
    crop = np.clip(img[y:y + side, x:x + side], 0, 1)
    pm = crop.copy(); pm[..., :3] *= pm[..., 3:4]
    pm = cv2.resize(pm, (OUT, OUT), interpolation=cv2.INTER_AREA)
    a = pm[..., 3:4]
    pm[..., :3] = np.where(a > 1e-4, pm[..., :3] / np.maximum(a, 1e-4), 1.0)
    cv2.imwrite(path, (np.clip(pm, 0, 1) * 255).astype(np.uint8),
                [cv2.IMWRITE_WEBP_QUALITY, 92])

if __name__ == '__main__':
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, build in POSES.items():
        export(build(), os.path.join(OUT_DIR, f'rabi_{name}.webp'))
        print('wrote', name)
