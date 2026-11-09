## Construye la MeshLibrary a partir de los .gltf de calles.
## Uso: godot --headless --path godot --script res://tools/build_library.gd
extends SceneTree

const PIECES := [
	"road_straight",
	"road_corner",
	"road_corner_curved",
	"road_tsplit",
	"road_junction",
	"road_straight_crossing",
	"base",
	"building_A",
	"building_B",
	"building_C",
	"building_D",
	"building_E",
	"building_F",
	"building_G",
	"building_H",
]


func _init() -> void:
	var lib := MeshLibrary.new()
	for i in PIECES.size():
		var name: String = PIECES[i]
		var scene: PackedScene = load("res://assets/kaykit/%s.gltf" % name)
		var root := scene.instantiate()
		var mi := _find_mesh(root)
		if mi == null:
			push_error("Sin MeshInstance3D en " + name)
			continue
		lib.create_item(i)
		lib.set_item_name(i, name)
		lib.set_item_mesh(i, mi.mesh)
		# Caja de colision ajustada al tamano del modelo (suelo plano o edificio).
		var aabb: AABB = mi.mesh.get_aabb()
		var shape := BoxShape3D.new()
		shape.size = aabb.size
		lib.set_item_shapes(i, [shape, Transform3D(Basis(), aabb.get_center())])
		root.free()
		print("item ", i, " = ", name)
	var err := ResourceSaver.save(lib, "res://resources/city_meshlib.res")
	print("guardado MeshLibrary: ", err)
	quit()


func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r:
			return r
	return null
