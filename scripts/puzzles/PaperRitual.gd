extends Node3D
class_name PaperRitual
## 谜题四：扎纸/民俗禁忌 三步仪式（破"鬼打墙"，开书架暗门）
## ① 点睛：左眼先点，后右眼（需朱砂笔）
## ② 上香：中 → 左 → 右（需火折子）
## ③ 敲铃：选"子时三刻"，敲三响
## 顺序错则重置本步 + 惊吓音效

signal completed

var phase := 1                  # 1 点睛 2 上香 3 敲铃
var _eyes_done: Array[String] = []     # "L" / "R"
var _incense_done: Array[String] = []  # "M" / "L" / "R"
var _bell_chosen := ""
var _bell_rings := 0

var figure_root: Node3D
var face_mesh: MeshInstance3D
var burner: Node3D
var bell_node: Node3D
var _bell_anim: AnimationPlayer

const INCENSE_ORDER := ["M", "L", "R"]

func _ready() -> void:
	add_to_group("paper_ritual")

func setup(figure: Node3D, burner_node: Node3D, bell: Node3D) -> void:
	figure_root = figure
	burner = burner_node
	bell_node = bell
	face_mesh = figure_root.find_child("Face", true, false) as MeshInstance3D
	_bell_anim = bell_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# 三个香头交互
	for id in ["Mid", "L", "R"]:
		var stick := burner.find_child("Incense" + id, true, false)
		if stick != null:
			var inc := IncenseInteract.new()
			inc.ritual = self
			inc.spot_id = id
			inc.name = "IncenseInteract" + id
			stick.add_child(inc)
			inc.add_box_collision(Vector3(0.09, 0.3, 0.09))
	# 眼睛交互（挂在纸人头部两侧）
	var head := figure_root.find_child("Head", true, false)
	if head != null:
		for side in ["L", "R"]:
			var eye := EyeInteract.new()
			eye.ritual = self
			eye.spot_id = side
			eye.name = "EyeInteract" + side
			head.add_child(eye)
			eye.position = Vector3(-0.055 if side == "L" else 0.055, 0.02, 0.13)
			eye.add_box_collision(Vector3(0.09, 0.12, 0.09))
	# 铜铃交互
	var ring := BellInteract.new()
	ring.ritual = self
	bell_node.add_child(ring)
	ring.add_box_collision(Vector3(0.22, 0.3, 0.22), Vector3(0, -0.05, 0))

func _toast(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		hud.toast(text)

func _fail(msg: String) -> void:
	AudioMgr.play("puzzle_fail", -10.0)
	_toast(msg)
	match phase:
		1: _eyes_done.clear()
		2: _incense_done.clear()
		3:
			_bell_chosen = ""
			_bell_rings = 0
	# 民俗犯忌 → 轻惊吓
	AudioMgr.play_at("whisper", figure_root.global_position, -12.0)

# ---------------------------------------------------------- ① 点睛
func paint_eye(spot: String) -> String:
	## 返回结果提示
	if phase != 1:
		return ""
	if not GameState.has_item("cinnabar_pen"):
		return "你得先有一支点睛笔。"
	var order: Array[String] = ["L", "R"]
	var next_needed: String = order[_eyes_done.size()]
	if spot != next_needed:
		_fail("扎纸行的规矩：开左眼认主。先左，后右。")
		return ""
	_eyes_done.append(spot)
	AudioMgr.play("unlock_click", -4.0, 1.2)
	_draw_eye(spot)
	if _eyes_done.size() >= 2:
		phase = 2
		_toast("纸人睁了眼……它好像看了你一眼。去香案点香。")
	return ""

func _draw_eye(spot: String) -> void:
	# 换脸材质：无眼 → 有眼（点睛后）
	if face_mesh == null:
		return
	var tex: Texture2D = load("res://assets/tex/t_face_eyed.png")
	if tex == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.92
	face_mesh.material_override = mat

# ---------------------------------------------------------- ② 上香
func light_incense(spot: String) -> String:
	if phase != 2:
		return ""
	if not GameState.has_item("fire_starter"):
		return "没有火，点不了香。去寻个火折子。"
	var next_needed: String = INCENSE_ORDER[_incense_done.size()]
	if spot != next_needed:
		_fail("香序错了。中间为先，再左，再右。")
		return ""
	_incense_done.append(spot)
	var ember := burner.find_child("Ember" + {"M": "Mid", "L": "L", "R": "R"}[spot], true, false)
	if ember != null:
		ember.visible = true
	AudioMgr.play("lantern_relight", -12.0, 1.3)
	if _incense_done.size() >= 3:
		phase = 3
		_toast("三炷香齐了。去敲铜铃——铃身上刻着时辰。")
	return ""

# ---------------------------------------------------------- ③ 敲铃
func choose_bell_hour(hour: String) -> void:
	if phase != 3:
		return
	_bell_chosen = hour
	_bell_rings = 0
	_toast("已择「%s」。敲三响。" % hour)

func ring_bell() -> String:
	## 返回面板反馈文本；空串 = 这一响有效
	if phase != 3:
		return "香与睛未齐——铃不认人。"
	if _bell_chosen == "":
		return "先择一个时辰再敲。"
	if _bell_chosen != "子时三刻":
		var wrong := "时辰错了——账上写的是「子时三刻，阵开灯灭」。已重置。"
		_fail("时辰错了。")
		return wrong
	_bell_rings += 1
	if _bell_anim != null:
		_bell_anim.play("bell_ring")
	AudioMgr.play("bell_single", -2.0)
	if _bell_rings >= 3:
		_complete()
	return ""

func _complete() -> void:
	GameState.solve_puzzle("ritual")
	AudioMgr.play("puzzle_success", -2.0)
	# MS-12：全宅纸人齐响（竹骨共振）
	for i in 5:
		var d := randf_range(0.15, 1.6)
		get_tree().create_timer(d).timeout.connect(func() -> void:
			AudioMgr.play_at("creak_wood", figure_root.global_position + Vector3(randf_range(-3, 3), 1, randf_range(-3, 3)), -6.0, randf_range(0.8, 1.5)))
	_toast("铃响三声，灯影一晃——身后传来竹篾摩擦的轻响。书架后有一阵风。")
	completed.emit()

# ---------------------------------------------------------- 交互子类
class EyeInteract extends Interactable:
	var ritual: PaperRitual
	var spot_id := ""

	func get_prompt() -> String:
		if ritual.phase != 1:
			return ""
		return "点睛（%s眼）" % ("左" if spot_id == "L" else "右")

	func _do_interact(_player: Node3D) -> void:
		var msg := ritual.paint_eye(spot_id)
		if msg != "":
			ritual._toast(msg)

class IncenseInteract extends Interactable:
	var ritual: PaperRitual
	var spot_id := ""

	func get_prompt() -> String:
		if ritual.phase != 2:
			return ""
		var names := {"M": "中", "L": "左", "R": "右"}
		return "点燃%s侧的香" % names[spot_id]

	func _do_interact(_player: Node3D) -> void:
		var msg := ritual.light_incense(spot_id)
		if msg != "":
			ritual._toast(msg)

class BellInteract extends Interactable:
	var ritual: PaperRitual

	func get_prompt() -> String:
		if ritual.phase != 3:
			return ""
		return "敲铜铃"

	func _do_interact(_player: Node3D) -> void:
		var ui := get_tree().get_first_node_in_group("bell_ui")
		if ui != null and ui.has_method("open_bell"):
			ui.open_bell(ritual)
