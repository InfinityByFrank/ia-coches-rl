## Camara libre sencilla para inspeccionar el mapa.
## WASD = mover, Q/E = subir/bajar, rueda = acercar/alejar.
extends Camera3D

@export var speed := 15.0


func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir.z -= 1
	if Input.is_key_pressed(KEY_S): dir.z += 1
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	if Input.is_key_pressed(KEY_E): dir.y += 1
	if Input.is_key_pressed(KEY_Q): dir.y -= 1
	if dir != Vector3.ZERO:
		global_position += global_transform.basis * dir.normalized() * speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			global_position += -global_transform.basis.z * 2.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			global_position += global_transform.basis.z * 2.0
