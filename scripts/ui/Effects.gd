extends CanvasLayer
class_name Effects
## 后处理特效层：暗角 / 胶片颗粒 / 红闪（闪回）/ 死亡淡出 / 追逐脉动

var _mat: ShaderMaterial
var _rect: ColorRect
var _pulse := 0.0
var _chase_mode := false

const SHADER_CODE := "
shader_type canvas_item;
uniform float vignette_strength = 0.38;
uniform float grain_amount = 0.05;
uniform float red_flash = 0.0;
uniform float fade_black = 0.0;
uniform float fade_white = 0.0;
uniform float pulse = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	float d = distance(SCREEN_UV, vec2(0.5));
	float vig = vignette_strength + pulse * 0.25;
	col *= 1.0 - vig * smoothstep(0.3, 0.82, d);
	float g = fract(sin(dot(SCREEN_UV * vec2(1234.5, 987.6), vec2(12.9898, 78.233))) * 43758.5453 + TIME);
	col += (g - 0.5) * grain_amount;
	col = mix(col, vec3(0.5, 0.04, 0.03), red_flash);
	col = mix(col, vec3(0.0), fade_black);
	col = mix(col, vec3(0.95), fade_white);
	COLOR = vec4(col, 1.0);
}"

func _ready() -> void:
	add_to_group("effects")
	layer = 80
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect.material = _mat
	add_child(_rect)

func _process(delta: float) -> void:
	if _chase_mode:
		_pulse = sin(Time.get_ticks_msec() / 1000.0 * 3.2) * 0.5 + 0.5
		_mat.set_shader_parameter("pulse", _pulse)

func red_flash(duration: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_red, 0.0, 1.0, duration * 0.3)
	tw.tween_method(_set_red, 1.0, 0.0, duration * 0.7)

func _set_red(v: float) -> void:
	_mat.set_shader_parameter("red_flash", v)

func death_fade() -> void:
	var tw := create_tween()
	tw.tween_method(_set_black, 0.0, 1.0, 1.4)

func _set_black(v: float) -> void:
	_mat.set_shader_parameter("fade_black", v)

func set_fade_black(v: float) -> void:
	_mat.set_shader_parameter("fade_black", v)

func set_fade_white(v: float) -> void:
	_mat.set_shader_parameter("fade_white", v)

func set_chase_mode(on: bool) -> void:
	_chase_mode = on
	if not on:
		_mat.set_shader_parameter("pulse", 0.0)

func set_grain(amount: float) -> void:
	_mat.set_shader_parameter("grain_amount", amount)
