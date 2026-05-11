#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFilter
import os, math

def bezier_pts(p0, p1, p2, p3, n=50):
    pts = []
    for i in range(n):
        t = i / (n - 1)
        u = 1 - t
        x = u**3*p0[0] + 3*u**2*t*p1[0] + 3*u*t**2*p2[0] + t**3*p3[0]
        y = u**3*p0[1] + 3*u**2*t*p1[1] + 3*u*t**2*p2[1] + t**3*p3[1]
        pts.append((int(x), int(y)))
    return pts

def create_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    pad = max(1, int(size * 0.025))
    corner = int(size * 0.22)
    cx = size // 2

    # ── Background gradient (dark navy → dark indigo) ──────────────────────
    bg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bg)
    for y in range(size):
        t = y / size
        r = int(8  + t * 10)
        g = int(6  + t * 8)
        b = int(22 + t * 14)
        bd.line([(0, y), (size, y)], fill=(r, g, b, 255))

    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [pad, pad, size-pad-1, size-pad-1], radius=corner, fill=255)
    img.paste(bg, mask=mask)

    # ── Warm amber glow behind cup ──────────────────────────────────────────
    gw = int(size * 0.72)
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    gx = cx - gw // 2
    gy = int(size * 0.28) - gw // 4
    ImageDraw.Draw(glow).ellipse([gx, gy, gx+gw, gy+gw], fill=(255, 120, 30, 45))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=int(size * 0.12)))
    img = Image.alpha_composite(img, glow)

    draw = ImageDraw.Draw(img)

    # ── Cup geometry ────────────────────────────────────────────────────────
    top_y   = int(size * 0.305)
    bot_y   = int(size * 0.695)
    top_hw  = int(size * 0.240)
    bot_hw  = int(size * 0.200)
    cream   = (243, 235, 220)

    # Body (trapezoid)
    draw.polygon([
        (cx - top_hw, top_y),
        (cx + top_hw, top_y),
        (cx + bot_hw, bot_y),
        (cx - bot_hw, bot_y),
    ], fill=cream)

    # Coffee surface ellipse
    eh = int(size * 0.026)
    draw.ellipse([cx - top_hw, top_y - eh, cx + top_hw, top_y + eh],
                 fill=(42, 20, 6))

    # Subtle coffee shine
    shine_w = int(size * 0.06)
    shine_h = int(size * 0.008)
    draw.ellipse([cx - top_hw + int(size*0.05),
                  top_y - eh//2 - shine_h,
                  cx - top_hw + int(size*0.05) + shine_w,
                  top_y - eh//2 + shine_h],
                 fill=(80, 50, 25))

    # Handle
    hx  = cx + top_hw - int(size * 0.015)
    ht  = int(size * 0.40)
    hb  = int(size * 0.615)
    hrw = int(size * 0.135)
    hlw = max(2, int(size * 0.034))
    draw.arc([hx, ht, hx+hrw, hb], start=-90, end=90, fill=cream, width=hlw)

    # Saucer
    s_hw = int(size * 0.290)
    s_y  = bot_y - int(size * 0.005)
    s_h  = int(size * 0.042)
    draw.ellipse([cx - s_hw, s_y, cx + s_hw, s_y + s_h], fill=cream)

    # ── Steam wisps (bezier curves composited as soft layer) ────────────────
    steam_y = top_y - eh

    for i, dx in enumerate([-int(size*0.085), 0, int(size*0.085)]):
        sx   = cx + dx
        sw   = 1 if i % 2 == 0 else -1
        pull = int(size * 0.065)
        p0   = (sx,              steam_y)
        p1   = (sx + sw*pull,    steam_y - int(size * 0.095))
        p2   = (sx - sw*pull,    steam_y - int(size * 0.200))
        p3   = (sx + sw*pull//2, steam_y - int(size * 0.295))

        pts  = bezier_pts(p0, p1, p2, p3)
        lw   = max(2, int(size * 0.021))

        layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        ld    = ImageDraw.Draw(layer)
        n     = len(pts)
        for k in range(n - 1):
            alpha = int(140 * (1 - k / n))
            ld.line([pts[k], pts[k+1]], fill=(205, 195, 220, alpha), width=lw)

        layer = layer.filter(ImageFilter.GaussianBlur(radius=max(1, int(size * 0.007))))
        img = Image.alpha_composite(img, layer)

    return img


# ── Iconset sizes ────────────────────────────────────────────────────────────
FILES = {
    'icon_16x16.png':      16,
    'icon_16x16@2x.png':   32,
    'icon_32x32.png':      32,
    'icon_32x32@2x.png':   64,
    'icon_128x128.png':    128,
    'icon_128x128@2x.png': 256,
    'icon_256x256.png':    256,
    'icon_256x256@2x.png': 512,
    'icon_512x512.png':    512,
    'icon_512x512@2x.png': 1024,
}

iconset = '/tmp/KeepAwake.iconset'
os.makedirs(iconset, exist_ok=True)

print('Rendering 1024×1024 base...')
base = create_icon(1024)

for fname, sz in FILES.items():
    icon = base if sz == 1024 else base.resize((sz, sz), Image.LANCZOS)
    icon.save(os.path.join(iconset, fname), 'PNG')
    print(f'  {fname} ({sz}px)')

print('Done.')
