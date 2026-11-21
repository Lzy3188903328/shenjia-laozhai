"""Build the art pass from the checked-in HD assets without changing their interfaces.

Preview into another directory first:
    python tools/refine_models.py --output D:/Downloads/shenjia-art-preview
"""

import argparse
import io
import json
from math import cos, pi, sin, tau
from pathlib import Path
import struct
from tempfile import TemporaryDirectory

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from glblib import MATLIB, Mesh, Prop, box, cylinder, normalize, trs_matrix
from props import register_materials


PROJECT = Path(__file__).resolve().parents[1]


def materials():
    register_materials()
    for image in (PROJECT / "assets" / "tex").glob("*.png"):
        MATLIB.reg_tex(image.stem, image.read_bytes())

    # Fine fibers and mottled pulp repeat across the sheets of each shade.
    rng = np.random.default_rng(920)
    broad = Image.fromarray(rng.integers(45, 210, (28, 28), dtype=np.uint8))
    broad = np.asarray(broad.resize((256, 256), Image.Resampling.BICUBIC), dtype=float)
    grain = rng.normal(0, 3.5, broad.shape)
    pulp = np.clip(225 + (broad - 128) * 0.18 + grain, 0, 255).astype(np.uint8)
    sheet = Image.fromarray(pulp).convert("RGB")
    fibers = Image.new("RGB", sheet.size, (240, 240, 240))
    draw = ImageDraw.Draw(fibers)
    for _ in range(1450):
        x, y = (int(v) for v in rng.integers(0, 256, 2))
        value = int(rng.integers(107, 203))
        draw.line((x, y, x + int(rng.integers(-2, 4)), y + int(rng.integers(2, 13))),
                  fill=(value, value, value), width=1)
    sheet = Image.blend(sheet, fibers.filter(ImageFilter.GaussianBlur(0.28)), 0.26)
    encoded = io.BytesIO()
    sheet.save(encoded, format="PNG")
    MATLIB.reg_tex("woven_paper", encoded.getvalue())

    m = MATLIB.mat
    m("IvoryShade", tex="woven_paper", color=(0.76, 0.47, 0.24, 0.97), rough=0.94,
      emissive=(0.11, 0.053, 0.013), alpha="BLEND", double=True)
    m("RedShade", tex="woven_paper", color=(0.43, 0.047, 0.016, 1), rough=0.83,
      emissive=(0.046, 0.004, 0.001), double=True)
    m("Parchment", tex="woven_paper", color=(0.62, 0.52, 0.36, 1), rough=0.94, double=True)
    m("UnbleachedPaper", tex="woven_paper", color=(0.36, 0.26, 0.13, 1), rough=0.92, double=True)
    m("PaperFolds", tex="woven_paper", color=(0.76, 0.67, 0.51, 1), rough=0.89, double=True)
    m("FadedIndigo", tex="t_cloth_white", color=(0.19, 0.28, 0.30, 1), rough=0.9, double=True)
    m("WeddingSilk", tex="t_cloth_red", color=(0.56, 0.17, 0.14, 1), rough=0.65, double=True)
    m("VeilCloth", tex="t_cloth_red", color=(0.40, 0.042, 0.025, 0.76), rough=0.8,
      alpha="BLEND", double=True)
    m("BurntLacquer", tex="t_wood_red", color=(0.47, 0.37, 0.29, 1), rough=0.73)
    m("WarmWood", tex="t_wood_dark", color=(0.64, 0.49, 0.34, 1), rough=0.76)
    m("BambooRind", tex="t_bamboo", color=(0.52, 0.36, 0.17, 1), rough=0.67)
    m("OxidizedBrass", tex="t_bronze", color=(0.67, 0.43, 0.22, 1), metal=0.62, rough=0.48)
    m("OldGoldThread", color=(0.48, 0.27, 0.095, 1), metal=0.23, rough=0.58)
    m("SootIron", color=(0.053, 0.047, 0.04, 1), metal=0.65, rough=0.71)
    m("StoneLedge", tex="t_stone", color=(0.53, 0.50, 0.40, 1), rough=0.91)
    m("SlateGrey", tex="t_tile", color=(0.43, 0.49, 0.49, 1), rough=0.81)
    m("CopperFlame", color=(1, 0.69, 0.19, 1), emissive=(1.0, 0.49, 0.10), rough=0.86)
    m("CinnabarBinding", color=(0.27, 0.033, 0.017, 1), rough=0.91)
    m("FadedThread", color=(0.29, 0.20, 0.10, 1), rough=0.89)


def sweep(points, radii, sides=8):
    """Tube with a frame along its path, including local cross-section changes."""
    points = np.asarray(points, dtype=float)
    radii = np.broadcast_to(radii, (len(points),))
    mesh = Mesh()
    for i, point in enumerate(points):
        tangent = np.asarray(normalize(points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]))
        guide = (0, 0, 1) if abs(tangent[2]) < 0.87 else (1, 0, 0)
        across = np.asarray(normalize(np.cross(guide, tangent)))
        vertical = np.cross(tangent, across)
        for j in range(sides + 1):
            angle = tau * j / sides
            normal = cos(angle) * across + sin(angle) * vertical
            mesh.pos.append(tuple(point + normal * radii[i]))
            mesh.nor.append(tuple(normal))
            mesh.uv.append((j / sides, i / (len(points) - 1)))
    for i in range(len(points) - 1):
        for j in range(sides):
            a = i * (sides + 1) + j
            b = a + sides + 1
            mesh.idx.extend((a, a + 1, b + 1, a, b + 1, b))
    return mesh


def circle(radius, y, steps=32):
    return [(radius * cos(tau * i / steps), y, radius * sin(tau * i / steps))
            for i in range(steps + 1)]


def shell(sections, sides=48, folds=0.0):
    """Y-up open surface through (height, half-width, half-depth) sections."""
    mesh = Mesh()
    for i, (y, width, depth) in enumerate(sections):
        below = sections[max(i - 1, 0)]
        above = sections[min(i + 1, len(sections) - 1)]
        dy = max(above[0] - below[0], 1e-6)
        for j in range(sides + 1):
            a = tau * j / sides
            drape = 1 + folds * (0.72 * cos(11 * a + 0.42 * y) + 0.28 * sin(17 * a))
            mesh.pos.append((width * cos(a) * drape, y, depth * sin(a) * drape))
            slope = ((above[1] - below[1]) * cos(a) ** 2 + (above[2] - below[2]) * sin(a) ** 2) / dy
            mesh.nor.append(tuple(normalize((cos(a) / max(width, 0.001), -slope / max(width, 0.001),
                                             sin(a) / max(depth, 0.001)))))
            mesh.uv.append((j / sides, i / (len(sections) - 1)))
    for i in range(len(sections) - 1):
        for j in range(sides):
            a = i * (sides + 1) + j
            b = a + sides + 1
            mesh.idx.extend((a, b, b + 1, a, b + 1, a + 1))
    return mesh


