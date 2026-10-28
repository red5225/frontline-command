extends RefCounted
class_name WorldState

const REGION_DATA_PATH := "res://data/regions.json"
const MOVE_SECONDS_PER_REGION := 8.5
const CAPTURE_SECONDS := 5.0

var regions: Array[Dictionary] = []
var units: Array[Dictionary] = []
var log_messages: Array[String] = []
var elapsed_seconds: float = 0.0
var resources: int = 220
var winner: String = ""
var _ai_clock: float = 0.0
var _income_clock: float = 0.0
var _contest_clock: float = 0.0

func _init() -> void:
	var raw := FileAccess.get_file_as_string(REGION_DATA_PATH)
	var parsed = JSON.parse_string(raw)
	if parsed is Array:
		for item in parsed:
			var region: Dictionary = item.duplicate(true)
			region["owner"] = str(region.get("initial_owner", "neutral"))
			region["neighbors"] = []
			region["capture_clock"] = 0.0
			region["contest_clock"] = 0.0
			region["contested"] = false
			regions.append(region)
	_build_neighbor_graph()
	_setup_units()
	add_log("ATLAS THEATER INITIALIZED")
	add_log("Command groups are ready. Select a group and issue a movement order.")

func _build_neighbor_graph() -> void:
	for region in regions:
		region["neighbors"] = []
	for i in range(regions.size()):
		var ranked: Array[Dictionary] = []
		var origin: Vector2 = _center(regions[i])
		for j in range(regions.size()):
			if i == j:
				continue
			ranked.append({
				"id": str(regions[j]["id"]),
				"distance": origin.distance_to(_center(regions[j]))
			})
		ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["distance"]) < float(b["distance"])
		)
		var take_count: int = mini(4, ranked.size())
		for k in range(take_count):
			var neighbor_id := str(ranked[k]["id"])
			if not regions[i]["neighbors"].has(neighbor_id):
				regions[i]["neighbors"].append(neighbor_id)
			var other: Dictionary = get_region(neighbor_id)
			if not other.is_empty() and not other["neighbors"].has(str(regions[i]["id"])):
				other["neighbors"].append(str(regions[i]["id"]))

func _setup_units() -> void:
	units.clear()
	_add_unit("p01", "Western Field Group", "player", "westreach", 68.0)
	_add_unit("p02", "Northern Field Group", "player", "balor", 73.0)
	_add_unit("p03", "Capital Reserve", "player", "cairn", 86.0)
	_add_unit("p04", "Central Support Group", "player", "kadesh", 65.0)
	_add_unit("p05", "Southern Field Group", "player", "zaren", 70.0)
	_add_unit("p06", "Western Relief Column", "player", "ashar", 57.0)
	_add_unit("r01", "Meridian Field Group", "rival", "vesk", 69.0)
	_add_unit("r02", "Northern Reserve Group", "rival", "talar", 65.0)
	_add_unit("r03", "Eastern Field Group", "rival", "palis", 62.0)
	_add_unit("r04", "Frontier Support Group", "rival", "ravel", 58.0)
	_add_unit("r05", "Southern Reserve Group", "rival", "kelesh", 63.0)
	_add_unit("r06", "Eastern Relief Column", "rival", "oshen", 55.0)

func _add_unit(unit_id: String, unit_name: String, owner: String, province_id: String, strength_value: float) -> void:
	units.append({
		"id": unit_id,
		"name": unit_name,
		"owner": owner,
		"province_id": province_id,
		"strength": strength_value,
		"readiness": 0.72 + float((units.size() * 7) % 20) / 100.0,
		"supply": 0.68 + float((units.size() * 11) % 25) / 100.0,
		"route": [],
		"target": "",
		"travel_clock": 0.0
	})

func get_region(region_id: String) -> Dictionary:
	for region in regions:
		if str(region.get("id", "")) == region_id:
			return region
	return {}

func get_unit(unit_id: String) -> Dictionary:
	for unit in units:
		if str(unit.get("id", "")) == unit_id:
			return unit
	return {}

func _center(region: Dictionary) -> Vector2:
	var value: Array = region.get("center", [0.5, 0.5])
	return Vector2(float(value[0]), float(value[1]))

