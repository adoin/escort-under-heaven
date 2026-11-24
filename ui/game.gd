extends Control

const Expedition = preload("res://scripts/expedition.gd")
const BoardView = preload("res://ui/board_view.gd")
const Scores = preload("res://scripts/progression.gd")
const Saves = preload("res://scripts/checkpoints.gd")
const World = preload("res://scripts/world.gd")
const NONE = Vector2i(-1, -1)
const GOLD = Color("e6c58b")
const MUTED = Color("b0b9ae")

var run := Expedition.new()
var play: Control
var board: BoardView
var heading: Label
var district: Label
var hint: Label
var vital: ProgressBar
var qi: ProgressBar
var supplies: Label
var action_buttons: Dictionary = {}
var status: Label
var combat_log: Label
var message: Label
var strike: Button
var sheet: PanelContainer
var page: VBoxContainer
var sheet_name := ""
var target := NONE
var aim := ""
var route_timer: Timer
var tune: AudioStreamPlayer
var last_beat := 0


func _ready() -> void:
	theme = _make_theme()
	var backdrop := ColorRect.new()
	backdrop.color = Color("151e20")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	route_timer = Timer.new()
	route_timer.wait_time = 0.075
	route_timer.timeout.connect(_walk_route)
	add_child(route_timer)
	tune = AudioStreamPlayer.new()
	tune.volume_db = -22.0
	add_child(tune)
	show_title()


func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	result.default_font_size = 13
	result.set_color("font_color", "Label", Color("ebe4d6"))
	result.set_stylebox("panel", "PanelContainer", _box("202b2d", "56605a", 10))
	var colors := {"normal":"2d393a","hover":"3a4947","pressed":"48554b","disabled":"242d2e"}
	for item in colors:
		result.set_stylebox(item, "Button", _box(colors[item], "52615d", 4))
	return result


