extends Node
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
func _click_at(pos: Vector2) -> void:
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
	await get_tree().process_frame
func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	var mend_ui: MendUI = main.get("mend_ui")
	mend_ui.open_ui(null)
	await _wait(0.2)
	var view: Control = mend_ui._view
	print("view rect=", view.get_global_rect(), " size=", view.size, " filter=", view.mouse_filter)
	var local := mend_ui._hotspot_rect("L")
	var click_pos := view.get_global_rect().position + local.position + local.size * 0.5
	print("hotspot L local=", local, " -> global center=", click_pos)
	# 先发一个鼠标移动事件（GUI 需要位置跟踪）
	var mm := InputEventMouseMotion.new()
	mm.position = click_pos
	mm.global_position = click_pos
	Input.parse_input_event(mm)
	await get_tree().process_frame
	print("hovered=", get_viewport().gui_get_hovered_control())
	await _click_at(click_pos)
	await _wait(0.2)
	print("picked_first=", mend_ui._picked_first, " (期望 L)")
	get_tree().quit(0)
