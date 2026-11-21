extends CanvasLayer
class_name HUD
## 极简国风 HUD：中心弱准点（对准交互物 → 水墨手掌/眼睛图标） / 交互提示 / 顶部目标 / 底部浮语

var _icon: InkIcon
var _prompt: Label
var _objective: Label
var _toast_label: Label
var _toast_queue: Array[String] = []
var _toast_timer := 0.0

func _ready() -> void:
	add_to_group("hud")
	layer = 50
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_icon = InkIcon.new()
	_icon.set_anchors_preset(Control.PRESET_CENTER)
	_icon.position = Vector2(-22, -22)
	_icon.custom_minimum_size = Vector2(44, 44)
	root.add_child(_icon)

	_prompt = UITheme.make_label("", 20, Color(0.92, 0.88, 0.78))
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-160, 44)
	_prompt.custom_minimum_size = Vector2(320, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_constant_override("shadow_offset_x", 1)
	_prompt.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(_prompt)

	_objective = UITheme.make_label("", 16, Color(0.75, 0.7, 0.6, 0.85))
	_objective.position = Vector2(18, 14)
	root.add_child(_objective)
	GameState.objective_changed.connect(_on_objective)

	_toast_label = UITheme.make_label("", 19, Color(0.9, 0.85, 0.72))
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_label.position = Vector2(-260, -120)
	_toast_label.custom_minimum_size = Vector2(520, 60)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_constant_override("shadow_offset_x", 1)
	_toast_label.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(_toast_label)

func _on_objective(text: String) -> void:
	_objective.text = "◆ " + text

func toast(text: String) -> void:
	_toast_queue.append(text)

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_label.text = ""
	elif _toast_queue.size() > 0:
		_toast_label.text = _toast_queue.pop_front()
		_toast_timer = 3.4

## icon_type: "dot" 平静准点 / "hand" 手掌·可拿可操作 / "eye" 眼睛·可翻看
func set_prompt(text: String, icon_type: String = "dot") -> void:
	_prompt.text = text
	_icon.set_state("dot" if text == "" else icon_type)

## ------------------------------------------------------------ 水墨图标
## 纯 canvas 绘制：宽淡笔刷打底（晕染）+ 窄浓笔锋收笔，无外部素材
class InkIcon extends Control:
	var _state := "dot"
	var _t := 0.0

	const INK := Color(0.93, 0.89, 0.8)          # 宣纸暖白墨色
	const INK_HALO := Color(0.93, 0.89, 0.8, 0.18)
	const CINNABAR := Color(0.62, 0.16, 0.1)     # 朱砂点缀

	func set_state(s: String) -> void:
		if s != _state:
			_state = s
			queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()  # 呼吸脉动

	func _draw() -> void:
		var c := size * 0.5
		match _state:
			"dot":
				# 平时：极弱的中心圆点
				draw_circle(c, 2.2, Color(1, 1, 1, 0.16 + 0.05 * sin(_t * 2.0)))
			"hand":
				_draw_hand(c)
			"eye":
				_draw_eye(c)
			_:
				draw_circle(c, 2.2, Color(1, 1, 1, 0.16))

	func _brush(p1: Vector2, p2: Vector2, width: float) -> void:
		# 晕染底笔 + 浓墨主笔
		draw_line(p1, p2, INK_HALO, width * 2.2, true)
		draw_line(p1, p2, INK, width, true)

	func _brush_circle(pos: Vector2, r: float) -> void:
		draw_circle(pos, r * 1.5, Color(INK.r, INK.g, INK.b, 0.15))
		draw_circle(pos, r, INK)

	func _draw_hand(c: Vector2) -> void:
		var pulse := 1.0 + 0.04 * sin(_t * 3.0)
		draw_set_transform(c, 0.0, Vector2.ONE * pulse)
		# 四指（微张、长短错落）
		var tips := [Vector2(-8, -14), Vector2(-3, -17), Vector2(2, -16), Vector2(7, -12)]
		var roots := [Vector2(-7, 2), Vector2(-3, 0), Vector2(2, 0), Vector2(6, 2)]
		for i in tips.size():
			_brush(roots[i], tips[i], 3.2)
		# 掌缘 + 拇指
		draw_arc(Vector2(0, 8), 9.5, -0.25, PI + 0.35, 18, INK_HALO, 8.0, true)
		draw_arc(Vector2(0, 8), 9.5, -0.25, PI + 0.35, 18, INK, 3.4, true)
		_brush(Vector2(-9, 4), Vector2(-15, 12), 3.0)
		# 腕
		_brush(Vector2(-3, 17), Vector2(3, 17), 4.0)
		draw_set_transform(c, 0.0, Vector2.ONE)

	func _draw_eye(c: Vector2) -> void:
		var pulse := 1.0 + 0.04 * sin(_t * 2.4)
		draw_set_transform(c, 0.0, Vector2.ONE * pulse)
		# 眼眶（两段弧合成杏仁形）
		var blink := 0.75 + 0.25 * absf(sin(_t * 1.1))   # 缓慢眨眼
		draw_arc(Vector2(0, -3.5), 14.0, PI + 0.45, TAU - 0.45, 22, INK_HALO, 8.0, true)
		draw_arc(Vector2(0, -3.5), 14.0, PI + 0.45, TAU - 0.45, 22, INK, 3.2, true)
		draw_arc(Vector2(0, 3.5), 14.0, 0.45, PI - 0.45, 22, INK_HALO, 8.0, true)
		draw_arc(Vector2(0, 3.5), 14.0, 0.45, PI - 0.45, 22, INK, 3.2, true)
		# 瞳（朱砂点睛）
		draw_circle(Vector2(0, 0), 6.2 * blink, Color(INK.r, INK.g, INK.b, 0.22))
		draw_circle(Vector2(0, 0), 4.6 * blink, INK)
		draw_circle(Vector2(0, 0), 2.0 * blink, CINNABAR)
		draw_set_transform(c, 0.0, Vector2.ONE)
