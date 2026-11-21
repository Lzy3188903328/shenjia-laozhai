extends Interactable
class_name DocPickup
## 可收集文档：拾起即打开阅读器，加入线索册

@export var doc_id := ""

func _ready() -> void:
	super._ready()
	icon_type = "eye"
	if doc_id == "":
		doc_id = name
	prompt_text = "翻看 · %s" % _doc_title()

func _doc_title() -> String:
	var d: Dictionary = ItemDB.DOCS.get(doc_id, {})
	return String(d.get("title", doc_id))

func _do_interact(_player: Node3D) -> void:
	GameState.add_doc(doc_id)
	AudioMgr.play("paper_flip", -4.0)
	var ui := get_tree().get_first_node_in_group("reader_ui")
	if ui != null and ui.has_method("open_doc"):
		ui.open_doc(doc_id)
	# 文档本体消失（已收入线索册）
	queue_free()
