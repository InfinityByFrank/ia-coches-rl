## Genera scenes/car.tscn
## Uso: godot --headless --path godot --script res://tools/build_car.gd
extends SceneTree


func _init() -> void:
	var root := CharacterBody3D.new()
	root.name = "Car"
	root.collision_layer = 2   # el coche esta en la capa 2
	root.collision_mask = 1    # y choca con la capa 1 (ciudad)
	root.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	root.set_script(load("res://scripts/car.gd"))

	# Modelo: el gltf mira hacia +Z, Godot usa -Z como "delante" -> giramos 180 grados.
	var model: Node3D = (load("res://assets/kaykit/car_sedan.gltf") as PackedScene).instantiate()
	model.name = "Model"
	model.rotation.y = PI
	root.add_child(model)
	model.owner = root

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.25, 0.9)
	col.shape = box
	col.position = Vector3(0, 0.25, 0)
	root.add_child(col)
	col.owner = root

	# Controlador de IA (Godot RL Agents)
	var ai := Node3D.new()
	ai.name = "AIController3D"
	ai.set_script(load("res://scripts/car_ai_controller.gd"))
	root.add_child(ai)
	ai.owner = root

	# Camara de seguimiento (detras y arriba)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, 1.6, 2.2)
	cam.rotation_degrees = Vector3(-25, 0, 0)
	cam.fov = 70
	root.add_child(cam)
	cam.owner = root

	var ps := PackedScene.new()
	ps.pack(root)
	print("guardado car.tscn: ", ResourceSaver.save(ps, "res://scenes/car.tscn"))
	quit()
