# 资产管线与 Blender ↔ Godot 协作规范
## 《沈家老宅》技术管线实现说明（对应 GDD 第一节）

---

## 1. 双轨资产管线

本项目实现了**两条并行、可热替换**的资产管线：

| 管线 | 工具 | 产出 | 状态 |
|---|---|---|---|
| **A · 程序化管线**（默认运行） | `tools/build_all.py`（纯 Python，无外部依赖） | `assets/` 下 31 张贴图 + 50 个 .glb + 34 个 WAV | ✅ 已生成并验证 |
| **B · Blender 高模管线**（重制升级） | `tools/blender/build_kit.py` / `build_props.py`（bpy 脚本） | 同名 .glb（含倒角/程序化脏迹材质/动画） | 🔧 安装 Blender 后可用 |

两条管线遵守**同一套命名/层级/动画规范**，B 的产物覆盖 A 的同名文件后，
执行 `Godot --headless --import` 即完成热替换，**Godot 端代码零改动**。

## 2. glTF 2.0 (.glb) 导出规范

自研写入器 `tools/glblib.py`（约 500 行纯 Python）实现了完整的 GLB 二进制容器：

- **几何**：POSITION / NORMAL / TEXCOORD_0 accessor + UNSIGNED_INT 索引，4 字节对齐 bufferView
- **贴图**：PNG 以 bufferView 内嵌（mimeType image/png），Godot 导入时自动解包
- **材质**：pbrMetallicRoughness（baseColorTexture / metallicFactor / roughnessFactor）、
  `alphaMode MASK`（窗棂镂空）、`alphaMode BLEND`（床幔/盖头）、emissiveFactor（灯火/鬼火）
- **层级**：命名节点树（`DoorLeaf`、`Head`、`Drawer`、`Flame`…），Godot 运行时按名查找驱动
- **动画**：rotation/translation 关键帧轨道（LINEAR 插值，四元数旋转）——
  `door_open` / `door_close` / `turn_head` / `drawer_open` / `lantern_sway` /
  `secretshelf_slide` / `bed_curtain_open` / `tablet_pickup` / `bell_ring` / `box_open`
- **碰撞命名**：`<名称>-colonly` → Godot 导入为 StaticBody3D + CollisionShape3D（不渲染）；
  门扇的碰撞代理挂在 `DoorLeaf` 之下，**随开门动画自动跟随**

### 图元库（glblib 内置，供道具构建）

`box / plane / quad / cylinder(圆台) / lathe(旋转成型) / sphere / annulus(圆环) /
prism(多边形挤出+耳切三角化)`——所有道具由此组合，例如：
纸人 = lathe 身体 + sphere 头 + quad 面具 + cylinder 手臂；铜镜 = cylinder 镜盘 + annulus 錽口 + cylinder 镜柄。

## 3. 程序化 PBR 贴图（tools/texgen.py，numpy 实现）

31 张 256–512px PNG，无外部素材依赖：

| 类别 | 贴图 | 技法 |
|---|---|---|
| 木作 | t_wood_dark / t_wood_red / t_wood_floor / t_bamboo | 正弦翘曲木纹 + fbm 污渍；红漆=红漆层×磨损遮罩×木底 |
| 砖石 | t_brick / t_stone / t_stone_moss / t_tile | 错缝砖排+灰缝+底部青苔爬痕（高度加权遮罩） |
| 纸质 | t_paper_white / t_paper_yellow / t_talisman / t_doc_ink / t_doc_blood / t_doc_burn | 纤维噪声 + 泛黄边缘 + 朱砂符笔画/竖排墨迹/圆印/烧焦渐变 |
| 布料 | t_cloth_white / t_cloth_red / t_flag / t_shoe_red | 平织明暗 + 折痕 fbm + 金线团花 |
| 面具 | t_face_smile / t_face_noeye / t_face_eyed / t_face_red | 参数化五官（无眼纸人 = 只有点睛前的微笑）——「似笑非笑」核心恐怖资产 |
| 金属 | t_bronze / t_iron / t_lantern_red | 铜绿 verdigris 斑块 / 锈蚀 / 灯笼竖骨 |

## 4. 程序化音效（tools/sfxgen.py，44.1kHz 16bit WAV）

34 个音频，全部合成：环境循环（雨/风/房间底噪/火盆/鬼息）、惊吓单音（门砰/抽屉/鼠叫/
唢呐长短/二胡滑音/更夫梆子/铜铃/贴耳戏曲/叹息/耳语/雷）、交互反馈（脚步×2/纸翻/锁簧/
成功和弦/失败不谐和音）、音乐（menu drone / chase 循环 96bpm / 结局暖调）。
循环音用**尾部交叉淡化**（loopify）保证无缝；Godot 侧 `AudioStreamWAV.loop_mode` 运行时设置。

## 5. Godot 导入验证（已通过）

- `--headless --import`：50 个 .glb + 31 png + 34 wav **0 错误**
- `-colonly` 代理在导入后正确转为 StaticBody3D；门扇碰撞随动画跟随（已用节点树 dump 验证）
- 动画轨道完整进入 AnimationPlayer（turn_head / door_open+door_close / drawer_open /
  lantern_sway / tablet_pickup / bell_ring / secretshelf_slide / bed_curtain_open / box_open）

## 6. Blender 侧规范细节

见 `tools/blender/README.md`。要点：
- 原点=模块底面中心、1m 网格对齐、米制、+Y 朝前
- Principled BSDF + Noise→ColorRamp 程序化青苔/斑驳（等效 A 管线的贴图遮罩思路）
- 细分/倒角提升高光质感（bmesh bevel 2 段）
- 门扇/纸人头/抽屉独立枢轴 + fcurves 关键帧，轨道名与 A 管线一致

## 7. 场景拼装（scripts/world/WorldBuilder.gd）

全宅由 kit 模块程序化拼装：`_wall()`（沿线段布 4m 模块、缺口自动分段并生成碰撞长盒）、
`_floor_rect / _ceiling_rect / _omni / _ghost_fire / _spawn_door / _spawn_doc / _spawn_pickup`。
五区域坐标表见文件头注释；谜题插槽、惊吓触发区、终局抉择点均以数据化位置布置。
