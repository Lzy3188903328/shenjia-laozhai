extends Node3D
class_name MirrorRoom
## 谜题三：铜镜光影折射（花厅暗房）
## 烛光 → M1 → M2 → M3 → 屏风"囍"字缺口，显出血字「十九」与阵法图
## 几何已在 Python 中验证为唯一解（俯视平面 x/z，与 Godot x/z 同构）

signal solved

# 镜面可选朝向（节点 yaw 度）——对应法线角 a: yaw = 90 - a
const YAW_STATES := [90.0, 45.0, 0.0, -45.0, -90.0]
const SOLUTION := [-45.0, 45.0, 0.0]   # 对应法线角 135/45/90
const MIRROR_EXTENT := 0.6
const TARGET_RADIUS := 0.35

# 房内局部坐标（烛台为原点）：x 东 / z 南
const CANDLE := Vector2(0, 0)
const MIRROR_POS := [Vector2(2.7, -0.4), Vector2(2.5, 2.4), Vector2(0.1, 2.9)]
const SCREEN_POS := Vector2(-1.6, 2.7)

var mirror_yaw: Array[float] = [90.0, 45.0, 0.0]
var mirror_nodes: Array[Node3D] = []
var candle_point: Vector3   # 世界坐标
var screen_point: Vector3
var _beam_mesh: MeshInstance3D
var _beam_im: ImmediateMesh
var _reveal_label: Label3D
var _diagram_label: Label3D

func _ready() -> void:
	add_to_group("mirror_room")

func setup(mirrors: Array[Node3D], candle_pos: Vector3, screen_pos: Vector3) -> void:
	mirror_nodes = mirrors
	candle_point = candle_pos
	screen_point = screen_pos
	_build_beam()
	_build_reveal()
	# 镜子交互
	for i in mirror_nodes.size():
		var mi := MirrorInteract.new()
		mi.room = self
		mi.index = i
		mi.prompt_text = "转动铜镜"
		mirror_nodes[i].add_child(mi)

func _build_beam() -> void:
	_beam_im = ImmediateMesh.new()
	_beam_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.75, 0.4, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.25)
	mat.emission_energy_multiplier = 2.0
	_beam_mesh.material_override = mat
	_beam_mesh.mesh = _beam_im
	add_child(_beam_mesh)
	_update_beam()

func _build_reveal() -> void:
	_reveal_label = Label3D.new()
	_reveal_label.text = "十九"
	_reveal_label.font_size = 220
	_reveal_label.pixel_size = 0.002
	_reveal_label.modulate = Color(0.45, 0.03, 0.02)
	_reveal_label.visible = false
	add_child(_reveal_label)
	_reveal_label.global_position = screen_point + Vector3(0, 1.5, 0)
	_diagram_label = Label3D.new()
	_diagram_label.text = "借命大阵 · 阵眼在水 · 子时三刻"
	_diagram_label.font_size = 44
	_diagram_label.pixel_size = 0.002
	_diagram_label.modulate = Color(0.45, 0.03, 0.02)
	_diagram_label.visible = false
	add_child(_diagram_label)
	_diagram_label.global_position = screen_point + Vector3(0, 0.9, 0)

class MirrorInteract extends Interactable:
	var room: MirrorRoom
	var index := 0

	func get_prompt() -> String:
		if room.mirror_yaw[index] == room.SOLUTION[index]:
			return "铜镜已对准光路"
		return "转动铜镜（当前 %d°）" % int(room.mirror_yaw[index])

	func _do_interact(_player: Node3D) -> void:
		var cur: int = room.YAW_STATES.find(room.mirror_yaw[index])
		var nxt: float = room.YAW_STATES[(cur + 1) % room.YAW_STATES.size()]
		room.mirror_yaw[index] = nxt
		var tw := room.mirror_nodes[index].create_tween()
		tw.tween_property(room.mirror_nodes[index], "rotation:y",
			deg_to_rad(nxt), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		AudioMgr.play("creak_wood", -12.0, randf_range(1.1, 1.4))
		room._update_beam()

# ---------------------------------------------------------- 光路计算（与 Python 求解器一致）
static func _reflect(d: Vector2, n: Vector2) -> Vector2:
	return d - 2.0 * d.dot(n) * n

func _normal_for(yaw_deg: float) -> Vector2:
	var a := deg_to_rad(yaw_deg)
	# 节点 yaw 旋转后镜面法线 = (sin yaw, cos yaw)（对应 +Z 面朝向）
	return Vector2(sin(a), cos(a))

func _chain() -> Dictionary:
	## 返回 {ok: bool, points: PackedVector2Array(局部2D), hit_dist: float}
	var points := PackedVector2Array()
	var pos := CANDLE
	points.append(pos)
	var d := (MIRROR_POS[0] - CANDLE).normalized()
	for i in MIRROR_POS.size():
		var n := _normal_for(mirror_yaw[i])
		var denom := d.dot(n)
		if absf(denom) < 1e-6:
			return {"ok": false, "points": points, "hit_dist": 99.0}
		var t: float = (MIRROR_POS[i] - pos).dot(n) / denom
		if t <= 0.05:
			return {"ok": false, "points": points, "hit_dist": 99.0}
		var hit := pos + d * t
		if (hit - MIRROR_POS[i]).length() > MIRROR_EXTENT:
			return {"ok": false, "points": points, "hit_dist": 99.0}
		points.append(hit)
		d = _reflect(d, n)
		pos = hit
	var rel := SCREEN_POS - pos
	var tproj := rel.dot(d)
	if tproj <= 0.0:
		return {"ok": false, "points": points, "hit_dist": 99.0}
	var closest := pos + d * tproj
	points.append(closest)
	var dist := (closest - SCREEN_POS).length()
	return {"ok": true, "points": points, "hit_dist": dist}

func _update_beam() -> void:
	if _beam_im == null:
		return
	_beam_im.clear_surfaces()
	var result := _chain()
	var pts: PackedVector2Array = result["points"]
	if pts.size() < 2:
		return
	var y := 1.15
	_beam_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in pts:
		# 局部2D → 以烛台为原点的世界坐标（房间组自身即原点）
		_beam_im.surface_add_vertex(Vector3(p.x, y, p.y))
	_beam_im.surface_end()
	var dist := float(result["hit_dist"])
	if result["ok"] and dist < TARGET_RADIUS:
		_on_solved()

func _on_solved() -> void:
	if GameState.get_flag("puzzle_mirror"):
		return
	GameState.solve_puzzle("mirror")
	AudioMgr.play("puzzle_success", -4.0)
	# 镜中红影一闪（惊吓E 联动）
	var runner := get_tree().get_first_node_in_group("scare_runner")
	if runner != null and runner.has_method("run_scare"):
		runner.run_scare("mirror_flash", screen_point + Vector3(0, 1.4, 0))
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void:
		_reveal_label.visible = true
		_diagram_label.visible = true
		AudioMgr.play("whisper", -8.0))
	solved.emit()
