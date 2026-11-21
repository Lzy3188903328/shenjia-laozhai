extends CharacterBody3D
## Player — 第一人称沉浸探索控制器
## 移动 / 慢跑 / 下蹲 / 交互射线 / 手持油灯（诡异预警三态）/ 脚步声 / 扔灯与拾回

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.4
const CROUCH_SPEED := 1.6
const ACCEL := 10.0
const JUMP_VELOCITY := 4.0
const INTERACT_DIST := 2.3
const MOUSE_SENS := 0.0022

var head: Node3D
var camera: Camera3D
var lantern_root: Node3D          # 手中灯笼模型挂点
var lantern_light: SpotLight3D
var lantern_omni: OmniLight3D
var lantern_flame: MeshInstance3D
var interact_ray: RayCast3D          # 交互物层(4)
var occlusion_ray: RayCast3D         # 场景遮挡层(1)

var _pitch := 0.0
var _crouching := false
var _current_speed := WALK_SPEED
var _step_accum := 0.0
var _footstep_timer := 0.0
var _lantern_on := true
var _lantern_thrown := false
var _thrown_lantern: Node3D = null
var _flicker_t := 0.0
var _input_locked := true   # 主菜单/开场过渡期间锁定，由 main 在游戏开始后解锁
var _base_head_y := 1.62
var _bob_t := 0.0
var _shake := 0.0

signal interact_target_changed(prompt_text: String, icon_type: String)
signal lantern_state_changed(state: String)

func _ready() -> void:
	_build_body()
	_build_lantern()
	_build_ray()
	ScareMgr.register_player(self)   # 鼠标捕获由 main 在游戏开始/恢复时统一管理

func _build_body() -> void:
	collision_layer = 2
	collision_mask = 1
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	col.shape = capsule
	col.position = Vector3(0, 0.85, 0)
	add_child(col)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, _base_head_y, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.05
	camera.far = 60.0
	head.add_child(camera)
	camera.current = true

func _build_lantern() -> void:
	lantern_root = Node3D.new()
	lantern_root.name = "LanternRoot"
	camera.add_child(lantern_root)
	lantern_root.position = Vector3(0.32, -0.34, -0.55)
	var scene: PackedScene = load("res://assets/props/hand_lantern.glb")
	if scene != null:
		var model := scene.instantiate()
		lantern_root.add_child(model)
		lantern_flame = model.find_child("Flame", true, false) as MeshInstance3D
	lantern_light = SpotLight3D.new()
	lantern_light.light_color = Color(1.0, 0.72, 0.38)
	lantern_light.light_energy = 5.0
	lantern_light.spot_range = 8.5
	lantern_light.spot_angle = 34.0
	lantern_light.spot_attenuation = 1.4
	lantern_light.shadow_enabled = true
	lantern_root.add_child(lantern_light)
	lantern_omni = OmniLight3D.new()
	lantern_omni.light_color = Color(0.9, 0.6, 0.3)
	lantern_omni.light_energy = 1.1
	lantern_omni.omni_range = 2.4
	lantern_root.add_child(lantern_omni)

func _build_ray() -> void:
	# 两段判定：先取交互物层命中，再用场景遮挡射线确认未被实体挡住
	# （留 12cm 容差——供桌上/妆奁顶上的道具贴面也能被选中）
	interact_ray = RayCast3D.new()
	interact_ray.target_position = Vector3(0, 0, -INTERACT_DIST)
	interact_ray.collision_mask = 4
	interact_ray.collide_with_areas = true
	camera.add_child(interact_ray)
	occlusion_ray = RayCast3D.new()
	occlusion_ray.target_position = Vector3(0, 0, -INTERACT_DIST)
	occlusion_ray.collision_mask = 1
	camera.add_child(occlusion_ray)

# ---------------------------------------------------------- 输入
func _unhandled_input(event: InputEvent) -> void:
	if _input_locked:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.35, 1.35)
		camera.rotation.x = _pitch
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("toggle_lantern"):
		_toggle_lantern()
	elif event.is_action_pressed("crouch"):
		_toggle_crouch()

func lock_input(lock: bool) -> void:
	_input_locked = lock

func _toggle_crouch() -> void:
	_crouching = not _crouching
	var target_y := 0.95 if _crouching else _base_head_y
	var tw := create_tween()
	tw.tween_property(head, "position:y", target_y, 0.22)

