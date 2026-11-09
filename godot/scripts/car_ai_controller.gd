## Puente entre el coche y Godot RL Agents.
## - Le dice a Python que observa el coche (8 valores) y que acciona (2 valores continuos).
## - Acumula la recompensa entre pasos de IA (con action_repeat > 1 hay varios frames por paso).
## - Cuando termina un episodio (choque o tiempo) marca `done` y recoloca el coche.
class_name CarAIController
extends AIController3D

@onready var car: Car = get_parent()


func _ready() -> void:
	super._ready()
	init(car)


func _physics_process(_delta: float) -> void:
	# Sin Sync o en modo HUMAN conduces tu; en TRAINING / ONNX lo conduce la IA.
	car.human_control = (
		control_mode == ControlModes.INHERIT_FROM_SYNC or control_mode == ControlModes.HUMAN
	)
	if car.human_control:
		return
	reward += car.step_reward
	n_steps += 1
	if car.is_done():
		done = true
		needs_reset = true
	if needs_reset:
		car.reset()
		reset()


#region Interfaz que exige AIController3D
func get_obs() -> Dictionary:
	return {"obs": car.get_obs()}


func get_reward() -> float:
	return reward


func get_action_space() -> Dictionary:
	return {"move": {"size": 2, "action_type": "continuous"}}  # [direccion, aceleracion]


func set_action(action) -> void:
	car.set_action(action["move"])
#endregion
