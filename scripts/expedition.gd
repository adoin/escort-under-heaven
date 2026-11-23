extends RefCounted

const World = preload("res://scripts/world.gd")
const Checkpoints = preload("res://scripts/checkpoints.gd")
const Progression = preload("res://scripts/progression.gd")
const SLOTS = 8

var world := World.new(data("world"))
var martial := data("martial_arts")
var campaign := data("campaign")
var saves: Checkpoints
var state: Dictionary = {}
var report: Array[String] = []
var notice := ""
var death_report := ""
var deaths := 0
var rng := RandomNumberGenerator.new()


static func data(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % file))


func _init(save_folder: String = "user://") -> void:
	saves = Checkpoints.new(save_folder)


func create(talent: String) -> void:
	rng.randomize()
	var weapon := "saber" if talent == "body" else "sword"
	state = {
		"area":"town", "pos":Vector2i(2, 3), "face":Vector2i.DOWN, "beat":0, "talent":talent,
		"hp":0, "qi":0, "bleed":0, "leg":false, "hunger":0, "thirst":0, "guard":false,
		"stance":0, "evade":0, "quiet":false, "cooldowns":{}, "rng":rng.state, "healed_intro":false,
		"weapon":weapon, "durability":{"sword":40,"saber":40,"jacket":40}, "style":"breath",
		"learned":["breath", weapon, "guard", "leap"], "stats":{"strength":0,"body":0,"spirit":0,"agility":0},
		"points":0, "skill_points":1, "level":1, "xp":0, "coins":55,
		"bag":{"medicine":3,"food":2,"water":2}, "job":"", "completed":[], "evidence":false, "surveyed":false,
		"cache_seen":false, "cache_claimed":false, "lead":"", "training":false,
		"departure_coins":55, "enemies":{},
		"progress":{"credit":0,"renown":0,"guild":0,"trips":0,"cases":[],"nominations":[],"sponsors":[],
			"routes":[],"milestones":[],"office":"","history":[],"equity":0,"debts":0,"claims":0}
	}
	_setup_world()
	state.hp = max_hp()
	state.qi = max_qi()
	report.clear()
	death_report = ""
	log_line("长风镖局收留了你。是时候凭自己的本事走一趟镖了。")
	saves.discard(Checkpoints.INN)
	_commit()


func _setup_world() -> void:
	world.state = state
	for area in world.zones:
		state.enemies[area] = []
		for spec in world.zones[area].enemies:
			state.enemies[area].append(_make_enemy(spec.id, spec.kind, Vector2i(spec.pos[0], spec.pos[1]), spec.patrol))


func _make_enemy(id: String, kind: String, position: Vector2i, route: Array) -> Dictionary:
	var patrol: Array[Vector2i] = []
	for point in route:
		patrol.append(Vector2i(point[0], point[1]))
	return {"id":id,"kind":kind,"pos":position,"hp":int(campaign.enemies[kind].hp),"patrol":patrol,
		"waypoint":0,"alert":0,"aggro":false,"charge":false,"target":Vector2i.ZERO,
		"face":Vector2i.DOWN,"attack_count":0,"winded":0,"elements":{}}


func load_slot(slot: String) -> bool:
	var loaded := saves.read(slot)
	if loaded.is_empty():
		return reject("这里没有可读的存档。")
	state = loaded
	world.state = state
	rng.state = int(state.rng)
	report.clear()
	log_line("从%s继续。" % ("归雁客栈" if slot == Checkpoints.INN else "上次行动"))
	if slot == Checkpoints.INN:
		_commit()
	return true


func _commit() -> void:
	state.rng = rng.state
	if not saves.write(Checkpoints.SESSION, state):
		notice = "续玩存档写入失败。"


func log_line(text: String) -> void:
	report.append(text)
	if report.size() > 32:
		report.pop_front()
	notice = text


func reject(text: String) -> bool:
	notice = text
	return false


func max_hp() -> int:
	return 40 + (6 if state.talent == "body" else 0) + 4 * int(state.stats.body)


func max_qi() -> int:
	return 12 + (4 if state.talent == "spirit" else 0) + 2 * int(state.stats.spirit)


