"""Emberwell game icon: a gold-rimmed heraldic shield (the flaming well inside), two swords crossed behind it,
a crown of gold flame-points on top, and the name on a red ribbon across the bottom, on a glowing ember field."""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = sys.argv[1]
S = 1024
W = H = S
FONT = "C:/Windows/Fonts/BOD_BLAR.TTF"
rng = np.random.default_rng(5)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
cx = W / 2


def blur(a, r):
    im = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r)), dtype=np.float32) / 255


def noise(scale, octaves=4, seed=0):
    r = np.random.default_rng(seed)
    acc = np.zeros((H, W), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        s = max(2, int(scale * 2 ** o))
        small = r.random((s, s)).astype(np.float32)
        big = np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), np.float32) / 255
        acc += big * amp
        tot += amp
        amp *= 0.5
    return acc / tot


def over(dst, rgb, alpha):
    a = np.clip(alpha, 0, 1)[..., None]
    dst[..., :3] = dst[..., :3] * (1 - a) + np.broadcast_to(rgb, dst[..., :3].shape) * a


def add(dst, rgb, alpha):
    a = np.clip(alpha, 0, 1)[..., None]
    dst[..., :3] = np.clip(dst[..., :3] + np.broadcast_to(rgb, dst[..., :3].shape) * a, 0, 1)


def mask_from(draw_fn):
    im = Image.new("L", (W * 2, H * 2), 0)
    draw_fn(ImageDraw.Draw(im), 2)
    return np.asarray(im.resize((W, H), Image.LANCZOS), np.float32) / 255


def bevel(mask, radius, strength=40, light=(-0.5, -0.65, 0.58)):
    hgt = blur(mask, radius)
    gy, gx = np.gradient(hgt)
    nz = 1.0 / np.sqrt(1 + (gx * strength) ** 2 + (gy * strength) ** 2)
    nx, ny = -gx * strength * nz, -gy * strength * nz
    L = np.array(light, np.float32)
    L /= np.linalg.norm(L)
    shade = nx * L[0] + ny * L[1] + nz * L[2]
    return shade, np.clip(shade, 0, 1) ** 16


def gold_ramp(v):
    stops = [(0.0, (1.0, 0.95, 0.70)), (0.35, (0.97, 0.76, 0.32)), (0.5, (0.62, 0.33, 0.09)),
             (0.56, (0.93, 0.68, 0.26)), (0.8, (0.78, 0.47, 0.14)), (1.0, (0.45, 0.22, 0.06))]
    g = np.zeros(v.shape + (3,), np.float32)
    for i in range(3):
        g[..., i] = np.interp(v, [s[0] for s in stops], [s[1][i] for s in stops])
    return g


def gold_metal(mask, top, bottom, radius=4, strength=45):
    v = np.clip((yy - top) / max(bottom - top, 1), 0, 1)
    shade, spec = bevel(mask, radius, strength)
    m = gold_ramp(v) * (0.45 + 0.75 * shade[..., None]) + spec[..., None] * 0.9
    return np.clip(m * (0.93 + 0.14 * noise(160, 2, 9))[..., None], 0, 1)


canvas = np.zeros((H, W, 3), np.float32)

# ---- the field: dark, glowing warm in the middle, embers --------------------------------------------
r = np.sqrt((xx - cx) ** 2 + (yy - 470) ** 2) / (S * 0.75)
base = np.stack([0.30 - r * 0.26, 0.09 - r * 0.08, 0.04 - r * 0.035], -1)
canvas[:] = np.clip(base, 0.01, 1) * (0.85 + 0.3 * noise(6, 4, 1))[..., None]
add(canvas, np.array([1.0, 0.42, 0.1]), np.clip(1 - r * 1.6, 0, 1) ** 2 * 0.55)
rays = (np.sin(np.arctan2(yy - 470, xx - cx) * 14) * 0.5 + 0.5) ** 6 * np.clip(1 - r * 1.3, 0, 1)
add(canvas, np.array([1.0, 0.55, 0.2]), rays * 0.18)

