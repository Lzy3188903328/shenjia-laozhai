# -*- coding: utf-8 -*-
"""
props.py — 《沈家老宅》全部资产生成器
模块化古宅 kit + 中式民俗道具，输出 .glb（含碰撞代理 -colonly 与动画轨道）
动画轨道命名规范：door_open / drawer_open / turn_head / lantern_sway /
                 secretshelf_slide / bed_curtain_open / tablet_pickup
"""
import math, os
import numpy as np
from glblib import (Prop, MATLIB, Mesh, box, plane, quad, cylinder, lathe, sphere,
                    annulus, prism, trs_matrix)

rng = np.random.default_rng(20241017)

def register_materials():
    M = MATLIB.mat
    M("M_WoodDark",  tex="t_wood_dark",  rough=0.78)
    M("M_WoodRed",   tex="t_wood_red",   rough=0.62)
    M("M_WoodFloor", tex="t_wood_floor", rough=0.72)
    M("M_Brick",     tex="t_brick",      rough=0.9)
    M("M_Stone",     tex="t_stone",      rough=0.92)
    M("M_StoneMoss", tex="t_stone_moss", rough=0.95)
    M("M_PaperWhite",tex="t_paper_white",rough=0.92)
    M("M_PaperYellow",tex="t_paper_yellow",rough=0.9)
    M("M_PaperRed",  tex="t_paper_red",  rough=0.85)
    M("M_Talisman",  tex="t_talisman",   rough=0.88)
    M("M_DocInk",    tex="t_doc_ink",    rough=0.9)
    M("M_DocInk2",   tex="t_doc_ink2",   rough=0.9)
    M("M_DocBlood",  tex="t_doc_blood",  rough=0.9)
    M("M_DocBurn",   tex="t_doc_burn",   rough=0.9)
    M("M_ClothWhite",tex="t_cloth_white",rough=0.9)
    M("M_ClothRed",  tex="t_cloth_red",  rough=0.8)
    M("M_Curtain",   tex="t_cloth_red",  rough=0.7, alpha="BLEND", double=True)
    M("M_Bronze",    tex="t_bronze",     metal=0.85, rough=0.35)
    M("M_BronzeMirror", tex="t_bronze",  metal=0.95, rough=0.12)
    M("M_Tile",      tex="t_tile",       rough=0.85)
    M("M_Bamboo",    tex="t_bamboo",     rough=0.8)
    M("M_Lattice",   tex="t_lattice",    alpha="MASK", double=True, cutoff=0.5)
    M("M_FaceSmile", tex="t_face_smile", rough=0.92)
    M("M_FaceNoEye", tex="t_face_noeye", rough=0.92)
    M("M_FaceEyed",  tex="t_face_eyed",  rough=0.92)
    M("M_FaceRed",   tex="t_face_red",   rough=0.9)
    M("M_Flag",      tex="t_flag",       rough=0.9, double=True)
    M("M_Jade",      tex="t_jade",       rough=0.15, emissive=(0.02, 0.06, 0.04))
    M("M_Mold",      tex="t_mold",       rough=0.95)
    M("M_Iron",      tex="t_iron",       metal=0.7, rough=0.5)
    M("M_LanternRed",tex="t_lantern_red",rough=0.8, emissive=(0.25, 0.03, 0.02))
    M("M_ShoeRed",   tex="t_shoe_red",   rough=0.7)
    M("M_Black",     tex="t_black",      rough=0.95)
    M("M_Flame",     color=(1.0, 0.62, 0.18, 1), rough=1.0, emissive=(1.0, 0.55, 0.15))
    M("M_FlameGreen",color=(0.4, 1.0, 0.45, 1), rough=1.0, emissive=(0.25, 0.9, 0.3))
    M("M_GhostFire", color=(0.45, 0.95, 0.55, 1), rough=1.0, emissive=(0.35, 0.9, 0.45))
    M("M_Brass",     color=(0.72, 0.55, 0.22, 1), metal=0.9, rough=0.3)

# ================================================================ 建筑 Kit
def build_wall_brick():
    p = Prop("SM_WallBrick")
    p.part("Wall", box(4, 3, 0.24, uv=2), "M_Brick", t=(0, 1.5, 0))
    p.col((0, 1.5, 0), (4, 3, 0.24))
    return p

def build_wall_wood():
    p = Prop("SM_WallWood")
    p.part("Panel", box(4, 3, 0.1, uv=2), "M_WoodDark", t=(0, 1.5, 0))
    p.part("FrameT", box(4.1, 0.16, 0.16), "M_WoodRed", t=(0, 3.0, 0))
    p.part("FrameB", box(4.1, 0.14, 0.18), "M_WoodRed", t=(0, 0.07, 0))
    for x in (-1.95, 1.95):
        p.part("FrameS%d" % int(x), box(0.16, 3.1, 0.16), "M_WoodRed", t=(x, 1.5, 0))
    for i in range(4):
        p.part("PanelDiv%d" % i, box(0.05, 2.7, 0.06), "M_WoodRed", t=(-1.5 + i, 1.5, 0.03))
    p.col((0, 1.5, 0), (4, 3, 0.14))
    return p

def build_pillar():
    p = Prop("SM_Pillar")
    p.part("Shaft", cylinder(0.14, 0.13, 2.9, 12), "M_WoodRed", t=(0, 0.12, 0))
    p.part("Base", box(0.42, 0.14, 0.42), "M_Stone", t=(0, 0.07, 0))
    p.part("Cap", cylinder(0.18, 0.14, 0.12, 12), "M_WoodDark", t=(0, 3.0, 0))
    p.col((0, 1.5, 0), (0.4, 3, 0.4))
    return p

def build_beam():
    p = Prop("SM_Beam")
    p.part("Beam", box(4, 0.24, 0.24, uv=2), "M_WoodDark", t=(0, 0, 0))
    p.col((0, 0, 0), (4, 0.24, 0.24))
    return p

