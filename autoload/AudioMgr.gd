extends Node
## AudioMgr — 总线 / 空间音效 / 环境氛围管理 / 惊吓 ducking

const SFX_DIR := "res://assets/sfx/"

var _streams: Dictionary = {}
var _layer1: AudioStreamPlayer   # 环境主轨
var _layer2: AudioStreamPlayer   # 环境副轨
var _chase_player: AudioStreamPlayer
var _drone_player: AudioStreamPlayer
var _current_region := ""

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_load_streams()
	_layer1 = _make_amb_player()
	_layer2 = _make_amb_player()
	_chase_player = _make_amb_player()
	_drone_player = _make_amb_player()

func _setup_buses() -> void:
	for bus_name in ["Ambient", "Scares", "Footstep", "Lantern"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func _load_streams() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		push_warning("AudioMgr: 无法打开音效目录 " + SFX_DIR)
		return
	for f in dir.get_files():
		if f.ends_with(".wav"):
			_streams[f.get_basename()] = load(SFX_DIR + f)
	for base_name in _streams:
		if base_name.begins_with("amb_") or base_name.begins_with("music_"):
			var s: AudioStreamWAV = _streams[base_name]
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() / 2  # 16bit mono 帧数

func _make_amb_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Ambient"
	p.volume_db = -60.0
	add_child(p)
	return p

# -------------------------------------------------- 一次性音效
func play(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	if not _streams.has(sfx_name):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = _streams[sfx_name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = "Scares"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p

func play_at(sfx_name: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_dist: float = 24.0) -> AudioStreamPlayer3D:
	if not _streams.has(sfx_name):
		return null
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[sfx_name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = "Scares"
	p.unit_size = max_dist * 0.35
	p.max_distance = max_dist
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return p

func play_random_at(sfx_name: String, pos: Vector3, volume_db: float = 0.0) -> void:
	play_at(sfx_name, pos, volume_db, randf_range(0.92, 1.08))

# -------------------------------------------------- 环境氛围（区域切换，交叉淡化）
## 区域 → [主轨, 副轨, 音量dB]
const AMBIENT_REGIONS := {
	"courtyard": ["amb_rain_loop", "amb_wind_loop", -6.0],
	"indoor": ["amb_room_tone", "amb_rain_loop", -12.0],
	"cellar": ["amb_room_tone", "amb_ghost_breath_loop", -10.0],
	"quiet": ["amb_room_tone", "", -14.0],
}

func set_ambient(region: String) -> void:
	if region == _current_region or not AMBIENT_REGIONS.has(region):
		return
	_current_region = region
	var spec: Array = AMBIENT_REGIONS[region]
	_fade_to(_layer1, String(spec[0]), float(spec[2]))
	_fade_to(_layer2, String(spec[1]), float(spec[2]) - 5.0)

func _fade_to(p: AudioStreamPlayer, stream_name: String, target_db: float) -> void:
	var tw := create_tween()
	if stream_name == "" or not _streams.has(stream_name):
		tw.tween_property(p, "volume_db", -60.0, 1.0)
		tw.tween_callback(p.stop)
		return
	if p.stream == _streams[stream_name] and p.playing:
		tw.tween_property(p, "volume_db", target_db, 1.2)
		return
	tw.tween_property(p, "volume_db", -60.0, 0.5)
	tw.tween_callback(func() -> void:
		p.stream = _streams[stream_name]
		p.play())
	tw.tween_property(p, "volume_db", target_db, 1.2)

func stop_ambient() -> void:
	_current_region = ""
	for p in [_layer1, _layer2]:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, 1.0)

# -------------------------------------------------- 音乐层
func play_drone() -> void:
	if _streams.has("music_drone_loop"):
		_drone_player.stop()
		_drone_player.stream = _streams["music_drone_loop"]
		_drone_player.volume_db = -10.0
		_drone_player.play()

func start_chase_music() -> void:
	if _streams.has("music_chase_loop"):
		_chase_player.stream = _streams["music_chase_loop"]
		_chase_player.volume_db = -6.0
		_chase_player.play()

func stop_chase_music() -> void:
	var tw := create_tween()
	tw.tween_property(_chase_player, "volume_db", -60.0, 2.0)

func play_ending_music() -> void:
	stop_chase_music()
	stop_ambient()
	if _streams.has("music_ending_warm"):
		_drone_player.stop()
		_drone_player.stream = _streams["music_ending_warm"]
		_drone_player.volume_db = -8.0
		_drone_player.play()

# -------------------------------------------------- 惊吓 ducking
func duck_ambient() -> void:
	var idx := AudioServer.get_bus_index("Ambient")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, -14.0)
		var timer := get_tree().create_timer(1.6)
		timer.timeout.connect(func() -> void:
			AudioServer.set_bus_volume_db(idx, 0.0))