func _toggle_lantern() -> void:
	if _lantern_thrown:
		return
	_lantern_on = not _lantern_on
	var tw := create_tween()
	tw.tween_property(lantern_root, "scale", Vector3.ONE if _lantern_on else Vector3(0.001, 0.001, 0.001), 0.18)
	lantern_state_changed.emit("on" if _lantern_on else "off")

# ---------------------------------------------------------- 主循环
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	var input_vec := Vector2.ZERO
	if not _input_locked:
		input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting: bool = Input.is_action_pressed("sprint") and not _crouching and input_vec.length() > 0.1
	var target_speed := CROUCH_SPEED if _crouching else (SPRINT_SPEED if sprinting else WALK_SPEED)
	var dir := (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
	if dir.length() > 0.1:
		_current_speed = target_speed
	velocity.x = move_toward(velocity.x, dir.x * target_speed, ACCEL * delta * target_speed)
	velocity.z = move_toward(velocity.z, dir.z * target_speed, ACCEL * delta * target_speed)
	if not _input_locked and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	move_and_slide()
	_update_footsteps(delta, sprinting)
	_update_lantern(delta)
	_update_headbob(delta, sprinting)
	_update_interact()

func _update_headbob(delta: float, sprinting: bool) -> void:
	var moving := velocity.length() > 0.5 and is_on_floor()
	if moving:
		_bob_t += delta * (11.0 if sprinting else 7.5)
		var amp := 0.018 if not sprinting else 0.03
		camera.position.y = sin(_bob_t) * amp
		camera.position.x = cos(_bob_t * 0.5) * amp * 0.6
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, delta * 6.0)
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 1.6, 0.0)
		camera.position += Vector3(randf_range(-_shake, _shake), randf_range(-_shake, _shake), 0)

func shake(strength: float = 0.08) -> void:
	_shake = strength

func _update_footsteps(delta: float, sprinting: bool) -> void:
	if velocity.length() < 0.6 or not is_on_floor():
		_footstep_timer = 0.12
		return
	_footstep_timer -= delta * (1.6 if sprinting else 1.0) * clampf(velocity.length() / WALK_SPEED, 0.6, 1.6)
	if _footstep_timer <= 0.0:
		_footstep_timer = 0.52
		var pitch := randf_range(0.9, 1.1)
		AudioMgr.play_at("step_wood_%d" % (1 + randi() % 2), global_position, -14.0 if _crouching else -7.0, pitch)

# ---------------------------------------------------------- 油灯三态（诡异预警联动）
func _update_lantern(delta: float) -> void:
	_flicker_t += delta
	var dread := ScareMgr.dread_level()
	var base_energy := 5.0
	var flame_scale := 1.0
	if not _lantern_on:
		lantern_light.light_energy = 0.0
		lantern_omni.light_energy = 0.0
		if lantern_flame != null:
			lantern_flame.visible = false
		return
	if lantern_flame != null:
		lantern_flame.visible = true
	match dread:
		0:
			base_energy = 5.0 + sin(_flicker_t * 2.1) * 0.25
			flame_scale = 1.0
			lantern_light.light_color = Color(1.0, 0.72, 0.38)
		1:
			base_energy = 4.6 + sin(_flicker_t * 7.0) * 0.55
			flame_scale = 0.85 + sin(_flicker_t * 5.0) * 0.08
			lantern_light.light_color = Color(0.95, 0.72, 0.42).lerp(Color(0.55, 0.9, 0.5), 0.25)
			_maybe_crackle(delta, 0.5)
		2:
			base_energy = 3.8 + sin(_flicker_t * 16.0) * 1.2
			flame_scale = 0.62 + sin(_flicker_t * 9.0) * 0.15
			lantern_light.light_color = Color(0.5, 0.92, 0.45).lerp(Color(0.9, 0.3, 0.2), 0.15)
			_maybe_crackle(delta, 2.5)
	lantern_light.light_energy = maxf(base_energy, 0.1)
	lantern_omni.light_energy = lantern_light.light_energy * 0.22
	lantern_omni.light_color = lantern_light.light_color
	if lantern_flame != null:
		lantern_flame.scale = Vector3.ONE * flame_scale

