# 《沈家老宅》
## 第一人称 3D 中式民俗悬疑解谜恐怖游戏 · Blender + Godot 4

> 一位失忆的年轻扎纸匠，在暴雨夜被一封朱砂印委托信"请"回十年前一夜灭门的沈家老宅——
> 这座宅子里所有的纸人，都出自他自己的手。

![类型](https://img.shields.io/badge/%E7%B1%BB%E5%9E%8B-%E6%B2%89%E6%B5%B8%E8%A7%A3%E8%B0%9C%2F%E5%BF%83%E7%90%86%E6%81%90%E6%80%96-red) ![引擎](https://img.shields.io/badge/%E5%BC%95%E6%93%8E-Godot%204.7%20Forward%2B-blue)

---

## 快速开始

### 运行游戏

```bash
# 方式一：Godot 编辑器
Godot_v4.7.2-stable_win64.exe --path .        # 打开编辑器后 F5 运行

# 方式二：直接运行
Godot_v4.7.2-stable_win64.exe --path .        # 主场景 Main.tscn 自动启动
```

### 重新生成全部资产（可选，已预生成）

```bash
python tools/build_all.py      # 贴图(31) + 50 个 .glb + 34 个音效，约 18 秒
```

### 验证（可选）

```bash
# 冒烟测试（110 项断言：内容完整性/谜题可解唯一/场景构建）
Godot_v4.7.2-stable_win64.exe --headless --path . res://tests/smoke.tscn

# 全流程通关模拟（28 项断言：四谜题链→终局→双结局）
Godot_v4.7.2-stable_win64.exe --headless --path . res://tests/playthrough.tscn

# 交互回归测试（44 项断言：全程合成键鼠输入驱动——
# 菜单点击/E 开门穿行/八卦锁与铜铃面板操作/抛灯拾回/鬼影遮挡/960×540 适配）
Godot_v4.7.2-stable_win64.exe --headless --path . res://tests/input_regression.tscn

# 视觉截图验证（渲染截图 → tests/shot_*.png；GPU 环境偶发 stalls，headless 测试为准）
Godot_v4.7.2-stable_win64.exe --path . res://tests/shot.tscn
```

### 操作

| 键位 | 功能 |
|---|---|
| WASD / Shift / Ctrl(C) | 移动 / 狂奔 / 下蹲（躲藏） |
| 鼠标 | 视角；E 交互 |
| F / G | 熄灯·点灯 / 抛出灯笼（可拾回） |
| Tab / J | 行囊·检视 / 线索册 |
| Esc | 暂停 |

**核心机制**：手持油灯是唯一光源——**灯火发绿、剧烈摇曳、灯芯爆裂 = 附近有东西醒着**。

**HUD 图标**：平时仅极弱中心圆点；对准可交互物时切换为**水墨手掌**（可拿/可操作）或**水墨眼睛**（可翻看，带朱砂瞳与缓慢眨眼脉动），下方弹出古风提示。图标为纯 canvas 双笔刷绘制（宽淡晕染打底 + 浓墨收笔），零素材依赖。

---

## 项目结构

```
├── project.godot              Godot 4.7 工程（Forward+ / 4 个 autoload）
├── scenes/main/Main.tscn      入口场景（一切由代码构建，便于程序化关卡）
├── autoload/                  GameState / ItemDB / AudioMgr / ScareMgr
├── scripts/
│   ├── player/Player.gd       第一人称控制器 + 油灯三态预警 + 交互射线
│   ├── interact/              Interactable 基类 / Pickup / DocPickup / Door / Drawer / Curtain / TriggerZone
│   ├── puzzles/               牌位归位 / 八卦锁 / 铜镜折射 / 扎纸仪式 + BellUI
│   ├── scares/Scares.gd       15 种小惊吓与剧情惊吓演出
│   ├── ghost/RedBride.gd      红衣鬼影（巡逻/追猎/捕获/重生）
│   ├── world/                 WorldBuilder（全宅关卡）/ RainField / Endings / 抉择点
│   └── ui/                    宣纸主题 / HUD / 行囊 / 3D检视 / 阅读器 / 主菜单 / 特效层
├── assets/
│   ├── kit/    (12)           模块化建筑 .glb（-colonly 碰撞代理）
│   ├── props/  (38)           民俗道具 .glb（含 door_open/turn_head/drawer_open/lantern_sway 动画轨道）
│   ├── tex/    (31)           程序化 PBR 贴图（宣纸/青砖/斑驳红漆/窗棂镂空/纸人面具…）
│   └── sfx/    (34)           程序化音效（雨/风/滴水/唢呐/二胡/梆子/铃/心跳/ chase 配乐…）
├── tools/
│   ├── build_all.py           一键资产管线（纯 Python，无外部依赖）
│   ├── glblib.py              自研 glTF 2.0 .glb 生成器（图元/材质/层级/动画/内嵌贴图）
│   ├── texgen.py / sfxgen.py  程序化贴图与音效合成（numpy）
│   └── blender/               Blender 高模重制管线（热替换同名 .glb）
├── tests/                     冒烟测试 + 截图验证 + 资产检查脚本
└── docs/GDD_沈家老宅.md        完整游戏设计文档
```

## 四大谜题（与剧情强绑定）

1. **祠堂牌位归位**——昭穆之制 + 牌位背面生辰；沈柏舟的牌位要归还供桌横头（情报在族谱）
2. **八卦机关锁**——离火倒悬于北、坎水逆位于南、巽风退居乾位，中宫纳水（情报在道士手札）
3. **铜镜光影折射**——三面铜镜把烛光折向屏风，显出血字「十九」（几何已验证唯一解）
4. **扎纸三忌仪式**——点睛（先左眼）→ 三炷香（中→左→右）→ 子时三刻敲铃三响（情报在账本）

谜题链：牌位 → 手札 → 八卦锁 → 玉佩+日记 → 铜镜 → 朱砂笔 → 仪式 → 密道 → 血书 → 终局抉择。

## 恐怖节奏

- **高频小惊吓**（6–8 分钟/次，配额+冷却防疲劳）：廊门拍响 / 窗棂黑影 / 抽屉纸人头 / 床幔白影 / 纸人回头杀 / 镜中红影 / 供品死鼠
- **中度剧情惊吓**：谜题一完成 → 全宅灯笼骤灭 + 太师椅多出红绣花鞋；拿契约 → 火灾闪回（红闪+震屏+心跳）
- **终局追逐**：血字三则生存法则（灯莫灭/名莫应/门莫开），熄灯蹲行降低被视距，**双结局**：
  - 真《了结》：把玉佩放回牌位前
  - 伪《长夜》：揣玉夺门而逃

## Blender 高模管线

安装 Blender 后（见 `tools/blender/README.md`）：

```bash
blender --background --python tools/blender/build_kit.py -- --out assets/kit_hd
blender --background --python tools/blender/build_props.py -- --out assets/props_hd
```

产出的同名 `.glb`（含 `-colonly` 碰撞代理与 `door_open/turn_head/drawer_open` 动画轨道）
直接覆盖 `assets/` 下同名文件 → `godot --headless --import` → 无需改任何代码即完成热替换。

## 技术要点

- **零外部资产依赖**：所有几何/贴图/音频均为程序化生成（glTF 2.0 二进制写入器为自研纯 Python 实现）
- Godot 4 Forward+：体积雾 / SDF 风格动态光 / ACES / 辉光 / 全屏暗角+胶片颗粒 shader
- 3D 空间音频四总线（Ambient/Scares/Footstep/Lantern），惊吓自动 ducking
- UI 全代码构建：宣纸 StyleBox、运行时加载系统 CJK 字体、Label3D 古文浮层
