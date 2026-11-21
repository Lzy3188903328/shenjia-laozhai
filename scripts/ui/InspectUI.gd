extends CanvasLayer
class_name InspectUI
## 3D 物品检视：SubViewport 内 360° 旋转，翻到背面浮现隐藏线索

signal closed

var _viewport: SubViewport
var _holder: Node3D
var _model: Node3D
var _title: Label
var _clue: Label
var _tip: Label
var _item_id := ""
var _dragging := false
var _rot_y := 0.0
var _rot_x := 0.0
var _dist := 1.2

func _ready() -> void:
	add_to_group("inspect_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(700, 500)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	var panel := PanelContainer.new()
	panel.add_to_group("paper_panel")
	panel.add_theme_stylebox_override("panel", UITheme.paper_stylebox(10.0))
	panel.custom_minimum_size = Vector2(700, 520)
	UITheme.center_panel(panel)
	root.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)

	_title = UITheme.make_label("", 24, Color(0.3, 0.08, 0.05))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)

	var vp_container := SubViewportContainer.new()
	vp_container.stretch = true
	vp_container.custom_minimum_size = Vector2(700, 440)
	vb.add_child(vp_container)
	vp_container.add_child(_viewport)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 1.2)
	_viewport.add_child(cam)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.05, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.4)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.2
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -140, 0)
	rim.light_energy = 0.5
	rim.light_color = Color(0.6, 0.7, 1.0)
	_viewport.add_child(rim)

	_holder = Node3D.new()
	_viewport.add_child(_holder)

	_clue = UITheme.make_label("", 18, Color(0.45, 0.08, 0.05))
	_clue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clue.custom_minimum_size = Vector2(680, 40)
	vb.add_child(_clue)
	_tip = UITheme.make_label("拖拽旋转 · 滚轮缩放 · 翻到背面或有发现 · Tab 关闭", 14, Color(0.35, 0.3, 0.24))
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_tip)

func open_item(item_id: String) -> void:
	_item_id = item_id
	_title.text = ItemDB.item_name(item_id)
	_clue.text = ""
	_rot_y = 0.0
	_rot_x = 0.0
	_dist = 1.2
	if _model != null:
		_model.queue_free()
	var mesh_path := ItemDB.item_mesh(item_id)
	var scene: PackedScene = load(mesh_path)
	if scene != null:
		_model = scene.instantiate()
		_holder.add_child(_model)
		# 归一化到视口大小（合并所有网格 AABB）
		var max_dim := 0.0
		for m in _model.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi != null and mi.mesh != null:
				var ab := mi.mesh.get_aabb()
				max_dim = maxf(max_dim, maxf(ab.size.x, maxf(ab.size.y, ab.size.z)))
		if max_dim > 0.0001:
			_model.scale = Vector3.ONE * (0.5 / max_dim)
			_model.position = Vector3(0, 0.25, 0)
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

func _process(delta: float) -> void:
	if not visible:
		return
	var cam := _viewport.get_camera_3d()
	if cam != null:
		cam.position = Vector3(0, 0, _dist)
	if _model != null:
		_model.rotation.y = _rot_y
		_model.rotation.x = _rot_x
	# 背面线索：面向后方 ±30° 内浮现
	var clue: String = ItemDB.item_clue(_item_id)
	if clue != "" and absf(wrapf(_rot_y, -PI, PI)) > deg_to_rad(140):
		if _clue.text == "":
			_clue.text = "「%s」" % clue
			AudioMgr.play("paper_flip", -10.0)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = clampf(_dist - 0.1, 0.5, 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = clampf(_dist + 0.1, 0.5, 3.0)
	elif event is InputEventMouseMotion and _dragging:
		_rot_y += event.relative.x * 0.01
		_rot_x = clampf(_rot_x + event.relative.y * 0.01, -1.2, 1.2)
	elif event.is_action_pressed("inventory") or event.is_action_pressed("pause"):
		close()
