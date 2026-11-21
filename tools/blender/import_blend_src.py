# -*- coding: utf-8 -*-
"""
import_blend_src.py — 把项目全部 50 个游戏 .glb 导入 Blender，生成可编辑 .blend 源文件
《沈家老宅》资产重制任务书 交付项：可编辑 .blend + 可重复执行的导出脚本

运行（Blender 4.2+，命令行）：
    blender --background --python import_blend_src.py -- --in ../assets --out ../blender_src
对 assets/kit/*.glb 与 assets/props/*.glb 逐个：
    1. 清空场景导入 glTF；
    2. 以资产文件名重命名根对象；
    3. 保存同名 .blend 到 --out 目录；
    4. 输出清单（对象数 / 网格数 / 动画数），供《资产重制任务书》核对。
后续美术可在 .blend 中直接重制，再经 tools/blender/build_*.py 流程导出同名 .glb 热替换。
"""
import bpy, os, sys, json

def get_args():
    argv = sys.argv
    src_in, out = "../assets", "../blender_src"
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

def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def import_glb(path):
    bpy.ops.import_scene.gltf(filepath=path)

def save_blend(path):
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)

def main():
    src_in, out = get_args()
    os.makedirs(out, exist_ok=True)
    manifest = []
    for sub in ("kit", "props"):
        d = os.path.join(src_in, sub)
        if not os.path.isdir(d):
            continue
        files = sorted(f for f in os.listdir(d) if f.endswith(".glb"))
        for f in files:
            name = f[:-4]
            clean_scene()
            import_glb(os.path.join(d, f))
            objs = [o for o in bpy.context.scene.objects]
            meshes = [o for o in objs if o.type == 'MESH']
            # 动画统计（含导入的 Action）
            anims = set()
            for o in objs:
                if o.animation_data and o.animation_data.action:
                    anims.add(o.animation_data.action.name)
                for tc in getattr(o.animation_data, "nla_tracks", []) or []:
                    for s in tc.strips:
                        anims.add(s.action.name if s.action else "")
            anims.discard("")
            blend_path = os.path.abspath(os.path.join(out, sub, name + ".blend"))
            os.makedirs(os.path.dirname(blend_path), exist_ok=True)
            save_blend(blend_path)
            manifest.append({
                "asset": "%s/%s.glb" % (sub, f),
                "blend": os.path.relpath(blend_path, out).replace(os.sep, "/"),
                "objects": len(objs),
                "meshes": len(meshes),
                "animations": sorted(a for a in anims if "Armature" not in a),
            })
            print("[blend-src] %-34s objects=%-3d meshes=%-3d anims=%s"
                  % (sub + "/" + f, len(objs), len(meshes), sorted(anims)))
    mpath = os.path.join(out, "asset_manifest.json")
    with open(mpath, "w", encoding="utf-8") as fp:
        json.dump(manifest, fp, ensure_ascii=False, indent=2)
    print("[blend-src] 完成：%d 个 .blend 源文件 → %s" % (len(manifest), mpath))

main()