# ---- two swords crossed behind the shield, points up and out --------------------------------------
def sword(angle):
    L, bw = 1150, 44
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sw = Image.new("RGBA", (160, L), (0, 0, 0, 0))
    a = np.zeros((L, 160, 4), np.float32)
    gy, gx = np.mgrid[0:L, 0:160].astype(np.float32)
    mid = 80
    tip, guard = 20, int(L * 0.72)
    hw = np.where(gy < tip + 120, bw * np.clip((gy - tip) / 120, 0, 1) ** 0.7, bw - (gy - tip - 120) / (guard - tip - 120) * 7)
    u = (gx - mid) / np.maximum(hw, 0.5)
    blade = ((np.abs(u) <= 1) & (gy >= tip) & (gy < guard)).astype(np.float32)
    b = 0.55 + 0.3 * np.clip(-u, -1, 1) + 0.45 * np.exp(-(u * 7) ** 2) + 0.2 * (np.abs(u) > 0.8)
    a[..., 0], a[..., 1], a[..., 2] = 0.74 * b, 0.77 * b, 0.82 * b
    a[..., 0] += 0.4 * np.clip(u, 0, 1)
    a[..., 1] += 0.15 * np.clip(u, 0, 1)
    a[..., 3] = blade
    gv = np.clip((gy - guard) / 34, 0, 1)
    gc = np.stack([0.98 - gv * 0.5, 0.75 - gv * 0.45, 0.3 - gv * 0.22], -1)
    g = ((gy >= guard) & (gy < guard + 34) & (np.abs(gx - mid) < 74)).astype(np.float32)
    grip = ((gy >= guard + 34) & (gy < guard + 200) & (np.abs(gx - mid) < 15)).astype(np.float32)
    pom = (((gx - mid) ** 2 + (gy - guard - 222) ** 2) < 26 ** 2).astype(np.float32)
    wrap = (np.sin(gy * 0.5) > 0.2).astype(np.float32)
    gripc = np.stack([0.24 + wrap * 0.1, 0.12 + wrap * 0.05, 0.07 + 0 * wrap], -1)
    for m, c in ((g, gc), (grip, gripc), (pom, gc)):
        a[..., :3] = np.where(m[..., None] > 0, c, a[..., :3])
        a[..., 3] = np.maximum(a[..., 3], m)
    sw = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA")
    lay.paste(sw, (int(cx - mid), int(520 - L * 0.5)), sw)
    return lay.rotate(angle, resample=Image.BICUBIC, center=(cx, 520))


for ang in (48, -48):
    s = np.asarray(sword(ang), np.float32) / 255
    over(canvas, np.zeros(3) + 0.02, blur(s[..., 3], 8) * 0.7)
    over(canvas, s[..., :3], s[..., 3])

# ---- the shield ---------------------------------------------------------------------------------
def shield_pts(k, inset):
    # a heater shield: a gently arched top, straight sides, curving to a point
    top, bot, half = 215 + inset, 830 - inset * 1.25, 300 - inset
    pts = []
    for i in range(41):
        t = i / 40
        x = cx - half + 2 * half * t
        pts.append((x, top + 28 * (1 - (2 * t - 1) ** 2) * -1 + 28))
    for i in range(1, 41):
        t = i / 40
        x = cx + half * (1 - t ** 1.6)
        y = top + 28 + (bot - top - 28) * (t ** 0.85)
        x = cx + half * np.cos(t * np.pi / 2) ** 0.75
        pts.append((x, top + 28 + (bot - top - 28) * np.sin(t * np.pi / 2) ** 1.4))
    for i in range(1, 40):
        t = 1 - i / 40
        x = cx - half * np.cos(t * np.pi / 2) ** 0.75
        pts.append((x, top + 28 + (bot - top - 28) * np.sin(t * np.pi / 2) ** 1.4))
    return [(x * k, y * k) for x, y in pts]


outer = mask_from(lambda d, k: d.polygon(shield_pts(k, 0), fill=255))
inner = mask_from(lambda d, k: d.polygon(shield_pts(k, 48), fill=255))
inner_line = mask_from(lambda d, k: d.polygon(shield_pts(k, 42), fill=255))
add(canvas, np.array([1.0, 0.45, 0.1]), blur(outer, 45) * 0.55)  # a warm halo
over(canvas, np.zeros(3), blur(outer, 14) * 0.8)  # its shadow
rim = np.clip(outer - inner, 0, 1)
over(canvas, gold_metal(outer, 200, 840, 5, 30), outer)
# the field inside: deep red-brown stone
fn = noise(30, 4, 3)
field = np.stack([0.26 + fn * 0.12, 0.07 + fn * 0.05, 0.05 + fn * 0.03], -1)
vign = np.clip(1 - np.sqrt(((xx - cx) / 260) ** 2 + ((yy - 520) / 330) ** 2), 0, 1)
field = field * (0.45 + 0.8 * vign[..., None])
lattice = ((np.abs(np.sin((xx + yy) / 34)) < 0.06) | (np.abs(np.sin((xx - yy) / 34)) < 0.06)).astype(np.float32)
field = field * (1 - lattice[..., None] * 0.35) + np.array([0.5, 0.2, 0.05]) * (lattice * 0.06)[..., None]
over(canvas, np.zeros(3) + 0.05, np.clip(inner_line - inner, 0, 1) * 0.9)
over(canvas, field, inner)
# rivets on the rim
riv = Image.new("L", (W, H), 0)
rd = ImageDraw.Draw(riv)
for x, y in shield_pts(1, 22)[::8]:
    rd.ellipse([x - 7, y - 7, x + 7, y + 7], fill=255)