func issue_move(unit_id: String, target_id: String) -> bool:
	var unit := get_unit(unit_id)
	var target := get_region(target_id)
	if unit.is_empty() or target.is_empty():
		return false
	if str(unit["province_id"]) == target_id:
		hold_unit(unit_id)
		add_log("%s is already in %s." % [unit["name"], target["name"]])
		return true
	var source_id := str(unit["province_id"])
	var previous: Dictionary = {source_id: ""}
	var queue: Array[String] = [source_id]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == target_id:
			break
		var region := get_region(current)
		for neighbor_value in region.get("neighbors", []):
			var neighbor_id := str(neighbor_value)
			if not previous.has(neighbor_id):
				previous[neighbor_id] = current
				queue.append(neighbor_id)
	if not previous.has(target_id):
		add_log("No route could be found to %s." % target["name"])
		return false
	var route: Array[String] = []
	var cursor := target_id
	while cursor != source_id:
		route.push_front(cursor)
		cursor = str(previous.get(cursor, ""))
		if cursor.is_empty():
			return false
	unit["route"] = route
	unit["target"] = target_id
	unit["travel_clock"] = 0.0
	add_log("%s ordered toward %s." % [unit["name"], target["name"]])
	return true

func hold_unit(unit_id: String) -> void:
	var unit := get_unit(unit_id)
	if unit.is_empty():
		return
	unit["route"] = []
	unit["target"] = ""
	unit["travel_clock"] = 0.0
	add_log("%s holding position." % unit["name"])

func step(delta: float) -> void:
	if winner != "" or delta <= 0.0:
		return
	elapsed_seconds += delta
	_step_movement(delta)
	_ai_clock += delta
	_income_clock += delta
	_contest_clock += delta
	if _contest_clock >= 1.0:
		_resolve_region_states(_contest_clock)
		_contest_clock = 0.0
	if _ai_clock >= 10.0:
		_ai_clock = 0.0
		_ai_step()
	if _income_clock >= 4.0:
		_income_clock = 0.0
		var player_regions := count_regions("player")
		resources += player_regions * 2
		for unit in units:
			if str(unit["owner"]) == "player":
				var location := get_region(str(unit["province_id"]))
				if str(location.get("owner", "")) == "player":
					unit["supply"] = minf(1.0, float(unit["supply"]) + 0.025)
				else:
					unit["supply"] = maxf(0.25, float(unit["supply"]) - 0.012)
	_check_victory()

func _step_movement(delta: float) -> void:
	for unit in units:
		var route: Array = unit.get("route", [])
		if route.is_empty():
			continue
		unit["travel_clock"] = float(unit["travel_clock"]) + delta
		if float(unit["travel_clock"]) >= MOVE_SECONDS_PER_REGION:
			unit["travel_clock"] = 0.0
			var next_region := str(route.pop_front())
			unit["province_id"] = next_region
			add_log("%s arrived in %s." % [unit["name"], get_region(next_region).get("name", next_region)])
			if route.is_empty():
				unit["target"] = ""
			else:
				unit["target"] = str(route.back())

func _resolve_region_states(delta: float) -> void:
	for region in regions:
		var region_id := str(region["id"])
		var player_here: Array[Dictionary] = []
		var rival_here: Array[Dictionary] = []
		for unit in units:
			if str(unit["province_id"]) != region_id or float(unit["strength"]) <= 0.0:
				continue
			if str(unit["owner"]) == "player":
				player_here.append(unit)
			elif str(unit["owner"]) == "rival":
				rival_here.append(unit)
		region["contested"] = not player_here.is_empty() and not rival_here.is_empty()
		if region["contested"]:
			region["capture_clock"] = 0.0
			region["contest_clock"] = float(region["contest_clock"]) + delta
			if float(region["contest_clock"]) >= 2.0:
				region["contest_clock"] = 0.0
				_apply_abstract_contest(player_here, rival_here, region)
		elif not player_here.is_empty():
			region["contest_clock"] = 0.0
			_advance_occupation(region, "player", delta)
		elif not rival_here.is_empty():
			region["contest_clock"] = 0.0
			_advance_occupation(region, "rival", delta)
		else:
			region["capture_clock"] = 0.0
			region["contest_clock"] = 0.0
	for i in range(units.size() - 1, -1, -1):
		if float(units[i]["strength"]) <= 0.0:
			add_log("%s has left the simulation after its strength was depleted." % units[i]["name"])
			units.remove_at(i)

