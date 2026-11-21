extends Interactable
class_name TriggerZone
## 无碰撞体触发区（Area3D）：进入时调用 ScareRunner / 自定义回调
## 由 WorldBuilder 放置在走廊、纸人背后等位置

@export var scare_id := ""
@export var trigger_size := Vector3(2.0, 2.0, 2.0)
@export var one_shot := true

var _area: Area3D
var _fired := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2   # 玩家
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = trigger_size
	col.shape = shape
	_area.add_child(col)
	add_child(_area)
	_area.body_entered.connect(_on_body)

func _on_body(body: Node3D) -> void:
	if _fired and one_shot:
		return
	if body.name != "Player":
		return
	_fired = true
	var runner := get_tree().get_first_node_in_group("scare_runner")
	if runner != null and scare_id != "":
		runner.run_scare(scare_id, global_position)
