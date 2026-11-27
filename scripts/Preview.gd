extends Control
## Avatar preview used in the character creation screen.

var color_idx := 0
var style := 0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 230)


func _draw() -> void:
	GS.draw_avatar(self, Vector2(size.x / 2.0, 130), color_idx, style, 4.5)
