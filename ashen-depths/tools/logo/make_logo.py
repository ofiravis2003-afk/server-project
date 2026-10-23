"""Emberwell logo: gold bevelled title over a flame rising from a stone well rim, embers, ornament."""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = sys.argv[1]
W, H = 2400, 1200
rng = np.random.default_rng(7)
FONT = "C:/Windows/Fonts/CASTELAR.TTF"


def blur(a, r):
    im = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r)), dtype=np.float32) / 255


def noise(scale, octaves=4, seed=0):
    r = np.random.default_rng(seed)
    acc = np.zeros((H, W), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        s = max(2, int(scale * 2 ** o))
        small = r.random((s, s * 2)).astype(np.float32)
        big = np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), np.float32) / 255
        acc += big * amp
        tot += amp
        amp *= 0.5
    return acc / tot


def over(dst, rgb, alpha):
    """alpha-composite a layer (rgb HxWx3 0..1, alpha HxW 0..1) over dst (HxWx4 premultiplied-free)."""
    a = np.clip(alpha, 0, 1)[..., None]
    da = dst[..., 3:4]
    out_a = a + da * (1 - a)
    out_rgb = (rgb * a + dst[..., :3] * da * (1 - a)) / np.maximum(out_a, 1e-6)
    dst[..., :3] = out_rgb
    dst[..., 3:4] = out_a


def add_glow(dst, rgb, alpha):
    """additive light (for fire and glows): brightens and adds coverage."""
    a = np.clip(alpha, 0, 1)[..., None]
    da = dst[..., 3:4]
    lit = dst[..., :3] * da + np.array(rgb, np.float32) * a if np.ndim(rgb) == 1 else dst[..., :3] * da + rgb * a
    out_a = np.clip(da + a, 0, 1)
    dst[..., :3] = np.clip(lit / np.maximum(out_a, 1e-6), 0, 1)
    dst[..., 3:4] = out_a



def layer_over(dst, layer):
    """composite a full-canvas RGBA PIL image over dst."""
    a = np.asarray(layer, np.float32) / 255
    over(dst, a[..., :3], a[..., 3])


def mirrored(layer):
    return layer.transpose(Image.FLIP_LEFT_RIGHT)