func _box(fill: String, border: String, padding: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(fill)
	result.border_color = Color(border)
	result.set_border_width_all(1)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_content_margin(side, padding)
	return result


func _label(parent: Node, text: String, font_size: int = 13, tint: Color = Color("ebe4d6")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", tint)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size.y = 25
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _section(name: String, title: String, closable: bool = true) -> void:
	close_sheet()
	if is_instance_valid(board):
		_clear_route()
	sheet_name = name
	sheet = PanelContainer.new()
	sheet.position = Vector2(128, 34)
	sheet.size = Vector2(512, 412)
	add_child(sheet)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	sheet.add_child(body)
	var top := HBoxContainer.new()
	body.add_child(top)
	var label := _label(top, title, 23, GOLD)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if closable:
		var close := _button(top, "关闭  Esc", close_sheet)
		close.size_flags_horizontal = Control.SIZE_SHRINK_END
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)
	scroll.add_child(page)


func close_sheet() -> void:
	if is_instance_valid(sheet):
		remove_child(sheet)
		sheet.queue_free()
	sheet = null
	sheet_name = ""


func show_title() -> void:
	if is_instance_valid(play):
		_clear_route()
		remove_child(play)
		play.queue_free()
		play = null
		board = null
	_section("title", "镖行天下", false)
	_label(page, "ESCORT UNDER HEAVEN", 17, GOLD)
	_label(page, "长风镖局在青水县给你留了一席之地。眼下有一趟失镖，等人查个明白。", 15, MUTED)
	_button(page, "新开一局", show_creation)
	_button(page, "继续上次行动", func(): _load(Saves.SESSION)).disabled = run.saves.read(Saves.SESSION).is_empty()
	_button(page, "读取客栈检查点", func(): _load(Saves.INN)).disabled = run.saves.read(Saves.INN).is_empty()
	_button(page, "退出游戏", func(): get_tree().quit())
	if not run.notice.is_empty():
		_label(page, run.notice, 13, GOLD)


func show_creation() -> void:
	_section("create", "初入江湖", false)
	_label(page, "选择一项天赋。兵器与武学可以自由改练。", 15, MUTED)
	for id in run.campaign.talents:
		var talent: Dictionary = run.campaign.talents[id]
		_button(page, "%s · %s" % [talent.name, talent.description], func():
			run.create(id)
			_start_play()
			show_page("hall"))
	if not run.saves.read(Saves.SESSION).is_empty() or not run.saves.read(Saves.INN).is_empty():
		_label(page, "选定天赋后覆盖现有存档。", 13, GOLD)
	_button(page, "返回标题", show_title)


func _load(slot: String) -> void:
	if run.load_slot(slot):
		_start_play()
	else:
		show_title()


func _start_play() -> void:
	close_sheet()
	target = NONE
	aim = ""
	last_beat = run.state.beat
	play = Control.new()
	play.size = Vector2(768, 480)
	add_child(play)
	var map_header := VBoxContainer.new()
	map_header.position = Vector2(16, 11)
	map_header.size.x = 480
	play.add_child(map_header)
	heading = _label(map_header, "", 21, GOLD)
	district = _label(map_header, "", 13, MUTED)
	board = BoardView.new()
	board.position = Vector2(16, 72)
	board.size = Vector2(480, 320)
	board.run = run
	board.cell_selected.connect(select_cell)
	play.add_child(board)
	var footer := VBoxContainer.new()
	footer.position = Vector2(16, 397)
	footer.size.x = 480
	play.add_child(footer)
	hint = _label(footer, "", 13, MUTED)
	message = _label(footer, "", 13, GOLD)
	var sidebar := PanelContainer.new()
	sidebar.position = Vector2(510, 12)
	sidebar.size = Vector2(246, 452)
	play.add_child(sidebar)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)
	sidebar.add_child(panel)
	action_buttons.clear()
	vital = _meter(panel, "c96b60")
	qi = _meter(panel, "56aaa5")
	supplies = _label(panel, "", 12, MUTED)
	status = _label(panel, "", 13, GOLD)
	_pair(panel, "交互 E", interact_near, "等待 .", func(): _act(run.wait))
	strike = _pair(panel, "普攻 F", func(): _strike(false), "招式 1", func(): _strike(true))
	_pair(panel, "格挡 2", _guard, "调息 3", func(): _act(run.breathe))
	_pair(panel, "跃步 4", _aim_leap, "金创药 5", func(): _act(run.use_item.bind("medicine")))
	_pair(panel, "换兵 Q", func(): _act(run.swap), "轻步 C", func(): _act(run.quiet))
	_pair(panel, "行囊 I", func(): show_page("bag"), "武学 K", func(): show_page("skills"))
	_pair(panel, "榜单 J", func(): show_page("journal"), "江湖 G", func(): show_page("endings"))
	_pair(panel, "操作 ?", func(): show_page("help"), "菜单 Esc", func(): show_page("pause"))
	var log_scroll := ScrollContainer.new()
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(log_scroll)
	combat_log = _label(log_scroll, "", 12, MUTED)
	combat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh()


func _pair(parent: Node, left: String, left_callback: Callable, right: String, right_callback: Callable) -> Button:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_action_button(row, left, left_callback).size_flags_stretch_ratio = 1
	return _action_button(row, right, right_callback)



# Small, code-native pixel masks: no runtime effects library or font glyph icons.
const ACTION_PIXELS = [
	["0010100", "0010100", "1010110", "1111111", "0111110", "0011100", "0011100"],
	["0111110", "0100010", "0010100", "0001000", "0010100", "0100010", "0111110"],
	["0000011", "0000111", "0001110", "1011100", "0111000", "0110000", "1001000"],
	["0001000", "1001001", "0101010", "0011100", "1111111", "0011100", "0101010"],
	["0111110", "0111110", "0110110", "0110110", "0011100", "0011100", "0001000"],
	["0001000", "0010100", "0100010", "0101010", "0100010", "0011100", "0001000"],
	["0000110", "0001110", "0011000", "0110000", "1100111", "0000010", "0000100"],
	["0011100", "0001000", "0111110", "0110110", "0100010", "0110110", "0111110"],
	["0100010", "1110010", "0100010", "0100111", "0100010", "0011100", "0001000"],
	["0011000", "0011000", "0001000", "0001100", "0011110", "0111000", "1100000"],
	["0011100", "0100010", "1111111", "1000001", "1011101", "1000001", "1111111"],
	["1110111", "1010101", "1010101", "1010101", "1010101", "1111111", "0001000"],
	["1111111", "1000001", "1011101", "1000001", "1011101", "1000001", "1111111"],
	["0011100", "0111110", "1101011", "1111111", "1101011", "0111110", "0011100"],
	["0011100", "0100010", "0000010", "0001100", "0001000", "0000000", "0001000"],
	["1111111", "1000001", "1011101", "1000001", "1011101", "1000001", "1111111"],
]


