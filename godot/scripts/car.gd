## Coche cinematico (modelo de bicicleta), equivalente al car_env.py de la fase 1.
##
## Observacion (14 valores):
##   7 rayos (-90..+90 grados): distancia a la pared, 0..1
##   velocidad, 0..1
##   posicion actual del volante, -1..1
##   direccion (seno, coseno) hacia las 2 proximas celdas de la ruta a la meta, -1..1
##   distancia que queda por la ruta / 30 m, 0..1
## Accion:      [direccion, aceleracion] en -1..1  (direccion +1 = derecha).
## Recompensa:  acercarse a la meta POR LA RUTA (x1.5 por metro) - 0.01 por paso,
##              +10 al llegar a la meta (y sale otra), -10 si choca,
##              castigo por girar mucho y por cambiar el giro de golpe (evita el zigzag).
##
## Convencion de Godot: el coche mira hacia -Z local.
class_name Car
extends CharacterBody3D

signal crashed

const MAX_SPEED := 4.0          # m/s
const ACCEL := 4.0              # m/s^2
const MAX_STEER_ANGLE := 0.6    # rad, giro maximo de las ruedas delanteras
const WHEELBASE := 0.5          # m, distancia entre ejes
const RAY_COUNT := 7
const RAY_MAX := 6.0            # m, alcance de los rayos
const RAY_HEIGHT := 0.25        # m, altura de los rayos (por encima del asfalto)
const MAX_EPISODE_STEPS := 2000
const GOAL_MIN_CELLS := 4       # la meta esta entre 4 y 12 celdas de distancia (por la ruta)
const GOAL_MAX_CELLS := 12
const GOAL_BONUS := 10.0
const PROGRESS_REWARD := 1.5    # recompensa por metro que se acerca a la meta
const STEER_RATE := 4.0         # el volante tarda 0.5 s en ir de un tope al otro
const STEER_PENALTY := 0.03     # castigo por fotograma = 0.03 * giro^2
const STEER_CHANGE_PENALTY := 0.2   # castigo por fotograma = 0.2 * |cambio de giro|

## true = lo conduces tu con el teclado; false = lo controla la IA (set_action).
@export var human_control := true
@export var show_rays := true

var speed := 0.0
var steer_cmd := 0.0      # posicion REAL del volante (-1..1)
var steer_target := 0.0   # lo que pide la IA / el teclado; el volante lo persigue con inercia
var throttle_cmd := 0.0
var is_crashed := false
var steps := 0
var step_reward := 0.0
var goal_cell := Vector2i.ZERO
var goals_reached := 0

var _graph: RoadGraph
var _dist_map: Dictionary = {}   # celda -> celdas hasta la meta
var _prev_cd := 0.0
var _beacon: MeshInstance3D

var _rays: Array[RayCast3D] = []
var _front_wheels: Array[Node3D] = []
var _ray_mesh := ImmediateMesh.new()


func _ready() -> void:
	add_to_group("car")
	for i in RAY_COUNT:
		var a := lerpf(-PI / 2.0, PI / 2.0, i / float(RAY_COUNT - 1))
		var r := RayCast3D.new()
		r.position.y = RAY_HEIGHT
		r.rotation.y = -a                       # angulo positivo = hacia la derecha
		r.target_position = Vector3(0, 0, -RAY_MAX)
		r.collision_mask = 1                    # solo ve edificios, calles y muros
		add_child(r)
		_rays.append(r)
	for w in $Model.find_children("*wheel_front*", "Node3D", true, false):
		_front_wheels.append(w)
	# Malla para dibujar los rayos
	var mi := MeshInstance3D.new()
	mi.mesh = _ray_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	mi.top_level = true
	add_child(mi)
	if has_node("Camera3D"):
		$Camera3D.make_current()
	_graph = get_tree().get_first_node_in_group("roadgraph")
	if _graph:
		_make_beacon()
		_new_goal()


func _physics_process(delta: float) -> void:
	if human_control:
		_read_keys(delta)
	step_reward = 0.0
	if not is_crashed:
		var prev_steer := steer_cmd
		steer_cmd = move_toward(steer_cmd, steer_target, STEER_RATE * delta)
		speed = clampf(speed + throttle_cmd * ACCEL * delta, 0.0, MAX_SPEED)
		rotation.y -= speed / WHEELBASE * tan(steer_cmd * MAX_STEER_ANGLE) * delta
		var hit := move_and_collide(-global_transform.basis.z * speed * delta)
		steps += 1
		if hit:
			is_crashed = true
			speed = 0.0
			step_reward = -10.0
			crashed.emit()
			if human_control:
				get_tree().create_timer(0.8).timeout.connect(reset)
		else:
			var cd := _cont_distance()
			step_reward = (_prev_cd - cd) * PROGRESS_REWARD - 0.01
			step_reward -= STEER_PENALTY * steer_cmd * steer_cmd + STEER_CHANGE_PENALTY * absf(steer_cmd - prev_steer)
			_prev_cd = cd
			if _graph and _cur_cell() == goal_cell:
				step_reward += GOAL_BONUS
				goals_reached += 1
				_new_goal()
	for w in _front_wheels:
		w.rotation.y = -steer_cmd * MAX_STEER_ANGLE
	_draw_rays()