def build_roof_seg():
    p = Prop("SM_RoofSeg")
    p.part("Slab", box(4.6, 0.12, 2.8, uv=2), "M_Tile", t=(0, 0, 0))
    p.part("Fascia", box(4.7, 0.18, 0.1), "M_WoodRed", t=(0, -0.05, 1.4))
    p.col((0, 0, 0), (4.6, 0.12, 2.8))
    return p

def build_floor_stone():
    p = Prop("SM_FloorStone")
    p.part("Floor", box(4, 0.1, 4, uv=2), "M_Stone", t=(0, -0.05, 0))
    p.col((0, -0.05, 0), (4, 0.1, 4))
    return p

def build_floor_wood():
    p = Prop("SM_FloorWood")
    p.part("Floor", box(4, 0.08, 4, uv=2), "M_WoodFloor", t=(0, -0.04, 0))
    p.col((0, -0.04, 0), (4, 0.08, 4))
    return p

def build_door():
    p = Prop("SM_Door")
    # 门框：开口 1.1 × 2.06（门洞必须真实可通行）
    p.part("JambL", box(0.16, 2.3, 0.22), "M_WoodRed", t=(-0.63, 1.15, 0))
    p.part("JambR", box(0.16, 2.3, 0.22), "M_WoodRed", t=(0.63, 1.15, 0))
    p.part("Lintel", box(1.42, 0.22, 0.24), "M_WoodRed", t=(0, 2.28, 0))
    # 门扇：枢轴节点在合页（x=-0.55），门板网格偏移到枢轴东侧（覆盖整个门洞）
    leaf = Mesh()
    leaf.merge(box(1.06, 2.06, 0.06, uv=1), trs_matrix(t=(0.53, 0, 0)))
    p.part("DoorLeaf", leaf, "M_WoodRed", t=(-0.55, 1.06, 0))
    # 门心雕花嵌板（父级=DoorLeaf；父级原点 y=1.06，局部 y=yy-1.06）
    for i, yy in enumerate((0.5, 1.15, 1.75)):
        p.part("Carve%d" % i, box(0.7, 0.5, 0.03), "M_WoodDark", t=(0.53, yy - 1.06, 0.045), parent="DoorLeaf")
    p.part("Pull", cylinder(0.02, 0.02, 0.16, 8), "M_Brass", t=(1.0, -0.35, 0.06), r=(90, 0, 0), parent="DoorLeaf")
    # 碰撞：门框两柱 + 上槛（绝不填满门洞）；门扇碰撞挂在 DoorLeaf 随动画跟随
    p.part("DoorLeaf-colonly", box(1.06, 2.06, 0.08), "M_Col", t=(0.53, 0, 0), parent="DoorLeaf")
    p.part("JambL-colonly", box(0.18, 2.3, 0.3), "M_Col", t=(-0.62, 1.15, 0))
    p.part("JambR-colonly", box(0.18, 2.3, 0.3), "M_Col", t=(0.62, 1.15, 0))
    p.part("Lintel-colonly", box(1.42, 0.32, 0.3), "M_Col", t=(0, 2.22, 0))
    # 打开动画（绕合页 -100°）
    # 向内开（+100°）：门扇扫向门后一侧，远离正对门按 E 的玩家
    p.anim("door_open", "DoorLeaf", "rotation",
           [(0.0, (0, 0, 0)), (0.6, (0, 55, 0)), (1.1, (0, 100, 0))])
    p.anim("door_close", "DoorLeaf", "rotation",
           [(0.0, (0, 100, 0)), (0.7, (0, 0, 0))])
    return p

def build_window():
    p = Prop("SM_Window")
    p.part("Frame", box(1.24, 1.24, 0.1), "M_WoodRed", t=(0, 1.5, 0))
    p.part("Lattice", quad(1.1, 1.1, uv=1), "M_Lattice", t=(0, 1.5, 0.06))
    p.part("LatticeB", quad(1.1, 1.1, uv=1), "M_Lattice", t=(0, 1.5, -0.06), r=(0, 180, 0))
    p.col((0, 1.5, 0), (1.24, 1.24, 0.12))
    return p

def build_railing():
    p = Prop("SM_Railing")
    p.part("RailTop", box(2, 0.08, 0.08), "M_WoodRed", t=(0, 0.9, 0))
    p.part("RailBot", box(2, 0.06, 0.06), "M_WoodDark", t=(0, 0.18, 0))
    for i in range(6):
        p.part("Bar%d" % i, box(0.06, 0.75, 0.06), "M_WoodRed", t=(-0.85 + i * 0.34, 0.5, 0))
    p.col((0, 0.5, 0), (2, 1, 0.1))
    return p

def build_step():
    p = Prop("SM_Step")
    p.part("Step", box(1.6, 0.16, 0.5), "M_Stone", t=(0, 0.08, 0))
    p.col((0, 0.08, 0), (1.6, 0.16, 0.5))
    return p

def build_plaque():
    p = Prop("SM_Plaque")
    p.part("Board", box(1.6, 0.5, 0.06), "M_Black", t=(0, 0, 0))
    p.part("Border", box(1.7, 0.6, 0.04), "M_WoodRed", t=(0, 0, -0.02))
    p.col((0, 0, 0), (1.7, 0.6, 0.1))
    return p

