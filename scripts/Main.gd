extends Control
## Main menu, new game + avatar customization.

var sel_color := 0
var sel_style := 0
var name_edit: LineEdit
var preview
var box: VBoxContainer


func _ready() -> void:
	var th := Theme.new()
	th.default_font_size = 30
	theme = th
	var bg := ColorRect.new()
	bg.color = Color("22264a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_show_menu()
	Audio.apply_settings()


func _reset_box() -> void:
	if box:
		remove_child(box)
		box.queue_free()
	box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 90
	box.offset_bottom = -60
	box.add_theme_constant_override("separation", 22)
	add_child(box)


func _label(text: String, size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	box.add_child(l)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 90)
	b.pressed.connect(cb)
	b.pressed.connect(func(): Audio.play("click"))
	box.add_child(b)
	return b


func _show_menu() -> void:
	_reset_box()
	_label("MALLTOPIA", 76, Color("ffd43b"))
	_label("My Dream Mall", 40, Color("a5d8ff"))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 80)
	box.add_child(sp)
	if GS.has_save():
		_button("Continue", _continue)
	_button("New Game", _show_new)
	_label("v0.1 prototype", 20, Color(1, 1, 1, 0.5))


func _continue() -> void:
	if GS.load_game():
		get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _show_new() -> void:
	_reset_box()
	box.offset_top = 60
	_label("Create your mall boss", 40, Color("ffd43b"))
	preview = preload("res://scripts/Preview.gd").new()
	box.add_child(preview)
	_label("Nickname", 28)
	name_edit = LineEdit.new()
	name_edit.text = "Boss"
	name_edit.max_length = 12
	name_edit.placeholder_text = "Your name"
	name_edit.custom_minimum_size = Vector2(0, 80)
	box.add_child(name_edit)
	_label("Outfit color", 28)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for i in GS.AVATAR_COLORS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(66, 66)
		var sb := StyleBoxFlat.new()
		sb.bg_color = GS.AVATAR_COLORS[i]
		sb.set_corner_radius_all(33)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_pick_color.bind(i))
		row.add_child(b)
	_label("Style", 28)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	box.add_child(row2)
	for i in GS.STYLE_NAMES.size():
		var b := Button.new()
		b.text = GS.STYLE_NAMES[i]
		b.custom_minimum_size = Vector2(0, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick_style.bind(i))
		row2.add_child(b)
	_button("Start building!", _start)
	_button("Back", _show_menu)
	_sync_preview()


func _pick_color(i: int) -> void:
	sel_color = i
	Audio.play("click")
	_sync_preview()


func _pick_style(i: int) -> void:
	sel_style = i
	Audio.play("click")
	_sync_preview()


func _sync_preview() -> void:
	preview.color_idx = sel_color
	preview.style = sel_style
	preview.queue_redraw()


func _start() -> void:
	var n := name_edit.text.strip_edges()
	if n == "":
		n = "Boss"
	GS.reset_state(n, sel_color, sel_style)
	GS.started = true
	GS.save_game()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
