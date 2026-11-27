extends Control
## Virtual on-screen joystick (works with touch via emulated mouse events).

signal moved(vec: Vector2)

const R := 60.0
var dragging := false
var knob := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(160, 160)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		dragging = e.pressed
		if e.pressed:
			_update(e.position)
		else:
			knob = Vector2.ZERO
			moved.emit(Vector2.ZERO)
			queue_redraw()
	elif e is InputEventMouseMotion and dragging:
		_update(e.position)


func _update(p: Vector2) -> void:
	knob = (p - size / 2.0).limit_length(R)
	moved.emit(knob / R)
	queue_redraw()


func _draw() -> void:
	draw_circle(size / 2.0, R + 12.0, Color(1, 1, 1, 0.16))
	draw_circle(size / 2.0, R + 12.0, Color(1, 1, 1, 0.35), false, 3.0)
	draw_circle(size / 2.0 + knob, 30.0, Color(1, 1, 1, 0.55))
