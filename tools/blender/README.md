# Blender 端高模重制管线

本目录是 **Blender + Godot 4 资产协作管线** 的 Blender 侧实现。当前游戏直接使用
`tools/build_all.py`（纯 Python glTF 2.0 生成器）产出的 `.glb` 运行；当你安装了
Blender 后，可用本管线产出**更高模数、带倒角与程序化脏迹材质**的同名资产，直接
**热替换** `assets/kit/` 与 `assets/props/` 下的同名文件，无需改动任何 Godot 代码。

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
