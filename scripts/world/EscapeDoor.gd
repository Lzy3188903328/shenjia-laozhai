extends Interactable
class_name EscapeDoor
## 南门（逃离出口）：终局前紧锁；终局后可逃 → 伪结局

func _ready() -> void:
	super._ready()
	prompt_text = "推开大门"

func get_prompt() -> String:
	if GameState.get_flag("finale") and not GameState.get_flag("ending_done"):
		return "夺门而逃"
	return "大门闩死了，推不开。"

func _do_interact(_player: Node3D) -> void:
	if not GameState.get_flag("finale"):
		AudioMgr.play("door_bang", -6.0, 0.6)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("toast"):
			hud.toast("门闩死死了。信上说：雨夜叩门自开——可它没说什么时候开。")
		return
	GameState.set_flag("ending_done")
	var bride := get_tree().get_first_node_in_group("red_bride")
	if bride != null:
		bride.active = false
	GameState.reach_ending("false")
