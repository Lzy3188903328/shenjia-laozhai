extends Interactable
class_name JadeChoice
## 终局抉择：天井玉佩台 —— 放回玉佩 = 真结局 / 携玉逃离南门 = 伪结局

func _ready() -> void:
	super._ready()
	prompt_text = "把玉佩放回牌位前"

func available() -> bool:
	return GameState.get_flag("finale") and not GameState.get_flag("ending_done")

func get_prompt() -> String:
	if not GameState.get_flag("finale"):
		return ""
	if GameState.has_item("jade_pendant"):
		return "把玉佩放回牌位前"
	return "牌位前的空位——玉佩不在此身"

func _do_interact(_player: Node3D) -> void:
	if not GameState.has_item("jade_pendant"):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("toast"):
			hud.toast("玉佩不在你身上。十年前她把玉佩锁进了闺房妆奁……去取回来还她。")
		return
	GameState.remove_item("jade_pendant")
	GameState.set_flag("ending_done")
	var bride := get_tree().get_first_node_in_group("red_bride")
	if bride != null:
		bride.active = false
	GameState.reach_ending("true")
