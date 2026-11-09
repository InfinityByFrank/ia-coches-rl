## Test automatico: el coche acelera recto y se imprimen sensores hasta que choca.
extends Node3D

var car: Car
var frame := 0

func _ready() -> void:
	var d: Node3D = load("res://scenes/drive.tscn").instantiate()
	add_child(d)
	car = d.get_node("Car")
	car.get_node("AIController3D").control_mode = AIController3D.ControlModes.ONNX_INFERENCE  # = lo conduce el codigo, no el teclado
	car.human_control = false
	car.set_action([0.0, 1.0])
	car.crashed.connect(func(): print(">>> CHOQUE en frame ", frame, " pos=", car.global_position, " reward=", car.step_reward))

func _physics_process(_delta: float) -> void:
	frame += 1
	if frame % 20 == 0 and not car.is_crashed:
		var o := car.get_obs()
		print("f%d pos=(%.1f,%.1f) obs=%s r=%.3f" % [frame, car.global_position.x, car.global_position.z, str(o.map(func(v): return snappedf(v, 0.01))), car.step_reward])