class Details:
    """Group static components by material, keeping draw calls and nodes predictable."""

    def __init__(self, prop):
        self.prop = prop
        self.groups = {}

    def add(self, material, mesh, location=(0, 0, 0), rotation=(0, 0, 0), parent=None):
        group = self.groups.setdefault((parent, material), Mesh())
        group.merge(mesh, trs_matrix(location, rotation))

    def block(self, material, size, at, rotation=(0, 0, 0), parent=None):
        self.add(material, box(*size), at, rotation, parent)

    def line(self, material, points, radius, sides=8, parent=None):
        self.add(material, sweep(points, radius, sides), parent=parent)

    def band(self, material, radius, y, thickness, x=0, z=0, parent=None):
        self.add(material, sweep(circle(radius, y), thickness), (x, 0, z), parent=parent)

    def disc(self, material, radius, height, at, rotation=(0, 0, 0), parent=None):
        self.add(material, cylinder(radius, radius, height, 24), at, rotation, parent)

    def finish(self):
        for (parent, material), mesh in self.groups.items():
            suffix = "_" + parent if parent else ""
            self.prop.part("Art_" + material + suffix, mesh, material, parent=parent)
        return self.prop


def lantern(hanging=False):
    prop = Prop("SM_HangingLantern" if hanging else "SM_HandLantern")
    detail = Details(prop)
    scale = 1.65 if hanging else 1.0
    drop = -0.63 if hanging else 0.0
    profile = [(0.025, 0.064), (0.045, 0.080), (0.072, 0.101), (0.108, 0.109),
               (0.143, 0.102), (0.174, 0.082), (0.195, 0.060)]
    sections = [(h * scale, r * scale, r * scale) for h, r in profile]
    material = "RedShade" if hanging else "IvoryShade"
    prop.part("Body", shell(sections, sides=48, folds=0.025), material, t=(0, drop, 0))
    for k in range(12):
        a = tau * k / 12
        path = [((r * scale + 0.0015) * cos(a), h * scale,
                 (r * scale + 0.0015) * sin(a)) for h, r in profile]
        detail.line("BambooRind" if k % 3 else "BurntLacquer", path, 0.0026 * scale, parent="Body")
    for y, r in [(0.026, 0.065), (0.033, 0.069), (0.191, 0.064), (0.197, 0.060)]:
        detail.band("BurntLacquer", r * scale, y * scale, 0.004 * scale, parent="Body")
    for y, r in [(0.037, 0.074), (0.184, 0.070)]:
        detail.band("CinnabarBinding", r * scale, y * scale, 0.0018 * scale, parent="Body")
    for k in range(12):
        a = tau * k / 12
        for y in (0.031, 0.193):
            x, z = 0.065 * scale * cos(a), 0.065 * scale * sin(a)
            detail.line("FadedThread", [(x, (y - 0.004) * scale, z), (x, (y + 0.004) * scale, z)],
                        0.0013 * scale, 5, parent="Body")
    detail.disc("SootIron", 0.050 * scale, 0.013 * scale, (0, 0.013, 0), parent="Body")
    detail.disc("OxidizedBrass", 0.036 * scale, 0.011 * scale, (0, 0.024, 0), parent="Body")
    detail.disc("SootIron", 0.016 * scale, 0.016 * scale, (0, 0.034, 0), parent="Body")
    if hanging:
        detail.line("FadedThread", [(0, 0, 0), (0, -0.18, 0), (0, drop + 0.32, 0)], 0.0032)
        for k in range(15):
            a = tau * k / 15
            detail.line("CinnabarBinding", [(0, -0.018, 0), (0.018 * cos(a), -0.105, 0.018 * sin(a)),
                        (0.024 * cos(a), -0.167 - 0.01 * sin(k), 0.024 * sin(a))],
                        0.0016, 5, parent="Body")
        prop.anim("lantern_sway", "Body", "rotation",
                  [(0, (0, 0, -6)), (0.7, (1, 1, 6)), (1.4, (0, 0, -6))])
    else:
        handle = [(0.061 * cos(pi * k / 20), 0.178 + 0.079 * sin(pi * k / 20),
                   -0.016 - 0.021 * sin(pi * k / 20)) for k in range(21)]
        detail.line("BambooRind", handle, 0.0042)
        for x in (-0.061, 0.061):
            detail.line("OxidizedBrass", [(x, 0.176, -0.017), (x, 0.189, -0.013)], 0.005)
        detail.line("FadedThread", [(-0.023, 0.252, -0.036), (0, 0.257, -0.039),
                                    (0.023, 0.252, -0.036)], 0.005)
        flame = shell([(0, 0.001, 0.001), (0.008, 0.007, 0.007), (0.020, 0.009, 0.008),
                       (0.033, 0.006, 0.006), (0.052, 0.0004, 0.0004)], sides=20)
        flame.pos = [(x + y * y * 4, y, z) for x, y, z in flame.pos]
        prop.part("Flame", flame, "CopperFlame", t=(0, 0.049, 0))
        prop.anim("lantern_sway", "Flame", "rotation",
                  [(0, (0, 0, -7)), (0.5, (0, 0, 7)), (1, (0, 0, -7))])
    return detail.finish()


def face_panel():
    """Domed paper face, with the original front-facing texture layout."""
    mesh = Mesh()
    rings, sides = 7, 40
    for i in range(rings + 1):
        for j in range(sides + 1):
            a, radius = tau * j / sides, i / rings
            x = radius * cos(a)
            y = radius * sin(a)
            mesh.pos.append((0.113 * x * (0.94 + 0.13 * y), 0.154 * y, 0.179 - 0.042 * radius ** 2))
            mesh.nor.append(tuple(normalize((0.48 * x, 0.43 * y, 1.0))))
            mesh.uv.append(((x + 1) * 0.5, (y + 1) * 0.5))
    for i in range(rings):
        for j in range(sides):
            a = i * (sides + 1) + j
            b = a + sides + 1
            mesh.idx.extend((a, b, b + 1, a, b + 1, a + 1))
    return mesh


