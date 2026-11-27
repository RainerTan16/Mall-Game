extends Node2D
## Mall gameplay: map, player, customers, shops, UI panels, arcade minigame.

const SLOT_W := 150.0
const SLOT_H := 130.0
const FLOOR_TOP := 100.0
const FLOOR_BOT := 870.0
const ENTRANCE := Vector2(270, 860)
const ARCADE_RECT := Rect2(240, 540, 60, 80)
const PLAYER_SPEED := 230.0

var player := Vector2(270, 760)
var joy := Vector2.ZERO
var customers: Array = []
var floaters: Array = []
var spawn_t := 1.5
var font: Font

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
	font = ThemeDB.fallback_font
	if not GS.started and not GS.load_game():
		GS.reset_state("Boss", 0, 0)
		GS.started = true
	_build_ui()
	GS.toast.connect(_on_toast)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_hud()
	Audio.apply_settings()


func _layout() -> void:
	var vp := get_viewport_rect().size
	var s := minf(1.0, vp.y / 960.0)
	scale = Vector2(s, s)
	position = Vector2((540.0 - 540.0 * s) / 2.0, maxf(0.0, (vp.y - 960.0 * s) / 2.0))


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

	# top HUD
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 10
	top.offset_right = -10
	top.offset_top = 6
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(top)
	var r1 := HBoxContainer.new()
	top.add_child(r1)
	lbl_money = Label.new()
	lbl_money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_money.add_theme_color_override("font_color", Color("ffd43b"))
	lbl_money.add_theme_font_size_override("font_size", 32)
	r1.add_child(lbl_money)
	lbl_level = Label.new()
	lbl_level.add_theme_font_size_override("font_size", 28)
	r1.add_child(lbl_level)
	var r2 := HBoxContainer.new()
	top.add_child(r2)
	xp_bar = _bar(r2, Color("4dabf7"))
	lbl_sat = Label.new()
	lbl_sat.add_theme_font_size_override("font_size", 20)
	r2.add_child(lbl_sat)
	sat_bar = _bar(r2, Color("51cf66"))

	# toast
	toast_lbl = Label.new()
	toast_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_lbl.offset_top = 125
	toast_lbl.offset_bottom = 175
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.add_theme_color_override("font_color", Color("fff3bf"))
	toast_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_lbl.add_theme_constant_override("outline_size", 8)
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_lbl.visible = false
	ui_root.add_child(toast_lbl)

	# joystick
	var js = preload("res://scripts/Joystick.gd").new()
	js.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	js.offset_left = 14
	js.offset_top = -260
	js.offset_right = 174
	js.offset_bottom = -100
	js.moved.connect(func(v: Vector2): joy = v)
	ui_root.add_child(js)

	# bottom bar
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = -84
	bar.offset_bottom = -8
	bar.add_theme_constant_override("separation", 6)
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
	panel.offset_left = 14
	panel.offset_top = 105
	panel.offset_right = -14
	panel.offset_bottom = -96
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
	arcade_lbl.position = Vector2(20, 110)
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
	var vp := get_viewport_rect().size
	arcade_btn.position = Vector2(randf_range(20, vp.x - 140), randf_range(200, vp.y - 260))


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
	player += dir * PLAYER_SPEED * delta
	player.x = clampf(player.x, 20.0, 520.0)
	player.y = clampf(player.y, FLOOR_TOP + 25.0, FLOOR_BOT - 8.0)
	_push_out_of_shops()
	_collect()
	_spawn(delta)
	_update_customers(delta)

	for f in floaters.duplicate():
		f.t -= delta
		f.pos.y -= 40.0 * delta
		if f.t <= 0.0:
			floaters.erase(f)

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
	queue_redraw()


func slot_rect(i: int) -> Rect2:
	var x := 16.0 if i % 2 == 0 else 374.0
	return Rect2(x, 130.0 + (i / 2) * 160.0, SLOT_W, SLOT_H)


func door(i: int) -> Vector2:
	var r := slot_rect(i)
	return Vector2(192.0 if i % 2 == 0 else 348.0, r.position.y + r.size.y / 2.0)


