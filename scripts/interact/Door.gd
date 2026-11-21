extends Interactable
class_name Door
## 木门：开门/关门动画（glb AnimationPlayer: door_open / door_close）
## 自身（含交互碰撞盒）挂接到门扇节点下随动画移动。
## 开/关动画期间禁用门叶碰撞（防止扫掠把玩家挤进或卡住），
## 关门动画结束、玩家离开门洞后恢复碰撞，恢复剧情锁与阻挡。

@export var locked := false
@export var locked_prompt := "此门扣而未启"
var _open := false
var _anim: AnimationPlayer
var _attached := false
var _leaf_col: StaticBody3D

func _ready() -> void:
	super._ready()
	# 延迟挂接（等 glb 场景树就绪）
	call_deferred("_attach_to_leaf")

func _attach_to_leaf() -> void:
	if _attached or not is_inside_tree():
		return
	var root := get_parent()
	if root == null:
		return
	var leaf := root.find_child("DoorLeaf", true, false) as Node3D
	if leaf == null:
		push_warning("Door: 未找到 DoorLeaf 节点：" + name)
		return
	var xform := global_transform
	root.remove_child(self)
	leaf.add_child(self)
	global_transform = xform
	_attached = true
	for body in leaf.find_children("*", "StaticBody3D", true, false):
		if body != self:
			_leaf_col = body
			break

func _get_anim() -> AnimationPlayer:
	if _anim != null and is_instance_valid(_anim):
		return _anim
	var p := get_parent()
	while p != null:
		var ap := p.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap != null:
			_anim = ap
			return _anim
		p = p.get_parent()
	return null

func _set_leaf_col(on: bool) -> void:
	if _leaf_col != null and is_instance_valid(_leaf_col):
		_leaf_col.set_deferred("collision_layer", 1 if on else 0)

func _restore_leaf_col_when_clear(retries: int = 4) -> void:
	## 关门后等玩家离开门洞再恢复门叶碰撞，避免把玩家关在里面
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.global_position.distance_to(global_position) < 1.4 and retries > 0:
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			_restore_leaf_col_when_clear(retries - 1))
		return
	_set_leaf_col(true)

func available() -> bool:
	return true

func get_prompt() -> String:
	if locked:
		return locked_prompt
	return "推开" if not _open else "关上"

func _do_interact(_player: Node3D) -> void:
	if locked:
		AudioMgr.play("unlock_click", -8.0, 0.8)
		return
	_open = not _open
	var anim := _get_anim()
	if anim == null:
		return
	if _open:
		anim.play("door_open")
		_set_leaf_col(false)   # 扫掠期间不与玩家/射线碰撞
		AudioMgr.play_at("creak_wood", global_position, -8.0)
	else:
		anim.play("door_close")
		_set_leaf_col(false)
		AudioMgr.play_at("door_bang", global_position, -14.0, 0.7)
		get_tree().create_timer(0.75).timeout.connect(func() -> void:
			_restore_leaf_col_when_clear())

func set_locked(v: bool, prompt: String = "") -> void:
	locked = v
	if prompt != "":
		locked_prompt = prompt

func slam_once() -> void:
	## MS-01 廊门拍响：猛开一角再重重弹回
	var anim := _get_anim()
	if anim == null or _open:
		return
	anim.play("door_open")
	anim.seek(0.4, true)
	await get_tree().create_timer(0.16).timeout
	if not is_instance_valid(anim) or _open:
		return
	anim.play_backwards("door_open")
	anim.seek(0.4, true)
	await get_tree().create_timer(0.22).timeout
	if not is_instance_valid(anim):
		return
	AudioMgr.play_at("door_bang", global_position, -2.0)
	anim.stop()
