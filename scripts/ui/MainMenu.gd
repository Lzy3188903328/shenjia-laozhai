extends CanvasLayer
class_name MainMenu
## 主菜单：水墨风标题 / 开始 / 退出（drone 底噪）

signal start_requested

var _root: Control

func _ready() -> void:
	layer = 100
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.025)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.paper_stylebox(30.0))
	panel.custom_minimum_size = Vector2(460, 420)
	_root.add_child(panel)
	UITheme.center_panel(panel)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var title := UITheme.make_label("沈 家 老 宅", 44, Color(0.4, 0.05, 0.04))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := UITheme.make_label("—— 中式民俗悬疑解谜 ——", 17, Color(0.35, 0.28, 0.2))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	var sep := ColorRect.new()
	sep.color = Color(0.45, 0.08, 0.05, 0.4)
	sep.custom_minimum_size = Vector2(0, 2)
	vb.add_child(sep)

	var hint := UITheme.make_label(
		"雨夜叩门自开。\n\nWASD 移动 · Shift 狂奔 · Ctrl 下蹲\nE 交互 · F 灯笼 · G 抛灯\nTab 行囊 · J 线索册 · Esc 暂停\n\n灯火发绿时——有什么在附近醒着。",
		16, Color(0.3, 0.24, 0.18))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

	var start := UITheme.make_button("踏 入 宅 门", 26)
	start.pressed.connect(func() -> void: start_requested.emit())
	vb.add_child(start)
	var quit := UITheme.make_button("离 开", 20)
	quit.pressed.connect(func() -> void: get_tree().quit())
	vb.add_child(quit)

	var seal := UITheme.make_label("朱", 30, Color(0.55, 0.1, 0.08))
	_root.add_child(seal)
	seal.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	seal.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	seal.grow_vertical = Control.GROW_DIRECTION_BEGIN
	seal.position = Vector2(-90, -70)
	seal.rotation_degrees = 12

func hide_menu() -> void:
	_root.visible = false
