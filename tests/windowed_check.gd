extends Node
## 图形模式专项验证：主菜单鼠标、合信后视角捕获与解锁、终局南门交互
## 运行：Godot --path . res://tests/windowed_check.tscn（需要 GPU 窗口环境）

var _fails := 0
var _passes := 0

func _ok(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("  PASS ", label)
	else:
		_fails += 1
		print("  FAIL ", label)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _press_key(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode; down.keycode = keycode; down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.physical_keycode = keycode; up.keycode = keycode; up.pressed = false
	Input.parse_input_event(up)

func _click_button(btn: BaseButton) -> void:
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

func _find_button(root: Node, text: String) -> BaseButton:
	var stack := [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Button and (n as Button).text.replace(" ", "") == text.replace(" ", ""):
			return n
		for c in n.get_children():
			stack.push_back(c)
	return null

func _ready() -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await _wait(0.4)
	# 1. 主菜单：鼠标可见可点击
	var menu: MainMenu = main.get("main_menu")
	_ok(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE, "主菜单鼠标指针可见")
	var start := _find_button(main, "踏 入 宅 门")
	_ok(start != null, "开始按钮存在")
	await _click_button(start)
	await _wait(2.6)
	# 2. 委托信打开 → 输入锁定；Esc 合上 → 恢复捕获
	_ok(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE, "读信期间鼠标指针可见")
	_press_key(KEY_ESCAPE)
	await _wait(0.3)
	_ok(Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED, "合信后视角捕获恢复")
	var player: CharacterBody3D = main.get("player")
	_ok(player.get("_input_locked") == false, "合信后移动解锁")
	# 捕获鼠标后，移动事件的位置在准星中心。
	var camera: Camera3D = player.get("camera")
	var yaw_before := player.rotation.y
	var pitch_before := camera.rotation.x
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_visible_rect().get_center()
	motion.global_position = motion.position
	motion.relative = Vector2(35, 12)
	motion.screen_relative = motion.relative
	get_viewport().push_input(motion, true)
	_ok(absf(player.rotation.y - yaw_before) > 0.01 and absf(camera.rotation.x - pitch_before) > 0.01,
		"准星中心的鼠标移动能转动视角")
	player.rotation.y = yaw_before
	player.set("_pitch", pitch_before)
	camera.rotation.x = pitch_before
	# 3. 终局南门：剧情阶段置为终局后，正面按 E 触发伪结局
	GameState.set_flag("finale_pending", false)
	var wb: WorldBuilder = main.get("world_builder")
	var bride: RedBride = main.get("bride")
	var wps := PackedVector3Array([Vector3(0, 0, 5), Vector3(0, 0, -6), Vector3(0, 0, -12)])
	bride.activate(wps)
	GameState.start_finale()
	player.global_position = Vector3(0, 0.15, 6.5)
	player.rotation.y = PI
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.5)
	_ok(GameState.get_flag("ending_done"), "终局南门 E 触发伪结局")
	_ok(bride.active == false, "鬼影停止追逐")
	print("WINDOWED CHECK RESULT: pass=%d fail=%d" % [_passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)
