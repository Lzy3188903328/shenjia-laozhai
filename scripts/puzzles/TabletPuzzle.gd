extends Node3D
class_name TabletPuzzle
## 谜题一：祠堂牌位归位（昭穆之制）
## 上层：沈松年(左) 沈王氏(右)｜中层：沈鸿儒(左) 沈周氏(右)｜下层：(空) 沈清欢(右)
## 沈柏舟的牌位不属于此架 → 放回供桌横头的"归还位"

signal solved

const TABLET_IDS := ["songnian", "wangshi", "hongru", "zhoushi", "baizhou", "qinghuan"]
const TABLET_NAMES := {
	"songnian": "沈松年", "wangshi": "沈王氏", "hongru": "沈鸿儒",
	"zhoushi": "沈周氏", "baizhou": "沈柏舟", "qinghuan": "沈清欢",
}
# 正确布局：slot_index -> tablet_id（-1 表示空位）
const CORRECT := ["songnian", "wangshi", "hongru", "zhoushi", "", "qinghuan"]
# 初始打乱
const INITIAL := ["hongru", "baizhou", "songnian", "qinghuan", "wangshi", "zhoushi"]

var slots: Array[Node3D] = []       # 6 个牌位插槽 Marker3D
var return_spot: Node3D             # 供桌横头归还位
var held_tablet := ""               # 玩家手中牌位
var slot_contents: Array[String] = []
var _tablets: Dictionary = {}       # tablet_id -> Node3D (glb instance)
var _return_held := false           # 归还位上是否已有柏舟

func _ready() -> void:
	add_to_group("tablet_puzzle")

func setup(slot_markers: Array[Node3D], spot: Node3D) -> void:
	slots = slot_markers
	return_spot = spot
	slot_contents.assign(INITIAL)
	for i in slots.size():
		var tablet_id := slot_contents[i]
		if tablet_id != "":
			_place_tablet_mesh(tablet_id, slots[i])
		_add_slot_interact(i)
	_add_return_interact()

func _place_tablet_mesh(tablet_id: String, parent_node: Node3D) -> void:
	var scene: PackedScene = load("res://assets/props/tablet.glb")
	var t := scene.instantiate()
	parent_node.add_child(t)
	t.name = "tablet_" + tablet_id
	_tablets[tablet_id] = t
	_add_name_label(t, tablet_id)

func _add_name_label(tablet: Node3D, tablet_id: String) -> void:
	var label := Label3D.new()
	label.text = String(TABLET_NAMES[tablet_id])
	label.font_size = 30
	label.pixel_size = 0.002
	label.modulate = Color(0.1, 0.07, 0.05)
	label.no_depth_test = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	tablet.add_child(label)
	label.position = Vector3(0, 0.16, 0.016)
	label.rotation.y = PI  # 纸条面向玩家一侧由插槽朝向决定

func _add_slot_interact(index: int) -> void:
	var s := slots[index]
	var si := SlotInteract.new()
	si.puzzle = self
	si.slot_index = index
	s.name = "Slot%d" % index
	s.add_child(si)
	si.add_box_collision(Vector3(0.28, 0.36, 0.26))

func _add_return_interact() -> void:
	var si := SlotInteract.new()
	si.puzzle = self
	si.slot_index = -1   # 归还位
	return_spot.add_child(si)
	si.add_box_collision(Vector3(0.5, 0.3, 0.4))

class SlotInteract extends Interactable:
	var puzzle: TabletPuzzle
	var slot_index := 0

	func _ready() -> void:
		super._ready()

	func get_prompt() -> String:
		if puzzle == null:
			return ""
		var occupied := ""
		if slot_index >= 0 and puzzle.slot_contents[slot_index] != "":
			occupied = "（%s）" % TabletPuzzle.TABLET_NAMES[puzzle.slot_contents[slot_index]]
		elif slot_index == -1 and puzzle._return_held:
			occupied = "（归还位）"
		if puzzle.held_tablet != "":
			if slot_index == -1:
				return "将 %s 放回供桌横头" % TabletPuzzle.TABLET_NAMES[puzzle.held_tablet]
			return "将 %s 安放于此 %s" % [TabletPuzzle.TABLET_NAMES[puzzle.held_tablet], occupied]
		if slot_index == -1:
			return ""
		if occupied == "":
			return "空位"
		return "请起 %s" % occupied.trim_prefix("（").trim_suffix("）")

	func interact(player: Node3D) -> void:
		if puzzle == null:
			return
		puzzle.handle_slot(slot_index, self)

func handle_slot(index: int, _interact: SlotInteract = null) -> void:
	# 归还位
	if index == -1:
		if held_tablet == "baizhou":
			_return_held = true
			var t: Node3D = _tablets["baizhou"]
			t.get_parent().remove_child(t)
			return_spot.add_child(t)
			t.position = Vector3(0, 0.02, 0)
			held_tablet = ""
			AudioMgr.play("unlock_click", -6.0)
			_check()
		elif held_tablet != "":
			AudioMgr.play("puzzle_fail", -14.0, 0.6)
			_toast("此位是供桌横头——放不得别家的牌位。")
		return
	# 拿起
	if held_tablet == "":
		var cur := slot_contents[index]
		if cur == "":
			return
		held_tablet = cur
		slot_contents[index] = ""
		if _tablets.has(cur):
			var t: Node3D = _tablets[cur]
			t.reparent(self)
			t.position = slots[index].position + Vector3(0, 0.25, 0)
			t.rotation.y = slots[index].rotation.y
		AudioMgr.play("paper_flip", -10.0, 0.8)
		if not GameState.get_flag("seen_tablet_back"):
			GameState.set_flag("seen_tablet_back")
			GameState.add_doc("doc_09_tablet_backs")
			_toast("牌位背面刻着生辰与忌日……已记入线索册。")
	# 放下
	else:
		var swap := slot_contents[index]
		var held_node: Node3D = _tablets[held_tablet] if _tablets.has(held_tablet) else null
		if held_node != null:
			held_node.reparent(slots[index])
			held_node.position = Vector3.ZERO
			held_node.rotation.y = 0
		if swap != "":
			var swap_node: Node3D = _tablets[swap]
			swap_node.reparent(self)
			swap_node.position = slots[index].position + Vector3(0, 0.25, 0)
		slot_contents[index] = held_tablet
		held_tablet = swap if swap != "" else ""
		AudioMgr.play("unlock_click", -8.0)
		_check()

func _toast(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		hud.toast(text)

func _check() -> void:
	for i in CORRECT.size():
		var want: String = CORRECT[i]
		var got := slot_contents[i]
		if want != got:
			# 错误反馈：烛火摇晃音
			if got != "" or want != "":
				if got != want and randf() < 0.7:
					AudioMgr.play("puzzle_fail", -20.0, 0.5)
					_toast("昭穆失序……烛火晃了一下。")
			return
	if not _return_held:
		_toast("架上归序了。可这架旁的牌位，不属于沈家这一支。")
		return
	GameState.solve_puzzle("tablets")
	AudioMgr.play("puzzle_success", -4.0)
	_toast("牌位归位。供桌底下传来一声铜簧轻响——暗格开了。")
	solved.emit()

func is_solved() -> bool:
	return GameState.get_flag("puzzle_tablets")
