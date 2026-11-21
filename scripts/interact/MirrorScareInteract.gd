extends Interactable
class_name MirrorScareInteract
## 梳妆台铜镜：凑近看 → MS-06 镜中红影（回头即消失）

var _mirror_used := false

func _ready() -> void:
	super._ready()
	icon_type = "eye"
	prompt_text = "凑近照镜"

func _do_interact(_player: Node3D) -> void:
	if _mirror_used:
		AudioMgr.play("breath_short", -14.0)
		return
	_mirror_used = true
	var runner := get_tree().get_first_node_in_group("scare_runner")
	if runner != null and runner.has_method("run_scare"):
		runner.run_scare("mirror_ghost", global_position)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		hud.toast("镜子里的你身后，站着一个穿红嫁衣的身影——你猛然回头……")