func _apply_abstract_contest(player_groups: Array[Dictionary], rival_groups: Array[Dictionary], region: Dictionary) -> void:
	var player_score := _group_score(player_groups)
	var rival_score := _group_score(rival_groups)
	if player_score >= rival_score:
		_reduce_groups(rival_groups, 2.5)
		_reduce_groups(player_groups, 0.8)
	else:
		_reduce_groups(player_groups, 2.5)
		_reduce_groups(rival_groups, 0.8)
	add_log("Control contest ongoing in %s." % region["name"])

func _group_score(groups: Array[Dictionary]) -> float:
	var result := 0.0
	for unit in groups:
		result += float(unit["strength"]) * (0.55 + float(unit["readiness"]) * 0.30 + float(unit["supply"]) * 0.15)
	return result

func _reduce_groups(groups: Array[Dictionary], amount: float) -> void:
	if groups.is_empty():
		return
	var per_group := amount / float(groups.size())
	for unit in groups:
		unit["strength"] = maxf(0.0, float(unit["strength"]) - per_group)
		unit["readiness"] = maxf(0.25, float(unit["readiness"]) - per_group * 0.003)

func _advance_occupation(region: Dictionary, side: String, delta: float) -> void:
	if str(region["owner"]) == side:
		region["capture_clock"] = 0.0
		return
	region["capture_clock"] = float(region["capture_clock"]) + delta
	if float(region["capture_clock"]) >= CAPTURE_SECONDS:
		var old_owner := str(region["owner"])
		region["owner"] = side
		region["capture_clock"] = 0.0
		if old_owner == "neutral":
			add_log("%s is now administered by %s." % [region["name"], _faction_name(side)])
		else:
			add_log("%s changed control from %s to %s." % [region["name"], _faction_name(old_owner), _faction_name(side)])
		var occupants := units_in_region(str(region["id"]), side)
		for unit in occupants:
			unit["supply"] = minf(1.0, float(unit["supply"]) + 0.08)

func _ai_step() -> void:
	for unit in units:
		var active_route: Array = unit.get("route", [])
		if str(unit["owner"]) != "rival" or not active_route.is_empty():
			continue
		var home := get_region(str(unit["province_id"]))
		var candidates: Array[Dictionary] = []
		for neighbor_id_value in home.get("neighbors", []):
			var region := get_region(str(neighbor_id_value))
			if region.is_empty() or str(region["owner"]) == "rival":
				continue
			candidates.append(region)
		if candidates.is_empty():
			continue
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_score := float(a.get("strategic", 1)) + (5.0 if str(a.get("owner", "")) == "neutral" else 0.0)
			var b_score := float(b.get("strategic", 1)) + (5.0 if str(b.get("owner", "")) == "neutral" else 0.0)
			return a_score > b_score
		)
		issue_move(str(unit["id"]), str(candidates[0]["id"]))

func _check_victory() -> void:
	if count_regions("player") >= 25:
		winner = "player"
		add_log("STRATEGIC OBJECTIVE COMPLETE — ATLAS COMMAND HOLDS THE MAJORITY.")
	elif count_regions("rival") >= 25:
		winner = "rival"
		add_log("SCENARIO ENDED — THE MERIDIAN COALITION HOLDS THE MAJORITY.")

func count_regions(side: String) -> int:
	var result := 0
	for region in regions:
		if str(region["owner"]) == side:
			result += 1
	return result

func units_in_region(region_id: String, side: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit in units:
		if str(unit["province_id"]) == region_id and (side.is_empty() or str(unit["owner"]) == side):
			result.append(unit)
	return result

func faction_units(side: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit in units:
		if str(unit["owner"]) == side:
			result.append(unit)
	return result

func add_log(message: String) -> void:
	var stamp := _clock_stamp()
	log_messages.push_front("[%s] %s" % [stamp, message])
	while log_messages.size() > 40:
		log_messages.pop_back()

func _clock_stamp() -> String:
	var total_minutes := int(elapsed_seconds * 2.0)
	var day := 1 + int(total_minutes / 1440)
	var hour := int((total_minutes % 1440) / 60)
	var minute := total_minutes % 60
	return "D%02d %02d:%02d" % [day, hour, minute]

func _faction_name(side: String) -> String:
	if side == "player":
		return "Atlas Command"
	if side == "rival":
		return "Meridian Coalition"
	return "Unadministered"
