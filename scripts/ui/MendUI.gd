extends CanvasLayer
class_name MendUI
## 补扎替身（玩法扩展 §二）：作坊侧桌的桌面近景
## 两片襟纸 + 一根红线 + 两个线孔：按穿衣者左右压襟（左衽：左压右），选对孔位收紧；
## 压反翘角、错孔红线横过领口；错两次可「对照旧衣」；成功后「翻开内襟」见「自用」；
## 持纸人头可「对一对断口」。相同发现只入册一次；追逐/结局开始后停用。

var _chest: Interactable
var _panel: PanelContainer
var _view: Control
var _status: Label
var _btn_mend: Button
var _btn_flap_inner: Button
var _btn_compare: Button

# 迷你游戏状态（保留已做对的步骤）
var _picked_first := ""       # 先选中的襟片："L" / "R"
var _overlap_done := ""       # 已压好的方向："LoverR"（正确 左压右）/ "RoverL"（压反，会翘）
var _hole_done := ""          # 已穿孔："low"（对旧折痕）/ "high"（横过领口）
var _error_count := 0
var _mend_done := false
var _inner_open := false
var _compared := false

const FLAP_NAMES := {"L": "左襟", "R": "右襟"}

func _ready() -> void:
	add_to_group("mend_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	_panel = PanelContainer.new()
	_panel.add_to_group("paper_panel")
	UITheme.center_panel(_panel)
	_panel.custom_minimum_size = Vector2(860, 640)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)
	var title := UITheme.make_label("— 补 扎 替 身 —", 24, Color(0.3, 0.08, 0.05))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var hint := UITheme.make_label("两片襟纸各带一根半脱的竹篾。照穿衣者的左右压好，再穿线收紧。", 15, Color(0.35, 0.28, 0.2))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	_view = Control.new()
	_view.custom_minimum_size = Vector2(820, 360)
	_view.draw.connect(_draw_view)
	# 热区按钮（补扎点击用按钮实现——按钮在暂停下可点击，与八卦锁同一机制）
	var hot_names := {"L": "左襟", "R": "右襟", "hole_hi": "上孔", "hole_lo": "下孔"}
	for slot in ["L", "R", "hole_hi", "hole_lo"]:
		var hb := Button.new()
		hb.name = "Hot_" + slot
		hb.text = hot_names[slot]
		hb.flat = true
		hb.add_theme_font_size_override("font_size", 16)
		var f := UITheme.get_font()
		if f != null:
			hb.add_theme_font_override("font", f)
		hb.add_theme_color_override("font_color", Color(0.3, 0.15, 0.1))
		hb.add_theme_color_override("font_hover_color", Color(0.55, 0.1, 0.06))
		hb.pressed.connect(_activate_slot.bind(slot))
		_view.add_child(hb)
	vb.add_child(_view)
	_view.resized.connect(_place_hotspots)
	_status = UITheme.make_label("", 17, Color(0.4, 0.08, 0.05))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(800, 34)
	vb.add_child(_status)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	_btn_mend = UITheme.make_button("收 紧")
	_btn_mend.pressed.connect(_on_mend)
	hb.add_child(_btn_mend)
	_btn_flap_inner = UITheme.make_button("翻 开 内 襟")
	_btn_flap_inner.pressed.connect(_on_inner)
	_btn_flap_inner.disabled = true
	hb.add_child(_btn_flap_inner)
	_btn_compare = UITheme.make_button("对 照 旧 衣")
	_btn_compare.pressed.connect(_on_compare)
	_btn_compare.visible = false
	hb.add_child(_btn_compare)
	_btn_compare.set_meta("compare_ok", false)
	var btn_head := UITheme.make_button("对 一 对 断 口")
	btn_head.pressed.connect(_on_compare_gap)
	btn_head.visible = false
	btn_head.name = "BtnGap"
	hb.add_child(btn_head)
	var close_b := UITheme.make_button("离 开 桌 案")
	close_b.pressed.connect(close)
	hb.add_child(close_b)

func open_ui(chest: Interactable) -> void:
	_chest = chest
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	call_deferred("_place_hotspots")
	_refresh()
	_view.queue_redraw()

