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
		"lane_buff_base": 1,
		"lane_buff_per_level": 2,
		"guard_bonus_per_level": 2,
		"guard_wall_bonus": 1,
		"hunter_bonus_per_level": 1,
		"hunter_execute_bonus_per_level": 1,
		"cleave_bonus_per_level": 1,
		"value_text": "Best with Guard/Hunter lanes where every attack gets amplified."
	}
}

const SUPPORT_PANEL_COLOR: Color = Color(0.33, 0.33, 0.54, 1.0)
const ATTACK_PANEL_COLOR: Color = Color(0.22, 0.30, 0.33, 1.0)
const EMPTY_PANEL_COLOR: Color = Color(0.13, 0.14, 0.18, 1.0)
const SELECTED_PANEL_COLOR: Color = Color(0.58, 0.47, 0.76, 1.0)
const MERGE_FLASH_COLOR: Color = Color(0.98, 0.97, 0.72, 1.0)
const LANE_HIT_FLASH_COLOR: Color = Color(0.78, 0.28, 0.28, 1.0)
const LANE_SPLASH_FLASH_COLOR: Color = Color(0.92, 0.62, 0.25, 1.0)
const LANE_AURA_COLOR: Color = Color(0.49, 0.34, 0.64, 1.0)
const LANE_IDLE_COLOR: Color = Color(0.80, 0.80, 0.88, 1.0)
const SUPPORT_AURA_TILE_COLOR: Color = Color(0.67, 0.52, 0.90, 1.0)
const BUFF_TYPE_SUPPORT: String = "support_damage"
const BUFF_TYPE_PROTECTION: String = "protection_holy"
const BUFF_TYPE_ATTACK: String = "attack_rage"
const BUFF_TYPE_HEALING: String = "healing_regen"
const BUFF_TYPE_VOID: String = "void_corruption"
const BUFF_TYPE_COLORS: Dictionary = {
	BUFF_TYPE_SUPPORT: Color(0.36, 0.64, 0.98, 1.0),
	BUFF_TYPE_PROTECTION: Color(0.95, 0.80, 0.34, 1.0),
	BUFF_TYPE_ATTACK: Color(0.88, 0.31, 0.31, 1.0),
	BUFF_TYPE_HEALING: Color(0.41, 0.79, 0.49, 1.0),
	BUFF_TYPE_VOID: Color(0.62, 0.43, 0.84, 1.0)
}
const BUFF_TYPE_PRIORITY: Array[String] = [
	BUFF_TYPE_SUPPORT,
	BUFF_TYPE_PROTECTION,
	BUFF_TYPE_ATTACK,
	BUFF_TYPE_HEALING,
	BUFF_TYPE_VOID
]

var next_unit: int = 0
var board_units: Array[Dictionary] = []
var tile_panels: Array[Panel] = []
var tile_labels: Array[Label] = []
var tile_aura_underlay_rects: Array[ColorRect] = []
var tile_aura_glow_rects: Array[ColorRect] = []
var tile_aura_core_rects: Array[ColorRect] = []
var tile_aura_ring_panels: Array[Panel] = []
var tile_aura_marker_labels: Array[Label] = []
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
@onready var background_rect: ColorRect = $Background
@onready var board_panel: Panel = $Board
@onready var wave_label: Label = $TopBar/TopRow/WaveLabel
@onready var gate_label: Label = $TopBar/TopRow/GateLabel
@onready var board_power_label: Label = $TopBar/TopRow/BoardPowerLabel
@onready var loss_label: Label = $LossLabel
@onready var tile_grid: GridContainer = $Board/BoardMargin/BoardContent/TileGrid
@onready var board_label: Label = $Board/BoardMargin/BoardContent/BoardLabel
@onready var enemy_lane_box: VBoxContainer = $EnemyLane
@onready var enemy_title_label: Label = $EnemyLane/EnemyTitle
@onready var unit_detail_label: Label = $UnitDetailPanel/UnitDetailLabel
@onready var unit_detail_panel: Panel = $UnitDetailPanel
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
@onready var top_row: HBoxContainer = $TopBar/TopRow

