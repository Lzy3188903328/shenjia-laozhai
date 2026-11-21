extends Node
## 交互回归测试（headless 可重复运行）：
## 全程通过"正常入口"注入键盘/鼠标事件——菜单点击、E 开门穿行、铜镜转动、
## 点睛/香序/铜铃、血书时序、八卦锁、抛灯拾回、鬼影遮挡、双结局、960×540 适配。
## 运行：Godot --headless --path . res://tests/input_regression.tscn

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
	get_window().size = Vector2i(1280, 720)   # headless 默认 64×64，先设定真实窗口尺寸
	await get_tree().process_frame
	await get_tree().process_frame
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var wb: WorldBuilder = main.get("world_builder")
	var player: CharacterBody3D = main.get("player")
	var cam: Camera3D = player.get("camera")

	# ---------------- 1. 主菜单点击开始 ----------------
	print("[1 主菜单]")
	var menu: MainMenu = main.get("main_menu")
	_ok(menu != null and menu.visible, "主菜单可见")
	var start_btn := _find_button(main, "踏 入 宅 门")
	_ok(start_btn != null, "找到「踏入宅门」按钮")
	await _click_button(start_btn)
	await _wait(2.4)
	var reader: ReaderUI = main.get("reader_ui")
	_ok(reader.visible, "委托信自动打开")
	_ok(player.get("_input_locked") == true, "阅读委托信期间输入锁定（合信后解锁）")

	# ---------------- 2. Esc 合信 → 提示 → WASD/鼠标 ----------------
	print("[2 开场流程]")
	_press_key(KEY_ESCAPE)
	await _wait(0.2)
	_ok(not reader.visible, "Esc 合上委托信")
	_ok(GameState.get_flag("hint_courtyard"), "出现开场方向提示")
	var p0: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _wait(0.6)
	Input.action_release("move_forward")
	_ok(player.global_position.z < p0.z - 0.3, "W 前进正常")
	var is_headless := DisplayServer.get_name() == "headless"
	if is_headless:
		print("  SKIP 鼠标转动/捕获（headless 无鼠标模式支持）")
	else:
		var yaw0: float = player.rotation.y
		var mm := InputEventMouseMotion.new()
		mm.relative = Vector2(240, 0)
		Input.parse_input_event(mm)
		await get_tree().process_frame
		await get_tree().physics_frame
		_ok(absf(player.rotation.y - yaw0) > 0.05, "鼠标转动视角正常")
		_ok(Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED, "鼠标已捕获")

	# ---------------- 3. E 开正厅门并穿过门洞 ----------------
	print("[3 正厅门]")
	player.global_position = Vector3(0, 0.15, -7.0)
	player.rotation.y = 0.0
	player.set("_pitch", 0.0)
	if cam != null:
		cam.rotation.x = 0.0
	var hall_door: Door = wb.find_child("HallSouthDoor", true, false)
	await _wait(0.3)
	_press_key(KEY_E)
	await _wait(1.4)
	_ok(hall_door._open, "E 后门脚本状态开启")
	var leaf: Node3D = hall_door.get_parent()
	_ok(leaf.rotation.y > 1.2, "门扇向内开动画已播放（rotation=%.2f）" % leaf.rotation.y)
	Input.action_press("move_forward")
	await _wait(1.8)
	Input.action_release("move_forward")
	_ok(player.global_position.z < -8.4, "穿过门洞进入正厅 z=%.2f" % player.global_position.z)

	# ---------------- 4. 祠堂门（正厅 → 祠堂） ----------------
	print("[4 祠堂门]")
	player.global_position = Vector3(0, 0.15, -16.0)
	player.rotation.y = 0.0
	await _wait(0.3)
	_press_key(KEY_E)
	await _wait(1.4)
	var shrine_door: Door = wb.find_child("ShrineDoor", true, false)
	_ok(shrine_door != null and shrine_door._open, "祠堂门开启")
	Input.action_press("move_forward")
	await _wait(1.6)
	Input.action_release("move_forward")
	_ok(player.global_position.z < -17.6, "穿过门洞进入祠堂 z=%.2f" % player.global_position.z)

	# ---------------- 5. 花厅铜镜：E 转动 → 显字 → 拾朱砂笔 ----------------
	print("[5 花厅铜镜]")
	var mr: MirrorRoom = wb.mirror_room
	player.global_position = Vector3(9.0, 0.15, -12.0)
	player.rotation.y = -PI / 2.0   # 面东朝 M1
	player.set("_pitch", -0.41)
	if cam != null:
		cam.rotation.x = -0.41
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.6)
	_ok(mr.mirror_yaw[0] == 45.0, "E 转动 M1：角度 90→45")
	_press_key(KEY_E)
	await _wait(0.6)
	_press_key(KEY_E)
	await _wait(0.8)
	_ok(mr.mirror_yaw[0] == -45.0, "M1 转到正确解 -45°")
	_ok(mr._reveal_label.visible, "屏风显字「十九」")
	_ok(GameState.get_flag("puzzle_mirror"), "铜镜谜题解开")
	_ok(GameState.objective == "屏风后有暗龛 · 取出朱砂笔", "任务栏指向屏风暗龛")
	var pen := _find_pickup_item("cinnabar_pen")
	_ok(pen != null, "朱砂笔在屏风后生成")
	player.global_position = Vector3(7.4, 0.15, -9.3)
	player.rotation.y = PI / 2.0    # 面西朝笔
	player.set("_pitch", -0.83)
	if cam != null:
		cam.rotation.x = -0.83
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.4)
	_ok(GameState.has_item("cinnabar_pen"), "E 拾取朱砂笔")
	_ok(GameState.objective == "朱砂笔已到手 · 去扎纸作坊", "任务栏指向扎纸作坊")

	# ---------------- 6. 拾火折子 ----------------
	print("[6 火折子]")
	player.global_position = Vector3(7.5, 0.15, 4.6)
	player.rotation.y = 0.0
	player.set("_pitch", -1.05)
	if cam != null:
		cam.rotation.x = -1.05
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.4)
	_ok(GameState.has_item("fire_starter"), "E 拾取火折子")

	# ---------------- 7. 点睛（左→右） ----------------
	print("[7 点睛]")
	var pr: PaperRitual = wb.paper_ritual
	player.global_position = Vector3(-10.445, 0.15, 0.3)
	player.rotation.y = PI          # 面南朝纸人
	player.set("_pitch", -0.18)
	if cam != null:
		cam.rotation.x = -0.18
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.4)
	_ok(pr._eyes_done == (["L"] as Array[String]), "E 点左眼")
	player.global_position = Vector3(-10.555, 0.15, 0.3)
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.4)
	_ok(pr.phase == 2, "右眼点完 → 进入上香阶段")

	# ---------------- 8. 上香：故意错一次 → 重置 → 中左右 ----------------
	print("[8 上香]")
	player.global_position = Vector3(-11.85, 0.15, -0.2)
	player.rotation.y = PI
	player.set("_pitch", -0.83)
	if cam != null:
		cam.rotation.x = -0.83
	await _wait(0.4)
	_press_key(KEY_E)   # 故意先点左香 → 香序错误
	await _wait(0.4)
	_ok(pr._incense_done.is_empty(), "香序错误 → 重置")
	var burner := wb.find_child("RitualBurner", true, false)
	_ok(burner.find_child("EmberMid", true, false).visible == false, "重置后香头回到未点燃状态")
	player.global_position = Vector3(-11.8, 0.15, -0.2)
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.3)
	_ok(pr._incense_done == (["Mid"] as Array[String]), "点燃中香（Mid 标识一致）")
	_ok(burner.find_child("EmberMid", true, false).visible, "中香香头发光")
	player.global_position = Vector3(-11.85, 0.15, -0.2)
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.3)
	player.global_position = Vector3(-11.75, 0.15, -0.2)
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.4)
	_ok(pr.phase == 3, "三炷香齐（中→左→右）→ 进入铜铃阶段")

	# ---------------- 9. 铜铃：错误时辰 → 正确三响 → 暗门通行 ----------------
	print("[9 铜铃]")
	var bell_ui: BellUI = main.get("bell_ui")
	player.global_position = Vector3(-10.5, 0.15, -0.9)
	player.rotation.y = PI
	player.set("_pitch", -0.03)
	if cam != null:
		cam.rotation.x = -0.03
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.4)
	_ok(bell_ui.visible, "E 打开铜铃面板")
	var wrong_btn := _find_button(bell_ui._panel, "子时二刻")
	await _click_button(wrong_btn)
	var ring_btn := _find_button(bell_ui._panel, "敲 响（三声）")
	await _click_button(ring_btn)
	await _wait(0.2)
	_ok(bell_ui.visible, "错误时辰后面板保持打开")
	_ok(pr._bell_rings == 0 and pr._bell_chosen == "", "错误时辰已重置")
	var ok_btn := _find_button(bell_ui._panel, "子时三刻")
	await _click_button(ok_btn)
	await _click_button(ring_btn)
	await _wait(0.2)
	_ok(pr._bell_rings == 1 and bell_ui.visible, "第一响后面板仍在（1/3）")
	await _click_button(ring_btn)
	await _wait(0.2)
	_ok(pr._bell_rings == 2 and bell_ui.visible, "第二响后面板仍在（2/3）")
	await _click_button(ring_btn)
	await _wait(1.5)
	_ok(GameState.get_flag("puzzle_ritual"), "三响完成 → 仪式解开")
	_ok(not bell_ui.visible and not get_tree().paused, "完成后面板关闭并恢复游戏")
	_ok(wb.bookshelf_blocker == null or not is_instance_valid(wb.bookshelf_blocker), "书架障碍已移除")
	await _wait(0.5)
	var shelf := wb.find_child("SecretShelf", true, false) as Node3D
	_ok(shelf != null and shelf.position.z < -3.0, "书架已滑开让出门洞")

	# ---------------- 10. 穿过暗门进密室 ----------------
	print("[10 暗门通行]")
	player.global_position = Vector3(-13.8, 0.15, -1.0)
	player.rotation.y = PI / 2.0   # 面西
	player.set("_pitch", 0.0)
	if cam != null:
		cam.rotation.x = 0.0
	await _wait(0.3)
	Input.action_press("move_forward")
	await _wait(2.4)
	Input.action_release("move_forward")
	_ok(player.global_position.x < -16.5, "穿过暗门进入密室 x=%.2f" % player.global_position.x)

	# ---------------- 12d. 补扎替身（桌面近景输入） ----------------
	print("[12d 补扎替身]")
	player.global_position = Vector3(-13.2, 0.15, 0.4)
	player.rotation.y = PI          # 面南朝侧桌
	player.set("_pitch", -0.72)
	if cam != null:
		cam.rotation.x = -0.5
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.4)
	var mend_ui: MendUI = main.get("mend_ui")
	_ok(mend_ui.visible, "E 打开补扎桌面近景")
	await _click_mend_slot("L")
	await _click_mend_slot("R")
	await _click_mend_slot("hole_lo")
	var mend_btn := _find_button(mend_ui._panel, "收 紧")
	print("  dbg mend_btn=", mend_btn, " rect=", mend_btn.get_global_rect() if mend_btn != null else "null",
		" disabled=", mend_btn.disabled if mend_btn != null else "-",
		" visible=", mend_btn.is_visible_in_tree() if mend_btn != null else "-")
	await _click_button(mend_btn)
	await _wait(0.3)
	_ok(GameState.get_flag("mend_done"), "左衽压襟 + 下孔收紧 → 胸架已补")
	_ok(GameState.docs.has("doc_13_mend_note"), "发现记入线索册")
	var inner_btn := _find_button(mend_ui._panel, "翻 开 内 襟")
	await _click_button(inner_btn)
	await _wait(0.3)
	_ok(mend_ui._inner_open, "翻开内襟可见「自用」墨字")
	var close_mend := _find_button(mend_ui._panel, "离 开 桌 案")
	await _click_button(close_mend)
	await _wait(0.3)
	_ok(not mend_ui.visible and not get_tree().paused, "退出近景恢复游戏（保留已做步骤）")

	# ---------------- 11. 血书时序：读完才追逐 ----------------
	print("[11 血书时序]")
	player.global_position = Vector3(-20, 0.15, -2.4)
	player.rotation.y = 0.0
	player.set("_pitch", -0.65)
	if cam != null:
		cam.rotation.x = -0.65
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.5)
	_ok(reader.visible, "E 拾取血书 → 阅读器打开")
	await _wait(3.5)
	_ok(not GameState.get_flag("finale"), "血书停留超 3 秒：追逐尚未开始")
	_press_key(KEY_ESCAPE)
	await _wait(0.3)
	_ok(not reader.visible, "Esc 合上血书")
	_ok(player.get("_input_locked") == false, "合上后恢复移动与视角")
	await _wait(3.3)
	_ok(GameState.get_flag("finale"), "过渡结束 → 终局追逐开始")
	var bride: RedBride = main.get("bride")
	# ---------------- 11b. 封门遭遇：沉默经过 → 应声 → 鬼影查声 ----------------
	print("[11b 封门遭遇]")
	var sealed: Interactable = wb.find_child("SealedDoor", true, false)
	_ok(sealed != null, "封门存在")
	player.global_position = Vector3(-5.0, 0.15, -11.5)
	player.rotation.y = PI / 2.0   # 面西朝封门
	player.set("_pitch", 0.0)
	if cam != null:
		cam.rotation.x = 0.0
	await _wait(1.0)
	_ok(GameState.get_flag("voice_encounter_played"), "终局经过封门 → 喊名遭遇触发")
	# 沉默走开再回来（台词不重播）
	player.global_position = Vector3(-4.0, 0.15, -11.5)
	await _wait(0.5)
	player.global_position = Vector3(-5.0, 0.15, -11.5)
	await _wait(0.4)
	# 按住 E 0.6 秒应一声
	Input.action_press("interact")
	await _wait(0.7)
	Input.action_release("interact")
	await _wait(0.2)
	_ok(GameState.get_flag("voice_responded"), "按住 E 应声")
	_ok(bride._investigating, "鬼影转向封门查声")
	player.global_position = Vector3(-3.5, 0.15, -11.0)   # 退到转角遮挡
	bride.active = false   # 测试准备：后续步骤固定鬼影状态

	# ---------------- 12. 八卦锁（界面按钮操作 + 提交） ----------------
	print("[12 八卦锁]")
	var lock: BaguaLock = wb.bagua_lock
	player.global_position = Vector3(14.2, 0.15, -1.0)
	player.rotation.y = -PI / 2.0   # 面向东墙妆奁盒
	player.set("_pitch", -0.85)
	if cam != null:
		cam.rotation.x = -0.85
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.4)
	_ok(lock.visible, "E 打开八卦锁面板")
	for dir in lock.TARGET:
		var a: int = lock.TRIGRAM_CYCLE.find(String(lock.STANDARD[dir]))
		var b: int = lock.TRIGRAM_CYCLE.find(String(lock.TARGET[dir]))
		for i in (b - a + 8) % 8:
			await _click_button(lock._sector_buttons[dir])
	var elem_clicks: int = (lock.ELEMENTS.find(BaguaLock.TARGET_ELEMENT) - lock.ELEMENTS.find("金") + 5) % 5
	for i in elem_clicks:
		await _click_button(lock._element_button)
	var submit := _find_button(lock._panel, "推 锁 芯")
	await _click_button(submit)
	await _wait(1.4)
	_ok(GameState.get_flag("puzzle_bagua"), "八卦锁提交后解锁")
	_ok(not lock.visible and not get_tree().paused, "面板延迟关闭并恢复游戏")
	var jade_pk := _find_pickup_item("jade_pendant")
	_ok(jade_pk != null, "妆奁盒产出玉佩奖励")
	if jade_pk != null:
		jade_pk._do_interact(null)
	_ok(GameState.has_item("jade_pendant"), "玉佩收入行囊")
	_ok(GameState.objective.begins_with("朱砂笔已到手") or GameState.objective.begins_with("玉佩已寻回"),
		"任务栏保留当前较靠后的有效目标（%s）" % GameState.objective)

	# ---------------- 12b. 闺房门双向穿行（墙体切分修复验证） ----------------
	print("[12b 闺房门双向]")
	player.global_position = Vector3(9.6, 0.15, -2.0)
	player.rotation.y = PI / 2.0   # 面西朝闺房门（1.6m 内）
	player.set("_pitch", 0.0)
	if cam != null:
		cam.rotation.x = 0.0
	var boudoor: Door = wb.find_child("BoudoirDoor", true, false)
	await _wait(0.3)
	_press_key(KEY_E)
	await _wait(1.4)
	_ok(boudoor._open, "闺房门开启")
	Input.action_press("move_forward")
	await _wait(1.5)
	Input.action_release("move_forward")
	_ok(player.global_position.x < 7.0, "从闺房穿出门洞进回廊 x=%.2f" % player.global_position.x)
	player.rotation.y = -PI / 2.0   # 转身面东
	await _wait(0.2)
	Input.action_press("move_forward")
	await _wait(1.5)
	Input.action_release("move_forward")
	_ok(player.global_position.x > 8.4, "从回廊返回闺房 x=%.2f" % player.global_position.x)

	# ---------------- 12c. 作坊门双向穿行 ----------------
	print("[12c 作坊门双向]")
	player.global_position = Vector3(-9.6, 0.15, -2.0)
	player.rotation.y = -PI / 2.0   # 面东朝作坊门（1.6m 内）
	await _wait(0.3)
	var wsdoor: Door = wb.find_child("WorkshopDoor", true, false)
	await _wait(0.3)
	var dbg_ray: RayCast3D = player.get("interact_ray")
	dbg_ray.force_raycast_update()
	print("  dbg aim=", player.get("_current_target"), " locked=", player.get("_input_locked"),
		" paused=", get_tree().paused, " pos=", player.global_position)
	_press_key(KEY_E)
	await _wait(1.4)
	print("  dbg after E open=", wsdoor._open)
	_ok(wsdoor._open, "作坊门开启")
	Input.action_press("move_forward")
	await _wait(1.5)
	Input.action_release("move_forward")
	_ok(player.global_position.x > -7.0, "从作坊穿出门洞进回廊 x=%.2f" % player.global_position.x)
	player.rotation.y = PI / 2.0   # 转身面西
	player.global_position.z = -2.0   # 校回门洞中心线（门洞净宽 1.08m）
	await _wait(0.2)
	Input.action_press("move_forward")
	await _wait(1.8)
	Input.action_release("move_forward")
	var space := player.get_world_3d().direct_space_state
	var qf := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 0.9, 0),
		player.global_position + Vector3(-0.8, 0.9, 0), 1)
	var hf := space.intersect_ray(qf)
	print("  dbg block ray=", hf.get("collider"), " pos=", hf.get("position"))
	_ok(player.global_position.x < -9.0, "从回廊返回作坊 x=%.2f" % player.global_position.x)

	# ---------------- 13. 抛灯与拾回 ----------------
	print("[13 抛灯拾回]")
	player.global_position = Vector3(2.5, 0.15, 3.0)
	player.rotation.y = 0.0
	await _wait(0.3)
	_press_key(KEY_G)
	await _wait(1.0)
	var thrown := _find_pickup_item("hand_lantern_thrown")
	_ok(thrown != null, "灯笼已抛出为可拾取对象")
	_ok(thrown != null and _has_collision(thrown), "抛出灯笼带交互碰撞")
	_ok(not player.get("_lantern_on"), "抛出后手持照明熄灭")
	if thrown != null:
		player.global_position = (thrown as Node3D).global_position + Vector3(0.9, 0.15, 0)
		player.rotation.y = PI / 2.0    # 面西朝灯笼
		player.set("_pitch", -1.05)
		if cam != null:
			cam.rotation.x = -1.05
		await _wait(0.4)
		_press_key(KEY_E)
		await _wait(0.4)
	_ok(player.get("_lantern_on"), "E 拾回并恢复手持照明")
	_ok(_find_pickup_item("hand_lantern_thrown") == null, "场景中无残留灯笼对象")

	# ---------------- 14. 鬼影：隔墙脱身 / 开阔被抓 / 重生 ----------------
	print("[14 鬼影追逐]")
	bride.activate(PackedVector3Array([
		Vector3(0, 0, 5), Vector3(0, 0, -6), Vector3(0, 0, -12),
		Vector3(0, 0, -21), Vector3(-4, 0, 0), Vector3(4, 0, 0)]))
	player.global_position = Vector3(3, 0.15, -16.6)   # 正厅内
	bride.global_position = Vector3(3, 0, -17.4)       # 墙（z=-17）另一侧
	bride.active = true
	bride.state = RedBride.State.CHASE
	bride._lose_timer = 99.0
	await _wait(1.5)
	_ok(player.global_position.distance_to(Vector3(3, 0.15, -16.6)) < 0.5,
		"隔实体墙时不会捕获（未重生）")
	bride.global_position = Vector3(3, 0, -16.9)       # 同一房间贴脸
	await _wait(3.0)
	_ok(player.global_position.distance_to(Vector3(-17.5, 0.15, -1.0)) < 1.0,
		"开阔处被抓后正常重生到密室门口")
	_ok(bride.active, "重生后追逐继续")

	# ---------------- 15. 伪结局：终局南门（院内正面 E） ----------------
	print("[15 伪结局 南门]")
	player.global_position = Vector3(0, 0.15, 6.5)
	player.rotation.y = PI            # 面南朝大门
	player.set("_pitch", 0.0)
	if cam != null:
		cam.rotation.x = 0.0
	var esc_door: Interactable = wb.find_child("EscapeDoor", true, false)
	_ok(esc_door != null, "南门终局交互体存在（院内可命中）")
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.5)
	_ok(GameState.get_flag("ending_done"), "终局状态置位（夺门而逃）")
	_ok(bride.active == false, "鬼影停止追逐")
	_ok(main.get("endings_ui").get("_busy") == true, "结局演出开始（且仅一次）")
	_press_key(KEY_TAB)
	await _wait(0.3)
	_ok(main.get("inventory_ui").visible == false, "结局期间 Tab 不打开行囊")
	_ok(player.get("_input_locked") == true, "结局期间输入保持锁定")
	_press_key(KEY_ESCAPE)
	await _wait(0.3)
	_ok(not main.get("pause_ui").visible, "结局播放中 Esc 不打开暂停菜单")

	# ---------------- 16. 960×540 重开 + 真结局（玉佩归还） ----------------
	print("[16 960×540 与真结局]")
	get_window().size = Vector2i(960, 540)
	await _wait(0.3)
	var vp_size := get_viewport().get_visible_rect().size
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var menu2: MainMenu = main.get("main_menu")
	var start2 := _find_button(main, "踏 入 宅 门")
	_ok(menu2.visible and start2 != null, "重开后主菜单可见")
	var r: Rect2 = start2.get_global_rect()
	_ok(r.position.x >= 0 and r.end.x <= vp_size.x and r.position.y >= 0 and r.end.y <= vp_size.y,
		"按钮在 960×540 屏幕内")
	await _click_button(start2)
	await _wait(2.4)
	var reader2: ReaderUI = main.get("reader_ui")
	_ok(reader2.visible, "重开后委托信仍可打开")
	var pr_rect: Rect2 = reader2._panel.get_global_rect()
	_ok(pr_rect.position.x >= 0 and pr_rect.end.x <= vp_size.x and pr_rect.position.y >= -8
		and pr_rect.end.y <= vp_size.y + 8, "信件面板在 960×540 内")
	_press_key(KEY_ESCAPE)
	await _wait(0.3)
	_ok(not reader2.visible, "960×540 下合上委托信")
	_press_key(KEY_TAB)
	await _wait(0.3)
	var inv: InventoryUI = main.get("inventory_ui")
	_ok(inv.visible, "Tab 打开行囊")
	var inv_rect: Rect2 = inv._panel.get_global_rect()
	_ok(inv_rect.position.x >= 0 and inv_rect.end.x <= vp_size.x and inv_rect.position.y >= 0
		and inv_rect.end.y <= vp_size.y, "行囊面板在 960×540 内")
	_press_key(KEY_TAB)
	await _wait(0.3)
	_ok(not inv.visible and not get_tree().paused, "行囊关闭并恢复游戏")
	# 真结局：玉佩归还（测试准备：发放玉佩并进入终局阶段）
	GameState.add_item("jade_pendant")
	GameState.start_finale()
	var player2: CharacterBody3D = main.get("player")
	player2.global_position = Vector3(0, 0.15, 1.9)
	player2.rotation.y = PI           # 面南朝玉佩台
	player2.set("_pitch", -0.66)
	var cam2: Camera3D = player2.get("camera")
	if cam2 != null:
		cam2.rotation.x = -0.66
	var bride2: RedBride = main.get("bride")
	bride2.active = true
	await _wait(0.4)
	_press_key(KEY_E)
	await _wait(0.5)
	_ok(GameState.get_flag("ending_done"), "真结局：玉佩归还触发")
	_ok(not GameState.has_item("jade_pendant"), "玉佩已从行囊移除")
	_ok(bride2.active == false, "真结局：鬼影停止追逐")
	get_window().size = Vector2i(1280, 720)

	print("INPUT REGRESSION RESULT: pass=%d fail=%d" % [_passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# ============================================================ 输入工具
func _press_key(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode
	down.keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.physical_keycode = keycode
	up.keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)

func _click_button(btn: BaseButton) -> void:
	if btn == null:
		return
	var pos := (btn as Control).get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _find_button(root: Node, text: String) -> BaseButton:
	_found = null
	_walk(root, func(n: Node) -> void:
		if n is BaseButton and _found == null:
			var t: String = (n as Button).text if n is Button else ""
			if t.replace(" ", "") == text.replace(" ", ""):
				_found = n)
	return _found as BaseButton

var _found: Node = null

func _find_pickup_item(item_id: String) -> Pickup:
	_found = null
	_walk(self, func(n: Node) -> void:
		if n is Pickup and n.item_id == item_id and _found == null:
			_found = n)
	return _found as Pickup

func _click_mend_slot(slot: String) -> void:
	var mend_ui: MendUI = main.get("mend_ui")
	var btn: Button = mend_ui._view.find_child("Hot_" + slot, true, false)
	_ok(btn != null, "热区按钮 Hot_%s 存在" % slot)
	await _click_button(btn)

func _has_collision(body: PhysicsBody3D) -> bool:
	for c in body.get_children():
		if c is CollisionShape3D and c.shape != null:
			return true
	return false

func _walk(node: Node, fn: Callable) -> void:
	fn.call(node)
	for c in node.get_children():
		_walk(c, fn)