func _action_box(fill: String, border: String, width: int = 1) -> StyleBoxFlat:
	var style := _box(fill, border, 4)
	style.set_border_width_all(width)
	style.border_width_bottom = 3
	return style


func _action_button(parent: Node, text: String, callback: Callable) -> Button:
	var index := action_buttons.size()
	var button := _button(parent, text, callback)
	button.custom_minimum_size = Vector2(109, 30)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_constant_override("h_separation", 5)
	button.add_theme_color_override("font_color", Color("eee5cf"))
	button.add_theme_color_override("font_hover_color", Color("fff0c4"))
	button.add_theme_color_override("font_pressed_color", Color("ffffff"))
	button.add_theme_stylebox_override("normal", _action_box("263638", "526863"))
	button.add_theme_stylebox_override("hover", _action_box("3b504b", "e6c58b"))
	var down := _action_box("17282c", "77c6bd")
	down.border_width_top = 3
	down.border_width_bottom = 1
	button.add_theme_stylebox_override("pressed", down)
	var pixels := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	for y in range(7):
		for x in range(7):
			if ACTION_PIXELS[index][y][x] == "1":
				pixels.fill_rect(Rect2i(x * 2, y * 2, 2, 2), Color("e6c58b"))
	button.icon = ImageTexture.create_from_image(pixels)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.tooltip_text = text
	action_buttons[text.get_slice(" ", 0)] = button
	return button


func _meter(parent: Node, tint: String) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.custom_minimum_size.y = 22
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background", _box("101c21", "526863", 0))
	var fill := _box(tint, tint, 0)
	fill.border_color = Color(tint).lightened(0.25)
	meter.add_theme_stylebox_override("fill", fill)
	parent.add_child(meter)
	var label := Label.new()
	label.name = "Value"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("101820"))
	label.add_theme_constant_override("outline_size", 4)
	meter.add_child(label)
	return meter


func _update_meter(meter: ProgressBar, title: String, value: int, maximum: int) -> void:
	meter.max_value = maximum
	meter.value = value
	meter.get_node("Value").text = "%s  %d / %d" % [title, value, maximum]


func _refresh() -> void:
	var state := run.state
	heading.text = "%s　·　%s" % [run.world.zone().name, Scores.phase(state.progress)]
	var job: String = "尚未接榜" if state.completed.is_empty() else "榜单已交付"
	if not state.job.is_empty():
		job = run.campaign.jobs[state.job].name + (" · 回客栈交榜" if run.can_deliver() else " · 进行中")
	district.text = "第 %d 拍　%s" % [state.beat, job]
	hint.text = "选跃步落点，或按方向键跃两格。Esc 取消。" if aim == "leap" else run.world.zone().hint
	message.text = run.notice
	_update_meter(vital, "生命", state.hp, run.max_hp())
	_update_meter(qi, "内力", state.qi, run.max_qi())
	supplies.text = "饥 %d　渴 %d　现银 %d 两" % [state.hunger, state.thirst, state.coins]
	status.text = "%s%s%s" % ["流血 %d 拍  " % state.bleed if state.bleed else "", "腿伤  " if state.leg else "", "交战" if run.threatened() else ("轻步" if state.quiet else "状态稳定" if state.bleed == 0 and not state.leg else "")]
	strike.text = "%s 1" % run.martial.skills[state.weapon].name
	for key in action_buttons:
		var selected: bool = (key == "跃步" and aim == "leap") or (key == "轻步" and state.quiet)
		action_buttons[key].add_theme_stylebox_override("normal", _action_box("34473e", "e6c58b", 2) if selected else _action_box("263638", "526863"))
	combat_log.text = "\n".join(run.report.slice(-5).duplicate().map(func(line): return "· " + line))
	board.selected = target
	board.queue_redraw()


