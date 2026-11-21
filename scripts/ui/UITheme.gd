extends RefCounted
class_name UITheme
## 国风 UI 主题：系统 CJK 字体运行时加载 + 宣纸 StyleBox + 朱砂点缀

static var _font: FontFile = null
static var _paper_tex: Texture2D = null

const FONT_CANDIDATES := [
	"C:\\Windows\\Fonts\\simhei.ttf",   # 黑体
	"C:\\Windows\\Fonts\\msyh.ttc",     # 微软雅黑
	"C:\\Windows\\Fonts\\simsun.ttc",   # 宋体
	"C:\\Windows\\Fonts\\simfang.ttf",  # 仿宋
	"/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
	"/System/Library/Fonts/PingFang.ttc",
]

static func get_font() -> FontFile:
	if _font != null:
		return _font
	for path in FONT_CANDIDATES:
		if FileAccess.file_exists(path):
			var f := FontFile.new()
			if f.load_dynamic_font(path) == OK:
				_font = f
				return _font
	return null

static func paper_tex() -> Texture2D:
	if _paper_tex != null:
		return _paper_tex
	_paper_tex = load("res://assets/tex/t_paper_yellow.png")
	return _paper_tex

static func paper_stylebox(margin: float = 14.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = paper_tex()
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb

## 面板锚定屏幕中心（任意窗口尺寸自适应，替代绝对坐标）
static func center_panel(panel: Control) -> void:
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

static func apply_theme(ctrl: Control, font_size: int = 18) -> void:
	var f := get_font()
	if f != null:
		ctrl.add_theme_font_override("font", f)
		ctrl.add_theme_font_size_override("font_size", font_size)

static func make_label(text: String, size: int = 18, color: Color = Color(0.12, 0.09, 0.06)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var f := get_font()
	if f != null:
		l.add_theme_font_override("font", f)
	return l

static func make_button(text: String, size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.14, 0.1, 0.06))
	b.add_theme_color_override("font_hover_color", Color(0.45, 0.08, 0.05))
	b.add_theme_color_override("font_pressed_color", Color(0.45, 0.08, 0.05))
	var f := get_font()
	if f != null:
		b.add_theme_font_override("font", f)
	return b
