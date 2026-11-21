extends Node
## 资产接口合规审计（对应 docs/沈家老宅_3D资产重制任务书.md 第六节）
## 逐项校验 50 个 GLB：文件可加载 / 关键节点 / 动画轨道 / 碰撞代理存在

var _fails := 0
var _passes := 0

func _ok(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("  PASS ", label)
	else:
		_fails += 1
		print("  FAIL ", label)

func _ready() -> void:
	print("[A. 50 个 GLB 全量可加载]")
	var kit := ["wall_brick", "wall_wood", "pillar", "beam", "roof_seg", "floor_stone",
		"floor_wood", "door", "window", "railing", "step", "plaque"]
	var props := ["paper_figure", "paper_head", "bride_ghost", "hand_lantern",
		"hanging_lantern", "tablet", "tablet_rack", "altar_table", "bagua_lock",
		"bronze_mirror", "mirror_stand", "incense_burner", "copper_bell", "cinnabar_pen",
		"fire_starter", "jade_pendant", "letter", "book_red", "book_dark", "contract",
		"blood_contract", "wedding_half", "bed", "dresser", "jewelry_box", "bookshelf",
		"armchair", "red_shoes", "candle", "stone_well", "spirit_flag", "bamboo_stack",
		"paste_pot", "luopan", "chair_wood", "dead_rat", "offering_plate", "desk_study"]
	_ok(kit.size() == 12, "建筑模块 12 个")
	_ok(props.size() == 38, "道具与角色 38 个")
	var scenes := {}
	for k in kit:
		scenes[k] = _load_scene("res://assets/kit/%s.glb" % k, "kit/" + k)
	for p in props:
		scenes[p] = _load_scene("res://assets/props/%s.glb" % p, "props/" + p)

	print("[B. 关键节点与动画（任务书第六节接口表）]")
	_check_node(scenes["door"], ["DoorLeaf"], "门")
	_check_anim(scenes["door"], ["door_open", "door_close"], "门")
	_check_col_body(scenes["door"], "DoorLeaf", "门扇独立碰撞")
	_check_node(scenes["hand_lantern"], ["Flame"], "手灯")
	_check_anim(scenes["hand_lantern"], ["lantern_sway"], "手灯")
	_check_node(scenes["hanging_lantern"], ["Body"], "挂灯")
	_check_anim(scenes["hanging_lantern"], ["lantern_sway"], "挂灯")
	_check_node(scenes["paper_figure"], ["Head", "Face"], "纸人")
	_check_anim(scenes["paper_figure"], ["turn_head"], "纸人")
	_check_anim(scenes["altar_table"], ["drawer_open"], "供桌")
	_check_node(scenes["altar_table"], ["Drawer"], "供桌")
	_check_anim(scenes["bed"], ["bed_curtain_open"], "床")
	_check_node(scenes["bed"], ["Curtain"], "床")
	_check_anim(scenes["tablet"], ["tablet_pickup"], "牌位")
	_check_node(scenes["incense_burner"], ["IncenseMid", "IncenseL", "IncenseR",
		"EmberMid", "EmberL", "EmberR"], "香炉六节点")
	_check_node(scenes["copper_bell"], ["Clapper"], "铜铃")
	_check_anim(scenes["copper_bell"], ["bell_ring"], "铜铃")
	_check_node(scenes["jewelry_box"], ["Lid"], "妆奁")
	_check_anim(scenes["jewelry_box"], ["box_open"], "妆奁")
	_check_node(scenes["bookshelf"], ["SecretPart"], "书架")
	_check_anim(scenes["bookshelf"], ["secretshelf_slide"], "书架")
	_check_node(scenes["mirror_stand"], ["Mirror"], "铜镜架")

	print("[C. 建筑模块碰撞代理（-colonly 命名约定）]")
	for k in kit:
		_check_col_proxy(scenes[k], k)

	print("[D. 交互挂载一致性（运行时识别的节点）]")
	_ok(wb_find("HallAltarDrawer") != null, "正厅供桌暗格 Drawer 挂载")
	_ok(wb_find("ShrineAltar") != null, "祠堂供桌存在")
	_ok(wb_find("BedCurtain") != null, "床幔交互挂载")
	_ok(wb_find("BaguaModel") != null, "八卦锁模型挂载于妆奁")

	print("ASSET AUDIT RESULT: pass=%d fail=%d" % [_passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)

var _wb: Node = null
func wb_find(name: String) -> Node:
	if _wb == null:
		_wb = load("res://scenes/main/Main.tscn").instantiate()
		add_child(_wb)
		return _wb.find_child(name, true, false)
	return _wb.find_child(name, true, false)

func _load_scene(path: String, label: String) -> PackedScene:
	var ps: PackedScene = load(path) if ResourceLoader.exists(path) else null
	_ok(ps != null, "可加载 " + label)
	return ps

func _flatten(root: Node) -> Array:
	var out: Array = []
	var stack := [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.push_back(c)
	return out

func _check_node(ps: PackedScene, names: Array, label: String) -> void:
	var root := ps.instantiate()
	var nodes := _flatten(root)
	for want in names:
		var found := false
		for n in nodes:
			if String(n.name).find(String(want)) >= 0:
				found = true
				break
		_ok(found, "%s 含节点 %s" % [label, want])
	root.free()

func _check_anim(ps: PackedScene, names: Array, label: String) -> void:
	var root := ps.instantiate()
	var ap: AnimationPlayer = null
	for n in _flatten(root):
		if n is AnimationPlayer:
			ap = n
			break
	if ap == null:
		_ok(false, "%s 有 AnimationPlayer" % label)
		root.free()
		return
	var list := ap.get_animation_list()
	for want in names:
		_ok(list.has(want), "%s 动画 %s" % [label, want])
	root.free()

func _check_col_body(ps: PackedScene, contain: String, label: String) -> void:
	var root := ps.instantiate()
	var found := false
	for n in _flatten(root):
		if n is StaticBody3D and String(n.name).find(contain) >= 0:
			found = true
			break
	_ok(found, "%s（%s）" % [label, contain])
	root.free()

func _check_col_proxy(ps: PackedScene, label: String) -> void:
	var root := ps.instantiate()
	var found := false
	for n in _flatten(root):
		if n is StaticBody3D:
			found = true
			break
	_ok(found, "%s 带碰撞代理" % label)
	root.free()