func _act(command: Callable) -> void:
	var previous_deaths := run.deaths
	command.call()
	if last_beat != run.state.beat:
		_play_tone(162.0 if run.threatened() else 245.0)
		last_beat = run.state.beat
	_refresh()
	if run.deaths > previous_deaths:
		_clear_route()
		show_page("death")


func _play_tone(frequency: float) -> void:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 11025
	var samples := PackedByteArray()
	samples.resize(720)
	for index in range(360):
		var envelope := 1.0 - index / 360.0
		var value := int(sin(TAU * frequency * index / wave.mix_rate) * envelope * 9000.0)
		samples.encode_s16(index * 2, value)
	wave.data = samples
	tune.stream = wave
	tune.play()


func _clear_route() -> void:
	route_timer.stop()
	board.route.clear()
	board.queue_redraw()


func select_cell(point: Vector2i) -> void:
	if sheet != null:
		return
	if aim == "leap":
		_clear_route()
		aim = ""
		_act(run.move.bind(point, true))
		return
	if not run.world.enemy_at(point).is_empty():
		_clear_route()
		if target == point:
			_strike(false)
		else:
			target = point
			var enemy := run.world.enemy_at(point)
			var skill: Dictionary = run.martial.skills[run.state.weapon]
			var preview: String = "普攻可达" if run.in_attack_range(point, 1) else "普攻不可达"
			if run.in_attack_range(point, int(skill.range)):
				preview += " · %s需 %d 内力 / 1 拍" % [skill.name, skill.cost] if run.skill_ready(run.state.weapon) else " · " + run.notice
			else:
				preview += " · 招式超距或受遮挡"
			run.notice = "%s · 生命 %d · 警觉 %d/100\n%s" % [run.enemy_name(enemy), enemy.hp, enemy.alert, preview]
			_refresh()
		return
	if point == target and not run.world.site(point).is_empty() and run.world.distance(run.state.pos, point) <= 1:
		_interact(point)
		return
	if point == target and not board.route.is_empty():
		if not run.threatened():
			route_timer.start()
		_walk_route()
		return
	_clear_route()
	target = point
	if run.world.walkable(point):
		board.route = run.world.path(run.state.pos, point)
	var site := run.world.site(point)
	if run.threatened() and board.route.size() > 1:
		board.route.clear()
		run.notice = "交战中只能逐格确认移动。"
	elif not site.is_empty() and run.world.distance(run.state.pos, point) <= 1:
		run.notice = "%s · 再点交互。" % site.name
	elif not board.route.is_empty():
		run.notice = "预计 %d 拍。再点同格移动，遇敌或危险会停下。" % board.route.size()
	else:
		run.notice = "此格无可执行动作。"
	_refresh()


func _walk_route() -> void:
	if board.route.is_empty():
		_clear_route()
		return
	var was_threatened := run.threatened()
	var bleed: int = run.state.bleed
	var health: int = run.state.hp
	var step: Vector2i = board.route.pop_front()
	_act(run.move.bind(step))
	if was_threatened or run.threatened() or run.state.bleed > bleed or run.state.hp < health or run.state.pos != step or board.route.is_empty():
		_clear_route()


func _nearest_enemy() -> Vector2i:
	var best := NONE
	var minimum := 100
	for enemy in run.state.enemies[run.state.area]:
		var distance := run.world.distance(run.state.pos, enemy.pos)
		if enemy.hp > 0 and distance < minimum:
			minimum = distance
			best = enemy.pos
	return best


func _strike(special: bool, channel: bool = false) -> void:
	_clear_route()
	var destination := target if not run.world.enemy_at(target).is_empty() else _nearest_enemy()
	_act(run.attack.bind(destination, special, channel))


