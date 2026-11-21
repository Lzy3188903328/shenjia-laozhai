extends Interactable
class_name MendChest
## 补扎替身侧桌（玩法扩展 §二）：待修男装纸人胸架，红线引人靠近
## E 打开桌面近景；追逐/结局开始后停用；保存已做对的步骤

func _ready() -> void:
	super._ready()
	prompt_text = "查看松脱的襟口"

func available() -> bool:
	# 追逐或结局开始后停用工作台
	if GameState.get_flag("finale"):
		return false
	if GameState.get_flag("ending_done"):
		return false
	return true

func get_prompt() -> String:
	if not available():
		return ""
	if GameState.get_flag("mend_done"):
		return "再看一眼补好的襟口"
	return prompt_text

func _do_interact(_player: Node3D) -> void:
	var ui := get_tree().get_first_node_in_group("mend_ui")
	if ui != null and ui.has_method("open_ui"):
		ui.open_ui(self)