func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _place_hotspots() -> void:
	## 视图布局完成后把四个热区按钮放到对应位置（视图尺寸变化时跟随）
	for slot in ["L", "R", "hole_hi", "hole_lo"]:
		var b := _view.get_node_or_null("Hot_" + slot) as Button
		if b != null:
			var rect := _hotspot_rect(slot)
			b.position = rect.position
			b.size = rect.size

func _refresh() -> void:
	_btn_flap_inner.disabled = not _mend_done
	_btn_compare.visible = _error_count >= 2 or _compared
	_btn_mend.disabled = _overlap_done == "" or _hole_done == ""
	var btn_head := _find_gap_button()
	btn_head.visible = GameState.has_item("paper_head")
	if _mend_done:
		_status.text = "领襟压好了。翻看内襟看看。"
	elif _overlap_done == "RoverL":
		_status.text = "压反了——右襟翘起来顶着，旧折痕对不上。"
	elif _hole_done == "high":
		_status.text = "红线横过了领口，盖住旧线留下的浅印。这一步不对。"
	elif _overlap_done == "LoverR":
		_status.text = "襟口压平了：左衽压右，和旧折痕严丝合缝。选个线孔收紧。"
	elif _picked_first != "":
		_status.text = "%s已拿起。再把另一片的下缘压进去。" % FLAP_NAMES[_picked_first]
	else:
		_status.text = "先拿起一片襟纸。"
	_view.queue_redraw()

func _find_gap_button() -> Button:
	for c in _panel.find_children("*", "Button", true, false):
		if c.name.begins_with("Btn") or (c as Button).text == "对 一 对 断 口":
			if (c as Button).text == "对 一 对 断 口":
				return c
	return null

# ---------------------------------------------------------- 桌面近景绘制
func _draw_collar(center: Vector2, scale: float, mirrored: bool, lifted: bool, col: Color) -> void:
	## 完好小纸衣的领襟：左衽（左压右），供对照
	var pts := PackedVector2Array([
		Vector2(-70, -80), Vector2(70, -80), Vector2(90, 30),
		Vector2(50, 85), Vector2(-50, 85), Vector2(-90, 30),
	])
	var flip := -1.0 if mirrored else 1.0
	var xf := Transform2D(0.0, center) * Transform2D(0.0, Vector2.ZERO) * Transform2D(0.0, Vector2.ZERO)
	var world_pts := PackedVector2Array()
	for p in pts:
		var q := Vector2(p.x * scale * flip, p.y * scale)
		if lifted:
			q.y -= 10
		world_pts.append(center + q)
	_view.draw_colored_polygon(world_pts, col)
	for i in world_pts.size():
		var a := world_pts[i]
		var b := world_pts[(i + 1) % world_pts.size()]
		_view.draw_line(a, b, Color(0.45, 0.3, 0.2), 2.5)
	# 左衽压线（左片搭在右片上的折线）
	_view.draw_line(world_pts[0] + Vector2(6, 0), world_pts[3] + Vector2(-6, -4), Color(0.5, 0.1, 0.08), 2.5)

