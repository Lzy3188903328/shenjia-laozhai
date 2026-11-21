extends SceneTree

func _dump(node: Node, depth: int) -> void:
	var tags := []
	if node is MeshInstance3D: tags.append("mesh")
	if node is StaticBody3D: tags.append("STATIC")
	if node is CollisionShape3D: tags.append("shape")
	if node is AnimationPlayer: tags.append("anim")
	print("  ".repeat(depth), node.name, " ", tags)
	for c in node.get_children():
		_dump(c, depth + 1)

func _init() -> void:
	for p in ["res://assets/kit/wall_brick.glb", "res://assets/kit/door.glb"]:
		print("=== ", p)
		var ps: PackedScene = load(p)
		var root := ps.instantiate()
		_dump(root, 1)
		root.free()
	quit(0)
