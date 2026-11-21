extends Node
## 冒烟测试：headless 运行 `godot --path . res://tests/smoke.tscn`
## 验证：内容完整性 / 谜题可解且唯一 / 场景构建 / 核心系统联动

var _fails := 0
var _passes := 0

func _ready() -> void:
	await get_tree().process_frame
	_test_itemdb_integrity()
	_test_doc_meshes()
	_test_combine_keys()
	_test_mirror_math()
	_test_tablet_config()
	_test_bagua_config()
	_test_ritual_order()
	await _test_world_build()
	print("SMOKE RESULT: pass=%d fail=%d" % [_passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)

func _ok(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("  PASS ", label)
	else:
		_fails += 1
		print("  FAIL ", label)

# ---------------------------------------------------------- 内容
func _test_itemdb_integrity() -> void:
	print("[ItemDB]")
	for id in ItemDB.ITEMS:
		var it: Dictionary = ItemDB.ITEMS[id]
		_ok(String(it.get("name", "")) != "", "item %s 有名称" % id)
		_ok(String(it.get("desc", "")) != "", "item %s 有描述" % id)
		_ok(ResourceLoader.exists(String(it.get("mesh", "?"))), "item %s 模型存在" % id)
	for id in ItemDB.DOCS:
		var d: Dictionary = ItemDB.DOCS[id]
		_ok((d.get("pages", []) as Array).size() > 0, "doc %s 有页" % id)
		_ok(String(d.get("plain", "")) != "", "doc %s 有白话释意" % id)
		_ok(String(d.get("title", "")) != "", "doc %s 有标题" % id)

func _test_doc_meshes() -> void:
	print("[DocMesh]")
	for doc_id in ItemDB.DOCS_MESH:
		_ok(ResourceLoader.exists("res://assets/props/%s.glb" % ItemDB.doc_mesh(doc_id)),
			"doc %s 场景模型存在" % doc_id)

func _test_combine_keys() -> void:
	print("[Combine]")
	for key in ItemDB.COMBINE:
		var parts: PackedStringArray = String(key).split("+")
		_ok(parts.size() == 2, "配方 %s 格式" % key)
		for p in parts:
			_ok(ItemDB.ITEMS.has(p) or ItemDB.DOCS.has(p), "配方 %s 引用有效 id %s" % [key, p])
		_ok(String(ItemDB.COMBINE[key].get("flag", "")) != "", "配方 %s 有 flag" % key)

# ---------------------------------------------------------- 谜题三：光路唯一解
func _test_mirror_math() -> void:
	print("[MirrorRoom]")
	var room := MirrorRoom.new()
	var combos := [[90.0, 45.0, 0.0], [45.0, 90.0, 45.0], [0.0, 0.0, 90.0], [90.0, 0.0, 45.0], [45.0, 45.0, 45.0]]
	var solutions := 0
	var best_dist := 999.0
	for yaw_a in MirrorRoom.YAW_STATES:
		for yaw_b in MirrorRoom.YAW_STATES:
			for yaw_c in MirrorRoom.YAW_STATES:
				room.mirror_yaw = [yaw_a, yaw_b, yaw_c]
				var result: Dictionary = room._chain()
				if bool(result["ok"]) and float(result["hit_dist"]) < MirrorRoom.TARGET_RADIUS:
					solutions += 1
					best_dist = minf(best_dist, float(result["hit_dist"]))
	_ok(solutions == 1, "光路解唯一（当前 %d 个解）" % solutions)
	room.mirror_yaw = [MirrorRoom.SOLUTION[0], MirrorRoom.SOLUTION[1], MirrorRoom.SOLUTION[2]]
	var r: Dictionary = room._chain()
	_ok(bool(r["ok"]) and float(r["hit_dist"]) < 0.35, "参考解可行 dist=%.3f" % float(r["hit_dist"]))
	room.free()

# ---------------------------------------------------------- 谜题一：牌位
func _test_tablet_config() -> void:
	print("[TabletPuzzle]")
	_ok(TabletPuzzle.CORRECT.size() == 6, "6 个牌位槽")
	var has_baizhou: bool = TabletPuzzle.CORRECT.has("baizhou")
	_ok(not has_baizhou, "沈柏舟牌位不在此架（归还制）")
	var all_ids: bool = true
	for t in TabletPuzzle.INITIAL:
		if not TabletPuzzle.TABLET_IDS.has(t):
			all_ids = false
	_ok(all_ids, "初始布局为有效排列")

# ---------------------------------------------------------- 谜题二：八卦
func _test_bagua_config() -> void:
	print("[BaguaLock]")
	var diff := 0
	for d in BaguaLock.TARGET:
		if BaguaLock.TARGET[d] != BaguaLock.STANDARD[d]:
			diff += 1
	_ok(diff >= 3, "目标布局需至少 3 处变动（当前 %d）" % diff)
	_ok(BaguaLock.TARGET_ELEMENT in BaguaLock.ELEMENTS, "五行钮合法")
	_ok(BaguaLock.TARGET.has("北") and BaguaLock.TARGET["北"] == "离", "离火倒悬于北（手札解法）")

# ---------------------------------------------------------- 谜题四：仪式
func _test_ritual_order() -> void:
	print("[PaperRitual]")
	_ok(PaperRitual.INCENSE_ORDER == ["M", "L", "R"], "香序：中→左→右")

# ---------------------------------------------------------- 场景构建
func _test_world_build() -> void:
	print("[World]")
	var main_scene: PackedScene = load("res://scenes/main/Main.tscn")
	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var wb: WorldBuilder = main.get("world_builder")
	_ok(wb != null, "WorldBuilder 存在")
	if wb != null:
		_ok(wb.get_child_count() > 100, "全宅节点数 %d > 100" % wb.get_child_count())
		_ok(wb.tablet_puzzle != null, "谜题一挂载")
		_ok(wb.mirror_room != null, "谜题三挂载")
		_ok(wb.paper_ritual != null, "谜题四挂载")
		_ok(wb.bagua_lock != null, "谜题二 UI 挂载")
	var player: Node = main.get("player")
	_ok(player != null, "玩家存在")
	var bride: Node = main.get("bride")
	_ok(bride != null, "红衣鬼影存在")
	_ok(get_tree().get_first_node_in_group("hud") != null, "HUD 挂载")
	_ok(get_tree().get_first_node_in_group("scare_runner") != null, "惊吓执行器挂载")
	_ok(get_tree().get_first_node_in_group("paper_panel") != null, "宣纸面板挂载")
	# 谜题交互物存在性
	_ok(wb.find_child("SecretShelf", true, false) != null, "暗格书架存在")
	_ok(wb.find_child("JewelryBox", true, false) != null, "妆奁盒交互存在")
	_ok(wb.find_child("DresserMirror", true, false) != null, "梳妆镜交互存在")
	_ok(wb.find_child("RitualBurner", true, false) != null, "仪式香炉存在")
	_ok(wb.find_child("RitualBell", true, false) != null, "仪式铜铃存在")
	main.queue_free()
	await get_tree().process_frame