def figure(kind):
    root = {"paper_figure": "SM_PaperFigure", "paper_head": "SM_PaperHead", "bride_ghost": "SM_BrideGhost"}
    prop = Prop(root[kind])
    detail = Details(prop)
    head_only = kind == "paper_head"
    ghost = kind == "bride_ghost"
    y_head = 0.17 if head_only else 1.48
    coat = "WeddingSilk" if ghost else "Parchment"
    dark = "CinnabarBinding" if ghost else "FadedIndigo"
    trim = "OldGoldThread" if ghost else "FadedThread"
    if not head_only:
        sections = [(0.075, 0.238, 0.155), (0.11, 0.251, 0.172), (0.22, 0.258, 0.178),
                    (0.46, 0.224, 0.158), (0.78, 0.183, 0.126), (0.99, 0.173, 0.119),
                    (1.135, 0.232, 0.140), (1.24, 0.257, 0.139), (1.30, 0.183, 0.118),
                    (1.34, 0.075, 0.073)]
        prop.part("Body", shell(sections, folds=0.091), coat)
        detail.add(dark, shell([(0.078, 0.242, 0.159), (0.107, 0.255, 0.174), (0.132, 0.26, 0.177)],
                               folds=0.09))
        detail.add(dark, shell([(0.886, 0.18, 0.126), (0.927, 0.179, 0.127), (0.960, 0.177, 0.125)],
                               folds=0.03))
        detail.line(trim, [(-0.079, 1.322, 0.076), (-0.062, 1.253, 0.137),
                           (0.026, 1.167, 0.154), (0.116, 1.091, 0.122),
                           (0.155, 0.965, 0.115)], 0.008, 8)
        detail.line(dark, [(0.068, 1.321, 0.084), (0.047, 1.266, 0.144),
                           (-0.018, 1.2, 0.155), (-0.09, 1.116, 0.143)], 0.008, 8)
        for sign in (-1, 1):
            arm = [(0.217 * sign, 1.247, 0.004), (0.294 * sign, 1.126, 0.018),
                   (0.320 * sign, 1.007, 0.050), (0.325 * sign, 0.861, 0.065),
                   (0.320 * sign, 0.763 if ghost else 0.831, 0.085)]
            detail.line(coat, arm, [0.074, 0.084, 0.072, 0.062, 0.063], 19)
            detail.line(dark, [arm[-2], arm[-1]], [0.064, 0.065], 19)
            detail.line(trim, [arm[-2], ((0.321 * sign), arm[-1][1] + 0.02, 0.078)], 0.005, 6)
            for j in range(4):
                x = sign * 0.32 + (j - 1.5) * 0.016
                y = arm[-1][1]
                detail.line("PaperFolds", [(x, y, 0.093), (x + sign * 0.008, y - 0.042, 0.115),
                            (x + sign * 0.004, y - 0.066 + j * 0.008, 0.111)], [0.009, 0.007, 0.003], 6)
        for k in range(24):
            a = tau * k / 24
            detail.line(trim, [(0.245 * cos(a), 0.116, 0.171 * sin(a)),
                        (0.253 * cos(a + 0.02), 0.127, 0.177 * sin(a + 0.02))], 0.0017, 5)
        if not ghost:
            prop.col((0, 0.8, 0), (0.50, 1.55, 0.40))
        detail.disc("BambooRind", 0.038, 0.11, (0, 1.31, 0))
    head_sections = [(-0.148, 0.031, 0.049), (-0.122, 0.072, 0.087),
                     (-0.057, 0.112, 0.122), (0.029, 0.127, 0.138), (0.102, 0.108, 0.126),
                     (0.150, 0.065, 0.079), (0.161, 0.007, 0.009)]
    prop.part("Head", shell(head_sections, sides=44), "PaperFolds", t=(0, y_head, 0))
    prop.part("Face", face_panel(), "M_FaceRed" if ghost else "M_FaceNoEye", parent="Head")
    for sign in (-1, 1):
        detail.line("UnbleachedPaper", [(0.109 * sign, -0.099, 0.085), (0.125 * sign, -0.03, 0.096),
                                        (0.115 * sign, 0.06, 0.090)], 0.004, 6, parent="Head")
    detail.add("M_Black", shell([(0.067, 0.128, 0.107), (0.107, 0.126, 0.124),
                                (0.148, 0.096, 0.101), (0.178, 0.049, 0.060),
                                (0.185, 0.006, 0.006)], folds=0.022), (0, 0, -0.028), parent="Head")
    detail.line(dark, [(-0.122, 0.072, 0.093), (-0.082, 0.105, 0.131),
                      (0.0, 0.122, 0.158), (0.082, 0.105, 0.131), (0.122, 0.072, 0.093)],
                0.008 if ghost else 0.006, parent="Head")
    if ghost:
        for sign in (-1, 1):
            detail.line("VeilCloth", [(sign * 0.10, 0.133, 0.03), (sign * 0.142, 0.0, 0.071),
                        (sign * 0.152, -0.146, 0.081), (sign * 0.15, -0.289, 0.03)],
                        [0.032, 0.038, 0.037, 0.018], 10, parent="Head")
            detail.line("OldGoldThread", [(sign * 0.107, 0.129, 0.054),
                        (sign * 0.163, -0.032, 0.066), (sign * 0.157, -0.258, 0.05)],
                        0.003, 6, parent="Head")
        detail.line("OxidizedBrass", [(-0.08, 0.131, -0.047), (0.089, 0.161, -0.075),
                                     (0.15, 0.165, -0.086)], 0.0038, 8, parent="Head")
    elif head_only:
        for k in range(7):
            a = tau * k / 7
            detail.line("BambooRind", [(0.044 * cos(a), 0.125, 0.047 * sin(a)),
                        (0.041 * cos(a), 0.044, 0.042 * sin(a)), (0.058 * cos(a), 0.008, 0.052 * sin(a))],
                        0.005, 6)
        detail.band("FadedThread", 0.041, 0.051, 0.003)
    else:
        prop.anim("turn_head", "Head", "rotation", [(0, (0, 0, 0)), (0.8, (0, 92, 0))])
    return detail.finish()