func mobility() -> Dictionary:
	var result: Dictionary = martial.movement.duplicate()
	result.evasion += (8 if state.talent == "agility" else 0) + 2 * int(state.stats.agility)
	if state.evade > 0:
		result.evasion += int(result.light_bonus)
	if state.leg:
		result.evasion = maxi(0, int(result.evasion) - 15)
		result.jump_height = 0
		result.leap_range = 0
	return result


func enemy_name(enemy: Dictionary) -> String:
	return campaign.enemies[enemy.kind].name


func move(destination: Vector2i, leap: bool = false) -> bool:
	var delta: Vector2i = destination - state.pos
	var length := world.distance(state.pos, destination)
	if length == 0 or (delta.x != 0 and delta.y != 0):
		return reject("只能沿四向移动。")
	if leap:
		if state.leg:
			return reject("腿伤限制跃步。仍可步行。")
		if not skill_ready("leap"):
			return false
	if length > (int(mobility().leap_range) if leap else 1):
		return reject("超出移动距离。")
	var direction := world.facing(delta)
	for step in range(1, length + 1):
		var point: Vector2i = state.pos + direction * step
		var over_low: bool = leap and step < length and world.cell(point) == "=" and mobility().jump_height >= 1
		if (not world.walkable(point) and not over_low) or not world.enemy_at(point).is_empty():
			return reject("墙、低障或敌人挡住了去路。")
	state.face = direction
	state.pos = destination
	if leap:
		_pay_skill("leap")
		state.evade = 1
		log_line("跃步移过 %d 格。" % length)
	return _resolve("leap" if leap else "move")


func wait() -> bool:
	log_line("你静候一拍。")
	return _resolve("wait")


func skill_ready(id: String) -> bool:
	var skill: Dictionary = martial.skills[id]
	if not state.learned.has(id):
		return reject("尚未习得%s。" % skill.name)
	if skill.has("weapon") and state.weapon != skill.weapon:
		return reject("当前装备不符。")
	if state.cooldowns.get(id, 0) > 0:
		return reject("%s仍需冷却 %d 拍。" % [skill.name, state.cooldowns[id]])
	if state.qi < skill.cost:
		return reject("内力不足。")
	return true


func _pay_skill(id: String) -> void:
	var skill: Dictionary = martial.skills[id]
	state.qi -= int(skill.cost)
	state.cooldowns[id] = int(skill.cooldown) + 1


func attack(target: Vector2i, special: bool = false, channel: bool = false) -> bool:
	var enemy := world.enemy_at(target)
	if enemy.is_empty():
		return reject("此格没有目标。")
	var weapon: String = state.weapon
	var art: Dictionary = martial.skills[weapon]
	var style: Dictionary = martial.internal[state.style]
	var delta: Vector2i = target - state.pos
	if not in_attack_range(target, int(art.range) if special else 1):
		return reject("超出直线射程，或中间有遮挡。")
	if special and not skill_ready(weapon):
		return false
	if special and channel and state.qi < int(art.cost) + _infusion_cost(style.element):
		return reject("注劲需要额外内力。")
	state.face = world.facing(delta)
	var damage := int(campaign.gear[weapon].power) + int(state.stats.strength) + int(style.attack)
	damage -= 2 if state.durability[weapon] == 0 else 0
	if special:
		_pay_skill(weapon)
		damage += int(art.power)
		if channel:
			state.qi -= _infusion_cost(style.element)
			damage += mini(int(art.infusion_cap), int(style.infusion_cap))
			_apply_element(enemy, style.element)
	if enemy.face == state.face:
		damage += 2
		log_line("从背后命中。")
	if enemy.charge and (damage >= 10 or (special and weapon == "saber")):
		_interrupt(enemy)
	if special and weapon == "saber":
		enemy.winded = 1
	damage = maxi(1, damage)
	enemy.hp -= damage
	enemy.alert = int(martial.movement.alert_limit)
	enemy.aggro = true
	state.quiet = false
	state.durability[weapon] = maxi(0, state.durability[weapon] - 1)
	log_line("%s命中%s，伤害 %d。" % [art.name if special else "普攻", enemy_name(enemy), damage])
	if enemy.hp <= 0:
		log_line("%s倒下。" % enemy_name(enemy))
		if enemy.kind != "trainer":
			if _can_add("token"):
				_add("token", 1)
			else:
				log_line("背包满了，未带走牙牌。")
			award_xp(1)
	return _resolve("attack")