# ================================================================ 道具
def _paper_figure(name, h=1.68, mat_body="M_ClothWhite", mat_face="M_FaceNoEye", hair=False):
    p = Prop(name)
    s = h / 1.68
    p.part("Base", cylinder(0.26 * s, 0.24 * s, 0.08, 12), "M_Bamboo")
    p.part("Body", lathe([
        (0.24 * s, 0.08), (0.26 * s, 0.3), (0.22 * s, 0.75), (0.20 * s, 0.95),
        (0.28 * s, 1.08), (0.30 * s, 1.16), (0.12 * s, 1.24), (0.05 * s, 1.28),
    ], 14), mat_body, s=(1, s, 1))
    # 手臂
    for side in (-1, 1):
        p.part("Arm%d" % side, cylinder(0.03 * s, 0.025 * s, 0.52 * s, 8), mat_body,
               t=(side * 0.30 * s, 1.08 * s, 0.06), r=(0, 0, side * 12))
        p.part("Hand%d" % side, sphere(0.045 * s, 8), mat_body,
               t=(side * 0.38 * s, 0.82 * s, 0.1))
    # 头（独立节点 turn_head）
    p.part("Head", sphere(0.14 * s, 14), mat_body, t=(0, 1.44 * s, 0), s=(1, 1.15, 1))
    p.part("Face", quad(0.20 * s, 0.24 * s), mat_face,
           t=(0, -0.01, 0.135 * s), parent="Head")
    if hair:
        p.part("Hair", sphere(0.145 * s, 12), "M_Black", t=(0, 1.44 * s, -0.01), s=(1, 0.9, 1))
    p.anim("turn_head", "Head", "rotation",
           [(0.0, (0, 0, 0)), (0.8, (0, 92, 0))])
    p.col((0, 0.8 * s, 0), (0.5, 1.55 * s, 0.4))
    return p

def build_paper_figure():
    return _paper_figure("SM_PaperFigure")

def build_paper_head():
    p = Prop("SM_PaperHead")
    p.part("Head", sphere(0.14, 14), "M_ClothWhite", t=(0, 0.14, 0), s=(1, 1.15, 1))
    p.part("Face", quad(0.20, 0.24), "M_FaceNoEye", t=(0, 0.13, 0.135))
    return p

def build_bride_ghost():
    """红衣鬼影（终局追逐）"""
    p = Prop("SM_BrideGhost")
    p.part("Body", lathe([
        (0.30, 0.0), (0.32, 0.25), (0.26, 0.8), (0.24, 1.0),
        (0.30, 1.12), (0.28, 1.24), (0.10, 1.32), (0.05, 1.36),
    ], 14), "M_ClothRed")
    for side in (-1, 1):
        p.part("Arm%d" % side, cylinder(0.035, 0.03, 0.58, 8), "M_ClothRed",
               t=(side * 0.30, 1.14, 0.02), r=(0, 0, side * 6))
        p.part("Hand%d" % side, sphere(0.05, 8), "M_PaperWhite",
               t=(side * 0.33, 0.56, 0.04))
    p.part("Head", sphere(0.15, 14), "M_PaperWhite", t=(0, 1.5, 0), s=(1, 1.2, 1))
    p.part("Face", quad(0.22, 0.26), "M_FaceRed", t=(0, 1.49, 0.143), parent="Head")
    p.part("Hair", sphere(0.16, 12), "M_Black", t=(0, 1.52, -0.02), s=(1, 0.92, 1))
    # 盖头（半透明红布，垂在头前）
    p.part("Veil", quad(0.34, 0.5), "M_Curtain", t=(0, 1.42, 0.16), r=(8, 0, 0))
    return p

def build_hand_lantern():
    """手持纸灯笼（玩家光源）"""
    p = Prop("SM_HandLantern")
    p.part("Body", cylinder(0.11, 0.11, 0.16, 14), "M_LanternRed", t=(0, 0.03, 0))
    p.part("CapT", cylinder(0.06, 0.05, 0.03, 12), "M_WoodDark", t=(0, 0.19, 0))
    p.part("CapB", cylinder(0.05, 0.06, 0.03, 12), "M_WoodDark", t=(0, 0, 0))
    p.part("Hook", cylinder(0.012, 0.012, 0.06, 6), "M_Iron", t=(0, 0.25, 0))
    # 提梁
    pts = []
    for i in range(9):
        a = math.pi * i / 8
        pts.append((0.09 * math.sin(a), 0.22 + 0.09 * math.cos(a) - 0.05, 0))
    p.part("Handle", lathe([(0.001, 0), (0.008, 0.01), (0.008, 0.02), (0.001, 0.03)], 6),
           "M_Bamboo", t=(0.09, 0.2, 0), r=(0, 90, 90))
    p.part("Flame", sphere(0.035, 8), "M_Flame", t=(0, 0.11, 0), s=(1, 1.4, 1))
    p.anim("lantern_sway", "Flame", "rotation",
           [(0.0, (0, 0, -7)), (0.5, (0, 0, 7)), (1.0, (0, 0, -7))])
    return p

def build_hanging_lantern():
    """回廊悬挂红灯笼"""
    p = Prop("SM_HangingLantern")
    p.part("Cord", cylinder(0.008, 0.008, 0.35, 6), "M_Bamboo", t=(0, 0, 0))
    p.part("Body", cylinder(0.19, 0.19, 0.28, 16), "M_LanternRed", t=(0, -0.63, 0))
    p.part("CapT", cylinder(0.08, 0.07, 0.04, 12), "M_Black", t=(0, -0.31, 0))
    p.part("CapB", cylinder(0.07, 0.08, 0.04, 12), "M_Black", t=(0, -0.66, 0))
    p.part("Tassel", cylinder(0.02, 0.005, 0.14, 8), "M_ClothRed", t=(0, -0.86, 0))
    p.anim("lantern_sway", "Body", "rotation",
           [(0.0, (0, 0, -9)), (0.6, (0, 2, 9)), (1.2, (0, 0, -9))])
    return p

