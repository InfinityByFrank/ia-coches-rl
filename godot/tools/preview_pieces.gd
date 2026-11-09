## Escena de prueba: cada pieza en una fila, sin rotar, con etiqueta.
## Uso: godot --path godot --script res://tools/preview_pieces.gd (genera scenes/preview.tscn)
extends SceneTree

func _init() -> void:
	var root := Node3D.new()
	root.name = "Preview"
	var gm := GridMap.new()
	gm.name = "GridMap"
	gm.mesh_library = load("res://resources/city_meshlib.res")
	gm.cell_size = Vector3(2, 1, 2)
	root.add_child(gm)
	gm.owner = root
	var n: int = gm.mesh_library.get_item_list().size()
	for i in n:
		gm.set_cell_item(Vector3i(i * 2, 0, 0), i)
		var l := Label3D.new()
		l.text = gm.mesh_library.get_item_name(i)
		l.position = Vector3(i * 4 + 1, 0.2, 2.6)
		l.rotation_degrees = Vector3(-90, 0, 0)
		l.pixel_size = 0.012
		l.modulate = Color.YELLOW
		root.add_child(l)
		l.owner = root
	var cam := Camera3D.new()
	cam.position = Vector3(n * 2, 14, 1)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.fov = 60
	root.add_child(cam)
	cam.owner = root
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	root.add_child(sun)
	sun.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "res://scenes/preview.tscn")
	quit()
