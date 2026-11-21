extends Node3D
## Main — 游戏总编排：环境氛围 / 全宅构建 / 游戏流程 / 终局追逐 / 双结局

var player: CharacterBody3D
var world_builder: WorldBuilder
var bride: RedBride
var effects: Effects
var hud: HUD
var main_menu: MainMenu
var inventory_ui: InventoryUI
var inspect_ui: InspectUI
var reader_ui: ReaderUI
var pause_ui: PauseUI
var endings_ui: Endings
var bell_ui: BellUI
var scares: Scares
var rain: RainField
var env: Environment

var _game_started := false
var _region := ""

# 环境音区域矩形
const REGION_COURTYARD := Rect2(-8, -8, 16, 16)
const REGION_CELLAR := Rect2(-24, -5, 8, 8)

# 各屋首访引导（一次性的方向提示，线索仍由场景与文档提供）
const VISIT_HINTS := {
	"hall": [Rect2(-6, -17, 12, 9), "正厅。供桌的暗格扣着铜簧——先去后面的祠堂，把错乱的牌位摆正。"],
	"shrine": [Rect2(-5, -25, 10, 8), "祠堂。族谱就摆在供桌上——考在左、妣在右，殇女居下层。"],
	"boudoir": [Rect2(8, -6, 8, 8), "闺房。妆奁盒上有一把八卦锁——解法应在道士手札里。"],
	"workshop": [Rect2(-16, -6, 8, 8), "扎纸作坊。账本边缘写着「扎纸三忌」——点睛、香序、铃时辰。"],
}
var _visited := {}

func _ready() -> void:
	randomize()
	_build_environment()
	_build_actors()
	_build_ui()
	_wire_signals()
	AudioMgr.play_drone()
	main_menu.start_requested.connect(_start_game)

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.015, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.26, 0.30)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.28, 0.33, 0.30)
	env.fog_density = 0.028
	env.fog_sky_affect = 1.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.028
	env.volumetric_fog_albedo = Color(0.6, 0.65, 0.72)
	env.volumetric_fog_emission = Color(0.01, 0.015, 0.02)
	env.volumetric_fog_length = 24.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# 幽绿月光
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.75, 0.62)
	moon.light_energy = 0.10
	moon.rotation_degrees = Vector3(-52, 28, 0)
	moon.shadow_enabled = true
	add_child(moon)

func _build_actors() -> void:
	world_builder = WorldBuilder.new()
	world_builder.name = "World"
	world_builder.add_to_group("world_builder")
	add_child(world_builder)
	rain = RainField.new()
	rain.name = "Rain"
	add_child(rain)
	scares = Scares.new()
	scares.name = "Scares"
	add_child(scares)
	player = load("res://scripts/player/Player.gd").new()
	player.name = "Player"
	player.add_to_group("player")
	add_child(player)
	player.position = Vector3(0, 0.15, 5.0)
	player.set_meta("respawn_pos", Vector3(-17.5, 0.15, -1.0))
	player.interact_target_changed.connect(func(text: String, icon_type: String) -> void:
		hud.set_prompt(text, icon_type))
	bride = RedBride.new()
	bride.name = "RedBride"
	add_child(bride)
	bride.global_position = Vector3(0, 0, -6)

func _build_ui() -> void:
	effects = Effects.new()
	add_child(effects)
	hud = HUD.new()
	add_child(hud)
	main_menu = MainMenu.new()
	add_child(main_menu)
	inventory_ui = InventoryUI.new()
	add_child(inventory_ui)
	inspect_ui = InspectUI.new()
	add_child(inspect_ui)
	reader_ui = ReaderUI.new()
	add_child(reader_ui)
	pause_ui = PauseUI.new()
	add_child(pause_ui)
	endings_ui = Endings.new()
	add_child(endings_ui)
	bell_ui = BellUI.new()
	add_child(bell_ui)
	effects.set_fade_black(1.0)

func _wire_signals() -> void:
	GameState.item_picked.connect(func(item_id: String) -> void:
		hud.toast("拾得 · %s" % ItemDB.item_name(item_id))
		if item_id == "jade_pendant":
			GameState.set_objective("玉佩已寻回 · 查明此宅真相")
			# 若已读过半张婚书：自动触发「玉佩 × 婚书」组合回忆
			if GameState.docs.has("doc_12_wedding_half") and not GameState.get_flag("memory_jade_wedding"):
				GameState.set_flag("memory_jade_wedding")
				await get_tree().create_timer(2.2).timeout
				hud.toast("玉佩背面的「清欢」与婚书残页并在一起——四月里她笑着等你，七月里她至死不肯闭上眼。（记忆闪回）")
				effects.red_flash(1.8))
	GameState.puzzle_solved.connect(_on_puzzle_solved)
	GameState.doc_read.connect(_on_doc_read)
	GameState.finale_started.connect(_start_finale)
	GameState.player_died.connect(_on_player_died)
	GameState.ending_reached.connect(func(ending_id: String) -> void:
		endings_ui.play_ending(ending_id))
	reader_ui.closed.connect(_on_letter_closed)

