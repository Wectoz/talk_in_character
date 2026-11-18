#!/usr/bin/env python3
"""Draws the Talk in Character icon: a laughing gold mask in a speech bubble, as pixel art, and
Forever's infinity mark for the wheel and the panel.

No image library is needed: shapes are signed distance functions, written out as PNG and TGA
with the standard library.  Run from the repo root:  python3 tools/make_icon.py
Outputs: curseforge/icon.png (448x448), TalkInCharacter/Media/icon.tga (64x64),
         TalkInCharacter/Media/infinity.tga (64x32, transparent, for the wheel and the panel).
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


GRID = 32  # the icon is pixel art on a 32 by 32 grid
OUTLINE = (0x2A, 0x16, 0x08)
BUBBLE_TAIL = ((0.27, 0.66), (0.47, 0.66), (0.22, 0.90))


def sd_bubble(x, y):
    return min(sd_round_box(x, y, 0.5, 0.46, 0.36, 0.26, 0.13), sd_triangle(x, y, BUBBLE_TAIL))


def sd_face(x, y):
    return (math.hypot((x - 0.5) / 0.200, (y - 0.462) / 0.212) - 1) * 0.200


def pixel(gx, gy):
    """The colour of grid cell (gx, gy): a laughing gold mask in a speech bubble."""
    cell = 1.0 / GRID
    cx, cy = (gx + 0.5) * cell, (gy + 0.5) * cell
    edge = min(cx, cy, 1 - cx, 1 - cy)
    if edge < cell:
        return OUTLINE
    if edge < 2 * cell:                                   # bronze frame, lit from the upper left
        return (0xD6, 0xA2, 0x4A) if cx + cy < 1 else (0x96, 0x68, 0x26)
    ex = gx if gx < GRID // 2 else GRID - 1 - gx          # the face is mirrored
    # eyes like "^ ^", and an open laugh three cells deep: placed by hand, as curves this small blur
    if (ex, gy) in ((12, 13), (13, 12), (14, 13)) or (gy == 16 and ex >= 11) or (gy == 17 and ex >= 12) or (gy == 18 and ex >= 13):
        return OUTLINE
    face, bubble = sd_face(cx, cy), sd_bubble(cx, cy)
    if face < 0:
        if face > -cell:
            return (0x7A, 0x48, 0x10)
        if (cx - 0.38) + (cy - 0.36) < 0.02:
            return (0xFF, 0xD8, 0x5A)                     # highlight
        return (0xF2, 0xB0, 0x30) if cy < 0.56 else (0xC8, 0x82, 0x1C)
    if bubble < 0:
        if bubble > -cell:
            return OUTLINE
        if bubble > -2.6 * cell:                          # the bubble's rim
            return (0xE8, 0xBC, 0x62) if cx + cy < 0.95 else (0xA8, 0x74, 0x2A)
        return (0x4A, 0x16, 0x26)
    # ground: a red glow with a dithered edge
    far = math.hypot(cx - 0.5, cy - 0.46)
    if far < 0.34 or (far < 0.44 and (gx + gy) % 2 == 0):
        return (0x9A, 0x22, 0x34)
    return (0x5C, 0x12, 0x22)


def render_icon(size):
    """`size` should be a multiple of 32, so every grid cell is the same number of pixels."""
    cells = [[pixel(gx, gy) + (255,) for gx in range(GRID)] for gy in range(GRID)]
    return [[cells[j * GRID // size][i * GRID // size] for i in range(size)] for j in range(size)]


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
    os.makedirs("TalkInCharacter/Media", exist_ok=True)
    write_png("curseforge/icon.png", render_icon(448))
    small = render_icon(64)
    write_tga("TalkInCharacter/Media/icon.tga", small)
    mark = render_mark(64, 32)
    write_tga("TalkInCharacter/Media/infinity.tga", mark)
    print("wrote curseforge/icon.png, TalkInCharacter/Media/icon.tga, TalkInCharacter/Media/infinity.tga")