var _crackle_chance := 0.0
func _maybe_crackle(delta: float, rate: float) -> void:
	_crackle_chance += delta * rate
	if _crackle_chance > 1.0:
		_crackle_chance = 0.0
		AudioMgr.play("wick_crackle", -8.0, randf_range(0.9, 1.15))

# ---------------------------------------------------------- 交互
var _current_target: Node = null
var _current_prompt := ""

func _update_interact() -> void:
	var new_target: Node = null
	var prompt := ""
	var icon := "dot"
	if interact_ray.is_colliding():
		var col := interact_ray.get_collider()
		if col != null and col is Area3D:
			col = col.get_parent()
		if col != null and col.has_method("get_prompt"):
			var hit_dist: float = camera.global_position.distance_to(interact_ray.get_collision_point())
			var blocked := false
			if occlusion_ray.is_colliding():
				var occ_dist: float = camera.global_position.distance_to(occlusion_ray.get_collision_point())
				blocked = occ_dist < hit_dist - 0.12
			if not blocked:
				new_target = col
				prompt = col.get_prompt()
				icon = col.get_icon_type() if col.has_method("get_icon_type") else "hand"
	if new_target != _current_target or prompt != _current_prompt:
		_current_target = new_target
		_current_prompt = prompt
		interact_target_changed.emit(prompt, icon)

func _try_interact() -> void:
	if _current_target != null and _current_target.has_method("interact"):
		_current_target.interact(self)

# ---------------------------------------------------------- 扔灯 / 拾回
func _unhandled_key_input(event: InputEvent) -> void:
	if _input_locked:
		return
	if event.is_action_pressed("throw_lantern") and not _lantern_thrown and _lantern_on:
		_throw_lantern()

func _throw_lantern() -> void:
	_lantern_thrown = true
	_lantern_on = false
	lantern_root.visible = false
	lantern_light.light_energy = 0.0
	lantern_omni.light_energy = 0.0
	var PickupScript := load("res://scripts/interact/Pickup.gd")
	var thrown: StaticBody3D = PickupScript.new()
	thrown.item_id = "hand_lantern_thrown"
	thrown.prompt_text = "拾起油灯"
	thrown.only_pickup_marker = true
	# 可被交互射线命中的碰撞体
	thrown.add_box_collision(Vector3(0.3, 0.5, 0.3))
	var world := get_tree().current_scene
	world.add_child(thrown)
	var start := global_position + Vector3(0, 1.5, 0)
	var target := _throw_landing(start)
	thrown.global_position = start
	var model: PackedScene = load("res://assets/props/hand_lantern.glb")
	if model != null:
		var inst := model.instantiate()
		thrown.add_child(inst)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 3.5
	light.omni_range = 6.0
	thrown.add_child(light)
	# 抛物线：两段补间（落点已经场景限位）
	var tw := thrown.create_tween()
	tw.tween_property(thrown, "global_position", (start + target) * 0.5 + Vector3(0, 0.8, 0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(thrown, "global_position", target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_thrown_lantern = thrown

func _throw_landing(start: Vector3) -> Vector3:
	## 用场景碰撞限制投掷距离与落点：贴墙不过墙、落地贴地
	var space := get_world_3d().direct_space_state
	var dir := -(transform.basis.z)   # 面朝方向
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3(0, 0, -1)
	# 前向限距（墙/家具挡住则缩短）
	var q := PhysicsRayQueryParameters3D.create(start, start + dir * 2.8, 1)
	var hit := space.intersect_ray(q)
	var reach := 2.6
	if not hit.is_empty():
		reach = maxf(0.8, start.distance_to(hit["position"]) - 0.45)
	var target := start + dir * reach
	# 垂直落点（门洞边缘/台阶等：取地面高度）
	var qd := PhysicsRayQueryParameters3D.create(target + Vector3(0, 1.2, 0), target + Vector3(0, -1.6, 0), 1)
	var down := space.intersect_ray(qd)
	if not down.is_empty():
		target.y = down["position"].y + 0.14
	else:
		target.y = start.y - 1.4
	return target

func retrieve_thrown_lantern() -> void:
	if _thrown_lantern != null and is_instance_valid(_thrown_lantern):
		_thrown_lantern.queue_free()
	_thrown_lantern = null
	_lantern_thrown = false
	_lantern_on = true
	lantern_root.visible = true
	AudioMgr.play("lantern_relight", -6.0)