func in_attack_range(target: Vector2i, reach: int) -> bool:
	var delta: Vector2i = target - state.pos
	return (delta.x == 0 or delta.y == 0) and world.distance(state.pos, target) <= reach and world.clear_line(state.pos, target, true)


func _infusion_cost(element: String) -> int:
	return 3 if element in ["fire", "thunder"] else 2


func _apply_element(enemy: Dictionary, element: String) -> void:
	var rule: Dictionary = martial.elements[element]
	log_line("%s劲注入招式。" % rule.name)
	if int(rule.threshold) == 0:
		return
	enemy.elements[element] = int(enemy.elements.get(element, 0)) + 1
	if enemy.elements[element] >= int(rule.threshold):
		enemy.elements[element] = 0
		match element:
			"cold": enemy.winded = 2
			"fire", "poison": enemy.hp -= 3
			"thunder":
				if enemy.charge:
					_interrupt(enemy)


func _interrupt(enemy: Dictionary) -> void:
	enemy.charge = false
	enemy.winded = 1
	log_line("%s的蓄势被打断！" % enemy_name(enemy))


func guard(direction: Vector2i) -> bool:
	if not skill_ready("guard"):
		return false
	if direction != Vector2i.ZERO:
		state.face = world.facing(direction)
	state.guard = true
	_pay_skill("guard")
	log_line("你面向来路格挡。")
	return _resolve("guard")


func breathe() -> bool:
	if not skill_ready("breath"):
		return false
	_pay_skill("breath")
	state.qi = mini(max_qi(), state.qi + 4)
	state.stance = 2
	log_line("调息回内，凝神护体。")
	return _resolve("breath")


func heal_leg() -> bool:
	if not state.leg:
		return reject("没有腿伤。")
	if state.bleed > 0 or state.qi < 5 or threatened():
		return reject("运功疗伤需先止血、脱离交战，并保留 5 内力。")
	state.qi -= 5
	state.leg = false
	log_line("运功缓解腿伤。")
	return _resolve("heal")


func swap() -> bool:
	state.weapon = "sword" if state.weapon == "saber" else "saber"
	log_line("换持%s。" % campaign.gear[state.weapon].name)
	return _resolve("swap")


func quiet() -> bool:
	state.quiet = not state.quiet
	log_line("开始轻步。" if state.quiet else "恢复正常脚步。")
	return _resolve("quiet")


func threatened() -> bool:
	for enemy in state.enemies[state.area]:
		if enemy.hp > 0 and (enemy.charge or (enemy.aggro and world.distance(enemy.pos, state.pos) <= 5)):
			return true
	return false


func _resolve(action: String, arrival: Dictionary = {}) -> bool:
	state.beat += 1
	if action != "guard":
		state.guard = false
	for enemy in state.enemies[state.area]:
		if enemy.hp > 0 and state.hp > 0:
			_enemy_turn(enemy, action)
	for skill in state.cooldowns:
		state.cooldowns[skill] = maxi(0, state.cooldowns[skill] - 1)
	state.stance = maxi(0, state.stance - 1)
	state.evade = 0
	if state.bleed > 0:
		state.hp -= 2
		state.bleed -= 1
		log_line("流血损失 2 生命%s。" % ("，伤口结痂" if state.bleed == 0 else ""))
	if state.area != "town":
		state.hunger = mini(100, state.hunger + 1)
		state.thirst = mini(100, state.thirst + 1)
		if state.beat % 5 == 0 and (state.hunger >= 90 or state.thirst >= 80):
			state.hp -= 1
			log_line("缺少补给，损失 1 生命。")
	if state.hp <= 0:
		_death()
	else:
		if not arrival.is_empty():
			state.area = arrival.area
			state.pos = Vector2i(arrival.spawn[0], arrival.spawn[1])
			if state.area == "camp" and state.job == "route_survey":
				state.surveyed = true
			log_line("抵达%s。%s" % [world.zone().name, world.zone().hint])
		_commit()
	return true


