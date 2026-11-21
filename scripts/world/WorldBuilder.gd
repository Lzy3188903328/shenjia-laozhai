extends Node3D
class_name WorldBuilder
## 沈家老宅 全宅关卡构建（模块化 kit 拼装）
##
## 平面图（X 向东 / Z 向南，单位米，墙高 3m）：
##            北(-Z)
##   ┌─────────祠堂─────────┐   密室(西)
##   │ 正厅          花厅    │
##   ├────────北回廊─────────┤
##   │西回廊  前院/天井  东回廊│
##   ├────────南回廊─────────┤
##   │ 作坊          闺房     │
##   └────────南门───────────┘
##
## 区域：前院 x[-8,8] z[-8,8]｜正厅 x[-6,6] z[-17,-8]｜花厅 x[6,11] z[-14,-8.5]
##       祠堂 x[-5,5] z[-25,-17]｜闺房 x[8,16] z[-6,2]｜作坊 x[-16,-8] z[-6,2]
##       密室 x[-24,-16] z[-5,3]

const KIT_DIR := "res://assets/kit/"
const PROP_DIR := "res://assets/props/"
const WALL_H := 3.0

var _kit_cache: Dictionary = {}
var tablet_puzzle: TabletPuzzle
var mirror_room: MirrorRoom
var paper_ritual: PaperRitual
var bagua_lock: BaguaLock
var bookshelf_blocker: StaticBody3D

func _ready() -> void:
	_build_all()

func _kit(kit_name: String) -> PackedScene:
	if not _kit_cache.has(kit_name):
		_kit_cache[kit_name] = load(KIT_DIR + kit_name + ".glb")
	return _kit_cache[kit_name]

## ---------------------------------------------------------- 基础放置
func _place_kit(kit_name: String, pos: Vector3, rot_y_deg: float = 0.0, parent: Node = null, scl: Vector3 = Vector3.ONE) -> Node3D:
	var inst := _kit(kit_name).instantiate()
	(parent if parent != null else self).add_child(inst)
	inst.position = pos
	inst.rotation.y = deg_to_rad(rot_y_deg)
	inst.scale = scl
	return inst

func _asset_path(name: String) -> String:
	if ResourceLoader.exists(PROP_DIR + name + ".glb"):
		return PROP_DIR + name + ".glb"
	return KIT_DIR + name + ".glb"

func _place_prop(prop_name: String, pos: Vector3, rot_y_deg: float = 0.0, parent: Node = null) -> Node3D:
	var inst: Node3D = load(_asset_path(prop_name)).instantiate()
	(parent if parent != null else self).add_child(inst)
	inst.position = pos
	inst.rotation.y = deg_to_rad(rot_y_deg)
	return inst

## 墙体：沿 a→b 放 kit 模块（含缺口），并生成碰撞长盒
func _wall(a: Vector2, b: Vector2, gaps: Array = [], kit: String = "wall_brick", height: float = WALL_H, parent: Node = null) -> void:
	## 墙体：视觉模块与碰撞统一由"实体区间"生成（修复实施文档 §一）
	## 缺口换算为 [c-w/2, c+w/2] 并裁剪排序合并，取补集得到实体区间；
	## 手动碰撞与视觉模块都只铺在实体区间内；墙模块自带的 GLB 碰撞停用，
	## 由手动碰撞统一阻挡（门扇/门樘/门楣/柱子等独立交互体的碰撞不受影响）。
	var dir := b - a
	var total := dir.length()
	if total < 0.05:
		return
	var yaw := atan2(-dir.y, dir.x)
	var dnorm := dir / total
	# 缺口 → 区间 → 排序合并 → 补集 = 实体区间
	var spans: Array = []
	for g: Dictionary in gaps:
		spans.append([clampf(g["c"] - g["w"] * 0.5, 0.0, total), clampf(g["c"] + g["w"] * 0.5, 0.0, total)])
	spans.sort_custom(func(x, y): return x[0] < y[0])
	var runs: Array = []
	var cursor := 0.0
	for s: Array in spans:
		if s[0] > cursor:
			runs.append([cursor, s[0]])
		cursor = maxf(cursor, s[1])
	if cursor < total:
		runs.append([cursor, total])
	runs = runs.filter(func(r: Array): return r[1] - r[0] > 0.05)
	# 每个实体区间：手动碰撞长盒 + 视觉模块（≤4m，末段按实际长度缩放）
	for r: Array in runs:
		var run_start: float = r[0]
		var run_end: float = r[1]
		var run_len: float = run_end - run_start
		var mid_t := (run_start + run_end) * 0.5
		var mid := a + dnorm * mid_t
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(run_len, height, 0.28)
		col.shape = shape
		body.add_child(col)
		(parent if parent != null else self).add_child(body)
		body.position = Vector3(mid.x, height * 0.5, mid.y)
		body.rotation.y = yaw
		var t := run_start
		while t < run_end - 0.01:
			var seg_len := minf(4.0, run_end - t)
			var seg_mid := t + seg_len * 0.5
			var pos := a + dnorm * seg_mid
			var inst := _place_kit(kit, Vector3(pos.x, 0, pos.y), rad_to_deg(yaw), parent, Vector3(seg_len / 4.0, 1.0, 1.0))
			# 墙模块的 GLB 自带碰撞停用——阻挡由上面的手动长盒负责
			for wall_body in inst.find_children("*", "StaticBody3D", true, false):
				wall_body.collision_layer = 0
				wall_body.collision_mask = 0
			t += 4.0