def molding(d, width, height, x, y, z, material="BurntLacquer", parent=None):
    for xx in (x - width / 2, x + width / 2):
        d.block(material, (0.019, height + 0.019, 0.012), (xx, y, z), parent=parent)
    for yy in (y - height / 2, y + height / 2):
        d.block(material, (width, 0.019, 0.012), (x, yy, z), parent=parent)


def arch(cx, cy, z, rx, ry, steps=18):
    return [(cx + rx * cos(tau * i / steps), cy + ry * sin(tau * i / steps), z)
            for i in range(steps + 1)]


def sprig(d, x, y, z, scale, material="OldGoldThread", parent=None):
    for k in range(4):
        sign = -1 if k % 2 else 1
        leaf = [(x, y + k * 0.19 * scale, z),
                (x + sign * 0.28 * scale, y + (k * 0.19 + 0.16) * scale, z),
                (x + sign * 0.30 * scale, y + (k * 0.19 + 0.37) * scale, z)]
        d.line(material, leaf, 0.023 * scale, 5, parent)
    d.line(material, [(x, y, z), (x, y + 0.94 * scale, z)], 0.021 * scale, 5, parent)


def building(name, d):
    if name == "wall_brick":
        for sign in (-1, 1):
            for y, height, depth in [(0.10, 0.20, 0.035), (0.208, 0.023, 0.043), (2.932, 0.085, 0.041)]:
                d.add("StoneLedge", box(4, height, depth, uv=2), (0, y, sign * 0.124))
            for k in range(8):
                d.block("StoneLedge", (0.012, 0.19, 0.005), (-1.75 + 0.5 * k, 0.104, sign * 0.144))
    elif name == "wall_wood":
        for z in (-0.062, 0.062):
            for x in (-1.5, -0.5, 0.5, 1.5):
                molding(d, 0.84, 1.81, x, 1.37, z, "WarmWood")
                molding(d, 0.84, 0.43, x, 2.67, z)
            for y in (0.33, 2.39):
                d.block("BurntLacquer", (4, 0.065, 0.062), (0, y, z))
    elif name == "pillar":
        for r, y, h in [(0.186, 0.14, 0.045), (0.160, 0.187, 0.031), (0.152, 0.218, 0.018)]:
            d.disc("StoneLedge", r, h, (0, y, 0))
        for r, y in [(0.146, 2.86), (0.155, 2.92), (0.171, 3.0)]:
            d.band("BurntLacquer", r, y, 0.010)
    elif name == "beam":
        for z in (-0.117, 0.117):
            for y in (-0.082, 0.079):
                d.block("BurntLacquer", (4, 0.026, 0.031), (0, y, z))
            for x in (-1.74, 1.74):
                molding(d, 0.35, 0.113, x, 0, z * 1.13, "WarmWood")
    elif name == "roof_seg":
        d.add("SlateGrey", box(4.6, 0.045, 1.57, uv=3), (0, 0.185, -0.68), (8.2, 0, 0))
        d.add("SlateGrey", box(4.6, 0.045, 1.57, uv=3), (0, 0.185, 0.68), (-8.2, 0, 0))
        d.line("SlateGrey", [(-2.30, 0.326, 0), (2.30, 0.326, 0)], 0.060, 12)
        for k in range(23):
            x = -2.20 + 0.20 * k
            d.line("SlateGrey", [(x, 0.109, -1.44), (x, 0.195, -0.74), (x, 0.310, 0),
                                (x, 0.195, 0.74), (x, 0.112, 1.44)], 0.042, 8)
            if k % 2 == 0:
                for z in (-1.34, 1.34):
                    d.block("WarmWood", (0.072, 0.093, 0.24), (x, -0.064, z))
        for sign in (-1, 1):
            d.block("BurntLacquer", (4.6, 0.10, 0.066), (0, -0.038, 1.42 * sign))
    elif name == "door":
        for sign in (-1, 1):
            z = sign * 0.072
            for y in (-0.55, 0.08, 0.66):
                molding(d, 0.76, 0.48, 0.53, y, z, parent="DoorLeaf")
                molding(d, 0.64, 0.37, 0.53, y, z + sign * 0.004, "WarmWood", "DoorLeaf")
                sprig(d, 0.53, y - 0.091, z + sign * 0.011, 0.18, "FadedThread", "DoorLeaf")
            for x in (0.087, 0.97):
                for y in (-0.9, -0.36, 0.24, 0.85):
                    d.disc("SootIron", 0.019, 0.008, (x, y, sign * 0.035), (sign * 90, 0, 0),
                           "DoorLeaf")
            d.disc("OxidizedBrass", 0.053, 0.014, (0.92, -0.34, sign * 0.05),
                   (sign * 90, 0, 0), "DoorLeaf")
            d.line("OxidizedBrass", arch(0.92, -0.389, sign * 0.079, 0.039, 0.049),
                   0.006, 9, "DoorLeaf")
            molding(d, 1.255, 2.25, 0, 1.14, sign * 0.135, "WarmWood")
    elif name == "window":
        for z in (-0.079, 0.079):
            molding(d, 1.164, 1.164, 0, 1.5, z)
            for x in (-0.35, 0, 0.35):
                molding(d, 0.31, 1.02, x, 1.5, z, "WarmWood")
                for y in (1.14, 1.49, 1.83):
                    pts = [(x, y + 0.106, z), (x + 0.12, y, z), (x, y - 0.106, z),
                           (x - 0.12, y, z), (x, y + 0.106, z)]
                    d.line("BurntLacquer", pts, 0.013, 6)
    elif name == "railing":
        for x in (-0.86, 0.86):
            d.block("BurntLacquer", (0.09, 0.91, 0.09), (x, 0.47, 0))
            d.disc("WarmWood", 0.057, 0.049, (x, 0.92, 0))
        for x in (-0.68, -0.34, 0, 0.34, 0.68):
            d.line("WarmWood", [(x, 0.405, 0), (x + 0.114, 0.54, 0), (x, 0.67, 0),
                                (x - 0.114, 0.54, 0), (x, 0.405, 0)], 0.018, 6)
    elif name in ("floor_stone", "floor_wood"):
        stone = name == "floor_stone"
        for row in range(7 if stone else 14):
            rows = 7 if stone else 14
            row_width = 4 / rows
            z = -2 + row_width * (row + 0.5)
            sections = 6 if stone else 4
            bounds = [-2] + [-2 + i * (4 / sections) + (0.11 if row % 2 else -0.10)
                            for i in range(1, sections)] + [2]
            for col, (a, b) in enumerate(zip(bounds, bounds[1:])):
                mat = ("StoneLedge" if (row * 7 + col * 3) % 5 else "M_Stone") if stone else (
                    "M_WoodFloor" if (row + col * 2) % 5 else "WarmWood")
                d.add(mat, box(b - a - 0.012, 0.010, row_width - 0.011, uv=0.65),
                      ((a + b) / 2, 0.0004 + 0.0007 * sin(row * 3 + col * 2), z))
                if not stone:
                    for x in (a + 0.045, b - 0.045):
                        d.disc("SootIron", 0.005, 0.002, (x, 0.006, z))
    elif name == "step":
        d.block("StoneLedge", (1.595, 0.032, 0.516), (0, 0.146, 0))
        for x in (-0.48, 0.23):
            d.block("M_StoneMoss", (0.012, 0.029, 0.007), (x, 0.136, 0.26))
    elif name == "plaque":
        for z in (-0.042, 0.042):
            molding(d, 1.58, 0.49, 0, 0, z)
            for x in (-0.66, 0.66):
                d.line("OldGoldThread", arch(x, 0, z * 1.2, 0.068, 0.092), 0.005, 6)
                sprig(d, x, -0.064, z * 1.2, 0.13)


