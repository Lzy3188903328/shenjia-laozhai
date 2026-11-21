extends Node
## 截图验证：加载完整游戏场景 → 定时截屏 → 退出

var _shots := 0
var main: Node

func _ready() -> void:
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	# 模拟游戏开始（跳过主菜单）
	await get_tree().process_frame
	main.get("main_menu").hide_menu()
	main.set("_game_started", true)
	main.get("effects").set_fade_black(0.0)
	await get_tree().create_timer(1.0).timeout
	await _snap("shot_courtyard.png")
	# 移动玩家到正厅
	var player: CharacterBody3D = main.get("player")
	var cam: Camera3D = player.get("camera")
	# HUD 水墨图标验证：手掌（对准供桌暗格）
	player.global_position = Vector3(0, 0.15, -13.0)
	player.set("_pitch", -0.66)
	if cam != null:
		cam.rotation.x = -0.66
	await get_tree().create_timer(0.6).timeout
	await _snap("shot_icon_hand.png")
	# 正厅全景
	player.global_position = Vector3(0, 0.15, -11)
	player.set("_pitch", 0.0)
	if cam != null:
		cam.rotation.x = 0.0
	await get_tree().create_timer(1.0).timeout
	await _snap("shot_hall.png")
	# 祠堂 + 眼睛图标（血字墙）
	player.global_position = Vector3(3.2, 0.15, -20.0)
	player.rotation.y = -PI / 2
	player.set("_pitch", -0.14)
	if cam != null:
		cam.rotation.x = -0.14
	await get_tree().create_timer(0.6).timeout
	await _snap("shot_icon_eye.png")
	# 祠堂全景
	player.global_position = Vector3(0, 0.15, -20)
	player.rotation.y = 0
	player.set("_pitch", 0.0)
	if cam != null:
		cam.rotation.x = 0.0
	await get_tree().create_timer(1.0).timeout
	await _snap("shot_shrine.png")
	# 闺房
	player.global_position = Vector3(12, 0.15, -2)
	await get_tree().create_timer(1.0).timeout
	await _snap("shot_boudoir.png")
	# 作坊
	player.global_position = Vector3(-12, 0.15, -2)
	await get_tree().create_timer(1.0).timeout
	await _snap("shot_workshop.png")
	# 密室
	player.global_position = Vector3(-20, 0.15, -1)
	await get_tree().create_timer(1.0).timeout
	await _snap("shot_cellar.png")
	print("SHOTS DONE")
	get_tree().quit(0)

func _snap(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tests/" + filename)
	print("saved ", filename)
