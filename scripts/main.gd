extends Control

const WorldStateScript = preload("res://scripts/world_state.gd")
const MapViewScript = preload("res://scripts/map_view.gd")

const COLOR_BG := Color("#0b1113")
const COLOR_PANEL := Color("#141e1f")
const COLOR_PANEL_ALT := Color("#192526")
const COLOR_BORDER := Color("#354644")
const COLOR_TEXT := Color("#d8e1d6")
const COLOR_MUTED := Color("#8fa198")
const COLOR_ACCENT := Color("#78d3b3")
const COLOR_WARN := Color("#e6c885")

var world
var map_view
var selected_region_id: String = "cairn"
var selected_unit_id: String = ""
var movement_mode: bool = false
var paused: bool = false
var speed_index: int = 0
var speed_values: Array[float] = [1.0, 2.0, 4.0]
var speed_names: Array[String] = ["1×", "2×", "4×"]
var supply_overlay: bool = false
var refresh_clock: float = 0.0

var clock_label: Label
var pause_button: Button
var speed_button: Button
var status_label: Label
var resource_label: Label
var region_name_label: Label
var region_owner_label: Label
var region_info_label: Label
var region_neighbors_label: Label
var unit_name_label: Label
var unit_stats_label: Label
var unit_order_label: Label
var order_button: Button
var hold_button: Button
var supply_button: Button
var counts_label: Label
var log_label: Label
var instruction_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	world = WorldStateScript.new()
	_build_interface()
	_update_all()

func _process(delta: float) -> void:
	if not paused:
		world.step(delta * speed_values[speed_index])
	refresh_clock += delta
	if refresh_clock >= 0.15:
		refresh_clock = 0.0
		_update_all()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)

func _build_interface() -> void:
	map_view = MapViewScript.new()
	map_view.position = Vector2(0, 72)
	map_view.size = Vector2(1510, 898)
	map_view.map_tapped.connect(_on_map_tapped)
	add_child(map_view)

	_build_top_bar()
	_build_right_panel()
	_build_bottom_log()

