extends Node
## 交互回归测试（headless 可重复运行）：
## 全程通过"正常入口"注入键盘/鼠标事件——菜单点击、E 开门、面板按钮、G 抛灯、
## Tab 行囊、Esc 关信，而非直接调用谜题方法。
## 运行：Godot --headless --path . res://tests/input_regression.tscn

var _fails := 0
var _passes := 0
var main: Node

func _ok(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("  PASS ", label)
	else:
		_fails += 1
		print("  FAIL ", label)

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)   # headless 默认 64×64，先设定真实窗口尺寸
	await get_tree().process_frame
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# ---------------- 1. 主菜单点击开始 ----------------
	print("[1 主菜单]")
	var menu: MainMenu = main.get("main_menu")
	_ok(menu != null and menu.visible, "主菜单可见")
	var start_btn := _find_button(main, "踏 入 宅 门")
	_ok(start_btn != null, "找到「踏入宅门」按钮")
	await _click_button(start_btn)
	await _wait(2.4)
	var reader: ReaderUI = main.get("reader_ui")
	_ok(reader.visible, "委托信自动打开")
	var player: CharacterBody3D = main.get("player")

	# ---------------- 2. Esc 合信 → 方向提示 → WASD/鼠标 ----------------
	print("[2 开场流程]")
	_press_key(KEY_ESCAPE)
	await _wait(0.2)
	_ok(not reader.visible, "Esc 合上委托信")
	_ok(GameState.get_flag("hint_courtyard"), "出现开场方向提示")
	var p0: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _wait(0.6)
	Input.action_release("move_forward")
	_ok(player.global_position.z < p0.z - 0.3, "W 前进正常")
	var is_headless := DisplayServer.get_name() == "headless"
	if is_headless:
		print("  SKIP 鼠标转动/捕获（headless 无鼠标模式支持）")
	else:
		var yaw0: float = player.rotation.y
		var mm := InputEventMouseMotion.new()
		mm.relative = Vector2(240, 0)
		Input.parse_input_event(mm)
		await get_tree().process_frame
		await get_tree().physics_frame
		_ok(absf(player.rotation.y - yaw0) > 0.05, "鼠标转动视角正常")
		_ok(Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED, "鼠标已捕获")

	# ---------------- 3. E 开正厅门并穿过门洞 ----------------
	print("[3 正厅门]")
	player.global_position = Vector3(0, 0.15, -7.0)
	player.rotation.y = 0.0
	player.set("_pitch", 0.0)
	var cam: Camera3D = player.get("camera")
	if cam != null:
		cam.rotation.x = 0.0
	var wb: WorldBuilder = main.get("world_builder")
	var hall_door: Door = wb.find_child("HallSouthDoor", true, false)
	_ok(hall_door != null, "正厅门存在")
	await _wait(0.3)
	_press_key(KEY_E)
	await _wait(1.4)
	_ok(hall_door._open, "E 后门脚本状态开启")
	var leaf: Node3D = hall_door.get_parent()
	_ok(leaf.rotation.y > 1.2, "门扇动画已播放（rotation=%.2f）" % leaf.rotation.y)
	Input.action_press("move_forward")
	await _wait(1.8)
	Input.action_release("move_forward")
	_ok(player.global_position.z < -8.4, "穿过门洞进入正厅 z=%.2f" % player.global_position.z)

	# ---------------- 4. 祠堂门（正厅 → 祠堂） ----------------
	print("[4 祠堂门]")
	player.global_position = Vector3(0, 0.15, -16.0)
	player.rotation.y = 0.0
	await _wait(0.3)
	_press_key(KEY_E)
	await _wait(1.4)
	var shrine_door: Door = wb.find_child("ShrineDoor", true, false)
	_ok(shrine_door != null and shrine_door._open, "祠堂门开启")
	Input.action_press("move_forward")
	await _wait(1.6)
	Input.action_release("move_forward")
	_ok(player.global_position.z < -17.6, "穿过门洞进入祠堂 z=%.2f" % player.global_position.z)

	# ---------------- 5. 八卦锁（界面按钮操作 + 提交） ----------------
	print("[5 八卦锁]")
	player.global_position = Vector3(14.2, 0.15, -1.0)
	player.rotation.y = -PI / 2.0       # 面向东墙妆奁盒（盒子在玩家东侧）
	player.set("_pitch", -0.85)
	if cam != null:
		cam.rotation.x = -0.85
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.4)
	var lock: BaguaLock = wb.bagua_lock
	_ok(lock.visible, "E 打开八卦锁面板")
	_ok(get_tree().paused, "面板暂停游戏")
	# 逐位拨盘至手札目标（由初始本位 → 目标位）
	for dir in lock.TARGET:
		var a: int = lock.TRIGRAM_CYCLE.find(String(lock.STANDARD[dir]))
		var b: int = lock.TRIGRAM_CYCLE.find(String(lock.TARGET[dir]))
		var clicks := (b - a + 8) % 8
		for i in clicks:
			await _click_button(lock._sector_buttons[dir])
	# 中心五行钮：金 → 水
	var elem_clicks: int = (lock.ELEMENTS.find(BaguaLock.TARGET_ELEMENT) - lock.ELEMENTS.find("金") + 5) % 5
	for i in elem_clicks:
		await _click_button(lock._element_button)
	var submit := _find_button(lock._panel, "推 锁 芯")
	_ok(submit != null, "找到提交按钮")
	await _click_button(submit)
	await _wait(1.4)
	_ok(GameState.get_flag("puzzle_bagua"), "八卦锁提交后解锁")
	_ok(not lock.visible and not get_tree().paused, "面板延迟关闭并恢复游戏")
	var jade := _find_pickup("jade_pendant")
	_ok(jade != null, "妆奁盒产出玉佩奖励")

	# ---------------- 6. 铜铃（错误时辰 → 正确三响 → 暗门） ----------------
	print("[6 铜铃]")
	var bell_ui: BellUI = main.get("bell_ui")
	var pr: PaperRitual = wb.paper_ritual
	pr.phase = 3   # 测试前置：点睛/香序已由 playthrough 覆盖，此处直入第三步
	player.global_position = Vector3(-10.5, 0.15, -0.9)
	player.rotation.y = PI
	player.set("_pitch", -0.11)
	if cam != null:
		cam.rotation.x = -0.11
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.4)
	_ok(bell_ui.visible, "E 打开铜铃面板")
	# 错误时辰：面板反馈 + 重置，不关闭
	var wrong_btn := _find_button(bell_ui._panel, "子时二刻")
	await _click_button(wrong_btn)
	var ring_btn := _find_button(bell_ui._panel, "敲 响（三声）")
	await _click_button(ring_btn)
	await _wait(0.2)
	_ok(bell_ui.visible, "错误时辰后面板保持打开")
	_ok(pr._bell_rings == 0 and pr._bell_chosen == "", "错误时辰已重置")
	# 正确时辰三响：一次打开面板内完成
	var ok_btn := _find_button(bell_ui._panel, "子时三刻")
	await _click_button(ok_btn)
	await _click_button(ring_btn)
	await _wait(0.2)
	_ok(pr._bell_rings == 1 and bell_ui.visible, "第一响后面板仍在（1/3）")
	await _click_button(ring_btn)
	await _wait(0.2)
	_ok(pr._bell_rings == 2 and bell_ui.visible, "第二响后面板仍在（2/3）")
	await _click_button(ring_btn)
	await _wait(1.5)
	_ok(GameState.get_flag("puzzle_ritual"), "三响完成 → 仪式解开")
	_ok(not bell_ui.visible and not get_tree().paused, "完成后面板关闭并恢复游戏")
	_ok(wb.bookshelf_blocker == null or not is_instance_valid(wb.bookshelf_blocker), "书架障碍已移除")
	await _wait(0.5)   # 等书架滑行动画（1.6s）完成
	var shelf := wb.find_child("SecretShelf", true, false) as Node3D
	_ok(shelf != null and shelf.position.z < -3.0, "书架已滑开让出门洞")

	# ---------------- 7. 穿过暗门进密室 ----------------
	print("[7 暗门通行]")
	player.global_position = Vector3(-13.8, 0.15, -1.0)
	player.rotation.y = PI / 2.0   # 面西
	player.set("_pitch", 0.0)
	if cam != null:
		cam.rotation.x = 0.0
	await _wait(0.3)
	Input.action_press("move_forward")
	await _wait(2.4)
	Input.action_release("move_forward")
	_ok(player.global_position.x < -16.5, "穿过暗门进入密室 x=%.2f" % player.global_position.x)

	# ---------------- 8. 抛灯与拾回 ----------------
	print("[8 抛灯拾回]")
	player.global_position = Vector3(2.5, 0.15, 3.0)
	player.rotation.y = 0.0
	await _wait(0.3)
	_press_key(KEY_G)
	await _wait(1.0)
	var thrown := _find_pickup("hand_lantern_thrown")
	_ok(thrown != null, "灯笼已抛出为可拾取对象")
	_ok(thrown != null and thrown.get_child_count() > 0 and _has_collision(thrown), "抛出灯笼带交互碰撞")
	_ok(not player.get("_lantern_on"), "抛出后手持照明熄灭")
	if thrown != null:
		player.global_position = thrown.global_position + Vector3(0.9, 0.15, 0)
		player.rotation.y = PI / 2.0    # 面西朝灯笼（灯笼在玩家西侧）
		player.set("_pitch", -1.05)     # 俯视地上的灯笼
		if cam != null:
			cam.rotation.x = -1.05
		await _wait(0.4)
		_press_key(KEY_E)
		await _wait(0.4)
	_ok(player.get("_lantern_on"), "E 拾回并恢复手持照明")
	_ok(_find_pickup("hand_lantern_thrown") == null, "场景中无残留灯笼对象")

	# ---------------- 9. 鬼影：隔墙脱身 / 开阔被抓 ----------------
	print("[9 鬼影追逐]")
	var bride: RedBride = main.get("bride")
	bride.activate(PackedVector3Array([
		Vector3(0, 0, 5), Vector3(0, 0, -6), Vector3(0, 0, -12),
		Vector3(0, 0, -21), Vector3(-4, 0, 0), Vector3(4, 0, 0)]))
	player.global_position = Vector3(3, 0.15, -16.6)   # 正厅内
	bride.global_position = Vector3(3, 0, -17.4)       # 墙（z=-17）另一侧
	bride.active = true
	bride.state = RedBride.State.CHASE
	bride._lose_timer = 99.0
	await _wait(1.5)
	_ok(player.global_position.distance_to(Vector3(3, 0.15, -16.6)) < 0.5,
		"隔实体墙时不会捕获（未重生）")
	bride.global_position = Vector3(3, 0, -16.9)       # 同一房间贴脸
	await _wait(3.0)
	_ok(player.global_position.distance_to(Vector3(-17.5, 0.15, -1.0)) < 1.0,
		"开阔处被抓后正常重生到密室门口")
	_ok(bride.active, "重生后追逐继续")

	# ---------------- 10. 960×540 窗口适配 + 重开主菜单 ----------------
	print("[10 窗口适配与重开]")
	get_window().size = Vector2i(960, 540)
	await _wait(0.3)
	var vp_size := get_viewport().get_visible_rect().size
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var menu2: MainMenu = main.get("main_menu")
	var start2 := _find_button(main, "踏 入 宅 门")
	_ok(menu2.visible and start2 != null, "重开后主菜单可见")
	var r: Rect2 = start2.get_global_rect()
	_ok(r.position.x >= 0 and r.end.x <= vp_size.x and r.position.y >= 0 and r.end.y <= vp_size.y,
		"按钮在 960×540 屏幕内")
	await _click_button(start2)
	await _wait(2.4)
	var reader2: ReaderUI = main.get("reader_ui")
	_ok(reader2.visible, "重开后委托信仍可打开")
	var pr_rect: Rect2 = reader2._panel.get_global_rect()
	_ok(pr_rect.position.x >= 0 and pr_rect.end.x <= vp_size.x and pr_rect.position.y >= -8
		and pr_rect.end.y <= vp_size.y + 8, "信件面板在 960×540 内")
	_press_key(KEY_ESCAPE)
	await _wait(0.2)
	_ok(not reader2.visible, "960×540 下合上委托信")
	_press_key(KEY_TAB)
	await _wait(0.3)
	var inv: InventoryUI = main.get("inventory_ui")
	_ok(inv.visible, "Tab 打开行囊")
	var inv_rect: Rect2 = inv._panel.get_global_rect()
	_ok(inv_rect.position.x >= 0 and inv_rect.end.x <= vp_size.x and inv_rect.position.y >= 0
		and inv_rect.end.y <= vp_size.y, "行囊面板在 960×540 内")
	_press_key(KEY_TAB)
	await _wait(0.3)
	_ok(not inv.visible and not get_tree().paused, "行囊关闭并恢复游戏")
	get_window().size = Vector2i(1280, 720)

	print("INPUT REGRESSION RESULT: pass=%d fail=%d" % [_passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# ============================================================ 输入工具
func _press_key(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode
	down.keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.physical_keycode = keycode
	up.keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)

func _click_button(btn: BaseButton) -> void:
	if btn == null:
		return
	var pos := (btn as Control).get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _find_button(root: Node, text: String) -> BaseButton:
	_found = null
	_walk(root, func(n: Node) -> void:
		if n is BaseButton and _found == null:
			var t: String = (n as Button).text if n is Button else ""
			if t.replace(" ", "") == text.replace(" ", ""):
				_found = n)
	return _found as BaseButton

var _found: Node = null

func _find_pickup(item_id: String) -> Pickup:
	_found = null
	_walk(self, func(n: Node) -> void:
		if n is Pickup and n.item_id == item_id and _found == null:
			_found = n)
	return _found as Pickup

func _has_collision(body: PhysicsBody3D) -> bool:
	for c in body.get_children():
		if c is CollisionShape3D and c.shape != null:
			return true
	return false

func _walk(node: Node, fn: Callable) -> void:
	fn.call(node)
	for c in node.get_children():
		_walk(c, fn)
