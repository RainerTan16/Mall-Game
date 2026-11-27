extends Control
## Main menu, new game + avatar customization (landscape layout).

var sel_color := 0
var sel_style := 0
var name_edit: LineEdit
var preview
var box: VBoxContainer
var cur: Control


func _ready() -> void:
	var th := Theme.new()
	th.default_font_size = 28
	theme = th
	var bg := ColorRect.new()
	bg.color = Color("22264a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_show_menu()
	Audio.apply_settings()


func _reset_box(l := 280, r := -280, t := 50, b := -30) -> void:
	if box:
		remove_child(box)
		box.queue_free()
	box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = l
	box.offset_right = r
	box.offset_top = t
	box.offset_bottom = b
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	cur = box


func _label(text: String, size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	cur.add_child(l)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 74)
	b.pressed.connect(cb)
	b.pressed.connect(func(): Audio.play("click"))
	cur.add_child(b)
	return b


func _show_menu() -> void:
	_reset_box()
	_label("MALLTOPIA 3D", 72, Color("ffd43b"))
	_label("My Dream Mall", 36, Color("a5d8ff"))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 20)
	box.add_child(sp)
	if GS.has_save():
		_button("Continue", _continue)
	_button("New Game", _show_new)
	_label("v0.2 prototype (3D, landscape)", 18, Color(1, 1, 1, 0.5))


func _continue() -> void:
	if GS.load_game():
		get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _show_new() -> void:
	_reset_box(50, -50, 24, -24)
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 40)
	box.add_child(hb)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	hb.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	hb.add_child(right)

	cur = left
	_label("Create your mall boss", 36, Color("ffd43b"))
	preview = preload("res://scripts/Preview.gd").new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preview)

	cur = right
	_label("Nickname", 24)
	name_edit = LineEdit.new()
	name_edit.text = "Boss"
	name_edit.max_length = 12
	name_edit.placeholder_text = "Your name"
	name_edit.custom_minimum_size = Vector2(0, 64)
	right.add_child(name_edit)
	_label("Outfit color", 24)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	right.add_child(row)
	for i in GS.AVATAR_COLORS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(58, 58)
		var sb := StyleBoxFlat.new()
		sb.bg_color = GS.AVATAR_COLORS[i]
		sb.set_corner_radius_all(29)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_pick_color.bind(i))
		row.add_child(b)
	_label("Style", 24)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	right.add_child(row2)
	for i in GS.STYLE_NAMES.size():
		var b := Button.new()
		b.text = GS.STYLE_NAMES[i]
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick_style.bind(i))
		row2.add_child(b)
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	right.add_child(row3)
	cur = row3
	var back := _button("Back", _show_menu)
	back.custom_minimum_size = Vector2(0, 70)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var go := _button("Start!", _start)
	go.custom_minimum_size = Vector2(0, 70)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