func _floor_rect(x0: float, z0: float, x1: float, z1: float, kit: String, parent: Node = null) -> void:
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var w := absf(x1 - x0)
	var d := absf(z1 - z0)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, 0.2, d)
	col.shape = shape
	body.add_child(col)
	(parent if parent != null else self).add_child(body)
	body.position = Vector3(cx, -0.1, cz)
	_place_kit(kit, Vector3(cx, 0.001, cz), 0, parent, Vector3(w / 4.0, 1.0, d / 4.0))

func _ceiling_rect(x0: float, z0: float, x1: float, z1: float, y: float, parent: Node = null) -> void:
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var w := absf(x1 - x0)
	var d := absf(z1 - z0)
	_place_kit("floor_wood", Vector3(cx, y, cz), 0, parent, Vector3(w / 4.0, 1.0, d / 4.0))

func _omni(pos: Vector3, color: Color, energy: float, range_r: float, group: String = "") -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_r
	l.shadow_enabled = energy > 1.2
	add_child(l)
	l.position = pos
	if group != "":
		l.add_to_group(group)
	return l

func _ghost_fire(pos: Vector3) -> void:
	var fire := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.05
	m.height = 0.1
	fire.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.4, 1.0, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.9, 0.45)
	mat.emission_energy_multiplier = 3.0
	fire.material_override = mat
	add_child(fire)
	fire.position = pos
	var l := _omni(pos, Color(0.35, 0.9, 0.4), 0.7, 2.2, "house_lights")
	l.shadow_enabled = false
	var tw := fire.create_tween().set_loops()
	tw.tween_property(fire, "position:y", pos.y + 0.15, 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(fire, "position:y", pos.y, 1.8).set_trans(Tween.TRANS_SINE)

func _loop_anim(node: Node3D, anim_name: String, offset: float = 0.0) -> void:
	var ap := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	var anim := ap.get_animation(anim_name)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	ap.play(anim_name)
	ap.seek(offset, true)

func _spawn_interactable(script: GDScript, pos: Vector3, rot_y_deg: float, col_size: Vector3) -> Interactable:
	var it: Interactable = script.new()
	add_child(it)
	it.position = pos
	it.rotation.y = deg_to_rad(rot_y_deg)
	it.add_box_collision(col_size)
	return it

func _spawn_pickup(item_id: String, pos: Vector3) -> Pickup:
	var pk := Pickup.new()
	pk.item_id = item_id
	add_child(pk)
	pk.position = pos
	pk.add_box_collision(Vector3(0.3, 0.3, 0.3))
	var scene: PackedScene = load(ItemDB.item_mesh(item_id))
	if scene != null:
		var inst := scene.instantiate()
		inst.scale = Vector3.ONE * 0.9
		pk.add_child(inst)
	return pk

func _spawn_doc(doc_id: String, pos: Vector3, rot_y_deg: float = 0.0) -> DocPickup:
	var dp := DocPickup.new()
	dp.doc_id = doc_id
	add_child(dp)
	dp.position = pos
	dp.rotation.y = deg_to_rad(rot_y_deg)
	dp.add_box_collision(Vector3(0.4, 0.35, 0.4))
	if ItemDB.DOCS_MESH.has(doc_id):
		var scene: PackedScene = load("res://assets/props/%s.glb" % ItemDB.doc_mesh(doc_id))
		if scene != null:
			var inst := scene.instantiate()
			inst.scale = Vector3.ONE * 0.9
			dp.add_child(inst)
	return dp

func _spawn_door(pos: Vector3, rot_y_deg: float, door_name: String = "Door") -> Door:
	var inst := _place_kit("door", pos, rot_y_deg)
	var door := Door.new()
	door.name = door_name
	inst.add_child(door)
	# 交互盒：略凸出于门扇两侧，保证先于门体碰撞被射线命中（随门扇挂接后一起移动）
	door.add_box_collision(Vector3(1.15, 2.15, 0.42), Vector3(-0.02, 1.06, 0))
	return door

func _candle(pos: Vector3) -> void:
	_place_prop("candle", pos)
	var l := _omni(pos + Vector3(0, 0.4, 0), Color(1.0, 0.6, 0.28), 1.1, 4.0, "house_lights")
	l.shadow_enabled = false

## ---------------------------------------------------------- 总装
func _build_all() -> void:
	_build_courtyard()
	_build_corridors()
	_build_main_hall()
	_build_mirror_room()
	_build_shrine_hall()
	_build_boudoir()
	_build_workshop()
	_build_cellar()
	_build_south_gate()

## ---------------- 前院与天井 ----------------
func _build_courtyard() -> void:
	_floor_rect(-8, -8, 8, 8, "floor_stone")
	# 北墙只铺 x ±6..8 两角——正厅南墙（含门洞）覆盖 x -6..6
	_wall(Vector2(-8, -8), Vector2(-6, -8))
	_wall(Vector2(6, -8), Vector2(8, -8))
	_wall(Vector2(-8, 8), Vector2(8, 8), [{"c": 8.0, "w": 2.6}])   # 南门缺口
	# 东西围墙在厢房门（z=-2）处让出缺口，与厢房墙的缺口对齐
	_wall(Vector2(-8, -8), Vector2(-8, 8), [{"c": 6.0, "w": 2.0}])
	_wall(Vector2(8, -8), Vector2(8, 8), [{"c": 6.0, "w": 2.0}])
	# 回廊内圈柱
	var zz := -6.4
	while zz <= 6.5:
		_place_kit("pillar", Vector3(-6.4, 0, zz))
		_place_kit("pillar", Vector3(6.4, 0, zz))
		_place_kit("pillar", Vector3(zz, 0, -6.4))
		_place_kit("pillar", Vector3(zz, 0, 6.4))
		zz += 3.2
	# 回廊檐顶
	var t := -6.0
	while t < 6.0:
		_place_kit("roof_seg", Vector3(t + 2.0, 3.15, -7.2), 180)
		_place_kit("roof_seg", Vector3(t + 2.0, 3.15, 7.2), 0)
		_place_kit("roof_seg", Vector3(-7.2, 3.15, t + 2.0), 90)
		_place_kit("roof_seg", Vector3(7.2, 3.15, t + 2.0), -90)
		t += 4.6
	# 枯井
	_place_prop("stone_well", Vector3(0, 0, 0))
	ScareMgr.add_dread_source("well", Vector3(0, 1, 0), false)
	# 灵幡
	_place_prop("spirit_flag", Vector3(-5, 0, -5), 20)
	_place_prop("spirit_flag", Vector3(5, 0, 5), 160)
	# 红灯笼（回廊）
	var lantern_count := 0
	var lx := -6.0
	while lx <= 6.5:
		var lan := _place_prop("hanging_lantern", Vector3(lx, 2.9, -6.9))
		_loop_anim(lan, "lantern_sway", randf_range(0.0, 1.0))
		if lantern_count % 2 == 0:
			var l := _omni(Vector3(lx, 2.6, -6.9), Color(0.9, 0.25, 0.1), 1.6, 5.0, "house_lights")
			l.shadow_enabled = false
		lantern_count += 1
		lx += 3.0
	var lz := -5.5
	while lz <= 6.0:
		var lan2 := _place_prop("hanging_lantern", Vector3(-6.9, 2.9, lz), 90)
		_loop_anim(lan2, "lantern_sway", randf_range(0.0, 1.0))
		var lan3 := _place_prop("hanging_lantern", Vector3(6.9, 2.9, lz), 90)
		_loop_anim(lan3, "lantern_sway", randf_range(0.0, 1.0))
		lz += 3.5
	_ghost_fire(Vector3(0.7, 0.5, 0.7))
	# 玉佩抉择台（终局）——置于天井中部，避开南门出生点 (0,5)
	_place_prop("altar_table", Vector3(0, 0, 3.0), 0).name = "ChoiceShrine"
	_spawn_interactable(load("res://scripts/world/JadeChoice.gd"), Vector3(0, 1.0, 2.7), 0, Vector3(0.8, 0.3, 0.4)).name = "JadeChoice" 

## ---------------- 回廊（MS-01 / 火折子） ----------------
func _build_corridors() -> void:
	var slam_door := _spawn_door(Vector3(-7.2, 0, 3.0), 90, "MS廊门")
	slam_door.add_to_group("slam_doors")
	slam_door.set_locked(true)
	slam_door.locked_prompt = "此门背后……在动。"
	var tz := TriggerZone.new()
	tz.scare_id = "corridor_bang"
	tz.trigger_size = Vector3(1.2, 2.2, 3.0)
	add_child(tz)
	tz.position = Vector3(-6.9, 1.2, 1.5)
	_place_prop("chair_wood", Vector3(7.0, 0, 4.0), 90)
	_spawn_pickup("fire_starter", Vector3(7.5, 0.0, 3.6))
	_place_prop("candle", Vector3(-7.0, 0, -3.0))
	var cl := _omni(Vector3(-7.0, 0.5, -3.0), Color(0.9, 0.55, 0.25), 0.8, 3.0, "house_lights")
	cl.shadow_enabled = false

## ---------------- 正厅 ----------------
func _build_main_hall() -> void:
	_floor_rect(-6, -17, 6, -8, "floor_wood")
	_ceiling_rect(-6, -17, 6, -8, 3.04)
	_wall(Vector2(-6, -8), Vector2(6, -8), [{"c": 6.0, "w": 2.0}])       # 南墙（门→回廊）
	_wall(Vector2(-6, -17), Vector2(-5, -17))                             # 北墙角（祠堂前墙覆盖中段）
	_wall(Vector2(5, -17), Vector2(6, -17))
	_wall(Vector2(-6, -17), Vector2(-6, -8))                              # 西墙
	_wall(Vector2(6, -17), Vector2(6, -8), [{"c": 6.0, "w": 2.0}])        # 东墙（门→花厅，z=-11）
	_spawn_door(Vector3(0, 0, -8), 0, "HallSouthDoor")
	_spawn_door(Vector3(6, 0, -11), 90, "HallEastDoor")
	# 供桌 + 暗格抽屉（谜题1 产出：道士手札）
	var altar := _place_prop("altar_table", Vector3(0, 0, -15.0), 0)
	altar.name = "HallAltar"
	var drawer := Drawer.new()
	drawer.name = "HallAltarDrawer"
	drawer.doc_inside = "doc_07_daoshi_notes"
	altar.add_child(drawer)
	drawer.position = Vector3(0, 0.55, 0.3)
	drawer.add_box_collision(Vector3(0.65, 0.35, 0.55))
	drawer.set_anim(altar.find_child("AnimationPlayer", true, false) as AnimationPlayer)
	drawer.set_locked(true, "暗格扣着铜簧——牌位似乎没摆对。")
	GameState.puzzle_solved.connect(func(pid: String) -> void:
		if pid == "tablets":
			drawer.set_locked(false))
	# 堂联匾额（囍/奠拼接）
	var plaque := _place_prop("plaque", Vector3(0, 2.4, -16.8), 180)
	var lb := Label3D.new()
	lb.text = "囍　　　　奠"
	lb.font_size = 150
	lb.pixel_size = 0.004
	lb.modulate = Color(0.6, 0.08, 0.06)
	add_child(lb)
	lb.position = Vector3(0, 1.5, -16.75)
	lb.rotation.y = PI
	_place_prop("armchair", Vector3(-3.5, 0, -10.0), 70)
	_place_prop("armchair", Vector3(3.5, 0, -10.0), -70)
	# 封门（玩法扩展 §四）：西墙壁龛封门，「名莫应」遭遇用
	var sealed := _spawn_interactable(load("res://scripts/interact/SealedDoor.gd"),
		Vector3(-5.85, 0, -11.5), -90, Vector3(0.4, 2.3, 1.3))
	sealed.name = "SealedDoor"
	_candle(Vector3(-0.8, 0.92, -15.2))
	_candle(Vector3(0.8, 0.92, -15.2))
	# 侍立纸人 ×2
	var f1 := _place_prop("paper_figure", Vector3(-2.2, 0, -15.6), 10)
	var f2 := _place_prop("paper_figure", Vector3(2.2, 0, -15.6), -10)
	f1.add_to_group("paper_figures")
	f2.add_to_group("paper_figures")
	# MS-02 窗棂黑影
	_place_kit("window", Vector3(2.5, 0, -8.35), 180)
	var tz := TriggerZone.new()
	tz.scare_id = "window_flash"
	tz.trigger_size = Vector3(2.0, 2.4, 1.6)
	add_child(tz)
	tz.position = Vector3(2.5, 1.2, -9.5)
	# MS-05 回头杀
	var tz2 := TriggerZone.new()
	tz2.scare_id = "figure_turn"
	tz2.trigger_size = Vector3(4.5, 2.2, 2.0)
	add_child(tz2)
	tz2.position = Vector3(0, 1.2, -13.8)
	var l := _omni(Vector3(0, 2.4, -12), Color(0.9, 0.5, 0.25), 1.3, 7.0, "house_lights")
	l.shadow_enabled = false

## ---------------- 花厅（谜题三 铜镜折射） ----------------
func _build_mirror_room() -> void:
	_floor_rect(6, -14, 11, -8.5, "floor_wood")
	_ceiling_rect(6, -14, 11, -8.5, 3.04)
	_wall(Vector2(6, -8.5), Vector2(11, -8.5))
	_wall(Vector2(6, -14), Vector2(11, -14))
	_wall(Vector2(11, -14), Vector2(11, -8.5))
	# 全暗房间：烛台为唯一光源
	var candle_world := Vector3(7.6, 0, -11.6)
	mirror_room = MirrorRoom.new()
	add_child(mirror_room)
	mirror_room.position = candle_world
	_place_prop("candle", Vector3(0, 0.9, 0), 0, mirror_room)
	var cl := _omni(candle_world + Vector3(0, 1.3, 0), Color(1.0, 0.6, 0.28), 1.2, 5.0, "house_lights")
	cl.shadow_enabled = false
	# 三面立镜
	var stands: Array[Node3D] = []
	var mirror_locals := [Vector3(2.7, 0, -0.4), Vector3(2.5, 0, 2.4), Vector3(0.1, 0, 2.9)]
	for i in mirror_locals.size():
		var stand := _place_prop("mirror_stand", mirror_locals[i], 0, mirror_room)
		stands.append(stand.find_child("Mirror", true, false))
	mirror_room.setup(stands, candle_world, candle_world + Vector3(-1.6, 0, 2.7))
	# 屏风
	var screen := _place_prop("plaque", candle_world + Vector3(-1.6, 0.95, 2.7), 90)
	screen.scale = Vector3(1.4, 2.4, 1.2)
	var slb := Label3D.new()
	slb.text = "月照奁中镜\n光落血字处"
	slb.font_size = 60
	slb.pixel_size = 0.003
	slb.modulate = Color(0.5, 0.4, 0.2)
	add_child(slb)
	slb.global_position = candle_world + Vector3(-1.5, 1.5, 2.7)
	slb.rotation.y = PI / 2

## ---------------- 祠堂（谜题一 牌位归位） ----------------
func _build_shrine_hall() -> void:
	_floor_rect(-5, -25, 5, -17, "floor_stone")
	_ceiling_rect(-5, -25, 5, -17, 3.04)
	_wall(Vector2(-5, -17), Vector2(5, -17), [{"c": 5.0, "w": 2.0}])
	_wall(Vector2(-5, -25), Vector2(5, -25))
	_wall(Vector2(-5, -25), Vector2(-5, -17))
	_wall(Vector2(5, -25), Vector2(5, -17))
	_spawn_door(Vector3(0, 0, -17), 0, "ShrineDoor")
	# 牌位架 + 谜题
	var rack := _place_prop("tablet_rack", Vector3(0, 0, -24.3), 0)
	rack.name = "TabletRack"
	tablet_puzzle = TabletPuzzle.new()
	add_child(tablet_puzzle)
	var slots: Array[Node3D] = []
	for row in 3:
		for side in 2:
			var marker := Node3D.new()
			rack.add_child(marker)
			var lx := -0.42 if side == 0 else 0.42
			var ly := 0.62 + row * 0.55
			marker.position = Vector3(lx, ly, 0.14)
			marker.name = "TabletSlot%d_%d" % [row, side]
			slots.append(marker)
	var ret_spot := Node3D.new()
	add_child(ret_spot)
	ret_spot.position = Vector3(2.0, 0.95, -22.0)
	tablet_puzzle.setup(slots, ret_spot)
	# 供桌 + 族谱 + 供品
	_place_prop("altar_table", Vector3(0, 0, -22.0), 0).name = "ShrineAltar"
	_spawn_doc("doc_08_genealogy", Vector3(-0.5, 0.93, -21.9), 160)
	_place_prop("offering_plate", Vector3(0.5, 0.93, -22.0))
	var rat_zone := TriggerZone.new()
	rat_zone.scare_id = "drawer_rat"
	rat_zone.trigger_size = Vector3(1.6, 2.0, 1.6)
	add_child(rat_zone)
	rat_zone.position = Vector3(0.5, 1.0, -21.0)
	# 血字（东墙）→ doc_10
	var blood := DocPickup.new()
	blood.doc_id = "doc_10_blood_rules"
	add_child(blood)
	blood.position = Vector3(4.75, 1.4, -20.0)
	blood.rotation.y = deg_to_rad(-90)
	blood.add_box_collision(Vector3(0.15, 1.3, 1.5))
	var blood_lb := Label3D.new()
	blood_lb.text = "灯莫明\n步莫急\n南门绝\n中庭还玉"
	blood_lb.font_size = 90
	blood_lb.pixel_size = 0.003
	blood_lb.modulate = Color(0.42, 0.05, 0.03)
	add_child(blood_lb)
	blood_lb.position = Vector3(4.88, 1.5, -20.0)
	blood_lb.rotation.y = -PI / 2
	# 灵幡
	_place_prop("spirit_flag", Vector3(-3.5, 0, -23.5), 30)
	_place_prop("spirit_flag", Vector3(3.5, 0, -23.5), 150)
	_candle(Vector3(-2.0, 0, -20.0))
	_candle(Vector3(2.0, 0, -20.0))
	_candle(Vector3(-1.4, 0.92, -21.6))
	_candle(Vector3(1.4, 0.92, -21.6))
	var l := _omni(Vector3(0, 2.3, -21), Color(0.85, 0.45, 0.22), 1.0, 7.0, "house_lights")
	l.shadow_enabled = false
	# 太师椅（MS-10 红绣花鞋出现位）
	_place_prop("armchair", Vector3(-3.8, 0, -18.5), 45).name = "MS10Chair"

## ---------------- 闺房（谜题二 八卦锁） ----------------
func _build_boudoir() -> void:
	_floor_rect(8, -6, 16, 2, "floor_wood")
	_ceiling_rect(8, -6, 16, 2, 3.04)
	_wall(Vector2(8, -6), Vector2(16, -6))
	_wall(Vector2(8, 2), Vector2(16, 2))
	_wall(Vector2(16, -6), Vector2(16, 2))
	_wall(Vector2(8, -6), Vector2(8, 2), [{"c": 4.0, "w": 2.0}])   # 西墙缺口（门 z=-2）
	_spawn_door(Vector3(8, 0, -2), 90, "BoudoirDoor")
	# 拔步床
	var bed := _place_prop("bed", Vector3(13.0, 0, -4.6), 0)
	bed.name = "Bed"
	var curtain := Curtain.new()
	curtain.name = "BedCurtain"
	curtain.doc_inside = "doc_04_diary_b"
	bed.add_child(curtain)
	curtain.position = Vector3(0, 0, 0.78)
	curtain.add_box_collision(Vector3(0.7, 1.9, 0.7))
	# 梳妆台 + 妆奁盒
	var dresser := _place_prop("dresser", Vector3(15.4, 0, -1.0), -90)
	dresser.name = "Dresser"
	_place_prop("jewelry_box", Vector3(15.15, 0.86, -1.0), -90)
	_place_prop("bagua_lock", Vector3(15.15, 1.06, -1.0), -90).name = "BaguaModel"
	bagua_lock = BaguaLock.new()
	add_child(bagua_lock)
	var box_inter := _spawn_interactable(load("res://scripts/puzzles/JewelryBoxInteract.gd"),
		Vector3(15.15, 0.92, -1.0), -90, Vector3(0.5, 0.45, 0.45))
	box_inter.name = "JewelryBox"
	# 梳妆台铜镜 → MS-06
	var mirror_inter := _spawn_interactable(load("res://scripts/interact/MirrorScareInteract.gd"),
		Vector3(15.62, 1.35, -1.0), -90, Vector3(0.2, 0.6, 0.55))
	mirror_inter.name = "DresserMirror"
	# 梳妆台抽屉 → 纸人头 + 家书
	var ddrawer := Drawer.new()
	ddrawer.name = "DresserDrawer"
	ddrawer.doc_inside = "doc_02_family_letter"
	ddrawer.scare_id = "drawer_head"
	dresser.add_child(ddrawer)
	ddrawer.position = Vector3(-0.2, 0.62, 0)
	ddrawer.add_box_collision(Vector3(0.45, 0.3, 0.45))
	ddrawer.set_anim(dresser.find_child("AnimationPlayer", true, false) as AnimationPlayer)
	# 绣墩 / 杂物
	_place_prop("chair_wood", Vector3(14.2, 0, 0.6), 200)
	_place_prop("bronze_mirror", Vector3(15.3, 0.9, -0.35), 30)
	# 压痕窗纸（玩法扩展 §三）：妆奁边压着的旧窗纸，侧照显纹
	var wpaper := _spawn_interactable(load("res://scripts/interact/WindowPaper.gd"),
		Vector3(14.6, 0.92, -0.45), 0, Vector3(0.4, 0.3, 0.4))
	wpaper.name = "WindowPaper"
	var l := _omni(Vector3(12, 2.3, -2), Color(0.85, 0.5, 0.28), 1.15, 7.0, "house_lights")
	l.shadow_enabled = false

## ---------------- 扎纸作坊（谜题四） ----------------
func _build_workshop() -> void:
	_floor_rect(-16, -6, -8, 2, "floor_wood")
	_ceiling_rect(-16, -6, -8, 2, 3.04)
	_wall(Vector2(-16, -6), Vector2(-8, -6))
	_wall(Vector2(-16, 2), Vector2(-8, 2))
	_wall(Vector2(-16, -6), Vector2(-16, 2), [{"c": 5.0, "w": 2.2}])   # 西墙缺口 → 密室（z=-1）
	_wall(Vector2(-8, -6), Vector2(-8, 2), [{"c": 4.0, "w": 2.0}])     # 东墙缺口 → 门（z=-2）
	_spawn_door(Vector3(-8, 0, -2), 90, "WorkshopDoor")
	# 书案
	_place_prop("desk_study", Vector3(-12.5, 0, -4.8), 0)
	_spawn_doc("doc_05_ledger", Vector3(-12.2, 0.83, -4.7), 170)
	_spawn_pickup("incense", Vector3(-13.0, 0.85, -4.7))
	_place_prop("luopan", Vector3(-12.8, 0.86, -5.0), 30)
	_place_prop("paste_pot", Vector3(-11.8, 0.84, -5.0))
	# 竹篾
	_place_prop("bamboo_stack", Vector3(-15.0, 0, -4.8))
	_place_prop("bamboo_stack", Vector3(-14.6, 0, 1.4), 40)
	# 仪式纸人（点睛对象）——置于南墙侧，为北面悬挂的铜铃让出瞄准线
	var figure := _place_prop("paper_figure", Vector3(-10.5, 0, 1.4), 180)
	figure.add_to_group("paper_figures")
	# 无眼纸人半成品
	_place_prop("paper_figure", Vector3(-14.0, 0, -3.2), 100).add_to_group("paper_figures")
	var small := _place_prop("paper_figure", Vector3(-13.0, 0, 1.2), 260)
	small.scale = Vector3.ONE * 0.7
	# 香炉（置于地面，避免凳面碰撞挡住香头瞄准）
	_place_prop("chair_wood", Vector3(-12.4, 0, 1.6), 90)
	var burner := _place_prop("incense_burner", Vector3(-11.8, 0, 0.9))
	burner.name = "RitualBurner"
	# 铜铃
	var bell := _place_prop("copper_bell", Vector3(-10.5, 1.7, 0.2))
	bell.name = "RitualBell"
	# 补扎替身侧桌（玩法扩展 §二）：待修男装胸架 + 翘起的红线
	_place_prop("chair_wood", Vector3(-13.2, 0, 1.3), 0)
	var mend_fig := _place_prop("paper_figure", Vector3(-13.2, 0.5, 1.3), 90)
	mend_fig.scale = Vector3.ONE * 0.45
	mend_fig.rotation_degrees = Vector3(-70, 90, 0)   # 平躺在侧桌上
	var mend_chest := _spawn_interactable(load("res://scripts/interact/MendChest.gd"),
		Vector3(-13.2, 0.85, 1.3), 0, Vector3(0.5, 0.4, 0.5))
	mend_chest.name = "MendChest"
	# 谜题四
	paper_ritual = PaperRitual.new()
	add_child(paper_ritual)
	paper_ritual.setup(figure, burner, bell)
	# 暗格书架（滑门 → 密室）
	var shelf := _place_prop("bookshelf", Vector3(-15.55, 0, -1.0), 90)
	shelf.name = "SecretShelf"
	shelf.add_to_group("secret_shelf")
	bookshelf_blocker = StaticBody3D.new()
	bookshelf_blocker.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 3.0, 2.0)
	col.shape = shape
	bookshelf_blocker.add_child(col)
	add_child(bookshelf_blocker)
	bookshelf_blocker.position = Vector3(-15.9, 1.5, -1.0)
	GameState.puzzle_solved.connect(func(pid: String) -> void:
		if pid == "ritual":
			_open_secret_passage())
	var l := _omni(Vector3(-12, 2.3, -1), Color(0.8, 0.5, 0.3), 1.15, 7.0, "house_lights")
	l.shadow_enabled = false

