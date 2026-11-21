extends Node
func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	var player: CharacterBody3D = main.get("player")
	var cam: Camera3D = player.get("camera")
	var wb: WorldBuilder = main.get("world_builder")
	var pr: PaperRitual = wb.paper_ritual
	pr.phase = 2
	GameState.add_item("fire_starter")
	var burner := wb.find_child("RitualBurner", true, false)
	print("burner=", burner.global_position)
	for id in ["Mid", "L", "R"]:
		var inc := burner.find_child("IncenseInteract" + id, true, false)
		if inc != null:
			print("  ", id, " gpos=", inc.global_position, " shape=", inc.get_child_count() > 0)
		else:
			print("  ", id, " MISSING")
	player.global_position = Vector3(-11.8, 0.15, -0.2)
	player.rotation.y = PI
	player.set("_pitch", -0.83)
	if cam != null:
		cam.rotation.x = -0.83
	for i in 8:
		await get_tree().physics_frame
	var ray: RayCast3D = player.get("interact_ray")
	ray.force_raycast_update()
	print("incense hit=", ray.get_collider(), " target=", player.get("_current_target"))
	if ray.get_collider() != null:
		print("  prompt=", ray.get_collider().get_prompt())
	get_tree().quit(0)