func _ready() -> void:
	_apply_dark_fantasy_theme()
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
		var aura_underlay: ColorRect = ColorRect.new()
		aura_underlay.anchors_preset = Control.PRESET_FULL_RECT
		aura_underlay.offset_left = 6.0
		aura_underlay.offset_top = 68.0
		aura_underlay.offset_right = -6.0
		aura_underlay.offset_bottom = -6.0
		aura_underlay.color = Color(1.0, 1.0, 1.0, 0.0)
		aura_underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(aura_underlay)
		panel.move_child(aura_underlay, 0)
		tile_aura_underlay_rects.append(aura_underlay)
		var aura_glow: ColorRect = ColorRect.new()
		aura_glow.anchors_preset = Control.PRESET_FULL_RECT
		aura_glow.offset_left = 4.0
		aura_glow.offset_top = 56.0
		aura_glow.offset_right = -4.0
		aura_glow.offset_bottom = -4.0
		aura_glow.color = Color(1.0, 1.0, 1.0, 0.0)
		aura_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(aura_glow)
		panel.move_child(aura_glow, 1)
		tile_aura_glow_rects.append(aura_glow)
		var aura_core: ColorRect = ColorRect.new()
		aura_core.anchors_preset = Control.PRESET_FULL_RECT
		aura_core.offset_left = 10.0
		aura_core.offset_top = 76.0
		aura_core.offset_right = -10.0
		aura_core.offset_bottom = -10.0
		aura_core.color = Color(1.0, 1.0, 1.0, 0.0)
		aura_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(aura_core)
		panel.move_child(aura_core, 2)
		tile_aura_core_rects.append(aura_core)
		var aura_ring: Panel = Panel.new()
		aura_ring.anchors_preset = Control.PRESET_FULL_RECT
		aura_ring.offset_left = 3.0
		aura_ring.offset_top = 3.0
		aura_ring.offset_right = -3.0
		aura_ring.offset_bottom = -3.0
		aura_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var aura_ring_style: StyleBoxFlat = StyleBoxFlat.new()
		aura_ring_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		aura_ring_style.border_width_left = 3
		aura_ring_style.border_width_top = 3
		aura_ring_style.border_width_right = 3
		aura_ring_style.border_width_bottom = 3
		aura_ring_style.corner_radius_top_left = 8
		aura_ring_style.corner_radius_top_right = 8
		aura_ring_style.corner_radius_bottom_left = 8
		aura_ring_style.corner_radius_bottom_right = 8
		aura_ring_style.border_color = Color(1.0, 1.0, 1.0, 0.0)
		aura_ring.add_theme_stylebox_override("panel", aura_ring_style)
		panel.add_child(aura_ring)
		panel.move_child(aura_ring, 3)
		tile_aura_ring_panels.append(aura_ring)
		var aura_marker: Label = Label.new()
		aura_marker.text = ""
		aura_marker.modulate = Color(1.0, 1.0, 1.0, 0.0)
		aura_marker.position = Vector2(7.0, 7.0)
		aura_marker.add_theme_font_size_override("font_size", 11)
		aura_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(aura_marker)
		tile_aura_marker_labels.append(aura_marker)
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

	_style_tile_panels_base()
	summon_button.pressed.connect(_on_summon_pressed)
	_render_board()
	_update_gate_ui()
	_update_wave_ui()
	_update_board_power_ui()
	_update_enemy_lane_ui()
	loss_label.visible = false
	status_label.text = "Prototype loaded. Summon units and hold the gate."
	_update_selection_detail()

func _apply_dark_fantasy_theme() -> void:
	background_rect.color = Color(0.05, 0.05, 0.07, 1.0)
	_apply_background_atmosphere()
	_style_board_panel()
	_style_top_bar()
	_style_enemy_lanes()
	_style_unit_detail_panel()
	_style_status_labels()

func _apply_background_atmosphere() -> void:
	var forest_shadow: ColorRect = ColorRect.new()
	forest_shadow.anchors_preset = Control.PRESET_FULL_RECT
	forest_shadow.offset_top = 110.0
	forest_shadow.color = Color(0.05, 0.10, 0.09, 0.62)
	forest_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(forest_shadow)
	move_child(forest_shadow, get_child_count() - 1)

	var abyss_haze: ColorRect = ColorRect.new()
	abyss_haze.anchors_preset = Control.PRESET_FULL_RECT
	abyss_haze.offset_left = 420.0
	abyss_haze.offset_top = 130.0
	abyss_haze.offset_right = -170.0
	abyss_haze.offset_bottom = -80.0
	abyss_haze.color = Color(0.28, 0.12, 0.38, 0.18)
	abyss_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(abyss_haze)
	move_child(abyss_haze, get_child_count() - 1)

	var gate_glow: ColorRect = ColorRect.new()
	gate_glow.anchors_preset = Control.PRESET_FULL_RECT
	gate_glow.offset_left = 16.0
	gate_glow.offset_top = 20.0
	gate_glow.offset_right = -16.0
	gate_glow.offset_bottom = -600.0
	gate_glow.color = Color(0.54, 0.17, 0.71, 0.17)
	gate_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gate_glow)
	move_child(gate_glow, get_child_count() - 1)

