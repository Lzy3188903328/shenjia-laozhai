extends Interactable
class_name Pickup
## 可拾取道具：拾起进行囊；hand_lantern_thrown 特例 → 拾回油灯

@export var item_id := ""
@export var only_pickup_marker := false   # 扔出的灯笼（不入库，拾回即复燃）

func _ready() -> void:
	super._ready()
	if item_id == "":
		item_id = name
	if prompt_text.begins_with("交互"):
		prompt_text = "拾取 · %s" % ItemDB.item_name(item_id)

func _do_interact(player: Node3D) -> void:
	if only_pickup_marker or item_id == "hand_lantern_thrown":
		if player.has_method("retrieve_thrown_lantern"):
			player.retrieve_thrown_lantern()
		queue_free()
		return
	GameState.add_item(item_id)
	AudioMgr.play("paper_flip", -6.0)
	queue_free()