func _draw_view() -> void:
	var c := _view.size * 0.5
	var f := UITheme.get_font()
	# 桌面
	_view.draw_rect(Rect2(c - Vector2(400, 160), Vector2(800, 320)), Color(0.36, 0.26, 0.17))
	# 完好的小纸衣（左上，作参照）
	_draw_collar(c + Vector2(-300, -100), 0.7, false, false, Color(0.85, 0.8, 0.7))
	var lbl := "小纸衣 · 领襟压向左"
	if f != null:
		_view.draw_string(f, c + Vector2(-370, -160), lbl, HORIZONTAL_ALIGNMENT_LEFT, 200, 16, Color(0.5, 0.42, 0.3))
	# 待修胸架（中央）
	var chest_col := Color(0.88, 0.83, 0.72)
	_view.draw_rect(Rect2(c - Vector2(120, 110), Vector2(240, 220)), chest_col)
	# 竹篾（每片襟纸一根半脱的竹篾）
	_view.draw_line(c + Vector2(-110, -100), c + Vector2(-20, -100), Color(0.5, 0.42, 0.25), 4.0)
	_view.draw_line(c + Vector2(20, 90), c + Vector2(110, 90), Color(0.5, 0.42, 0.25), 4.0)
	# 旧折痕（虚线示意：左衽压痕应在的位置）
	for k in 7:
		var x0 := c.x - 100 + k * 28.0
		_view.draw_line(Vector2(x0, c.y - 60), Vector2(x0 + 10, c.y + 60), Color(0.4, 0.3, 0.2, 0.5), 2.0)
	# 襟片状态
	var l_sel := _picked_first == "L"
	var r_sel := _picked_first == "R"
	# 右襟（画在底：若左压右则被盖住一半）
	var r_lift := _overlap_done == "RoverL" and _hole_done != "low"
	var r_off := Vector2(60 if r_sel else 0, -14 if r_lift else 0)
	var r_rot := 0.18 if r_lift else 0.0
	_draw_flap(c + Vector2(40, 0) + r_off, r_rot, "R", Color(0.82, 0.76, 0.6))
	# 左襟（压在上面：正确结果）
	var l_lift := _overlap_done == "LoverR" and _hole_done != "low"
	_draw_flap(c + Vector2(-40, 0) + (Vector2(60, 10) if l_lift else Vector2(0, 0)), 0.0, "L", Color(0.9, 0.85, 0.72))
	# 红线与线孔
	var hole_hi := c + Vector2(-10, -70)
	var hole_lo := c + Vector2(-10, 70)
	_view.draw_circle(hole_hi, 9.0, Color(0.5, 0.1, 0.08))
	_view.draw_circle(hole_lo, 9.0, Color(0.5, 0.1, 0.08))
	if _hole_done == "low":
		_view.draw_line(c + Vector2(-90, -60), hole_lo, Color(0.62, 0.1, 0.08), 3.0)
		_view.draw_line(hole_lo, c + Vector2(80, 60), Color(0.62, 0.1, 0.08), 3.0)
	elif _hole_done == "high":
		# 错孔：红线横过领口，盖住旧线浅印
		_view.draw_line(c + Vector2(-120, 0), hole_hi, Color(0.62, 0.1, 0.08), 3.0)
		_view.draw_line(hole_hi, c + Vector2(120, 0), Color(0.62, 0.1, 0.08), 3.0)
	# 若翻开内襟：显示左衽收线与「自用」墨字
	if _inner_open:
		_view.draw_rect(Rect2(c + Vector2(-140, -150), Vector2(280, 120)), Color(0.78, 0.72, 0.58))
		for k in 6:
			_view.draw_line(c + Vector2(-120 + k * 40, -140), c + Vector2(-100 + k * 40, -50), Color(0.5, 0.1, 0.08, 0.8), 3.0)
		if f != null:
			_view.draw_string(f, c + Vector2(-130, -40), "自用", HORIZONTAL_ALIGNMENT_LEFT, 120, 22, Color(0.45, 0.08, 0.06))
	if _compared:
		if f != null:
			_view.draw_string(f, c + Vector2(-370, 140), "颈圈断口与纸人头里的竹篾，一根根对上了。",
				HORIZONTAL_ALIGNMENT_LEFT, 300, 16, Color(0.45, 0.3, 0.2))

func _draw_flap(center: Vector2, rot: float, side: String, col: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(-80, -90), center + Vector2(80, -90),
		center + Vector2(100, 40), center + Vector2(60, 100), center + Vector2(-60, 100),
		center + Vector2(-100, 40),
	])
	var xf := Transform2D(rot, center)
	var world_pts := PackedVector2Array()
	for p in pts:
		world_pts.append(xf * p)
	_view.draw_colored_polygon(world_pts, col)
	# 襟边描线 + 竹篾
	for i in world_pts.size():
		var a := world_pts[i]
		var b := world_pts[(i + 1) % world_pts.size()]
		_view.draw_line(a, b, Color(0.45, 0.3, 0.2), 3.0)
	_view.draw_line(world_pts[0] + Vector2(0, 0), world_pts[5] + Vector2(0, 0), Color(0.5, 0.42, 0.25), 4.0)
	# 热区标记（可点击区域）
	var hot := _hotspot_rect(side)
	if hot.size.x > 0:
		_view.draw_rect(Rect2(hot.position - _view.position, hot.size), Color(0.3, 0.6, 0.9, 0.08), false, 2.0)

