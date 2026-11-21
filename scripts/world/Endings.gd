extends CanvasLayer
class_name Endings
## 双结局演出：真结局《了结》/ 伪结局《长夜》

signal finished

var _black: ColorRect
var _label: Label
var _sub: Label
var _busy := false

func _ready() -> void:
	layer = 90
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 不可吞掉下层 UI（八卦锁/行囊等）的鼠标点击
	add_child(_black)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)
	_sub = Label.new()
	_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 20)
	_sub.add_theme_color_override("font_color", Color(0.55, 0.5, 0.42))
	_sub.offset_top = 200
	add_child(_sub)

func play_ending(ending_id: String) -> void:
	if _busy:
		return
	_busy = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	match ending_id:
		"true":
			_true_ending()
		"false":
			_false_ending()

func _fade(to_alpha: float, dur: float, color: Color = Color(0, 0, 0, 1)) -> void:
	_black.color.a = _black.color.a
	var tw := create_tween()
	tw.tween_property(_black, "color", Color(color.r, color.g, color.b, to_alpha), dur)
	await tw.finished

func _true_ending() -> void:
	AudioMgr.stop_chase_music()
	AudioMgr.play_ending_music()
	await _fade(1.0, 1.6)
	_label.text = "你把玉佩轻轻放回牌位前。\n雨声停了。"
	await _fade(0.0, 1.4)
	await _wait(1.2)
	_label.text = "灯笼一盏一盏，安静地暗下去。\n雾里那个红衣的身影，俯身拾起玉佩，\n朝你深深一拜。"
	await _fade(0.0, 0.1)
	await _wait(3.6)
	_label.text = ""
	await _fade(1.0, 1.2, Color(0.92, 0.9, 0.84))
	await _wait(1.0)
	_label.text = "【真结局 · 了结】\n\n十年恩怨，一拜而终。\n走出山门时，天已经亮了。\n你把那半枚鞋扣埋在了村口的老槐树下。\n从此再没有人请你扎纸人——\n苏城的阿九纸扎铺，关门了。"
	_label.add_theme_font_size_override("font_size", 26)
	await _fade(0.0, 1.6, Color(0.92, 0.9, 0.84))
	_sub.text = "——《沈家老宅》 谢谢游玩 · 按 Esc 退出"
	finished.emit()

func _false_ending() -> void:
	AudioMgr.stop_chase_music()
	await _fade(1.0, 0.8)
	_label.text = "你冲出大门——"
	await _wait(1.4)
	AudioMgr.play("suona_long", -4.0)
	_label.text = "门外没有村子。\n门外是十年前的那个雨夜。\n唢呐声里，祠堂的火光冲天而起，\n而你的手里，还攥着那枚不属于你的玉佩。"
	await _fade(0.0, 1.0)
	await _wait(3.8)
	_label.text = ""
	await _fade(1.0, 1.0)
	_label.text = "【伪结局 · 长夜】\n\n因果未了。\n雨还会下十年。\n\n（把玉佩还回去吧——她还在等。）"
	_label.add_theme_font_size_override("font_size", 26)
	await _fade(0.0, 1.6)
	_sub.text = "——《沈家老宅》 谢谢游玩 · 按 Esc 退出"
	finished.emit()

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout

func _input(event: InputEvent) -> void:
	if _busy and _sub.text != "" and event.is_action_pressed("pause"):
		get_tree().quit()
