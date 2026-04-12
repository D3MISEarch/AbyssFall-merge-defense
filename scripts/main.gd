extends Control

const BOARD_COLUMNS: int = 5
const BOARD_ROWS: int = 3
const EMPTY_TILE_TEXT: String = "Empty"
const MAX_LEVEL: int = 3

const LANE_COUNT: int = 3
const LANE_LENGTH: int = 8
const SPAWN_INTERVAL_SECONDS: float = 2.0
const ADVANCE_INTERVAL_SECONDS: float = 1.0
const BASE_GATE_HP: int = 100

const UNIT_ROTATION: Array[String] = ["Lane Guard", "Hunter", "Cleave Bot", "Banner"]
const ROLE_TAGS: Dictionary = {
	"lane": "HOLD",
	"single": "BURST",
	"cleave": "AOE",
	"support": "AURA"
}
const UNIT_SHORT_NAMES: Dictionary = {
	"Lane Guard": "Guard",
	"Hunter": "Hunter",
	"Cleave Bot": "Cleave",
	"Banner": "Banner"
}
const UNIT_DEFINITIONS: Dictionary = {
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

const SUPPORT_PANEL_COLOR: Color = Color(0.33, 0.33, 0.54, 1.0)
const ATTACK_PANEL_COLOR: Color = Color(0.31, 0.47, 0.38, 1.0)
const EMPTY_PANEL_COLOR: Color = Color(0.22, 0.24, 0.31, 1.0)
const SELECTED_PANEL_COLOR: Color = Color(0.92, 0.75, 0.32, 1.0)
const MERGE_FLASH_COLOR: Color = Color(0.98, 0.97, 0.72, 1.0)
const LANE_HIT_FLASH_COLOR: Color = Color(0.78, 0.28, 0.28, 1.0)
const LANE_SPLASH_FLASH_COLOR: Color = Color(0.92, 0.62, 0.25, 1.0)
const LANE_AURA_COLOR: Color = Color(0.28, 0.55, 0.84, 1.0)
const LANE_IDLE_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const SUPPORT_AURA_TILE_COLOR: Color = Color(0.52, 0.74, 1.0, 1.0)

var next_unit: int = 0
var board_units: Array[Dictionary] = []
var tile_panels: Array[Panel] = []
var tile_labels: Array[Label] = []
var selected_tile_index: int = -1

var gate_hp: int = BASE_GATE_HP
var wave_number: int = 1
var spawned_enemies_total: int = 0
var next_spawn_lane: int = 0
var game_over: bool = false
var spawn_timer: float = 0.0
var advance_timer: float = 0.0
var enemy_lanes: Array[Array] = []
var support_feedback_lines: Array[String] = []

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
@onready var enemy_panels: Array[Panel] = [
	$EnemyLane/Enemy1,
	$EnemyLane/Enemy2,
	$EnemyLane/Enemy3
]
@onready var top_bar_panel: Panel = $TopBar

func _ready() -> void:
	board_units.resize(BOARD_COLUMNS * BOARD_ROWS)
	for i in board_units.size():
		board_units[i] = {}

	enemy_lanes.resize(LANE_COUNT)
	for lane_index in LANE_COUNT:
		enemy_lanes[lane_index] = []

	for i in tile_grid.get_child_count():
		var tile: Node = tile_grid.get_child(i)
		var panel: Panel = tile as Panel
		if panel == null:
			continue
		tile_panels.append(panel)
		var label: Label = panel.get_node("TileLabel") as Label
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

	var empty_index: int = _find_empty_tile()
	if empty_index == -1:
		status_label.text = "Board is full. Merge or clear a tile before summoning."
		return

	var summoned_name: String = UNIT_ROTATION[next_unit]
	next_unit = (next_unit + 1) % UNIT_ROTATION.size()
	board_units[empty_index] = {"name": summoned_name, "level": 1}
	_render_board()
	_update_support_feedback_ui()
	_update_enemy_lane_ui()
	status_label.text = "Summoned %s into tile %d." % [_format_unit(board_units[empty_index]), empty_index + 1]

func _on_tile_gui_input(event: InputEvent, tile_index: int) -> void:
	if game_over:
		return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
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
	var from_unit: Dictionary = board_units[from_index]
	var to_unit: Dictionary = board_units[to_index]

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
	_show_merge_feedback(to_index)
	selected_tile_index = -1
	_update_selection_detail()
	_render_board()
	_update_support_feedback_ui()
	_update_enemy_lane_ui()

func _spawn_enemy() -> void:
	var lane_index: int = next_spawn_lane
	next_spawn_lane = (next_spawn_lane + 1) % LANE_COUNT

	var enemy_hp: int = 2 + wave_number
	var enemy_damage: int = 5 + wave_number
	var enemy: Dictionary = {
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
	support_feedback_lines.clear()
	for lane_index in LANE_COUNT:
		if enemy_lanes[lane_index].is_empty():
			continue

		var lane_support_bonus: int = _get_lane_support_bonus(lane_index)
		if lane_support_bonus > 0:
			support_feedback_lines.append("L%d aura +%d" % [lane_index + 1, lane_support_bonus])
		for column in BOARD_COLUMNS:
			var tile_index: int = lane_index * BOARD_COLUMNS + column
			if tile_index >= board_units.size() or _is_tile_empty(tile_index):
				continue
			if enemy_lanes[lane_index].is_empty():
				break

			var unit: Dictionary = board_units[tile_index]
			var role: String = _get_unit_role(unit)
			var damage: int = _get_unit_base_damage(unit)

			if role == "support":
				continue

			damage += lane_support_bonus
			var support_contributed: bool = lane_support_bonus > 0
			if role == "lane":
				damage += int(_get_unit_stat(unit, "lane_bonus", 0))
				if enemy_lanes[lane_index].size() >= int(_get_unit_stat(unit, "crowd_threshold", 99)):
					damage += int(_get_unit_stat(unit, "crowd_bonus", 0))
			elif role == "single":
				damage += int(_get_unit_stat(unit, "focus_bonus", 0))
				var front_progress: int = _get_front_enemy_progress(lane_index)
				if LANE_LENGTH - front_progress <= int(_get_unit_stat(unit, "execute_range", 0)):
					damage += int(_get_unit_stat(unit, "execute_bonus", 0))

			_damage_front_enemy(lane_index, damage, support_contributed)
			if role == "cleave":
				var splash_ratio: float = float(_get_unit_stat(unit, "splash_ratio", 0.0))
				var splash_damage: int = int(round(float(damage) * splash_ratio))
				_damage_secondary_enemy(lane_index, splash_damage, support_contributed)
	_update_support_feedback_ui()

func _damage_front_enemy(lane_index: int, damage: int, support_contributed: bool) -> void:
	if damage <= 0 or enemy_lanes[lane_index].is_empty():
		return

	var front_index: int = _get_front_enemy_index(enemy_lanes[lane_index])
	var enemy: Dictionary = enemy_lanes[lane_index][front_index]
	enemy["hp"] = int(enemy["hp"]) - damage
	_spawn_lane_popup(lane_index, "-%d" % damage, Color(1.0, 0.45, 0.45, 1.0), false)
	_flash_lane_panel(lane_index, LANE_HIT_FLASH_COLOR)
	if support_contributed:
		_show_support_aura_feedback(lane_index)

	if int(enemy["hp"]) <= 0:
		enemy_lanes[lane_index].remove_at(front_index)
		status_label.text = "Lane %d enemy defeated by %d damage." % [lane_index + 1, damage]
	else:
		enemy_lanes[lane_index][front_index] = enemy

func _damage_secondary_enemy(lane_index: int, damage: int, support_contributed: bool) -> void:
	if damage <= 0 or enemy_lanes[lane_index].size() < 2:
		return

	var sorted_indices: Array[int] = _get_enemy_indices_by_progress(enemy_lanes[lane_index])
	var secondary_index: int = sorted_indices[1]
	var enemy: Dictionary = enemy_lanes[lane_index][secondary_index]
	enemy["hp"] = int(enemy["hp"]) - damage
	_spawn_lane_popup(lane_index, "SPLASH -%d" % damage, Color(1.0, 0.72, 0.35, 1.0), true)
	_flash_lane_panel(lane_index, LANE_SPLASH_FLASH_COLOR)
	if support_contributed:
		_show_support_aura_feedback(lane_index)

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
			var enemy: Dictionary = enemy_lanes[lane_index][enemy_index]
			enemy["progress"] = int(enemy["progress"]) + 1

			if int(enemy["progress"]) >= LANE_LENGTH:
				var gate_damage: int = int(enemy["damage"])
				gate_hp = max(0, gate_hp - gate_damage)
				enemy_lanes[lane_index].remove_at(enemy_index)
				status_label.text = "The gate was hit from lane %d for %d!" % [lane_index + 1, gate_damage]
				_show_gate_hit_feedback(gate_damage)
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
		var occupied: bool = not _is_tile_empty(i)
		tile_labels[i].text = _format_tile_unit(board_units[i]) if occupied else EMPTY_TILE_TEXT

		if i == selected_tile_index:
			tile_panels[i].self_modulate = SELECTED_PANEL_COLOR
		else:
			if not occupied:
				tile_panels[i].self_modulate = EMPTY_PANEL_COLOR
			elif _get_unit_role(board_units[i]) == "support":
				tile_panels[i].self_modulate = SUPPORT_PANEL_COLOR
			else:
				tile_panels[i].self_modulate = ATTACK_PANEL_COLOR
	_update_board_power_ui()

func _update_wave_ui() -> void:
	wave_label.text = "Wave: %d" % wave_number

func _update_gate_ui() -> void:
	gate_label.text = "Gate HP: %d / %d" % [gate_hp, BASE_GATE_HP]

func _update_board_power_ui() -> void:
	board_power_label.text = "Board Power: %d" % _get_board_power()

func _update_enemy_lane_ui() -> void:
	for lane_index in LANE_COUNT:
		var lane_text: String = "Lane %d: " % [lane_index + 1]
		_set_lane_panel_base_visual(lane_index)
		if enemy_lanes[lane_index].is_empty():
			var clear_line: String = lane_text + "Clear"
			if lane_index < support_feedback_lines.size():
				clear_line += " | " + support_feedback_lines[lane_index]
			enemy_labels[lane_index].text = clear_line
			continue

		var segments: Array[String] = []
		for enemy_data in enemy_lanes[lane_index]:
			var enemy: Dictionary = enemy_data
			var progress: int = int(enemy["progress"])
			var distance_to_gate: int = LANE_LENGTH - progress
			segments.append("[%s HP:%d D:%d]" % [enemy["name"], int(enemy["hp"]), distance_to_gate])
		var lane_line: String = lane_text + " ".join(segments)
		if lane_index < support_feedback_lines.size():
			lane_line += " | " + support_feedback_lines[lane_index]
		enemy_labels[lane_index].text = lane_line

func _get_front_enemy_index(lane_enemies: Array) -> int:
	var selected_index: int = 0
	var first_enemy: Dictionary = lane_enemies[0]
	var furthest_progress: int = int(first_enemy["progress"])

	for i in lane_enemies.size():
		var enemy: Dictionary = lane_enemies[i]
		var candidate_progress: int = int(enemy["progress"])
		if candidate_progress > furthest_progress:
			furthest_progress = candidate_progress
			selected_index = i

	return selected_index

func _get_front_enemy_progress(lane_index: int) -> int:
	if enemy_lanes[lane_index].is_empty():
		return 0
	var front_index: int = _get_front_enemy_index(enemy_lanes[lane_index])
	var enemy: Dictionary = enemy_lanes[lane_index][front_index]
	return int(enemy["progress"])

func _get_enemy_indices_by_progress(lane_enemies: Array) -> Array[int]:
	var ordered_indices: Array[int] = []
	for i in lane_enemies.size():
		ordered_indices.append(i)

	ordered_indices.sort_custom(func(a: int, b: int) -> bool:
		return int(lane_enemies[a]["progress"]) > int(lane_enemies[b]["progress"])
	)
	return ordered_indices

func _get_lane_support_bonus(lane_index: int) -> int:
	var bonus: int = 0
	for column in BOARD_COLUMNS:
		var tile_index: int = lane_index * BOARD_COLUMNS + column
		if tile_index >= board_units.size() or _is_tile_empty(tile_index):
			continue
		var unit: Dictionary = board_units[tile_index]
		if _get_unit_role(unit) != "support":
			continue
		bonus += int(_get_unit_stat(unit, "lane_buff_per_level", 0)) * int(unit["level"])
	return bonus

func _get_board_power() -> int:
	var total_power: int = 0
	for lane_index in LANE_COUNT:
		var lane_support_bonus: int = _get_lane_support_bonus(lane_index)
		for column in BOARD_COLUMNS:
			var tile_index: int = lane_index * BOARD_COLUMNS + column
			if tile_index >= board_units.size() or _is_tile_empty(tile_index):
				continue
			var unit: Dictionary = board_units[tile_index]
			var role: String = _get_unit_role(unit)
			var unit_power: int = _get_unit_base_damage(unit)
			if role == "support":
				var ally_count: int = _get_lane_non_support_count(lane_index)
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
	var count: int = 0
	for column in BOARD_COLUMNS:
		var tile_index: int = lane_index * BOARD_COLUMNS + column
		if tile_index >= board_units.size() or _is_tile_empty(tile_index):
			continue
		if _get_unit_role(board_units[tile_index]) == "support":
			continue
		count += 1
	return count

func _get_unit_base_damage(unit: Dictionary) -> int:
	var level: int = int(unit["level"])
	var unit_info: Dictionary = _get_unit_definition(unit)
	var multipliers: Dictionary = unit_info.get("level_damage_multiplier", {})
	var level_multiplier: int = int(multipliers.get(level, level))
	return int(unit_info.get("base_damage", 0)) * level_multiplier

func _get_unit_role(unit: Dictionary) -> String:
	return str(_get_unit_definition(unit).get("role", "single"))

func _get_unit_definition(unit: Dictionary) -> Dictionary:
	var unit_name: String = str(unit.get("name", ""))
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
	var role_label: String = str(_get_unit_definition(unit).get("label", "Role"))
	var damage: int = _get_unit_base_damage(unit)
	var effect_text: String = _get_unit_effect_text(unit)
	return "%s Lv%d | %s | %d ATK | %s" % [unit["name"], int(unit["level"]), role_label, damage, effect_text]

func _format_tile_unit(unit: Dictionary) -> String:
	var role_tag: String = _get_unit_role_tag(unit)
	var unit_name: String = _get_unit_short_name(unit)
	var atk_text: String = "%d ATK" % _get_unit_base_damage(unit)
	if _get_unit_role(unit) == "support":
		atk_text = "Buff +%d" % (int(_get_unit_stat(unit, "lane_buff_per_level", 0)) * int(unit["level"]))
	return "%s\nL%d %s\n%s" % [unit_name, int(unit["level"]), role_tag, atk_text]

func _get_unit_short_name(unit: Dictionary) -> String:
	return str(UNIT_SHORT_NAMES.get(str(unit.get("name", "")), unit.get("name", "Unit")))

func _get_unit_role_tag(unit: Dictionary) -> String:
	return str(ROLE_TAGS.get(_get_unit_role(unit), ""))

func _get_unit_effect_text(unit: Dictionary) -> String:
	var role: String = _get_unit_role(unit)
	var level: int = int(unit["level"])
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
		var splash_percent: int = int(round(float(_get_unit_stat(unit, "splash_ratio", 0.0)) * 100.0))
		return "%d%% splash" % splash_percent
	if role == "support":
		var buff_total: int = int(_get_unit_stat(unit, "lane_buff_per_level", 0)) * level
		return "Lane allies gain +%d damage each" % buff_total
	return "No effect"

func _get_unit_why_text(unit: Dictionary) -> String:
	return str(_get_unit_definition(unit).get("value_text", "Useful for steady lane damage."))

func _update_selection_detail() -> void:
	if selected_tile_index == -1 or _is_tile_empty(selected_tile_index):
		unit_detail_label.text = "Tile Details\nSelect a unit tile to view role, effect, and tactical use."
		return

	var unit: Dictionary = board_units[selected_tile_index]
	var role_label: String = str(_get_unit_definition(unit).get("label", "Role"))
	unit_detail_label.text = "Tile %d • %s\nRole: %s (%s)\nEffect: %s\nWhy use it: %s" % [
		selected_tile_index + 1,
		_format_unit(unit),
		role_label,
		_get_unit_role_tag(unit),
		_get_unit_effect_text(unit),
		_get_unit_why_text(unit)
	]

func _update_support_feedback_ui() -> void:
	var lines: Array[String] = []
	for lane_index in LANE_COUNT:
		var lane_bonus: int = _get_lane_support_bonus(lane_index)
		if lane_bonus > 0:
			lines.append("L%d aura +%d" % [lane_index + 1, lane_bonus])
		else:
			lines.append("")
	support_feedback_lines = lines

func _show_merge_feedback(tile_index: int) -> void:
	if tile_index < 0 or tile_index >= tile_panels.size():
		return
	var panel: Panel = tile_panels[tile_index]
	var base_color: Color = panel.self_modulate
	var base_scale: Vector2 = panel.scale
	var tween: Tween = create_tween()
	tween.tween_property(panel, "self_modulate", MERGE_FLASH_COLOR, 0.12)
	tween.tween_property(panel, "self_modulate", base_color, 0.20)
	var pulse_up: Vector2 = Vector2(base_scale.x * 1.06, base_scale.y * 1.06)
	var scale_tween: Tween = create_tween()
	scale_tween.tween_property(panel, "scale", pulse_up, 0.10)
	scale_tween.tween_property(panel, "scale", base_scale, 0.14)
	_spawn_floating_text(panel, "LV UP!", Color(0.95, 0.95, 0.5, 1.0), Vector2(22.0, 10.0), 16)

func _show_gate_hit_feedback(damage: int) -> void:
	var tween: Tween = create_tween()
	var base_scale: Vector2 = gate_label.scale
	var hit_scale: Vector2 = Vector2(base_scale.x * 1.1, base_scale.y * 1.1)
	tween.tween_property(gate_label, "modulate", Color(1.0, 0.45, 0.45, 1.0), 0.10)
	tween.tween_property(gate_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22)
	var scale_tween: Tween = create_tween()
	scale_tween.tween_property(gate_label, "scale", hit_scale, 0.10)
	scale_tween.tween_property(gate_label, "scale", base_scale, 0.16)
	var bar_tween: Tween = create_tween()
	bar_tween.tween_property(top_bar_panel, "self_modulate", Color(1.0, 0.63, 0.63, 1.0), 0.12)
	bar_tween.tween_property(top_bar_panel, "self_modulate", Color(1.0, 1.0, 1.0, 1.0), 0.24)
	_spawn_floating_text(gate_label, "-%d HP" % damage, Color(1.0, 0.45, 0.45, 1.0), Vector2(24.0, 0.0), 16)

func _spawn_lane_popup(lane_index: int, text: String, color: Color, is_secondary_hit: bool) -> void:
	if lane_index < 0 or lane_index >= enemy_labels.size():
		return
	var host: Label = enemy_labels[lane_index]
	var x_offset: float = host.size.x - 82.0
	var y_offset: float = 0.0 if not is_secondary_hit else 18.0
	var font_size: int = 18 if not is_secondary_hit else 14
	_spawn_floating_text(host, text, color, Vector2(x_offset, y_offset), font_size)

func _spawn_floating_text(host: Control, text: String, color: Color, offset: Vector2, font_size: int) -> void:
	var popup: Label = Label.new()
	popup.text = text
	popup.modulate = color
	popup.z_index = 50
	popup.position = offset
	popup.add_theme_font_size_override("font_size", font_size)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(popup)

	var tween: Tween = create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 18.0, 0.35)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.35)
	tween.finished.connect(func() -> void:
		if is_instance_valid(popup):
			popup.queue_free()
	)

