extends Node3D
class_name Scares
## 恐怖演出执行器（scare_runner）：所有小惊吓 / 剧情惊吓 / 闪回的具体表现
## 恐怖节奏：ScareMgr 控制配额与冷却；本节点只负责"怎么吓"

var _player: Node3D

func _ready() -> void:
	add_to_group("scare_runner")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _fade_out_meshes(root: Node3D, dur: float, then_free: bool = true) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		var tw := mi.create_tween()
		tw.tween_property(mi, "transparency", 1.0, dur)
	if then_free:
		var tw2 := root.get_tree().create_timer(dur + 0.05)
		tw2.timeout.connect(func() -> void:
			if is_instance_valid(root):
				root.queue_free())

func _find_player() -> Node3D:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group("player")
	return _player

func run_scare(scare_id: String, pos: Vector3) -> void:
	if not ScareMgr.fire(scare_id):
		return
	_dispatch(scare_id, pos)

## 剧情惊吓（不走配额冷却——剧本节点必发）
func run_scare_forced(scare_id: String, pos: Vector3) -> void:
	_dispatch(scare_id, pos)

func _dispatch(scare_id: String, pos: Vector3) -> void:
	match scare_id:
		"corridor_bang": _corridor_bang(pos)
		"window_flash": _window_flash(pos)
		"drawer_head": _drawer_head(pos)
		"drawer_rat": _drawer_rat(pos)
		"curtain_ghost": _curtain_ghost(pos)
		"figure_turn": _figure_turn(pos)
		"mirror_ghost": _mirror_ghost(pos)
		"mirror_flash": _mirror_flash(pos)
		"well_whisper": _well_whisper(pos)
		"shoes_appear": _shoes_appear(pos)
		"flashback_fire": _flashback_fire()
		"blackout": _blackout()
		"basement_candles": _basement_candles(pos)
		"opera_close": _opera_close(pos)
		"banzi_far": AudioMgr.play("bangzi_far", -10.0)

# ---------------------------------------------------------- MS-01 廊门拍响
func _corridor_bang(pos: Vector3) -> void:
	var nearest: Door = null
	var best := 9999.0
	for d in get_tree().get_nodes_in_group("slam_doors"):
		var dist: float = (d as Node3D).global_position.distance_to(pos)
		if dist < best:
			best = dist
			nearest = d
	if nearest != null:
		nearest.slam_once()

# ---------------------------------------------------------- MS-02 窗棂黑影
func _window_flash(pos: Vector3) -> void:
	AudioMgr.play_at("door_bang", pos, -6.0, 1.4)
	AudioMgr.play_at("amb_wind_loop", pos, -4.0)
	# 黑影从窗外掠过
	var quad := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.8, 1.8)
	quad.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.02, 0.02, 0.03, 0.95)
	quad.material_override = mat
	get_tree().current_scene.add_child(quad)
	quad.global_position = pos + Vector3(0, 1.4, 0)
	var tw := quad.create_tween()
	tw.tween_property(quad, "global_position", quad.global_position + Vector3(2.4, 0, 0), 0.35)
	tw.tween_callback(quad.queue_free)

# ---------------------------------------------------------- MS-03 抽屉滚出纸人头
func _drawer_head(pos: Vector3) -> void:
	AudioMgr.play_at("drawer_roll", pos, -4.0)
	var scene: PackedScene = load("res://assets/props/paper_head.glb")
	if scene == null:
		return
	var head := scene.instantiate()
	get_tree().current_scene.add_child(head)
	head.global_position = pos + Vector3(0, 0.3, 0.2)
	var tw := head.create_tween()
	tw.tween_property(head, "global_position", pos + Vector3(randf_range(-0.4, 0.4), 0.14, 0.7), 0.7)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		AudioMgr.play_at("creak_wood", pos, -10.0, 1.3))

# ---------------------------------------------------------- MS-07 供品下窜出死老鼠
func _drawer_rat(pos: Vector3) -> void:
	AudioMgr.play_at("rat_squeak", pos, -4.0)
	var scene: PackedScene = load("res://assets/props/dead_rat.glb")
	if scene == null:
		return
	var rat := scene.instantiate()
	get_tree().current_scene.add_child(rat)
	rat.global_position = pos
	rat.rotation.y = randf() * TAU
	var away := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 1.2
	var tw := rat.create_tween()
	tw.tween_property(rat, "global_position", pos + away, 0.5)

# ---------------------------------------------------------- MS-04 床幔白影
func _curtain_ghost(pos: Vector3) -> void:
	var scene: PackedScene = load("res://assets/props/paper_figure.glb")
	if scene == null:
		return
	var ghost: Node3D = scene.instantiate()
	ghost.scale = Vector3.ONE * 1.05
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = pos
	# 朝向玩家
	var p := _find_player()
	if p != null:
		var dir := p.global_position - ghost.global_position
		dir.y = 0
		if dir.length() > 0.1:
			ghost.rotation.y = atan2(dir.x, dir.z)
	AudioMgr.play_at("breath_short", pos, 0.0)
	AudioMgr.play_at("creak_wood", pos, -6.0, 0.7)
	var tw := ghost.create_tween()
	tw.tween_interval(0.55)
	tw.tween_callback(func() -> void: _fade_out_meshes(ghost, 0.3))

