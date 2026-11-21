extends Interactable
class_name SealedDoor
## 封门（玩法扩展 §四）：给「名莫应」一次真正的选择
## 血书前首次经过：门内轻叩两声 + 门缝纸条颤动，只能查看门闩；
## 终局追逐开始后经过同一扇门：清欢喊名 + 红袖伸出，可「按住 E 应一声」
## 应声 → 鬼影转向封门查声（≤4 秒）；沉默走开 → 第二声渐远。均一次。

var _knock_intro_played := false
var _encounter_played := false
var _sleeve: MeshInstance3D
var _paper_strip: MeshInstance3D
var _respond_hold := 0.0

func _ready() -> void:
	super._ready()
	prompt_text = "查看门闩"
	# 封门外观：门板 + 门缝下伸出的红袖（初始收起）+ 门缝纸条
	var door_scene: PackedScene = load("res://assets/props/door.glb")
	if door_scene != null:
		var inst := door_scene.instantiate()
		add_child(inst)
		inst.rotation.y = 0
		inst.scale = Vector3(0.92, 0.98, 1)
	add_box_collision(Vector3(1.15, 2.15, 0.42), Vector3(-0.02, 1.06, 0))
	_sleeve = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.22, 0.45)
	_sleeve.mesh = pm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.45, 0.06, 0.05)
	_sleeve.material_override = smat
	add_child(_sleeve)
	_sleeve.position = Vector3(0.3, 0.12, 0.24)
	_sleeve.rotation_degrees = Vector3(-70, 0, 0)
	_sleeve.visible = false
	_paper_strip = MeshInstance3D.new()
	var pm2 := PlaneMesh.new()
	pm2.size = Vector2(0.1, 0.18)
	_paper_strip.mesh = pm2
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.85, 0.8, 0.68)
	_paper_strip.material_override = pmat
	add_child(_paper_strip)
	_paper_strip.position = Vector3(-0.3, 0.1, 0.23)
	_paper_strip.rotation_degrees = Vector3(-80, 0, 0)
	# 首次经过触发区（铺垫：血书之前）
	var tz := Area3D.new()
	tz.collision_layer = 0
	tz.collision_mask = 2
	var tcol := CollisionShape3D.new()
	var tshape := BoxShape3D.new()
	tshape.size = Vector3(3.0, 2.4, 3.0)
	tcol.shape = tshape
	tz.add_child(tcol)
	add_child(tz)
	tz.body_entered.connect(_on_intro_body)

func _on_intro_body(body: Node3D) -> void:
	if body.name != "Player" or _knock_intro_played:
		return
	_knock_intro_played = true
	AudioMgr.play_at("bangzi", global_position, -6.0, 0.7)
	var t := get_tree().create_timer(0.5)
	t.timeout.connect(func() -> void:
		AudioMgr.play_at("bangzi", global_position, -8.0, 0.6)
		_tremble_paper())
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		hud.toast("侧门里轻叩了两声，门缝下的纸条跟着颤了颤。")

func _tremble_paper() -> void:
	if _paper_strip == null or not is_instance_valid(_paper_strip):
		return
	var tw := _paper_strip.create_tween()
	tw.tween_property(_paper_strip, "rotation:z", 0.25, 0.08)
	tw.tween_property(_paper_strip, "rotation:z", -0.2, 0.08)
	tw.tween_property(_paper_strip, "rotation:z", 0.0, 0.1)

func available() -> bool:
	return true

func get_prompt() -> String:
	if GameState.get_flag("finale") and not GameState.get_flag("ending_done") and _encounter_played == false:
		return "按住 E 应一声" if _respond_ready() else "门里有人在喊……"
	if GameState.get_flag("finale"):
		return ""
	return "查看门闩"

func _respond_ready() -> bool:
	# 仅当玩家主动瞄准封门时显示应答（按住 0.6 秒）
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return true

func _process(delta: float) -> void:
	if not visible or GameState.get_flag("ending_done"):
		return
	# 正式遭遇触发：终局开始后玩家经过封门，且未处于近身追逐/结局演出
	if not _encounter_played and GameState.get_flag("finale"):
		var player := get_tree().get_first_node_in_group("player")
		var bride := get_tree().get_first_node_in_group("red_bride")
		if player != null and global_position.distance_to(player.global_position) < 3.0:
			if bride == null or not bride._can_see_player():
				_play_encounter()
	# 应答：按住 E 0.6 秒（仅瞄准此门时）
	if _encounter_played and not _responded:
		var player := get_tree().get_first_node_in_group("player")
		var runner := get_tree().get_first_node_in_group("scare_runner")
		var aim_here := false
		if player != null and Input.is_action_pressed("interact"):
			var tgt: Node = player.get("_current_target")
			aim_here = tgt == self
		if aim_here:
			_respond_hold += delta
			if _respond_hold >= 0.6:
				_respond()
		else:
			_respond_hold = 0.0

var _responded := false

func _play_encounter() -> void:
	_encounter_played = true
	GameState.set_flag("voice_encounter_played")
	AudioMgr.play_at("bangzi", global_position, -4.0, 0.8)
	var t := get_tree().create_timer(0.7)
	t.timeout.connect(func() -> void:
		AudioMgr.play_at("opera_voice", global_position, 2.0, 0.85)
		_sleeve.visible = true
		var tw := _sleeve.create_tween()
		tw.tween_property(_sleeve, "position:z", 0.34, 0.5))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		hud.toast("门里用清欢的声音喊：「阿九，是你么？」——门缝下伸出一角红袖。")

func _respond() -> void:
	if _responded:
		return
	_responded = true
	GameState.set_flag("voice_responded")
	AudioMgr.play_at("opera_voice", global_position, 0.0, 0.6)   # 门里用阿九自己的声音重复
	var tw := _sleeve.create_tween()
	tw.tween_property(_sleeve, "position:z", 0.24, 0.18)
	var bride := get_tree().get_first_node_in_group("red_bride")
	if bride != null and bride.has_method("investigate_door"):
		bride.investigate_door(global_position, 4.0)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		hud.toast("门里用你自己的声音重复了刚才的回答——红袖猛地缩了回去。红衣的身影转向了这扇门。")

func _do_interact(_player: Node3D) -> void:
	if GameState.get_flag("finale"):
		return   # 终局阶段：E 由按住应答逻辑处理
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		hud.toast("闩从廊里扣着。里头刚才是谁？")
	AudioMgr.play("unlock_click", -10.0, 0.6)