func _enemy_turn(enemy: Dictionary, action: String) -> void:
	var info: Dictionary = campaign.enemies[enemy.kind]
	var distance := world.distance(enemy.pos, state.pos)
	var direction := world.facing(state.pos - enemy.pos)
	if enemy.winded > 0:
		enemy.winded -= 1
		return
	if enemy.charge:
		enemy.charge = false
		if state.pos == enemy.target and distance == 1:
			_enemy_hit(enemy, info, true)
		else:
			log_line("%s的重斩落空。" % info.name)
		return
	var limit := int(martial.movement.alert_limit)
	var old_alert: int = enemy.alert
	if distance <= 1:
		enemy.alert = limit
	elif distance <= int(info.sense) and world.clear_line(enemy.pos, state.pos):
		var noise := 40 + (20 if enemy.face == direction else 0)
		noise += 20 if action == "leap" else 0
		noise -= 35 if world.cell(state.pos) == "^" else 0
		noise -= 20 if state.quiet else 0
		enemy.alert = clampi(enemy.alert + noise, 0, limit)
	else:
		enemy.alert = maxi(0, enemy.alert - (25 if distance > 7 else 10))
	enemy.aggro = enemy.alert >= limit or (enemy.aggro and enemy.alert > 0)
	if old_alert < limit and enemy.alert == limit:
		log_line("%s发现了你！" % info.name)
	if enemy.aggro:
		if distance == 1:
			enemy.face = direction
			if info.get("charge", false):
				enemy.charge = true
				enemy.target = state.pos
				log_line("%s蓄势重斩。移开红格，或以重击打断。" % info.name)
			else:
				_enemy_hit(enemy, info, false)
		else:
			_enemy_step(enemy, state.pos)
	elif not enemy.patrol.is_empty() and state.beat % 3 == 0:
		if enemy.pos == enemy.patrol[enemy.waypoint]:
			enemy.waypoint = (enemy.waypoint + 1) % enemy.patrol.size()
		_enemy_step(enemy, enemy.patrol[enemy.waypoint])


func _enemy_step(enemy: Dictionary, target: Vector2i) -> void:
	var route := world.path(enemy.pos, target)
	if route.is_empty() or route[0] == state.pos or not world.enemy_at(route[0]).is_empty():
		return
	enemy.face = route[0] - enemy.pos
	enemy.pos = route[0]


func _enemy_hit(enemy: Dictionary, info: Dictionary, heavy: bool) -> void:
	var direction := world.facing(enemy.pos - state.pos)
	var covered: bool = state.guard and direction == state.face
	var dodge := int(mobility().evasion)
	if rng.randi_range(1, 100) <= dodge and enemy.kind != "trainer":
		log_line("闪过%s的攻击。" % info.name)
		return
	var damage := int(info.damage) + (7 if heavy else 0)
	damage -= int(martial.internal[state.style].defense) + (2 if state.stance > 0 else 0)
	damage += 1 if state.durability.jacket == 0 else 0
	damage += 1 if state.face == -direction and enemy.kind != "trainer" else 0
	if covered:
		state.guard = false
		damage = int(ceil(damage * 0.35))
		log_line("正面格挡卸去了大部分冲击。")
	damage = maxi(1, damage)
	state.hp -= damage
	state.durability.jacket = maxi(0, state.durability.jacket - 1)
	enemy.attack_count += 1
	log_line("%s%s击中，损失 %d 生命。" % [info.name, "重斩" if heavy else "", damage])
	if not covered and enemy.attack_count % 2 == 1:
		if info.has("bleed"):
			state.bleed = int(info.bleed)
			if not state.healed_intro:
				log_line("流血每拍掉 2 生命。按 5 或点金创药立即止血。")
		if info.get("leg", false) or heavy:
			state.leg = true
			log_line("腿伤封住了跃步。可步行撤退后运功疗伤。")


func _death() -> void:
	deaths += 1
	death_report = "\n".join(report.slice(-5))
	saves.discard(Checkpoints.SESSION)
	if not load_slot(Checkpoints.INN):
		var talent: String = state.talent
		var final_actions := death_report
		create(talent)
		death_report = final_actions
		log_line("尚未投宿，回到镖局。")
	else:
		log_line("你倒下了，已回到归雁客栈的投宿存档。")


