extends StaticBody3D
class_name Interactable
## 交互物基类：提示文本 / 一次性交互 / 碰撞层(4)

@export var prompt_text := "交互"
@export var icon_type := "hand"   # "hand" 手掌·可拿可操作 / "eye" 眼睛·可翻看
@export var once := false
var _used := false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0

func get_icon_type() -> String:
	return icon_type

func available() -> bool:
	return not (once and _used)

func get_prompt() -> String:
	if not available():
		return ""
	return prompt_text

func interact(_player: Node3D) -> void:
	if not available():
		return
	_used = true
	_do_interact(_player)

func _do_interact(_player: Node3D) -> void:
	pass

## 生成包围碰撞盒（由 WorldBuilder 调用）
func add_box_collision(size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = offset
	add_child(col)
