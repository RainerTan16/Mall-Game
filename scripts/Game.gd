extends Node3D
## 3D mall gameplay (landscape): world, player, customers, UI panels, arcade minigame.

const ENTRANCE := Vector3(-12.5, 0.0, 0.0)
const ARCADE_POS := Vector3(11.5, 0.0, 0.0)
const SHOP_SIZE := Vector3(5.0, 2.6, 4.0)
const PLAYER_SPEED := 7.0
const CAM_OFFSET := Vector3(0.0, 16.0, 13.2)

var player := Vector3(-9.0, 0.0, 0.0)
var joy := Vector2.ZERO
var customers: Array = []
var floaters: Array = []
var spawn_t := 1.5

var cam: Camera3D
var player_node: Node3D
var shop_nodes: Array = []
var decor_nodes: Array = []

var ui_root: Control
var lbl_money: Label
var lbl_level: Label
var lbl_sat: Label
var xp_bar: ProgressBar
var sat_bar: ProgressBar
var toast_lbl: Label
var toast_t := 0.0

var panel: PanelContainer
var panel_box: VBoxContainer
var panel_scroll: ScrollContainer
var panel_builder: Callable

var arcade_layer: Control
var arcade_on := false
var arcade_time := 0.0
var arcade_score := 0
var arcade_btn: Button
var arcade_lbl: Label


func _ready() -> void:
	if not GS.started and not GS.load_game():
		GS.reset_state("Boss", 0, 0)
		GS.started = true
	_build_world()
	_build_ui()
	GS.toast.connect(_on_toast)
	_refresh_hud()
	Audio.apply_settings()


