extends Control

signal map_tapped(region_id: String, button: int, unit_id: String)

const OUTLINE_NORMALIZED := [
	Vector2(0.05, 0.31), Vector2(0.12, 0.24), Vector2(0.22, 0.20),
	Vector2(0.31, 0.19), Vector2(0.39, 0.15), Vector2(0.48, 0.17),
	Vector2(0.56, 0.12), Vector2(0.64, 0.08), Vector2(0.70, 0.10),
	Vector2(0.77, 0.15), Vector2(0.85, 0.17), Vector2(0.89, 0.24),
	Vector2(0.87, 0.29), Vector2(0.82, 0.33), Vector2(0.85, 0.38),
	Vector2(0.81, 0.43), Vector2(0.79, 0.49), Vector2(0.75, 0.52),
	Vector2(0.73, 0.59), Vector2(0.68, 0.62), Vector2(0.64, 0.70),
	Vector2(0.57, 0.73), Vector2(0.52, 0.78), Vector2(0.45, 0.78),
	Vector2(0.39, 0.83), Vector2(0.31, 0.81), Vector2(0.26, 0.84),
	Vector2(0.21, 0.77), Vector2(0.15, 0.72), Vector2(0.12, 0.64),
	Vector2(0.09, 0.58), Vector2(0.07, 0.49), Vector2(0.03, 0.43)
]

const COLOR_BG := Color("#0b1315")
const COLOR_GRID := Color(0.25, 0.34, 0.32, 0.20)
const COLOR_BORDER := Color("#344542")
const COLOR_PLAYER := Color("#315e56")
const COLOR_RIVAL := Color("#755044")
const COLOR_NEUTRAL := Color("#363f3b")
const COLOR_SELECTED := Color("#f3d28a")
const COLOR_TEXT := Color("#d6dfd4")
const COLOR_MUTED := Color("#899b91")

var world
var selected_region_id: String = ""
var selected_unit_id: String = ""
var supply_overlay: bool = false
var map_rect := Rect2()
var outline_polygon := PackedVector2Array()
var cell_polygons: Array[PackedVector2Array] = []
var cached_region_count: int = -1
var cached_size := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_process(true)

func update_view(next_world, region_id: String, unit_id: String, show_supply: bool) -> void:
	world = next_world
	selected_region_id = region_id
	selected_unit_id = unit_id
	supply_overlay = show_supply
	if world != null and (cached_region_count != world.regions.size() or cached_size != size):
		_build_geometry()
	queue_redraw()

func _process(_delta: float) -> void:
	if world != null and (cached_region_count != world.regions.size() or cached_size != size):
		_build_geometry()
		queue_redraw()

func _build_geometry() -> void:
	if world == null:
		return
	cached_region_count = world.regions.size()
	cached_size = size
	map_rect = Rect2(Vector2(44, 70), Vector2(maxf(100.0, size.x - 88), maxf(100.0, size.y - 142)))
	outline_polygon = PackedVector2Array()
	for point in OUTLINE_NORMALIZED:
		outline_polygon.append(_map_point(point))
	cell_polygons.clear()
	for i in range(world.regions.size()):
		var polygon := outline_polygon.duplicate()
		var center_i := _region_point(world.regions[i])
		for j in range(world.regions.size()):
			if i == j:
				continue
			var center_j := _region_point(world.regions[j])
			var normal := 2.0 * (center_j - center_i)
			var limit := center_j.length_squared() - center_i.length_squared()
			polygon = _clip_half_plane(polygon, normal, limit)
			if polygon.is_empty():
				break
		cell_polygons.append(polygon)

func _map_point(point: Vector2) -> Vector2:
	return map_rect.position + Vector2(point.x * map_rect.size.x, point.y * map_rect.size.y)

func _region_point(region: Dictionary) -> Vector2:
	var center: Array = region.get("center", [0.5, 0.5])
	return _map_point(Vector2(float(center[0]), float(center[1])))

func _clip_half_plane(polygon: PackedVector2Array, normal: Vector2, limit: float) -> PackedVector2Array:
	var output := PackedVector2Array()
	if polygon.size() < 3:
		return output
	var previous: Vector2 = polygon[polygon.size() - 1]
	var previous_inside: bool = normal.dot(previous) <= limit + 0.01
	for current in polygon:
		var current_inside: bool = normal.dot(current) <= limit + 0.01
		if current_inside != previous_inside:
			var edge := current - previous
			var denominator := normal.dot(edge)
			if absf(denominator) > 0.0001:
				var amount := (limit - normal.dot(previous)) / denominator
				output.append(previous.lerp(current, clampf(amount, 0.0, 1.0)))
		if current_inside:
			output.append(current)
		previous = current
		previous_inside = current_inside
	return output

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	for gx in range(0, int(size.x), 36):
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), COLOR_GRID, 1.0)
	for gy in range(0, int(size.y), 36):
		draw_line(Vector2(0, gy), Vector2(size.x, gy), COLOR_GRID, 1.0)
	if world == null:
		return
	if cached_region_count != world.regions.size() or cached_size != size:
		_build_geometry()
	_draw_cartographic_decoration()
	for i in range(world.regions.size()):
		var region: Dictionary = world.regions[i]
		if i >= cell_polygons.size():
			continue
		var poly: PackedVector2Array = cell_polygons[i]
		if poly.size() < 3:
			continue
		var fill := _owner_color(str(region.get("owner", "neutral")))
		if supply_overlay:
			var supply_factor := float(region.get("supply", 0.5))
			fill = fill.lerp(Color("#d1bd80"), supply_factor * 0.45)
		if str(region.get("id", "")) == selected_region_id:
			fill = fill.lerp(COLOR_SELECTED, 0.24)
		draw_colored_polygon(poly, fill)
		draw_polyline(_closed(poly), COLOR_BORDER, 1.2, true)
		var center := _region_point(region)
		var label := str(region.get("name", "REGION"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-float(label.length()) * 3.15, 4), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_TEXT)
		if bool(region.get("capital", false)):
			draw_circle(center + Vector2(0, -10), 4.0, COLOR_SELECTED)
			draw_arc(center + Vector2(0, -10), 7.0, 0.0, TAU, 20, Color("#1a2422"), 1.1)
	_draw_units()
	_draw_map_frame()