func _read_keys(delta: float) -> void:
	var s := Input.get_axis(&"ui_left", &"ui_right")
	steer_target = s
	var t := Input.get_axis(&"ui_down", &"ui_up")
	throttle_cmd = t if t != 0.0 else -0.3     # sin pedal: frena suavemente
	if Input.is_key_pressed(KEY_R):
		reset()


## La IA llama a esto cada paso con [direccion, aceleracion].
func set_action(action: Array) -> void:
	steer_target = clampf(action[0], -1.0, 1.0)
	throttle_cmd = clampf(action[1], -1.0, 1.0)


func get_obs() -> Array:
	var obs: Array = []
	for r in _rays:
		r.force_raycast_update()
		if r.is_colliding():
			obs.append(r.global_position.distance_to(r.get_collision_point()) / RAY_MAX)
		else:
			obs.append(1.0)
	obs.append(speed / MAX_SPEED)
	obs.append(steer_cmd)
	if _graph:
		for n in _next_cells():
			var local := global_transform.basis.inverse() * (_graph.cell_center(n) - global_position)
			var a := atan2(local.x, -local.z)   # 0 = justo delante, + = a la derecha
			obs.append(sin(a))
			obs.append(cos(a))
		obs.append(clampf(_cont_distance() / 30.0, 0.0, 1.0))
	else:
		obs.append_array([0.0, 1.0, 0.0, 1.0, 0.0])
	return obs


func is_done() -> bool:
	return is_crashed or steps >= MAX_EPISODE_STEPS


## Recoloca el coche en un punto de salida aleatorio (grupo "spawn").
func reset() -> void:
	var spawns := get_tree().get_nodes_in_group("spawn")
	if spawns.size() > 0:
		var s: Node3D = spawns.pick_random()
		global_transform = s.global_transform
	speed = 0.0
	steer_cmd = 0.0
	steer_target = 0.0
	throttle_cmd = 0.0
	is_crashed = false
	steps = 0
	goals_reached = 0
	if _graph:
		_new_goal()


func _draw_rays() -> void:
	_ray_mesh.clear_surfaces()
	if not show_rays:
		return
	_ray_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for r in _rays:
		var end := r.global_position + r.global_transform.basis * r.target_position
		var frac := 1.0
		if r.is_colliding():
			end = r.get_collision_point()
			frac = r.global_position.distance_to(end) / RAY_MAX
		var c := Color.RED.lerp(Color.GREEN, frac)
		_ray_mesh.surface_set_color(c)
		_ray_mesh.surface_add_vertex(r.global_position)
		_ray_mesh.surface_set_color(c)
		_ray_mesh.surface_add_vertex(end)
	_ray_mesh.surface_end()


#region Meta y ruta
func _cur_cell() -> Vector2i:
	return _graph.world_to_cell(global_position)


## Las 2 proximas celdas del camino mas corto desde la posicion actual hasta la meta.
func _next_cells() -> Array:
	var out: Array = []
	var c := _cur_cell()
	for k in 2:
		var best := c
		var best_d: int = _dist_map.get(c, 999)
		for dir in RoadGraph.DIRS:
			var n: Vector2i = c + dir
			if _dist_map.has(n) and _dist_map[n] < best_d:
				best = n
				best_d = _dist_map[n]
		out.append(best)
		c = best
	return out


## Metros que quedan hasta la meta siguiendo la ruta (continuo, sin saltos al cambiar de celda).
func _cont_distance() -> float:
	var n1: Vector2i = _next_cells()[0]
	return _dist_map.get(n1, 999) * RoadGraph.CELL + global_position.distance_to(_graph.cell_center(n1))


## Elige una meta nueva a 4-12 celdas, cuya ruta empiece hacia delante (sin dar la vuelta).
func _new_goal() -> void:
	var cur := _cur_cell()
	var res := _graph.bfs(cur)
	var dist: Dictionary = res[0]
	var first: Dictionary = res[1]
	var fwd := -global_transform.basis.z
	var ahead: Array[Vector2i] = []
	var any: Array[Vector2i] = []
	for c: Vector2i in dist:
		var d: int = dist[c]
		if d < GOAL_MIN_CELLS or d > GOAL_MAX_CELLS:
			continue
		any.append(c)
		var step := _graph.cell_center(first[c]) - _graph.cell_center(cur)
		if step.normalized().dot(fwd) > 0.5:
			ahead.append(c)
	var pool := ahead if not ahead.is_empty() else any
	goal_cell = pool.pick_random()
	_dist_map = _graph.bfs(goal_cell)[0]
	_prev_cd = _cont_distance()
	if _beacon:
		_beacon.global_position = _graph.cell_center(goal_cell) + Vector3(0, 1.0, 0)


func _make_beacon() -> void:
	if not show_rays:
		return   # en entrenamiento no hace falta dibujarla
	_beacon = MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.12
	m.bottom_radius = 0.12
	m.height = 2.0
	_beacon.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 1.0, 0.3, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beacon.material_override = mat
	_beacon.top_level = true
	add_child(_beacon)
#endregion