func _style_board_panel() -> void:
	var board_style: StyleBoxFlat = StyleBoxFlat.new()
	board_style.bg_color = Color(0.08, 0.08, 0.12, 0.94)
	board_style.border_width_left = 2
	board_style.border_width_top = 2
	board_style.border_width_right = 2
	board_style.border_width_bottom = 2
	board_style.border_color = Color(0.35, 0.26, 0.46, 0.78)
	board_style.corner_radius_top_left = 12
	board_style.corner_radius_top_right = 12
	board_style.corner_radius_bottom_left = 12
	board_style.corner_radius_bottom_right = 12
	board_panel.add_theme_stylebox_override("panel", board_style)
	board_label.text = "Ritual Board (5x3)"
	board_label.modulate = Color(0.84, 0.82, 0.91, 1.0)

func _style_top_bar() -> void:
	var top_style: StyleBoxFlat = StyleBoxFlat.new()
	top_style.bg_color = Color(0.09, 0.07, 0.12, 0.96)
	top_style.border_width_left = 2
	top_style.border_width_top = 2
	top_style.border_width_right = 2
	top_style.border_width_bottom = 2
	top_style.border_color = Color(0.43, 0.29, 0.58, 0.88)
	top_style.corner_radius_top_left = 10
	top_style.corner_radius_top_right = 10
	top_style.corner_radius_bottom_left = 10
	top_style.corner_radius_bottom_right = 10
	top_bar_panel.add_theme_stylebox_override("panel", top_style)
	top_row.add_theme_constant_override("separation", 20)
	wave_label.modulate = Color(0.88, 0.87, 0.94, 1.0)
	gate_label.modulate = Color(0.93, 0.84, 0.97, 1.0)
	board_power_label.modulate = Color(0.78, 0.87, 0.90, 1.0)

	var summon_style: StyleBoxFlat = StyleBoxFlat.new()
	summon_style.bg_color = Color(0.23, 0.12, 0.30, 1.0)
	summon_style.border_width_left = 2
	summon_style.border_width_top = 2
	summon_style.border_width_right = 2
	summon_style.border_width_bottom = 2
	summon_style.border_color = Color(0.63, 0.46, 0.81, 0.95)
	summon_style.corner_radius_top_left = 8
	summon_style.corner_radius_top_right = 8
	summon_style.corner_radius_bottom_left = 8
	summon_style.corner_radius_bottom_right = 8
	summon_button.add_theme_stylebox_override("normal", summon_style)
	summon_button.add_theme_stylebox_override("hover", summon_style)
	summon_button.add_theme_stylebox_override("pressed", summon_style)
	summon_button.text = "Invoke Unit"
	summon_button.modulate = Color(0.95, 0.92, 1.0, 1.0)

func _style_enemy_lanes() -> void:
	enemy_lane_box.add_theme_constant_override("separation", 12)
	enemy_title_label.text = "Voidbound Approach"
	enemy_title_label.modulate = Color(0.88, 0.82, 0.94, 1.0)
	for lane_panel in enemy_panels:
		var lane_style: StyleBoxFlat = StyleBoxFlat.new()
		lane_style.bg_color = Color(0.10, 0.10, 0.14, 0.95)
		lane_style.border_width_left = 1
		lane_style.border_width_top = 1
		lane_style.border_width_right = 1
		lane_style.border_width_bottom = 1
		lane_style.border_color = Color(0.39, 0.29, 0.50, 0.76)
		lane_style.corner_radius_top_left = 8
		lane_style.corner_radius_top_right = 8
		lane_style.corner_radius_bottom_left = 8
		lane_style.corner_radius_bottom_right = 8
		lane_panel.add_theme_stylebox_override("panel", lane_style)
	for lane_label in enemy_labels:
		lane_label.modulate = Color(0.88, 0.88, 0.93, 1.0)

