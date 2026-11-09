## Escena auxiliar: instancia la ciudad y coloca la camara cerca de un cruce (solo para revisar).
extends Node3D

func _ready() -> void:
	var city: Node3D = load("res://scenes/city.tscn").instantiate()
	add_child(city)
	var cam: Camera3D = city.get_node("Camera3D")
	cam.set_script(null)
	var target := Vector3(8, 0.5, 8)   # cruce interior (celda 4,4)
	cam.global_position = target + Vector3(7, 7, 9)
	cam.look_at(target + Vector3(0, 0.5, 0), Vector3.UP)