# ---------------------------------------------------------- 开场
func _start_game() -> void:
	if _game_started:
		return
	_game_started = true
	GameState.new_game()
	main_menu.hide_menu()
	player.lock_input(false)   # 解除开场锁
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: effects.set_fade_black(v), 1.0, 0.0, 2.2)
	AudioMgr.stop_ambient()
	await get_tree().create_timer(1.2).timeout
	reader_ui.open_doc("doc_01_entrust")
	hud.toast("雨越下越大。今晚正是七月十五中元夜——这封委托信，是三天前送到你铺子门口的。")

func _on_letter_closed() -> void:
	## 合上文档后：开场方向提示 / 血书读完后的终局过渡（顺序：合上→恢复行动→3s 后追逐）
	if not _game_started:
		return
	if GameState.get_flag("finale_pending") and not GameState.get_flag("finale"):
		GameState.set_flag("finale_pending", false)
		# 此时阅读器已关闭、移动与鼠标已恢复
		scares.run_scare_forced("flashback_fire", player.global_position)
		hud.toast("「可敢认？」——血书上的血迹未干。怨气开始苏醒。跑。")
		await get_tree().create_timer(3.0).timeout
		GameState.start_finale()
		return
	if GameState.get_flag("hint_courtyard"):
		return
	GameState.set_flag("hint_courtyard")
	hud.toast("穿过天井，去正厅避雨——委托信上说，雨夜叩门自开。")
	GameState.set_objective("穿过天井 · 去正厅避雨")

# ---------------------------------------------------------- 区域氛围
func _process(_delta: float) -> void:
	if not _game_started:
		return
	var pos := player.global_position
	ScareMgr.update_dread(pos)
	var new_region := "indoor"
	if REGION_COURTYARD.has_point(Vector2(pos.x, pos.z)):
		new_region = "courtyard"
	elif REGION_CELLAR.has_point(Vector2(pos.x, pos.z)):
		new_region = "cellar"
	if new_region != _region:
		_region = new_region
		AudioMgr.set_ambient(_region)
	for k in VISIT_HINTS:
		if not _visited.has(k) and (VISIT_HINTS[k][0] as Rect2).has_point(Vector2(pos.x, pos.z)):
			_visited[k] = true
			hud.toast(VISIT_HINTS[k][1])
			match k:
				"hall":
					if not GameState.get_flag("puzzle_tablets"):
						GameState.set_objective("祠堂 · 归位牌位")
	if rain != null:
		rain.set_follow(pos)

# ---------------------------------------------------------- 谜题连锁反应
func _on_puzzle_solved(puzzle_id: String) -> void:
	match puzzle_id:
		"tablets":
			# MS-10：全场灯笼骤灭 → 红绣花鞋
			scares.run_scare_forced("blackout", player.global_position)
			await get_tree().create_timer(3.4).timeout
			scares.run_scare_forced("shoes_appear", Vector3(-3.8, 0.5, -18.5))
			hud.toast("灯复明了。太师椅上……多了一双沾满泥水的红绣花鞋。")
			# 红绣花鞋可拾取（与随身鞋扣可组合）
			var PickupScript2 := load("res://scripts/interact/Pickup.gd")
			var shoes: Pickup = PickupScript2.new()
			shoes.item_id = "red_shoes"
			add_child(shoes)
			shoes.global_position = Vector3(-3.8, 0.55, -18.4)
			shoes.add_box_collision(Vector3(0.35, 0.3, 0.4))
			var shoes_scene: PackedScene = load("res://assets/props/red_shoes.glb")
			if shoes_scene != null:
				var sinst := shoes_scene.instantiate()
				shoes.add_child(sinst)
			GameState.set_objective("闺房的妆奁盒上有八卦锁")
		"mirror":
			# 屏风后暗龛现出朱砂笔（谜题三产出，仪式所需）
			var PickupScript := load("res://scripts/interact/Pickup.gd")
			var pen: Pickup = PickupScript.new()
			pen.item_id = "cinnabar_pen"
			add_child(pen)
			pen.global_position = Vector3(6.6, 0.75, -9.3)
			pen.add_box_collision(Vector3(0.3, 0.3, 0.3))
			var pen_scene: PackedScene = load("res://assets/props/cinnabar_pen.glb")
			if pen_scene != null:
				var inst := pen_scene.instantiate()
				inst.scale = Vector3.ONE * 1.5
				pen.add_child(inst)
			var pedestal := world_builder._place_prop("chair_wood", Vector3(6.6, 0, -9.3), 0)
			GameState.set_objective("朱砂笔已到手 · 去扎纸作坊完成仪式")
		"ritual":
			GameState.set_objective("书架后有风 · 探寻密道")
		"bagua":
			pass  # 妆奁盒脚本自行处理