# ---------------------------------------------------------- MS-05 纸人回头杀
func _figure_turn(pos: Vector3) -> void:
	var nearest_head: Node3D = null
	var best := 9999.0
	for f in get_tree().get_nodes_in_group("paper_figures"):
		var head: Node3D = f.find_child("Head", true, false)
		if head == null:
			continue
		var dist: float = head.global_position.distance_to(pos)
		if dist < best:
			best = dist
			nearest_head = head
	if nearest_head == null:
		return
	AudioMgr.play_at("creak_wood", nearest_head.global_position, -2.0, 0.75)
	var tw := nearest_head.create_tween()
	# 转向玩家
	var p := _find_player()
	if p != null:
		var dir := p.global_position - nearest_head.global_position
		var yaw := atan2(dir.x, dir.z)
		tw.tween_property(nearest_head, "rotation:y", yaw - nearest_head.get_parent().rotation.y, 1.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ---------------------------------------------------------- MS-06 镜中红影（回头即消失）
func _mirror_ghost(_pos: Vector3) -> void:
	var p := _find_player()
	if p == null:
		return
	AudioMgr.play("opera_voice", -4.0)
	var scene: PackedScene = load("res://assets/props/bride_ghost.glb")
	if scene == null:
		return
	var bride: Node3D = scene.instantiate()
	get_tree().current_scene.add_child(bride)
	var back := -(p.transform.basis.z)  # 玩家身后
	back.y = 0
	back = back.normalized() if back.length() > 0.1 else Vector3.FORWARD
	bride.global_position = p.global_position + back * 2.6 + Vector3(0, 0.1, 0)
	bride.look_at(p.global_position + Vector3(0, 1.4, 0))
	# 玩家回头（视线朝向新娘）→ 消失
	var watcher := func() -> bool:
		var pp := _find_player()
		if pp == null:
			return true
		var to_bride := bride.global_position - pp.global_position
		var forward := -(pp.transform.basis.z)
		return to_bride.normalized().dot(forward) > 0.45
	var elapsed := 0.0
	var check_timer := Timer.new()
	check_timer.wait_time = 0.1
	check_timer.autostart = true
	add_child(check_timer)
	check_timer.timeout.connect(func() -> void:
		elapsed += 0.1
		if elapsed > 4.0 or watcher.call():
			if is_instance_valid(bride):
				_fade_out_meshes(bride, 0.12)
			check_timer.queue_free())

# ---------------------------------------------------------- 镜谜题完成·红衣一闪
func _mirror_flash(pos: Vector3) -> void:
	AudioMgr.play("suona_short", -6.0)
	var scene: PackedScene = load("res://assets/props/bride_ghost.glb")
	if scene == null:
		return
	var bride: Node3D = scene.instantiate()
	get_tree().current_scene.add_child(bride)
	bride.global_position = pos + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	_fade_out_meshes(bride, 0.45)

# ---------------------------------------------------------- 枯井低语
func _well_whisper(pos: Vector3) -> void:
	AudioMgr.play_at("whisper", pos, -2.0)
	AudioMgr.play_at("drip_well", pos, -4.0)

# ---------------------------------------------------------- MS-10 红绣花鞋
func _shoes_appear(pos: Vector3) -> void:
	# 红绣花鞋模型由 main 侧的 Pickup 承载（此处只负责"出现瞬间"的声画）
	AudioMgr.play("sigh_woman", 0.0)
	AudioMgr.play("suona_short", -10.0, 0.9)
	var fx := get_tree().get_first_node_in_group("effects")
	if fx != null and fx.has_method("red_flash"):
		fx.red_flash(0.8)

# ---------------------------------------------------------- MS-11 火灾闪回
func _flashback_fire() -> void:
	var fx := get_tree().get_first_node_in_group("effects")
	var p := _find_player()
	if p != null and p.has_method("shake"):
		p.shake(0.12)
	AudioMgr.play("fire_crackle_loop", -4.0)
	AudioMgr.play("suona_long", -6.0)
	AudioMgr.play("heartbeat", -2.0)
	if fx != null and fx.has_method("red_flash"):
		fx.red_flash(2.4)
	var t := get_tree().create_timer(2.6)
	t.timeout.connect(func() -> void:
		AudioMgr.play("sigh_woman", -6.0))

# ---------------------------------------------------------- 全场灯笼骤灭
func _blackout() -> void:
	var lights: Array[Light3D] = []
	for l in get_tree().get_nodes_in_group("house_lights"):
		if l is Light3D:
			lights.append(l)
	for l in lights:
		l.set_meta("prev_energy", l.light_energy)
		l.light_energy = 0.0
	AudioMgr.play("sigh_woman", 2.0)
	AudioMgr.play("suona_short", 0.0)
	var t := get_tree().create_timer(3.2)
	t.timeout.connect(func() -> void:
		for l in lights:
			if is_instance_valid(l):
				l.light_energy = float(l.get_meta("prev_energy", l.light_energy)))

# ---------------------------------------------------------- MS-13 密室白烛齐燃
func _basement_candles(_pos: Vector3) -> void:
	for l in get_tree().get_nodes_in_group("cellar_candles"):
		if l is Light3D:
			var tw := l.create_tween()
			tw.tween_property(l, "light_energy", float(l.get_meta("target_energy", 1.5)), 0.6)
	AudioMgr.play("whisper", -6.0)
	AudioMgr.play_at("drip_well", _pos, -4.0)

# ---------------------------------------------------------- 贴耳戏曲念白
func _opera_close(pos: Vector3) -> void:
	AudioMgr.play_at("opera_voice", pos, 4.0)
