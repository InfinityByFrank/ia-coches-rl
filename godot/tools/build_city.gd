## Genera scenes/city.tscn: GridMap con retícula de calles.
## Uso: godot --headless --path godot --script res://tools/build_city.gd
extends SceneTree

const SIZE := 13          # celdas por lado (13 x 13)
const SPACING := 4        # una calle cada 4 celdas -> manzanas de 3x3

# Indices en la MeshLibrary (ver build_library.gd)
const STRAIGHT := 0
const CORNER := 1
const CORNER_CURVED := 2
const TSPLIT := 3
const JUNCTION := 4
const CROSSING := 5
const BASE := 6
const BUILDINGS := [7, 8, 9, 10, 11, 12, 13, 14]  # building_A .. building_H

# Direcciones en el plano XZ (visto desde arriba: N = -Z, E = +X)
const N := Vector3i(0, 0, -1)
const E := Vector3i(1, 0, 0)
const S := Vector3i(0, 0, 1)
const W := Vector3i(-1, 0, 0)

# Conexiones de cada pieza SIN rotar (comprobado en la imagen de preview)
const BASE_CONN := {
	STRAIGHT: [N, S],
	CROSSING: [N, S],
	CORNER: [E, S],
	CORNER_CURVED: [E, S],
	TSPLIT: [N, S, E],
	JUNCTION: [N, E, S, W],
}


