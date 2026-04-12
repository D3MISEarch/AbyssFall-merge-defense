extends Control

const BOARD_COLUMNS := 5
const BOARD_ROWS := 3
const EMPTY_TILE_TEXT := "Empty"
const MAX_LEVEL := 3
const BASE_UNIT_DAMAGE := 1
const LEVEL_DAMAGE_MULTIPLIER := {
	1: 1,
	2: 3,
	3: 6
}

const LANE_COUNT := 3
const LANE_LENGTH := 8
const SPAWN_INTERVAL_SECONDS := 2.0
const ADVANCE_INTERVAL_SECONDS := 1.0
const BASE_GATE_HP := 100

var next_unit := 0
var unit_names := ["Unit A", "Unit B", "Unit C", "Unit D"]
var board_units: Array[Dictionary] = []
var tile_panels: Array[Panel] = []
var tile_labels: Array[Label] = []
var selected_tile_index := -1

var gate_hp := BASE_GATE_HP
var wave_number := 1
var spawned_enemies_total := 0
var next_spawn_lane := 0
var game_over := false
var spawn_timer := 0.0
var advance_timer := 0.0
var enemy_lanes: Array[Array] = []

@onready var summon_button: Button = $TopBar/TopRow/SummonButton
@onready var status_label: Label = $StatusLabel
@onready var wave_label: Label = $TopBar/TopRow/WaveLabel
@onready var gate_label: Label = $TopBar/TopRow/GateLabel
@onready var board_power_label: Label = $TopBar/TopRow/BoardPowerLabel
@onready var loss_label: Label = $LossLabel
@onready var tile_grid: GridContainer = $Board/BoardMargin/BoardContent/TileGrid
@onready var enemy_labels: Array[Label] = [
	$EnemyLane/Enemy1/Enemy1Label,
	$EnemyLane/Enemy2/Enemy2Label,
	$EnemyLane/Enemy3/Enemy3Label
]

func _ready() -> void:
	board_units.resize(BOARD_COLUMNS * BOARD_ROWS)
	for i in board_units.size():
		board_units[i] = {}

	enemy_lanes.resize(LANE_COUNT)
	for lane_index in LANE_COUNT:
		enemy_lanes[lane_index] = []

	for i in tile_grid.get_child_count():
		var tile := tile_grid.get_child(i)
		var panel := tile as Panel
		if panel == null:
			continue
		tile_panels.append(panel)
		var label := panel.get_node("TileLabel") as Label
		tile_labels.append(label)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_tile_gui_input.bind(i))

	summon_button.pressed.connect(_on_summon_pressed)
	_render_board()
	_update_gate_ui()
	_update_wave_ui()
	_update_board_power_ui()
	_update_enemy_lane_ui()
	loss_label.visible = false
	status_label.text = "Prototype loaded. Summon units and hold the gate."

func _process(delta: float) -> void:
	if game_over:
		return

	spawn_timer += delta
	advance_timer += delta

	if spawn_timer >= SPAWN_INTERVAL_SECONDS:
		spawn_timer -= SPAWN_INTERVAL_SECONDS
		_spawn_enemy()

	if advance_timer >= ADVANCE_INTERVAL_SECONDS:
		advance_timer -= ADVANCE_INTERVAL_SECONDS
		_tick_enemy_loop()

func _on_summon_pressed() -> void:
	if game_over:
		status_label.text = "The gate has fallen. Restart the scene to try again."
		return

	var empty_index := _find_empty_tile()
	if empty_index == -1:
		status_label.text = "Board is full. Merge or clear a tile before summoning."
		return

	var summoned_name := unit_names[next_unit]
	next_unit = (next_unit + 1) % unit_names.size()
	board_units[empty_index] = {"name": summoned_name, "level": 1}
	_render_board()
	status_label.text = "Summoned %s into tile %d." % [_format_unit(board_units[empty_index]), empty_index + 1]

func _on_tile_gui_input(event: InputEvent, tile_index: int) -> void:
	if game_over:
		return

	var mouse_button := event as InputEventMouseButton
	if mouse_button == null:
		return
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
		return
	_on_tile_clicked(tile_index)

func _on_tile_clicked(tile_index: int) -> void:
	if _is_tile_empty(tile_index):
		selected_tile_index = -1
		status_label.text = "Selection cleared."
		_render_board()
		return

	if selected_tile_index == -1:
		selected_tile_index = tile_index
		status_label.text = "Selected tile %d: %s." % [tile_index + 1, _format_unit(board_units[tile_index])]
		_render_board()
		return

	if selected_tile_index == tile_index:
		selected_tile_index = -1
		status_label.text = "Selection cleared."
		_render_board()
		return

	_attempt_merge(selected_tile_index, tile_index)

func _attempt_merge(from_index: int, to_index: int) -> void:
	var from_unit := board_units[from_index]
	var to_unit := board_units[to_index]

	if from_unit["name"] != to_unit["name"]:
		status_label.text = "Invalid merge: unit names do not match."
		selected_tile_index = -1
		_render_board()
		return

	if from_unit["level"] != to_unit["level"]:
		status_label.text = "Invalid merge: unit levels do not match."
		selected_tile_index = -1
		_render_board()
		return

	if int(to_unit["level"]) >= MAX_LEVEL:
		status_label.text = "Invalid merge: %s is already at max level." % _format_unit(to_unit)
		selected_tile_index = -1
		_render_board()
		return

	board_units[from_index] = {}
	board_units[to_index] = {"name": to_unit["name"], "level": int(to_unit["level"]) + 1}
	status_label.text = "Merged into %s on tile %d." % [_format_unit(board_units[to_index]), to_index + 1]
	selected_tile_index = -1
	_render_board()

