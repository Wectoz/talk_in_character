#!/usr/bin/env python3
"""Draws the Bronzetongue icon: Forever's infinity mark in a bronze speech bubble.

No image library is needed: shapes are signed distance functions, written out as PNG and TGA
with the standard library.  Run from the repo root:  python3 tools/make_icon.py
Outputs: curseforge/icon-400.png, Bronzetongue/Media/icon.tga (64x64),
         Bronzetongue/Media/infinity.tga (64x32, transparent, for the wheel and the panel).
"""
import math
import os
import struct
import zlib

LIGHT, MID, DARK = (0xF0, 0xD9, 0xA0), (0xB9, 0x8A, 0x3E), (0x5E, 0x43, 0x18)
INK = (0x19, 0x15, 0x10)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def bronze(t):
    """Bronze ramp: pale highlight, warm middle, deep shadow."""
    return mix(LIGHT, MID, t * 2) if t < 0.5 else mix(MID, DARK, t * 2 - 1)


def over(base, color, alpha):
    return mix(base, color, alpha)


def cover(distance, pixel):
    """Antialiased coverage of a shape whose edge is `distance` away (negative inside)."""
    return max(0.0, min(1.0, 0.5 - distance / pixel))


def sd_round_box(x, y, cx, cy, hw, hh, r):
    qx, qy = abs(x - cx) - hw + r, abs(y - cy) - hh + r
    return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r


def sd_triangle(x, y, pts):
    (x0, y0), (x1, y1), (x2, y2) = pts
    best, sign = 1e9, 1.0
    for (ax, ay), (bx, by) in (((x0, y0), (x1, y1)), ((x1, y1), (x2, y2)), ((x2, y2), (x0, y0))):
        ex, ey, wx, wy = bx - ax, by - ay, x - ax, y - ay
        t = max(0.0, min(1.0, (wx * ex + wy * ey) / (ex * ex + ey * ey)))
        best = min(best, math.hypot(wx - ex * t, wy - ey * t))
        if ex * wy - ey * wx < 0:
            sign = -1.0
    orient = (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0)
    inside = sign > 0 if orient > 0 else all(
        (bx - ax) * (y - ay) - (by - ay) * (x - ax) <= 0
        for (ax, ay), (bx, by) in (((x0, y0), (x1, y1)), ((x1, y1), (x2, y2)), ((x2, y2), (x0, y0))))
    return -best if inside else best


def lemniscate(cx, cy, a, squash, n=72):
    pts = []
    for i in range(n + 1):
        t = 2 * math.pi * i / n
        d = 1 + math.sin(t) ** 2
        pts.append((cx + a * math.cos(t) / d, cy + squash * a * math.sin(t) * math.cos(t) / d))
    return pts


def sd_polyline(x, y, pts):
    best = 1e9
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        ex, ey, wx, wy = bx - ax, by - ay, x - ax, y - ay
        t = max(0.0, min(1.0, (wx * ex + wy * ey) / (ex * ex + ey * ey + 1e-12)))
        d = math.hypot(wx - ex * t, wy - ey * t)
        if d < best:
            best = d
    return best


TAIL = ((0.27, 0.62), (0.47, 0.62), (0.24, 0.87))


def sd_bubble(x, y):
    return min(sd_round_box(x, y, 0.5, 0.435, 0.37, 0.25, 0.11), sd_triangle(x, y, TAIL))


def render_icon(size):
    px = 1.0 / size
    loop = lemniscate(0.5, 0.435, 0.255, 1.45)
    rows = []
    for j in range(size):
        y = (j + 0.5) * px
        row = []
        for i in range(size):
            x = (i + 0.5) * px
            # ground: warm glow fading to near black
            glow = math.hypot(x - 0.5, y - 0.42) / 0.75
            c = mix((0x4A, 0x38, 0x1A), (0x0B, 0x09, 0x06), glow)
            # bubble: soft shadow, bronze rim lit from the upper left, dark inside
            d = sd_bubble(x, y)
            c = over(c, (0, 0, 0), 0.55 * cover(sd_bubble(x - 0.015, y - 0.02) - 0.01, 0.05))
            c = over(c, bronze(0.15 + 0.75 * (x + y) / 2), cover(d, px))
            inner = d + 0.045
            c = over(c, mix((0x2E, 0x25, 0x19), (0x12, 0x0F, 0x0B), (y - 0.18) / 0.5), cover(inner, px))
            c = over(c, (0, 0, 0), 0.5 * cover(-inner - 0.0 , 0.03) * cover(inner, px))  # inner shadow under the rim
            # infinity mark: dark outline, bronze stroke, pale highlight along its upper edge
            if 0.18 < x < 0.82 and 0.24 < y < 0.63:
                dl = sd_polyline(x, y, loop)
                c = over(c, (0, 0, 0), 0.6 * cover(sd_polyline(x - 0.008, y - 0.014, loop) - 0.05, 0.03))
                c = over(c, (0x24, 0x18, 0x08), cover(dl - 0.052, px))
                c = over(c, bronze(0.10 + 0.8 * (y - 0.30) / 0.27), cover(dl - 0.040, px))
                dh = sd_polyline(x + 0.006, y + 0.012, loop)
                c = over(c, (0xFF, 0xF3, 0xCF), 0.55 * cover(dh - 0.010, px) * cover(dl - 0.040, px))
            # frame: bronze border with a dark inner line, like a game icon
            edge = min(x, y, 1 - x, 1 - y)
            c = over(c, (0, 0, 0), 0.7 * cover(edge - 0.055, px))
            c = over(c, bronze(0.1 + 0.8 * (x + y) / 2), cover(edge - 0.042, px))
            c = over(c, (0x10, 0x0C, 0x06), cover(edge - 0.008, px))
            row.append((int(c[0] + 0.5), int(c[1] + 0.5), int(c[2] + 0.5), 255))
        rows.append(row)
    return rows


def render_mark(width, height):
    """The infinity mark alone on a transparent ground."""
    loop = lemniscate(0.5, 0.25, 0.44, 1.5)
    px = 1.0 / width
    rows = []
    for j in range(height):
        y = (j + 0.5) * px
        row = []
        for i in range(width):
            x = (i + 0.5) * px
            dl = sd_polyline(x, y, loop)
            alpha = cover(dl - 0.055, px)
            c = bronze(0.1 + 0.8 * y / 0.5)
            row.append((int(c[0]), int(c[1]), int(c[2]), int(alpha * 255 + 0.5)))
        rows.append(row)
    return rows


def write_png(path, rows):
    height, width = len(rows), len(rows[0])
    raw = b"".join(b"\x00" + bytes(v for p in row for v in p) for row in rows)

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def write_tga(path, rows):
    """Uncompressed 32-bit TGA, the form the game reads. Rows are stored bottom up, as BGRA."""
    height, width = len(rows), len(rows[0])
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8)
    with open(path, "wb") as f:
        f.write(header)
        for row in reversed(rows):
            f.write(bytes(v for (r, g, b, a) in row for v in (b, g, r, a)))


if __name__ == "__main__":
    os.makedirs("curseforge", exist_ok=True)
    os.makedirs("Bronzetongue/Media", exist_ok=True)
    write_png("curseforge/icon-400.png", render_icon(400))
    small = render_icon(64)
    write_tga("Bronzetongue/Media/icon.tga", small)
    mark = render_mark(64, 32)
    write_tga("Bronzetongue/Media/infinity.tga", mark)
    print("wrote curseforge/icon-400.png, Bronzetongue/Media/icon.tga, Bronzetongue/Media/infinity.tga")
