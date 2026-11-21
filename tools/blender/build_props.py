# -*- coding: utf-8 -*-
"""
build_props.py — Blender 端核心民俗道具高模管线（纸人 / 油灯 / 牌位 / 八卦锁 / 铜镜 / 供桌）
《沈家老宅》：PBR + 动画轨道 + 碰撞命名，产出与 Godot 侧同名 .glb（可整体热替换 assets/props/）

运行：blender --background --python build_props.py -- --out ../assets/props_hd
"""
import bpy, os, sys, math, bmesh
from mathutils import Euler

def get_args():
    argv = sys.argv
    out = "../assets/props_hd"
    if "--" in argv:
        rest = argv[argv.index("--") + 1:]
        if len(rest) >= 2 and rest[0] == "--out":
            out = rest[1]
    return out

OUT = "../assets/props_hd"

def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def _mat(name, base, rough=0.8, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*base, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m

def _box(name, size, mat, loc=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh); bm.free()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    o.location = loc
    return o

def _cyl(name, r0, r1, depth, mat, loc=(0, 0, 0), verts=24):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, radius1=r0, radius2=r1, depth=depth, segments=verts)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh); bm.free()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    o.location = loc
    return o

def _sphere(name, r, mat, loc=(0, 0, 0), segs=24):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2, radius=r)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh); bm.free()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    o.location = loc
    return o

def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]

def export(root, path, anims=True):
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_yup=True,
                              use_selection=True, export_animations=anims)

# ---------------------------------------------------------- 纸人（SK_PaperFigure）
def build_paper_figure():
    clean_scene()
    m_cloth = _mat("M_ClothWhite", (0.78, 0.74, 0.66), 0.9)
    m_face = _mat("M_Face", (0.88, 0.85, 0.76), 0.92)
    m_bamboo = _mat("M_Bamboo", (0.5, 0.45, 0.25), 0.8)
    base = _cyl("Base", 0.26, 0.24, 0.08, m_bamboo, loc=(0, 0, 0.04))
    body = _cyl("Body", 0.24, 0.20, 1.16, m_cloth, loc=(0, 0, 0.66), verts=20)
    for side in (-1, 1):
        arm = _cyl("Arm%d" % side, 0.03, 0.025, 0.52, m_cloth,
                   loc=(side * 0.3, 0, 1.08))
        arm.rotation_euler = Euler((0, 0, math.radians(side * 12)))
        hand = _sphere("Hand%d" % side, 0.045, m_cloth, loc=(side * 0.38, 0, 0.82))
    # 头（独立枢轴 → turn_head 动画）
    head = _sphere("Head", 0.14, m_cloth, loc=(0, 0, 1.44), segs=20)
    head.scale = (1, 1.15, 1)
    face = _box("Face", (0.2, 0.005, 0.24), m_face, loc=(0, 0.13, 1.44))
    face.parent = head
    root = join([base, body], "SM_PaperFigure")
    # turn_head 轨道
    ad = bpy.data.actions.new("turn_head")
    head.animation_data_create()
    head.animation_data.action = ad
    fc = ad.fcurves.new(data_path="rotation_euler", index=2)
    for t, deg in [(0.0, 0.0), (0.8, 92.0)]:
        fc.keyframe_points.insert(t, math.radians(deg))
    export(root, os.path.join(OUT, "paper_figure.glb"))

# ---------------------------------------------------------- 手持油灯
def build_hand_lantern():
    clean_scene()
    m_red = _mat("M_LanternRed", (0.55, 0.08, 0.06), 0.7)
    m_wood = _mat("M_WoodDark", (0.1, 0.06, 0.04), 0.8)
    m_flame = _mat("M_Flame", (1.0, 0.62, 0.18), 1.0)
    m_flame.use_nodes = True
    b = m_flame.node_tree.nodes["Principled BSDF"]
    b.inputs["Emission Color"].default_value = (1.0, 0.5, 0.12, 1)
    if "Emission Strength" in b.inputs:
        b.inputs["Emission Strength"].default_value = 6.0
    body = _cyl("Body", 0.11, 0.11, 0.16, m_red, loc=(0, 0, 0.11), verts=16)
    cap_t = _cyl("CapT", 0.06, 0.05, 0.03, m_wood, loc=(0, 0, 0.205))
    cap_b = _cyl("CapB", 0.05, 0.06, 0.03, m_wood, loc=(0, 0, 0.015))
    flame = _sphere("Flame", 0.035, m_flame, loc=(0, 0, 0.11))
    root = join([body, cap_t, cap_b], "SM_HandLantern")
    export(root, os.path.join(OUT, "hand_lantern.glb"), anims=False)

