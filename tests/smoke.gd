extends SceneTree
## Headless gameplay smoke test: godot --headless --path . -s tests/smoke.gd

func _initialize() -> void:
	var gs = root.get_node("GS")
	gs.reset_state("Tester", 1, 2)
	gs.started = true
	gs.money = 100000
	var game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(gs.buy_shop(0)); assert(gs.buy_shop(1))
	assert(gs.upgrade_shop(0)); assert(gs.hire(1)); assert(gs.buy_decor(0))
	gs.level = 10
	assert(gs.expand())
	assert(gs.buy_shop(2))
	for fn in ["_open_shops", "_open_decor", "_open_quests", "_open_menu"]:
		game.call(fn)
		await process_frame
		game._refresh_panel()
		await process_frame
		game._close_panel()
	game._open_shop(0)
	await process_frame
	game._close_panel()
	game._open_arcade()
	game._arcade_hit(); game._arcade_hit()
	game.arcade_time = 0.01
	for i in 600:
		await process_frame
	for i in 400:
		game._process(0.25)
	assert(gs.stats.served > 0)
	gs.save_game()
	var money_before = gs.money
	assert(gs.load_game())
	assert(gs.shops[0].level == 2 and gs.unlocked_slots == 3)
	print("OK served=", gs.stats.served, " earned=", gs.stats.earned, " arcade=", gs.stats.arcade, " money=", money_before, " customers=", game.customers.size())
	quit()