func _push_out_of_shops() -> void:
	for i in GS.MAX_SLOTS:
		var r := slot_rect(i).grow(10.0)
		if r.has_point(player):
			var dl := player.x - r.position.x
			var dr := r.end.x - player.x
			var dt := player.y - r.position.y
			var db := r.end.y - player.y
			var m := minf(minf(dl, dr), minf(dt, db))
			if m == dl:
				player.x = r.position.x
			elif m == dr:
				player.x = r.end.x
			elif m == dt:
				player.y = r.position.y
			else:
				player.y = r.end.y


func _collect() -> void:
	for i in GS.SHOPS.size():
		var s: Dictionary = GS.shops[i]
		if s.owned and s.pending > 0 and player.distance_to(slot_rect(i).get_center()) < 105.0:
			var n: int = s.pending
			s.pending = 0
			GS.stat_add("collected", 1)
			GS.add_money(n)
			Audio.play("coin")
			_float("+%d" % n, slot_rect(i).get_center(), Color("ffd43b"))


func _float(text: String, pos: Vector2, col: Color) -> void:
	floaters.append({"pos": pos, "text": text, "t": 1.2, "col": col})


func _shoppers_at(i: int) -> int:
	var n := 0
	for c in customers:
		if c.state == 1 and c.target == i:
			n += 1
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
	customers.append({
		"pos": ENTRANCE + Vector2(randf_range(-30, 30), 0),
		"target": open.pick_random(), "state": 0, "t": 0.0,
		"col": Color.from_hsv(randf(), 0.5, 0.95), "speed": randf_range(60.0, 100.0)})


func _update_customers(delta: float) -> void:
	for c in customers.duplicate():
		match c.state:
			0:
				var tgt := door(c.target)
				c.pos = c.pos.move_toward(tgt, c.speed * delta)
				if c.pos.distance_to(tgt) < 2.0:
					if _shoppers_at(c.target) >= 2 + GS.shops[c.target].employees * 2:
						_float("Too busy!", c.pos, Color("ff8787"))
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
				if c.pos.distance_to(ENTRANCE) < 3.0:
					customers.erase(c)


func _serve(c: Dictionary) -> void:
	var i: int = c.target
	var income := GS.shop_income(i)
	if GS.shops[i].employees > 0:
		GS.add_money(income)
		_float("+%d" % income, door(i), Color("ffd43b"))
	else:
		GS.shops[i].pending += income
	GS.satisfaction = minf(100.0, GS.satisfaction + 1.2)
	GS.add_xp(3)
	GS.stat_add("served", 1)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if arcade_on:
			return
		var p := to_local(get_global_mouse_position())
		for i in GS.MAX_SLOTS:
			if slot_rect(i).has_point(p):
				Audio.play("click")
				_open_shop(i)
				return
		if ARCADE_RECT.grow(24.0).has_point(p):
			Audio.play("click")
			_open_arcade()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if panel:
			_close_panel()
		else:
			_open_menu()