func _open_secret_passage() -> void:
	var shelf := get_tree().get_first_node_in_group("secret_shelf") as Node3D
	if shelf != null:
		var anim := shelf.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim != null:
			anim.play("secretshelf_slide")
		# 整架沿西墙滑向作坊北侧，让出 x=-16 的门洞；同时关闭书架全部碰撞体
		var tw := shelf.create_tween()
		tw.tween_property(shelf, "position", Vector3(-15.55, 0, -4.6), 1.6)			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		for body in shelf.find_children("*", "StaticBody3D", true, false):
			body.collision_layer = 0
			body.collision_mask = 0
	AudioMgr.play_at("creak_wood", Vector3(-15.6, 1, -1.0), -4.0, 0.8)
	if bookshelf_blocker != null:
		bookshelf_blocker.queue_free()
	_spawn_doc("doc_06_contract", Vector3(-16.8, 0.9, -1.0), 90)
	AudioMgr.play_at("whisper", Vector3(-17, 1, -1), -6.0)

## ---------------- 祠堂密室（终局） ----------------
func _build_cellar() -> void:
	_floor_rect(-24, -5, -16, 3, "floor_stone")
	_ceiling_rect(-24, -5, -16, 3, 2.6)
	_wall(Vector2(-24, -5), Vector2(-16, -5), [], "wall_wood")
	_wall(Vector2(-24, 3), Vector2(-16, 3), [], "wall_wood")
	_wall(Vector2(-24, -5), Vector2(-24, 3), [], "wall_wood")
	_wall(Vector2(-16, 2), Vector2(-16, 3))   # 东墙补缺（与作坊西墙拼接）
	# 法事残坛 + 血书
	_place_prop("altar_table", Vector3(-20, 0, -3.4), 0).name = "CellarAltar"
	_spawn_doc("doc_11_blood_contract", Vector3(-20, 0.95, -3.2), 175)
	# 妆奁 + 半张婚书
	_place_prop("chair_wood", Vector3(-22.5, 0, -3.8), 0)
	_place_prop("jewelry_box", Vector3(-22.5, 0.48, -3.8))
	_spawn_doc("doc_12_wedding_half", Vector3(-22.5, 0.7, -3.8), 200)
	# 白烛阵（初始熄灭）
	for p in [Vector3(-21.5, 0, -1.0), Vector3(-18.5, 0, -1.0), Vector3(-21.5, 0, 1.0), Vector3(-18.5, 0, 1.0)]:
		_place_prop("candle", p)
		var l := _omni(p + Vector3(0, 0.4, 0), Color(0.4, 1.0, 0.45), 0.0, 3.5, "cellar_candles")
		l.set_meta("target_energy", 1.4)
		l.shadow_enabled = false
	_ghost_fire(Vector3(-20, 0.5, 0))
	var tz := TriggerZone.new()
	tz.scare_id = "basement_candles"
	tz.trigger_size = Vector3(6.0, 2.5, 5.0)
	add_child(tz)
	tz.position = Vector3(-20, 1.2, -1.0)
	ScareMgr.add_dread_source("cellar", Vector3(-20, 1, -1), false)
	var l2 := _omni(Vector3(-20, 2.0, -1), Color(0.5, 0.75, 0.4), 0.35, 5.0, "house_lights")
	l2.shadow_enabled = false

