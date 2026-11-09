## Coche cinematico (modelo de bicicleta), equivalente al car_env.py de la fase 1.
##
## Observacion: 7 rayos (-90..+90 grados) con la distancia a la pared normalizada 0..1
##              + velocidad normalizada 0..1  ->  8 valores.
## Accion:      [direccion, aceleracion] en -1..1  (direccion +1 = derecha).
## Recompensa:  avance (velocidad) - 0.01 por paso, -10 si choca.
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

## true = lo conduces tu con el teclado; false = lo controla la IA (set_action).
@export var human_control := true
@export var show_rays := true

var speed := 0.0
var steer_cmd := 0.0
var throttle_cmd := 0.0
var is_crashed := false
var steps := 0
var step_reward := 0.0

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


func _physics_process(delta: float) -> void:
	if human_control:
		_read_keys(delta)
	step_reward = 0.0
	if not is_crashed:
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
			step_reward = speed / MAX_SPEED * 0.1 - 0.01
	for w in _front_wheels:
		w.rotation.y = -steer_cmd * MAX_STEER_ANGLE
	_draw_rays()


func _read_keys(delta: float) -> void:
	var s := Input.get_axis(&"ui_left", &"ui_right")
	steer_cmd = move_toward(steer_cmd, s, 4.0 * delta)
	var t := Input.get_axis(&"ui_down", &"ui_up")
	throttle_cmd = t if t != 0.0 else -0.3     # sin pedal: frena suavemente
	if Input.is_key_pressed(KEY_R):
		reset()


## La IA llama a esto cada paso con [direccion, aceleracion].
func set_action(action: Array) -> void:
	steer_cmd = clampf(action[0], -1.0, 1.0)
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
	throttle_cmd = 0.0
	is_crashed = false
	steps = 0


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