# ---------------------------------------------------------- 牌位
def build_tablet():
    clean_scene()
    m_wood = _mat("M_WoodRed", (0.3, 0.045, 0.04), 0.6)
    m_paper = _mat("M_PaperYellow", (0.86, 0.79, 0.6), 0.9)
    body = _box("Body", (0.11, 0.022, 0.28), m_wood, loc=(0, 0, 0.14))
    paper = _box("FacePaper", (0.075, 0.004, 0.17), m_paper, loc=(0, 0.013, 0.13))
    root = join([body, paper], "SM_Tablet")
    export(root, os.path.join(OUT, "tablet.glb"), anims=False)

# ---------------------------------------------------------- 八卦锁
def build_bagua_lock():
    clean_scene()
    m_brass = _mat("M_Brass", (0.72, 0.55, 0.22), 0.3, metal=0.9)
    m_iron = _mat("M_Iron", (0.16, 0.16, 0.17), 0.5, metal=0.7)
    base = _cyl("Base", 0.18, 0.18, 0.03, m_brass, loc=(0, 0, 0.015), verts=32)
    ring = _cyl("Ring", 0.145, 0.145, 0.012, m_brass, loc=(0, 0, 0.036), verts=32)
    for i in range(8):
        a = 2 * math.pi * i / 8
        slot = _box("Slot%d" % i, (0.055, 0.035, 0.014), m_iron,
                    loc=(0.125 * math.sin(a), 0.125 * math.cos(a), 0.05))
        slot.rotation_euler = Euler((0, 0, -a))
        slot.parent = ring
    knob = _cyl("Knob", 0.055, 0.05, 0.045, m_brass, loc=(0, 0, 0.062), verts=16)
    root = join([base, knob], "SM_BaguaLock")
    export(root, os.path.join(OUT, "bagua_lock.glb"), anims=False)

# ---------------------------------------------------------- 铜镜
def build_bronze_mirror():
    clean_scene()
    m_mirror = _mat("M_BronzeMirror", (0.62, 0.55, 0.4), 0.12, metal=0.95)
    m_bronze = _mat("M_Bronze", (0.45, 0.34, 0.18), 0.35, metal=0.85)
    m_wood = _mat("M_WoodRed", (0.3, 0.045, 0.04), 0.6)
    disc = _cyl("Disc", 0.13, 0.13, 0.014, m_mirror, loc=(0, 0, 0), verts=28)
    disc.rotation_euler = Euler((math.radians(90), 0, 0))
    rim = _cyl("Rim", 0.145, 0.145, 0.02, m_bronze, loc=(0, 0, 0), verts=28)
    rim.rotation_euler = Euler((math.radians(90), 0, 0))
    handle = _cyl("Handle", 0.018, 0.014, 0.11, m_wood, loc=(0, -0.17, 0))
    root = join([disc, rim, handle], "SM_BronzeMirror")
    export(root, os.path.join(OUT, "bronze_mirror.glb"), anims=False)

# ---------------------------------------------------------- 供桌
def build_altar_table():
    clean_scene()
    m_red = _mat("M_WoodRed", (0.3, 0.045, 0.04), 0.6)
    m_dark = _mat("M_WoodDark", (0.1, 0.06, 0.04), 0.78)
    top = _box("Top", (2.2, 0.9, 0.09), m_red, loc=(0, 0, 0.86))
    parts = [top]
    for x, y in ((-1.0, -0.38), (1.0, -0.38), (-1.0, 0.38), (1.0, 0.38)):
        parts.append(_box("Leg%d%d" % (int(x * 10), int(y * 10)),
                          (0.12, 0.12, 0.82), m_dark, loc=(x, y, 0.41)))
    parts.append(_box("ApronF", (2.1, 0.04, 0.22), m_dark, loc=(0, 0.42, 0.72)))
    drawer = _box("Drawer", (0.56, 0.4, 0.16), m_dark, loc=(0, 0.18, 0.6))
    drawer_face = _box("DrawerFace", (0.6, 0.03, 0.2), m_red, loc=(0, 0.4, 0.6))
    drawer_face.parent = drawer
    root = join(parts, "SM_AltarTable")
    # drawer_open 轨道（沿 -Y 前拉，供桌面向 -Y 时）
    ad = bpy.data.actions.new("drawer_open")
    drawer.animation_data_create()
    drawer.animation_data.action = ad
    fc = ad.fcurves.new(data_path="location", index=1)
    for t, y in [(0.0, 0.18), (0.7, 0.48)]:
        fc.keyframe_points.insert(t, y)
    export(root, os.path.join(OUT, "altar_table.glb"))

# ---------------------------------------------------------- 主流程
def main():
    global OUT
    OUT = get_args()
    os.makedirs(OUT, exist_ok=True)
    build_paper_figure()
    build_hand_lantern()
    build_tablet()
    build_bagua_lock()
    build_bronze_mirror()
    build_altar_table()
    print("[blender] 道具高模导出完成 →", OUT)

if __name__ == "__main__":
    main()