func _guard() -> void:
	var opponent := target if not run.world.enemy_at(target).is_empty() else _nearest_enemy()
	_act(run.guard.bind(run.state.face if opponent == NONE else opponent - run.state.pos))


func _aim_leap() -> void:
	_clear_route()
	if not run.state.leg and run.skill_ready("leap"):
		aim = "leap" if aim.is_empty() else ""
	elif run.state.leg:
		run.notice = "腿伤限制跃步。仍可步行。"
	_refresh()


func interact_near() -> void:
	var point: Vector2i = run.state.pos
	if run.world.distance(point, target) <= 1 and not run.world.site(target).is_empty():
		_interact(target)
		return
	for direction in [Vector2i.ZERO, run.state.face] + World.DIRECTIONS:
		if not run.world.site(point + direction).is_empty():
			_interact(point + direction)
			return
	run.notice = "靠近地图上的字母标记，再按 E。"
	_refresh()


func _interact(point: Vector2i) -> void:
	_clear_route()
	var previous_deaths := run.deaths
	var previous_area: String = run.state.area
	var service := run.interact(point)
	if previous_area != run.state.area:
		target = NONE
	_refresh()
	if run.deaths > previous_deaths:
		show_page("death")
	elif service != "":
		show_page(service)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE:
		if event.echo: return
		match sheet_name:
			"title": return
			"create": show_title()
			"":
				if aim != "" or not route_timer.is_stopped():
					aim = ""
					_clear_route()
					_refresh()
				else: show_page("pause")
			_: close_sheet()
		get_viewport().set_input_as_handled()
		return
	if sheet != null or not is_instance_valid(play):
		return
	_clear_route()
	var direction := Vector2i.ZERO
	match event.physical_keycode:
		KEY_W, KEY_UP: direction = Vector2i.UP
		KEY_S, KEY_DOWN: direction = Vector2i.DOWN
		KEY_A, KEY_LEFT: direction = Vector2i.LEFT
		KEY_D, KEY_RIGHT: direction = Vector2i.RIGHT
	if direction != Vector2i.ZERO:
		if event.echo:
			return
		var distance := 2 if aim == "leap" else 1
		aim = ""
		target = NONE
		_act(run.move.bind(run.state.pos + direction * distance, distance == 2))
	elif not event.echo:
		match event.physical_keycode:
			KEY_E: interact_near()
			KEY_F: _strike(false)
			KEY_1: _strike(true, event.shift_pressed)
			KEY_2: _guard()
			KEY_3: _act(run.breathe)
			KEY_4: _aim_leap()
			KEY_5: _act(run.use_item.bind("medicine"))
			KEY_Q: _act(run.swap)
			KEY_C: _act(run.quiet)
			KEY_PERIOD, KEY_SPACE: _act(run.wait)
			KEY_I: show_page("bag")
			KEY_K: show_page("skills")
			KEY_J: show_page("journal")
			KEY_G: show_page("endings")
			KEY_SLASH: show_page("help")
	get_viewport().set_input_as_handled()


func _option(text: String, command: Callable) -> Button:
	return _button(page, text, func():
		var current := sheet_name
		_act(command)
		if sheet_name == current:
			show_page(current))