func _draw_cartographic_decoration() -> void:
	if outline_polygon.size() < 3:
		return
	var shadow := PackedVector2Array()
	for p in outline_polygon:
		shadow.append(p + Vector2(7, 9))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.20))
	draw_colored_polygon(outline_polygon, Color("#232d2a"))
	for i in range(12):
		var y := map_rect.position.y + map_rect.size.y * (0.13 + float(i) * 0.057)
		var line := PackedVector2Array()
		for step_index in range(30):
			var x := map_rect.position.x + map_rect.size.x * float(step_index) / 29.0
			var wave := sin(float(step_index) * 0.45 + float(i) * 0.7) * (5.0 + float(i % 3) * 2.0)
			line.append(Vector2(x, y + wave))
		draw_polyline(line, Color(0.58, 0.67, 0.58, 0.035), 1.0, true)

func _draw_units() -> void:
	for unit in world.units:
		var region := world.get_region(str(unit["province_id"]))
		if region.is_empty():
			continue
		var position := _region_point(region) + Vector2(0, 17)
		if not str(unit.get("target", "")).is_empty():
			var target_region := world.get_region(str(unit["target"]))
			if not target_region.is_empty():
				draw_line(position, _region_point(target_region) + Vector2(0, 17), Color(0.9, 0.83, 0.59, 0.35), 1.4, true)
		var color := Color("#66d4b4") if str(unit["owner"]) == "player" else Color("#e89a7b")
		if str(unit["id"]) == selected_unit_id:
			draw_circle(position, 13.0, Color(0.95, 0.82, 0.53, 0.18))
			draw_arc(position, 14.0, 0.0, TAU, 28, COLOR_SELECTED, 2.0)
		draw_circle(position, 8.5, Color("#101715"))
		draw_circle(position, 6.0, color)
		draw_circle(position, 1.9, Color("#f1f0dd"))

func _draw_map_frame() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(30, 32), "ATLAS THEATER  /  REGIONAL CONTROL MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b6c6b8"))
	draw_string(ThemeDB.fallback_font, Vector2(30, 52), "ILLUSTRATIVE WORLD • REGION BORDERS ARE PROCEDURAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_MUTED)
	draw_line(Vector2(28, 60), Vector2(size.x - 28, 60), Color(0.56, 0.66, 0.57, 0.23), 1.0)
	var legend_y := size.y - 28
	draw_circle(Vector2(42, legend_y - 3), 5.0, Color("#66d4b4"))
	draw_string(ThemeDB.fallback_font, Vector2(54, legend_y), "ATLAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_TEXT)
	draw_circle(Vector2(122, legend_y - 3), 5.0, Color("#e89a7b"))
	draw_string(ThemeDB.fallback_font, Vector2(134, legend_y), "MERIDIAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_TEXT)
	draw_circle(Vector2(230, legend_y - 3), 5.0, Color("#737e74"))
	draw_string(ThemeDB.fallback_font, Vector2(242, legend_y), "UNADMINISTERED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_TEXT)

func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var closed := poly.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed

func _owner_color(owner: String) -> Color:
	match owner:
		"player":
			return COLOR_PLAYER
		"rival":
			return COLOR_RIVAL
		_:
			return COLOR_NEUTRAL

func _region_at(position: Vector2) -> String:
	if outline_polygon.size() < 3 or not Geometry2D.is_point_in_polygon(position, outline_polygon):
		return ""
	var nearest_id := ""
	var nearest_distance := INF
	for region in world.regions:
		var center := _region_point(region)
		var distance := center.distance_to(position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = str(region["id"])
	return nearest_id

func _unit_at(position: Vector2) -> String:
	var best_id := ""
	var best_distance := 18.0
	for unit in world.units:
		var region := world.get_region(str(unit["province_id"]))
		if region.is_empty():
			continue
		var unit_position := _region_point(region) + Vector2(0, 17)
		var distance := unit_position.distance_to(position)
		if distance < best_distance:
			best_distance = distance
			best_id = str(unit["id"])
	return best_id

func _gui_input(event: InputEvent) -> void:
	if world == null or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or (mouse_event.button_index != MOUSE_BUTTON_LEFT and mouse_event.button_index != MOUSE_BUTTON_RIGHT):
		return
	var region_id := _region_at(mouse_event.position)
	if region_id.is_empty():
		return
	var unit_id := ""
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		unit_id = _unit_at(mouse_event.position)
	map_tapped.emit(region_id, mouse_event.button_index, unit_id)
	accept_event()
