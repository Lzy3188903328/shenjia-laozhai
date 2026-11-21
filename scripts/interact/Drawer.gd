extends Interactable
class_name Drawer
## 抽屉/暗格：拉开动画（drawer_open），可锁定；携带内容物（道具/文档）与惊吓

signal opened

@export var item_inside := ""
@export var doc_inside := ""
@export var scare_id := ""            # 拉开时触发的小惊吓
@export var scare_pos_offset := Vector3(0, 0.3, 0)

var locked := false
var locked_prompt := "锁着呢"
var _open := false
var _anim: AnimationPlayer
var _spawned := false

func _ready() -> void:
	super._ready()
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	prompt_text = "拉开"

func set_locked(v: bool, prompt: String = "") -> void:
	locked = v
	if prompt != "":
		locked_prompt = prompt

func get_prompt() -> String:
	if _open:
		return ""
	if locked:
		return locked_prompt
	return prompt_text

func _do_interact(_player: Node3D) -> void:
	if _open:
		return
	if locked:
		AudioMgr.play("unlock_click", -10.0, 0.7)
		return
	_open = true
	if _anim != null:
		_anim.play("drawer_open")
	AudioMgr.play_at("drawer_roll", global_position, -6.0)
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self):
		return
	_spawn_contents()
	opened.emit()

func _spawn_contents() -> void:
	if _spawned:
		return
	_spawned = true
	if scare_id != "":
		var scare := get_tree().get_first_node_in_group("scare_runner")
		if scare != null and scare.has_method("run_scare"):
			scare.run_scare(scare_id, global_position + scare_pos_offset)
	if doc_inside != "":
		_spawn_pickup("res://scripts/interact/DocPickup.gd", doc_inside, ItemDB.doc_mesh(doc_inside))
	elif item_inside != "":
		_spawn_pickup("res://scripts/interact/Pickup.gd", item_inside, ItemDB.item_mesh(item_inside))

func _spawn_pickup(script_path: String, id: String, model_path: String) -> void:
	var script: GDScript = load(script_path)
	var pk: Interactable = script.new()
	pk.name = id
	var world := get_tree().current_scene
	world.add_child(pk)
	pk.global_position = global_position + Vector3(0, 0.3, 0)
	if model_path != "":
		var scene: PackedScene = load("res://assets/props/%s.glb" % model_path)
		if scene != null:
			var inst := scene.instantiate()
			inst.scale = Vector3.ONE * 0.8
			pk.add_child(inst)
	pk.add_box_collision(Vector3(0.3, 0.25, 0.3))
