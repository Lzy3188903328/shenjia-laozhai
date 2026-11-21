extends CanvasLayer
class_name BaguaLock
## 谜题二：五行八卦机关锁（闺房妆奁盒）
## 解法（据道士手札）：离→北、坎→南、巽→西北（与乾互换），余卦归本位；中宫纳「水」
## 后天八卦本位：离S 坎N 震E 兑W 巽SE 乾NW 坤SW 艮NE

signal solved
signal wrong_attempt

# 八方位顺序（UI 环绕排列）
const DIRECTIONS := ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
# 后天八卦本位（初始状态）
const STANDARD := {"北": "坎", "东北": "艮", "东": "震", "东南": "巽",
                   "南": "离", "西南": "坤", "西": "兑", "西北": "乾"}
# 目标：离北、坎南、巽西北(与乾互换)，余归本位
const TARGET := {"北": "离", "东北": "艮", "东": "震", "东南": "乾",
                 "南": "坎", "西南": "坤", "西": "兑", "西北": "巽"}
const TRIGRAM_CYCLE := ["乾", "兑", "离", "震", "巽", "坎", "艮", "坤"]
const ELEMENTS := ["金", "木", "水", "火", "土"]
const TARGET_ELEMENT := "水"

var ring: Dictionary = {}
var element := "金"
var _wrong_count := 0

var _panel: PanelContainer
var _sector_buttons: Dictionary = {}
var _element_button: Button
var _status_label: Label

func _ready() -> void:
	add_to_group("bagua_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS   # 面板暂停游戏时自身仍接收输入
	ring = STANDARD.duplicate()
	layer = 30
	_build_ui()
	visible = false

func open() -> void:
	ring = STANDARD.duplicate()
	element = "金"
	_refresh()
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.add_to_group("paper_panel")
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(560, 520)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "八 卦 机 关 锁"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vb.add_child(title)
	var hint := Label.new()
	hint.text = "（转盘可逐位拨动 · 中心五行钮可换）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	vb.add_child(hint)

	# 八卦环
	var center := Control.new()
	center.custom_minimum_size = Vector2(420, 380)
	vb.add_child(center)
	for i in DIRECTIONS.size():
		var dir: String = DIRECTIONS[i]
		var b := Button.new()
		b.text = "%s\n%s" % [dir, ring[dir]]
		b.custom_minimum_size = Vector2(84, 62)
		var ang := -PI / 2 + i * TAU / 8.0   # 北在上
		var radius := 150.0
		b.position = Vector2(210 + cos(ang) * radius - 42, 190 + sin(ang) * radius - 31)
		b.pressed.connect(_on_sector.bind(dir))
		center.add_child(b)
		_sector_buttons[dir] = b
	_element_button = Button.new()
	_element_button.text = "中宫\n%s" % element
	_element_button.custom_minimum_size = Vector2(96, 72)
	_element_button.position = Vector2(210 - 48, 190 - 36)
	_element_button.pressed.connect(_on_element)
	center.add_child(_element_button)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_status_label)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	var check := Button.new()
	check.text = "推 锁 芯"
	check.pressed.connect(_on_check)
	hb.add_child(check)
	var close_b := Button.new()
	close_b.text = "退 开"
	close_b.pressed.connect(close)
	hb.add_child(close_b)
	add_child(_panel)
	UITheme.center_panel(_panel)

func _on_sector(dir: String) -> void:
	var cur: String = ring[dir]
	var idx := TRIGRAM_CYCLE.find(cur)
	ring[dir] = TRIGRAM_CYCLE[(idx + 1) % TRIGRAM_CYCLE.size()]
	AudioMgr.play("unlock_click", -8.0, randf_range(0.9, 1.2))
	_refresh()

func _on_element() -> void:
	var idx := ELEMENTS.find(element)
	element = ELEMENTS[(idx + 1) % ELEMENTS.size()]
	AudioMgr.play("unlock_click", -8.0, 0.8)
	_refresh()

func _refresh() -> void:
	for dir in _sector_buttons:
		_sector_buttons[dir].text = "%s\n%s" % [dir, ring[dir]]
	_element_button.text = "中宫\n%s" % element

func _on_check() -> void:
	for dir in TARGET:
		if ring[dir] != TARGET[dir]:
			_fail()
			return
	if element != TARGET_ELEMENT:
		_fail()
		return
	AudioMgr.play("puzzle_success", -2.0)
	_status_label.text = "铜簧弹开——锁开了。"
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		close()
		solved.emit())

func _fail() -> void:
	_wrong_count += 1
	AudioMgr.play("puzzle_fail", -8.0)
	_status_label.text = "锁芯纹丝不动……镜子里好像有什么动了一下。"
	if _wrong_count >= 3:
		wrong_attempt.emit()
		_wrong_count = 0
