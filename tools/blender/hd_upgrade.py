# -*- coding: utf-8 -*-
"""
hd_upgrade.py — 资产重制批次①：几何升级（任务书「微倒角/平滑/修正穿插」）
对全部 50 个游戏 .glb 做 Blender 几何处理并导出到独立目录（分批验证后再替换正式资源）：
  1. 导入 glTF；
  2. 碰撞代理（*colonly）不加修饰、原样导出；
  3. 可见网格加 Bevel 修饰符（50° 限角，2 段）——倒角让棱边受光，贴近「微倒角」要求；
  4. 有机件（灯/纸/鬼/玉/铃/炉/烛等）整体平滑着色，建筑硬表面保持平面+倒角；
  5. 以 export_apply=True 应用修饰符导出同名 .glb。
运行：
    blender --background --python hd_upgrade.py -- --in ../assets --out ../assets_hd
"""
import bpy, os, sys

# 有机件：整网格平滑着色
SMOOTH_ALL = {"hand_lantern", "hanging_lantern", "paper_figure", "paper_head",
              "bride_ghost", "jade_pendant", "copper_bell", "incense_burner",
              "candle", "paste_pot", "offering_plate", "luopan", "stone_well",
              "tablet", "red_shoes", "dead_rat", "book_red", "book_dark"}

def get_args():
    argv = sys.argv
    src_in, out = "../assets", "../assets_hd"
    if "--" in argv:
        rest = argv[argv.index("--") + 1:]
        i = 0
        while i < len(rest):
            if rest[i] == "--in" and i + 1 < len(rest):
                src_in = rest[i + 1]; i += 2
            elif rest[i] == "--out" and i + 1 < len(rest):
                out = rest[i + 1]; i += 2
            else:
                i += 1
    return src_in, out

def main():
    src_in, out = get_args()
    manifest = []
    for sub in ("kit", "props"):
        d = os.path.join(src_in, sub)
        files = sorted(f for f in os.listdir(d) if f.endswith(".glb"))
        for f in files:
            name = f[:-4]
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.gltf(filepath=os.path.join(d, f))
            smooth = name in SMOOTH_ALL
            for o in list(bpy.context.scene.objects):
                if o.type != 'MESH':
                    continue
                if "colonly" in o.name or "col" in o.name.lower().split('.'):
                    continue   # 碰撞代理不做修饰
                mod = o.modifiers.new("Bevel", 'BEVEL')
                mod.width = 0.008
                mod.segments = 2
                mod.angle_limit = 0.9   # ~50°，只倒锐棱
                if smooth:
                    for p in o.data.polygons:
                        p.use_smooth = True
            out_glb = os.path.abspath(os.path.join(out, sub, f))
            os.makedirs(os.path.dirname(out_glb), exist_ok=True)
            bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB',
                                      export_yup=True, export_apply=True)
            manifest.append("%s/%s.glb" % (sub, f))
            print("[hd] %s/%s.glb (smooth=%s)" % (sub, f, smooth))
    print("[hd] 完成：%d 个 HD .glb" % len(manifest))

main()