## ---------------- 南门 ----------------
func _build_south_gate() -> void:
	_place_kit("pillar", Vector3(-1.5, 0, 8))
	_place_kit("pillar", Vector3(1.5, 0, 8))
	_place_kit("beam", Vector3(0, 2.9, 8))
	_place_kit("roof_seg", Vector3(0, 3.4, 8.6), 0)
	var plaque := _place_prop("plaque", Vector3(0, 2.6, 8.0), 180)
	var lb := Label3D.new()
	lb.text = "沈 宅"
	lb.font_size = 180
	lb.pixel_size = 0.004
	lb.modulate = Color(0.75, 0.62, 0.35)
	plaque.add_child(lb)
	lb.position = Vector3(0, 0, 0.035)
	lb.rotation.y = PI
	# 终局交互体放在门扇的天井一侧（z 7.3..7.8）：院内瞄准南门时先于锁死的门扇命中
	var esc := _spawn_interactable(load("res://scripts/world/EscapeDoor.gd"), Vector3(0, 1.0, 7.55), 0, Vector3(2.4, 2.2, 0.5))
	esc.name = "EscapeDoor"
	var gate := _spawn_door(Vector3(0, 0, 8.0), 180, "SouthGateDoor")
	gate.set_locked(true)
	for x in [-4.0, 4.0]:
		var lan := _place_prop("hanging_lantern", Vector3(x, 2.9, 6.9))
		_loop_anim(lan, "lantern_sway", randf_range(0.0, 1.0))
