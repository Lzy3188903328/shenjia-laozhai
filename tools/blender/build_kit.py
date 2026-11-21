# -*- coding: utf-8 -*-
"""
build_kit.py — Blender 端模块化古宅 Kit 高模重制管线（bpy 2.9+ / 3.x / 4.x）
《沈家老宅》Blender + Godot 4 资产协作规范实现

运行方式（Blender 命令行，无需打开界面）：
    blender --background --python build_kit.py -- --out ../assets/kit_hd

规范要点（与 docs/GDD 第 1.1 节一致）：
  * 模块化：青砖墙 / 雕花木门 / 窗棂 / 廊柱 / 屋檐，1m 网格对齐，原点在模块底面中心
  * PBR： Principled BSDF（BaseColor / Roughness / Normal），程序化生成污渍/青苔/斑驳贴图
  * 碰撞：命名 `-col`（静态 trimesh）/ `-colonly`（纯碰撞）；Godot 导入自动映射
  * 动画：门扇 door_open / door_close 轨道（绕合页枢轴 -100°）
  * 导出：glTF 2.0 (.glb)，+Y 朝前，米制
"""
import bpy, os, sys, math, bmesh
from mathutils import Vector, Euler

# ---------------------------------------------------------------- 参数解析
def get_args():
    argv = sys.argv
    out = "../assets/kit_hd"
    if "--" in argv:
        rest = argv[argv.index("--") + 1:]
        if len(rest) >= 2 and rest[0] == "--out":
            out = rest[1]
    return out

# ---------------------------------------------------------------- 场景清理
def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0

# ---------------------------------------------------------------- 材质
def _new_mat(name, base, rough=0.75, metal=0.0, spec=0.3):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*base, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = spec
    return m

def _add_noise_grime(mat, base=(0.3, 0.3, 0.3, 1), color_a=(0.5, 0.5, 0.5, 1), scale=6.0, strength=0.35):
    """程序化污渍/青苔：Noise → Mix(A=原底色, B=污渍色, Factor=强度) → BaseColor（无环）"""
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].color = color_a
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = 'RGBA'
    mix.blend_type = 'MIX'
    mix.inputs["A"].default_value = base
    mix.inputs["Factor"].default_value = strength
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])

def make_materials():
    mats = {
        "M_Brick":     _new_mat("M_Brick", (0.30, 0.33, 0.30), 0.92),
        "M_WoodDark":  _new_mat("M_WoodDark", (0.10, 0.065, 0.04), 0.78),
        "M_WoodRed":   _new_mat("M_WoodRed", (0.30, 0.045, 0.04), 0.6),
        "M_Stone":     _new_mat("M_Stone", (0.30, 0.32, 0.31), 0.92),
        "M_Tile":      _new_mat("M_Tile", (0.14, 0.155, 0.17), 0.85),
        "M_Bronze":    _new_mat("M_Bronze", (0.45, 0.34, 0.18), 0.35, metal=0.85),
        "M_Brass":     _new_mat("M_Brass", (0.72, 0.55, 0.22), 0.30, metal=0.9),
        "M_Black":     _new_mat("M_Black", (0.02, 0.02, 0.02), 0.95),
    }
    # 青苔爬痕
    _add_noise_grime(mats["M_Brick"], base=(0.30, 0.33, 0.30, 1), color_a=(0.16, 0.30, 0.14, 1), scale=5.0, strength=0.45)
    _add_noise_grime(mats["M_Stone"], base=(0.30, 0.32, 0.31, 1), color_a=(0.14, 0.27, 0.12, 1), scale=4.0, strength=0.4)
    _add_noise_grime(mats["M_Tile"], base=(0.14, 0.155, 0.17, 1), color_a=(0.13, 0.22, 0.11, 1), scale=6.0, strength=0.35)
    # 红漆斑驳
    _add_noise_grime(mats["M_WoodRed"], base=(0.30, 0.045, 0.04, 1), color_a=(0.10, 0.06, 0.035, 1), scale=9.0, strength=0.55)
    return mats

# ---------------------------------------------------------------- 建模工具
def _obj_from_bmesh(bm, name, mat):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj

def make_box(name, size, mat, loc=(0, 0, 0), bevel=0.012):
    """居中盒体 + 微倒角（防 Godot 高光闪烁）"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect='EDGES')
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    obj = _obj_from_bmesh(bm, name, mat)
    obj.location = loc
    return obj

def make_cyl(name, r, depth, mat, loc=(0, 0, 0), verts=24):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, radius1=r, radius2=r, depth=depth, segments=verts)
    obj = _obj_from_bmesh(bm, name, mat)
    obj.location = loc
    return obj

def join(objs, name):
    """合并为单物体（导出 draw call 更少）"""
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]

def add_collision(obj, kind="-col"):
    """碰撞代理：复制简化包围盒，命名规范由 Godot 导入器识别"""
    col = obj.copy()
    col.data = obj.data.copy()
    col.name = obj.name + kind
    bpy.context.collection.objects.link(col)
    # 用收缩包裹的粗略盒（trimesh 由 Godot 生成）
    for mod in col.modifiers:
        col.modifiers.remove(mod)
    dec = col.modifiers.new("Decimate", 'DECIMATE')
    dec.ratio = 0.25
    col.display_type = 'WIRE'
    col.hide_render = True
    return col

def add_door_animation(root, leaf):
    """门扇开合轨道：door_open（绕合页 -100°）/ door_close"""
    ad = bpy.data.actions.new("door_open")
    leaf.rotation_mode = 'XYZ'
    leaf_data = leaf.id_data.animation_data_create()
    leaf_data.action = ad
    fc = ad.fcurves.new(data_path="rotation_euler", index=1)
    # 关键帧（秒, 弧度）
    for t, deg in [(0.0, 0.0), (0.6, -55.0), (1.1, -100.0)]:
        fc.keyframe_points.insert(t, math.radians(deg))
    for kp in fc.keyframe_points:
        kp.interpolation = 'BEZIER'

def export_glb(root_obj, path):
    bpy.ops.object.select_all(action='DESELECT')
    root_obj.select_set(True)
    bpy.context.view_layer.objects.active = root_obj
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB',
                              export_yup=True, export_apply=True,
                              use_selection=True, export_animations=True)

# ---------------------------------------------------------------- Kit 模块
def build_wall_brick(mats):
    root = make_box("SM_WallBrick", (4.0, 0.24, 3.0), mats["M_Brick"], loc=(0, 0, 1.5))
    # 砖缝凹槽（低模细节）
    for i in range(1, 10):
        groove = make_box("groove", (3.98, 0.26, 0.012), mats["M_Brick"], loc=(0, 0, i * 0.3))
        root = join([root, groove], "SM_WallBrick")
    add_collision(root, "-colonly")
    export_glb(root, os.path.join(OUT, "wall_brick.glb"))

def build_wall_wood(mats):
    panel = make_box("panel", (4.0, 0.10, 3.0), mats["M_WoodDark"], loc=(0, 0, 1.5))
    parts = [panel]
    parts.append(make_box("ft", (4.1, 0.16, 0.16), mats["M_WoodRed"], loc=(0, 0, 3.0)))
    parts.append(make_box("fb", (4.1, 0.14, 0.18), mats["M_WoodRed"], loc=(0, 0, 0.07)))
    for x in (-1.95, 1.95):
        parts.append(make_box("fs", (0.16, 0.16, 3.1), mats["M_WoodRed"], loc=(x, 0, 1.5)))
    for i in range(4):
        parts.append(make_box("div", (0.05, 0.06, 2.7), mats["M_WoodRed"], loc=(-1.5 + i, 0.03, 1.5)))
    root = join(parts, "SM_WallWood")
    add_collision(root, "-colonly")
    export_glb(root, os.path.join(OUT, "wall_wood.glb"))

def build_pillar(mats):
    shaft = make_cyl("shaft", 0.14, 2.9, mats["M_WoodRed"], loc=(0, 0, 1.57), verts=20)
    base = make_box("base", (0.42, 0.42, 0.14), mats["M_Stone"], loc=(0, 0, 0.07))
    cap = make_cyl("cap", 0.16, 0.12, mats["M_WoodDark"], loc=(0, 0, 3.06), verts=20)
    root = join([shaft, base, cap], "SM_Pillar")
    add_collision(root, "-colonly")
    export_glb(root, os.path.join(OUT, "pillar.glb"))

def build_roof_seg(mats):
    slab = make_box("slab", (4.6, 2.8, 0.12), mats["M_Tile"], loc=(0, 0, 0))
    # 瓦垄
    for i in range(12):
        ridge = make_box("ridge", (4.6, 0.06, 0.05), mats["M_Tile"], loc=(0, -1.32 + i * 0.24, 0.08))
        slab = join([slab, ridge], "slab")
    fascia = make_box("fascia", (4.7, 0.1, 0.18), mats["M_WoodRed"], loc=(0, 1.4, -0.05))
    root = join([slab, fascia], "SM_RoofSeg")
    export_glb(root, os.path.join(OUT, "roof_seg.glb"))

def build_door(mats):
    # 门框
    parts = [
        make_box("jambL", (0.16, 0.22, 2.3), mats["M_WoodRed"], loc=(-0.63, 0, 1.15)),
        make_box("jambR", (0.16, 0.22, 2.3), mats["M_WoodRed"], loc=(0.63, 0, 1.15)),
        make_box("lintel", (1.42, 0.24, 0.22), mats["M_WoodRed"], loc=(0, 0, 2.3)),
    ]
    frame = join(parts, "DoorFrame")
    add_collision(frame, "-colonly")
    # 门扇（枢轴在合页 x=-0.55）
    leaf_parts = [make_box("leaf", (1.06, 0.06, 2.06), mats["M_WoodRed"], loc=(0.55, 0, 1.03))]
    for i, y in enumerate((0.5, 1.15, 1.75)):
        leaf_parts.append(make_box("carve%d" % i, (0.7, 0.03, 0.5), mats["M_WoodDark"],
                                   loc=(0.55, 0.045, y)))
    leaf = join(leaf_parts, "DoorLeaf")
    leaf.location = (-0.55, 0, 0)
    leaf.rotation_euler = Euler((0, 0, 0))
    # 门扇碰撞（随动画跟随）
    leaf_col = make_box("DoorLeaf-colonly", (1.06, 0.08, 2.06), mats["M_Black"], loc=(0.55, 0, 1.03))
    leaf_col.parent = leaf
    leaf_col.hide_render = True
    add_door_animation("SM_Door", leaf)
    export_glb(frame, os.path.join(OUT, "door_frame.glb"))
    export_glb(leaf, os.path.join(OUT, "door_leaf.glb"))

def build_window(mats):
    parts = [make_box("f", (1.24, 0.1, 1.24), mats["M_WoodRed"], loc=(0, 0, 1.5))]
    root = join(parts, "SM_Window")
    # 万字纹窗棂（细条阵列）
    bars = []
    n = 8
    for k in range(1, n):
        bars.append(make_box("vb%d" % k, (0.035, 0.06, 1.1), mats["M_WoodRed"],
                             loc=(-0.55 + k * 1.1 / n, 0.04, 1.5)))
        bars.append(make_box("hb%d" % k, (1.1, 0.06, 0.035), mats["M_WoodRed"],
                             loc=(0, 0.04, 0.95 + k * 1.1 / n)))
    root = join([root] + bars, "SM_Window")
    export_glb(root, os.path.join(OUT, "window.glb"))

def build_floor_stone(mats):
    root = make_box("SM_FloorStone", (4.0, 4.0, 0.1), mats["M_Stone"], loc=(0, 0, -0.05))
    for i in range(1, 4):
        gap = make_box("gap%d" % i, (3.99, 0.02, 0.02), mats["M_Stone"], loc=(0, -2 + i, 0.005))
        root = join([root, gap], "SM_FloorStone")
    add_collision(root, "-colonly")
    export_glb(root, os.path.join(OUT, "floor_stone.glb"))

def build_railing(mats):
    parts = [
        make_box("top", (2.0, 0.08, 0.08), mats["M_WoodRed"], loc=(0, 0, 0.9)),
        make_box("bot", (2.0, 0.06, 0.06), mats["M_WoodDark"], loc=(0, 0, 0.18)),
    ]
    for i in range(6):
        parts.append(make_box("bar%d" % i, (0.06, 0.06, 0.75), mats["M_WoodRed"],
                              loc=(-0.85 + i * 0.34, 0, 0.5)))
    root = join(parts, "SM_Railing")
    add_collision(root, "-colonly")
    export_glb(root, os.path.join(OUT, "railing.glb"))

# ---------------------------------------------------------------- 主流程
def main():
    global OUT
    OUT = get_args()
    os.makedirs(OUT, exist_ok=True)
    clean_scene()
    mats = make_materials()
    build_wall_brick(mats)
    clean_scene(); mats = make_materials()
    build_wall_wood(mats)
    clean_scene(); mats = make_materials()
    build_pillar(mats)
    clean_scene(); mats = make_materials()
    build_roof_seg(mats)
    clean_scene(); mats = make_materials()
    build_door(mats)
    clean_scene(); mats = make_materials()
    build_window(mats)
    clean_scene(); mats = make_materials()
    build_floor_stone(mats)
    clean_scene(); mats = make_materials()
    build_railing(mats)
    print("[blender] Kit 高模导出完成 →", OUT)

if __name__ == "__main__":
    main()