def furniture(name, d):
    if name == "altar_table":
        for z in (-0.444, 0.444):
            d.block("WarmWood", (2.18, 0.024, 0.022), (0, 0.854, z))
            for x in (-0.68, 0.68):
                molding(d, 0.64, 0.106, x, 0.728, z)
                for n in (-1, 0, 1):
                    sprig(d, x + n * 0.17, 0.677, z * 1.034, 0.108)
        for x in (-1, 1):
            for z in (-0.38, 0.38):
                for y in (0.055, 0.118, 0.673):
                    d.block("BurntLacquer", (0.132, 0.026, 0.132), (x, y, z))
                d.block("WarmWood", (0.089, 0.06, 0.75), (x, 0.28, 0))
        d.line("OxidizedBrass", arch(0, -0.037, 0.275, 0.045, 0.035), 0.006, 8, "Drawer")
    elif name in ("chair_wood", "armchair"):
        arm = name == "armchair"
        width, depth, y = (0.50, 0.44, 0.41) if arm else (0.43, 0.4, 0.435)
        for z in (depth / 2, -depth / 2):
            d.block("BurntLacquer", (width, 0.03, 0.028), (0, y, z))
            d.block("WarmWood", (width * 0.83, 0.033, 0.03), (0, 0.176, z * 0.85))
        molding(d, width * 0.82, 0.34, 0, 0.76, -depth / 2 + 0.04, "WarmWood")
        for x in (-0.105, 0, 0.105):
            sprig(d, x, 0.61, -depth / 2 + 0.047, 0.24, "FadedThread")
        if arm:
            for x in (-0.242, 0.242):
                d.line("WarmWood", [(x, 0.65, -0.21), (x, 0.669, -0.1), (x, 0.661, 0.136),
                                    (x, 0.635, 0.224)], 0.024)
    elif name == "desk_study":
        for x in (-0.64, 0.64):
            d.block("WarmWood", (0.08, 0.064, 0.52), (x, 0.22, 0))
        for x in (-0.32, 0.32):
            molding(d, 0.52, 0.104, x, 0.69, 0.327, "BurntLacquer")
        for x in (0.41, 0.497, 0.54):
            d.line("FadedThread", [(x, 0.795, -0.22), (x + 0.026, 0.795, -0.13),
                                   (x + 0.045, 0.795, -0.085)], 0.002, 5)
    elif name == "dresser":
        for x in (-0.27, 0.25):
            molding(d, 0.38, 0.122, x, 0.66, 0.226)
        for x in (-0.21, 0.21):
            d.line("OxidizedBrass", arch(x, 0.63, 0.244, 0.033, 0.025), 0.0055, 8)
        d.line("BurntLacquer", arch(0, 1.35, -0.142, 0.211, 0.245, 32), 0.014, 8)
        for s in (-1, 1):
            sprig(d, 0.215 * s, 1.25, -0.129, 0.13)
    elif name == "bed":
        for y in (0.24, 0.34, 2.25):
            d.block("BurntLacquer", (2.21, 0.052, 0.043), (0, y, 0.759))
        for x in (-0.84, -0.42, 0, 0.42, 0.84):
            molding(d, 0.36, 0.147, x, 2.17, 0.733)
            sprig(d, x, 2.107, 0.744, 0.137)
        for x in (-1.05, 1.05):
            for y in (0.48, 2.081, 2.24):
                d.band("OxidizedBrass", 0.054, y, 0.006, x, 0.70)
        for k in range(10):
            x = -0.44 + 0.094 * k
            d.line("WeddingSilk", [(x, -0.85, 0.013), (x + 0.01, -0.2, 0.02),
                                  (x - 0.02, 0.30, 0.012), (x, 0.86, 0.009)],
                   0.014, 7, "Curtain")
    elif name == "bookshelf":
        for y in (0.45, 1.05, 1.65):
            d.block("BurntLacquer", (0.8, 0.025, 0.022), (0.45, y, 0.173))
            d.block("BurntLacquer", (0.8, 0.025, 0.022), (-0.45, y, 0.173),
                    parent="SecretPart" if y == 1.05 else None)
        molding(d, 0.792, 0.54, 0.44, 1.35, 0.201, "WarmWood", "SecretPart")
        d.block("BurntLacquer", (1.82, 0.064, 0.05), (0, 2.18, 0.181))
    elif name == "stone_well":
        for y, r in ((0.09, 0.619), (0.22, 0.626), (0.35, 0.628), (0.49, 0.635)):
            d.band("StoneLedge", r, y, 0.008)
            for k in range(12):
                a = tau * k / 12 + y
                d.line("StoneLedge", [(r * cos(a), y, r * sin(a)),
                                     (r * cos(a), y + 0.116, r * sin(a))], 0.007, 5)
        for r in (0.506, 0.653):
            d.band("StoneLedge", r, 0.554, 0.019)
        for x in (-0.7, 0.7):
            d.block("WarmWood", (0.12, 0.15, 0.126), (x, 1.13, 0))
            d.disc("SootIron", 0.039, 0.017, (x, 1.14, 0.067), (90, 0, 0))


