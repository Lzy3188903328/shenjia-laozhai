extends CanvasLayer
class_name WindowPaperUI
## 查看压纹近景（玩法扩展 §三）：左右灯位按钮完成同一观察，供难以细调视角的玩家
## 辨认纹样后记入线索册；若铜镜已解，文案改为「正是花厅那扇屏风」

var _paper: WindowPaper
var _panel: PanelContainer
var _lamp_left: Button
var _lamp_right: Button
var _recognize: Button
var _view: Control
var _view_alpha := 0.0
var _lamp_side := 0   # -1 左 / +1 右 / 0 未定
var _recorded := false

func _ready() -> void:
	add_to_group("window_paper_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	_panel = PanelContainer.new()
	_panel.add_to_group("paper_panel")
	UITheme.center_panel(_panel)
	_panel.custom_minimum_size = Vector2(620, 480)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)
	var title := UITheme.make_label("— 压 痕 窗 纸 —", 24, Color(0.3, 0.08, 0.05))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var hint := UITheme.make_label("妆奁边取下的旧窗纸。换着灯位照，才照得出压过的纹样。", 16, Color(0.35, 0.28, 0.2))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	# 纸面视图（左右灯位渐显纹样）
	_view = Control.new()
	_view.custom_minimum_size = Vector2(560, 220)
	_view.draw.connect(_draw_view)
	vb.add_child(_view)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	_lamp_left = UITheme.make_button("左 灯 位")
	_lamp_left.pressed.connect(func() -> void: _set_lamp(-1))
	hb.add_child(_lamp_left)
	_lamp_right = UITheme.make_button("右 灯 位")
	_lamp_right.pressed.connect(func() -> void: _set_lamp(1))
	hb.add_child(_lamp_right)
	var hb2 := HBoxContainer.new()
	hb2.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb2)
	_recognize = UITheme.make_button("辨 认 纹 样")
	_recognize.pressed.connect(_on_recognize)
	_recognize.disabled = true
	hb2.add_child(_recognize)
	var close_b := UITheme.make_button("放 下")
	close_b.pressed.connect(close)
	hb2.add_child(close_b)

func _draw_view() -> void:
	var c := _view.size * 0.5
	# 纸面
	_view.draw_rect(Rect2(c - Vector2(230, 90), Vector2(460, 180)), Color(0.82, 0.76, 0.62))
	# 蜡痕
	for x in [-190.0, 190.0]:
		_view.draw_circle(c + Vector2(x, 70), 8.0, Color(0.9, 0.82, 0.55))
	# 灯位示意（当前选择）
	if _lamp_side != 0:
		var lx := c.x + _lamp_side * 190.0
		_view.draw_circle(Vector2(lx, c.y - 80), 10.0, Color(1.0, 0.8, 0.35))
		_view.draw_line(Vector2(lx, c.y - 80), c + Vector2(0, 0), Color(1.0, 0.75, 0.3, 0.35), 2.0)
	# 纹样（按灯位渐显：左灯出左半、右灯出右半、两侧都照完整）
	var alpha := _view_alpha
	if alpha > 0.01:
		var col := Color(0.35, 0.1, 0.08, alpha)
		var left_half := _lamp_side <= 0
		var right_half := _lamp_side >= 0
		# 折枝
		_view.draw_line(c + Vector2(-90, 40), c + Vector2(-30, -10), col, 3.0)
		_view.draw_line(c + Vector2(-30, -10), c + Vector2(40, -30), col, 3.0)
		if right_half:
			_view.draw_line(c + Vector2(40, -30), c + Vector2(90, 20), col, 3.0)
		# 花瓣（缺瓣：右上缺）
		_view.draw_arc(c + Vector2(-40, -20), 26.0, 0.6, 2.6, 16, col, 3.0)
		_view.draw_arc(c + Vector2(-40, -20), 26.0, 3.2, 4.4, 16, col, 3.0)
		if left_half:
			_view.draw_arc(c + Vector2(-40, -20), 26.0, 4.6, 5.6, 12, col, 3.0)
		# 「花厅」题字
		var f := UITheme.get_font()
		if f != null:
			_view.draw_string(f, c + Vector2(120, -60), "花厅",
				HORIZONTAL_ALIGNMENT_LEFT, 120, 30, col)

func _set_lamp(side: int) -> void:
	_lamp_side = side
	_view_alpha = minf(_view_alpha + 0.6, 1.0)
	_view.queue_redraw()
	AudioMgr.play("paper_flip", -10.0)
	if _view_alpha >= 1.0:
		_recognize.disabled = false

func _on_recognize() -> void:
	if _paper == null:
		return
	_record()

func _record() -> void:
	if _recorded:
		return
	_recorded = true
	GameState.add_doc("doc_14_window_rubbing")
	AudioMgr.play("puzzle_success", -10.0)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		if GameState.get_flag("puzzle_mirror"):
			hud.toast("正是花厅那扇屏风——缺瓣的花纹对上了。")
		else:
			hud.toast("阿九记下：「花厅门上，也有这样一枝缺瓣的花。」")
			main_refresh_objective()
	close()

func main_refresh_objective() -> void:
	var m := get_tree().get_first_node_in_group("main")
	if m != null and m.has_method("_refresh_objective"):
		m._refresh_objective()

func open_ui(paper: WindowPaper) -> void:
	_paper = paper
	_view_alpha = 0.0
	_lamp_side = 0
	_recognize.disabled = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