func _is_road(x: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= SIZE or z >= SIZE:
		return false
	return x % SPACING == 0 or z % SPACING == 0


func _rotate(d: Vector3i, k: int) -> Vector3i:
	var v := Basis(Vector3.UP, k * PI / 2.0) * Vector3(d)
	return Vector3i(roundi(v.x), 0, roundi(v.z))


## Busca la rotacion (0..3) que hace coincidir las conexiones de la pieza con las necesarias.
func _find_rotation(item: int, needed: Array) -> int:
	for k in 4:
		var rotated: Array = []
		for d in BASE_CONN[item]:
			rotated.append(_rotate(d, k))
		var ok := rotated.size() == needed.size()
		for d in needed:
			if not rotated.has(d):
				ok = false
		if ok:
			return k
	push_error("Sin rotacion valida para item %d con %s" % [item, needed])
	return 0


## Direccion hacia la que mira un edificio de la manzana: hacia la calle mas cercana.
func _facing(x: int, z: int, rng: RandomNumberGenerator) -> Vector3i:
	var i := x % SPACING - 1  # 0..2 dentro de la manzana
	var j := z % SPACING - 1
	if j == 0:
		return N
	if j == 2:
		return S
	if i == 0:
		return W
	if i == 2:
		return E
	return [N, E, S, W][rng.randi() % 4]  # celda central


## Rotacion (0..3) que lleva la fachada del modelo (+Z = S sin rotar) hacia `face`.
func _front_rotation(face: Vector3i) -> int:
	for k in 4:
		if _rotate(S, k) == face:
			return k
	return 0


func _add_prop(parent: Node3D, owner_root: Node, model: String, pos: Vector3, angle_y: float) -> void:
	var inst: Node3D = (load("res://assets/kaykit/%s.gltf" % model) as PackedScene).instantiate()
	inst.position = pos
	inst.rotation.y = angle_y
	parent.add_child(inst)
	inst.owner = owner_root


func _init() -> void:
	var root := Node3D.new()
	root.name = "City"

	var gm := GridMap.new()
	gm.name = "GridMap"
	gm.mesh_library = load("res://resources/city_meshlib.res")
	gm.cell_size = Vector3(2, 1, 2)
	gm.cell_center_x = true
	gm.cell_center_y = false
	gm.cell_center_z = true
	root.add_child(gm)
	gm.owner = root

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts := {}
	for z in SIZE:
		for x in SIZE:
			var item := BASE
			var k := 0
			if _is_road(x, z):
				var conn: Array = []
				for d in [N, E, S, W]:
					if _is_road(x + d.x, z + d.z):
						conn.append(d)
				match conn.size():
					4:
						item = JUNCTION
					3:
						item = TSPLIT
					2:
						if conn.has(N) and conn.has(S) or conn.has(E) and conn.has(W):
							item = STRAIGHT
							# Paso de peatones en el centro de cada tramo
							if (x % SPACING == 2 and z % SPACING == 0) or (z % SPACING == 2 and x % SPACING == 0):
								item = CROSSING
						else:
							item = CORNER_CURVED
					_:
						item = STRAIGHT
				if conn.size() == 2 and item == STRAIGHT or item == CROSSING:
					# Recta/paso: base va N-S; si el tramo es E-W hay que girar
					k = _find_rotation(item, [E, W] if conn.has(E) else [N, S])
				elif item != STRAIGHT:
					k = _find_rotation(item, conn)
			else:
				# Manzana: edificio aleatorio (semilla fija) mirando hacia su calle
				item = BUILDINGS[rng.randi() % BUILDINGS.size()]
				k = _front_rotation(_facing(x, z, rng))
			var basis := Basis(Vector3.UP, k * PI / 2.0)
			gm.set_cell_item(Vector3i(x, 0, z), item, gm.get_orthogonal_index_from_basis(basis))
			counts[item] = counts.get(item, 0) + 1
	print("Piezas por item: ", counts)

	# --- Mobiliario urbano (instancias sueltas, no caben en el GridMap) ---
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	props.owner = root
	for z in SIZE:
		for x in SIZE:
			if not _is_road(x, z):
				continue
			var c := Vector3((x + 0.5) * 2.0, 0.1, (z + 0.5) * 2.0)  # centro de la celda
			var cell_item := gm.get_cell_item(Vector3i(x, 0, z))
			if cell_item == JUNCTION:
				# Un semaforo por esquina; cada acceso (N, S, E, O) queda con uno delante.
				for sx in [-1, 1]:
					for sz in [-1, 1]:
						var face := Vector3(0, 0, sz) if sx == sz else Vector3(sx, 0, 0)
						_add_prop(props, root, "trafficlight_A", c + Vector3(sx * 0.8, 0, sz * 0.8), atan2(face.x, face.z))
			elif cell_item == STRAIGHT:
				# Farolas alternando lados; el brazo apunta hacia la calzada.
				var horizontal := z % SPACING == 0
				var o := (x if horizontal else z) % SPACING
				if o != 1 and o != 3:
					continue
				var side := 1 if o == 1 else -1
				var off := Vector3(0, 0, -0.85 * side) if horizontal else Vector3(-0.85 * side, 0, 0)
				var arm := Vector3(0, 0, side) if horizontal else Vector3(side, 0, 0)
				_add_prop(props, root, "streetlight", c + off, atan2(arm.z, -arm.x))

	# Muros invisibles alrededor del mapa (para que rayos y coche no salgan al vacio)
	var walls := StaticBody3D.new()
	walls.name = "BoundaryWalls"
	root.add_child(walls)
	walls.owner = root
	var w := SIZE * 2.0  # lado del mapa en metros
	for def in [[Vector3(w / 2, 0.5, -0.5), Vector3(w + 2, 1, 1)], [Vector3(w / 2, 0.5, w + 0.5), Vector3(w + 2, 1, 1)],
			[Vector3(-0.5, 0.5, w / 2), Vector3(1, 1, w + 2)], [Vector3(w + 0.5, 0.5, w / 2), Vector3(1, 1, w + 2)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = def[1]
		cs.shape = bs
		cs.position = def[0]
		walls.add_child(cs)
		cs.owner = root

	# Luz y cielo
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	sun.owner = root

	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	env.owner = root

	# Camara orbital para mirar el mapa (WASD mueve, rueda = zoom)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	var centro := Vector3(SIZE, 0, SIZE)  # centro del mapa (SIZE*2/2)
	cam.position = centro + Vector3(0, 30, 14)
	cam.look_at_from_position(cam.position, centro, Vector3.UP)
	cam.set_script(load("res://scripts/camera_rig.gd"))
	root.add_child(cam)
	cam.owner = root

	var ps := PackedScene.new()
	ps.pack(root)
	print("guardado city.tscn: ", ResourceSaver.save(ps, "res://scenes/city.tscn"))
	quit()