def puzzle(name, d):
    if name == "tablet":
        d.block("BurntLacquer", (0.125, 0.034, 0.047), (0, 0.018, 0), parent="Body")
        molding(d, 0.091, 0.165, 0, 0.129, 0.017, "BurntLacquer", "Body")
        sprig(d, 0, 0.194, -0.016, 0.07, "OldGoldThread", "Body")
    elif name == "tablet_rack":
        for y in (0.536, 1.083, 1.634):
            d.block("BurntLacquer", (1.78, 0.039, 0.044), (0, y, 0.173))
            for x in (-0.70, 0.0, 0.7):
                sprig(d, x, y - 0.041, 0.199, 0.052)
        for x in (-0.87, 0.87):
            d.block("WarmWood", (0.054, 1.94, 0.049), (x, 1.0, 0.177))
        d.block("WarmWood", (1.875, 0.029, 0.043), (0, 2.025, 0.204))
    elif name == "bagua_lock":
        for r, y in ((0.178, 0.033), (0.142, 0.048), (0.052, 0.083)):
            d.band("OxidizedBrass", r, y, 0.0045)
        for k in range(8):
            a = tau * k / 8
            d.disc("SootIron", 0.010, 0.008, (0.163 * cos(a), 0.034, 0.163 * sin(a)))
            for t in range(3):
                r = 0.097 + 0.011 * t
                x, z = r * cos(a), r * sin(a)
                d.block("OldGoldThread", (0.005, 0.0025, 0.029), (x, 0.045, z),
                        (0, -a * 180 / pi, 0))
    elif name in ("bronze_mirror", "mirror_stand"):
        stand = name == "mirror_stand"
        r, y = (0.282, 0) if stand else (0.137, 0)
        # The imported Mirror cylinder has a local X rotation; attach its bezel in XZ.
        if stand:
            for height in (0.005, 0.022):
                d.band("OxidizedBrass", r, height, 0.012, parent="Mirror")
            for x in (-0.18, 0.18):
                d.line("WarmWood", [(x, 0.073, -0.12), (0, 0.38, -0.13), (0, 0.71, -0.12)], 0.022)
            d.block("BurntLacquer", (0.495, 0.026, 0.392), (0, 0.058, 0))
        else:
            for z in (-0.02, 0.012):
                d.line("OxidizedBrass", arch(0, y, z, r, r, 32), 0.006, 8)
            for k in range(8):
                a = tau * k / 8
                d.line("OldGoldThread", arch(0.093 * cos(a), 0.093 * sin(a), 0.016, 0.017, 0.016),
                       0.0018, 6)
            for yy in (-0.15, -0.102, -0.072):
                d.band("OxidizedBrass", 0.021, yy, 0.003)
    elif name == "incense_burner":
        for y, r in ((0.046, 0.165), (0.11, 0.139), (0.18, 0.142)):
            d.band("OxidizedBrass", r, y, 0.0055)
        d.disc("UnbleachedPaper", 0.105, 0.019, (0, 0.187, 0))
        for x in (-0.149, 0.149):
            d.line("OxidizedBrass", arch(x, 0.146, 0, 0.039, 0.05), 0.008, 9)
    elif name == "copper_bell":
        for y, r in ((0.004, 0.070), (0.024, 0.065), (0.079, 0.059), (0.123, 0.059)):
            d.band("OxidizedBrass", r, y, 0.0035)
        for k in range(8):
            a = k * tau / 8
            d.line("OldGoldThread", [(0.060 * cos(a), 0.035, 0.060 * sin(a)),
                                     (0.057 * cos(a), 0.066, 0.057 * sin(a))], 0.0021, 5)
    elif name == "jewelry_box":
        for z in (-0.123, 0.123):
            molding(d, 0.327, 0.126, 0, 0.084, z, "BurntLacquer")
            for x in (-0.11, 0.11):
                sprig(d, x, 0.04, z * 1.08, 0.084)
        for x in (-0.129, 0.129):
            d.block("OxidizedBrass", (0.045, 0.029, 0.018), (x, 0.159, -0.129))
        d.block("OxidizedBrass", (0.05, 0.043, 0.013), (0, 0.127, 0.136))
        for r in (0.044, 0.062, 0.086):
            d.band("OldGoldThread", r, 0.022, 0.0026, parent="Lid")
    elif name == "jade_pendant":
        for r, height in ((0.051, 0.0), (0.0195, 0.0)):
            d.band("M_Jade", r, height, 0.004)
        d.line("CinnabarBinding", [(0, 0.007, 0.047), (0.013, 0.047, 0.019),
                   (0.009, 0.086, 0.011), (-0.006, 0.117, 0.009)], 0.0032)
        for k in range(7):
            a = tau * k / 7
            d.line("M_Jade", [(0.026 * cos(a), 0.006, 0.026 * sin(a)),
                               (0.047 * cos(a + 0.075), 0.008, 0.047 * sin(a + 0.075))], 0.002, 6)
    elif name == "cinnabar_pen":
        for y in (0.04, 0.047, 0.053, 0.059, 0.080, 0.214):
            d.band("FadedThread", 0.008, y, 0.0013)
        d.line("CinnabarBinding", [(0, 0.011, 0), (0.001, 0.019, 0), (0, 0.039, 0)],
               [0.001, 0.0045, 0.0065], 11)


def paper_goods(name, d):
    if name in ("book_dark", "book_red"):
        d.block("Parchment", (0.185, 0.031, 0.144), (0.004, 0, 0))
        for y in (-0.012, -0.004, 0.005, 0.010):
            d.block("UnbleachedPaper", (0.181, 0.001, 0.002), (0.007, y, 0.073))
        for z in (-0.057, -0.022, 0.022, 0.057):
            d.line("FadedThread", [(-0.084, -0.022, z), (-0.105, -0.015, z),
                                   (-0.105, 0.018, z), (-0.084, 0.024, z)], 0.0017, 7)
        d.block("Parchment", (0.041, 0.0014, 0.072), (-0.046, 0.023, -0.015))
    elif name == "contract":
        for x in (-0.146, 0.146):
            d.line("OxidizedBrass", [(x, 0.065, 0), (x, 0.030, 0.029), (x, 0, 0),
                                     (x, 0.030, -0.029), (x, 0.065, 0)], 0.0028, 8)
        for z in (0.075, 0.14, 0.199):
            d.line("UnbleachedPaper", [(-0.119, 0.019, z), (0.12, 0.019, z)], 0.0011, 5)
    else:
        width, height = {"letter": (0.16, 0.22), "blood_contract": (0.30, 0.40),
                         "wedding_half": (0.20, 0.28)}[name]
        if name == "letter":
            d.disc("CinnabarBinding", 0.021, 0.008, (0, 0.013, 0))
            d.line("OldGoldThread", [(-0.011, 0.022, 0.006), (0.008, 0.022, 0.006),
                                    (0.008, 0.022, -0.008), (-0.009, 0.022, -0.008)], 0.0011, 5)
        for sign in (-1, 1):
            edge = [(sign * (width / 2 + sin(k * 2.3) * 0.002), 0.0055 + sin(k * 0.9) * 0.0018,
                     (k / 14 - 0.5) * height) for k in range(15)]
            d.line("SootIron" if name == "wedding_half" and sign == 1 else "UnbleachedPaper",
                   edge, 0.0015, 5)