def build_tablet():
    """牌位：木身 + 黄纸条（名字由引擎 Label3D 叠加），背面刻生辰"""
    p = Prop("SM_Tablet")
    poly = [(-0.055, 0), (0.055, 0), (0.055, 0.20), (0.028, 0.28), (-0.028, 0.28), (-0.055, 0.20)]
    p.part("Body", prism(poly, 0.022), "M_WoodRed")
    p.part("FacePaper", quad(0.075, 0.17), "M_PaperYellow", t=(0, 0.13, 0.013))
    p.col((0, 0.14, 0), (0.12, 0.3, 0.03))
    p.anim("tablet_pickup", "Body", "translation",
           [(0.0, (0, 0, 0)), (0.4, (0, 0.12, 0.25))])
    return p

def build_tablet_rack():
    p = Prop("SM_TabletRack")
    for x in (-0.85, 0.85):
        p.part("Side_%d" % int(x * 100), box(0.06, 2.0, 0.4), "M_WoodDark", t=(x, 1.0, 0))
    for i, y in enumerate((0.55, 1.1, 1.65)):
        p.part("Shelf%d" % i, box(1.8, 0.05, 0.36), "M_WoodDark", t=(0, y, 0))
        p.part("Ridge%d" % i, box(1.8, 0.04, 0.05), "M_WoodRed", t=(0, y + 0.045, -0.14))
    p.part("Top", box(1.9, 0.08, 0.44), "M_WoodRed", t=(0, 2.0, 0))
    p.col((0, 1.0, 0), (1.8, 2.0, 0.4))
    return p

def build_altar_table():
    """供桌：含暗格抽屉（谜题1 产出道士手札）"""
    p = Prop("SM_AltarTable")
    p.part("Top", box(2.2, 0.09, 0.9, uv=1.5), "M_WoodRed", t=(0, 0.86, 0))
    for x, z in ((-1.0, -0.38), (1.0, -0.38), (-1.0, 0.38), (1.0, 0.38)):
        p.part("Leg_%d_%d" % (int(x * 100), int(z * 100)), box(0.12, 0.82, 0.12), "M_WoodDark", t=(x, 0.41, z))
    p.part("ApronF", box(2.1, 0.22, 0.04), "M_WoodDark", t=(0, 0.72, 0.42))
    p.part("ApronB", box(2.1, 0.22, 0.04), "M_WoodDark", t=(0, 0.72, -0.42))
    # 暗格抽屉
    p.part("Drawer", box(0.56, 0.16, 0.4), "M_WoodDark", t=(0, 0.6, 0.18))
    p.part("DrawerFace", box(0.6, 0.2, 0.03), "M_WoodRed", t=(0, 0, 0.22), parent="Drawer")
    p.part("DrawerKnob", sphere(0.025, 8), "M_Brass", t=(0, 0, 0.25), parent="Drawer")
    p.anim("drawer_open", "Drawer", "translation",
           [(0.0, (0, 0.6, 0.18)), (0.7, (0, 0.6, 0.48))])
    p.col((0, 0.45, 0), (2.2, 0.9, 0.9))
    return p

def build_bagua_lock():
    """八卦机关锁：底盘 + 8 卦转盘 Ring + 中心五行钮 Knob"""
    p = Prop("SM_BaguaLock")
    p.part("Base", cylinder(0.18, 0.18, 0.03, 20), "M_Brass", t=(0, 0, 0))
    p.part("BaseRing", annulus(0.18, 0.15, 20), "M_Bronze", t=(0, 0.031, 0), r=(90, 0, 0))
    for i in range(8):
        a = 2 * math.pi * i / 8
        p.part("Slot%d" % i, box(0.055, 0.014, 0.035), "M_Iron",
               t=(0.125 * math.sin(a), 0.035, 0.125 * math.cos(a)), r=(0, -math.degrees(a), 0), parent="Ring")
    p.part("Ring", cylinder(0.145, 0.145, 0.012, 20), "M_Bronze", t=(0, 0.03, 0))
    p.part("Knob", cylinder(0.055, 0.05, 0.045, 12), "M_Brass", t=(0, 0.05, 0))
    p.part("KnobMark", box(0.01, 0.01, 0.05), "M_Iron", t=(0, 0.075, 0.02))
    return p

def build_bronze_mirror():
    """手持铜镜（检视：边缘铭文）"""
    p = Prop("SM_BronzeMirror")
    p.part("Disc", cylinder(0.13, 0.13, 0.014, 20), "M_BronzeMirror", t=(0, 0, 0), r=(90, 0, 0))
    p.part("Rim", annulus(0.145, 0.13, 20), "M_Bronze", t=(0, 0.008, 0), r=(90, 0, 0))
    p.part("Handle", cylinder(0.018, 0.014, 0.11, 8), "M_WoodRed", t=(0, -0.17, 0))
    return p

def build_mirror_stand():
    """谜题用立式铜镜（Mirror 节点可绕 Y 旋转）"""
    p = Prop("SM_MirrorStand")
    p.part("Base", box(0.5, 0.06, 0.4), "M_WoodDark", t=(0, 0.03, 0))
    p.part("Post", box(0.1, 0.9, 0.1), "M_WoodRed", t=(0, 0.5, -0.12))
    p.part("Mirror", cylinder(0.26, 0.26, 0.02, 20), "M_BronzeMirror", t=(0, 1.05, 0), r=(90, 0, 0))
    p.part("Frame", annulus(0.30, 0.26, 20), "M_Brass", t=(0, 1.05, 0), r=(90, 0, 0))
    p.part("Knob", cylinder(0.03, 0.03, 0.05, 10), "M_Brass", t=(0, 0.98, -0.06))
    p.col((0, 0.45, 0), (0.5, 0.9, 0.35))   # 只挡底座立柱，镜面交互盒(y~1.05)不被遮
    return p

