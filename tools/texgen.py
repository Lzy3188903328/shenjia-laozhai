# -*- coding: utf-8 -*-
"""
texgen.py — 程序化 PBR 贴图生成（纯 numpy + zlib PNG，无外部依赖）
《沈家老宅》：潮湿青苔 / 斑驳红漆 / 泛黄宣纸 / 陈旧木纹 / 窗棂镂空 / 纸人面具 …
"""
import zlib, struct, math
import numpy as np
from glblib import MATLIB

rng = np.random.default_rng(20241017)

# ---------------------------------------------------------------- PNG
def save_png(path, arr):
    """arr: (h,w,3) 或 (h,w,4) uint8"""
    h, w, c = arr.shape
    ctype = 2 if c == 3 else 6
    raw = b"".join(b"\x00" + arr[y].tobytes() for y in range(h))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 6))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)
    return path

# ---------------------------------------------------------------- 噪声
def fbm(shape, scale=4, octaves=4, seed=None):
    r = np.random.default_rng(seed if seed is not None else rng.integers(1 << 30))
    h, w = shape
    out = np.zeros(shape, dtype=np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        s = scale * (2 ** o)
        gw, gh = max(2, s), max(2, s)
        g = r.random((gh, gw)).astype(np.float32)
        # 双线性放大
        yi = np.linspace(0, gh - 1, h)
        xi = np.linspace(0, gw - 1, w)
        y0 = yi.astype(int); x0 = xi.astype(int)
        y1 = np.minimum(y0 + 1, gh - 1); x1 = np.minimum(x0 + 1, gw - 1)
        fy = (yi - y0)[:, None]; fx = (xi - x0)[None, :]
        v = (g[np.ix_(y0, x0)] * (1 - fy) * (1 - fx) + g[np.ix_(y1, x0)] * fy * (1 - fx)
             + g[np.ix_(y0, x1)] * (1 - fy) * fx + g[np.ix_(y1, x1)] * fy * fx)
        out += v * amp
        tot += amp
        amp *= 0.5
    return out / tot

def warp_x(shape, amount, scale=6):
    """水平正弦扭曲（木纹用）"""
    h, w = shape
    y = np.arange(h)[:, None].astype(np.float32)
    x = np.arange(w)[None, :].astype(np.float32)
    return x + amount * np.sin(y / scale * 2 * math.pi + fbm(shape, 3, 2))

# ---------------------------------------------------------------- 基础调色
def mix(a, b, t):
    t = np.clip(t, 0, 1)[..., None] if t.ndim == 2 else np.clip(t, 0, 1)
    return a * (1 - t) + b * t

def to_rgb(r, g, b):
    return np.stack([r, g, b], axis=-1)

def clamp01(x):
    return np.clip(x, 0, 1)

# ---------------------------------------------------------------- 生成器
def gen_wood(dark=(0.16, 0.10, 0.07), light=(0.34, 0.22, 0.13), vertical=True, size=512):
    n = fbm((size, size), 5, 4, seed=hash(str(dark)) & 0xFFFF)
    x = warp_x((size, size), 14, 22)
    grain = np.sin(x / size * math.pi * 26 + n * 5) * 0.5 + 0.5
    grain = grain * 0.6 + fbm((size, size), 40, 3) * 0.4
    col = mix(np.array(dark), np.array(light), grain)
    # 斑驳污渍
    stain = fbm((size, size), 3, 3) > 0.62
    col = mix(col, col * 0.55, stain * 0.7)
    return col

def gen_wood_red(size=512):
    """斑驳红漆：红漆剥落露出木底"""
    wood = gen_wood((0.14, 0.09, 0.06), (0.30, 0.20, 0.12), size=size)
    lac = np.zeros((size, size, 3), dtype=np.float32)
    lac[..., 0] = 0.42
    lac[..., 1] = 0.06
    lac[..., 2] = 0.05
    wear = fbm((size, size), 4, 5)
    wear = clamp01((wear - 0.45) * 3)
    col = mix(lac, wood, wear)
    col *= (0.75 + fbm((size, size), 30, 2) * 0.5)[..., None]
    return col

def gen_brick(size=512):
    """青砖墙：错缝砖排 + 灰缝 + 底部青苔"""
    col = np.zeros((size, size, 3), dtype=np.float32)
    base = np.array((0.30, 0.33, 0.30))
    bh, bw = size // 10, size // 4
    for row in range(size // bh + 1):
        off = (bw // 2) if row % 2 else 0
        for cb in range(-1, size // bw + 1):
            x0 = cb * bw + off
            y0 = row * bh
            v = 0.75 + rng.random() * 0.35
            t = base * v
            col[max(0, y0):min(size, y0 + bh - 3), max(0, x0):min(size, x0 + bw - 3)] = t
    col += (fbm((size, size), 8, 4)[..., None] - 0.5) * 0.10
    # 灰缝暗线
    for row in range(size // bh + 1):
        y0 = row * bh
        if y0 < size - 2:
            col[y0:y0 + 3, :] *= 0.6
    moss = fbm((size, size), 5, 4)
    mossband = np.clip((np.arange(size) / size - 0.55) * 4, 0, 1)
    moss = clamp01((moss - 0.52) * 4) * mossband[:, None]
    col = mix(col, np.array((0.18, 0.30, 0.16)), moss)
    return col

def gen_stone(size=512, mossy=False):
    """青石板大块"""
    col = np.ones((size, size, 3), dtype=np.float32) * np.array((0.32, 0.34, 0.33))
    cell = size // 3
    for row in range(3):
        for c in range(3):
            v = 0.8 + rng.random() * 0.3
            col[row * cell:(row + 1) * cell - 2, c * cell:(c + 1) * cell - 2] *= v
    n = fbm((size, size), 10, 4)
    col += (n[..., None] - 0.5) * 0.14
    # 深色缝隙
    for k in range(0, size + 1, cell):
        if k < size - 1:
            col[k:k + 2, :] *= 0.55
            col[:, k:k + 2] *= 0.55
    if mossy:
        moss = clamp01((fbm((size, size), 4, 4) - 0.48) * 4)
        col = mix(col, np.array((0.16, 0.28, 0.14)), moss * 0.8)
    return col

def gen_paper(tint=(0.87, 0.82, 0.70), stained=False, size=256):
    """宣纸：纤维噪点，泛黄污渍"""
    col = np.ones((size, size, 3), dtype=np.float32) * np.array(tint)
    fib = fbm((size, size), 60, 3)
    col *= (0.92 + fib * 0.16)[..., None]
    if stained:
        s = fbm((size, size), 4, 4)
        col = mix(col, np.array((0.55, 0.44, 0.30)), clamp01((s - 0.6) * 2.5))
        # 边缘黄化
        yy, xx = np.mgrid[0:size, 0:size]
        edge = np.minimum.reduce([xx, yy, size - 1 - xx, size - 1 - yy]) / (size / 2)
        col = mix(col, np.array((0.62, 0.52, 0.36)), clamp01(1 - edge) * 0.5)
    return col

def gen_talisman(size=256):
    """符纸：黄纸 + 朱砂竖排符笔画"""
    col = gen_paper((0.88, 0.76, 0.42), stained=True, size=size)
    red = np.array((0.55, 0.08, 0.06))
    yy, xx = np.mgrid[0:size, 0:size]
    stroke = np.zeros((size, size), dtype=np.float32)
    r = np.random.default_rng(777)
    # 中轴主笔
    cx = size * 0.5
    stroke += np.exp(-((xx - cx) ** 2) / 40) * (yy > size * 0.12) * (yy < size * 0.88)
    # 侧笔与折笔
    for i in range(6):
        px = size * (0.30 + 0.4 * r.random())
        py0 = size * (0.15 + 0.5 * r.random())
        ln = size * (0.12 + 0.25 * r.random())
        ang = r.choice([-0.35, 0.0, 0.35])
        d = yy - (py0 + np.tan(ang) * (xx - px))
        stroke += np.exp(-(d ** 2) / 22) * (yy > py0) * (yy < py0 + ln)
    # 圆符头
    stroke += 1.0 * ((xx - cx) ** 2 + (yy - size * 0.14) ** 2 < (size * 0.045) ** 2)
    ink = clamp01(stroke)
    col = mix(col, red, ink * 0.92)
    return col

def gen_ink_doc(size=256, seal=True, dark_red=False):
    """文书：泛黄宣纸 + 竖排墨迹行 + 朱砂印"""
    col = gen_paper((0.84, 0.77, 0.60), stained=True, size=size)
    yy, xx = np.mgrid[0:size, 0:size]
    ink = np.zeros((size, size), dtype=np.float32)
    r = np.random.default_rng(1234)
    for cxi in range(5):
        cx = size * (0.14 + cxi * 0.16)
        y = size * 0.10
        while y < size * 0.86:
            ln = size * (0.02 + 0.035 * r.random())
            ink += np.exp(-((xx - cx) ** 2) / 12) * ((yy > y) * (yy < y + ln)) * (0.7 + 0.3 * r.random())
            y += ln + size * 0.012
    if dark_red:  # 血书
        ink_col = np.array((0.42, 0.05, 0.04))
    else:
        ink_col = np.array((0.13, 0.10, 0.08))
    col = mix(col, ink_col, clamp01(ink) * 0.85)
    if seal:
        sx, sy, sr = size * 0.82, size * 0.78, size * 0.07
        ring = ((xx - sx) ** 2 + (yy - sy) ** 2) < sr ** 2
        inner = ((xx - sx) ** 2 + (yy - sy) ** 2) < (sr * 0.6) ** 2
        sq = clamp01(ring.astype(float) * 0.9 + inner * 0.45)
        col = mix(col, np.array((0.55, 0.08, 0.06)), sq * 0.9)
    return col

def gen_cloth(tint=(0.90, 0.88, 0.82), size=256, weave=8):
    col = np.ones((size, size, 3), dtype=np.float32) * np.array(tint)
    yy, xx = np.mgrid[0:size, 0:size]
    w = (np.sin(xx / weave * math.pi) * 0.5 + np.sin(yy / weave * math.pi) * 0.5)
    col *= 0.94 + w[..., None] * 0.06
    n = fbm((size, size), 6, 3)
    col = mix(col, col * 0.7, clamp01((n - 0.62) * 3))  # 污渍
    return col

def gen_cloth_red(size=256):
    col = gen_cloth((0.42, 0.05, 0.06), size=size)
    fold = fbm((size, size), 3, 3)
    col = mix(col, col * 0.55, clamp01((fold - 0.5) * 2.5))
    # 金边
    yy, xx = np.mgrid[0:size, 0:size]
    col[(np.abs(yy - size * 0.5) > size * 0.46), :] = np.array((0.5, 0.38, 0.15))
    return col

def gen_bronze(size=256):
    col = np.ones((size, size, 3), dtype=np.float32) * np.array((0.45, 0.34, 0.18))
    n = fbm((size, size), 8, 4)
    col *= (0.7 + n * 0.6)[..., None]
    verd = clamp01((fbm((size, size), 5, 4) - 0.58) * 3)
    col = mix(col, np.array((0.25, 0.42, 0.30)), verd)
    return col

def gen_tile(size=512):
    """屋瓦：横向瓦垄"""
    col = np.ones((size, size, 3), dtype=np.float32) * np.array((0.20, 0.22, 0.24))
    yy, xx = np.mgrid[0:size, 0:size]
    row = np.sin(yy / size * math.pi * 18)
    col *= 0.75 + row[..., None] * 0.25
    seam = (xx % 42 < 3)
    col[seam, :] *= 0.8
    n = fbm((size, size), 6, 3)
    col += (n[..., None] - 0.5) * 0.08
    moss = clamp01((fbm((size, size), 5, 4) - 0.6) * 3)
    col = mix(col, np.array((0.15, 0.24, 0.13)), moss * 0.7)
    return col

def gen_bamboo(size=256):
    """竹篾：竖条编织"""
    col = np.ones((size, size, 3), dtype=np.float32) * np.array((0.55, 0.50, 0.28))
    m = np.mgrid[0:size, 0:size]
    strips = (m[1] % 26 < 22)
    col *= strips[..., None]
    col += np.where(strips[..., None], 0, np.array((0.05, 0.05, 0.04)))
    n = fbm((size, size), 30, 3)
    col *= (0.85 + n * 0.3)[..., None]
    return col

def gen_lattice(size=256):
    """窗棂：RGBA 镂空，万字纹"""
    rgba = np.zeros((size, size, 4), dtype=np.float32)
    wood = np.array((0.28, 0.19, 0.11))
    rgba[..., :3] = wood
    rgba[..., 3] = 0  # 默认镂空
    m = np.mgrid[0:size, 0:size]
    yy, xx = m[0], m[1]
    t = size // 32  # 条宽
    frame = (xx < t) | (xx > size - t) | (yy < t) | (yy > size - t)
    rgba[..., 3][frame] = 1
    # 万字纹网格：竖横条
    step = size // 8
    for k in range(1, 8):
        v = np.abs(xx - k * step) < t
        h = np.abs(yy - k * step) < t
        rgba[..., 3][v] = 1
        rgba[..., 3][h] = 1
    # 斜撑
    for k in range(-2, 10):
        diag = np.abs((xx - k * step * 0.5)) < t
        rgba[..., 3][diag] = 1
    rgba[..., :3] *= (0.85 + fbm((size, size), 8, 3))[..., None] * 1.2
    return rgba

def _face_base(size):
    col = gen_paper((0.92, 0.88, 0.78), size=size)
    yy, xx = np.mgrid[0:size, 0:size]
    return col, yy, xx

def _blob(cx, cy, rx, ry, yy, xx):
    return ((xx - cx) ** 2 / (rx ** 2) + (yy - cy) ** 2 / (ry ** 2)) < 1

def gen_face(size=256, eyes=True, smile=True, red=False):
    """纸人面具：惨白底 + 眼缝 + 似笑非笑"""
    if red:
        col = gen_paper((0.78, 0.70, 0.62), size=size)
    else:
        col = gen_paper((0.93, 0.90, 0.80), size=size)
    yy, xx = np.mgrid[0:size, 0:size]
    dark = np.array((0.10, 0.08, 0.07)) if not red else np.array((0.05, 0.03, 0.03))
    if eyes:
        for ex in (0.36, 0.64):
            b = _blob(size * ex, size * 0.38, size * 0.045, size * 0.030, yy, xx)
            col[b] = col[b] * 0.15 + dark * 0.85
    if smile:
        # 弧线嘴（浅浅上扬的似笑非笑）：边缘比中间低约 20px
        t = (yy - (size * 0.56 - (xx - size * 0.5) ** 2 * 0.0012))
        mouth = (np.abs(t) < size * 0.014) & (xx > size * 0.30) & (xx < size * 0.70)
        col[mouth] = col[mouth] * 0.2 + dark * 0.8
        # 两端上翘小点
        for ex in (0.30, 0.70):
            b = _blob(size * ex, size * 0.542, size * 0.020, size * 0.012, yy, xx)
            col[b] = col[b] * 0.2 + dark * 0.8
    if red:
        # 红痕（泪/血）
        for ex in (0.36, 0.64):
            b = _blob(size * ex, size * 0.55, size * 0.012, size * 0.18, yy, xx)
            col = mix(col, np.array((0.35, 0.04, 0.04)), b * 0.75)
    return col

def gen_flag(size=256):
    """灵幡：白布 + 墨字痕 + 顶部红边"""
    col = gen_cloth((0.88, 0.86, 0.80), size=size)
    yy, xx = np.mgrid[0:size, 0:size]
    ink = np.zeros((size, size), dtype=np.float32)
    r = np.random.default_rng(99)
    for cxi in range(2):
        cx = size * (0.35 + cxi * 0.3)
        y = size * 0.14
        while y < size * 0.85:
            ln = size * (0.03 + 0.04 * r.random())
            ink += np.exp(-((xx - cx) ** 2) / 14) * ((yy > y) * (yy < y + ln)) * (0.6 + 0.4 * r.random())
            y += ln + size * 0.015
    col = mix(col, np.array((0.15, 0.12, 0.10)), clamp01(ink) * 0.8)
    col[yy < size * 0.08, :] = np.array((0.45, 0.06, 0.06))
    return col

def gen_jade(size=256):
    col = np.ones((size, size, 3), dtype=np.float32) * np.array((0.30, 0.55, 0.38))
    n = fbm((size, size), 6, 4)
    col = mix(col, np.array((0.55, 0.75, 0.55)), clamp01((n - 0.55) * 3) * 0.7)
    return col

def gen_burn_paper(size=256):
    """半张婚书：泛黄纸 + 右缘烧焦"""
    col = gen_paper((0.85, 0.78, 0.62), stained=True, size=size)
    yy, xx = np.mgrid[0:size, 0:size]
    ink = np.zeros((size, size), dtype=np.float32)
    r = np.random.default_rng(55)
    cx = size * 0.25
    y = size * 0.12
    while y < size * 0.8:
        ln = size * (0.025 + 0.04 * r.random())
        ink += np.exp(-((xx - cx) ** 2) / 14) * ((yy > y) * (yy < y + ln)) * (0.7 + 0.3 * r.random())
        y += ln + size * 0.014
    col = mix(col, np.array((0.12, 0.09, 0.08)), clamp01(ink) * 0.85)
    burn = clamp01((xx / size - 0.62) * 4)
    col = mix(col, np.array((0.10, 0.07, 0.05)), burn)
    scorch = clamp01((xx / size - 0.52) * 5)
    col = mix(col, np.array((0.30, 0.16, 0.08)), scorch * (1 - burn))
    return col

def gen_floorwood(size=512):
    col = gen_wood((0.20, 0.14, 0.09), (0.38, 0.27, 0.16), size=size)
    m = np.mgrid[0:size, 0:size]
    plank = (m[1] % 64 < 3)
    col[plank, :] *= 0.6
    # 随机错缝
    for row in range(size // 64):
        cx = int(rng.random() * size)
        y0 = row * 64
        col[y0:y0 + 64, max(0, cx - 2):cx + 2] *= 0.65
    return col

def gen_mold(size=128):
    """发霉供品：灰绿团"""
    col = np.ones((size, size, 3), dtype=np.float32) * np.array((0.55, 0.52, 0.42))
    n = fbm((size, size), 6, 4)
    col = mix(col, np.array((0.25, 0.35, 0.20)), clamp01((n - 0.5) * 3))
    return col

def gen_shoe_red(size=256):
    """绣花鞋：红绸 + 金线团花"""
    col = gen_cloth_red(size=size)
    yy, xx = np.mgrid[0:size, 0:size]
    for cx, cy in ((0.3, 0.35), (0.7, 0.35), (0.5, 0.65)):
        ring = np.abs(np.sqrt((xx - size * cx) ** 2 + (yy - size * cy) ** 2) - size * 0.08) < size * 0.012
        col[ring] = np.array((0.55, 0.42, 0.16))
    return col

def gen_black(size=64):
    return np.zeros((size, size, 3), dtype=np.float32) + 0.02

def gen_iron(size=128):
    col = np.ones((size, size, 3), dtype=np.float32) * np.array((0.16, 0.16, 0.17))
    n = fbm((size, size), 20, 3)
    col *= (0.8 + n * 0.4)[..., None]
    rust = clamp01((fbm((size, size), 6, 4) - 0.62) * 3)
    col = mix(col, np.array((0.30, 0.15, 0.08)), rust * 0.6)
    return col

def gen_lantern_red(size=256):
    """红灯笼：红纸 + 竖骨条 + 磨损"""
    col = np.ones((size, size, 3), dtype=np.float32) * np.array((0.48, 0.07, 0.06))
    yy, xx = np.mgrid[0:size, 0:size]
    rib = (xx % (size // 6) < size // 48)
    col[rib] *= 0.55
    n = fbm((size, size), 8, 3)
    col *= (0.8 + n * 0.4)[..., None]
    # 上下深色包边
    col[: size // 8] *= 0.35
    col[-size // 8:] *= 0.35
    return col

# ---------------------------------------------------------------- 注册
def build_all(out_dir):
    import os
    os.makedirs(out_dir, exist_ok=True)
    def reg(name, arr, rough=None, metal=None):
        arr8 = np.clip(arr * 255, 0, 255).astype(np.uint8)
        pth = save_png(os.path.join(out_dir, name + ".png"), arr8)
        with open(pth, "rb") as f:
            MATLIB.reg_tex(name, f.read())  # 注册真正的 PNG 文件字节

    reg("t_wood_dark", gen_wood((0.16, 0.10, 0.07), (0.34, 0.22, 0.13)))
    reg("t_wood_red", gen_wood_red())
    reg("t_wood_floor", gen_floorwood())
    reg("t_brick", gen_brick())
    reg("t_stone", gen_stone())
    reg("t_stone_moss", gen_stone(mossy=True))
    reg("t_paper_white", gen_paper((0.90, 0.87, 0.78)))
    reg("t_paper_yellow", gen_paper((0.86, 0.79, 0.62), stained=True))
    reg("t_paper_red", gen_cloth((0.52, 0.08, 0.07), weave=14))
    reg("t_talisman", gen_talisman())
    reg("t_doc_ink", gen_ink_doc(seal=True))
    reg("t_doc_ink2", gen_ink_doc(seal=False))
    reg("t_doc_blood", gen_ink_doc(seal=True, dark_red=True))
    reg("t_doc_burn", gen_burn_paper())
    reg("t_cloth_white", gen_cloth((0.90, 0.88, 0.82)))
    reg("t_cloth_red", gen_cloth_red())
    reg("t_bronze", gen_bronze())
    reg("t_tile", gen_tile())
    reg("t_bamboo", gen_bamboo())
    reg("t_lattice", gen_lattice())
    reg("t_face_smile", gen_face(eyes=True, smile=True))
    reg("t_face_noeye", gen_face(eyes=False, smile=True))
    reg("t_face_eyed", gen_face(eyes=True, smile=False))
    reg("t_face_red", gen_face(eyes=True, smile=False, red=True))
    reg("t_flag", gen_flag())
    reg("t_jade", gen_jade())
    reg("t_mold", gen_mold())
    reg("t_iron", gen_iron())
    reg("t_lantern_red", gen_lantern_red())
    reg("t_shoe_red", gen_shoe_red())
    reg("t_black", gen_black())
    print("[texgen] 贴图完成: %d 张" % len(MATLIB.textures))


if __name__ == "__main__":
    import sys
    build_all(sys.argv[1] if len(sys.argv) > 1 else "../assets/tex")
