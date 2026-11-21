extends Node
## GameState — 全局状态机与信号总线（《沈家老宅》）
## 章节推进 / 道具与文档库存 / 谜题标志 / 终局与结局

signal item_picked(item_id: String)
signal doc_read(doc_id: String)
signal puzzle_solved(puzzle_id: String)
signal flag_changed(flag: String, value: bool)
signal objective_changed(text: String)
signal scare_fired(scare_id: String)
signal finale_started
signal ending_reached(ending_id: String)  # "true" / "false"
signal player_died(reason: String)

const START_ITEMS: Array[String] = ["letter_entrust", "shoe_buckle"]

# 行囊中的道具
var items: Array[String] = []
# 已收集文档 id（顺序即收集顺序）
var docs: Array[String] = []
# 全局标志：谜题/惊吓/剧情节点
var flags: Dictionary = {}
# 当前目标提示
var objective: String = ""

func _enter_tree() -> void:
	_setup_input_map()
	process_mode = Node.PROCESS_MODE_ALWAYS

func new_game() -> void:
	items.clear()
	docs.clear()
	flags.clear()
	objective = "避雨 · 寻回玉佩"
	for it in START_ITEMS:
		items.append(it)
		objective_changed.emit(objective)

# ---------------------------------------------------------- 输入映射（代码注册，免去 project.godot 序列化错误）
func _setup_input_map() -> void:
	var binds := {
		"move_forward": [KEY_W], "move_back": [KEY_S],
		"move_left": [KEY_A], "move_right": [KEY_D],
		"sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C],
		"interact": [KEY_E], "toggle_lantern": [KEY_F], "throw_lantern": [KEY_G],
		"inventory": [KEY_TAB, KEY_I], "journal": [KEY_J], "pause": [KEY_ESCAPE],
		"jump": [KEY_SPACE],
	}
	for action: String in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

# ---------------------------------------------------------- 库存
func has_item(item_id: String) -> bool:
	return items.has(item_id)

func add_item(item_id: String) -> void:
	if items.has(item_id):
		return
	items.append(item_id)
	item_picked.emit(item_id)

func remove_item(item_id: String) -> void:
	items.erase(item_id)

func add_doc(doc_id: String) -> void:
	if docs.has(doc_id):
		return
	docs.append(doc_id)
	doc_read.emit(doc_id)

# ---------------------------------------------------------- 标志
func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)

func get_flag(flag: String) -> bool:
	return flags.get(flag, false)

# ---------------------------------------------------------- 目标
func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)

# ---------------------------------------------------------- 谜题
func solve_puzzle(puzzle_id: String) -> void:
	if get_flag("puzzle_" + puzzle_id):
		return
	set_flag("puzzle_" + puzzle_id)
	puzzle_solved.emit(puzzle_id)

# ---------------------------------------------------------- 终局
func start_finale() -> void:
	if get_flag("finale"):
		return
	set_flag("finale")
	finale_started.emit()

func reach_ending(ending_id: String) -> void:
	ending_reached.emit(ending_id)

func player_die(reason: String = "caught") -> void:
	player_died.emit(reason)