def build_incense_burner():
    """香炉 + 三炷香（中间/左/右，燃点由引擎控制）"""
    p = Prop("SM_IncenseBurner")
    p.part("Bowl", lathe([(0.02, 0), (0.16, 0.01), (0.17, 0.03), (0.12, 0.14),
                          (0.14, 0.17), (0.145, 0.19), (0.13, 0.20)], 16), "M_Bronze")
    for i in range(3):
        a = 2 * math.pi * i / 3
        p.part("Leg%d" % i, cylinder(0.015, 0.01, 0.08, 6), "M_Bronze",
               t=(0.09 * math.cos(a), -0.075, 0.09 * math.sin(a)), r=(15 * math.cos(a), 0, 15 * math.sin(a)))
    for nm, x in (("IncenseMid", 0.0), ("IncenseL", -0.05), ("IncenseR", 0.05)):
        p.part(nm, cylinder(0.005, 0.004, 0.24, 5), "M_Iron", t=(x, 0.3, 0), r=(rng.uniform(-4, 4), 0, rng.uniform(-4, 4)))
        p.part("Ember" + nm[7:], sphere(0.008, 6), "M_Flame", t=(x, 0.42, 0))
    return p

def build_copper_bell():
    """铜铃：铃身刻时辰（引擎 Label3D），铃舌可敲"""
    p = Prop("SM_CopperBell")
    p.part("Bell", lathe([(0.055, 0.16), (0.062, 0.12), (0.055, 0.05),
                          (0.065, 0.01), (0.07, 0.0), (0.065, -0.01)], 16), "M_Brass")
    p.part("Loop", annulus(0.022, 0.012, 10), "M_Brass", t=(0, 0.18, 0), r=(90, 0, 0))
    p.part("Clapper", sphere(0.02, 8), "M_Iron", t=(0, 0.01, 0))
    p.anim("bell_ring", "Clapper", "translation",
           [(0.0, (0, 0.01, 0)), (0.08, (0.05, 0.01, 0)), (0.16, (-0.05, 0.01, 0)),
            (0.24, (0.04, 0.01, 0)), (0.32, (0, 0.01, 0))])
    return p

def build_cinnabar_pen():
    p = Prop("SM_CinnabarPen")
    p.part("Handle", cylinder(0.008, 0.007, 0.16, 8), "M_Bamboo", t=(0, 0.08, 0))
    p.part("Ferrule", cylinder(0.008, 0.006, 0.02, 8), "M_Brass", t=(0, 0.03, 0))
    p.part("Tip", cylinder(0.007, 0.001, 0.035, 8), "M_PaperRed", t=(0, 0, 0))
    return p

def build_fire_starter():
    """火折子：铜管 + 引燃头（点燃由引擎切换材质发光）"""
    p = Prop("SM_FireStarter")
    p.part("Tube", cylinder(0.016, 0.014, 0.13, 10), "M_Iron")
    p.part("Cap", cylinder(0.017, 0.012, 0.03, 10), "M_Brass", t=(0, 0.14, 0))
    p.part("Tip", cylinder(0.01, 0.006, 0.03, 8), "M_PaperYellow", t=(0, -0.015, 0))
    return p

def build_jade_pendant():
    p = Prop("SM_JadePendant")
    p.part("Ring", annulus(0.05, 0.02, 20), "M_Jade", t=(0, 0, 0.004))
    p.part("RingB", annulus(0.05, 0.02, 20), "M_Jade", t=(0, 0, -0.004), r=(180, 0, 0))
    p.part("Cord", cylinder(0.003, 0.003, 0.08, 5), "M_ClothRed", t=(0, 0.09, 0))
    return p

def build_letter():
    p = Prop("SM_Letter")
    p.part("Paper", quad(0.16, 0.22), "M_DocInk2", t=(0, 0.005, 0), r=(-90, 0, 0))
    p.part("Flap", quad(0.155, 0.1), "M_DocInk", t=(0, 0.006, -0.045), r=(-78, 0, 0))
    p.part("Seal", cylinder(0.02, 0.02, 0.008, 12), "M_PaperRed", t=(0, 0.008, 0.0))
    return p

def _book(name, cover_mat, w=0.2, h=0.045, d=0.15):
    p = Prop(name)
    p.part("Cover", box(w, h, d), cover_mat)
    p.part("Pages", box(w - 0.02, h - 0.014, d - 0.012), "M_PaperWhite", t=(0.006, 0, 0))
    return p

def build_book_red():
    return _book("SM_BookRed", "M_ClothRed")

def build_book_dark():
    return _book("SM_BookDark", "M_WoodDark")

def build_contract():
    """法事契约（卷轴）"""
    p = Prop("SM_Contract")
    p.part("Roll", cylinder(0.028, 0.028, 0.26, 10), "M_PaperYellow", t=(0, 0.03, 0), r=(0, 0, 90))
    p.part("KnobA", cylinder(0.035, 0.03, 0.02, 10), "M_WoodDark", t=(-0.14, 0.03, 0), r=(0, 0, 90))
    p.part("KnobB", cylinder(0.035, 0.03, 0.02, 10), "M_WoodDark", t=(0.14, 0.03, 0), r=(0, 0, 90))
    p.part("Unrolled", quad(0.24, 0.2), "M_DocInk", t=(0, 0.015, 0.14), r=(-84, 0, 0))
    return p

def build_blood_contract():
    """血书契约（密室终局铁证）"""
    p = Prop("SM_BloodContract")
    p.part("Paper", quad(0.3, 0.4), "M_DocBlood", t=(0, 0.005, 0), r=(-90, 0, 0))
    p.part("PaperB", quad(0.3, 0.4), "M_DocBlood", t=(0, 0.002, 0.0), r=(-90, 180, 0))
    return p

def build_wedding_half():
    """半张婚书（烧焦边缘）"""
    p = Prop("SM_WeddingHalf")
    p.part("Paper", quad(0.2, 0.28), "M_DocBurn", t=(0, 0.004, 0), r=(-90, 0, 0))
    return p