def small_prop(name, d):
    if name == "bamboo_stack":
        for k in range(14):
            offset = 0.022 * (k % 7 - 3)
            y = 0.044 + 0.044 * (k // 7)
            d.line("BambooRind", [(-0.96 + 0.08 * sin(k), y, offset),
                                  (0.14, y - 0.01, offset + 0.02),
                                  (1.02 + 0.067 * cos(k), y + 0.02, offset)], 0.010, 6)
        for x in (-0.62, 0.50):
            rope = [(x, 0.095 + 0.067 * cos(tau * i / 20), 0.085 * sin(tau * i / 20))
                    for i in range(21)]
            d.line("FadedThread", rope, 0.005, 7)
    elif name == "candle":
        for k in range(6):
            a = k * tau / 6
            r = 0.022
            d.line("PaperFolds", [(r * cos(a), 0.284, r * sin(a)),
                                  (r * cos(a + 0.11), 0.246, r * sin(a + 0.11)),
                                  (r * cos(a + 0.09), 0.204 + 0.04 * sin(k), r * sin(a + 0.09))],
                   [0.0032, 0.0039, 0.0012], 6)
        d.band("Parchment", 0.028, 0.103, 0.0043)
    elif name == "dead_rat":
        d.line("FadedThread", [(0, 0.06, 0.174), (0.04, 0.027, 0.232),
                              (0.104, 0.019, 0.24), (0.136, 0.012, 0.207)], [0.009, 0.007, 0.005, 0.0017])
        for x in (-0.035, 0.035):
            d.line("SootIron", [(x, 0.061, -0.15), (x * 1.6, 0.055, -0.172),
                                (x * 2.2, 0.054, -0.164)], 0.0018, 5)
    elif name == "fire_starter":
        for y in (0.009, 0.02, 0.121, 0.135, 0.155):
            d.band("OxidizedBrass", 0.0166, y, 0.0021)
        d.line("FadedThread", [(0.014, 0.125, 0), (0.03, 0.149, 0),
                               (0.021, 0.174, 0), (0.01, 0.164, 0)], 0.002)
    elif name == "luopan":
        d.disc("Parchment", 0.116, 0.003, (0, 0.055, 0))
        for r in (0.078, 0.101, 0.124):
            d.band("OxidizedBrass", r, 0.061, 0.0024)
        d.block("CinnabarBinding", (0.01, 0.004, 0.145), (0, 0.063, 0))
        for k in range(36):
            a = tau * k / 36
            d.line("SootIron", [(0.089 * cos(a), 0.059, 0.089 * sin(a)),
                                (0.102 * cos(a), 0.059, 0.102 * sin(a))], 0.0011, 5)
    elif name == "offering_plate":
        for y, r in ((0.023, 0.144), (0.030, 0.136), (0.032, 0.119)):
            d.band("FadedIndigo" if y == 0.030 else "Parchment", r, y, 0.0036)
        for k in range(10):
            a = k * tau / 10
            d.line("FadedIndigo", [(0.123 * cos(a), 0.032, 0.123 * sin(a)),
                                   (0.132 * cos(a + 0.09), 0.034, 0.132 * sin(a + 0.09))],
                   0.0015, 5)
    elif name == "paste_pot":
        for y, r in ((0.011, 0.113), (0.063, 0.129), (0.118, 0.131), (0.169, 0.113)):
            d.band("StoneLedge", r, y, 0.005)
        d.line("WarmWood", [(0.064, 0.16, 0.038), (0.108, 0.205, 0.067),
                            (0.152, 0.243, 0.085)], 0.0085, 9)
    elif name == "red_shoes":
        for side, x in enumerate((-0.06, 0.06)):
            welt = [(x + 0.042 * cos(tau * k / 24), 0.021, 0.111 * sin(tau * k / 24))
                    for k in range(25)]
            opening = [(x + 0.028 * cos(tau * k / 24), 0.077, -0.021 + 0.047 * sin(tau * k / 24))
                       for k in range(25)]
            d.line("FadedThread", welt, 0.0035)
            d.line("CinnabarBinding", opening, 0.004)
            for k in range(5):
                a = k * tau / 5
                d.line("OldGoldThread", [(x, 0.104, 0.052), (x + 0.013 * cos(a), 0.102,
                            0.052 + 0.021 * sin(a)), (x, 0.105, 0.052)], 0.0018, 6)
            if side == 1:
                d.disc("OxidizedBrass", 0.007, 0.009, (x + 0.029, 0.087, -0.02))
    elif name == "spirit_flag":
        for y in (0.772, 1.823, 1.919):
            d.band("FadedThread", 0.018, y, 0.0048)
        d.line("UnbleachedPaper", [(0.018, 0.7, 0.007), (0.13, 0.695, 0.011), (0.24, 0.71, 0.012),
                                  (0.35, 0.674, 0.009), (0.49, 0.705, 0.008)], 0.0025, 5)
        for k in range(12):
            x = 0.02 + 0.041 * k
            d.line("Parchment", [(x, 0.710, 0.006), (x + 0.013, 0.61 + 0.04 * sin(k), 0.019)],
                   0.0036, 5)


FURNITURE = {
    "altar_table", "armchair", "bed", "bookshelf", "chair_wood", "desk_study", "dresser", "stone_well",
}
PUZZLES = {
    "tablet", "tablet_rack", "bagua_lock", "bronze_mirror", "mirror_stand",
    "incense_burner", "copper_bell", "jewelry_box", "jade_pendant", "cinnabar_pen",
}
DOCUMENTS = {"letter", "book_dark", "book_red", "contract", "blood_contract", "wedding_half"}
SMALL_PROPS = {
    "bamboo_stack", "candle", "dead_rat", "fire_starter", "luopan", "offering_plate",
    "paste_pot", "red_shoes", "spirit_flag",
}
FIGURES = {"paper_figure", "paper_head", "bride_ghost"}
LANTERNS = {"hand_lantern", "hanging_lantern"}


def read_glb(path):
    raw = path.read_bytes()
    magic, version, _ = struct.unpack_from("<4sII", raw)
    if magic != b"glTF" or version != 2:
        raise ValueError(f"Not a glTF 2.0 binary: {path}")
    size, kind = struct.unpack_from("<I4s", raw, 12)
    if kind != b"JSON":
        raise ValueError(f"Missing JSON chunk: {path}")
    end = 20 + size
    data = json.loads(raw[20:end])
    bin_size, bin_kind = struct.unpack_from("<I4s", raw, end)
    if bin_kind != b"BIN\0" or len(data["buffers"]) != 1:
        raise ValueError(f"Expected a single embedded buffer: {path}")
    return data, raw[end + 8:end + 8 + bin_size]


def write_glb(path, data, payload):
    encoded = json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    payload += b"\0" * (-len(payload) % 4)
    path.write_bytes(
        struct.pack("<4sII", b"glTF", 2, 28 + len(encoded) + len(payload))
        + struct.pack("<I4s", len(encoded), b"JSON") + encoded
        + struct.pack("<I4s", len(payload), b"BIN\0") + payload
    )


def copy_geometry(dst, src, offset):
    """Append the static glblib output's indexes to an existing Blender GLB."""
    keys = ("bufferViews", "accessors", "images", "samplers", "textures", "materials", "meshes")
    base = {key: len(dst.get(key, [])) for key in keys}
    for view in src.get("bufferViews", []):
        view["byteOffset"] = view.get("byteOffset", 0) + offset
    for acc in src.get("accessors", []):
        acc["bufferView"] += base["bufferViews"]
    for im in src.get("images", []):
        im["bufferView"] += base["bufferViews"]
    for tex in src.get("textures", []):
        tex["source"] += base["images"]
        if "sampler" in tex:
            tex["sampler"] += base["samplers"]
    for mat in src.get("materials", []):
        for group in (mat, mat.get("pbrMetallicRoughness", {})):
            for key, value in group.items():
                if key.endswith("Texture"):
                    value["index"] += base["textures"]
    for mesh in src.get("meshes", []):
        for primitive in mesh["primitives"]:
            primitive["indices"] += base["accessors"]
            primitive["material"] += base["materials"]
            primitive["attributes"] = {
                semantic: idx + base["accessors"] for semantic, idx in primitive["attributes"].items()
            }
    for key in keys:
        if src.get(key):
            dst.setdefault(key, []).extend(src[key])
    return base["meshes"]


def attach_nodes(dst, src, mesh_offset):
    src_root = src["scenes"][src.get("scene", 0)]["nodes"][0]
    dst_root = dst["scenes"][dst.get("scene", 0)]["nodes"][0]
    original = {n.get("name"): i for i, n in enumerate(dst["nodes"])}
    mapping = {src_root: dst_root}
    for i, n in enumerate(src["nodes"]):
        if i == src_root:
            continue
        if "mesh" in n:
            mapping[i] = len(dst["nodes"])
            dst["nodes"].append({k: v for k, v in n.items() if k != "children"})
            dst["nodes"][-1]["mesh"] += mesh_offset
        else:
            try:
                mapping[i] = original[n["name"]]
            except KeyError as e:
                raise ValueError(f"Cannot attach art to missing node {n['name']}") from e
    for i, n in enumerate(src["nodes"]):
        for child in n.get("children", []):
            # Existing transform nodes already have a parent in the Blender asset.
            if "mesh" in src["nodes"][child]:
                dst["nodes"][mapping[i]].setdefault("children", []).append(mapping[child])


def rematerialize(data, name):
    for m in data.get("materials", []):
        base = m.get("pbrMetallicRoughness")
        if base is None:
            continue
        if m.get("name") == "M_WoodRed":
            base["baseColorFactor"] = [0.51, 0.44, 0.36, 1]
            base["roughnessFactor"] = 0.74
        if m.get("name") == "M_WoodDark":
            base["baseColorFactor"] = [0.76, 0.63, 0.52, 1]
    if name == "window":
        # The old 'frame' was a solid slab behind the two lattice faces.
        for node in data["nodes"]:
            if node.get("name") == "Frame":
                node.pop("mesh", None)


def combine(old, layer, output):
    asset, binary = read_glb(old)
    detail, data = read_glb(layer)
    rematerialize(asset, old.stem)
    mesh_offset = copy_geometry(asset, detail, len(binary))
    attach_nodes(asset, detail, mesh_offset)
    binary += data
    asset["buffers"][0]["byteLength"] = len(binary)
    write_glb(output, asset, binary)


def build_one(source, output, intermediate):
    name = source.stem
    if name in LANTERNS:
        lantern(hanging=name == "hanging_lantern").save(output)
        return
    if name in FIGURES:
        figure(name).save(output)
        return

    detail = Details(Prop("ArtDetails"))
    if source.parent.name == "kit":
        building(name, detail)
    elif name in FURNITURE:
        furniture(name, detail)
    elif name in PUZZLES:
        puzzle(name, detail)
    elif name in DOCUMENTS:
        paper_goods(name, detail)
    elif name in SMALL_PROPS:
        small_prop(name, detail)
    if not detail.groups:
        raise ValueError(f"No modeled details for {source.name}")
    detail.finish().save(intermediate)
    combine(source, intermediate, output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=PROJECT / "assets_hd")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        parser.error("Use separate source and output directories")
    inputs = sorted(
        p for category in ("kit", "props") for p in (args.input / category).glob("*.glb")
    )
    if len(inputs) != 50:
        parser.error(f"Expected 50 base GLBs, found {len(inputs)} in {args.input}")
    materials()
    with TemporaryDirectory(prefix="shenjia-model-") as tmp:
        intermediate = Path(tmp) / "detail.glb"
        for source in inputs:
            destination = args.output / source.parent.name / source.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            build_one(source, destination, intermediate)
            print(f"{source.parent.name}/{source.name}  {destination.stat().st_size:,} bytes")
    print(f"Built {len(inputs)} models")


if __name__ == "__main__":
    main()