func _build_top_bar() -> void:
	var panel := _make_panel(Vector2(0, 0), Vector2(1920, 72), COLOR_PANEL, Color("#2d3e3d"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	var title := _make_label(brand, "FRONTLINE COMMAND", 23, COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 22)
	_make_label(brand, "ATLAS  /  THEATER SIMULATION", 10, COLOR_MUTED)
	row.add_child(brand)

	var divider := ColorRect.new()
	divider.color = Color("#3a4d49")
	divider.custom_minimum_size = Vector2(1, 38)
	row.add_child(divider)

	status_label = _make_label(row, "SIMULATION ACTIVE", 12, COLOR_ACCENT)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	resource_label = _make_label(row, "SUPPLY  220", 13, COLOR_WARN)
	clock_label = _make_label(row, "DAY 01 • 00:00", 13, COLOR_TEXT)
	pause_button = _make_button(row, "PAUSE", _toggle_pause, 120, 40)
	speed_button = _make_button(row, "SPEED 1×", _cycle_speed, 128, 40)

func _build_right_panel() -> void:
	var panel := _make_panel(Vector2(1518, 82), Vector2(390, 835), COLOR_PANEL, Color("#30413e"))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	_make_label(column, "COMMAND OVERVIEW", 11, COLOR_ACCENT)
	_make_label(column, "REGION INTELLIGENCE", 19, COLOR_TEXT)
	region_name_label = _make_label(column, "CAIRN", 21, COLOR_WARN)
	region_owner_label = _make_label(column, "ADMINISTERED BY ATLAS", 12, COLOR_ACCENT)
	region_info_label = _make_label(column, "Terrain / supply / strategic value", 12, COLOR_MUTED)
	region_neighbors_label = _make_label(column, "Adjacent regions: —", 11, COLOR_MUTED)
	_add_separator(column)

	_make_label(column, "FIELD GROUP SELECTED", 11, COLOR_ACCENT)
	unit_name_label = _make_label(column, "NO GROUP SELECTED", 17, COLOR_TEXT)
	unit_stats_label = _make_label(column, "Select a group marker on the map.", 12, COLOR_MUTED)
	unit_order_label = _make_label(column, "Current order: —", 12, COLOR_WARN)
	instruction_label = _make_label(column, "Choose a group, then issue an order and click a destination.", 11, COLOR_MUTED)
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	order_button = _make_button(column, "ISSUE MOVEMENT ORDER", _arm_movement, 0, 42)
	hold_button = _make_button(column, "HOLD POSITION", _hold_selected, 0, 38)
	_make_button(column, "SELECT NEXT GROUP", _select_next_group, 0, 38)
	supply_button = _make_button(column, "SUPPLY OVERLAY: OFF", _toggle_supply, 0, 38)
	_add_separator(column)

	_make_label(column, "REGIONAL CONTROL", 11, COLOR_ACCENT)
	counts_label = _make_label(column, "ATLAS  09   /   MERIDIAN  06   /   OPEN  19", 12, COLOR_TEXT)
	counts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_make_label(column, "OBJECTIVE", 11, COLOR_ACCENT)
	var objective := _make_label(column, "Administer 25 of 34 regions to secure the theater.", 12, COLOR_MUTED)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_make_button(column, "RESTART SCENARIO", _restart_scenario, 0, 36)

func _build_bottom_log() -> void:
	var panel := _make_panel(Vector2(0, 970), Vector2(1510, 110), COLOR_PANEL, Color("#2b3b39"))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	_make_label(column, "OPERATIONS LOG  /  LATEST DEVELOPMENTS", 10, COLOR_ACCENT)
	log_label = _make_label(column, "Simulation initialized.", 12, COLOR_TEXT)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _make_panel(position_value: Vector2, size_value: Vector2, fill: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position_value
	panel.size = size_value
	panel.add_theme_stylebox_override("panel", _style(fill, border, 8, 12))
	add_child(panel)
	return panel

func _style(fill: Color, border: Color, radius: int = 5, margin: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func _make_label(parent: Node, text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _make_button(parent: Node, text_value: String, callback: Callable, width: float, height: float) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(width, height)
	if width <= 0.0:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color("#f4e5bd"))
	button.add_theme_stylebox_override("normal", _style(COLOR_PANEL_ALT, COLOR_BORDER, 4, 7))
	button.add_theme_stylebox_override("hover", _style(Color("#243433"), COLOR_ACCENT, 4, 7))
	button.add_theme_stylebox_override("pressed", _style(Color("#30443e"), COLOR_ACCENT, 4, 7))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _add_separator(parent: Node) -> void:
	var line := HSeparator.new()
	line.add_theme_color_override("separator", Color("#334542"))
	parent.add_child(line)

func _on_map_tapped(region_id: String, button: int, unit_id: String) -> void:
	if unit_id != "":
		selected_unit_id = unit_id
		selected_region_id = str(world.get_unit(unit_id).get("province_id", region_id))
		movement_mode = false
		_update_all()
		return
	if movement_mode or (button == MOUSE_BUTTON_RIGHT and selected_unit_id != ""):
		if selected_unit_id != "":
			world.issue_move(selected_unit_id, region_id)
		else:
			world.add_log("Select a field group before issuing a movement order.")
		movement_mode = false
	else:
		selected_region_id = region_id
	_update_all()

func _arm_movement() -> void:
	if selected_unit_id.is_empty():
		world.add_log("Select a field group marker first.")
		return
	movement_mode = true
	instruction_label.text = "ORDER MODE ACTIVE — click a destination region on the map."
	_update_all()

func _hold_selected() -> void:
	if selected_unit_id.is_empty():
		world.add_log("Select a field group marker first.")
		return
	world.hold_unit(selected_unit_id)
	movement_mode = false
	_update_all()

func _select_next_group() -> void:
	var friendly: Array[Dictionary] = world.faction_units("player")
	if friendly.is_empty():
		return
	var current_index := -1
	for i in range(friendly.size()):
		if str(friendly[i]["id"]) == selected_unit_id:
			current_index = i
			break
	var next_index := (current_index + 1) % friendly.size()
	selected_unit_id = str(friendly[next_index]["id"])
	selected_region_id = str(friendly[next_index]["province_id"])
	movement_mode = false
	_update_all()

func _toggle_supply() -> void:
	supply_overlay = not supply_overlay
	_update_all()

func _toggle_pause() -> void:
	paused = not paused
	_update_all()

func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % speed_values.size()
	_update_all()

func _restart_scenario() -> void:
	world = WorldStateScript.new()
	selected_region_id = "cairn"
	selected_unit_id = ""
	movement_mode = false
	paused = false
	speed_index = 0
	supply_overlay = false
	_update_all()

func _update_all() -> void:
	if world == null:
		return
	if map_view != null:
		map_view.update_view(world, selected_region_id, selected_unit_id, supply_overlay)
	if clock_label != null:
		clock_label.text = _format_clock()
		pause_button.text = "RESUME" if paused else "PAUSE"
		speed_button.text = "SPEED " + speed_names[speed_index]
		resource_label.text = "SUPPLY  " + str(world.resources)
		status_label.text = "SIMULATION PAUSED" if paused else ("VICTORY" if world.winner == "player" else ("SCENARIO ENDED" if world.winner == "rival" else "SIMULATION ACTIVE"))
		status_label.add_theme_color_override("font_color", COLOR_WARN if paused or world.winner != "" else COLOR_ACCENT)
	if region_name_label != null:
		var region: Dictionary = world.get_region(selected_region_id)
		if region.is_empty():
			region = world.regions[0]
			selected_region_id = str(region["id"])
		region_name_label.text = str(region["name"]).to_upper()
		var owner: String = str(region["owner"])
		region_owner_label.text = "ADMINISTERED BY " + _owner_name(owner).to_upper()
		region_owner_label.add_theme_color_override("font_color", _owner_color(owner))
		region_info_label.text = "Terrain: %s   •   Strategic value: %s" % [str(region["terrain"]), str(region["strategic"])]
		region_neighbors_label.text = "Connected regions: " + str(region["neighbors"].size())
	if unit_name_label != null:
		var unit: Dictionary = world.get_unit(selected_unit_id)
		if unit.is_empty():
			unit_name_label.text = "NO GROUP SELECTED"
			unit_stats_label.text = "Click a group marker on the map or use SELECT NEXT GROUP."
			unit_order_label.text = "Current order: —"
		else:
			unit_name_label.text = str(unit["name"]).to_upper()
			unit_stats_label.text = "Strength %d   •   Readiness %d%%\nSupply %d%%" % [roundi(float(unit["strength"])), roundi(float(unit["readiness"]) * 100.0), roundi(float(unit["supply"]) * 100.0)]
			var target: String = str(unit.get("target", ""))
			unit_order_label.text = "Current order: " + (str(world.get_region(target).get("name", target)) if not target.is_empty() else "Hold / occupy")
		if movement_mode:
			instruction_label.text = "ORDER MODE ACTIVE — click a destination region."
		elif selected_unit_id.is_empty():
			instruction_label.text = "Choose a group marker, then issue an order. Right-click is a quick order."
		else:
			instruction_label.text = "Left-click regions to inspect. Right-click a region for a quick order."
		order_button.text = "CHOOSE DESTINATION" if movement_mode else "ISSUE MOVEMENT ORDER"
		hold_button.disabled = selected_unit_id.is_empty()
		order_button.disabled = selected_unit_id.is_empty()
		supply_button.text = "SUPPLY OVERLAY: ON" if supply_overlay else "SUPPLY OVERLAY: OFF"
	if counts_label != null:
		var atlas := world.count_regions("player")
		var meridian := world.count_regions("rival")
		var open_count := world.count_regions("neutral")
		counts_label.text = "ATLAS  %02d   /   MERIDIAN  %02d   /   OPEN  %02d" % [atlas, meridian, open_count]
	if log_label != null:
		var line_count: int = mini(3, world.log_messages.size())
		var recent: Array[String] = []
		for i in range(line_count):
			recent.append(world.log_messages[i])
		log_label.text = "\n".join(recent)

func _format_clock() -> String:
	var total_minutes := int(world.elapsed_seconds * 2.0)
	var day := 1 + int(total_minutes / 1440)
	var hour := int((total_minutes % 1440) / 60)
	var minute := total_minutes % 60
	return "DAY %02d  •  %02d:%02d" % [day, hour, minute]

func _owner_name(owner: String) -> String:
	match owner:
		"player":
			return "Atlas Command"
		"rival":
			return "Meridian Coalition"
		_:
			return "Unadministered"

func _owner_color(owner: String) -> Color:
	match owner:
		"player":
			return COLOR_ACCENT
		"rival":
			return Color("#e89a7b")
		_:
			return COLOR_MUTED
