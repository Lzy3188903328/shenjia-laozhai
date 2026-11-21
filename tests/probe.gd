extends Node
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
func _press_key(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode; down.keycode = keycode; down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.physical_keycode = keycode; up.keycode = keycode; up.pressed = false
	Input.parse_input_event(up)
func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	var player: CharacterBody3D = main.get("player")
	var wb: WorldBuilder = main.get("world_builder")
	var cam: Camera3D = player.get("camera")
	# 铜铃（纸人已移开）
	var pr: PaperRitual = wb.paper_ritual
	pr.phase = 3
	player.global_position = Vector3(-10.5, 0.15, -0.9)
	player.rotation.y = PI
	player.set("_pitch", -0.11)
	if cam != null:
		cam.rotation.x = -0.11
	for i in 8:
		await get_tree().physics_frame
	var ray: RayCast3D = player.get("interact_ray")
	ray.force_raycast_update()
	print("bell target=", player.get("_current_target"), " prompt=",
		ray.get_collider().get_prompt() if ray.get_collider() != null else "none")
	# 灯笼
	player.global_position = Vector3(2.5, 0.15, 3.0)
	player.rotation.y = 0.0
	await _wait(0.3)
	_press_key(KEY_G)
	await _wait(1.0)
	var stack := [self]
	var thrown: Node3D = null
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Pickup and n.item_id == "hand_lantern_thrown":
			thrown = n
			break
		for c in n.get_children():
			stack.push_back(c)
	print("thrown=", thrown, " pos=", thrown.global_position if thrown != null else Vector3.ZERO)
	if thrown != null:
		player.global_position = thrown.global_position + Vector3(0.9, 0.15, 0)
		player.rotation.y = -PI / 2.0
		player.set("_pitch", -1.05)
		if cam != null:
			cam.rotation.x = -1.05
		for i in 8:
			await get_tree().physics_frame
		ray.force_raycast_update()
		print("lantern hit=", ray.get_collider(), " target=", player.get("_current_target"))
		# 手动沿射线查询
		var space := player.get_world_3d().direct_space_state
		var from: Vector3 = ray.global_position
		var to: Vector3 = ray.global_transform * ray.target_position
		var q := PhysicsRayQueryParameters3D.create(from, to, 4)
		var h := space.intersect_ray(q)
		print("manual mask4=", h.get("collider"), " pos=", h.get("position"))
		print("ray from=", from, " to=", to)
		var q2 := PhysicsRayQueryParameters3D.create(from, to, 4 | 1)
		print("manual mask4|1=", space.intersect_ray(q2).get("collider"))
	get_tree().quit(0)