func _style_unit_detail_panel() -> void:
	var detail_style: StyleBoxFlat = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	detail_style.border_width_left = 1
	detail_style.border_width_top = 1
	detail_style.border_width_right = 1
	detail_style.border_width_bottom = 1
	detail_style.border_color = Color(0.37, 0.30, 0.51, 0.85)
	detail_style.corner_radius_top_left = 8
	detail_style.corner_radius_top_right = 8
	detail_style.corner_radius_bottom_left = 8
	detail_style.corner_radius_bottom_right = 8
	unit_detail_panel.add_theme_stylebox_override("panel", detail_style)
	unit_detail_label.modulate = Color(0.86, 0.88, 0.95, 1.0)

func _style_status_labels() -> void:
	status_label.modulate = Color(0.84, 0.83, 0.90, 1.0)
	loss_label.modulate = Color(0.97, 0.52, 0.67, 1.0)

func _style_tile_panels_base() -> void:
	for panel in tile_panels:
		var tile_style: StyleBoxFlat = StyleBoxFlat.new()
		tile_style.bg_color = Color(0.06, 0.07, 0.10, 0.96)
		tile_style.border_width_left = 1
		tile_style.border_width_top = 1
		tile_style.border_width_right = 1
		tile_style.border_width_bottom = 1
		tile_style.border_color = Color(0.34, 0.31, 0.40, 0.75)
		tile_style.corner_radius_top_left = 10
		tile_style.corner_radius_top_right = 10
		tile_style.corner_radius_bottom_left = 10
		tile_style.corner_radius_bottom_right = 10
		panel.add_theme_stylebox_override("panel", tile_style)

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
			var role_support_bonus: int = _get_lane_role_support_bonus(lane_index, role)
			damage += role_support_bonus
			var support_contributed: bool = lane_support_bonus > 0
			if role_support_bonus > 0:
				support_contributed = true
			if role == "lane":
				damage += int(_get_unit_stat(unit, "lane_bonus", 0))
				if enemy_lanes[lane_index].size() >= int(_get_unit_stat(unit, "crowd_threshold", 99)):
					damage += int(_get_unit_stat(unit, "crowd_bonus", 0))
					var guard_wall_bonus: int = _get_lane_guard_wall_bonus(lane_index)
					damage += guard_wall_bonus
					if guard_wall_bonus > 0:
						support_contributed = true
			elif role == "single":
				damage += int(_get_unit_stat(unit, "focus_bonus", 0))
				var front_progress: int = _get_front_enemy_progress(lane_index)
				if LANE_LENGTH - front_progress <= int(_get_unit_stat(unit, "execute_range", 0)):
					damage += int(_get_unit_stat(unit, "execute_bonus", 0))
					var hunter_execute_bonus: int = _get_lane_hunter_execute_bonus(lane_index)
					damage += hunter_execute_bonus
					if hunter_execute_bonus > 0:
						support_contributed = true

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
		_update_tile_buff_aura(i, occupied)

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

func _update_tile_buff_aura(tile_index: int, occupied: bool) -> void:
	if tile_index < 0:
		return
	if tile_index >= tile_aura_underlay_rects.size():
		return
	if tile_index >= tile_aura_glow_rects.size():
		return
	if tile_index >= tile_aura_core_rects.size():
		return
	if tile_index >= tile_aura_ring_panels.size():
		return
	if tile_index >= tile_aura_marker_labels.size():
		return
	var underlay_rect: ColorRect = tile_aura_underlay_rects[tile_index]
	var glow_rect: ColorRect = tile_aura_glow_rects[tile_index]
	var core_rect: ColorRect = tile_aura_core_rects[tile_index]
	var ring_panel: Panel = tile_aura_ring_panels[tile_index]
	var marker_label: Label = tile_aura_marker_labels[tile_index]
	var ring_style: StyleBoxFlat = ring_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if ring_style == null:
		return
	if not occupied:
		underlay_rect.color = Color(1.0, 1.0, 1.0, 0.0)
		glow_rect.color = Color(1.0, 1.0, 1.0, 0.0)
		core_rect.color = Color(1.0, 1.0, 1.0, 0.0)
		ring_style.border_color = Color(1.0, 1.0, 1.0, 0.0)
		marker_label.text = ""
		marker_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		return

	var buff_types: Array[String] = _get_tile_active_buff_types(tile_index)
	if buff_types.is_empty():
		underlay_rect.color = Color(1.0, 1.0, 1.0, 0.0)
		glow_rect.color = Color(1.0, 1.0, 1.0, 0.0)
		core_rect.color = Color(1.0, 1.0, 1.0, 0.0)
		ring_style.border_color = Color(1.0, 1.0, 1.0, 0.0)
		marker_label.text = ""
		marker_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		return

	var primary_type: String = _get_primary_buff_type(buff_types)
	var buff_color: Color = _get_buff_color(primary_type)
	var is_focus_recipient: bool = _is_tile_receiving_selected_support(tile_index)
	var underlay_alpha: float = 0.45
	var glow_alpha: float = 0.36
	var core_alpha: float = 0.74
	var ring_alpha: float = 0.82
	var marker_alpha: float = 0.86
	if is_focus_recipient:
		underlay_alpha = 0.62
		glow_alpha = 0.58
		core_alpha = 0.90
		ring_alpha = 0.98
		marker_alpha = 1.0
	underlay_rect.color = Color(buff_color.r * 0.55, buff_color.g * 0.55, buff_color.b * 0.55, underlay_alpha)
	glow_rect.color = Color(buff_color.r, buff_color.g, buff_color.b, glow_alpha)
	core_rect.color = Color(buff_color.r, buff_color.g, buff_color.b, core_alpha)
	ring_style.border_color = Color(buff_color.r, buff_color.g, buff_color.b, ring_alpha)
	marker_label.text = _get_buff_marker_text(primary_type, is_focus_recipient)
	marker_label.modulate = Color(buff_color.r, buff_color.g, buff_color.b, marker_alpha)
	ring_panel.add_theme_stylebox_override("panel", ring_style)

