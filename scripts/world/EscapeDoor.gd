extends Interactable
class_name EscapeDoor
## 南门（逃离出口）：终局前紧锁；终局后可逃 → 伪结局

func _ready() -> void:
	super._ready()
	prompt_text = "推开大门"

func get_prompt() -> String:
	if GameState.get_flag("finale") and not GameState.get_flag("ending_done"):
		return "夺门而逃"
	return "门闩从外面反扣着。信上只说雨夜叩门自开——却没说放不放你走。"

func _do_interact(_player: Node3D) -> void:
	if not GameState.get_flag("finale"):
		AudioMgr.play("door_bang", -6.0, 0.6)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("toast"):
			hud.toast("门闩从外面反扣着。信上只说雨夜叩门自开——却没说放不放你走。")
		return
	GameState.set_flag("ending_done")
	var bride := get_tree().get_first_node_in_group("red_bride")
	if bride != null:
		bride.active = false
	GameState.reach_ending("false")
