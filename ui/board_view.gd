extends Control

signal cell_selected(cell: Vector2i)

const CELL = 20
const World = preload("res://scripts/world.gd")
const Expedition = preload("res://scripts/expedition.gd")
const ART_DIR = "res://assets/placeholder/"
const ART_IDS = [
	"floor", "floor_town", "road_town", "floor_forest", "road_forest", "floor_camp", "road_camp",
	"wall", "wall_town", "wall_forest", "wall_camp", "door", "brush", "low",
	"player", "sentry", "raider", "chief", "trainer", "site",
	"site_hall", "site_board", "site_shop", "site_inn", "site_travel", "site_evidence", "site_cache"
]

var run: Expedition
var route: Array[Vector2i] = []
var selected := Vector2i(-1, -1)
var palette: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART_DIR + "palette.json"))
var textures: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for id in ART_IDS:
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
	draw_rect(Rect2(Vector2.ZERO, Vector2(rows[0].length() * CELL, rows.size() * CELL)), Color("172521"))
	for row in range(rows.size()):
		for col in range(rows[row].length()):
			_draw_cell(Vector2i(col, row), rows[row][col])
	_draw_ambience(state.area)
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
	var id := _terrain_id(point, symbol)
	if textures.has(id):
		draw_texture_rect(textures[id], box, false)
	elif textures.has("floor") and (id.begins_with("floor_") or id.begins_with("road_")):
		draw_texture_rect(textures.floor, box, false)
	else:
		var base := Color(palette.get(id, palette.get("floor", "28383a")))
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
		draw_rect(box, Color(0, 0, 0, 0.12), false)
	var site := run.world.site(point)
	if not site.is_empty():
		_draw_site(origin, site, symbol)


func _terrain_id(point: Vector2i, symbol: String) -> String:
	if symbol == "#":
		return "wall_" + run.state.area if textures.has("wall_" + run.state.area) else "wall"
	if symbol == "^":
		return "brush"
	if symbol == "=":
		return "low"
	if symbol == "+":
		return "door"
	var area: String = run.state.area
	if area == "town":
		return "road_town" if _town_road(point) else "floor_town"
	if area == "forest":
		return "road_forest" if _forest_road(point) else "floor_forest"
	return "road_camp" if _camp_road(point) else "floor_camp"


func _town_road(point: Vector2i) -> bool:
	# Broad east-west streets make the county readable as a place, while the
	# green pockets keep the town from becoming one large brown rectangle.
	if point.y in [5, 9, 11, 13, 14]:
		return true
	return point.x in [8, 9, 10, 11] and point.y > 0 and point.y < 15


func _forest_road(point: Vector2i) -> bool:
	# The north route follows the ridge, while a second, rougher track cuts
	# through the southern brush line.
	if point.y == 1 or (point.x >= 20 and point.y <= 7):
		return true
	return (point.x <= 2 and point.y in [7, 8, 9]) or (point.y == 9 and point.x <= 17)


func _camp_road(point: Vector2i) -> bool:
	# Dusty passages join the west gate to the central yard, upper store rooms,
	# and the evidence platform; remaining ground stays packed earth.
	return point.y == 12 or point.y in [8, 9] or (point.y == 5 and point.x >= 10) or (point.x in [9, 10] and point.y >= 8 and point.y <= 11)


func _draw_site(origin: Vector2, site: Dictionary, symbol: String) -> void:
	var action: String = site.get("action", "")
	var id := "site_" + action
	if action == "travel":
		id = "site_travel"
	if textures.has(id):
		draw_texture_rect(textures[id], Rect2(origin, Vector2(CELL, CELL)), false)
		return
	if textures.has("site"):
		draw_texture_rect(textures.site, Rect2(origin, Vector2(CELL, CELL)), false)
		return
	var marker := Color(palette.get("site", "e1b96e"))
	draw_rect(Rect2(origin + Vector2(2, 2), Vector2(16, 16)), marker.darkened(0.65))
	draw_rect(Rect2(origin + Vector2(2, 2), Vector2(16, 16)), marker, false)
	draw_rect(Rect2(origin + Vector2(7, 7), Vector2(6, 6)), marker)


func _draw_ambience(area: String) -> void:
	var size := Vector2(480, 320)
	var tint := Color(0.12, 0.18, 0.15, 0.12)
	if area == "town":
		tint = Color(0.92, 0.76, 0.48, 0.07)
	elif area == "camp":
		tint = Color(0.08, 0.05, 0.04, 0.18)
	# A low-opacity canopy/sky wash gives the flat tile field a little depth.
	draw_rect(Rect2(0, 0, size.x, 18), tint)
	draw_rect(Rect2(0, size.y - 10, size.x, 10), Color(0.03, 0.05, 0.05, 0.18))
	draw_rect(Rect2(Vector2.ZERO, size), Color("101b1b"), false, 2)


func _draw_actor(point: Vector2i, direction: Vector2i, id: String) -> void:
	var origin := Vector2(point * CELL)
	draw_rect(Rect2(origin + Vector2(3, 17), Vector2(14, 2)), Color(0.04, 0.06, 0.06, 0.65))
	if textures.has(id):
		draw_texture_rect(textures[id], Rect2(origin, Vector2(CELL, CELL)), false)
	else:
		var tint := Color(palette.get(id, "8ed0ba"))
		draw_rect(Rect2(origin + Vector2(4, 14), Vector2(13, 3)), Color("161c20"))
		draw_rect(Rect2(origin + Vector2(6, 7), Vector2(9, 8)), tint.darkened(0.28))
		draw_rect(Rect2(origin + Vector2(7, 4), Vector2(7, 5)), tint)
		draw_rect(Rect2(origin + Vector2(5, 11), Vector2(11, 2)), tint)
	var tip := origin + Vector2(10, 10) + Vector2(direction * 8)
	draw_rect(Rect2(tip - Vector2.ONE, Vector2(3, 3)), Color("fff0ca"))