func _get_buff_marker_text(buff_type: String, is_focus_recipient: bool) -> String:
	var marker_map: Dictionary = {
		BUFF_TYPE_SUPPORT: "+AURA",
		BUFF_TYPE_PROTECTION: "+HOLY",
		BUFF_TYPE_ATTACK: "+RAGE",
		BUFF_TYPE_HEALING: "+REGEN",
		BUFF_TYPE_VOID: "+VOID"
	}
	var marker_variant: Variant = marker_map.get(buff_type, "+BUFF")
	var marker_text: String = str(marker_variant)
	if is_focus_recipient:
		return "%s *" % marker_text
	return marker_text

func _get_tile_active_buff_types(tile_index: int) -> Array[String]:
	var buff_types: Array[String] = []
	if tile_index < 0 or tile_index >= board_units.size() or _is_tile_empty(tile_index):
		return buff_types
	var unit: Dictionary = board_units[tile_index]
	var lane_index: int = int(tile_index / BOARD_COLUMNS)

	if _get_unit_role(unit) != "support" and _get_lane_support_bonus(lane_index) > 0:
		buff_types.append(BUFF_TYPE_SUPPORT)
	return buff_types

func _get_primary_buff_type(buff_types: Array[String]) -> String:
	for buff_type in BUFF_TYPE_PRIORITY:
		if buff_types.has(buff_type):
			return buff_type
	if buff_types.is_empty():
		return ""
	return str(buff_types[0])

func _get_buff_color(buff_type: String) -> Color:
	var fallback_color: Color = Color(0.72, 0.72, 0.78, 1.0)
	var mapped_color: Variant = BUFF_TYPE_COLORS.get(buff_type, fallback_color)
	if mapped_color is Color:
		return mapped_color
	return fallback_color

func _is_tile_receiving_selected_support(tile_index: int) -> bool:
	if selected_tile_index < 0 or selected_tile_index >= board_units.size():
		return false
	if _is_tile_empty(selected_tile_index) or _is_tile_empty(tile_index):
		return false
	var selected_unit: Dictionary = board_units[selected_tile_index]
	if _get_unit_role(selected_unit) != "support":
		return false
	if tile_index == selected_tile_index:
		return false
	var target_unit: Dictionary = board_units[tile_index]
	if _get_unit_role(target_unit) == "support":
		return false
	var selected_lane: int = int(selected_tile_index / BOARD_COLUMNS)
	var tile_lane: int = int(tile_index / BOARD_COLUMNS)
	return selected_lane == tile_lane

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
		var level: int = int(unit["level"])
		bonus += int(_get_unit_stat(unit, "lane_buff_base", 0))
		bonus += int(_get_unit_stat(unit, "lane_buff_per_level", 0)) * level
	return bonus

