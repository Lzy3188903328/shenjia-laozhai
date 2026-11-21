extends CanvasLayer
class_name ReaderUI
## 文档阅读器：古籍原件（竖排感）+ 底部现代白话浮层（保证阅读无障碍）

signal closed

var _panel: PanelContainer
var _title: Label
var _body: Label
var _plain: Label
var _plain_toggle: Button
var _prev_btn: Button
var _next_btn: Button
var _page_label: Label
var _doc_id := ""
var _page := 0

func _ready() -> void:
	add_to_group("reader_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 58
	visible = false
	_panel = PanelContainer.new()
	_panel.add_to_group("paper_panel")
	_panel.add_theme_stylebox_override("panel", UITheme.paper_stylebox(24.0))
	_panel.custom_minimum_size = Vector2(640, 520)
	add_child(_panel)
	UITheme.center_panel(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)

	_title = UITheme.make_label("", 28, Color(0.35, 0.06, 0.05))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)

	var sep := ColorRect.new()
	sep.color = Color(0.45, 0.08, 0.05, 0.35)
	sep.custom_minimum_size = Vector2(0, 2)
	vb.add_child(sep)

	_body = UITheme.make_label("", 21, Color(0.16, 0.11, 0.07))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(580, 240)
	vb.add_child(_body)

	_plain = UITheme.make_label("", 17, Color(0.2, 0.3, 0.2))
	_plain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plain.custom_minimum_size = Vector2(580, 70)
	vb.add_child(_plain)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	_prev_btn = UITheme.make_button("上一页")
	_prev_btn.pressed.connect(func() -> void: _flip(-1))
	hb.add_child(_prev_btn)
	_page_label = UITheme.make_label("", 16, Color(0.4, 0.3, 0.2))
	hb.add_child(_page_label)
	_next_btn = UITheme.make_button("下一页")
	_next_btn.pressed.connect(func() -> void: _flip(1))
	hb.add_child(_next_btn)
	_plain_toggle = UITheme.make_button("白话释意：关")
	_plain_toggle.pressed.connect(_toggle_plain)
	hb.add_child(_plain_toggle)
	var close_b := UITheme.make_button("合上（Esc）")
	close_b.pressed.connect(close)
	hb.add_child(close_b)

func open_doc(doc_id: String) -> void:
	_doc_id = doc_id
	_page = 0
	var d: Dictionary = ItemDB.DOCS.get(doc_id, {})
	_title.text = "《%s》" % String(d.get("title", doc_id))
	_plain.visible = false
	_plain_toggle.text = "白话释意：关"
	_refresh()
	visible = true
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("lock_input"):
		player.lock_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close() -> void:
	visible = false
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("lock_input"):
		player.lock_input(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()

func _refresh() -> void:
	var d: Dictionary = ItemDB.DOCS.get(_doc_id, {})
	var pages: Array = d.get("pages", [])
	_page = clampi(_page, 0, pages.size() - 1)
	if pages.size() > 0:
		_body.text = String(pages[_page])
	_page_label.text = "%d / %d" % [_page + 1, pages.size()]
	_prev_btn.disabled = _page <= 0
	_next_btn.disabled = _page >= pages.size() - 1
	_plain.text = "〔释〕" + String(d.get("plain", ""))

func _flip(dir: int) -> void:
	var new_page := _page + dir
	var d: Dictionary = ItemDB.DOCS.get(_doc_id, {})
	if new_page < 0 or new_page >= (d.get("pages", []) as Array).size():
		return
	_page = new_page
	AudioMgr.play("paper_flip", -8.0)
	_refresh()

func _toggle_plain() -> void:
	_plain.visible = not _plain.visible
	_plain_toggle.text = "白话释意：%s" % ("开" if _plain.visible else "关")
	AudioMgr.play("paper_flip", -12.0)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("interact"):
		# E 键翻页
		get_viewport().set_input_as_handled()
		_flip(1)