# =====================================================  drawing
func _text(txt: String, cx: float, y: float, size: int, col: Color, w := 150.0) -> void:
	draw_string(font, Vector2(cx - w / 2.0, y), txt, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


func _draw() -> void:
	# floor
	draw_rect(Rect2(0, FLOOR_TOP, 540, FLOOR_BOT - FLOOR_TOP + 10), Color("efe9dc"))
	for r in range(13):
		for c in range(4):
			if (r + c) % 2 == 0:
				draw_rect(Rect2(182 + c * 44, FLOOR_TOP + r * 44, 44, 44), Color("e2dac8"))
	draw_rect(Rect2(210, 866, 120, 14), Color("4dabf7"))
	_text("ENTRANCE", 270, 856, 16, Color("495057"), 120)

	# decorations
	for i in GS.DECOR.size():
		if GS.decor[i]:
			_draw_decor(i, Vector2(230.0 + (i % 2) * 80.0, 150.0 + (i / 2) * 110.0))

	# arcade machine
	draw_rect(ARCADE_RECT, Color("5f3dc4"))
	draw_rect(Rect2(ARCADE_RECT.position + Vector2(8, 8), Vector2(44, 28)), Color("74c0fc"))
	draw_circle(ARCADE_RECT.position + Vector2(20, 55), 6, Color("ff6b6b"))
	draw_circle(ARCADE_RECT.position + Vector2(40, 55), 6, Color("ffd43b"))
	_text("ARCADE", 270, 636, 16, Color("5f3dc4"), 100)

	# shops
	for i in GS.MAX_SLOTS:
		_draw_shop(i)

	# customers
	for c in customers:
		draw_circle(c.pos + Vector2(0, 5), 10, c.col)
		draw_circle(c.pos + Vector2(0, -7), 6.5, Color("ffdfc0"))

	# player
	GS.draw_avatar(self, player, GS.avatar_color, GS.avatar_style, 1.2)
	_text(GS.nickname, player.x, player.y - 34, 16, Color("212529"), 120)

	for f in floaters:
		_text(f.text, f.pos.x, f.pos.y, 22, f.col, 140)


func _draw_shop(i: int) -> void:
	var r := slot_rect(i)
	if i >= GS.unlocked_slots:
		draw_rect(r, Color("868e96"))
		_text("LOCKED", r.get_center().x, r.get_center().y - 4, 22, Color("dee2e6"))
		_text("Needs Lv %d" % i, r.get_center().x, r.get_center().y + 22, 18, Color("dee2e6"))
		return
	var d: Dictionary = GS.SHOPS[i]
	var s: Dictionary = GS.shops[i]
	if not s.owned:
		draw_rect(r, Color("adb5bd"))
		draw_rect(r.grow(-6), Color("ced4da"))
		_text("For sale", r.get_center().x, r.get_center().y - 6, 24, Color("343a40"))
		_text(GS.fmt(d.cost) + " coins", r.get_center().x, r.get_center().y + 22, 20, Color("343a40"))
		return
	draw_rect(r, d.color.darkened(0.25))
	draw_rect(r.grow(-6), d.color.lightened(0.35))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 30)), d.color)
	_text(d.name, r.get_center().x, r.position.y + 23, 22, Color.WHITE)
	_text("Lv %d" % s.level, r.get_center().x, r.get_center().y + 8, 24, Color("212529"))
	_text("Staff %d" % s.employees, r.get_center().x, r.get_center().y + 34, 18, Color("212529"))
	var door_x := r.end.x - 4.0 if i % 2 == 0 else r.position.x - 2.0
	draw_rect(Rect2(door_x, r.get_center().y - 18, 6, 36), Color("495057"))
	if s.pending > 0:
		var bp := r.position + Vector2(r.size.x - 30, 52)
		draw_circle(bp, 24, Color("fab005"))
		draw_circle(bp, 24, Color("e67700"), false, 3.0)
		_text(GS.fmt(s.pending), bp.x, bp.y + 6, 16, Color("212529"), 60)


func _draw_decor(i: int, p: Vector2) -> void:
	match i:
		0:
			draw_rect(Rect2(p.x - 8, p.y + 6, 16, 14), Color("8d5524"))
			draw_circle(p + Vector2(0, -4), 16, Color("2f9e44"))
		1:
			draw_rect(Rect2(p.x - 26, p.y, 52, 12), Color("8d5524"))
			draw_rect(Rect2(p.x - 26, p.y - 10, 52, 6), Color("a9743a"))
		2:
			draw_circle(p, 28, Color("74c0fc"))
			draw_circle(p, 16, Color("a5d8ff"))
			draw_circle(p, 5, Color.WHITE)
		3:
			draw_rect(Rect2(p.x - 36, p.y - 12, 72, 28), Color("212529"))
			_text("OPEN", p.x, p.y + 8, 22, Color("ff4dd2"), 72)
		4:
			draw_rect(Rect2(p.x - 30, p.y - 36, 60, 70), Color("c92a2a"))
			draw_rect(Rect2(p.x - 26, p.y - 32, 52, 62), Color("e03131"), false, 3.0)
		5:
			draw_circle(p, 20, Color("ffd43b"))
			draw_circle(p, 10, Color("fff3bf"))
			for a in 6:
				draw_circle(p + Vector2(26, 0).rotated(a * TAU / 6.0), 5, Color("ffe066"))