def build_bed():
    """雕花拔步床：床幔 Curtain 节点（bed_curtain_open）"""
    p = Prop("SM_Bed")
    p.part("Platform", box(2.2, 0.32, 1.5), "M_WoodRed", t=(0, 0.18, 0))
    p.part("Mattress", box(2.0, 0.1, 1.3), "M_ClothWhite", t=(0, 0.38, 0))
    p.part("Pillow", box(0.4, 0.09, 0.25), "M_ClothRed", t=(-0.6, 0.46, -0.3))
    for x, z in ((-1.05, -0.7), (1.05, -0.7), (-1.05, 0.7), (1.05, 0.7)):
        p.part("Post_%d_%d" % (int(x * 100), int(z * 100)), cylinder(0.05, 0.045, 2.0, 10), "M_WoodRed", t=(x, 0.34, z))
        p.part("Finial_%d_%d" % (int(x * 100), int(z * 100)), sphere(0.06, 8), "M_Brass", t=(x, 2.36, z))
    p.part("Canopy", box(2.3, 0.08, 1.6), "M_WoodRed", t=(0, 2.28, 0))
    p.part("Backboard", box(2.2, 1.15, 0.06), "M_WoodRed", t=(0, 1.0, -0.72))
    for i in range(5):
        p.part("Carve%d" % i, box(0.3, 0.4, 0.03), "M_WoodDark", t=(-0.8 + i * 0.4, 1.0, -0.68))
    # 床幔（可掀开）
    p.part("Curtain", quad(1.0, 1.75), "M_Curtain", t=(-0.75, 1.32, 0.68))
    p.part("Curtain2", quad(1.0, 1.75), "M_Curtain", t=(0.75, 1.32, 0.68), parent="Curtain", s=(1, 1, 1))
    p.anim("bed_curtain_open", "Curtain", "translation",
           [(0.0, (-0.75, 1.32, 0.68)), (0.8, (-1.35, 1.32, 0.5)), (1.2, (-1.5, 1.32, 0.2))])
    p.col((0, 1.0, 0), (2.2, 2.0, 1.5))
    return p

def build_dresser():
    """梳妆台：铜镜 + 抽屉"""
    p = Prop("SM_Dresser")
    p.part("Top", box(1.0, 0.06, 0.5), "M_WoodRed", t=(0, 0.78, 0))
    for x, z in ((-0.44, -0.2), (0.44, -0.2), (-0.44, 0.2), (0.44, 0.2)):
        p.part("Leg_%d_%d" % (int(x * 100), int(z * 100)), box(0.07, 0.75, 0.07), "M_WoodDark", t=(x, 0.38, z))
    p.part("BodyF", box(0.9, 0.2, 0.42), "M_WoodDark", t=(0, 0.65, 0))
    p.part("Drawer", box(0.4, 0.14, 0.4), "M_WoodRed", t=(-0.2, 0.66, 0))
    p.part("Knob", sphere(0.02, 8), "M_Brass", t=(-0.2, 0.66, 0.21))
    # 立镜
    p.part("MirrorFrame", annulus(0.24, 0.19, 20), "M_WoodRed", t=(0, 1.35, -0.16), r=(90, 0, 0), s=(0.85, 1.1, 1))
    p.part("MirrorGlass", cylinder(0.21, 0.21, 0.012, 20), "M_BronzeMirror", t=(0, 1.35, -0.16), r=(90, 0, 0), s=(0.85, 1.1, 1))
    p.part("MirrorPost", box(0.06, 0.35, 0.06), "M_WoodDark", t=(0, 0.98, -0.16))
    p.col((0, 0.5, 0), (1.0, 1.0, 0.5))
    return p

def build_jewelry_box():
    """妆奁盒：盒身 + 盖 Lid（八卦锁由引擎挂载到盖上）"""
    p = Prop("SM_JewelryBox")
    p.part("Body", box(0.36, 0.16, 0.24), "M_WoodRed", t=(0, 0.08, 0))
    p.part("Trim", box(0.38, 0.02, 0.26), "M_Brass", t=(0, 0.155, 0))
    p.part("Lid", box(0.37, 0.04, 0.25), "M_WoodRed", t=(0, 0.19, 0))
    p.anim("box_open", "Lid", "translation",
           [(0.0, (0, 0.19, 0)), (0.5, (0, 0.24, 0.1))])
    return p

def build_bookshelf_secret():
    """暗格书架：SecretPart 滑开（secretshelf_slide）"""
    p = Prop("SM_Bookshelf")
    p.part("Back", box(1.8, 2.2, 0.04), "M_WoodDark", t=(0, 1.1, -0.14))
    for x in (-0.88, 0.88):
        p.part("Side_%d" % int(x * 100), box(0.05, 2.2, 0.34), "M_WoodDark", t=(x, 1.1, 0))
    for i, y in enumerate((0.45, 1.05, 1.65)):
        if i < 2:
            p.part("ShelfL%d" % i, box(0.86, 0.04, 0.32), "M_WoodDark", t=(-0.45, y, 0))
        p.part("ShelfR%d" % i, box(0.86, 0.04, 0.32), "M_WoodDark", t=(0.45, y, 0))
    p.part("Top", box(1.8, 0.06, 0.36), "M_WoodRed", t=(0, 2.2, 0))
    # 书本
    r = np.random.default_rng(42)
    for row_i, (y, xs) in enumerate(((0.62, (-0.85, 0.0)), (1.22, (-0.85, 0.0)), (1.82, (-0.85, 0.0)))):
        x = xs[0]
        while x < -0.05:
            w = r.uniform(0.03, 0.06)
            h = r.uniform(0.22, 0.3)
            mat = "M_PaperRed" if r.random() < 0.4 else ("M_DocInk2" if r.random() < 0.5 else "M_WoodDark")
            p.part("BookL%d_%d" % (row_i, int(x * 100)),
                   box(w, h, 0.24), mat, t=(x + w / 2, y + h / 2, 0), parent="SecretPart" if row_i == 1 else None)
            x += w + 0.008
        x = 0.05
        while x < 0.85:
            w = r.uniform(0.03, 0.06)
            h = r.uniform(0.22, 0.3)
            mat = "M_PaperYellow" if r.random() < 0.3 else "M_WoodDark"
            p.part("BookR%d_%d" % (row_i, int(x * 100)), box(w, h, 0.24), mat, t=(x + w / 2, y + h / 2, 0))
            x += w + 0.008
    # 暗格段（中排右侧整段可滑开）
    p.part("SecretPanel", box(0.88, 0.6, 0.05), "M_WoodDark", t=(0.44, 1.35, 0.17), parent="SecretPart")
    p.anim("secretshelf_slide", "SecretPart", "translation",
           [(0.0, (0, 0, 0)), (1.2, (-0.92, 0, 0))])
    p.col((0, 1.1, 0), (1.8, 2.2, 0.36))
    return p

