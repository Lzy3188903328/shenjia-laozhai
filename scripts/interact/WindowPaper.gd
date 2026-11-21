extends Interactable
class_name WindowPaper
## 灯下辨纸痕（玩法扩展 §三）：妆奁边的旧窗纸
## 正面举灯照平凹痕；沿桌沿 40°~75° 侧照并稳定半秒 → 压纹两层渐显；
## 按 E 打开「查看压纹」近景，左右灯位按钮完成同一观察；辨认后记入线索册。

var _pattern: Label3D
var _reveal := 0.0
var _stable := 0.0
var _revealed := false
var _recorded := false

func _ready() -> void:
	super._ready()
	prompt_text = "查看压纹"
	icon_type = "eye"
	add_box_collision(Vector3(0.4, 0.3, 0.4))
	# 纸面本体（微卷角纸片）
	var paper := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.3, 0.22)
	paper.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.82, 0.76, 0.62)
	pmat.roughness = 0.95
	paper.material_override = pmat
	add_child(paper)
	paper.position = Vector3(0, -0.03, 0)
	paper.rotation_degrees = Vector3(0, 25, 0)
	# 两处蜡痕提示（桌面灯位）
	for x in [-0.28, 0.28]:
		var wax := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.03
		wm.bottom_radius = 0.03
		wm.height = 0.008
		wax.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.9, 0.82, 0.55)
		wax.material_override = wmat
		add_child(wax)
		wax.position = Vector3(x, -0.075, 0.12)
	# 压纹层（渐显）：折枝花 + 「花厅」题字
	_pattern = Label3D.new()
	_pattern.text = "花厅"
	_pattern.font_size = 160
	_pattern.pixel_size = 0.0012
	_pattern.modulate = Color(0.35, 0.1, 0.08, 0.0)
	_pattern.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(_pattern)
	_pattern.position = Vector3(0, 0.005, 0)
	_pattern.rotation_degrees = Vector3(-90, 25, 0)
	var petal := Label3D.new()
	petal.text = "❀"
	petal.font_size = 240
	petal.pixel_size = 0.0012
	petal.modulate = Color(0.35, 0.1, 0.08, 0.0)
	add_child(petal)
	petal.position = Vector3(-0.09, 0.006, 0)
	petal.rotation_degrees = Vector3(-90, 25, 0)
	petal.name = "PetalMark"

func _process(delta: float) -> void:
	if _revealed:
		return
	var player := get_tree().get_first_node_in_group("player")
	var cam: Camera3D = player.get("camera") if player != null else null
	if player == null or cam == null:
		return
	# 条件：手灯点亮 + 两米内 + 视线照向纸面且与法线夹角 40°~75° + 稳定半秒
	var lantern: Node3D = player.find_child("LanternRoot", true, false)
	var lit := false
	if lantern != null:
		for c in lantern.get_children():
			if c is Light3D and c.light_energy > 0.3:
				lit = true
	if not lit:
		_stable = 0.0
		return
	if global_position.distance_to(player.global_position) > 2.0:
		_stable = 0.0
		return
	var fwd := -(cam.global_transform.basis.z)
	var normal := Vector3.UP
	var dotv := fwd.dot(normal)
	if dotv < 0.259 or dotv > 0.766:   # 法线夹角 40°~75°
		_stable = 0.0
		return
	_stable += delta
	if _stable >= 0.5:
		_revealed = true
		_fade_pattern_in()
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("toast"):
			hud.toast("折枝花、缺瓣的蕊，和「花厅」两个字，从纸面上浮了出来。")

func _fade_pattern_in() -> void:
	var tw := create_tween()
	tw.tween_method(_set_alpha, 0.0, 1.0, 1.2)

func _set_alpha(v: float) -> void:
	for c in get_children():
		if c is Label3D:
			var l := c as Label3D
			var base := Color(0.35, 0.1, 0.08)
			l.modulate = Color(base.r, base.g, base.b, v)

func get_prompt() -> String:
	if _revealed:
		return "辨认纹样"
	return "查看压纹"

func _do_interact(_player: Node3D) -> void:
	var ui := get_tree().get_first_node_in_group("window_paper_ui")
	if ui != null and ui.has_method("open_ui"):
		ui.open_ui(self)