func _get_lane_role_support_bonus(lane_index: int, role: String) -> int:
	var bonus: int = 0
	var stat_name: String = ""
	if role == "lane":
		stat_name = "guard_bonus_per_level"
	elif role == "single":
		stat_name = "hunter_bonus_per_level"
	elif role == "cleave":
		stat_name = "cleave_bonus_per_level"
	if stat_name == "":
		return 0

	for column in BOARD_COLUMNS:
		var tile_index: int = lane_index * BOARD_COLUMNS + column
		if tile_index >= board_units.size() or _is_tile_empty(tile_index):
			continue
		var unit: Dictionary = board_units[tile_index]
		if _get_unit_role(unit) != "support":
			continue
		bonus += int(_get_unit_stat(unit, stat_name, 0)) * int(unit["level"])
	return bonus

func _get_lane_guard_wall_bonus(lane_index: int) -> int:
	var bonus: int = 0
	for column in BOARD_COLUMNS:
		var tile_index: int = lane_index * BOARD_COLUMNS + column
		if tile_index >= board_units.size() or _is_tile_empty(tile_index):
			continue
		var unit: Dictionary = board_units[tile_index]
		if _get_unit_role(unit) != "support":
			continue
		bonus += int(_get_unit_stat(unit, "guard_wall_bonus", 0))
	return bonus

func _get_lane_hunter_execute_bonus(lane_index: int) -> int:
	var bonus: int = 0
	for column in BOARD_COLUMNS:
		var tile_index: int = lane_index * BOARD_COLUMNS + column
		if tile_index >= board_units.size() or _is_tile_empty(tile_index):
			continue
		var unit: Dictionary = board_units[tile_index]
		if _get_unit_role(unit) != "support":
			continue
		bonus += int(_get_unit_stat(unit, "hunter_execute_bonus_per_level", 0)) * int(unit["level"])
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
				var support_level: int = int(unit["level"])
				var ally_scale: int = max(1, ally_count)
				var aura_power: int = int(_get_unit_stat(unit, "lane_buff_base", 0))
				aura_power += int(_get_unit_stat(unit, "lane_buff_per_level", 0)) * support_level
				var role_power: int = int(_get_unit_stat(unit, "guard_bonus_per_level", 0)) * support_level
				role_power += int(_get_unit_stat(unit, "hunter_bonus_per_level", 0)) * support_level
				role_power += int(_get_unit_stat(unit, "cleave_bonus_per_level", 0)) * support_level
				role_power += int(_get_unit_stat(unit, "hunter_execute_bonus_per_level", 0)) * support_level
				role_power += int(_get_unit_stat(unit, "guard_wall_bonus", 0))
				unit_power = (aura_power + role_power) * ally_scale
			else:
				unit_power += lane_support_bonus
				unit_power += _get_lane_role_support_bonus(lane_index, role)
				if role == "lane":
					unit_power += int(_get_unit_stat(unit, "lane_bonus", 0))
					unit_power += int(_get_unit_stat(unit, "crowd_bonus", 0))
					unit_power += _get_lane_guard_wall_bonus(lane_index)
				elif role == "single":
					unit_power += int(_get_unit_stat(unit, "focus_bonus", 0))
					unit_power += int(_get_unit_stat(unit, "execute_bonus", 0))
					unit_power += _get_lane_hunter_execute_bonus(lane_index)
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
		var support_level: int = int(unit["level"])
		var lane_buff_total: int = int(_get_unit_stat(unit, "lane_buff_base", 0))
		lane_buff_total += int(_get_unit_stat(unit, "lane_buff_per_level", 0)) * support_level
		atk_text = "Aura +%d" % lane_buff_total
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
		var lane_buff_total: int = int(_get_unit_stat(unit, "lane_buff_base", 0))
		lane_buff_total += int(_get_unit_stat(unit, "lane_buff_per_level", 0)) * level
		var guard_bonus: int = int(_get_unit_stat(unit, "guard_bonus_per_level", 0)) * level
		var hunter_bonus: int = int(_get_unit_stat(unit, "hunter_bonus_per_level", 0)) * level
		return "Aura +%d, Guard +%d, Hunter +%d" % [lane_buff_total, guard_bonus, hunter_bonus]
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
		var guard_bonus: int = _get_lane_role_support_bonus(lane_index, "lane")
		var hunter_bonus: int = _get_lane_role_support_bonus(lane_index, "single")
		if lane_bonus > 0:
			lines.append("L%d A+%d G+%d H+%d" % [lane_index + 1, lane_bonus, guard_bonus, hunter_bonus])
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