def build_armchair():
    p = Prop("SM_Armchair")
    p.part("Seat", box(0.52, 0.06, 0.48), "M_WoodRed", t=(0, 0.42, 0))
    p.part("Back", box(0.52, 0.6, 0.06), "M_WoodRed", t=(0, 0.75, -0.21))
    for x in (-0.24, 0.24):
        p.part("Arm_%d" % int(x * 100), box(0.06, 0.2, 0.44), "M_WoodRed", t=(x, 0.55, 0))
        p.part("Leg_%d_%d" % (int(x * 100), 18), box(0.05, 0.42, 0.05), "M_WoodDark", t=(x, 0.21, -0.18))
        p.part("LegR_%d_%d" % (int(x * 100), 18), box(0.05, 0.42, 0.05), "M_WoodDark", t=(x, 0.21, 0.18))
    p.part("Cushion", box(0.44, 0.06, 0.4), "M_ClothRed", t=(0, 0.47, 0.02))
    p.col((0, 0.5, 0), (0.55, 1.0, 0.5))
    return p

def build_red_shoes():
    p = Prop("SM_RedShoes")
    for i, x in enumerate((-0.06, 0.06)):
        p.part("Shoe%d" % i, sphere(0.05, 10), "M_ShoeRed", t=(x, 0.045, 0), s=(0.8, 0.7, 2.2))
        p.part("Sole%d" % i, box(0.08, 0.02, 0.24), "M_Black", t=(x, 0.01, 0.01))
    return p

def build_candle():
    p = Prop("SM_Candle")
    p.part("Stick", cylinder(0.022, 0.02, 0.2, 10), "M_PaperWhite", t=(0, 0.1, 0))
    p.part("Wax", cylinder(0.024, 0.018, 0.03, 10), "M_PaperWhite", t=(0, 0.21, 0))
    p.part("Wick", cylinder(0.002, 0.002, 0.02, 4), "M_Black", t=(0, 0.23, 0))
    p.part("Flame", sphere(0.014, 8), "M_Flame", t=(0, 0.26, 0), s=(1, 1.6, 1))
    return p

def build_stone_well():
    """枯井：石圈 + 井架 + 符纸"""
    p = Prop("SM_StoneWell")
    p.part("Ring", lathe([(0.55, 0), (0.62, 0), (0.62, 0.55), (0.55, 0.55)], 20), "M_StoneMoss")
    p.part("Rim", annulus(0.66, 0.5, 20), "M_StoneMoss", t=(0, 0.551, 0))
    p.part("Hole", cylinder(0.5, 0.5, 0.4, 20, cap=False), "M_Black", t=(0, 0.08, 0), r=(180, 0, 0))
    p.part("HoleBottom", plane(1.0, 1.0, uv=1), "M_Black", t=(0, 0.06, 0))
    for x in (-0.7, 0.7):
        p.part("Post%d" % int(x * 10), box(0.1, 1.3, 0.1), "M_WoodDark", t=(x, 0.6, 0))
    p.part("Crossbar", cylinder(0.05, 0.05, 1.6, 8), "M_WoodDark", t=(0, 1.22, 0), r=(0, 0, 90))
    p.part("Axle", cylinder(0.03, 0.03, 0.9, 8), "M_WoodDark", t=(0, 1.1, 0.3), r=(90, 0, 0))
    p.part("Rope", cylinder(0.012, 0.012, 0.6, 5), "M_Bamboo", t=(0, 0.55, 0.3))
    p.part("Bucket", cylinder(0.09, 0.07, 0.12, 10), "M_WoodDark", t=(0, 0.42, 0.3))
    p.part("Talisman", quad(0.18, 0.3), "M_Talisman", t=(0, 0.35, 0.63))
    p.col((0, 0.3, 0), (1.3, 0.6, 1.3))
    return p

def build_spirit_flag():
    """灵幡：竹杆 + 白幡"""
    p = Prop("SM_SpiritFlag")
    p.part("Pole", cylinder(0.015, 0.012, 1.9, 6), "M_Bamboo", t=(0, 0.95, 0))
    p.part("Cloth", quad(0.5, 1.15), "M_Flag", t=(0.26, 1.28, 0))
    p.part("Top", sphere(0.03, 8), "M_Bamboo", t=(0, 1.92, 0))
    return p

def build_bamboo_stack():
    p = Prop("SM_BambooStack")
    for i in range(6):
        p.part("Str%d" % i, cylinder(0.018, 0.015, 2.3, 6), "M_Bamboo",
               t=(0, 0.05 + i * 0.03, 0), r=(0, rng.uniform(0, 180), 90))
    return p

def build_paste_pot():
    p = Prop("SM_PastePot")
    p.part("Pot", lathe([(0.09, 0), (0.11, 0.01), (0.13, 0.09), (0.12, 0.16), (0.10, 0.17)], 14),
           "M_PaperWhite")
    p.part("Paste", cylinder(0.09, 0.09, 0.02, 12), "M_PaperWhite", t=(0, 0.15, 0))
    return p

