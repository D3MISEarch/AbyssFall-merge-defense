extends Control

const BOARD_COLUMNS := 5
const BOARD_ROWS := 3
const EMPTY_TILE_TEXT := "Empty"
const MAX_LEVEL := 3

const LANE_COUNT := 3
const LANE_LENGTH := 8
const SPAWN_INTERVAL_SECONDS := 2.0
const ADVANCE_INTERVAL_SECONDS := 1.0
const BASE_GATE_HP := 100

const UNIT_ROTATION := ["Lane Guard", "Hunter", "Cleave Bot", "Banner"]
const ROLE_TAGS := {
	"lane": "HOLD",
	"single": "BURST",
	"cleave": "AOE",
	"support": "AURA"
}
const UNIT_SHORT_NAMES := {
	"Lane Guard": "Guard",
	"Hunter": "Hunter",
	"Cleave Bot": "Cleave",
	"Banner": "Banner"
}
const UNIT_DEFINITIONS := {
	"Lane Guard": {
		"role": "lane",
		"label": "Lane Holder",
		"base_damage": 2,
		"level_damage_multiplier": {1: 2, 2: 3, 3: 4},
		"lane_bonus": 1,
		"crowd_bonus": 2,
		"crowd_threshold": 2,
		"value_text": "Best anchor when one lane gets crowded."
	},
	"Hunter": {
		"role": "single",
		"label": "Priority Burst",
		"base_damage": 1,
		"level_damage_multiplier": {1: 2, 2: 4, 3: 7},
		"focus_bonus": 3,
		"execute_range": 2,
		"execute_bonus": 2,
		"value_text": "Deletes the enemy closest to your gate."
	},
	"Cleave Bot": {
		"role": "cleave",
		"label": "Wave Clear",
		"base_damage": 2,
		"level_damage_multiplier": {1: 1, 2: 2, 3: 3},
		"splash_ratio": 1.0,
		"value_text": "Most efficient when lanes have 2+ enemies."
	},
	"Banner": {
		"role": "support",
		"label": "Lane Support",
		"base_damage": 0,
		"level_damage_multiplier": {1: 0, 2: 0, 3: 0},
		"lane_buff_per_level": 2,
		"value_text": "Pure force multiplier for every ally in its lane."
	}
}

var next_unit := 0
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
@onready var unit_detail_label: Label = $UnitDetailPanel/UnitDetailLabel
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
		label.anchors_preset = Control.PRESET_FULL_RECT
		label.offset_left = 8.0
		label.offset_top = 8.0
		label.offset_right = -8.0
		label.offset_bottom = -8.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_update_selection_detail()

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

	var summoned_name := UNIT_ROTATION[next_unit]
	next_unit = (next_unit + 1) % UNIT_ROTATION.size()
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
		_update_selection_detail()
		_render_board()
		return

	if selected_tile_index == -1:
		selected_tile_index = tile_index
		status_label.text = "Selected tile %d: %s." % [tile_index + 1, _format_unit(board_units[tile_index])]
		_update_selection_detail()
		_render_board()
		return

	if selected_tile_index == tile_index:
		selected_tile_index = -1
		status_label.text = "Selection cleared."
		_update_selection_detail()
		_render_board()
		return

	_attempt_merge(selected_tile_index, tile_index)

func _attempt_merge(from_index: int, to_index: int) -> void:
	var from_unit := board_units[from_index]
	var to_unit := board_units[to_index]

	if from_unit["name"] != to_unit["name"]:
		status_label.text = "Invalid merge: unit names do not match."
		selected_tile_index = -1
		_update_selection_detail()
		_render_board()
		return

	if from_unit["level"] != to_unit["level"]:
		status_label.text = "Invalid merge: unit levels do not match."
		selected_tile_index = -1
		_update_selection_detail()
		_render_board()
		return

	if int(to_unit["level"]) >= MAX_LEVEL:
		status_label.text = "Invalid merge: %s is already at max level." % _format_unit(to_unit)
		selected_tile_index = -1
		_update_selection_detail()
		_render_board()
		return

	board_units[from_index] = {}
	board_units[to_index] = {"name": to_unit["name"], "level": int(to_unit["level"]) + 1}
	status_label.text = "Merged into %s on tile %d." % [_format_unit(board_units[to_index]), to_index + 1]
	selected_tile_index = -1
	_update_selection_detail()
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

		var lane_support_bonus := _get_lane_support_bonus(lane_index)
		for column in BOARD_COLUMNS:
			var tile_index := lane_index * BOARD_COLUMNS + column
			if tile_index >= board_units.size() or _is_tile_empty(tile_index):
				continue
			if enemy_lanes[lane_index].is_empty():
				break

			var unit := board_units[tile_index]
			var role := _get_unit_role(unit)
			var damage := _get_unit_base_damage(unit)

			if role == "support":
				continue

			damage += lane_support_bonus
			if role == "lane":
				damage += int(_get_unit_stat(unit, "lane_bonus", 0))
				if enemy_lanes[lane_index].size() >= int(_get_unit_stat(unit, "crowd_threshold", 99)):
					damage += int(_get_unit_stat(unit, "crowd_bonus", 0))
			elif role == "single":
				damage += int(_get_unit_stat(unit, "focus_bonus", 0))
				var front_progress := _get_front_enemy_progress(lane_index)
				if LANE_LENGTH - front_progress <= int(_get_unit_stat(unit, "execute_range", 0)):
					damage += int(_get_unit_stat(unit, "execute_bonus", 0))

			_damage_front_enemy(lane_index, damage)
			if role == "cleave":
				var splash_ratio := float(_get_unit_stat(unit, "splash_ratio", 0.0))
				var splash_damage := int(round(float(damage) * splash_ratio))
				_damage_secondary_enemy(lane_index, splash_damage)

