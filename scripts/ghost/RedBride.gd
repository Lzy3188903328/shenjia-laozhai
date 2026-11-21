extends Node3D
class_name RedBride
## 红衣鬼影（终局追逐）：沿墙安全路线巡逻 + 视线/听觉检测 + 带实体遮挡判定的捕获
## 生存规则（墙上血字）：灯莫明 / 步莫急 / 名莫应 / 南门绝 / 中庭还玉
## 追逐规则：视线开阔直线扑击；脱离视线则沿巡逻路线追（绝不直穿实体墙）

enum State { IDLE, PATROL, CHASE }

const PATROL_SPEED := 1.7
const CHASE_SPEED := 2.9
const CATCH_RADIUS := 1.3
const VISION_RANGE_LIT := 11.0     # 玩家提灯时鬼影视距
const VISION_RANGE_DARK := 4.5     # 玩家熄灯时
const HEARING_RANGE := 6.0         # 奔跑脚步声传播距离
const LOSE_TIME := 4.0

var state: State = State.IDLE
var waypoints: PackedVector3Array = []
var _wp_index := 0
var _player: Node3D
var _model: Node3D
var _glow: OmniLight3D
var _lose_timer := 0.0
var active := false
var _investigating := false
var _investigate_pos := Vector3.ZERO
var _investigate_timer := 0.0

func investigate_door(pos: Vector3, timeout: float = 4.0) -> void:
	## 玩家应声后转向声源（封门）查声：沿现有可通行段接近，到达或超时恢复；
	## 出现直接视线时现有追逐优先。回应只暴露门的位置，抓捕仍由距离与遮挡决定。
	if not active:
		return
	if state == State.CHASE and _can_see_player():
		return   # 直接视线：现有追逐优先，不转查声
	_investigating = true
	_investigate_pos = pos
	_investigate_timer = timeout
	if state != State.CHASE:
		state = State.CHASE
		_lose_timer = timeout

func _ready() -> void:
	add_to_group("red_bride")
	var scene: PackedScene = load("res://assets/props/bride_ghost.glb")
	if scene != null:
		_model = scene.instantiate()
		add_child(_model)
		var tw := create_tween().set_loops()
		tw.tween_property(_model, "position:y", 0.06, 1.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_model, "position:y", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.7, 0.1, 0.08)
	_glow.light_energy = 0.0
	_glow.omni_range = 3.0
	add_child(_glow)

func activate(wps: PackedVector3Array) -> void:
	waypoints = wps
	_wp_index = 0
	active = true
	state = State.PATROL
	if _glow != null:
		var tw := create_tween()
		tw.tween_property(_glow, "light_energy", 1.6, 2.0)

func _find_player() -> Node3D:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group("player")
	return _player

# ---------------------------------------------------------- 视线 / 听觉
func _los_clear() -> bool:
	## 与玩家之间有无实体遮挡（墙/门板）
	var p := _find_player()
	if p == null:
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1.3, 0),
		p.global_position + Vector3(0, 1.0, 0),
		1)   # 只与静态世界层相交
	return space.intersect_ray(q).is_empty()

func _lit_state() -> Dictionary:
	var p := _find_player()
	var lit := false
	var lantern: Node3D = p.find_child("LanternRoot", true, false) if p != null else null
	if lantern != null:
		for c in lantern.get_children():
			if c is Light3D and c.light_energy > 0.3:
				lit = true
	var crouching: bool = p != null and p.get("head") != null and p.get("head").position.y < 1.2
	return {"lit": lit, "crouch": crouching}

func _can_see_player() -> bool:
	var p := _find_player()
	if p == null or not active:
		return false
	var st := _lit_state()
	var range_now := VISION_RANGE_LIT if st["lit"] else VISION_RANGE_DARK
	if st["crouch"] and not st["lit"]:
		range_now *= 0.6
	if p.global_position.distance_to(global_position) > range_now:
		return false
	return _los_clear()

func _hears_player() -> bool:
	var p := _find_player()
	if p == null or not active:
		return false
	var vel: Vector3 = p.get("velocity")
	if vel == null:
		return false
	if Vector2(vel.x, vel.z).length() < 3.0:
		return false
	return p.global_position.distance_to(global_position) < HEARING_RANGE

# ---------------------------------------------------------- 移动
func _face_dir(dir: Vector3) -> void:
	var yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, 0.12)

