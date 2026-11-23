extends RefCounted

const DIRECTIONS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var zones: Dictionary
var state: Dictionary


func _init(world_data: Dictionary) -> void:
	zones = world_data


func zone() -> Dictionary:
	return zones[state.area]


func cell(point: Vector2i) -> String:
	var rows: Array = zone().rows
	if point.y < 0 or point.y >= rows.size() or point.x < 0 or point.x >= rows[point.y].length():
		return "#"
	return rows[point.y][point.x]


func site(point: Vector2i) -> Dictionary:
	return zone().sites.get(cell(point), {})


func enemy_at(point: Vector2i) -> Dictionary:
	for enemy in state.enemies[state.area]:
		if enemy.hp > 0 and enemy.pos == point:
			return enemy
	return {}


func walkable(point: Vector2i) -> bool:
	return cell(point) not in ["#", "="]


func distance(first: Vector2i, second: Vector2i) -> int:
	return (second - first).abs().x + (second - first).abs().y


func facing(delta: Vector2i) -> Vector2i:
	if absi(delta.x) > absi(delta.y):
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))


func clear_line(first: Vector2i, last: Vector2i, units_block: bool = false) -> bool:
	var delta := last - first
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps <= 1:
		return true
	for step in range(1, steps):
		var point := Vector2i(Vector2(first).lerp(Vector2(last), float(step) / steps).round())
		if not walkable(point) or (units_block and not enemy_at(point).is_empty()):
			return false
	return true


func path(first: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [first]
	var previous: Dictionary = {first: first}
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		if current == goal:
			var result: Array[Vector2i] = []
			while current != first:
				result.push_front(current)
				current = previous[current]
			return result
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if previous.has(next) or not walkable(next):
				continue
			if next != goal and (next == state.pos or not enemy_at(next).is_empty()):
				continue
			previous[next] = current
			frontier.append(next)
	return []
