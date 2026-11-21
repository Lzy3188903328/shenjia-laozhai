extends Node
## ScareMgr — 小惊吓调度器：配额 / 冷却 / 灯火预警联动
## 恐怖节奏原则：每 2 次小惊吓后强制安静期（>45s），避免惊吓疲劳

signal dread_changed(level: int)  # 0 平静 / 1 不安 / 2 恐慌

const COOLDOWN := 45.0            # 同类惊吓最小间隔
const QUIET_WINDOW := 40.0        # 连发 2 次后的安静期
const DREAD_UNEASE_DIST := 12.0   # 预警距离
const DREAD_PANIC_DIST := 6.0

var _dread_sources: Dictionary = {}   # id -> {pos: Vector3, once: bool, fired: bool, weight: float}
var _recent: Dictionary = {}          # scare_id -> last time fired
var _recent_count := 0
var _quiet_until := 0.0
var _dread_level := 0

var _player: Node3D

func register_player(p: Node3D) -> void:
	_player = p

func add_dread_source(id: String, pos: Vector3, once: bool = false) -> void:
	_dread_sources[id] = {"pos": pos, "once": once, "fired": false}

func remove_dread_source(id: String) -> void:
	_dread_sources.erase(id)

func can_fire(scare_id: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _quiet_until:
		return false
	if _recent.has(scare_id) and now - float(_recent[scare_id]) < COOLDOWN:
		return false
	return true

func fire(scare_id: String) -> bool:
	if not can_fire(scare_id):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	_recent[scare_id] = now
	_recent_count += 1
	if _recent_count >= 2:
		_recent_count = 0
		_quiet_until = now + QUIET_WINDOW
	AudioMgr.duck_ambient()
	GameState.scare_fired.emit(scare_id)
	return true

## 灯火预警：每帧由玩家油灯查询最近的怨气源距离
func nearest_dread(pos: Vector3) -> Dictionary:
	var best_dist := 9999.0
	var best_id := ""
	for id in _dread_sources:
		var d: float = pos.distance_to(_dread_sources[id]["pos"])
		if d < best_dist:
			best_dist = d
			best_id = id
	return {"id": best_id, "dist": best_dist}

func update_dread(pos: Vector3) -> void:
	var near := nearest_dread(pos)
	var level := 0
	if near["dist"] < DREAD_PANIC_DIST:
		level = 2
	elif near["dist"] < DREAD_UNEASE_DIST:
		level = 1
	if level != _dread_level:
		_dread_level = level
		dread_changed.emit(level)

func dread_level() -> int:
	return _dread_level