# =====================================================  3D world building
func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _add(parent: Node, mesh: Mesh, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _box(parent: Node, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(parent, b, c, pos)


func _cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	return _add(parent, m, c, pos)


func _sphere(parent: Node, r: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return _add(parent, m, c, pos)


func _capsule(parent: Node, r: float, h: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return _add(parent, m, c, pos)


func _label3d(parent: Node, text: String, size: int, pos: Vector3, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0105
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color.BLACK
	l.no_depth_test = true
	l.position = pos
	parent.add_child(l)
	return l


func _set_text(l: Label3D, t: String) -> void:
	if l.text != t:
		l.text = t


func slot_center(i: int) -> Vector3:
	return Vector3(-9.0 + (i / 2) * 6.0, 0.0, -5.5 if i % 2 == 0 else 5.5)


func door(i: int) -> Vector3:
	var c := slot_center(i)
	return Vector3(c.x, 0.0, -2.6 if i % 2 == 0 else 2.6)


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1e2140")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.9
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.rotation_degrees = Vector3(-50.4, 0, 0)
	cam.position = CAM_OFFSET
	add_child(cam)
	cam.make_current()

	# floor + corridor + entrance + walls
	_box(self, Vector3(27, 0.2, 17), Vector3(0, -0.1, 0), Color("cfc7b3"))
	_box(self, Vector3(27, 0.02, 7), Vector3(0, 0.01, 0), Color("efe9dc"))
	for k in 13:
		_box(self, Vector3(1, 0.025, 1), Vector3(-12.0 + k * 2.0, 0.02, 0.0 if k % 2 == 0 else 1.0), Color("e2dac8"))
	_box(self, Vector3(1.0, 0.03, 3.0), Vector3(-13.0, 0.03, 0), Color("4dabf7"))
	_box(self, Vector3(27, 3.0, 0.4), Vector3(0, 1.5, -8.7), Color("495057"))
	_label3d(self, "ENTRANCE", 40, Vector3(-12.5, 1.2, 1.9), Color("a5d8ff"))

	# shops
	for i in GS.MAX_SLOTS:
		var root := Node3D.new()
		root.position = slot_center(i)
		add_child(root)
		var front := 1.0 if i % 2 == 0 else -1.0
		var body := _box(root, SHOP_SIZE, Vector3(0, SHOP_SIZE.y / 2.0, 0), Color.GRAY)
		var sign_col: Color = GS.SHOPS[i].color
		_box(root, Vector3(5.0, 0.5, 0.15), Vector3(0, 2.3, front * 2.05), sign_col)
		_box(root, Vector3(1.3, 1.8, 0.12), Vector3(0, 0.9, front * 2.03), Color("343a40"))
		var nm := _label3d(root, "", 54, Vector3(0, 3.9, 0), Color.WHITE)
		var inf := _label3d(root, "", 40, Vector3(0, 3.35, 0), Color("ffe8a3"))
		var coin := _label3d(root, "", 56, Vector3(0, 4.9, 0), Color("ffd43b"))
		coin.visible = false
		shop_nodes.append({"mat": body.material_override, "name": nm, "info": inf, "coin": coin})

	# decorations (shown when owned)
	for i in GS.DECOR.size():
		var n := Node3D.new()
		n.position = Vector3(-9.0 + i * 3.6, 0.0, 0.0)
		add_child(n)
		_build_decor_model(n, i)
		decor_nodes.append(n)

	# arcade machine
	var ar := Node3D.new()
	ar.position = ARCADE_POS
	add_child(ar)
	_box(ar, Vector3(1.6, 2.4, 1.2), Vector3(0, 1.2, 0), Color("5f3dc4"))
	_box(ar, Vector3(1.2, 0.8, 0.1), Vector3(-0.0, 1.7, 0.6), Color("74c0fc"))
	_cyl(ar, 0.1, 0.1, 0.2, Vector3(-0.3, 1.0, 0.65), Color("ff6b6b"))
	_cyl(ar, 0.1, 0.1, 0.2, Vector3(0.3, 1.0, 0.65), Color("ffd43b"))
	_label3d(ar, "ARCADE", 44, Vector3(0, 3.1, 0), Color("d0bfff"))

	# player
	player_node = Node3D.new()
	add_child(player_node)
	var col: Color = GS.AVATAR_COLORS[GS.avatar_color % GS.AVATAR_COLORS.size()]
	_capsule(player_node, 0.45, 1.5, Vector3(0, 0.75, 0), col)
	_sphere(player_node, 0.38, Vector3(0, 1.85, 0), Color("ffdfc0"))
	match GS.avatar_style:
		0:
			_cyl(player_node, 0.4, 0.4, 0.18, Vector3(0, 2.18, 0), col.darkened(0.35))
			_box(player_node, Vector3(0.5, 0.06, 0.35), Vector3(0, 2.1, 0.4), col.darkened(0.5))
		1:
			_cyl(player_node, 0.45, 0.28, 0.35, Vector3(0, 2.3, 0), Color("ffd43b"))
		2:
			_sphere(player_node, 0.17, Vector3(-0.3, 2.2, 0), Color("ff8fb3"))
			_sphere(player_node, 0.17, Vector3(0.3, 2.2, 0), Color("ff8fb3"))
			_sphere(player_node, 0.1, Vector3(0, 2.2, 0), Color("ff5c8a"))
	_label3d(player_node, GS.nickname, 44, Vector3(0, 2.9, 0), Color.WHITE)


func _build_decor_model(n: Node3D, i: int) -> void:
	match i:
		0:
			_cyl(n, 0.4, 0.3, 0.6, Vector3(0, 0.3, 0), Color("8d5524"))
			_sphere(n, 0.7, Vector3(0, 1.1, 0), Color("2f9e44"))
		1:
			_box(n, Vector3(2.2, 0.15, 0.8), Vector3(0, 0.5, 0), Color("a9743a"))
			_box(n, Vector3(2.2, 0.6, 0.12), Vector3(0, 0.9, -0.35), Color("8d5524"))
			_box(n, Vector3(0.15, 0.5, 0.7), Vector3(-1.0, 0.25, 0), Color("495057"))
			_box(n, Vector3(0.15, 0.5, 0.7), Vector3(1.0, 0.25, 0), Color("495057"))
		2:
			_cyl(n, 1.1, 1.2, 0.5, Vector3(0, 0.25, 0), Color("adb5bd"))
			_cyl(n, 0.95, 0.95, 0.2, Vector3(0, 0.45, 0), Color("74c0fc"))
			_cyl(n, 0.12, 0.12, 1.2, Vector3(0, 1.0, 0), Color("ced4da"))
			_sphere(n, 0.25, Vector3(0, 1.7, 0), Color("a5d8ff"))
		3:
			_box(n, Vector3(0.15, 2.0, 0.15), Vector3(0, 1.0, 0), Color("495057"))
			_box(n, Vector3(1.8, 0.7, 0.15), Vector3(0, 2.2, 0), Color("212529"))
			_label3d(n, "OPEN", 48, Vector3(0, 2.2, 0.2), Color("ff4dd2"))
		4:
			_box(n, Vector3(2.2, 0.03, 4.0), Vector3(0, 0.035, 0), Color("c92a2a"))
			_box(n, Vector3(1.9, 0.035, 3.7), Vector3(0, 0.04, 0), Color("e03131"))
		5:
			_cyl(n, 0.04, 0.04, 1.2, Vector3(0, 3.0, 0), Color("495057"))
			_sphere(n, 0.5, Vector3(0, 2.2, 0), Color("ffd43b"))
			for a in 6:
				_sphere(n, 0.15, Vector3(0, 2.2, 0) + Vector3(0.9, 0, 0).rotated(Vector3.UP, a * TAU / 6.0), Color("ffe066"))


# =====================================================  UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 26
	ui_root.theme = th
	layer.add_child(ui_root)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 6
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(top)
	var r1 := HBoxContainer.new()
	top.add_child(r1)
	lbl_money = Label.new()
	lbl_money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_money.add_theme_color_override("font_color", Color("ffd43b"))
	lbl_money.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_money.add_theme_constant_override("outline_size", 6)
	lbl_money.add_theme_font_size_override("font_size", 32)
	r1.add_child(lbl_money)
	lbl_level = Label.new()
	lbl_level.add_theme_font_size_override("font_size", 28)
	lbl_level.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_level.add_theme_constant_override("outline_size", 6)
	r1.add_child(lbl_level)
	var r2 := HBoxContainer.new()
	top.add_child(r2)
	xp_bar = _bar(r2, Color("4dabf7"))
	lbl_sat = Label.new()
	lbl_sat.add_theme_font_size_override("font_size", 20)
	lbl_sat.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_sat.add_theme_constant_override("outline_size", 5)
	r2.add_child(lbl_sat)
	sat_bar = _bar(r2, Color("51cf66"))

	toast_lbl = Label.new()
	toast_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_lbl.offset_top = 92
	toast_lbl.offset_bottom = 140
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.add_theme_color_override("font_color", Color("fff3bf"))
	toast_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_lbl.add_theme_constant_override("outline_size", 8)
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_lbl.visible = false
	ui_root.add_child(toast_lbl)

	var js = preload("res://scripts/Joystick.gd").new()
	js.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	js.offset_left = 14
	js.offset_top = -200
	js.offset_right = 174
	js.offset_bottom = -40
	js.moved.connect(func(v: Vector2): joy = v)
	ui_root.add_child(js)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 220
	bar.offset_right = -14
	bar.offset_top = -80
	bar.offset_bottom = -8
	bar.add_theme_constant_override("separation", 8)
	ui_root.add_child(bar)
	_nav(bar, "Shops", _open_shops)
	_nav(bar, "Decor", _open_decor)
	_nav(bar, "Quests", _open_quests)
	_nav(bar, "Arcade", _open_arcade)
	_nav(bar, "Menu", _open_menu)


func _bar(parent: Control, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 20)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b


func _nav(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	b.pressed.connect(func(): Audio.play("click"))
	parent.add_child(b)


func _refresh_hud() -> void:
	lbl_money.text = "Coins: %s" % GS.fmt(GS.money)
	lbl_level.text = "Lv %d" % GS.level
	xp_bar.max_value = 100.0 * GS.level
	xp_bar.value = GS.xp
	sat_bar.value = GS.satisfaction
	lbl_sat.text = " Happy %d%% " % int(GS.satisfaction)


func _on_toast(msg: String) -> void:
	toast_lbl.text = msg
	toast_lbl.visible = true
	toast_t = 2.6


# =====================================================  panels
func _open_panel(title: String, builder: Callable) -> void:
	_close_panel()
	panel_builder = builder
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 50
	panel.offset_top = 78
	panel.offset_right = -50
	panel.offset_bottom = -92
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.1, 0.11, 0.22, 0.98)
	psb.set_corner_radius_all(14)
	psb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", psb)
	ui_root.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var t := Label.new()
	t.text = title
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", Color("ffd43b"))
	head.add_child(t)
	var x := Button.new()
	x.text = "X"
	x.custom_minimum_size = Vector2(76, 64)
	x.pressed.connect(_close_panel)
	head.add_child(x)
	panel_scroll = ScrollContainer.new()
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(panel_scroll)
	panel_box = VBoxContainer.new()
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_theme_constant_override("separation", 10)
	panel_scroll.add_child(panel_box)
	panel_builder.call(panel_box)


func _close_panel() -> void:
	if panel:
		panel.queue_free()
		panel = null


func _refresh_panel() -> void:
	if panel == null:
		return
	var sv := panel_scroll.scroll_vertical
	for c in panel_box.get_children():
		panel_box.remove_child(c)
		c.queue_free()
	panel_builder.call(panel_box)
	await get_tree().process_frame
	if panel:
		panel_scroll.scroll_vertical = sv


func _label(box: Control, text: String, size := 24, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	box.add_child(l)
	return l


func _button(box: Control, text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 66)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not enabled
	b.pressed.connect(cb)
	box.add_child(b)
	return b


func _act(ok: bool) -> void:
	if ok:
		Audio.play("coin")
	_refresh_panel()


func _do_buy(i: int) -> void:
	_act(GS.buy_shop(i))


func _do_upgrade(i: int) -> void:
	_act(GS.upgrade_shop(i))


func _do_hire(i: int) -> void:
	_act(GS.hire(i))


func _do_decor(i: int) -> void:
	_act(GS.buy_decor(i))


func _do_expand() -> void:
	_act(GS.expand())


func _do_claim(id: String) -> void:
	if GS.claim_mission(id):
		Audio.play("coin")
	_refresh_panel()


# ----- shops
func _open_shops() -> void:
	_open_panel("Shops", _build_shops)


func _build_shops(box: VBoxContainer) -> void:
	_label(box, "Coins: %s   |   Plots: %d/%d" % [GS.fmt(GS.money), GS.unlocked_slots, GS.MAX_SLOTS], 26, Color("ffd43b"))
	if GS.unlocked_slots < GS.MAX_SLOTS:
		var n := GS.unlocked_slots
		_button(box, "Expand mall: %s coins (needs Lv %d)" % [GS.fmt(GS.EXPAND_COST[n]), n], _do_expand)
	for i in GS.SHOPS.size():
		box.add_child(HSeparator.new())
		_shop_block(box, i)


func _open_shop(i: int) -> void:
	_open_panel(GS.SHOPS[i].name, _build_one.bind(i))


func _build_one(box: VBoxContainer, i: int) -> void:
	_label(box, "Coins: %s" % GS.fmt(GS.money), 26, Color("ffd43b"))
	_shop_block(box, i)


func _shop_block(box: VBoxContainer, i: int) -> void:
	var d: Dictionary = GS.SHOPS[i]
	var s: Dictionary = GS.shops[i]
	_label(box, "%s  (%s)" % [d.name, d.cat], 30, d.color.lightened(0.25))
	if i >= GS.unlocked_slots:
		_label(box, "Locked plot. Expand the mall to unlock.", 22, Color.GRAY)
	elif not s.owned:
		_label(box, "Earns about %d coins per customer." % d.income, 22)
		_button(box, "Open shop: %s coins" % GS.fmt(d.cost), _do_buy.bind(i), GS.money >= d.cost)
	else:
		_label(box, "Level %d/%d  |  Staff %d/%d  |  %d coins per customer  |  Waiting to collect: %d" % [
			s.level, GS.MAX_SHOP_LEVEL, s.employees, GS.MAX_STAFF, GS.shop_income(i), s.pending], 22)
		var maxed: bool = s.level >= GS.MAX_SHOP_LEVEL
		_button(box, "MAX LEVEL" if maxed else "Upgrade: %s coins" % GS.fmt(GS.upgrade_cost(i)), _do_upgrade.bind(i), not maxed and GS.money >= GS.upgrade_cost(i))
		var full: bool = s.employees >= GS.MAX_STAFF
		_button(box, "Staff full" if full else "Hire employee: %s coins" % GS.fmt(GS.hire_cost(i)), _do_hire.bind(i), not full and GS.money >= GS.hire_cost(i))
		if s.employees > 0:
			_label(box, "Staff auto-collect income and handle more customers. Wage: 8 coins/min each.", 20, Color(1, 1, 1, 0.7))
		else:
			_label(box, "No staff: walk near the shop to collect coins.", 20, Color(1, 1, 1, 0.7))


# ----- decorations
func _open_decor() -> void:
	_open_panel("Decorations", _build_decor)


func _build_decor(box: VBoxContainer) -> void:
	_label(box, "Coins: %s   |   Happiness bonus: +%d" % [GS.fmt(GS.money), GS.decor_bonus()], 26, Color("ffd43b"))
	for i in GS.DECOR.size():
		var d: Dictionary = GS.DECOR[i]
		box.add_child(HSeparator.new())
		_label(box, "%s   (+%d happiness)" % [d.name, d.sat], 28)
		if GS.decor[i]:
			_label(box, "Owned", 22, Color("69db7c"))
		else:
			_button(box, "Buy: %s coins" % GS.fmt(d.cost), _do_decor.bind(i), GS.money >= d.cost)


# ----- quests
func _open_quests() -> void:
	_open_panel("Quests", _build_quests)


func _build_quests(box: VBoxContainer) -> void:
	_label(box, "Missions", 30, Color("ffd43b"))
	for m in GS.MISSIONS:
		var prog := mini(GS.mission_progress(m), m.target)
		_label(box, "%s  [%s/%s]  Reward %d" % [m.text, GS.fmt(prog), GS.fmt(m.target), m.reward], 22)
		if GS.claimed.has(m.id):
			_label(box, "Completed", 20, Color("69db7c"))
		elif prog >= m.target:
			_button(box, "Claim %d coins" % m.reward, _do_claim.bind(m.id))
	box.add_child(HSeparator.new())
	_label(box, "Achievements", 30, Color("ffd43b"))
	for a in GS.ACHIEVEMENTS:
		var done: bool = GS.achieved.has(a.id)
		var t: String = a.text + ("   [DONE]" if done else "   [%s/%s]" % [GS.fmt(mini(GS.stats.get(a.stat, 0), a.target)), GS.fmt(a.target)])
		_label(box, t, 22, Color("69db7c") if done else Color.WHITE)


# ----- menu
func _open_menu() -> void:
	_open_panel("Menu", _build_menu)


func _build_menu(box: VBoxContainer) -> void:
	_label(box, "%s  |  Level %d  |  Earned %s total" % [GS.nickname, GS.level, GS.fmt(GS.stats.get("earned", 0))], 24)
	_button(box, "Save now", _menu_save)
	_button(box, "Music: " + ("ON" if GS.music_on else "OFF"), _menu_music)
	_button(box, "Sound effects: " + ("ON" if GS.sfx_on else "OFF"), _menu_sfx)
	_button(box, "Save and go to main menu", _menu_exit)
	_label(box, "Game saves automatically every 15 seconds.", 20, Color(1, 1, 1, 0.7))


func _menu_save() -> void:
	GS.save_game()
	GS.say("Game saved")


func _menu_music() -> void:
	GS.music_on = not GS.music_on
	Audio.apply_settings()
	_refresh_panel()


func _menu_sfx() -> void:
	GS.sfx_on = not GS.sfx_on
	_refresh_panel()


func _menu_exit() -> void:
	GS.save_game()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


# =====================================================  arcade minigame
func _open_arcade() -> void:
	if arcade_on:
		return
	_close_panel()
	arcade_on = true
	arcade_time = 15.0
	arcade_score = 0
	arcade_layer = ColorRect.new()
	arcade_layer.color = Color(0.05, 0.02, 0.15, 0.85)
	arcade_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(arcade_layer)
	arcade_lbl = Label.new()
	arcade_lbl.position = Vector2(30, 90)
	arcade_lbl.add_theme_font_size_override("font_size", 34)
	arcade_layer.add_child(arcade_lbl)
	arcade_btn = Button.new()
	arcade_btn.text = "TAP!"
	arcade_btn.custom_minimum_size = Vector2(120, 120)
	arcade_btn.size = Vector2(120, 120)
	arcade_btn.pressed.connect(_arcade_hit)
	arcade_layer.add_child(arcade_btn)
	_arcade_move()


func _arcade_move() -> void:
	var vp := get_viewport().get_visible_rect().size
	arcade_btn.position = Vector2(randf_range(30, vp.x - 150), randf_range(140, vp.y - 150))


func _arcade_hit() -> void:
	arcade_score += 1
	Audio.play("click")
	_arcade_move()


func _arcade_end() -> void:
	arcade_on = false
	var reward := arcade_score * (4 + GS.level * 2)
	arcade_layer.queue_free()
	GS.add_money(reward)
	GS.satisfaction = minf(100.0, GS.satisfaction + 3.0)
	GS.add_xp(10 + arcade_score)
	GS.stat_add("arcade", 1)
	Audio.play("coin")
	GS.say("Arcade score %d: +%d coins!" % [arcade_score, reward])


# =====================================================  loop
func _process(delta: float) -> void:
	GS.tick(delta)

	var dir := joy
	var k := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if k != Vector2.ZERO:
		dir = k
	player += Vector3(dir.x, 0.0, dir.y) * PLAYER_SPEED * delta
	player.x = clampf(player.x, -12.8, 12.8)
	player.z = clampf(player.z, -7.8, 7.8)
	_push_out_of_shops()
	_collect()
	_spawn(delta)
	_update_customers(delta)
	_update_world(delta)

	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0:
			toast_lbl.visible = false

	if arcade_on:
		arcade_time -= delta
		arcade_lbl.text = "Time %.1f    Score %d" % [maxf(0.0, arcade_time), arcade_score]
		if arcade_time <= 0.0:
			_arcade_end()

	_refresh_hud()


func _update_world(delta: float) -> void:
	player_node.position = player
	var target := Vector3(clampf(player.x, -6.0, 6.0) * 0.5, 0.0, 0.5 + player.z * 0.25)
	cam.position = cam.position.lerp(target + CAM_OFFSET, clampf(6.0 * delta, 0.0, 1.0))

	for i in GS.MAX_SLOTS:
		var n: Dictionary = shop_nodes[i]
		var d: Dictionary = GS.SHOPS[i]
		var s: Dictionary = GS.shops[i]
		var mat: StandardMaterial3D = n.mat
		var coin: Label3D = n.coin
		if i >= GS.unlocked_slots:
			mat.albedo_color = Color("868e96")
			_set_text(n.name, "Locked")
			_set_text(n.info, "Needs Lv %d" % i)
			coin.visible = false
		elif not s.owned:
			mat.albedo_color = Color("ced4da")
			_set_text(n.name, d.name)
			_set_text(n.info, "For sale: %s" % GS.fmt(d.cost))
			coin.visible = false
		else:
			mat.albedo_color = d.color.lightened(0.3)
			_set_text(n.name, d.name)
			_set_text(n.info, "Lv %d  Staff %d" % [s.level, s.employees])
			coin.visible = s.pending > 0
			if s.pending > 0:
				_set_text(coin, "$" + GS.fmt(s.pending))
	for i in decor_nodes.size():
		decor_nodes[i].visible = GS.decor[i]

	for c in customers:
		c.node.position = c.pos

	for f in floaters.duplicate():
		f.t -= delta
		f.node.position.y += 1.4 * delta
		f.node.modulate.a = clampf(f.t / 0.5, 0.0, 1.0)
		if f.t <= 0.0:
			f.node.queue_free()
			floaters.erase(f)


func _push_out_of_shops() -> void:
	for i in GS.MAX_SLOTS:
		var c := slot_center(i)
		var r := Rect2(c.x - 2.9, c.z - 2.4, 5.8, 4.8)
		var p := Vector2(player.x, player.z)
		if r.has_point(p):
			var dl := p.x - r.position.x
			var dr := r.end.x - p.x
			var dt := p.y - r.position.y
			var db := r.end.y - p.y
			var m := minf(minf(dl, dr), minf(dt, db))
			if m == dl:
				player.x = r.position.x
			elif m == dr:
				player.x = r.end.x
			elif m == dt:
				player.z = r.position.y
			else:
				player.z = r.end.y


func _xz_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _collect() -> void:
	for i in GS.SHOPS.size():
		var s: Dictionary = GS.shops[i]
		if s.owned and s.pending > 0 and _xz_dist(player, slot_center(i)) < 4.4:
			var n: int = s.pending
			s.pending = 0
			GS.stat_add("collected", 1)
			GS.add_money(n)
			Audio.play("coin")
			_float("+%d" % n, door(i) + Vector3(0, 2.2, 0), Color("ffd43b"))


func _float(text: String, pos: Vector3, col: Color) -> void:
	var l := _label3d(self, text, 56, pos, col)
	floaters.append({"node": l, "t": 1.3})


func _shoppers_at(i: int) -> int:
	var n := 0
	for c in customers:
		if c.state == 1 and c.target == i:
			n += 1
	return n


func _make_customer_node(col: Color) -> Node3D:
	var n := Node3D.new()
	_capsule(n, 0.32, 1.2, Vector3(0, 0.6, 0), col)
	_sphere(n, 0.26, Vector3(0, 1.4, 0), Color("ffdfc0"))
	add_child(n)
	return n


func _spawn(delta: float) -> void:
	spawn_t -= delta
	if spawn_t > 0.0:
		return
	var open: Array = []
	for i in GS.shops.size():
		if GS.shops[i].owned:
			open.append(i)
	var attract := 0.15 * open.size() + GS.decor_bonus() / 40.0 + GS.level * 0.05 + GS.satisfaction / 200.0
	spawn_t = clampf(4.0 / (1.0 + attract), 0.7, 6.0)
	if open.is_empty() or customers.size() >= mini(25, 5 + GS.level * 2):
		return
	var col := Color.from_hsv(randf(), 0.5, 0.95)
	var pos := ENTRANCE + Vector3(0, 0, randf_range(-1.2, 1.2))
	var node := _make_customer_node(col)
	node.position = pos
	customers.append({
		"pos": pos, "node": node, "target": open.pick_random(), "state": 0, "t": 0.0,
		"speed": randf_range(1.8, 2.8)})


func _update_customers(delta: float) -> void:
	for c in customers.duplicate():
		match c.state:
			0:
				var tgt := door(c.target)
				c.pos = c.pos.move_toward(tgt, c.speed * delta)
				if c.pos.distance_to(tgt) < 0.1:
					if _shoppers_at(c.target) >= 2 + GS.shops[c.target].employees * 2:
						_float("Too busy!", c.pos + Vector3(0, 2.2, 0), Color("ff8787"))
						GS.satisfaction = maxf(0.0, GS.satisfaction - 3.0)
						c.state = 2
					else:
						c.state = 1
						c.t = randf_range(1.5, 3.5)
			1:
				c.t -= delta
				if c.t <= 0.0:
					_serve(c)
					c.state = 2
			2:
				c.pos = c.pos.move_toward(ENTRANCE, c.speed * delta)
				if c.pos.distance_to(ENTRANCE) < 0.15:
					c.node.queue_free()
					customers.erase(c)


func _serve(c: Dictionary) -> void:
	var i: int = c.target
	var income := GS.shop_income(i)
	if GS.shops[i].employees > 0:
		GS.add_money(income)
		_float("+%d" % income, door(i) + Vector3(0, 2.2, 0), Color("ffd43b"))
	else:
		GS.shops[i].pending += income
	GS.satisfaction = minf(100.0, GS.satisfaction + 1.2)
	GS.add_xp(3)
	GS.stat_add("served", 1)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if arcade_on:
			return
		var from := cam.project_ray_origin(e.position)
		var dir := cam.project_ray_normal(e.position)
		var best := -2
		var best_d := 1e9
		for i in GS.MAX_SLOTS:
			var c := slot_center(i)
			var hit = AABB(c + Vector3(-2.5, 0, -2.0), SHOP_SIZE).intersects_ray(from, dir)
			if hit != null and from.distance_to(hit) < best_d:
				best_d = from.distance_to(hit)
				best = i
		var ah = AABB(ARCADE_POS + Vector3(-0.9, 0, -0.7), Vector3(1.8, 2.4, 1.4)).intersects_ray(from, dir)
		if ah != null and from.distance_to(ah) < best_d:
			best = -1
		if best >= 0:
			Audio.play("click")
			_open_shop(best)
		elif best == -1:
			Audio.play("click")
			_open_arcade()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if panel:
			_close_panel()
		else:
			_open_menu()
