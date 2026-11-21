# Blender 端资产管线（对应《沈家老宅_3D资产重制任务书》）

本目录实现任务书的 Blender 侧交付。使用 Blender 4.2.3 LTS 验证了导入及保存。

## 游戏内当前模型

运行时从 `assets/kit/` 和 `assets/props/` 读取模型。`assets_hd/` 是上一批几何升级的输入。当前批次重做了两类灯笼、纸人、纸人头和红衣鬼影，并为建筑和道具增加了各自的结构及材质细节。

在项目根目录执行，先将资产导出到单独的目录。生成器需要 NumPy 和 Pillow。

```sh
python tools/refine_models.py --output ../shenjia-art-preview
blender --background --python tools/blender/import_blend_src.py -- --in ../shenjia-art-preview --out ../shenjia-blend-preview
```

正式版可编辑文件在 `blender_src/kit/` 与 `blender_src/props/`。清单中的 `blend` 路径相对于清单所在目录。替换 GLB 后在 Godot 查看实际画面，并验证资产审计和交互回归。本批次的验收截图见 `docs/screenshots/art_pass/`。

## 三条可重复执行的管线

### 1. 全量 .blend 源文件（50 个，任务书交付项①）
把游戏内正在运行的 50 个同名 .glb 逐个导入 Blender，生成**可编辑源文件**，
供美术在此基础上手工重制（保留节点名 / 枢轴 / 动画）：

```bash
blender.exe --background --python import_blend_src.py -- --in assets --out blender_src
```

产出：`blender_src/kit/*.blend`（12）+ `blender_src/props/*.blend`（38）+
`blender_src/asset_manifest.json`（每资产的对象数/网格数/动画轨道清单，10 个带动画资产全部入档）。

### 2. 原生高模批次（先做样板：任务书第二节）
`build_kit.py` / `build_props.py` 以 bmesh+程序材质直接建模并导出高模 .glb
（Blender 4.2 已验证通过，含程序化青苔/污渍材质图、门扇合页动画）：

```bash
blender.exe --background --python build_kit.py   -- --out blender_src/hd_kit    # 9 个建筑模块
blender.exe --background --python build_props.py -- --out blender_src/hd_props   # 6 个样板道具
```

产出 `blender_src/hd_*/**.glb`（油灯/纸人/供桌/门/青砖墙/木地板样板已覆盖任务书验收路线）。

### 3. 热替换回游戏
验证过的 .glb 覆盖 `assets/kit|props/` 同名文件 → `Godot --headless --path . --import` →
运行 `tests/asset_audit.tscn` 确认接口（节点/动画/碰撞）未破坏，再进游戏验收画面。

## 接口合规审计

`tests/asset_audit.tscn`（headless 可跑）对照任务书第六节接口表逐项机检：
50 个 GLB 可加载、关键节点（DoorLeaf/Flame/Head/Face/Mirror/Incense×3/Ember×3/Clapper/Lid/SecretPart/Drawer/Curtain）、
动画轨道（door_open/close、lantern_sway、turn_head、drawer_open、tablet_pickup、bell_ring、box_open、secretshelf_slide、bed_curtain_open）、
门扇独立碰撞、建筑模块 -colonly 代理、运行时挂载一致性。当前 **97 项全部通过**。

## Blender 4.2 API 适配记录
- Principled BSDF 输出口名为 `BSDF`（非 "Base Color"）；程序材质图不得形成反馈环（glTF 导出器会递归爆栈）。
- 污渍/青苔材质采用无环接法：Noise → Mix(A=底色, B=污渍色) → BaseColor。


## 使用方法

```bash
# Kit 模块（墙/柱/檐/门/窗/栏/地面）
blender --background --python build_kit.py -- --out ../assets/kit_hd

# 核心道具（纸人/油灯/牌位/八卦锁/铜镜/供桌）
blender --background --python build_props.py -- --out ../assets/props_hd
```

## 资产规范（与 GDD 1.1 节一致）

| 项 | 规范 |
|---|---|
| 单位 | 米制（+Y 朝前，glTF 导出自动 Y-up） |
| 模块化 | 墙 4m×3m×0.24m，柱 Ø0.3×3m，原点在底面中心，1m 网格对齐 |
| PBR | Principled BSDF；青苔/斑驳用 Noise+ColorRamp 程序化混合，无需外部贴图 |
| 碰撞 | `-colonly` 后缀（纯碰撞不渲染）、`-col`（可视+碰撞）|
| 动画轨道 | `door_open/door_close`（绕合页 -100°）、`drawer_open`、`turn_head`（纸人转头 92°）|
| 导出 | glTF 2.0 `.glb`，仅导出选中层级 |

## 已实现

- `build_kit.py`：wall_brick（砖缝凹槽）、wall_wood、pillar（柱础+柱帽）、roof_seg
  （瓦垄+ fascia）、door（门框+门扇双导出、合页枢轴、开门动画）、window（万字纹窗棂）、
  floor_stone、railing
- `build_props.py`：paper_figure（头/身/手分件 + turn_head 动画）、hand_lantern
  （自发光火焰）、tablet、bagua_lock（8 卦槽位）、bronze_mirror（镜面金属度 0.95）、
  altar_table（暗格抽屉 + drawer_open 动画）

## 热替换注意事项

1. 导出的 glb 根节点名需与现有资产一致（脚本已保证）；
2. 动画轨道名一致（`door_open` / `turn_head` / `drawer_open`），Godot 端 `AnimationPlayer.play()` 无需改动；
3. 道具的动画目标节点名（`DoorLeaf` / `Head` / `Drawer` / `Flame`）必须保留——WorldBuilder 运行时会按名查找；
4. 替换后执行一次 `godot --headless --import` 重建导入缓存即可。