riv_a = np.asarray(riv, np.float32) / 255
sh, sp = bevel(riv_a, 2, 30)
over(canvas, np.clip(np.array([0.95, 0.78, 0.4]) * (0.5 + 0.6 * sh[..., None]) + sp[..., None], 0, 1), riv_a)

# ---- inside: the well and its fire -----------------------------------------------------------------
wy, wrx, wry = 640, 175, 40
e = ((xx - cx) / wrx) ** 2 + ((yy - wy) / wry) ** 2
e_in = ((xx - cx) / (wrx - 34)) ** 2 + ((yy - wy) / (wry - 13)) ** 2
pit = np.clip((1 - e_in) * 6, 0, 1) * inner
depth = np.clip(1 - e_in, 0, 1)
over(canvas, np.stack([0.4 + depth, 0.1 + depth ** 1.5 * 0.8, depth ** 3 * 0.5], -1).clip(0, 1), pit)
flame = np.zeros((H, W), np.float32)
n1, n2 = noise(5, 5, 11), noise(10, 4, 12)
for ox, height, w0 in [(0, 380, 120), (-70, 260, 70), (75, 280, 72), (-30, 330, 85), (35, 320, 85)]:
    t = np.clip((wy - yy) / height, 0, 1.2)
    wob = (n1 - 0.5) * 120 * t + np.sin(yy / 30 + ox) * 10 * t
    width = w0 * np.clip(1 - t, 0, 1) ** 0.9
    f = np.clip(1 - np.abs(xx - cx - ox - wob) / np.maximum(width, 1), 0, 1) ** 0.7 * (yy < wy + 4) * (width > 4)
    flame = np.maximum(flame, f)
flame = blur(np.clip(flame * np.clip(n2 * 1.4 + 0.3, 0, 1) * 1.5, 0, 1), 3) * inner
heat = np.clip(flame * (1.25 - np.clip((wy - yy) / 380, 0, 1) * 0.7), 0, 1)
fcol = np.stack([np.ones_like(heat), np.clip(0.15 + heat * 0.85, 0, 1), np.clip((heat - 0.55) * 1.7, 0, 1) * 0.85], -1)
add(canvas, np.array([1.0, 0.35, 0.08]), blur(flame, 30) * 0.7 * inner)
add(canvas, fcol, flame)
# the well's stone rim (front half over the fire's foot)
ring = ((e <= 1) & (e_in > 1)).astype(np.float32)
sn = noise(50, 3, 14)
stone = np.stack([0.42 + sn * 0.2, 0.36 + sn * 0.17, 0.32 + sn * 0.15], -1)
lit = np.clip(1.5 - e_in, 0, 1) ** 2
stone = stone * (0.6 + 0.4 * (yy < wy)[..., None]) + np.array([1.0, 0.45, 0.1]) * lit[..., None] * 0.6
ang = np.arctan2((yy - wy) / wry, (xx - cx) / wrx)
stone = stone * (1 - (np.abs(np.sin(ang * 12)) < 0.07)[..., None] * 0.6)
over(canvas, np.clip(stone, 0, 1), blur(ring, 1))
side = ((e > 1) & (((xx - cx) / wrx) ** 2 + ((yy - wy - 26) / wry) ** 2 <= 1) & (yy >= wy)).astype(np.float32)
over(canvas, np.clip(stone * 0.55, 0, 1), blur(side, 1))

# ---- a crown of gold flame-points on top ------------------------------------------------------------
def crown(d, k):
    base_y = 236
    for ox, h, w in [(0, 175, 52), (-100, 125, 40), (100, 125, 40), (-195, 85, 34), (195, 85, 34)]:
        x = cx + ox
        pts = [(x - w, base_y), (x - w * 0.55, base_y - h * 0.45), (x - w * 0.15, base_y - h * 0.62),
               (x + w * 0.1, base_y - h), (x + w * 0.35, base_y - h * 0.55), (x + w, base_y)]
        d.polygon([(px * k, py * k) for px, py in pts], fill=255)
    d.ellipse([(cx - 22) * k, (base_y - 60) * k, (cx + 22) * k, (base_y - 16) * k], fill=0)