func _move_toward(target: Vector3, step: float) -> void:
	var to_target := target - global_position
	to_target.y = 0
	if to_target.length() < 0.05:
		return
	var dir := to_target.normalized()
	global_position += dir * step
	_face_dir(dir)

func _move_route(step: float) -> void:
	## 沿墙安全路线走；路线上遇到关着的门/墙体时换下一个巡逻点（门开后可恢复通行）
	if waypoints.is_empty():
		return
	var target := waypoints[_wp_index]
	var to_target := target - global_position
	to_target.y = 0
	if to_target.length() < 0.4:
		_wp_index = (_wp_index + 1) % waypoints.size()
		return
	if not _segment_clear(target):
		# 通路被实体挡住（如关闭的门）：换巡逻点，等待门开后再走这条边
		_wp_index = (_wp_index + 1) % waypoints.size()
		return
	_move_toward(target, step)

func _segment_clear(to_pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1.0, 0),
		to_pos + Vector3(0, 1.0, 0),
		1)
	return space.intersect_ray(q).is_empty()

func _chase_via_route(delta: float) -> void:
	## 脱离视线时沿巡逻路线追（环线取短方向），绝不直穿实体墙
	var p := _find_player()
	if waypoints.is_empty():
		return
	var n := waypoints.size()
	var gi := _nearest_route_index(global_position)
	var pi := _nearest_route_index(p.global_position)
	if gi == pi:
		_move_toward(waypoints[pi], CHASE_SPEED * delta)
		return
	var fwd := (pi - gi + n) % n
	var back := (gi - pi + n) % n
	var step_i := 1 if fwd <= back else n - 1
	var nxt := (gi + step_i) % n
	var tgt := waypoints[nxt]
	if _segment_clear(tgt):
		_move_toward(tgt, CHASE_SPEED * delta)
		if global_position.distance_to(tgt) < 0.5:
			_wp_index = nxt
	else:
		pass  # 通路受阻：原地伫立（雾中一点红），等视线恢复

func _nearest_route_index(pos: Vector3) -> int:
	var best := 0
	var best_d := 1e9
	for i in waypoints.size():
		var d: float = pos.distance_to(waypoints[i])
		if d < best_d:
			best_d = d
			best = i
	return best

# ---------------------------------------------------------- 主循环
func _physics_process(delta: float) -> void:
	if not active:
		return
	var p := _find_player()
	if p == null:
		return
	# 捕获判定：距离 + 实体视线（隔墙脱身）
	if p.global_position.distance_to(global_position) < CATCH_RADIUS and _los_clear():
		_catch(p)
		return
	match state:
		State.PATROL:
			_move_route(PATROL_SPEED * delta)
			if _can_see_player() or _hears_player():
				_start_chase()
		State.CHASE:
			var sees := _can_see_player()
			if sees or _hears_player():
				_lose_timer = LOSE_TIME
			elif not _investigating:
				_lose_timer -= delta
			if _investigating:
				# 查声：直线可通则直走，否则沿巡逻段接近；到达/超时即恢复
				_investigate_timer -= delta
				if _segment_clear(_investigate_pos):
					_move_toward(_investigate_pos, CHASE_SPEED * delta)
				else:
					_move_route(CHASE_SPEED * delta)
				if global_position.distance_to(_investigate_pos) < 0.7 or _investigate_timer <= 0.0:
					_investigating = false
					_lose_timer = LOSE_TIME
			elif sees:
				_move_toward(p.global_position, CHASE_SPEED * delta)
			elif _lose_timer > 0.0:
				_chase_via_route(delta)
			else:
				state = State.PATROL
				AudioMgr.play_at("whisper", global_position, -8.0)

func _start_chase() -> void:
	if state == State.CHASE:
		return
	state = State.CHASE
	_lose_timer = LOSE_TIME
	AudioMgr.play_at("suona_short", global_position, 0.0)
	AudioMgr.play_at("opera_voice", global_position, -4.0)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		hud.toast("红衣的身影在雾里转过头来——跑！")

func _catch(_p: Node3D) -> void:
	active = false
	AudioMgr.play("suona_long", 0.0)
	var fx := get_tree().get_first_node_in_group("effects")
	if fx != null and fx.has_method("death_fade"):
		fx.death_fade()
	GameState.player_die("caught")
