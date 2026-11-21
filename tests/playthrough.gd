extends Node
## 全流程通关模拟（headless）：谜题链 → 终局 → 双结局 完整依赖链验证
## 运行：Godot --headless --path . res://tests/playthrough.tscn

var _fails := 0
var _passes := 0
var main: Node

func _ok(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("  PASS ", label)
	else:
		_fails += 1
		print("  FAIL ", label)

func _ready() -> void:
	await get_tree().process_frame
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.new_game()
	main.set("_game_started", true)   # 测试准备：视为已进入游戏（血书合上回调依赖此状态）
	var wb: WorldBuilder = main.get("world_builder")
	var tp: TabletPuzzle = wb.tablet_puzzle
	var mr: MirrorRoom = wb.mirror_room
	var pr: PaperRitual = wb.paper_ritual

	# ---------------- 谜题一：牌位归位（贪心模拟抓放） ----------------
	print("[谜题一 牌位归位]")
	var moves := 0
	for i in tp.slot_contents.size():
		var guard := 0
		while String(tp.slot_contents[i]) != String(TabletPuzzle.CORRECT[i]) and guard < 8:
			guard += 1
			tp.handle_slot(i)                      # 拿起当前错位的牌位
			var held := tp.held_tablet
			if held == "":
				break
			var target := TabletPuzzle.CORRECT.find(held)
			if target >= 0:
				tp.handle_slot(target)             # 放到它应在的槽（可能触发交换）
			else:
				tp.handle_slot(-1)                 # 柏舟 → 归还位
			moves += 1
	print("  （模拟抓放 %d 次）" % moves)
	_ok(GameState.get_flag("puzzle_tablets"), "牌位谜题解开（供桌暗格解锁）")

	# 暗格抽屉：解锁 → 拉开 → 取手札
	var drawer: Drawer = wb.find_child("HallAltarDrawer", true, false)
	_ok(not drawer.locked, "供桌暗格已解锁")
	drawer._do_interact(null)
	await get_tree().create_timer(1.2).timeout   # 抽屉动画(0.75s)到位后生成手札
	var note := _find_pickup_doc("doc_07_daoshi_notes")
	_ok(note != null, "手札已生成于暗格")
	if note != null:
		note._do_interact(null)
	_ok(GameState.docs.has("doc_07_daoshi_notes"), "手札收入线索册")

	# ---------------- 谜题二：八卦锁 ----------------
	print("[谜题二 八卦锁]")
	var lock: BaguaLock = wb.bagua_lock
	lock.ring = BaguaLock.TARGET.duplicate()
	lock.element = BaguaLock.TARGET_ELEMENT
	lock._on_check()
	await get_tree().create_timer(1.2).timeout
	_ok(GameState.get_flag("puzzle_bagua"), "八卦锁解开")
	var jade_pk := _find_pickup_item("jade_pendant")
	_ok(jade_pk != null, "玉佩从妆奁盒产出")
	if jade_pk != null:
		jade_pk._do_interact(null)
	_ok(GameState.has_item("jade_pendant"), "玉佩收入行囊")

	# ---------------- 谜题三：铜镜折射 ----------------
	print("[谜题三 铜镜折射]")
	_ok(mr.SOLUTION == [-45.0, 45.0, 0.0], "解法与 Python 求解器一致")
	mr.mirror_yaw = [mr.SOLUTION[0], mr.SOLUTION[1], mr.SOLUTION[2]]
	mr._update_beam()
	await get_tree().create_timer(1.0).timeout
	_ok(GameState.get_flag("puzzle_mirror"), "铜镜谜题解开")
	var pen := _find_pickup_item("cinnabar_pen")
	_ok(pen != null, "朱砂笔从屏风暗龛产出")
	if pen != null:
		pen._do_interact(null)
	_ok(GameState.has_item("cinnabar_pen"), "朱砂笔收入行囊")

	# 火折子（东回廊拾取）
	var fire := _find_pickup_item("fire_starter")
	_ok(fire != null, "火折子存在于回廊")
	if fire != null:
		fire._do_interact(null)

	# ---------------- 谜题四：扎纸仪式（含错误顺序回退） ----------------
	print("[谜题四 扎纸仪式]")
	var wrong_msg: String = pr.paint_eye("R")
	_ok(wrong_msg == "", "先点右眼 → 被禁忌拒绝并重置")
	_ok(pr._eyes_done.is_empty(), "点睛顺序重置生效")
	pr.paint_eye("L")
	pr.paint_eye("R")
	_ok(pr.phase == 2, "点睛完成 → 进入上香阶段")
	var no_fire: String = ""
	pr._incense_done.clear()
	pr.light_incense("Mid")
	pr.light_incense("L")
	pr.light_incense("R")
	_ok(pr.phase == 3, "三炷香点燃（中→左→右）")
	pr.choose_bell_hour("子时三刻")
	pr.ring_bell()
	pr.ring_bell()
	pr.ring_bell()
	await get_tree().create_timer(0.5).timeout
	_ok(GameState.get_flag("puzzle_ritual"), "仪式完成 → 暗格书架滑开")
	_ok(wb.bookshelf_blocker == null or not is_instance_valid(wb.bookshelf_blocker), "书架碰撞已移除")
	var contract := _find_pickup_doc("doc_06_contract")
	_ok(contract != null, "法事契约出现在暗格")
	if contract != null:
		contract._do_interact(null)
	_ok(GameState.docs.has("doc_06_contract"), "契约收入线索册")

	# ---------------- 终局：血书 → 怨气爆发 ----------------
	print("[终局]")
	GameState.add_doc("doc_11_blood_contract")
	(main.get("reader_ui") as ReaderUI).close()   # 玩家合上血书 → 3 秒过渡后开始追逐
	await get_tree().create_timer(4.2).timeout
	_ok(GameState.get_flag("finale"), "血书触发终局（怨气爆发）")
	var bride: RedBride = main.get("bride")
	_ok(bride.active, "红衣鬼影开始巡逻")
	# 被捕获 → 重生点
	bride._catch(null)
	await get_tree().create_timer(2.4).timeout
	var ppos: Vector3 = main.get("player").global_position
	_ok(ppos.distance_to(Vector3(-17.5, 0.15, -1.0)) < 0.5, "被捕获后从密室门口重生")
	_ok(bride.active, "追逐重置")

	# ---------------- 双结局 ----------------
	print("[结局分支]")
	var jade_choice := wb.find_child("JadeChoice", true, false)
	_ok(jade_choice != null, "天井玉佩抉择台存在")
	if jade_choice != null:
		jade_choice._do_interact(null)
	await get_tree().create_timer(0.3).timeout
	_ok(GameState.get_flag("ending_done"), "真结局：玉佩放回牌位前")

	# 伪结局路径（新开一周目直达终局）
	GameState.set_flag("finale", false)
	GameState.flags.erase("finale")
	GameState.flags.erase("ending_done")
	GameState.add_item("jade_pendant")
	GameState.start_finale()
	var esc := wb.find_child("EscapeDoor", true, false)
	_ok(esc != null, "南门逃亡点存在")
	if esc != null:
		esc._do_interact(null)
	_ok(GameState.get_flag("ending_done"), "伪结局：夺门而出")

	print("PLAYTHROUGH RESULT: pass=%d fail=%d" % [_passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)

var _found: Node = null

func _find_pickup_item(item_id: String) -> Pickup:
	_found = null
	# 从测试根遍历（drawer/妆奁的产出物挂在 current_scene 即测试根上）
	_walk(self, func(n: Node) -> void:
		if n is Pickup and n.item_id == item_id and _found == null:
			_found = n)
	return _found as Pickup

func _find_pickup_doc(doc_id: String) -> DocPickup:
	_found = null
	_walk(self, func(n: Node) -> void:
		if n is DocPickup and n.doc_id == doc_id and _found == null:
			_found = n)
	return _found as DocPickup

func _walk(node: Node, fn: Callable) -> void:
	fn.call(node)
	for c in node.get_children():
		_walk(c, fn)
