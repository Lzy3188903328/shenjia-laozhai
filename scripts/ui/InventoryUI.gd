extends CanvasLayer
class_name InventoryUI
## 行囊 / 线索册（宣纸风格）：物品检视入口 + 两两组合 + 文档回看

var _panel: PanelContainer
var _list_box: VBoxContainer
var _detail_name: Label
var _detail_desc: Label
var _inspect_btn: Button
var _combine_btn: Button
var _doc_btn: Button
var _close_btn: Button
var _selected := ""
var _combine_mode := false
var _combine_first := ""

var _doc_panel: PanelContainer
var _doc_list_box: VBoxContainer

func _ready() -> void:
	add_to_group("inventory_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时行囊自身仍接收输入
	layer = 55
	visible = false
	_build_main()
	_build_docs()

func _build_main() -> void:
	_panel = PanelContainer.new()
	_panel.add_to_group("paper_panel")
	_panel.add_theme_stylebox_override("panel", UITheme.paper_stylebox(16.0))
	_panel.custom_minimum_size = Vector2(760, 460)
	add_child(_panel)
	UITheme.center_panel(_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	_panel.add_child(hb)

	# 左：物品列表
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	hb.add_child(left)
	var lt := UITheme.make_label("— 行 囊 —", 22, Color(0.3, 0.08, 0.05))
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(lt)
	_list_box = VBoxContainer.new()
	left.add_child(_list_box)

	# 右：详情
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(400, 0)
	hb.add_child(right)
	_detail_name = UITheme.make_label("", 24, Color(0.2, 0.12, 0.06))
	right.add_child(_detail_name)
	_detail_desc = UITheme.make_label("", 18, Color(0.25, 0.18, 0.1))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.custom_minimum_size = Vector2(400, 240)
	right.add_child(_detail_desc)
	var buttons := VBoxContainer.new()
	right.add_child(buttons)
	_inspect_btn = UITheme.make_button("检 视（翻看细节）")
	_inspect_btn.pressed.connect(_on_inspect)
	buttons.add_child(_inspect_btn)
	_combine_btn = UITheme.make_button("组 合…")
	_combine_btn.pressed.connect(_on_combine)
	buttons.add_child(_combine_btn)
	_doc_btn = UITheme.make_button("线 索 册")
	_doc_btn.pressed.connect(_on_show_docs)
	buttons.add_child(_doc_btn)
	_close_btn = UITheme.make_button("收起（Tab）")
	_close_btn.pressed.connect(close)
	buttons.add_child(_close_btn)

func _build_docs() -> void:
	_doc_panel = PanelContainer.new()
	_doc_panel.add_to_group("paper_panel")
	_doc_panel.add_theme_stylebox_override("panel", UITheme.paper_stylebox(16.0))
	_doc_panel.custom_minimum_size = Vector2(760, 460)
	add_child(_doc_panel)
	UITheme.center_panel(_doc_panel)
	var vb := VBoxContainer.new()
	_doc_panel.add_child(vb)
	var lt := UITheme.make_label("— 线 索 册 —", 22, Color(0.3, 0.08, 0.05))
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lt)
	_doc_list_box = VBoxContainer.new()
	vb.add_child(_doc_list_box)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 380)
	vb.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.custom_minimum_size = Vector2(680, 0)
	scroll.add_child(inner)
	_doc_list_box = inner
	var back := UITheme.make_button("回 行 囊")
	back.pressed.connect(func() -> void:
		_doc_panel.visible = false
		_panel.visible = true)
	vb.add_child(back)

func open() -> void:
	visible = true
	_doc_panel.visible = false
	_panel.visible = true
	_selected = ""
	_combine_mode = false
	_combine_first = ""
	_refresh()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("inventory") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()

func _refresh() -> void:
	for c in _list_box.get_children():
		c.queue_free()
	for item_id in GameState.items:
		var b := UITheme.make_button(ItemDB.item_name(item_id), 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var is_first: bool = (_combine_mode and _combine_first == item_id)
		if item_id == _selected:
			b.modulate = Color(1.15, 1.05, 0.9)
		b.pressed.connect(_on_select.bind(item_id))
		_list_box.add_child(b)
	if GameState.items.is_empty():
		_list_box.add_child(UITheme.make_label("（空空如也）", 16, Color(0.4, 0.35, 0.3)))
	_refresh_detail()

func _refresh_docs() -> void:
	for c in _doc_list_box.get_children():
		c.queue_free()
	for doc_id in GameState.docs:
		var d: Dictionary = ItemDB.DOCS.get(doc_id, {})
		var b := UITheme.make_button("《%s》" % String(d.get("title", doc_id)), 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_read_doc.bind(doc_id))
		_doc_list_box.add_child(b)
	if GameState.docs.is_empty():
		_doc_list_box.add_child(UITheme.make_label("（尚未收集任何线索）", 16, Color(0.4, 0.35, 0.3)))

func _on_select(item_id: String) -> void:
	if _combine_mode and _combine_first != "" and _combine_first != item_id:
		_try_combine(_combine_first, item_id)
		return
	_selected = item_id
	_refresh()

func _refresh_detail() -> void:
	if _selected == "":
		_detail_name.text = ""
		_detail_desc.text = ""
		return
	_detail_name.text = ItemDB.item_name(_selected)
	_detail_desc.text = ItemDB.item_desc(_selected)
	if _combine_mode:
		_detail_desc.text = "正在组合：请选择另一件物品。\n（再点一次取消）"

func _on_inspect() -> void:
	if _selected == "":
		return
	var insp := get_tree().get_first_node_in_group("inspect_ui")
	if insp != null and insp.has_method("open_item"):
		insp.open_item(_selected)
		close()

func _on_combine() -> void:
	if _selected == "":
		return
	_combine_mode = not _combine_mode
	_combine_first = _selected if _combine_mode else ""
	_refresh_detail()

func _try_combine(a: String, b: String) -> void:
	var key := "%s+%s" % [a, b]
	var alt := "%s+%s" % [b, a]
	var recipe: Dictionary = ItemDB.COMBINE.get(key, ItemDB.COMBINE.get(alt, {}))
	_combine_mode = false
	_combine_first = ""
	if recipe.is_empty():
		AudioMgr.play("puzzle_fail", -16.0, 0.7)
		_detail_desc.text = "这两样东西合不到一块儿。"
		return
	GameState.set_flag(String(recipe["flag"]))
	AudioMgr.play("puzzle_success", -10.0)
	_detail_desc.text = String(recipe["text"])
	var fx := get_tree().get_first_node_in_group("effects")
	if fx != null and String(recipe["flag"]) == "memory_jade_wedding":
		if fx.has_method("red_flash"):
			fx.red_flash(1.8)

func _on_show_docs() -> void:
	_refresh_docs()
	_panel.visible = false
	_doc_panel.visible = true

func _on_read_doc(doc_id: String) -> void:
	var reader := get_tree().get_first_node_in_group("reader_ui")
	if reader != null and reader.has_method("open_doc"):
		close()
		reader.open_doc(doc_id)