func interact(point: Vector2i) -> String:
	var site := world.site(point)
	if site.is_empty() or world.distance(state.pos, point) > 1:
		reject("走到标记旁再交互。")
		return ""
	match site.action:
		"travel":
			if state.area == "town":
				if state.job == "":
					reject("先在县城榜亭接榜。归雁客栈可在出发前投宿存档。")
					return ""
				state.departure_coins = state.coins
			_resolve("travel", site)
		"evidence":
			if state.job != "lost_escort" or state.evidence:
				reject("这里没有待取的账册。")
				return ""
			state.evidence = true
			state.cache_seen = true
			log_line("藏好账册。夹页标着西北藏货间，你可以回客栈交榜，也可以去搜查。")
			_resolve("search")
		"cache":
			state.cache_seen = true
			if state.cache_claimed:
				reject("藏货间已经搜过。")
				return ""
			if not _can_add("silverware"):
				reject("背包无剩余格，旧银器先留在原处。")
				return ""
			_add("silverware", 1)
			state.cache_claimed = true
			log_line("找到一只旧银器。")
			_resolve("search")
		_:
			if not threatened():
				return site.action
			reject("先结束镖局演练。")
	return ""


func near_service(action: String) -> bool:
	if state.area != "town" or threatened():
		return false
	for direction in World.DIRECTIONS + [Vector2i.ZERO]:
		if world.site(state.pos + direction).get("action") == action:
			return true
	return false


func train() -> bool:
	if not near_service("hall") or state.training:
		return reject("演练已结束，或不在镖局。")
	state.training = true
	state.pos = Vector2i(2, 3)
	state.face = Vector2i.RIGHT
	state.enemies.town.append(_make_enemy("hall_trainer", "trainer", Vector2i(3, 3), []))
	log_line("镖师演示浅伤。用金创药止血，再普攻结束演练。")
	return _resolve("training")


func accept_job(id: String) -> bool:
	if not near_service("board") or id != next_job() or id.is_empty():
		return reject("当前无法接取这张榜。")
	state.job = id
	log_line("接榜 · %s。%s" % [campaign.jobs[id].name, campaign.jobs[id].description])
	_commit()
	return true


func next_job() -> String:
	if state.job != "":
		return ""
	for id in campaign.jobs:
		if id not in state.completed:
			return id
	return ""


func can_deliver() -> bool:
	return (state.job == "lost_escort" and state.evidence) or (state.job == "route_survey" and state.surveyed)


func deliver() -> bool:
	if not near_service("inn") or not can_deliver() or state.job in state.completed:
		return reject("没有可交付的榜单。")
	var job: Dictionary = campaign.jobs[state.job]
	state.coins += int(job.pay)
	state.progress.credit = mini(100, state.progress.credit + int(job.credit))
	state.progress.renown = mini(100, state.progress.renown + int(job.renown))
	state.progress.trips += 1
	state.completed.append(state.job)
	if state.job == "lost_escort":
		state.evidence = false
		state.lead = "available"
	state.job = ""
	award_xp(3)
	log_line("交榜 · %s。赏银 %d 两，本趟现银变化 %+d 两。" % [job.name, job.pay, state.coins - state.departure_coins])
	_commit()
	return true


func follow_lead(accept: bool) -> bool:
	if not near_service("inn") or state.lead not in ["available", "deferred"]:
		return reject("客栈暂无新传闻。")
	state.lead = "recorded" if accept else "deferred"
	log_line("账册的剑穗纹样指向青岚剑社。已记下柳津渡的接应人。" if accept else "暂且搁置线索，随时可再向掌柜打听。")
	_commit()
	return true


func rest() -> bool:
	if not near_service("inn"):
		return reject("只能在归雁客栈投宿。")
	var before := state.duplicate(true)
	state.hp = max_hp()
	state.qi = max_qi()
	state.leg = false
	state.bleed = 0
	state.hunger = 0
	state.thirst = 0
	state.cooldowns.clear()
	state.guard = false
	state.stance = 0
	state.rng = rng.state
	if not saves.write(Checkpoints.INN, state):
		state = before
		world.state = state
		return reject("投宿存档写入失败。")
	log_line("已投宿并保存客栈检查点。镖局担保住宿，你已恢复伤势和补给状态。")
	_commit()
	return true


func bag_slots() -> int:
	var occupied := 0
	for id in state.bag:
		occupied += _stacks(id, int(state.bag[id]))
	return occupied


func _stacks(id: String, count: int) -> int:
	return ceili(float(count) / int(campaign.items[id].stack))


