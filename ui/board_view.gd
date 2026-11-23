extends Control

signal cell_selected(cell: Vector2i)

const CELL = 20
const World = preload("res://scripts/world.gd")
const Expedition = preload("res://scripts/expedition.gd")
const ART_DIR = "res://assets/placeholder/"

var run: Expedition
var route: Array[Vector2i] = []
var selected := Vector2i(-1, -1)
var palette: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART_DIR + "palette.json"))
var textures: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for id in palette:
		var path: String = ART_DIR + id + ".png"
		if ResourceLoader.exists(path, "Texture2D"):
			textures[id] = load(path)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cell_selected.emit(Vector2i((event.position / CELL).floor()))
		accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	if run == null or run.state.is_empty():
		return ""
	var point := Vector2i((at_position / CELL).floor())
	var enemy := run.world.enemy_at(point)
	if not enemy.is_empty():
		return "%s  生命 %d  警觉 %d/100" % [run.enemy_name(enemy), enemy.hp, enemy.alert]
	var site := run.world.site(point)
	if not site.is_empty():
		return site.name
	return {"#":"墙 · 阻挡通行和直线招式", "+":"门洞 · 适合限制接敌方向", "^":"草丛 · 降低巡哨警觉", "=":"低障 · 需更高跳跃高度"}.get(run.world.cell(point), "")


func _draw() -> void:
	if run == null or run.state.is_empty():
		return
	var state := run.state
	var rows: Array = run.world.zone().rows
	for row in range(rows.size()):
		for col in range(rows[row].length()):
			_draw_cell(Vector2i(col, row), rows[row][col])
	for cell in route:
		draw_rect(Rect2(Vector2(cell * CELL) + Vector2(8, 8), Vector2(4, 4)), Color("bce2cd"))
	if selected.x >= 0:
		draw_rect(Rect2(selected * CELL, Vector2(CELL, CELL)).grow(-1), Color("ead2a0"), false, 2)
	for enemy in state.enemies[state.area]:
		if enemy.hp <= 0:
			continue
		if enemy.charge:
			var warning := Rect2(enemy.target * CELL, Vector2(CELL, CELL))
			draw_rect(warning, Color(0.95, 0.25, 0.22, 0.55))
			draw_rect(warning.grow(-1), Color("ff8e72"), false, 2)
		_draw_actor(enemy.pos, enemy.face, enemy.kind)
		var origin := Vector2(enemy.pos * CELL) + Vector2(3, 17)
		var ratio := float(enemy.hp) / float(run.campaign.enemies[enemy.kind].hp)
		draw_rect(Rect2(origin, Vector2(14, 2)), Color("191e20"))
		draw_rect(Rect2(origin, Vector2(floorf(14 * ratio), 2)), Color("f9ae91"))
		if enemy.alert > 0:
			var alert_color := Color("ff826d") if enemy.aggro else Color("f5cc7c")
			draw_rect(Rect2(origin - Vector2(-11, 14), Vector2(3, 4)), alert_color)
	_draw_actor(state.pos, state.face, "player")


func _draw_cell(point: Vector2i, symbol: String) -> void:
	var origin := Vector2(point * CELL)
	var box := Rect2(origin, Vector2(CELL, CELL))
	var id: String = {"#":"wall", "^":"brush", "=":"low", "+":"door"}.get(symbol, "floor")
	if textures.has(id):
		draw_texture_rect(textures[id], box, false)
	else:
		var base := Color(palette[id])
		if id == "floor" and run.state.area == "town":
			base = Color("45413a")
		if id == "floor" and run.state.area == "camp":
			base = Color("31353c")
		var pattern := posmod(point.x * 13 + point.y * 7, 5)
		draw_rect(box, base.darkened(pattern * 0.025))
		if symbol == "#":
			draw_rect(Rect2(origin + Vector2(0, 2), Vector2(20, 6)), Color(palette.brick))
			draw_rect(Rect2(origin + Vector2(1 + pattern * 3, 3), Vector2(2, 5)), base)
		elif symbol == "^":
			draw_rect(Rect2(origin + Vector2(4 + pattern, 5), Vector2(2, 8)), base.lightened(0.2))
			draw_rect(Rect2(origin + Vector2(10 + pattern, 9), Vector2(3, 5)), base.lightened(0.13))
		elif symbol == "+":
			draw_rect(Rect2(origin + Vector2(3, 1), Vector2(14, 3)), base.lightened(0.22))
		draw_rect(box, Color(0, 0, 0, 0.14), false)
	if not run.world.site(point).is_empty():
		if textures.has("site"):
			draw_texture_rect(textures.site, box, false)
		else:
			var marker := Color(palette.site)
			draw_rect(Rect2(origin + Vector2(2, 2), Vector2(16, 16)), marker.darkened(0.65))
			draw_rect(Rect2(origin + Vector2(2, 2), Vector2(16, 16)), marker, false)
			draw_string(get_theme_default_font(), origin + Vector2(6, 14), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, marker)


func _draw_actor(point: Vector2i, direction: Vector2i, id: String) -> void:
	var origin := Vector2(point * CELL)
	if textures.has(id):
		draw_texture_rect(textures[id], Rect2(origin, Vector2(CELL, CELL)), false)
	else:
		var tint := Color(palette[id])
		draw_rect(Rect2(origin + Vector2(4, 14), Vector2(13, 3)), Color("161c20"))
		draw_rect(Rect2(origin + Vector2(6, 7), Vector2(9, 8)), tint.darkened(0.28))
		draw_rect(Rect2(origin + Vector2(7, 4), Vector2(7, 5)), tint)
		draw_rect(Rect2(origin + Vector2(5, 11), Vector2(11, 2)), tint)
	var tip := origin + Vector2(10, 10) + Vector2(direction * 8)
	draw_rect(Rect2(tip - Vector2.ONE, Vector2(3, 3)), Color("fff0ca"))
