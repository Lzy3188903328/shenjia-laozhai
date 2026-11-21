extends Interactable
class_name JewelryBoxInteract
## 闺房妆奁盒：交互打开八卦锁 UI；解开 → 盖开，产出 日记·上 + 玉佩

var _opened := false
var _box_anim: AnimationPlayer

func _ready() -> void:
	super._ready()
	prompt_text = "拨动妆奁盒上的八卦锁"
	add_to_group("jewelry_box")
	var wb := get_tree().get_first_node_in_group("world_builder")
	if wb != null and wb.get("bagua_lock") != null:
		var lock: BaguaLock = wb.get("bagua_lock")
		lock.solved.connect(_on_solved)

func get_prompt() -> String:
	if _opened:
		return ""
	if GameState.get_flag("puzzle_bagua"):
		return "打开妆奁盒"
	return prompt_text

func _do_interact(_player: Node3D) -> void:
	if _opened:
		return
	var wb := get_tree().get_first_node_in_group("world_builder")
	if wb == null:
		return
	var lock: BaguaLock = wb.get("bagua_lock")
	if lock == null:
		return
	if GameState.get_flag("puzzle_bagua"):
		_open_box()
	else:
		lock.open()

func _on_solved() -> void:
	GameState.solve_puzzle("bagua")
	_open_box()

func _open_box() -> void:
	if _opened:
		return
	_opened = true
	var wb := get_tree().get_first_node_in_group("world_builder")
	var box_model := get_parent().find_child("JewelryBox", true, false)
	if wb != null:
		# 找到妆奁盒 glb 实例播放开盖动画
		var boxes := wb.find_children("JewelryBox*", "Node3D", true, false)
		for b in boxes:
			var ap := b.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if ap != null:
				ap.play("box_open")
	var hud := get_tree().get_first_node_in_group("hud")
	AudioMgr.play("unlock_click", -2.0)
	AudioMgr.play("puzzle_success", -8.0)
	# 产出：日记·上 + 玉佩
	var world := get_tree().current_scene
	var diary := DocPickup.new()
	diary.doc_id = "doc_03_diary_a"
	world.add_child(diary)
	diary.global_position = global_position + Vector3(0, 0.25, 0.1)
	diary.add_box_collision(Vector3(0.3, 0.3, 0.3))
	var dscene: PackedScene = load("res://assets/props/%s.glb" % ItemDB.doc_mesh("doc_03_diary_a"))
	if dscene != null:
		var inst := dscene.instantiate()
		inst.scale = Vector3.ONE * 0.9
		diary.add_child(inst)
	var jade := Pickup.new()
	jade.item_id = "jade_pendant"
	world.add_child(jade)
	jade.global_position = global_position + Vector3(0, 0.35, -0.1)
	jade.add_box_collision(Vector3(0.25, 0.25, 0.25))
	var jscene: PackedScene = load(ItemDB.item_mesh("jade_pendant"))
	if jscene != null:
		var jinst := jscene.instantiate()
		jinst.scale = Vector3.ONE * 1.6
		jade.add_child(jinst)
	if hud != null and hud.has_method("toast"):
		hud.toast("妆奁盒开了。里面躺着一本日记……和那枚你找了很久的玉佩。")
	GameState.set_objective("玉佩已寻回 · 查明此宅真相")
