extends CanvasLayer
class_name PauseUI
## 暂停菜单（Esc）：继续 / 重开 / 退出

var _panel: PanelContainer

func _ready() -> void:
	layer = 95
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UITheme.paper_stylebox(24.0))
	_panel.custom_minimum_size = Vector2(320, 260)
	add_child(_panel)
	UITheme.center_panel(_panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)
	var t := UITheme.make_label("—— 暂 停 ——", 26, Color(0.35, 0.06, 0.05))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var resume := UITheme.make_button("继 续")
	resume.pressed.connect(close)
	vb.add_child(resume)
	var restart := UITheme.make_button("重 返 宅 门")
	restart.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	vb.add_child(restart)
	var quit := UITheme.make_button("离 开 山 谷")
	quit.pressed.connect(func() -> void: get_tree().quit())
	vb.add_child(quit)

func open() -> void:
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