def build_luopan():
    """八卦罗盘"""
    p = Prop("SM_Luopan")
    p.part("Case", cylinder(0.13, 0.13, 0.035, 20), "M_WoodRed")
    p.part("Dial", cylinder(0.115, 0.115, 0.012, 20), "M_PaperYellow", t=(0, 0.036, 0))
    p.part("Needle", box(0.008, 0.004, 0.16), "M_Brass", t=(0, 0.048, 0))
    p.part("Glass", cylinder(0.115, 0.115, 0.004, 20), "M_BronzeMirror", t=(0, 0.052, 0))
    return p

def build_chair_wood():
    p = Prop("SM_ChairWood")
    p.part("Seat", box(0.44, 0.05, 0.42), "M_WoodDark", t=(0, 0.44, 0))
    p.part("Back", box(0.44, 0.5, 0.04), "M_WoodDark", t=(0, 0.72, -0.19))
    for x, z in ((-0.18, -0.17), (0.18, -0.17), (-0.18, 0.17), (0.18, 0.17)):
        p.part("Leg_%d_%d" % (int(x * 100), int(z * 100)), box(0.05, 0.44, 0.05), "M_WoodDark", t=(x, 0.22, z))
    p.col((0, 0.4, 0), (0.45, 0.8, 0.45))
    return p

def build_dead_rat():
    p = Prop("SM_DeadRat")
    p.part("Body", sphere(0.06, 10), "M_Mold", t=(0, 0.05, 0), s=(1, 0.8, 2.0))
    p.part("Head", sphere(0.045, 8), "M_Mold", t=(0, 0.05, -0.13), s=(1, 0.8, 1.1))
    p.part("Tail", cylinder(0.006, 0.004, 0.16, 5), "M_Black", t=(0, 0.03, 0.16), r=(80, 0, 0))
    for x in (-0.03, 0.03):
        p.part("Ear%d" % int(x * 10), sphere(0.015, 6), "M_Mold", t=(x, 0.09, -0.15))
    return p

def build_offering_plate():
    p = Prop("SM_OfferingPlate")
    p.part("Plate", cylinder(0.15, 0.13, 0.03, 14), "M_PaperWhite")
    for i, (x, y) in enumerate(((-0.05, 0.03), (0.05, 0.03), (0.0, 0.07))):
        p.part("Bun%d" % i, sphere(0.045, 8), "M_Mold", t=(x, 0.05, y), s=(1, 0.7, 1))
    return p

def build_desk_study():
    """书案"""
    p = Prop("SM_DeskStudy")
    p.part("Top", box(1.5, 0.07, 0.7), "M_WoodDark", t=(0, 0.76, 0))
    for x, z in ((-0.68, -0.28), (0.68, -0.28), (-0.68, 0.28), (0.68, 0.28)):
        p.part("Leg_%d_%d" % (int(x * 100), int(z * 100)), box(0.09, 0.72, 0.09), "M_WoodDark", t=(x, 0.38, z))
    p.part("DrawerF", box(1.3, 0.16, 0.04), "M_WoodRed", t=(0, 0.65, 0.33))
    p.col((0, 0.4, 0), (1.5, 0.8, 0.7))
    return p

BUILDERS = {
    # kit
    "wall_brick": build_wall_brick, "wall_wood": build_wall_wood,
    "pillar": build_pillar, "beam": build_beam, "roof_seg": build_roof_seg,
    "floor_stone": build_floor_stone, "floor_wood": build_floor_wood,
    "door": build_door, "window": build_window, "railing": build_railing,
    "step": build_step, "plaque": build_plaque,
    # props
    "paper_figure": build_paper_figure, "paper_head": build_paper_head,
    "bride_ghost": build_bride_ghost, "hand_lantern": build_hand_lantern,
    "hanging_lantern": build_hanging_lantern, "tablet": build_tablet,
    "tablet_rack": build_tablet_rack, "altar_table": build_altar_table,
    "bagua_lock": build_bagua_lock, "bronze_mirror": build_bronze_mirror,
    "mirror_stand": build_mirror_stand, "incense_burner": build_incense_burner,
    "copper_bell": build_copper_bell, "cinnabar_pen": build_cinnabar_pen,
    "fire_starter": build_fire_starter, "jade_pendant": build_jade_pendant,
    "letter": build_letter, "book_red": build_book_red, "book_dark": build_book_dark,
    "contract": build_contract, "blood_contract": build_blood_contract,
    "wedding_half": build_wedding_half, "bed": build_bed, "dresser": build_dresser,
    "jewelry_box": build_jewelry_box, "bookshelf": build_bookshelf_secret,
    "armchair": build_armchair, "red_shoes": build_red_shoes, "candle": build_candle,
    "stone_well": build_stone_well, "spirit_flag": build_spirit_flag,
    "bamboo_stack": build_bamboo_stack, "paste_pot": build_paste_pot,
    "luopan": build_luopan, "chair_wood": build_chair_wood,
    "dead_rat": build_dead_rat, "offering_plate": build_offering_plate,
    "desk_study": build_desk_study,
}


def build_all(out_kit, out_props):
    os.makedirs(out_kit, exist_ok=True)
    os.makedirs(out_props, exist_ok=True)
    kit_names = {"wall_brick", "wall_wood", "pillar", "beam", "roof_seg", "floor_stone",
                 "floor_wood", "door", "window", "railing", "step", "plaque"}
    n = 0
    for name, fn in BUILDERS.items():
        out = os.path.join(out_kit if name in kit_names else out_props, name + ".glb")
        fn().save(out)
        n += 1
    print("[props] 资产完成: %d 个 .glb" % n)


if __name__ == "__main__":
    import sys
    register_materials()
    import texgen
    texgen.build_all(os.path.join(os.path.dirname(__file__), "..", "assets", "tex"))
    build_all("../assets/kit", "../assets/props")