func _hotspot_rect(side: String) -> Rect2:
	var c := _view.size * 0.5
	match side:
		"L":
			return Rect2(c + Vector2(-140, -100), Vector2(180, 200))
		"R":
			return Rect2(c + Vector2(-10, -90), Vector2(200, 210))
		"hole_hi":
			return Rect2(c + Vector2(-30, -90), Vector2(40, 40))
		"hole_lo":
			return Rect2(c + Vector2(-30, 50), Vector2(40, 40))
	return Rect2()

# ---------------------------------------------------------- 交互
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
		return
	# 鼠标热区点击由 _view.gui_input 处理；此处保留键盘光标路径
	# 方向键移动光标 + 确认键（与鼠标等价）
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		var step := -1 if event.is_action_pressed("ui_left") else 1
		var order := ["", "L", "R", "hole_hi", "hole_lo"]
		_kbd_index = clampi(_kbd_index + step, 0, order.size() - 1)
		_kbd_slot = order[_kbd_index]
		_view.queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate_slot(_kbd_slot)
		get_viewport().set_input_as_handled()

var _kbd_slot := ""
var _kbd_index := 0

func _activate_slot(slot: String) -> void:
	if slot == "":
		return
	match slot:
		"L", "R":
			if _overlap_done != "":
				return   # 已压好，保留正确部分
			if _picked_first == "":
				_picked_first = slot
				AudioMgr.play("paper_flip", -10.0)
			else:
				# 两片都选定 → 得到压襟方向
				if _picked_first == "L" and slot == "R":
					_overlap_done = "LoverR"    # 左衽：左压右 ✓
				else:
					_overlap_done = "RoverL"    # 压反 ✗
				AudioMgr.play("unlock_click", -6.0)
		"hole_hi", "hole_lo":
			if _overlap_done == "":
				return
			_hole_done = "high" if slot == "hole_hi" else "low"
			AudioMgr.play("paper_flip", -8.0)
	_refresh()

func _on_mend() -> void:
	# 收紧：校验压襟方向与孔位
	if _overlap_done == "":
		_status.text = "还没压襟，收什么线？"
		_view.queue_redraw()
		return
	if _hole_done == "":
		_status.text = "线孔还没选。"
		_view.queue_redraw()
		return
	if _overlap_done == "LoverR" and _hole_done == "low":
		_mend_done = true
		AudioMgr.play("puzzle_success", -8.0)
		# 记录「胸架已补」（只入册一次）
		GameState.add_doc("doc_13_mend_note")
		GameState.set_flag("mend_done")
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("toast"):
			hud.toast("襟口压平了——这一手，和作坊里那些纸人一个手势。")
	else:
		_error_count += 1
		AudioMgr.play("puzzle_fail", -10.0)
		# 收紧失败只松开出错的那一步
		if _overlap_done == "RoverL":
			_overlap_done = ""
			_hole_done = ""
		elif _hole_done == "high":
			_hole_done = ""
	# 错两次解锁「对照旧衣」
	if _error_count >= 2:
		_btn_compare.visible = true
	_refresh()
	_view.queue_redraw()

func _on_inner() -> void:
	_inner_open = true
	_view.queue_redraw()
	AudioMgr.play("paper_flip", -6.0)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		hud.toast("阿九：「最后这一扣，我从来都是反手收的。」")

func _on_compare() -> void:
	_compared = true
	_btn_compare.set_meta("compare_ok", true)
	GameState.set_flag("mend_compare_seen")
	_view.queue_redraw()
	AudioMgr.play("paper_flip", -6.0)

func _on_compare_gap() -> void:
	_compared = true
	GameState.set_flag("gap_compared")
	AudioMgr.play("puzzle_success", -10.0)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		hud.toast("颈圈的断口和纸人头里的竹篾，一根一根对上了。")
	_view.queue_redraw()