def sword_layer(angle, cross, length=980):
    """a steel longsword, tip up, lit warm on its right side by the fire; rotated by angle around cross."""
    sw, sh = 300, length
    gy, gx = np.mgrid[0:sh, 0:sw].astype(np.float32)
    mid = sw / 2
    tip, guard = 40, int(sh * 0.70)
    hw = np.where(gy < tip + 140, 44 * np.clip((gy - tip) / 140, 0, 1) ** 0.7, 44 - (gy - tip - 140) / (guard - tip - 140) * 8)
    u = (gx - mid) / np.maximum(hw, 0.5)
    blade = ((np.abs(u) <= 1) & (gy >= tip) & (gy < guard)).astype(np.float32)
    b = 0.5 + 0.3 * np.clip(-u, -1, 1)
    b = b + 0.45 * np.exp(-(u * 8) ** 2)  # the bright ridge
    b = b + 0.25 * (np.abs(u) > 0.82)  # honed edges
    steel = np.stack([0.72 * b, 0.75 * b, 0.80 * b], -1)
    steel += np.array([0.55, 0.22, 0.05]) * np.clip(u, 0, 1)[..., None] * 0.8  # fire on its right flank
    steel *= (0.85 + 0.3 * np.asarray(Image.fromarray((np.random.default_rng(3).random((sh // 40 + 1, sw // 40 + 1)) * 255).astype(np.uint8)).resize((sw, sh), Image.BICUBIC), np.float32)[..., None] / 255)
    rgba = np.zeros((sh, sw, 4), np.float32)
    rgba[..., :3] = np.clip(steel, 0, 1)
    rgba[..., 3] = blade
    # crossguard, grip, pommel
    def put(maskarr, col):
        rgba[..., :3] = np.where(maskarr[..., None] > 0, col, rgba[..., :3])
        rgba[..., 3] = np.maximum(rgba[..., 3], maskarr)
    gv = np.clip((gy - guard) / 30, 0, 1)
    goldcol = np.stack([0.95 - gv * 0.5, 0.72 - gv * 0.45, 0.30 - gv * 0.22], -1)
    put(((gy >= guard) & (gy < guard + 30) & (np.abs(gx - mid) < 125 - (gy - guard) * 0.4)).astype(np.float32), goldcol)
    for sx in (-1, 1):
        put((((gx - mid - sx * 128) ** 2 + (gy - guard - 14) ** 2) < 17 ** 2).astype(np.float32), goldcol)
    grip_end = guard + 30 + int(sh * 0.17)
    wrap = (np.sin((gy - guard) * 0.55) > 0.3).astype(np.float32)
    gripcol = np.stack([0.20 + wrap * 0.10, 0.10 + wrap * 0.05, 0.06 + wrap * 0.02], -1) * (0.7 + 0.5 * np.clip(-(gx - mid) / 14, -1, 1))[..., None]
    put(((gy >= guard + 30) & (gy < grip_end) & (np.abs(gx - mid) < 15)).astype(np.float32), np.clip(gripcol, 0, 1))
    pv = np.clip((gy - grip_end) / 50, 0, 1)
    put((((gx - mid) ** 2 + (gy - grip_end - 22) ** 2) < 26 ** 2).astype(np.float32), np.stack([0.95 - pv * 0.5, 0.7 - pv * 0.45, 0.3 - pv * 0.2], -1))
    im = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")
    pivot = (mid, sh * 0.42)
    big = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    big.paste(im, (int(cross[0] - pivot[0]), int(cross[1] - pivot[1])), im)
    return big.rotate(angle, resample=Image.BICUBIC, center=cross)


def chain_layer(start, end, link=46):
    """an iron chain from start to end, lit orange on the side facing the middle."""
    dx, dy = end[0] - start[0], end[1] - start[1]
    length = int(np.hypot(dx, dy))
    cw = 70
    strip = np.zeros((length, cw, 4), np.float32)
    gy, gx = np.mgrid[0:length, 0:cw].astype(np.float32)
    m = cw / 2
    mask = np.zeros((length, cw), np.float32)
    k = 0
    for y0 in range(0, length - link, int(link * 0.78)):
        cy = y0 + link / 2
        if k % 2 == 0:  # a link seen face on: an oval ring
            e_o = ((gx - m) / 21) ** 2 + ((gy - cy) / (link / 2)) ** 2
            e_i = ((gx - m) / 10) ** 2 + ((gy - cy) / (link / 2 - 10)) ** 2
            mask = np.maximum(mask, ((e_o <= 1) & (e_i > 1)).astype(np.float32))
        else:  # a link seen edge on: a bar
            mask = np.maximum(mask, ((np.abs(gx - m) < 6) & (np.abs(gy - cy) < link / 2)).astype(np.float32))
        k += 1
    side = np.clip((gx - m) / 21, -1, 1)
    col = np.stack([0.16 + 0.05 * side, 0.14 + 0.03 * side, 0.13 + 0.02 * side], -1)
    col += np.array([0.9, 0.4, 0.1]) * np.clip(side, 0, 1)[..., None] ** 1.5 * 0.9
    strip[..., :3] = np.clip(col, 0, 1)
    strip[..., 3] = mask
    im = Image.fromarray((strip * 255).astype(np.uint8), "RGBA")
    ang = np.degrees(np.arctan2(dx, dy))
    big = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    big.paste(im, (int(start[0] - m), int(start[1])), im)
    return big.rotate(ang, resample=Image.BICUBIC, center=start)


canvas = np.zeros((H, W, 4), np.float32)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
cx = W / 2

# ---- the text mask -------------------------------------------------------------------------
word = "EMBERWELL"
big, small = 330, 260
mask_img = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(mask_img)
fb, fs = ImageFont.truetype(FONT, big), ImageFont.truetype(FONT, small)
letters = [(c, fb if i in (0, 5) else fs) for i, c in enumerate(word)]
track = 6
widths = [d.textbbox((0, 0), c, font=f)[2] - d.textbbox((0, 0), c, font=f)[0] for c, f in letters]
total = sum(widths) + track * (len(letters) - 1)
baseline = 790
x = cx - total / 2
for (c, f), w in zip(letters, widths):
    bb = d.textbbox((0, 0), c, font=f, anchor="ls")
    d.text((x - bb[0], baseline), c, font=f, fill=255, anchor="ls")
    x += w + track
text = np.asarray(mask_img, np.float32) / 255
ys, xs = np.nonzero(text > 0.5)
top, bot, left, right = ys.min(), ys.max(), xs.min(), xs.max()

# ---- the well: a ring of stones in perspective, a glowing pit, fire rising out of it --------
rim_y, rim_rx, rim_ry, rim_h = 850, 600, 96, 46
e = ((xx - cx) / rim_rx) ** 2 + ((yy - rim_y) / rim_ry) ** 2
e_in = ((xx - cx) / (rim_rx - 80)) ** 2 + ((yy - rim_y) / (rim_ry - 30)) ** 2
e_low = ((xx - cx) / rim_rx) ** 2 + ((yy - rim_y - rim_h) / rim_ry) ** 2
ang = np.arctan2((yy - rim_y) / rim_ry, (xx - cx) / rim_rx)
stone_n = noise(60, 4, 5)
grain = noise(220, 2, 6)
base_stone = np.stack([0.24 + stone_n * 0.22, 0.19 + stone_n * 0.17, 0.16 + stone_n * 0.13], -1) * (0.7 + 0.6 * grain)[..., None]

# the pit: bright deep in the middle, dark at its walls
pit = np.clip((1 - e_in) * 8, 0, 1)
depth = np.clip(1 - e_in, 0, 1)
pit_col = np.stack([0.25 + depth * 0.85, 0.06 + depth ** 1.6 * 0.75, 0.02 + depth ** 3 * 0.45], -1)
over(canvas, np.clip(pit_col, 0, 1), blur(pit, 2))

# the top of the rim (behind the fire: its far half)
top_ring = ((e <= 1) & (e_in > 1)).astype(np.float32)
seams = (np.abs(np.sin(ang * 26 + 0.3)) < 0.06).astype(np.float32)
inner_lit = np.clip(1.6 - e_in, 0, 1)  # the edge nearest the fire is lit orange
top_col = base_stone * 0.9 + np.array([1.0, 0.45, 0.12]) * (inner_lit ** 2)[..., None] * 0.7
top_col = top_col * (1 - seams[..., None] * 0.65)
far = (yy < rim_y).astype(np.float32)
over(canvas, np.clip(top_col, 0, 1), blur(top_ring * far, 1.2))

# fire: several tongues, licking upward out of the pit
flame = np.zeros((H, W), np.float32)
n1 = noise(4, 5, 1)
n2 = noise(9, 4, 2)
tongues = [(0, 760, 300), (-170, 520, 170), (180, 560, 180), (-330, 330, 120), (340, 360, 120), (-70, 640, 200), (90, 600, 190)]
for ox, height, w0 in tongues:
    fy0 = rim_y + 10
    t = np.clip((fy0 - yy) / height, 0, 1.2)
    wob = (n1 - 0.5) * 220 * t + np.sin(yy / 55 + ox + n2 * 5) * 26 * t
    width = w0 * np.clip(1 - t, 0, 1) ** 0.9 * (0.6 + 0.4 * np.cos(t * 1.4))
    dx = np.abs(xx - cx - ox - wob)
    f = np.clip(1 - dx / np.maximum(width, 1), 0, 1) ** 0.7 * (yy < fy0) * (width > 6)
    flame = np.maximum(flame, f)
flame = flame * np.clip(n2 * 1.4 + 0.25, 0, 1)
flame = blur(np.clip(flame * 1.5, 0, 1), 5)
tt = np.clip((rim_y - yy) / 760, 0, 1)
heat = np.clip(flame * (1.25 - tt * 0.7), 0, 1)
col = np.stack([np.ones_like(heat), np.clip(0.15 + heat * 0.85, 0, 1), np.clip((heat - 0.55) * 1.7, 0, 1) * 0.85], -1)
add_glow(canvas, np.array([1.0, 0.32, 0.06]), blur(flame, 70) * 0.6)
add_glow(canvas, col, flame)
# two crossed swords, their points down in the fire, hilts up
sw_l = sword_layer(180 - 30, (cx, 520), 1050)
layer_over(canvas, sw_l)
layer_over(canvas, mirrored(sw_l))
# chains hanging down into the well (the old lift)
ch = chain_layer((cx - 760, -10), (cx - 420, rim_y - 20))
layer_over(canvas, ch)
layer_over(canvas, mirrored(ch))

# the near half of the rim in front of the fire: its top, then its side wall with blocks and mortar
near = 1 - far
over(canvas, np.clip(top_col, 0, 1), blur(top_ring * near, 1.2))
side = ((e > 1) & (e_low <= 1) & (yy >= rim_y)).astype(np.float32)
course = ((yy - rim_y - (rim_ry * np.sqrt(np.clip(1 - ((xx - cx) / rim_rx) ** 2, 0, 1)))) / rim_h)  # 0 top .. 1 bottom
mortar_h = (np.abs(course - 0.5) < 0.05).astype(np.float32)
shift = np.where(course < 0.5, 0.0, 0.5)
mortar_v = (np.abs(np.sin(ang * 13 + shift * np.pi)) < 0.05).astype(np.float32)
side_col = base_stone * (0.55 - 0.25 * np.clip(course, 0, 1))[..., None] * (0.7 + 0.5 * np.cos(ang - np.pi / 2) ** 2)[..., None]
side_col = side_col * (1 - np.maximum(mortar_h, mortar_v)[..., None] * 0.6)
over(canvas, np.clip(side_col, 0, 1), blur(side, 1.2))
# a dark line where the top meets the side
lip = ((e > 0.985) & (e <= 1.02) & (yy >= rim_y)).astype(np.float32)
over(canvas, np.zeros((H, W, 3)) + 0.05, blur(lip, 1) * 0.8)

# glowing runes cut into the side wall
rune = Image.new("L", (W, H), 0)
rd = ImageDraw.Draw(rune)
rr = np.random.default_rng(11)
for i in range(-9, 10):
    gxp = cx + i * 50
    yb = rim_y + rim_ry * np.sqrt(max(0.0, 1 - ((gxp - cx) / rim_rx) ** 2)) + rim_h * 0.5
    for _ in range(3):
        x1, y1 = gxp + rr.uniform(-10, 10), yb + rr.uniform(-13, 13)
        x2, y2 = gxp + rr.uniform(-10, 10), yb + rr.uniform(-13, 13)
        rd.line([(x1, y1), (x2, y2)], fill=255, width=3)
rune_a = np.asarray(rune, np.float32) / 255 * side * (1 - np.clip(np.abs(xx - cx) / rim_rx, 0, 1) ** 3)
add_glow(canvas, np.array([1.0, 0.5, 0.12]), blur(rune_a, 6) * 1.6)
add_glow(canvas, np.array([1.0, 0.85, 0.5]), rune_a)

# ---- the gold letters --------------------------------------------------------------------
dil1 = np.clip(blur(text, 7) * 3.2, 0, 1)  # dark edge
dil2 = np.clip(blur(text, 13) * 3.0, 0, 1)  # thin outer gold rim
glow = blur(dil2, 40)
add_glow(canvas, np.array([1.0, 0.45, 0.1]), glow * 0.9)
over(canvas, np.zeros((H, W, 3)) + np.array([0.75, 0.5, 0.18]), dil2)
over(canvas, np.zeros((H, W, 3)) + np.array([0.12, 0.05, 0.02]), dil1)

# gold gradient over the letters' height, with a bright horizon band
v = np.clip((yy - top) / (bot - top), 0, 1)
stops = [(0.0, (1.0, 0.97, 0.80)), (0.38, (0.98, 0.78, 0.36)), (0.52, (0.62, 0.32, 0.08)),
         (0.56, (0.95, 0.70, 0.28)), (0.8, (0.80, 0.48, 0.14)), (1.0, (0.45, 0.20, 0.05))]
gold = np.zeros((H, W, 3), np.float32)
for i in range(3):
    gold[..., i] = np.interp(v, [s[0] for s in stops], [s[1][i] for s in stops])
# bevel: light from upper left on a soft height field
hgt = blur(text, 5)
gy, gx = np.gradient(hgt)
nz = 1.0 / np.sqrt(1 + (gx * 40) ** 2 + (gy * 40) ** 2)
nx, ny = -gx * 40 * nz, -gy * 40 * nz
L = np.array([-0.5, -0.6, 0.62])
L = L / np.linalg.norm(L)
shade = nx * L[0] + ny * L[1] + nz * L[2]
spec = np.clip(shade, 0, 1) ** 18
metal = gold * (0.45 + 0.75 * shade[..., None]) + spec[..., None] * 0.9
# subtle hammered texture
metal *= (0.92 + 0.16 * noise(120, 2, 9))[..., None]
over(canvas, np.clip(metal, 0, 1), text)

# ---- the ornament under the word: lines and a diamond ---------------------------------------
orn = Image.new("L", (W, H), 0)
od = ImageDraw.Draw(orn)
oy = 1000
for sgn in (-1, 1):
    od.line([(cx + sgn * 60, oy), (cx + sgn * 520, oy)], fill=255, width=6)
    od.ellipse([cx + sgn * 540 - 9, oy - 9, cx + sgn * 540 + 9, oy + 9], fill=255)
od.polygon([(cx, oy - 34), (cx + 34, oy), (cx, oy + 34), (cx - 34, oy)], fill=255)
orn_a = np.asarray(orn, np.float32) / 255
fade = np.clip(1 - np.abs(xx - cx) / 600, 0, 1) ** 0.6
orn_a = orn_a * np.maximum(fade, (np.abs(xx - cx) < 40))
over(canvas, np.zeros((H, W, 3)) + np.array([0.12, 0.05, 0.02]), np.clip(blur(orn_a, 3) * 2, 0, 1))
over(canvas, gold * 0.9 + 0.1, orn_a)
gem = Image.new("L", (W, H), 0)
ImageDraw.Draw(gem).polygon([(cx, oy - 20), (cx + 20, oy), (cx, oy + 20), (cx - 20, oy)], fill=255)
gem_a = np.asarray(gem, np.float32) / 255
over(canvas, np.zeros((H, W, 3)) + np.array([1.0, 0.45, 0.1]), gem_a)
add_glow(canvas, np.array([1.0, 0.5, 0.15]), blur(gem_a, 18) * 1.5)

# ---- the tagline -------------------------------------------------------------------------
tag = Image.new("L", (W, H), 0)
ImageDraw.Draw(tag).text((cx, 1075), "DESCEND  •  SURVIVE  •  RETURN", font=ImageFont.truetype(FONT, 56), fill=255, anchor="mm")
tag_a = np.asarray(tag, np.float32) / 255
over(canvas, np.zeros((H, W, 3)) + np.array([0.1, 0.04, 0.02]), np.clip(blur(tag_a, 3) * 2.5, 0, 1))
tv = np.clip((yy - 1050) / 50, 0, 1)
tag_col = np.stack([1.0 - tv * 0.25, 0.85 - tv * 0.35, 0.55 - tv * 0.35], -1)
over(canvas, tag_col, tag_a)

# ---- embers -------------------------------------------------------------------------------
dots = Image.new("L", (W, H), 0)
dd = ImageDraw.Draw(dots)
for _ in range(120):
    ex = rng.normal(cx, 380)
    ey = rng.uniform(60, 900) if rng.random() < 0.8 else rng.uniform(60, 400)
    r = rng.uniform(2.0, 5.5)
    if top - 10 < ey < bot + 10 and left < ex < right:
        continue
    dd.ellipse([ex - r, ey - r, ex + r, ey + r], fill=int(rng.uniform(150, 255)))
dots_a = np.asarray(dots, np.float32) / 255
add_glow(canvas, np.array([1.0, 0.55, 0.15]), blur(dots_a, 8) * 1.8)
add_glow(canvas, np.array([1.0, 0.85, 0.5]), dots_a)

img = Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), "RGBA")
bb = img.getbbox()
img = img.crop((max(0, bb[0] - 24), max(0, bb[1] - 24), min(W, bb[2] + 24), min(H, bb[3] + 24)))
img.save(OUT)
# a preview on a dark background
bg = Image.new("RGBA", img.size, (14, 10, 9, 255))
bg.alpha_composite(img)
bg.convert("RGB").save(OUT.replace(".png", "_preview.jpg"), quality=90)
print(img.size)
