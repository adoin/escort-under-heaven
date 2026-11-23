extends SceneTree

const Game = preload("res://scenes/game.tscn")
const Saves = preload("res://scripts/checkpoints.gd")
const Expedition = preload("res://scripts/expedition.gd")

var game: Control
var run: Expedition
var directory := ""
var failures := 0


func _initialize() -> void:
	call_deferred("_play")


func check(label: String, outcome: bool) -> void:
	print("%s  %s" % ["PASS" if outcome else "FAIL", label])
	if not outcome:
		failures += 1
		print("      %s · %s · %s · %s" % [run.state.get("area"), run.state.get("pos"), run.state.get("hp"), run.notice])


func button(text: String) -> bool:
	for node in game.page.find_children("*", "Button", true, false):
		if node.text.begins_with(text) and not node.disabled:
			node.pressed.emit()
			return true
	return false


func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)


func click(point: Vector2i) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = game.board.position + Vector2(point * 20) + Vector2(10, 10)
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func walk(points: Array, fight: bool = false) -> bool:
	var area: String = run.state.area
	for goal in points:
		for attempt in range(100):
			if run.state.pos == goal or run.state.area != area:
				break
			if fight:
				if run.state.bleed > 0 and run.state.bag.has("medicine"):
					press(KEY_5)
					continue
				if run.state.thirst >= 65 and run.state.bag.has("water") and not run.threatened():
					run.use_item("water")
					continue
				if run.state.hunger >= 85 and run.state.bag.has("food") and not run.threatened():
					run.use_item("food")
					continue
				if not run.threatened() and run.state.leg and run.state.qi >= 5:
					run.heal_leg()
					continue
				if not run.threatened() and run.state.qi < 8 and run.state.cooldowns.get("breath", 0) == 0:
					press(KEY_3)
					continue
				if fight_near():
					continue
			var route := run.world.path(run.state.pos, goal)
			if route.is_empty():
				return false
			var direction: Vector2i = route[0] - run.state.pos
			var key: Key = {Vector2i.UP: KEY_UP, Vector2i.DOWN: KEY_S, Vector2i.LEFT: KEY_LEFT, Vector2i.RIGHT: KEY_D}[direction]
			var before: int = run.state.beat
			press(key)
			if run.state.beat <= before:
				return false
		if run.state.pos != goal or run.state.area != area:
			return false
	return true


func fight_near() -> bool:
	for enemy in run.state.enemies[run.state.area]:
		var delta: Vector2i = enemy.pos - run.state.pos
		var distance := run.world.distance(enemy.pos, run.state.pos)
		if enemy.hp <= 0 or (delta.x != 0 and delta.y != 0) or not run.world.clear_line(run.state.pos, enemy.pos, true):
			continue
		if distance <= 2 and run.state.qi >= 3 and run.state.cooldowns.get("sword", 0) == 0:
			game.target = enemy.pos
			press(KEY_1)
			return true
		if distance == 1:
			game.target = enemy.pos
			press(KEY_F)
			return true
	return false