func show_page(name: String) -> void:
	var titles := {"hall":"长风镖局", "board":"县城榜亭", "inn":"归雁客栈", "shop":"陆记商铺",
		"bag":"行囊与装备", "skills":"武学与属性", "journal":"榜单与见闻", "endings":"江湖进度",
		"resign":"辞任", "help":"操作与地形", "pause":"暂停", "death":"远征失利", "forms":"十九大类"}
	_section(name, titles[name])
	var state := run.state
	match name:
		"hall":
			_label(page, "‘身手可以慢慢练，镖货却不能丢。’镖头将备用兵刃交给你，指了指城东榜亭。", 15)
			_label(page, "东边 B 接榜，南边 I 投宿，G 出城。建议先试招，再去客栈留个检查点。")
			_button(page, "演练 · 流血与止血", func():
				close_sheet()
				_act(run.train)).disabled = state.training
			_button(page, "告别镖头", close_sheet)
		"board":
			var job := run.next_job()
			if job != "":
				var spec: Dictionary = run.campaign.jobs[job]
				_label(page, "%s　赏银 %d 两" % [spec.name, spec.pay], 16, GOLD)
				_label(page, spec.description)
				_option("接榜", run.accept_job.bind(job))
			else:
				_label(page, "你已经接榜。" if state.job != "" else "目前的榜单均已交付。")
		"inn":
			_label(page, "投宿恢复生命与内力，治疗腿伤并覆盖客栈检查点。费用由镖局担保。")
			_option("投宿并存档", run.rest)
			_option("交榜领赏", run.deliver).disabled = not run.can_deliver()
			if state.lead in ["available", "deferred"]:
				_label(page, "掌柜认出了账册上的剑穗纹样。", 14, GOLD)
				_option("打听青岚剑社", run.follow_lead.bind(true))
				_option("暂且搁置", run.follow_lead.bind(false)).disabled = state.lead == "deferred"
		"shop":
			_label(page, "现银 %d 两　行囊 %d/%d 格" % [state.coins, run.bag_slots(), Expedition.SLOTS], 15, GOLD)
			var repair_price := run.repair_cost()
			_option("修理兵刃和布衣 · %d 两" % repair_price, run.repair).disabled = repair_price == 0
			for id in run.campaign.items:
				var item: Dictionary = run.campaign.items[id]
				var count := int(state.bag.get(id, 0))
				if int(item.buy) > 0 or count > 0:
					_label(page, "%s · 持有 %d" % [item.name, count])
				if int(item.buy) > 0:
					_option("买入 · %d 两" % item.buy, run.trade.bind(id, true)).disabled = state.coins < int(item.buy)
				if count > 0:
					_option("卖出 · %d 两" % item.sell, run.trade.bind(id, false))
			for route in run.campaign.trade_routes:
				_label(page, "商路预留 · %s → %s，预计收货价 %d 两。" % [route.origin, route.destination, route.destination_price], 13, MUTED)
		"bag":
			_label(page, "行囊 %d/%d 格　证物 %s" % [run.bag_slots(), Expedition.SLOTS, "独立保管" if state.evidence else "无"], 15, GOLD)
			for id in state.durability:
				_label(page, "%s　耐久 %d/40%s" % [run.campaign.gear[id].name, state.durability[id], "　持用中" if state.weapon == id else ""])
			_button(page, "换兵器 · 1 拍", func(): _close_and_act(run.swap))
			for id in state.bag:
				var item_name: String = run.campaign.items[id].name
				if id in ["medicine", "food", "water"]:
					_button(page, "用 %s（余 %d）· 1 拍" % [item_name, state.bag[id]], func(): _close_and_act(run.use_item.bind(id)))
				else:
					_label(page, "%s × %d" % [item_name, state.bag[id]])
			_button(page, "运功疗伤 · 5 内力 / 1 拍", func(): _close_and_act(run.heal_leg)).disabled = not state.leg
		"skills":
			_label(page, "境界 %d　阅历 %d/4　属性点 %d　武学点 %d" % [state.level, state.xp, state.points, state.skill_points], 15, GOLD)
			var stats := {"strength":"力量 · 提高伤害", "body":"体魄 · 提高生命上限", "spirit":"意志 · 提高内力上限", "agility":"敏捷 · 提高闪避"}
			for id in stats:
				_option("%s　%d　＋" % [stats[id], state.stats[id]], run.raise_stat.bind(id)).disabled = state.points == 0 or state.area != "town"
			var mobility := run.mobility()
			_label(page, "轻功 · %d 行动/拍　闪避 %d%%　跳高 %d　警觉上限 %d" % [mobility.actions_per_beat, mobility.evasion, mobility.jump_height, mobility.alert_limit])
			for id in run.martial.skills:
				var skill: Dictionary = run.martial.skills[id]
				_label(page, "%s · %s · %d 内力 / %d 拍 / 冷却 %d" % [skill.kind, skill.name, skill.cost, skill.beats, skill.cooldown], 14, GOLD)
				_label(page, skill.description)
				if id not in state.learned:
					_option("习得 · 1 武学点", run.learn.bind(id)).disabled = state.skill_points == 0 or state.area != "town"
			_button(page, "使用注劲招式 · 选中目标后施展", func():
				close_sheet()
				_strike(true, true))
			_button(page, "查看十九大类", func(): show_page("forms"))
		"forms":
			for form in run.martial.forms:
				_label(page, "%s · %s / %s　%s" % [form.name, form.attack, form.defense, "待实装" if form.status == "placeholder" else "可习得"])
			_button(page, "返回武学", func(): show_page("skills"))
		"journal":
			if state.job != "":
				_label(page, run.campaign.jobs[state.job].description)
				_label(page, "目标已达成，回归雁客栈交付。" if run.can_deliver() else "查访中。", 14, GOLD)
			else:
				_label(page, "前往县城榜亭查看可接榜单。")
			for id in state.completed:
				_label(page, "已交 · %s" % run.campaign.jobs[id].name)
			if state.cache_seen:
				_label(page, "西北藏货间 · %s" % ("已搜查" if state.cache_claimed else "发现位置，可选择绕行。"))
			if state.lead != "":
				_label(page, "青岚剑社 · %s" % ("柳津渡有接应人，后续地点预留。" if state.lead == "recorded" else "可向归雁客栈掌柜打听。"))
		"endings":
			var progress: Dictionary = state.progress
			_label(page, "%s　结算 %d 趟" % [Scores.phase(progress), progress.trips], 15, GOLD)
			_label(page, "官面信用 %d/85　武林声望 %d/85　净资产 %d/1000000 两" % [progress.credit, progress.renown, run.net_worth()])
			_label(page, "商帮信用 %d/80　现职 %s" % [progress.guild, Scores.TITLES.get(progress.office, "无")])
			for id in Scores.TITLES:
				var missing := Scores.requirements(id, progress, run.net_worth())
				var active: bool = progress.office == id or (id == "wealth" and id in progress.history)
				_label(page, Scores.TITLES[id], 14, GOLD)
				_label(page, "尚缺 %s" % missing if not missing.is_empty() else ("已确认。" if active else "符合确认条件。"))
				_option("确认结局", run.confirm_ending.bind(id)).disabled = not missing.is_empty() or active
			for id in progress.history:
				_label(page, "曾达成 · %s" % Scores.TITLES[id])
			if progress.office != "":
				_button(page, "辞去当前职务…", func(): show_page("resign"))
		"resign":
			_label(page, "将辞去%s。历史结局保留，再次任职须符合当时条件。" % Scores.TITLES[state.progress.office])
			_button(page, "确认辞任", func():
				_act(run.resign)
				show_page("endings"))
		"help":
			_label(page, "WASD 或方向键逐格走。点地格预览，再点确认。交战只走一格。靠近字母标记后按 E，或再点一次交互。")
			_label(page, "单击敌人选中。F 普攻、1 招式、Shift+1 注劲，未选中时试击最近敌人。2 面向敌人架招，3 调息，4 选跃步落点，5 止血。")
			_label(page, "Q 换兵，C 轻步，句号或空格等待。行囊中可饮水、吃干粮、运功疗伤。无效动作不计拍。")
			_label(page, "浅色缺口是门洞，深色砖是墙，草丛可降低警觉。红格是下一拍重击，及时移开或打断。")
			_label(page, "地图标记 H 镖局、B 榜亭、S 商铺、I 客栈、G 前往下一区、T 折返、E 证物、C 藏货间。")
		"pause":
			_button(page, "继续行走", close_sheet)
			_button(page, "返回标题", show_title)
			_button(page, "退出游戏", func(): get_tree().quit())
		"death":
			_label(page, run.notice, 14, GOLD)
			_label(page, run.death_report)
			_button(page, "继续", close_sheet)
	if name not in ["death", "pause", "help"] and not run.notice.is_empty():
		_label(page, run.notice, 13, GOLD)


func _close_and_act(command: Callable) -> void:
	close_sheet()
	_act(command)
