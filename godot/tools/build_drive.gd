## Genera tres escenas:
##   scenes/world.tscn = ciudad + puntos de salida
##   scenes/drive.tscn = world + 1 coche que conduces tu
##   scenes/train.tscn = world + 16 coches de IA + nodo Sync (Godot RL Agents)
##   scenes/watch.tscn = igual con 3 coches y rayos visibles (para ver a la IA conducir)
## Uso: godot --headless --path godot --script res://tools/build_drive.gd
extends SceneTree

const SPACING := 4
const STRAIGHT := 0   # indice en la MeshLibrary
const TRAIN_CARS := 16


func _init() -> void:
	_build_world()
	_build_drive()
	_build_agents("train", TRAIN_CARS, false)
	_build_agents("watch", 3, true)
	quit()


func _save(node: Node, path: String) -> void:
	var ps := PackedScene.new()
	ps.pack(node)
	print("guardado ", path, ": ", ResourceSaver.save(ps, path))


func _build_world() -> void:
	var root := Node3D.new()
	root.name = "World"
	var city: Node3D = (load("res://scenes/city.tscn") as PackedScene).instantiate()
	city.name = "City"
	root.add_child(city)
	city.owner = root
	var gm: GridMap = city.get_node("GridMap")

	# Puntos de salida: en cada recta, un punto por sentido, en el carril derecho.
	var spawns := Node3D.new()
	spawns.name = "SpawnPoints"
	root.add_child(spawns)
	spawns.owner = root
	var n := 0
	for cell in gm.get_used_cells():
		if gm.get_cell_item(cell) != STRAIGHT:
			continue
		var c := Vector3((cell.x + 0.5) * 2.0, 0.1, (cell.z + 0.5) * 2.0)
		var horizontal: bool = cell.z % SPACING == 0
		# [direccion de marcha, desplazamiento lateral al carril derecho]
		var lanes: Array = []
		if horizontal:
			lanes = [[Vector3(1, 0, 0), Vector3(0, 0, 0.5)], [Vector3(-1, 0, 0), Vector3(0, 0, -0.5)]]
		else:
			lanes = [[Vector3(0, 0, 1), Vector3(-0.5, 0, 0)], [Vector3(0, 0, -1), Vector3(0.5, 0, 0)]]
		for l in lanes:
			var m := Marker3D.new()
			m.name = "Spawn%d" % n
			n += 1
			m.position = c + l[1]
			m.rotation.y = atan2(-l[0].x, -l[0].z)   # el coche mira a -Z
			m.add_to_group("spawn", true)
			spawns.add_child(m)
			m.owner = root
	print("puntos de salida: ", n)
	# Grafo de calles (para metas y rutas)
	var graph := Node.new()
	graph.name = "RoadGraph"
	graph.set_script(load("res://scripts/road_graph.gd"))
	root.add_child(graph)
	graph.owner = root
	_save(root, "res://scenes/world.tscn")


func _new_car(name: String, spawn: Node3D) -> Node3D:
	var car: Node3D = (load("res://scenes/car.tscn") as PackedScene).instantiate()
	car.name = name
	car.position = spawn.position
	car.rotation = spawn.rotation
	return car


func _build_drive() -> void:
	var root := Node3D.new()
	root.name = "Drive"
	var world: Node3D = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.owner = root
	var car := _new_car("Car", world.get_node("SpawnPoints").get_child(0))
	root.add_child(car)
	car.owner = root
	_save(root, "res://scenes/drive.tscn")


func _build_agents(scene_name: String, count: int, rays: bool) -> void:
	var root := Node3D.new()
	root.name = scene_name.capitalize()
	var world: Node3D = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.owner = root
	var spawns := world.get_node("SpawnPoints")
	for i in count:
		var car := _new_car("Car%d" % i, spawns.get_child(randi() % spawns.get_child_count()))
		car.set("show_rays", rays)   # sin dibujar rayos en entrenamiento: va mas rapido
		root.add_child(car)
		car.owner = root
	# Nodo que habla con Python
	var sync := Node.new()
	sync.name = "Sync"
	sync.set_script(load("res://addons/godot_rl_agents/sync.gd"))
	sync.set("control_mode", 1)       # TRAINING
	sync.set("action_repeat", 8)      # 1 decision cada 8 frames fisicos (~7.5 por segundo)
	root.add_child(sync)
	sync.owner = root
	_save(root, "res://scenes/%s.tscn" % scene_name)
