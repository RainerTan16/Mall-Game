extends Node
## Global game state: economy rules, progression, save/load.

signal changed
signal toast(msg: String)

const SAVE_PATH := "user://malltopia_save.json"
const MAX_SLOTS := 8
const START_SLOTS := 2
const EXPAND_COST := [0, 0, 800, 2000, 5000, 10000, 20000, 40000]
const MAX_SHOP_LEVEL := 5
const MAX_STAFF := 3
const AVATAR_COLORS := [Color("ff6b6b"), Color("4dabf7"), Color("51cf66"), Color("ffd43b"), Color("b197fc"), Color("ff922b")]
const STYLE_NAMES := ["Cap", "Crown", "Bow"]

const SHOPS := [
	{"name": "Fashion", "cat": "Clothing", "cost": 150, "income": 10, "color": Color("e64980")},
	{"name": "Snacks", "cat": "Food", "cost": 400, "income": 22, "color": Color("fd7e14")},
	{"name": "Books", "cat": "Books", "cost": 900, "income": 45, "color": Color("7950f2")},
	{"name": "Gadgets", "cat": "Electronics", "cost": 1800, "income": 80, "color": Color("1c7ed6")},
	{"name": "Toys", "cat": "Toys", "cost": 3500, "income": 140, "color": Color("fab005")},
	{"name": "Pharmacy", "cat": "Health", "cost": 6500, "income": 240, "color": Color("12b886")},
	{"name": "Sports", "cat": "Sports", "cost": 11000, "income": 400, "color": Color("fa5252")},
	{"name": "Jewelry", "cat": "Luxury", "cost": 18000, "income": 650, "color": Color("15aabf")},
]

const DECOR := [
	{"name": "Potted Plant", "cost": 120, "sat": 2},
	{"name": "Bench", "cost": 250, "sat": 3},
	{"name": "Fountain", "cost": 800, "sat": 5},
	{"name": "Neon Sign", "cost": 1500, "sat": 6},
	{"name": "Red Carpet", "cost": 3000, "sat": 8},
	{"name": "Chandelier", "cost": 6000, "sat": 12},
]

const MISSIONS := [
	{"id": "m1", "text": "Open your first shop", "stat": "shops_owned", "target": 1, "reward": 100},
	{"id": "m2", "text": "Serve 10 customers", "stat": "served", "target": 10, "reward": 150},
	{"id": "m3", "text": "Earn 1,000 coins", "stat": "earned", "target": 1000, "reward": 300},
	{"id": "m4", "text": "Upgrade shops 3 times", "stat": "upgrades", "target": 3, "reward": 250},
	{"id": "m5", "text": "Hire an employee", "stat": "hired", "target": 1, "reward": 300},
	{"id": "m6", "text": "Buy 2 decorations", "stat": "decor", "target": 2, "reward": 400},
	{"id": "m7", "text": "Play the arcade 3 times", "stat": "arcade", "target": 3, "reward": 300},
	{"id": "m8", "text": "Own 4 shops", "stat": "shops_owned", "target": 4, "reward": 800},
	{"id": "m9", "text": "Reach level 5", "stat": "level", "target": 5, "reward": 1000},
]

const ACHIEVEMENTS := [
	{"id": "a1", "text": "Earn 500 coins", "stat": "earned", "target": 500},
	{"id": "a2", "text": "Earn 5,000 coins", "stat": "earned", "target": 5000},
	{"id": "a3", "text": "Earn 50,000 coins", "stat": "earned", "target": 50000},
	{"id": "a4", "text": "Serve 50 customers", "stat": "served", "target": 50},
	{"id": "a5", "text": "Serve 250 customers", "stat": "served", "target": 250},
	{"id": "a6", "text": "Own all 8 shops", "stat": "shops_owned", "target": 8},
	{"id": "a7", "text": "Reach level 10", "stat": "level", "target": 10},
	{"id": "a8", "text": "Play arcade 10 times", "stat": "arcade", "target": 10},
	{"id": "a9", "text": "Hire 5 employees", "stat": "hired", "target": 5},
	{"id": "a10", "text": "Buy every decoration", "stat": "decor", "target": 6},
]

var started := false
var nickname := "Boss"
var avatar_color := 0
var avatar_style := 0
var money := 0
var level := 1
var xp := 0
var satisfaction := 50.0
var shops: Array = []
var unlocked_slots := START_SLOTS
var decor: Array = []
var stats: Dictionary = {}
var claimed: Array = []
var achieved: Array = []
var music_on := true
var sfx_on := true
var wage_t := 0.0
var save_t := 0.0