func _flash_lane_panel(lane_index: int, flash_color: Color) -> void:
	if lane_index < 0 or lane_index >= enemy_panels.size():
		return
	var lane_panel: Panel = enemy_panels[lane_index]
	var base_color: Color = lane_panel.self_modulate
	var tween: Tween = create_tween()
	tween.tween_property(lane_panel, "self_modulate", flash_color, 0.08)
	tween.tween_property(lane_panel, "self_modulate", base_color, 0.16)

func _show_support_aura_feedback(lane_index: int) -> void:
	if lane_index < 0 or lane_index >= enemy_panels.size():
		return
	var lane_bonus: int = _get_lane_support_bonus(lane_index)
	if lane_bonus <= 0:
		return
	var lane_panel: Panel = enemy_panels[lane_index]
	_spawn_floating_text(lane_panel, "AURA +%d" % lane_bonus, SUPPORT_AURA_TILE_COLOR, Vector2(10.0, 8.0), 13)

func _set_lane_panel_base_visual(lane_index: int) -> void:
	if lane_index < 0 or lane_index >= enemy_panels.size():
		return
	var lane_panel: Panel = enemy_panels[lane_index]
	var lane_bonus: int = _get_lane_support_bonus(lane_index)
	if lane_bonus > 0:
		lane_panel.self_modulate = LANE_AURA_COLOR
	else:
		lane_panel.self_modulate = LANE_IDLE_COLOR
