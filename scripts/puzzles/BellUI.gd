extends CanvasLayer
class_name BellUI
## 铜铃时辰选择面板：一次打开完成三声敲击，显示所选时辰与 n/3 进度；
## 时辰错误在面板上反馈并按谜题规则重置；Esc/退出按钮恢复移动与视角。

const HOURS := ["子初", "子时一刻", "子时二刻", "子时三刻", "子时四刻", "丑初"]

var ritual: PaperRitual
var _panel: PanelContainer
var _status: Label
var _hint: Label

func _ready() -> void:
	add_to_group("bell_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS   # 面板暂停游戏时自身仍接收输入
	layer = 30
	_build()
	visible = false

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_to_group("paper_panel")
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(400, 300)
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "铜 铃 择 时"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	UITheme.apply_theme(title)
	vb.add_child(title)
	var hour_row := HBoxContainer.new()
	hour_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hour_row)
	for h in HOURS:
		var b := UITheme.make_button(h, 16)
		b.custom_minimum_size = Vector2(100, 44)
		b.pressed.connect(_on_hour.bind(h))
		hour_row.add_child(b)
	_hint = UITheme.make_label("择定时辰后，敲响三声。", 15, Color(0.35, 0.28, 0.2))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_hint)
	_status = UITheme.make_label("", 19, Color(0.4, 0.08, 0.05))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(380, 34)
	vb.add_child(_status)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	var ring := UITheme.make_button("敲 响（三声）")
	ring.pressed.connect(_on_ring)
	hb.add_child(ring)
	var close_b := UITheme.make_button("退 开")
	close_b.pressed.connect(close)
	hb.add_child(close_b)
	add_child(_panel)
	UITheme.center_panel(_panel)

func open_bell(r: PaperRitual) -> void:
	ritual = r
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_status()

func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()

func _on_hour(h: String) -> void:
	AudioMgr.play("unlock_click", -8.0)
	if ritual != null:
		ritual.choose_bell_hour(h)
		_refresh_status()

func _on_ring() -> void:
	if ritual == null:
		return
	var msg: String = ritual.ring_bell()
	if GameState.get_flag("puzzle_ritual"):
		# 三声齐 → 完成仪式，稍候关窗（暗门在 ritual.completed 已触发）
		_status.add_theme_color_override("font_color", Color(0.2, 0.35, 0.15))
		_status.text = "钟鸣三声——灯影一晃，书架后有风。"
		var tw := create_tween()
		tw.tween_interval(1.1)
		tw.tween_callback(close)
		return
	_refresh_status(msg)

func _refresh_status(err: String = "") -> void:
	_status.add_theme_color_override("font_color", Color(0.4, 0.08, 0.05))
	if err != "":
		_status.text = err
		return
	if ritual == null or ritual.phase != 3:
		_status.text = "（香未齐、睛未点——铃不认人。）"
		return
	if ritual._bell_chosen == "":
		_status.text = "请先择一个时辰。"
	elif ritual._bell_rings == 0:
		_status.text = "已择「%s」· 待敲 0/3" % ritual._bell_chosen
	else:
		_status.text = "已择「%s」· 响 %d/3" % [ritual._bell_chosen, ritual._bell_rings]