func _play() -> void:
	directory = OS.get_cache_dir().path_join("escort-playtest-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	game = Game.instantiate()
	game.run = Expedition.new(directory)
	run = game.run
	root.add_child(game)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(768, 480)
	await process_frame
	check("title and creation", game.sheet_name == "title" and button("新开一局") and button("静心") and game.sheet_name == "hall" and run.max_qi() == 16)
	check("training causes bleeding", button("演练") and run.state.bleed > 0 and run.state.hp < run.max_hp())
	var medicine: int = run.state.bag.medicine
	press(KEY_5)
	check("medicine spends one beat and stops bleeding", run.state.bleed == 0 and run.state.bag.medicine == medicine - 1 and run.state.beat == 2)
	press(KEY_F)
	check("ordinary attack ends training", not run.threatened())
	var next := Vector2i(2, 4)
	click(next)
	check("mouse preview costs no beat", run.state.beat == 3 and game.board.route.size() == 1)
	click(next)
	check("mouse confirmation walks", run.state.pos == next and run.state.beat == 4)
	check("walk to notice board", walk([Vector2i(18, 3)]))
	press(KEY_E)
	check("accept first bounty", game.sheet_name == "board" and button("接榜") and run.state.job == "lost_escort")
	press(KEY_ESCAPE)
	check("walk to inn checkpoint", walk([Vector2i(10, 9)]))
	press(KEY_E)
	check("pre-departure checkpoint", button("投宿") and run.saves.read(Saves.INN) == run.state)
	press(KEY_ESCAPE)
	check("leave town", walk([Vector2i(11, 13)]))
	press(KEY_E)
	check("north road and enter camp", run.state.area == "forest" and walk([Vector2i(2, 1), Vector2i(21, 1), Vector2i(21, 7)], true))
	press(KEY_E)
	check("enter camp", run.state.area == "camp")
	check("camp route and real combat", walk([Vector2i(9, 12), Vector2i(9, 9), Vector2i(10, 5), Vector2i(18, 3)], true) and run.state.bag.get("token", 0) > 0)
	press(KEY_E)
	check("evidence and optional cache discovery", run.state.evidence and run.state.cache_seen and not run.state.cache_claimed)
	check("withdraw without clearing cache", walk([Vector2i(10, 5), Vector2i(9, 9), Vector2i(9, 12), Vector2i(2, 12)], true))
	press(KEY_E)
	check("north road return", run.state.area == "forest" and walk([Vector2i(21, 1), Vector2i(2, 1), Vector2i(2, 7)], true))
	press(KEY_E)
	check("return to inn", run.state.area == "town" and walk([Vector2i(10, 11)]))
	press(KEY_E)
	var silver: int = run.state.coins
	check("submit bounty and receive reward", game.sheet_name == "inn" and button("交榜") and run.state.coins == silver + 105 and run.state.progress.trips == 1 and not run.state.evidence)
	check("defer and reopen sect lead", button("暂且") and run.state.lead == "deferred" and button("打听") and run.state.lead == "recorded")
	check("save at inn after delivery", button("投宿") and run.saves.read(Saves.INN) == run.state)
	var checkpoint := run.state.duplicate(true)
	print("First delivery checkpoint beat: %d" % checkpoint.beat)
	press(KEY_ESCAPE)
	check("reject repeat delivery", not run.deliver() and run.state.progress.trips == 1)
	check("walk to shop", walk([Vector2i(12, 7)]))
	press(KEY_E)
	check("repair and trade", game.sheet_name == "shop" and button("修理") and run.repair_cost() == 0 and button("买入") and button("卖出"))
	press(KEY_ESCAPE)
	press(KEY_K)
	check("allocate attribute and learn another weapon", button("力量") and run.state.stats.strength == 1 and button("习得") and "saber" in run.state.learned)
	press(KEY_ESCAPE)
	var session := run.state.duplicate(true)
	game.show_title()
	check("reload action snapshot", button("继续上次") and run.state == session)
	check("second expedition without mandatory sect chain", walk([Vector2i(18, 3)]))
	press(KEY_E)
	check("accept follow-up", button("接榜") and run.state.job == "route_survey")
	press(KEY_ESCAPE)
	check("depart a second time", walk([Vector2i(11, 13)]))
	press(KEY_E)
	check("second departure enters forest", run.state.area == "forest")
	var reset := Expedition.new(directory)
	check("independent reload preserves region, enemies, inventory and RNG", reset.load_slot(Saves.SESSION) and reset.state == run.state)
	check("short southern trail reaches ambush lane", walk([Vector2i(2, 9), Vector2i(7, 9), Vector2i(10, 9)], true) and run.state.area == "forest")
	await _focused_checks(checkpoint)
	for slot in [Saves.INN, Saves.SESSION]:
		run.saves.discard(slot)
	DirAccess.remove_absolute(directory)
	quit(0 if failures == 0 else 1)


func _focused_checks(checkpoint: Dictionary) -> void:
	game.show_title()
	check("title loads inn checkpoint", button("读取客栈") and run.state == checkpoint)
	press(KEY_G)
	check("ending panel opens and insufficient progress is rejected", game.sheet_name == "endings" and not run.confirm_ending("jinyiwei"))
	press(KEY_ESCAPE)
	var progress: Dictionary = run.state.progress
	progress.credit = 85
	progress.renown = 85
	progress.guild = 80
	progress.cases = ["case_1", "case_2", "case_3"]
	progress.nominations = ["jinyiwei", "dongchang"]
	progress.milestones = ["jinyiwei", "dongchang", "top_wealth", "assembly"]
	progress.routes = ["route_1", "route_2", "route_3"]
	progress.sponsors = ["sect_1", "sect_2", "sect_3", "sect_4"]
	progress.equity = 1000000
	progress.debts = run.net_worth() - 999999
	check("net asset threshold accounts for debt", not run.confirm_ending("wealth"))
	progress.debts -= 1
	check("wealth coexists with office, rival offices are mutually exclusive", run.confirm_ending("jinyiwei") and run.confirm_ending("wealth") and not run.confirm_ending("dongchang") and not run.confirm_ending("alliance"))
	check("resign and switch offices while retaining history", run.resign() and run.confirm_ending("alliance") and run.resign() and run.confirm_ending("dongchang") and progress.history.size() == 4)
	check("reload checkpoint before combat fixtures", run.load_slot(Saves.INN))
	var state := run.state
	state.area = "camp"
	state.pos = Vector2i(13, 2)
	state.enemies.camp = [run._make_enemy("test_chief", "chief", Vector2i(14, 2), [])]
	var chief: Dictionary = state.enemies.camp[0]
	run.wait()
	check("chief first beat telegraphs without damage", chief.charge and state.hp == run.max_hp())
	run.move(Vector2i(13, 3))
	check("moving off marked tile cancels hit", not chief.charge and state.hp == run.max_hp())
	run.move(Vector2i(13, 2))
	run.attack(chief.pos, true, true)
	check("infused sword hit interrupts second beat", not chief.charge and chief.hp < 24 and state.qi == run.max_qi() - 5 and state.hp == run.max_hp())
	run.breathe()
	check("breathe recovers qi and grants a temporary buff", state.qi == run.max_qi() - 1 and state.stance == 1)
	check("learn saber after returning to town", run.load_slot(Saves.INN) and run.learn("saber") and run.swap())
	state = run.state
	state.area = "camp"
	state.pos = Vector2i(13, 2)
	state.enemies.camp = [run._make_enemy("test_chief", "chief", Vector2i(14, 2), [])]
	chief = state.enemies.camp[0]
	run.wait()
	check("saber pressure breaks chief charge", chief.charge and run.attack(chief.pos, true) and not chief.charge and chief.hp <= 10 and state.hp == run.max_hp())
	run.state.face = Vector2i.RIGHT
	state.enemies.camp = [run._make_enemy("test_sentry", "sentry", Vector2i(14, 2), [])]
	check("front guard reduces hit and prevents wound", run.guard(Vector2i.RIGHT) and state.bleed == 0 and state.hp == run.max_hp() - 2)
	state.pos = Vector2i(19, 12)
	state.enemies.camp = [run._make_enemy("test_raider", "raider", Vector2i(20, 12), [])]
	run.wait()
	var before: int = state.beat
	check("leg injury disables leap without spending time", state.leg and not run.move(Vector2i(17, 12), true) and state.beat == before)
	check("ordinary retreat remains available", run.move(Vector2i(18, 12)) and state.pos == Vector2i(18, 12))
	state.enemies.camp.clear()
	check("treat leg safely with qi, then leap", run.heal_leg() and not state.leg and run.move(Vector2i(16, 12), true))
	state.hp = 1
	state.bleed = 2
	press(KEY_PERIOD)
	check("death rolls back to inn and replaces stale session", run.state == checkpoint and run.saves.read(Saves.SESSION) == checkpoint and game.sheet_name == "death")
	if DisplayServer.get_name() != "headless":
		game.close_sheet()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check("rendered viewport readback", image != null and image.save_png("/tmp/escort-playtest.png") == OK)
