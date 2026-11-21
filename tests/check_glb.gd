extends SceneTree

func _init() -> void:
	var paths := [
		"res://assets/props/paper_figure.glb",
		"res://assets/kit/door.glb",
		"res://assets/props/altar_table.glb",
		"res://assets/props/hanging_lantern.glb",
		"res://assets/props/tablet.glb",
		"res://assets/kit/wall_brick.glb",
	]
	for p in paths:
		var ps: PackedScene = load(p)
		if ps == null:
			print("FAIL load: ", p)
			continue
		var root := ps.instantiate()
		var names: Array[String] = []
		for c in root.get_children():
			names.append(c.name + ("(mesh)" if c is MeshInstance3D else "(node)"))
		var anims := ""
		var ap := root.find_child("AnimationPlayer", true, false)
		if ap != null:
			anims = str(ap.get_animation_list())
		print("OK ", p.get_file(), " children=", names, " anims=", anims)
		root.free()
	quit(0)