# ---------------------------------------------------------- 文档触发链
func _on_doc_read(doc_id: String) -> void:
	match doc_id:
		"doc_06_contract":
			scares.run_scare_forced("flashback_fire", player.global_position)
			hud.toast("六月十九的契约上按着过火烙下的掌印……和你右手掌心的烧疤，分毫不差。")
		"doc_04_diary_b":
			effects.red_flash(1.2)
			AudioMgr.play("sigh_woman", -8.0)
			hud.toast("日记停在中元前夜。第九尊男装替身……她早就知道你想替自己逃命了。")
		"doc_12_wedding_half":
			effects.red_flash(1.4)
			hud.toast("婚书上的「阿」字……你叫阿九。")
			if GameState.has_item("jade_pendant") and not GameState.get_flag("memory_jade_wedding"):
				GameState.set_flag("memory_jade_wedding")
				await get_tree().create_timer(2.2).timeout
				hud.toast("玉佩背面的「清欢」与婚书残页并在一起——四月里她笑着等你，七月里她至死不肯闭上眼。（记忆闪回）")
				effects.red_flash(1.8)
		"doc_11_blood_contract":
			# 首次拾取血书：先留在阅读器里读完；玩家合上后（_on_letter_closed）再启动过渡与追逐
			GameState.set_flag("finale_pending")
		"doc_10_blood_rules":
			hud.toast("血字像是警告，又像是……留给你的生存法则。")

# ---------------------------------------------------------- 终局追逐
func _start_finale() -> void:
	effects.set_chase_mode(true)
	AudioMgr.start_chase_music()
	for l in get_tree().get_nodes_in_group("house_lights"):
		if l is Light3D:
			l.light_color = Color(0.45, 0.85, 0.4).lerp(l.light_color, 0.25)
	env.fog_light_color = Color(0.4, 0.12, 0.08)
	env.volumetric_fog_albedo = Color(0.55, 0.2, 0.15)
	env.volumetric_fog_density = 0.05
	AudioMgr.play("suona_long", -2.0)
	# 墙安全巡逻路线：相邻点之间只穿过天井开阔区与正厅/祠堂门洞（x=0 直线）
	var wps := PackedVector3Array([
		Vector3(0, 0, 5), Vector3(0, 0, -6), Vector3(0, 0, -12),
		Vector3(0, 0, -21), Vector3(-4, 0, 0), Vector3(4, 0, 0),
	])
	bride.activate(wps)
	GameState.set_objective("逃！把玉佩放回天井的牌位前 · 或夺门而出（南门）")
	hud.toast("「灯莫明，步莫急，南门绝，中庭还玉。」——雾里传来急促的木屐声。")

# ---------------------------------------------------------- 死亡与重生
func _on_player_died(_reason: String) -> void:
	await get_tree().create_timer(2.2).timeout
	player.global_position = player.get_meta("respawn_pos", Vector3(-17.5, 0.15, -1.0))
	player.velocity = Vector3.ZERO
	effects.set_fade_black(1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: effects.set_fade_black(v), 1.0, 0.0, 1.4)
	bride.global_position = Vector3(0, 0, -2)
	bride.active = true
	bride.state = RedBride.State.PATROL
	hud.toast("又被她追上了……记住：熄灯下蹲藏住身形，别在廊下狂奔！")

# ---------------------------------------------------------- 全局输入
func _unhandled_input(event: InputEvent) -> void:
	if not _game_started:
		return
	if player != null and player.get("_input_locked"):
		return   # 主菜单/开场过渡/阅读器期间锁住全局 UI 快捷键
	if reader_ui.visible or inventory_ui.visible or inspect_ui.visible or pause_ui.visible:
		return
	if bell_ui.visible:
		return
	if event.is_action_pressed("inventory"):
		inventory_ui.open()
	elif event.is_action_pressed("journal"):
		inventory_ui.open()
		inventory_ui._on_show_docs()
	elif event.is_action_pressed("pause"):
		pause_ui.open()