func _spawn_enemy() -> void:
	var lane_index := next_spawn_lane
	next_spawn_lane = (next_spawn_lane + 1) % LANE_COUNT

	var enemy_hp := 2 + wave_number
	var enemy_damage := 5 + wave_number
	var enemy := {
		"name": "W%d Ghoul" % wave_number,
		"hp": enemy_hp,
		"max_hp": enemy_hp,
		"damage": enemy_damage,
		"progress": 0
	}
	enemy_lanes[lane_index].append(enemy)
	spawned_enemies_total += 1

	if spawned_enemies_total % 6 == 0:
		wave_number += 1
		_update_wave_ui()

	status_label.text = "Enemy spawned in lane %d." % [lane_index + 1]
	_update_enemy_lane_ui()

func _tick_enemy_loop() -> void:
	_apply_board_auto_damage()
	_advance_enemies_toward_gate()
	_update_enemy_lane_ui()

func _apply_board_auto_damage() -> void:
	for lane_index in LANE_COUNT:
		if enemy_lanes[lane_index].is_empty():
			continue

		var lane_damage := _get_lane_damage(lane_index)
		if lane_damage <= 0:
			continue

		var target_index := _get_front_enemy_index(enemy_lanes[lane_index])
		var enemy := enemy_lanes[lane_index][target_index]
		enemy["hp"] = int(enemy["hp"]) - lane_damage

		if int(enemy["hp"]) <= 0:
			enemy_lanes[lane_index].remove_at(target_index)
			status_label.text = "Lane %d enemy defeated by %d board damage." % [lane_index + 1, lane_damage]
		else:
			enemy_lanes[lane_index][target_index] = enemy

func _advance_enemies_toward_gate() -> void:
	for lane_index in LANE_COUNT:
		if enemy_lanes[lane_index].is_empty():
			continue

		for enemy_index in range(enemy_lanes[lane_index].size() - 1, -1, -1):
			var enemy := enemy_lanes[lane_index][enemy_index]
			enemy["progress"] = int(enemy["progress"]) + 1

			if int(enemy["progress"]) >= LANE_LENGTH:
				gate_hp = max(0, gate_hp - int(enemy["damage"]))
				enemy_lanes[lane_index].remove_at(enemy_index)
				status_label.text = "The gate was hit from lane %d!" % [lane_index + 1]
			else:
				enemy_lanes[lane_index][enemy_index] = enemy

	_update_gate_ui()
	if gate_hp <= 0:
		_trigger_loss()

func _trigger_loss() -> void:
	if game_over:
		return

	game_over = true
	loss_label.visible = true
	status_label.text = "Gate HP reached 0. You lost this run."

func _render_board() -> void:
	for i in board_units.size():
		var occupied := not _is_tile_empty(i)
		tile_labels[i].text = _format_unit(board_units[i]) if occupied else EMPTY_TILE_TEXT

		if i == selected_tile_index:
			tile_panels[i].self_modulate = Color(0.92, 0.75, 0.32, 1.0)
		else:
			tile_panels[i].self_modulate = Color(0.31, 0.47, 0.38, 1.0) if occupied else Color(0.22, 0.24, 0.31, 1.0)
	_update_board_power_ui()

func _update_wave_ui() -> void:
	wave_label.text = "Wave: %d" % wave_number

func _update_gate_ui() -> void:
	gate_label.text = "Gate HP: %d / %d" % [gate_hp, BASE_GATE_HP]

func _update_board_power_ui() -> void:
	board_power_label.text = "Board Power: %d" % _get_board_power()

func _update_enemy_lane_ui() -> void:
	for lane_index in LANE_COUNT:
		var lane_text := "Lane %d: " % [lane_index + 1]
		if enemy_lanes[lane_index].is_empty():
			enemy_labels[lane_index].text = lane_text + "Clear"
			continue

		var segments: Array[String] = []
		for enemy in enemy_lanes[lane_index]:
			var progress := int(enemy["progress"])
			var distance_to_gate := LANE_LENGTH - progress
			segments.append("[%s HP:%d D:%d]" % [enemy["name"], int(enemy["hp"]), distance_to_gate])
		enemy_labels[lane_index].text = lane_text + " ".join(segments)

func _get_front_enemy_index(lane_enemies: Array) -> int:
	var selected_index := 0
	var furthest_progress := int(lane_enemies[0]["progress"])

	for i in lane_enemies.size():
		var candidate_progress := int(lane_enemies[i]["progress"])
		if candidate_progress > furthest_progress:
			furthest_progress = candidate_progress
			selected_index = i

	return selected_index

func _get_lane_damage(lane_index: int) -> int:
	var total_damage := 0
	for column in BOARD_COLUMNS:
		var tile_index := lane_index * BOARD_COLUMNS + column
		if tile_index >= board_units.size() or _is_tile_empty(tile_index):
			continue
		total_damage += _get_unit_damage(board_units[tile_index])
	return total_damage

func _get_board_power() -> int:
	var total_power := 0
	for unit in board_units:
		if unit.is_empty():
			continue
		total_power += _get_unit_damage(unit)
	return total_power

func _get_unit_damage(unit: Dictionary) -> int:
	var level := int(unit["level"])
	var multiplier := int(LEVEL_DAMAGE_MULTIPLIER.get(level, level))
	return BASE_UNIT_DAMAGE * multiplier

func _find_empty_tile() -> int:
	for i in board_units.size():
		if _is_tile_empty(i):
			return i
	return -1

func _is_tile_empty(tile_index: int) -> bool:
	return board_units[tile_index].is_empty()

func _format_unit(unit: Dictionary) -> String:
	var damage := _get_unit_damage(unit)
	return "%s Lv%d (%d DMG)" % [unit["name"], int(unit["level"]), damage]