func _damage_front_enemy(lane_index: int, damage: int) -> void:
	if damage <= 0 or enemy_lanes[lane_index].is_empty():
		return

	var front_index := _get_front_enemy_index(enemy_lanes[lane_index])
	var enemy := enemy_lanes[lane_index][front_index]
	enemy["hp"] = int(enemy["hp"]) - damage

	if int(enemy["hp"]) <= 0:
		enemy_lanes[lane_index].remove_at(front_index)
		status_label.text = "Lane %d enemy defeated by %d damage." % [lane_index + 1, damage]
	else:
		enemy_lanes[lane_index][front_index] = enemy

func _damage_secondary_enemy(lane_index: int, damage: int) -> void:
	if damage <= 0 or enemy_lanes[lane_index].size() < 2:
		return

	var sorted_indices := _get_enemy_indices_by_progress(enemy_lanes[lane_index])
	var secondary_index := sorted_indices[1]
	var enemy := enemy_lanes[lane_index][secondary_index]
	enemy["hp"] = int(enemy["hp"]) - damage

	if int(enemy["hp"]) <= 0:
		enemy_lanes[lane_index].remove_at(secondary_index)
		status_label.text = "Lane %d cleave splash defeated an enemy." % [lane_index + 1]
	else:
		enemy_lanes[lane_index][secondary_index] = enemy

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
		tile_labels[i].text = _format_tile_unit(board_units[i]) if occupied else EMPTY_TILE_TEXT

		if i == selected_tile_index:
			tile_panels[i].self_modulate = Color(0.92, 0.75, 0.32, 1.0)
		else:
			if not occupied:
				tile_panels[i].self_modulate = Color(0.22, 0.24, 0.31, 1.0)
			elif _get_unit_role(board_units[i]) == "support":
				tile_panels[i].self_modulate = Color(0.33, 0.33, 0.54, 1.0)
			else:
				tile_panels[i].self_modulate = Color(0.31, 0.47, 0.38, 1.0)
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

func _get_front_enemy_progress(lane_index: int) -> int:
	if enemy_lanes[lane_index].is_empty():
		return 0
	var front_index := _get_front_enemy_index(enemy_lanes[lane_index])
	return int(enemy_lanes[lane_index][front_index]["progress"])

func _get_enemy_indices_by_progress(lane_enemies: Array) -> Array[int]:
	var ordered_indices: Array[int] = []
	for i in lane_enemies.size():
		ordered_indices.append(i)

	ordered_indices.sort_custom(func(a: int, b: int) -> bool:
		return int(lane_enemies[a]["progress"]) > int(lane_enemies[b]["progress"])
	)
	return ordered_indices

func _get_lane_support_bonus(lane_index: int) -> int:
	var bonus := 0
	for column in BOARD_COLUMNS:
		var tile_index := lane_index * BOARD_COLUMNS + column
		if tile_index >= board_units.size() or _is_tile_empty(tile_index):
			continue
		var unit := board_units[tile_index]
		if _get_unit_role(unit) != "support":
			continue
		bonus += int(_get_unit_stat(unit, "lane_buff_per_level", 0)) * int(unit["level"])
	return bonus

func _get_board_power() -> int:
	var total_power := 0
	for lane_index in LANE_COUNT:
		var lane_support_bonus := _get_lane_support_bonus(lane_index)
		for column in BOARD_COLUMNS:
			var tile_index := lane_index * BOARD_COLUMNS + column
			if tile_index >= board_units.size() or _is_tile_empty(tile_index):
				continue
			var unit := board_units[tile_index]
			var role := _get_unit_role(unit)
			var unit_power := _get_unit_base_damage(unit)
			if role == "support":
				var ally_count := _get_lane_non_support_count(lane_index)
				unit_power = int(_get_unit_stat(unit, "lane_buff_per_level", 0)) * int(unit["level"]) * max(1, ally_count)
			else:
				unit_power += lane_support_bonus
				if role == "lane":
					unit_power += int(_get_unit_stat(unit, "lane_bonus", 0))
					unit_power += int(_get_unit_stat(unit, "crowd_bonus", 0))
				elif role == "single":
					unit_power += int(_get_unit_stat(unit, "focus_bonus", 0))
					unit_power += int(_get_unit_stat(unit, "execute_bonus", 0))
				elif role == "cleave":
					unit_power += int(round(float(unit_power) * float(_get_unit_stat(unit, "splash_ratio", 0.0))))
			total_power += unit_power
	return total_power