func _can_add(id: String) -> bool:
	var count := int(state.bag.get(id, 0))
	return bag_slots() - _stacks(id, count) + _stacks(id, count + 1) <= SLOTS


func _add(id: String, count: int) -> void:
	state.bag[id] = int(state.bag.get(id, 0)) + count
	if state.bag[id] <= 0:
		state.bag.erase(id)


func use_item(id: String) -> bool:
	if not state.bag.has(id):
		return reject("背包里没有%s。" % campaign.items[id].name)
	match id:
		"medicine":
			if state.bleed == 0:
				return reject("没有需要处置的流血。")
			state.bleed = 0
			state.healed_intro = true
		"food":
			if state.hunger == 0:
				return reject("当前不饿。")
			state.hunger = maxi(0, state.hunger - 55)
		"water":
			if state.thirst == 0:
				return reject("当前不渴。")
			state.thirst = maxi(0, state.thirst - 60)
		_:
			return reject("这件货物可在商铺卖出。")
	_add(id, -1)
	log_line("使用%s。" % campaign.items[id].name)
	return _resolve("item")


func trade(id: String, buying: bool) -> bool:
	if not near_service("shop") or not campaign.items.has(id):
		return reject("只能在陆记商铺交易。")
	var item: Dictionary = campaign.items[id]
	if buying:
		if int(item.buy) <= 0 or state.coins < int(item.buy) or not _can_add(id):
			return reject("缺货、现银不足或背包没有空位。")
		state.coins -= int(item.buy)
		_add(id, 1)
	else:
		if not state.bag.has(id):
			return reject("未持有这种货。")
		state.coins += int(item.sell)
		_add(id, -1)
	log_line("%s%s。" % ["购入" if buying else "卖出", item.name])
	_commit()
	return true


func repair_cost() -> int:
	var missing := 0
	for durability in state.durability.values():
		missing += 40 - int(durability)
	return ceili(missing / 2.0)


func repair() -> bool:
	var price := repair_cost()
	if not near_service("shop") or price == 0 or state.coins < price:
		return reject("无需修理、现银不足或未在商铺。")
	state.coins -= price
	for id in state.durability:
		state.durability[id] = 40
	log_line("花费 %d 两修理兵器与布衣。" % price)
	_commit()
	return true


func award_xp(amount: int) -> void:
	state.xp += amount
	while state.xp >= 4:
		state.xp -= 4
		state.level += 1
		state.points += 1
		state.skill_points += 1
		log_line("阅历提升。获得 1 属性点、1 武学点。")


func raise_stat(id: String) -> bool:
	if state.area != "town" or threatened() or state.points < 1 or not state.stats.has(id):
		return reject("只能在安全处使用属性点。")
	state.points -= 1
	state.stats[id] += 1
	log_line("属性提升。")
	_commit()
	return true


func learn(id: String) -> bool:
	if state.area != "town" or threatened() or not martial.skills.has(id) or state.skill_points < 1 or id in state.learned:
		return reject("只能在安全处使用武学点习得新招。")
	var skill: Dictionary = martial.skills[id]
	if skill.has("requires") and skill.requires not in state.learned:
		return reject("还未习得前置武学。")
	state.skill_points -= 1
	state.learned.append(id)
	log_line("习得%s。" % skill.name)
	_commit()
	return true


func net_worth() -> int:
	var total := int(state.coins)
	for id in state.bag:
		total += int(state.bag[id]) * int(campaign.items[id].sell)
	for id in state.durability:
		total += floori(int(campaign.gear[id].value) * int(state.durability[id]) / 40.0)
	return total + int(state.progress.equity) - int(state.progress.debts) - int(state.progress.claims)


func confirm_ending(route: String) -> bool:
	var missing := Progression.requirements(route, state.progress, net_worth())
	if not missing.is_empty():
		return reject("尚缺 · " + missing)
	if state.progress.office == route or (route == "wealth" and route in state.progress.history):
		return reject("已经确认这项结局。")
	if route != "wealth":
		state.progress.office = route
	state.progress.history.append(route)
	log_line("达成 · %s。你仍可继续行走江湖。" % Progression.TITLES[route])
	_commit()
	return true


func resign() -> bool:
	if state.progress.office == "":
		return reject("当前没有任职。")
	log_line("已辞去%s。" % Progression.TITLES[state.progress.office])
	state.progress.office = ""
	_commit()
	return true
