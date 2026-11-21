# -*- coding: utf-8 -*-
"""build_all.py — 一键生成全部资产：贴图 → 道具/kit .glb → 音效"""
import os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

def main():
    t0 = time.time()
    import texgen
    texgen.build_all(os.path.join(ROOT, "assets", "tex"))
    import props
    props.register_materials()
    props.build_all(os.path.join(ROOT, "assets", "kit"), os.path.join(ROOT, "assets", "props"))
    import sfxgen
    sfxgen.build_all(os.path.join(ROOT, "assets", "sfx"))
    print("[build_all] 总耗时 %.1fs" % (time.time() - t0))

if __name__ == "__main__":
    main()