func _get_lane_non_support_count(lane_index: int) -> int:
	var count := 0
	for column in BOARD_COLUMNS:
		var tile_index := lane_index * BOARD_COLUMNS + column
		if tile_index >= board_units.size() or _is_tile_empty(tile_index):
			continue
		if _get_unit_role(board_units[tile_index]) == "support":
			continue
		count += 1
	return count

func _get_unit_base_damage(unit: Dictionary) -> int:
	var level := int(unit["level"])
	var unit_info := _get_unit_definition(unit)
	var multipliers := unit_info.get("level_damage_multiplier", {})
	var level_multiplier := int(multipliers.get(level, level))
	return int(unit_info.get("base_damage", 0)) * level_multiplier

func _get_unit_role(unit: Dictionary) -> String:
	return str(_get_unit_definition(unit).get("role", "single"))

func _get_unit_definition(unit: Dictionary) -> Dictionary:
	var unit_name := str(unit.get("name", ""))
	return UNIT_DEFINITIONS.get(unit_name, UNIT_DEFINITIONS["Hunter"])

func _get_unit_stat(unit: Dictionary, stat_name: String, default_value: Variant) -> Variant:
	return _get_unit_definition(unit).get(stat_name, default_value)

func _find_empty_tile() -> int:
	for i in board_units.size():
		if _is_tile_empty(i):
			return i
	return -1

func _is_tile_empty(tile_index: int) -> bool:
	return board_units[tile_index].is_empty()

func _format_unit(unit: Dictionary) -> String:
	var role_label := str(_get_unit_definition(unit).get("label", "Role"))
	var damage := _get_unit_base_damage(unit)
	var effect_text := _get_unit_effect_text(unit)
	return "%s Lv%d | %s | %d ATK | %s" % [unit["name"], int(unit["level"]), role_label, damage, effect_text]

func _format_tile_unit(unit: Dictionary) -> String:
	var role_tag := _get_unit_role_tag(unit)
	var unit_name := _get_unit_short_name(unit)
	var atk_text := "%d ATK" % _get_unit_base_damage(unit)
	if _get_unit_role(unit) == "support":
		atk_text = "Buff +%d" % (int(_get_unit_stat(unit, "lane_buff_per_level", 0)) * int(unit["level"]))
	return "%s\nL%d %s\n%s" % [unit_name, int(unit["level"]), role_tag, atk_text]

func _get_unit_short_name(unit: Dictionary) -> String:
	return str(UNIT_SHORT_NAMES.get(str(unit.get("name", "")), unit.get("name", "Unit")))

func _get_unit_role_tag(unit: Dictionary) -> String:
	return str(ROLE_TAGS.get(_get_unit_role(unit), ""))

func _get_unit_effect_text(unit: Dictionary) -> String:
	var role := _get_unit_role(unit)
	var level := int(unit["level"])
	if role == "lane":
		return "+%d flat, +%d when %d+ enemies in lane" % [
			int(_get_unit_stat(unit, "lane_bonus", 0)),
			int(_get_unit_stat(unit, "crowd_bonus", 0)),
			int(_get_unit_stat(unit, "crowd_threshold", 2))
		]
	if role == "single":
		return "+%d focus, +%d if enemy is %d tiles from gate" % [
			int(_get_unit_stat(unit, "focus_bonus", 0)),
			int(_get_unit_stat(unit, "execute_bonus", 0)),
			int(_get_unit_stat(unit, "execute_range", 0))
		]
	if role == "cleave":
		var splash_percent := int(round(float(_get_unit_stat(unit, "splash_ratio", 0.0)) * 100.0))
		return "%d%% splash" % splash_percent
	if role == "support":
		var buff_total := int(_get_unit_stat(unit, "lane_buff_per_level", 0)) * level
		return "Lane allies gain +%d damage each" % buff_total
	return "No effect"

func _get_unit_why_text(unit: Dictionary) -> String:
	return str(_get_unit_definition(unit).get("value_text", "Useful for steady lane damage."))

func _update_selection_detail() -> void:
	if selected_tile_index == -1 or _is_tile_empty(selected_tile_index):
		unit_detail_label.text = "Tile Details\nSelect a unit tile to view role, effect, and tactical use."
		return

	var unit := board_units[selected_tile_index]
	var role_label := str(_get_unit_definition(unit).get("label", "Role"))
	unit_detail_label.text = "Tile %d • %s\nRole: %s (%s)\nEffect: %s\nWhy use it: %s" % [
		selected_tile_index + 1,
		_format_unit(unit),
		role_label,
		_get_unit_role_tag(unit),
		_get_unit_effect_text(unit),
		_get_unit_why_text(unit)
	]
