extends Node3D
class_name RainField
## 前院暴雨：GPUParticles3D 跟随玩家 + 雾气面片

var _particles: GPUParticles3D
var _follow := Vector3.ZERO

func _ready() -> void:
	_particles = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 1.5
	pm.initial_velocity_min = 13.0
	pm.initial_velocity_max = 17.0
	pm.gravity = Vector3(0, -3.0, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(13, 0.3, 13)
	pm.color = Color(0.55, 0.62, 0.72, 0.5)
	_particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.68, 0.8, 0.45)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	quad.material = mat
	_particles.draw_pass_1 = quad
	_particles.amount = 900
	_particles.lifetime = 1.1
	add_child(_particles)
	_particles.position = Vector3(0, 9, 0)
	AudioMgr.play("amb_rain_loop", -6.0)

func set_follow(pos: Vector3) -> void:
	_follow = pos

func _process(_delta: float) -> void:
	_particles.global_position = Vector3(_follow.x, _follow.y + 9.0, _follow.z)
