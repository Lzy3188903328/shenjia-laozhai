extends Interactable
class_name Curtain
## 床幔：掀开（bed_curtain_open）+ 床幔白影惊吓 + 床下暗格文档

@export var doc_inside := ""
@export var scare_id := "curtain_ghost"
var _open := false
var _anim: AnimationPlayer

func _ready() -> void:
	super._ready()
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	prompt_text = "掀开床幔"

func get_prompt() -> String:
	if _open:
		return "查看床底"
	return prompt_text

func _do_interact(_player: Node3D) -> void:
	if not _open:
		_open = true
		if _anim != null:
			_anim.play("bed_curtain_open")
		var runner := get_tree().get_first_node_in_group("scare_runner")
		if runner != null and scare_id != "":
			runner.run_scare(scare_id, global_position + Vector3(0, 1.2, 0))
		await get_tree().create_timer(1.4).timeout
		if not is_instance_valid(self):
			return
		prompt_text = "查看床底"
	else:
		# 床下暗格 → 日记 · 下
		if doc_inside != "" and not GameState.get_flag("got_diary_b"):
			GameState.set_flag("got_diary_b")
			GameState.add_doc(doc_inside)
			AudioMgr.play("paper_flip", -4.0)
			var ui := get_tree().get_first_node_in_group("reader_ui")
			if ui != null and ui.has_method("open_doc"):
				ui.open_doc(doc_inside)
		else:
			AudioMgr.play("breath_short", -10.0)