func reset_state(nick: String, col: int, style: int) -> void:
	nickname = nick
	avatar_color = col
	avatar_style = style
	money = 300
	level = 1
	xp = 0
	satisfaction = 50.0
	shops = []
	for i in SHOPS.size():
		shops.append({"owned": false, "level": 1, "employees": 0, "pending": 0})
	unlocked_slots = START_SLOTS
	decor = []
	for i in DECOR.size():
		decor.append(false)
	stats = {"earned": 0, "served": 0, "shops_owned": 0, "upgrades": 0, "hired": 0, "decor": 0, "arcade": 0, "level": 1, "collected": 0}
	claimed = []
	achieved = []
	wage_t = 0.0
	save_t = 0.0


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if not started:
		return
	var d := {
		"nick": nickname, "col": avatar_color, "style": avatar_style,
		"money": money, "level": level, "xp": xp, "sat": satisfaction,
		"shops": shops, "slots": unlocked_slots, "decor": decor,
		"stats": stats, "claimed": claimed, "achieved": achieved,
		"music": music_on, "sfx": sfx_on,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	reset_state(str(d.get("nick", "Boss")), int(d.get("col", 0)), int(d.get("style", 0)))
	money = int(d.get("money", 300))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	satisfaction = float(d.get("sat", 50.0))
	unlocked_slots = clampi(int(d.get("slots", START_SLOTS)), START_SLOTS, MAX_SLOTS)
	var sh: Array = d.get("shops", [])
	for i in mini(sh.size(), shops.size()):
		var s: Dictionary = sh[i]
		shops[i] = {"owned": bool(s.get("owned", false)), "level": int(s.get("level", 1)),
			"employees": int(s.get("employees", 0)), "pending": int(s.get("pending", 0))}
	var dc: Array = d.get("decor", [])
	for i in mini(dc.size(), decor.size()):
		decor[i] = bool(dc[i])
	var st: Dictionary = d.get("stats", {})
	for k in st:
		stats[k] = int(st[k])
	claimed = d.get("claimed", [])
	achieved = d.get("achieved", [])
	music_on = bool(d.get("music", true))
	sfx_on = bool(d.get("sfx", true))
	started = true
	return true


func say(msg: String) -> void:
	toast.emit(msg)


static func fmt(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


# ---------- economy ----------
func add_money(n: int, count_as_earned := true) -> void:
	money += n
	if count_as_earned and n > 0:
		stat_add("earned", n)
	changed.emit()


func spend(n: int) -> bool:
	if money < n:
		Audio.play("error")
		say("Not enough coins")
		return false
	money -= n
	changed.emit()
	return true


func stat_add(key: String, n: int) -> void:
	stats[key] = int(stats.get(key, 0)) + n
	check_progress()


func stat_set(key: String, v: int) -> void:
	stats[key] = v
	check_progress()


func add_xp(n: int) -> void:
	xp += n
	while xp >= 100 * level:
		xp -= 100 * level
		level += 1
		add_money(level * 100, false)
		say("LEVEL UP! Now level %d (+%d coins)" % [level, level * 100])
		Audio.play("level")
		stat_set("level", level)
	changed.emit()


func check_progress() -> void:
	for a in ACHIEVEMENTS:
		if not achieved.has(a.id) and int(stats.get(a.stat, 0)) >= a.target:
			achieved.append(a.id)
			say("Achievement: " + a.text)
			Audio.play("level")
			add_xp(40)


# ---------- shops ----------
func shop_income(i: int) -> int:
	var s: Dictionary = shops[i]
	var base: float = SHOPS[i].income * (1.0 + 0.6 * (s.level - 1)) * (1.0 + 0.3 * s.employees)
	return int(base * (0.75 + satisfaction / 200.0))


func upgrade_cost(i: int) -> int:
	return int(SHOPS[i].cost * 0.6 * pow(2.0, shops[i].level - 1)) + 100


func hire_cost(i: int) -> int:
	return int(SHOPS[i].cost * 0.5) + 150


func employees_total() -> int:
	var n := 0
	for s in shops:
		n += int(s.employees)
	return n


func owned_count() -> int:
	var n := 0
	for s in shops:
		if s.owned:
			n += 1
	return n


func buy_shop(i: int) -> bool:
	if i >= unlocked_slots or shops[i].owned:
		return false
	if not spend(SHOPS[i].cost):
		return false
	shops[i].owned = true
	say("Opened %s!" % SHOPS[i].name)
	add_xp(25)
	stat_set("shops_owned", owned_count())
	return true


func upgrade_shop(i: int) -> bool:
	if not shops[i].owned:
		return false
	if shops[i].level >= MAX_SHOP_LEVEL:
		say("Already max level")
		return false
	if not spend(upgrade_cost(i)):
		return false
	shops[i].level += 1
	add_xp(15)
	stat_add("upgrades", 1)
	return true


func hire(i: int) -> bool:
	if not shops[i].owned:
		return false
	if shops[i].employees >= MAX_STAFF:
		say("Staff is full")
		return false
	if not spend(hire_cost(i)):
		return false
	shops[i].employees += 1
	satisfaction = minf(100.0, satisfaction + 2.0)
	add_xp(10)
	stat_add("hired", 1)
	return true


func buy_decor(i: int) -> bool:
	if decor[i]:
		return false
	if not spend(DECOR[i].cost):
		return false
	decor[i] = true
	add_xp(15)
	var n := 0
	for d in decor:
		if d:
			n += 1
	stat_set("decor", n)
	return true


func expand() -> bool:
	var n := unlocked_slots
	if n >= MAX_SLOTS:
		return false
	if level < n:
		Audio.play("error")
		say("Need level %d to expand" % n)
		return false
	if not spend(EXPAND_COST[n]):
		return false
	unlocked_slots += 1
	add_xp(30)
	say("Mall expanded! New plot unlocked")
	return true


func decor_bonus() -> int:
	var b := 0
	for i in decor.size():
		if decor[i]:
			b += DECOR[i].sat
	return b


func sat_target() -> float:
	return clampf(30.0 + decor_bonus() + employees_total() * 2.0 + level, 0.0, 100.0)


# ---------- missions ----------
func mission_progress(m: Dictionary) -> int:
	return int(stats.get(m.stat, 0))


func claim_mission(id: String) -> bool:
	for m in MISSIONS:
		if m.id == id and not claimed.has(id) and mission_progress(m) >= m.target:
			claimed.append(id)
			add_money(m.reward, false)
			add_xp(30)
			say("Mission reward: +%d coins" % m.reward)
			return true
	return false


func tick(delta: float) -> void:
	satisfaction = move_toward(satisfaction, sat_target(), 0.4 * delta)
	wage_t += delta
	if wage_t >= 60.0:
		wage_t = 0.0
		var w := employees_total() * 8
		if w > 0:
			var pay := mini(w, money)
			money -= pay
			say("Wages paid: %d coins" % pay)
			changed.emit()
	save_t += delta
	if save_t >= 15.0:
		save_t = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# ---------- shared avatar drawing ----------
func draw_avatar(ci: CanvasItem, p: Vector2, color_idx: int, style: int, s: float) -> void:
	var col: Color = AVATAR_COLORS[color_idx % AVATAR_COLORS.size()]
	ci.draw_circle(p + Vector2(0, 8 * s), 14 * s, col)
	ci.draw_circle(p + Vector2(0, -8 * s), 9 * s, Color("ffdfc0"))
	ci.draw_circle(p + Vector2(-3.5 * s, -8 * s), 1.3 * s, Color.BLACK)
	ci.draw_circle(p + Vector2(3.5 * s, -8 * s), 1.3 * s, Color.BLACK)
	match style:
		0:
			ci.draw_rect(Rect2(p.x - 9 * s, p.y - 19 * s, 18 * s, 7 * s), col.darkened(0.35))
			ci.draw_rect(Rect2(p.x - 9 * s, p.y - 13 * s, 18 * s, 2 * s), col.darkened(0.5))
		1:
			ci.draw_colored_polygon(PackedVector2Array([
				p + Vector2(-8, -16) * s, p + Vector2(-8, -26) * s, p + Vector2(-4, -21) * s,
				p + Vector2(0, -27) * s, p + Vector2(4, -21) * s, p + Vector2(8, -26) * s,
				p + Vector2(8, -16) * s]), Color("ffd43b"))
		2:
			var pink := Color("ff8fb3")
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -17) * s, p + Vector2(-9, -23) * s, p + Vector2(-9, -11) * s]), pink)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -17) * s, p + Vector2(9, -11) * s, p + Vector2(9, -23) * s]), pink)