cr = mask_from(crown)
over(canvas, np.zeros(3) + 0.08, np.clip(blur(cr, 4) * 2.5, 0, 1))
over(canvas, gold_metal(cr, 80, 240, 3, 40), cr)
gem = mask_from(lambda d, k: d.ellipse([(cx - 17) * k, (236 - 55) * k, (cx + 17) * k, (236 - 21) * k], fill=255))
add(canvas, np.array([1.0, 0.4, 0.1]), blur(gem, 14) * 1.2)
gs, gsp = bevel(gem, 3, 25)
over(canvas, np.clip(np.array([1.0, 0.35, 0.08]) * (0.6 + 0.6 * gs[..., None]) + gsp[..., None], 0, 1), gem)

# ---- the ribbon with the name -------------------------------------------------------------------------
by, bh, sag = 760, 150, 46  # its middle's top, its height, how much it bows down at the centre
curve = lambda x: by + sag * (1 - ((x - cx) / 470) ** 2)  # (bows upward at the ends)
top_edge = curve(xx)
band = ((yy >= top_edge) & (yy <= top_edge + bh) & (np.abs(xx - cx) <= 430)).astype(np.float32)
# folded tails behind the ends
tail = Image.new("L", (W * 2, H * 2), 0)
td = ImageDraw.Draw(tail)
for sgn in (-1, 1):
    x0 = cx + sgn * 400
    y0 = curve(x0) + 40
    pts = [(x0, y0), (x0 + sgn * 110, y0 - 10), (x0 + sgn * 70, y0 + bh * 0.5), (x0 + sgn * 112, y0 + bh + 6), (x0, y0 + bh)]
    td.polygon([(px * 2, py * 2) for px, py in pts], fill=255)
tail_a = np.asarray(tail.resize((W, H), Image.LANCZOS), np.float32) / 255 * (1 - band)
over(canvas, np.zeros(3), blur(tail_a + band, 10) * 0.7)
over(canvas, np.array([0.36, 0.06, 0.04]), tail_a)
v = np.clip((yy - top_edge) / bh, 0, 1)
red = np.stack([0.62 - v * 0.3, 0.1 - v * 0.05, 0.07 - v * 0.03], -1) * (0.9 + 0.2 * noise(80, 2, 21))[..., None]
over(canvas, red, band)
edges = (band * ((yy - top_edge < 9) | (top_edge + bh - yy < 9))).astype(np.float32)
over(canvas, gold_metal(edges, 0, H, 2, 20), edges)

# the name: flat text, then bent along the ribbon
txt = Image.new("L", (W, H), 0)
font = ImageFont.truetype(FONT, 118)
ImageDraw.Draw(txt).text((cx, by + bh / 2 + 4), "EMBERWELL", font=font, fill=255, anchor="mm")
t = np.asarray(txt, np.float32) / 255
bent = np.zeros_like(t)
for x in range(W):
    shift = int(round(curve(x) - by))
    bent[:, x] = np.roll(t[:, x], shift)
ys = np.nonzero(bent.max(1) > 0.5)[0]
ttop, tbot = ys.min(), ys.max()
over(canvas, np.array([0.12, 0.03, 0.02]), np.clip(blur(bent, 4) * 3.5, 0, 1))
over(canvas, gold_metal(bent, ttop, tbot, 3, 40), bent)

# ---- embers over everything ------------------------------------------------------------------------
dots = Image.new("L", (W, H), 0)
dd = ImageDraw.Draw(dots)
for _ in range(60):
    ex, ey = rng.uniform(40, W - 40), rng.uniform(40, 700)
    if abs(ex - cx) < 300 and 200 < ey < 760:
        continue
    rr = rng.uniform(2, 5)
    dd.ellipse([ex - rr, ey - rr, ex + rr, ey + rr], fill=int(rng.uniform(150, 255)))
d_a = np.asarray(dots, np.float32) / 255
add(canvas, np.array([1.0, 0.5, 0.15]), blur(d_a, 6) * 1.6)
add(canvas, np.array([1.0, 0.85, 0.55]), d_a)

img = Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), "RGB")
img.save(OUT)
img.resize((512, 512), Image.LANCZOS).save(OUT.replace(".png", "_512.png"))
img.resize((150, 150), Image.LANCZOS).save(OUT.replace(".png", "_small.png"))
print("ok")
