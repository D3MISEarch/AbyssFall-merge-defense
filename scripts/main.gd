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

const ROLE_ICONS: Dictionary = {
	"lane": "🛡",
	"single": "➤",
	"cleave": "✦",
	"support": "◉"
}
const HOSTILE_ICON_SET: Array[String] = ["☠", "◈", "✢", "⬣", "✥"]
const PLAYER_MONSTER_ICON_SET: Array[String] = ["⬤", "☠", "◉", "◆"]
const OPPONENT_MONSTER_ICON_SET: Array[String] = ["☠", "◈", "✢", "⬣"]
const PLAYER_MONSTER_COLOR: Color = Color(0.18, 0.26, 0.32, 0.96)
const OPPONENT_MONSTER_COLOR: Color = Color(0.32, 0.12, 0.28, 0.97)
const PLAYER_MONSTER_EDGE: Color = Color(0.58, 0.82, 0.92, 0.95)
const OPPONENT_MONSTER_EDGE: Color = Color(0.89, 0.53, 0.79, 0.95)
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
const ATTACK_PANEL_COLOR: Color = Color(0.23, 0.28, 0.30, 1.0)
const EMPTY_PANEL_COLOR: Color = Color(0.11, 0.12, 0.15, 1.0)
const SELECTED_PANEL_COLOR: Color = Color(0.48, 0.39, 0.66, 1.0)
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
var tile_icon_glow_rects: Array[ColorRect] = []
var tile_icon_labels: Array[Label] = []
var tile_level_badge_rects: Array[ColorRect] = []
var tile_level_badge_labels: Array[Label] = []
var tile_aura_underlay_rects: Array[ColorRect] = []
var tile_aura_glow_rects: Array[ColorRect] = []
var tile_aura_core_rects: Array[ColorRect] = []
var tile_aura_ring_panels: Array[Panel] = []
var tile_aura_marker_labels: Array[Label] = []
var tile_ritual_slab_rects: Array[ColorRect] = []
var tile_ritual_glyph_rects: Array[ColorRect] = []
var tile_ritual_crack_rects: Array[ColorRect] = []
var selected_tile_index: int = -1

var gate_hp: int = BASE_GATE_HP
var wave_number: int = 1
var spawned_enemies_total: int = 0
var next_spawn_lane: int = 0
var game_over: bool = false
var spawn_timer: float = 0.0
var advance_timer: float = 0.0
var enemy_lanes: Array[Array] = []
var opponent_lanes: Array[Array] = []
var support_feedback_lines: Array[String] = []
var lane_portal_core_rects: Array[ColorRect] = []
var lane_portal_ring_rects: Array[ColorRect] = []
var opponent_tile_panels: Array[Panel] = []
var opponent_tile_labels: Array[Label] = []
var opponent_tile_icon_labels: Array[Label] = []
var opponent_tile_glow_rects: Array[ColorRect] = []
var route_visual_layers: Array[Control] = []
var strip_ambience_layers: Array[Control] = []
var lane_monster_visuals: Array[Control] = []
var hostile_monster_layer: Control
var player_monster_layer: Control
var combat_fx_layer: Control
var gate_flash_overlays: Dictionary = {}
var player_lane_target_panels: Array[Panel] = []
var player_lane_target_labels: Array[Label] = []
var opponent_core_hp: int = BASE_GATE_HP

@onready var summon_button: Button = $BottomControls/BottomRow/SummonButton
@onready var status_label: Label = $StatusLabel
@onready var background_rect: ColorRect = $Background
@onready var board_panel: Panel = $BattlefieldStack/PlayerStrip/PlayerFlow/Board
@onready var opponent_board_panel: Panel = $BattlefieldStack/EnemyStrip/EnemyFlow/OpponentBoard
@onready var center_strip_panel: Panel = $BattlefieldStack/CenterStrip
@onready var wave_label: Label = $TopBar/TopRow/TopStats/WaveLabel
@onready var gate_label: Label = $TopBar/TopRow/TopStats/GateLabel
@onready var board_power_label: Label = $TopBar/TopRow/TopStats/BoardPowerLabel
@onready var loss_label: Label = $LossLabel
@onready var tile_grid: GridContainer = $BattlefieldStack/PlayerStrip/PlayerFlow/Board/BoardMargin/BoardContent/TileGrid
@onready var board_label: Label = $BattlefieldStack/PlayerStrip/PlayerFlow/Board/BoardMargin/BoardContent/BoardLabel
@onready var enemy_lane_box: VBoxContainer = $BattlefieldStack/EnemyStrip/EnemyFlow/EnemyRightPath
@onready var enemy_title_label: Label = $BattlefieldStack/EnemyStrip/EnemyFlow/EnemyRightPath/EnemyTitle
@onready var unit_detail_label: Label = $UnitDetailPanel/UnitDetailLabel
@onready var unit_detail_panel: Panel = $UnitDetailPanel
@onready var enemy_labels: Array[Label] = [
	$BattlefieldStack/EnemyStrip/EnemyFlow/EnemyRightPath/Enemy1/Enemy1Label,
	$BattlefieldStack/EnemyStrip/EnemyFlow/EnemyRightPath/Enemy2/Enemy2Label,
	$BattlefieldStack/EnemyStrip/EnemyFlow/EnemyRightPath/Enemy3/Enemy3Label
]
@onready var enemy_panels: Array[Panel] = [
	$BattlefieldStack/EnemyStrip/EnemyFlow/EnemyRightPath/Enemy1,
	$BattlefieldStack/EnemyStrip/EnemyFlow/EnemyRightPath/Enemy2,
	$BattlefieldStack/EnemyStrip/EnemyFlow/EnemyRightPath/Enemy3
]
@onready var top_bar_panel: Panel = $TopBar
@onready var top_row: HBoxContainer = $TopBar/TopRow
@onready var top_upgrade_cards: HBoxContainer = $TopBar/TopRow/TopUpgradeCards
@onready var top_stats_box: VBoxContainer = $TopBar/TopRow/TopStats
@onready var hero_panel: Panel = $TopBar/TopRow/HeroPanel
@onready var hero_label: Label = $TopBar/TopRow/HeroPanel/HeroLabel
@onready var bottom_controls_panel: Panel = $BottomControls
@onready var bottom_row: HBoxContainer = $BottomControls/BottomRow
@onready var mana_label: Label = $BottomControls/BottomRow/ManaLabel
@onready var roulette_button: Button = $BottomControls/BottomRow/RouletteButton
@onready var utility_button: Button = $BottomControls/BottomRow/UtilityButton
@onready var bottom_upgrade_row: Panel = $BottomUpgradeRow
@onready var bottom_upgrade_cards: HBoxContainer = $BottomUpgradeRow/BottomUpgradeCards
@onready var enemy_strip_panel: Panel = $BattlefieldStack/EnemyStrip
@onready var player_strip_panel: Panel = $BattlefieldStack/PlayerStrip
@onready var enemy_spawn_panel: Panel = $BattlefieldStack/EnemyStrip/EnemyFlow/EnemySpawn
@onready var enemy_gate_panel: Panel = $BattlefieldStack/EnemyStrip/EnemyFlow/EnemyGate
@onready var enemy_left_path_panel: Panel = $BattlefieldStack/EnemyStrip/EnemyFlow/EnemyLeftPath
@onready var player_spawn_panel: Panel = $BattlefieldStack/PlayerStrip/PlayerFlow/PlayerSpawn
@onready var player_gate_panel: Panel = $BattlefieldStack/PlayerStrip/PlayerFlow/PlayerGate
@onready var player_left_path_panel: Panel = $BattlefieldStack/PlayerStrip/PlayerFlow/PlayerLeftPath
@onready var player_right_path_panel: Panel = $BattlefieldStack/PlayerStrip/PlayerFlow/PlayerRightPath
@onready var center_label: Label = $BattlefieldStack/CenterStrip/CenterContent/CenterLabel
@onready var battle_info_row: HBoxContainer = $BattlefieldStack/CenterStrip/CenterContent/BattleInfoRow
@onready var life_info_label: Label = $BattlefieldStack/CenterStrip/CenterContent/BattleInfoRow/LifeInfoLabel
@onready var wave_info_label: Label = $BattlefieldStack/CenterStrip/CenterContent/BattleInfoRow/WaveInfoLabel
@onready var timer_info_label: Label = $BattlefieldStack/CenterStrip/CenterContent/BattleInfoRow/TimerInfoLabel
@onready var boss_info_label: Label = $BattlefieldStack/CenterStrip/CenterContent/BattleInfoRow/BossInfoLabel
@onready var pressure_info_label: Label = $BattlefieldStack/CenterStrip/CenterContent/BattleInfoRow/PressureInfoLabel
@onready var enemy_spawn_label: Label = $BattlefieldStack/EnemyStrip/EnemyFlow/EnemySpawn/EnemySpawnLabel
@onready var enemy_gate_label_text: Label = $BattlefieldStack/EnemyStrip/EnemyFlow/EnemyGate/EnemyGateLabel
@onready var player_spawn_label: Label = $BattlefieldStack/PlayerStrip/PlayerFlow/PlayerSpawn/PlayerSpawnLabel
@onready var player_gate_label_text: Label = $BattlefieldStack/PlayerStrip/PlayerFlow/PlayerGate/PlayerGateLabel
@onready var enemy_left_path_label: Label = $BattlefieldStack/EnemyStrip/EnemyFlow/EnemyLeftPath/EnemyLeftPathLabel
@onready var player_left_path_label: Label = $BattlefieldStack/PlayerStrip/PlayerFlow/PlayerLeftPath/PlayerLeftPathLabel
@onready var player_right_path_label: Label = $BattlefieldStack/PlayerStrip/PlayerFlow/PlayerRightPath/PlayerRightPathLabel
@onready var opponent_title_label: Label = $BattlefieldStack/EnemyStrip/EnemyFlow/OpponentBoard/OpponentMargin/OpponentContent/OpponentLabel
@onready var opponent_tile_grid: GridContainer = $BattlefieldStack/EnemyStrip/EnemyFlow/OpponentBoard/OpponentMargin/OpponentContent/OpponentTileGrid
@onready var top_upgrade_buttons: Array[Button] = [
	$TopBar/TopRow/TopUpgradeCards/TopCard1,
	$TopBar/TopRow/TopUpgradeCards/TopCard2,
	$TopBar/TopRow/TopUpgradeCards/TopCard3,
	$TopBar/TopRow/TopUpgradeCards/TopCard4
]
@onready var bottom_upgrade_buttons: Array[Button] = [
	$BottomUpgradeRow/BottomUpgradeCards/BottomCard1,
	$BottomUpgradeRow/BottomUpgradeCards/BottomCard2,
	$BottomUpgradeRow/BottomUpgradeCards/BottomCard3,
	$BottomUpgradeRow/BottomUpgradeCards/BottomCard4
]

func _ready() -> void:
	_apply_dark_fantasy_theme()
	board_units.resize(BOARD_COLUMNS * BOARD_ROWS)
	for i in board_units.size():
		board_units[i] = {}

	enemy_lanes.resize(LANE_COUNT)
	for lane_index in LANE_COUNT:
		enemy_lanes[lane_index] = []
	opponent_lanes.resize(LANE_COUNT)
	for lane_index in LANE_COUNT:
		opponent_lanes[lane_index] = []

	combat_fx_layer = Control.new()
	combat_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(combat_fx_layer)
	move_child(combat_fx_layer, get_child_count() - 1)

	_ensure_monster_layers()

	for i in tile_grid.get_child_count():
		var tile: Node = tile_grid.get_child(i)
		var panel: Panel = tile as Panel
		if panel == null:
			continue
		tile_panels.append(panel)
		var ritual_slab: ColorRect = ColorRect.new()
		ritual_slab.anchors_preset = Control.PRESET_FULL_RECT
		ritual_slab.offset_left = 5.0
		ritual_slab.offset_top = 5.0
		ritual_slab.offset_right = -5.0
		ritual_slab.offset_bottom = -5.0
		ritual_slab.color = Color(0.09, 0.10, 0.12, 0.72)
		ritual_slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(ritual_slab)
		panel.move_child(ritual_slab, 0)
		tile_ritual_slab_rects.append(ritual_slab)
		var ritual_glyph: ColorRect = ColorRect.new()
		ritual_glyph.anchors_preset = Control.PRESET_FULL_RECT
		ritual_glyph.offset_left = 14.0
		ritual_glyph.offset_top = 14.0
		ritual_glyph.offset_right = -14.0
		ritual_glyph.offset_bottom = -88.0
		ritual_glyph.color = Color(0.57, 0.35, 0.68, 0.15)
		ritual_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(ritual_glyph)
		panel.move_child(ritual_glyph, 1)
		tile_ritual_glyph_rects.append(ritual_glyph)
		var ritual_crack: ColorRect = ColorRect.new()
		ritual_crack.anchors_preset = Control.PRESET_FULL_RECT
		ritual_crack.offset_left = 20.0
		ritual_crack.offset_top = 76.0
		ritual_crack.offset_right = -16.0
		ritual_crack.offset_bottom = -42.0
		ritual_crack.color = Color(0.03, 0.04, 0.05, 0.45)
		ritual_crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(ritual_crack)
		panel.move_child(ritual_crack, 2)
		tile_ritual_crack_rects.append(ritual_crack)
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
		var icon_glow: ColorRect = ColorRect.new()
		icon_glow.anchors_preset = Control.PRESET_FULL_RECT
		icon_glow.offset_left = 18.0
		icon_glow.offset_top = 12.0
		icon_glow.offset_right = -18.0
		icon_glow.offset_bottom = -54.0
		icon_glow.color = Color(0.55, 0.70, 0.92, 0.0)
		icon_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon_glow)
		tile_icon_glow_rects.append(icon_glow)
		var icon_label: Label = Label.new()
		icon_label.anchors_preset = Control.PRESET_FULL_RECT
		icon_label.offset_left = 6.0
		icon_label.offset_top = 8.0
		icon_label.offset_right = -6.0
		icon_label.offset_bottom = -44.0
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 30)
		icon_label.text = ""
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon_label)
		tile_icon_labels.append(icon_label)
		var level_badge: ColorRect = ColorRect.new()
		level_badge.position = Vector2(72.0, 6.0)
		level_badge.size = Vector2(28.0, 18.0)
		level_badge.color = Color(0.78, 0.68, 0.33, 0.0)
		level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(level_badge)
		tile_level_badge_rects.append(level_badge)
		var level_label: Label = Label.new()
		level_label.anchors_preset = Control.PRESET_FULL_RECT
		level_label.offset_left = 74.0
		level_label.offset_top = 6.0
		level_label.offset_right = -2.0
		level_label.offset_bottom = -34.0
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		level_label.add_theme_font_size_override("font_size", 11)
		level_label.modulate = Color(0.08, 0.08, 0.08, 0.0)
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(level_label)
		tile_level_badge_labels.append(level_label)
		var label: Label = panel.get_node("TileLabel") as Label
		tile_labels.append(label)
		label.anchors_preset = Control.PRESET_FULL_RECT
		label.offset_left = 8.0
		label.offset_top = 52.0
		label.offset_right = -8.0
		label.offset_bottom = -6.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 11)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_tile_gui_input.bind(i))

	for i in opponent_tile_grid.get_child_count():
		var tile: Node = opponent_tile_grid.get_child(i)
		var panel: Panel = tile as Panel
		if panel == null:
			continue
		opponent_tile_panels.append(panel)
		var hostile_glow: ColorRect = ColorRect.new()
		hostile_glow.anchors_preset = Control.PRESET_FULL_RECT
		hostile_glow.offset_left = 8.0
		hostile_glow.offset_top = 8.0
		hostile_glow.offset_right = -8.0
		hostile_glow.offset_bottom = -8.0
		hostile_glow.color = Color(0.58, 0.24, 0.70, 0.18)
		hostile_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(hostile_glow)
		opponent_tile_glow_rects.append(hostile_glow)
		var icon_label: Label = Label.new()
		icon_label.anchors_preset = Control.PRESET_FULL_RECT
		icon_label.offset_left = 4.0
		icon_label.offset_top = 4.0
		icon_label.offset_right = -4.0
		icon_label.offset_bottom = -18.0
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 24)
		icon_label.modulate = Color(0.84, 0.71, 0.90, 0.85)
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon_label)
		opponent_tile_icon_labels.append(icon_label)
		var label: Label = panel.get_node("OppTileLabel") as Label
		if label != null:
			opponent_tile_labels.append(label)
	_build_player_lane_targets()

	_style_tile_panels_base()
	summon_button.pressed.connect(_on_summon_pressed)
	_render_board()
	_update_gate_ui()
	_update_wave_ui()
	_update_board_power_ui()
	_update_battle_info_strip()
	_update_enemy_lane_ui()
	loss_label.visible = false
	status_label.text = "Prototype loaded. Summon units and hold the gate."
	_update_selection_detail()
	enemy_strip_panel.resized.connect(_on_battlefield_strip_resized)
	player_strip_panel.resized.connect(_on_battlefield_strip_resized)
	call_deferred("_build_u_route_overlays")

func _apply_dark_fantasy_theme() -> void:
	background_rect.color = Color(0.05, 0.05, 0.07, 1.0)
	_apply_background_atmosphere()
	_style_battlefield_strips()
	_style_board_panel()
	_style_opponent_board()
	_style_center_strip()
	_style_top_bar()
	_style_bottom_controls()
	_style_upgrade_rows()
	_style_enemy_lanes()
	_style_unit_detail_panel()
	_style_status_labels()

func _on_battlefield_strip_resized() -> void:
	_build_strip_ambience()
	_ensure_monster_layers()
	call_deferred("_build_u_route_overlays")
	call_deferred("_update_lane_monster_positions")

func _build_u_route_overlays() -> void:
	_clear_route_overlays()
	_build_strip_u_route(enemy_strip_panel, enemy_spawn_panel, opponent_board_panel, enemy_gate_panel, true)
	_build_strip_u_route(player_strip_panel, player_spawn_panel, board_panel, player_gate_panel, false)

func _clear_route_overlays() -> void:
	for route_layer in route_visual_layers:
		if is_instance_valid(route_layer):
			route_layer.queue_free()
	route_visual_layers.clear()

func _build_strip_u_route(
	strip_panel: Panel,
	spawn_panel: Panel,
	center_board_panel: Panel,
	gate_panel: Panel,
	is_hostile_strip: bool
) -> void:
	if not is_instance_valid(strip_panel):
		return
	if not is_instance_valid(spawn_panel):
		return
	if not is_instance_valid(center_board_panel):
		return
	if not is_instance_valid(gate_panel):
		return

	var strip_overlay: Control = Control.new()
	strip_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip_panel.add_child(strip_overlay)
	strip_panel.move_child(strip_overlay, strip_panel.get_child_count() - 1)
	route_visual_layers.append(strip_overlay)

	var spawn_rect: Rect2 = _rect_in_local_space(strip_panel, spawn_panel)
	var board_rect: Rect2 = _rect_in_local_space(strip_panel, center_board_panel)
	var gate_rect: Rect2 = _rect_in_local_space(strip_panel, gate_panel)
	var lane_thickness: float = 20.0
	var board_padding: float = 14.0
	var left_lane_x: float = max(6.0, board_rect.position.x - lane_thickness - board_padding)
	var right_lane_x: float = min(
		strip_panel.size.x - lane_thickness - 6.0,
		board_rect.position.x + board_rect.size.x + board_padding
	)
	var top_lane_y: float = max(6.0, board_rect.position.y - lane_thickness - board_padding)
	var bottom_lane_y: float = min(
		strip_panel.size.y - lane_thickness - 6.0,
		board_rect.position.y + board_rect.size.y + board_padding
	)
	var hostile_top_lane_y: float = clamp(
		board_rect.position.y - (lane_thickness * 0.55),
		4.0,
		strip_panel.size.y - lane_thickness - 4.0
	)
	var hostile_bottom_lane_y: float = clamp(
		board_rect.position.y + board_rect.size.y - (lane_thickness * 0.45),
		4.0,
		strip_panel.size.y - lane_thickness - 4.0
	)
	var hostile_vertical_height: float = max(42.0, (hostile_bottom_lane_y + lane_thickness) - hostile_top_lane_y)
	var vertical_height: float = max(42.0, (bottom_lane_y + lane_thickness) - top_lane_y)
	var horizontal_width: float = max(60.0, (right_lane_x + lane_thickness) - left_lane_x)
	var spawn_top_entry_y: float = clamp(spawn_rect.position.y + 10.0, 4.0, strip_panel.size.y - lane_thickness - 4.0)
	var spawn_bottom_entry_y: float = clamp(
		spawn_rect.position.y + spawn_rect.size.y - lane_thickness - 10.0,
		4.0,
		strip_panel.size.y - lane_thickness - 4.0
	)
	var gate_top_entry_y: float = clamp(gate_rect.position.y + 10.0, 4.0, strip_panel.size.y - lane_thickness - 4.0)
	var gate_bottom_entry_y: float = clamp(
		gate_rect.position.y + gate_rect.size.y - lane_thickness - 10.0,
		4.0,
		strip_panel.size.y - lane_thickness - 4.0
	)
	var spawn_connector_start_x: float = spawn_rect.position.x + spawn_rect.size.x - 8.0
	var gate_connector_end_x: float = gate_rect.position.x + 8.0
	var spawn_connector_width: float = max(16.0, left_lane_x - spawn_connector_start_x)
	var gate_connector_width: float = max(16.0, gate_connector_end_x - (right_lane_x + lane_thickness))
	var lane_color: Color = Color(0.36, 0.48, 0.58, 0.82)
	var edging_color: Color = Color(0.70, 0.78, 0.86, 0.90)
	var glow_color: Color = Color(0.43, 0.62, 0.78, 0.22)
	var fog_color: Color = Color(0.36, 0.46, 0.57, 0.12)
	if is_hostile_strip:
		lane_color = Color(0.39, 0.21, 0.46, 0.84)
		edging_color = Color(0.73, 0.41, 0.74, 0.91)
		glow_color = Color(0.59, 0.27, 0.72, 0.24)
		fog_color = Color(0.57, 0.28, 0.68, 0.16)
		_add_route_segment(
			strip_overlay,
			Rect2(spawn_connector_start_x, spawn_top_entry_y, spawn_connector_width, lane_thickness),
			lane_color,
			edging_color,
			glow_color,
			fog_color,
			false
		)
		_add_route_segment(
			strip_overlay,
			Rect2(left_lane_x, hostile_top_lane_y, lane_thickness, hostile_vertical_height),
			lane_color,
			edging_color,
			glow_color,
			fog_color,
			true
		)
		_add_route_segment(
			strip_overlay,
			Rect2(left_lane_x, hostile_bottom_lane_y, horizontal_width, lane_thickness),
			lane_color,
			edging_color,
			glow_color,
			fog_color,
			false
		)
		_add_route_segment(
			strip_overlay,
			Rect2(right_lane_x, hostile_top_lane_y, lane_thickness, hostile_vertical_height),
			lane_color,
			edging_color,
			glow_color,
			fog_color,
			true
		)
		_add_route_segment(
			strip_overlay,
			Rect2(right_lane_x + lane_thickness, gate_top_entry_y, gate_connector_width, lane_thickness),
			lane_color,
			edging_color,
			glow_color,
			fog_color,
			false
		)
	else:
		lane_color = lane_color.lightened(0.08)
		glow_color = glow_color.lightened(0.12)
		_add_route_segment(
			strip_overlay,
			Rect2(spawn_connector_start_x, spawn_bottom_entry_y, spawn_connector_width, lane_thickness),
			lane_color,
			edging_color,
			glow_color,
			fog_color,
			false
		)
		_add_route_segment(
			strip_overlay,
			Rect2(left_lane_x, top_lane_y, lane_thickness, vertical_height),
			lane_color,
			edging_color,
			glow_color,
			fog_color,
			true
		)
		_add_route_segment(
			strip_overlay,
			Rect2(left_lane_x, top_lane_y, horizontal_width, lane_thickness),
			lane_color,
			edging_color,
			glow_color,
			fog_color,
			false
		)
		_add_route_segment(
			strip_overlay,
			Rect2(right_lane_x, top_lane_y, lane_thickness, vertical_height),
			lane_color,
			edging_color,
			glow_color,
			fog_color,
			true
		)
		_add_route_segment(
			strip_overlay,
			Rect2(right_lane_x + lane_thickness, gate_bottom_entry_y, gate_connector_width, lane_thickness),
			lane_color,
			edging_color,
			glow_color,
			fog_color,
			false
		)

func _rect_in_local_space(local_root: Control, target: Control) -> Rect2:
	var target_rect: Rect2 = target.get_global_rect()
	var local_position: Vector2 = _global_to_control_space(local_root, target_rect.position)
	return Rect2(local_position, target_rect.size)

func _global_to_control_space(local_root: Control, global_position: Vector2) -> Vector2:
	var inverse_transform: Transform2D = local_root.get_global_transform_with_canvas().affine_inverse()
	return inverse_transform * global_position

func _ensure_monster_layers() -> void:
	hostile_monster_layer = _ensure_strip_monster_layer(enemy_strip_panel, hostile_monster_layer, "HostileMonsterLayer")
	player_monster_layer = _ensure_strip_monster_layer(player_strip_panel, player_monster_layer, "PlayerMonsterLayer")

func _ensure_strip_monster_layer(strip_panel: Panel, existing_layer: Control, layer_name: String) -> Control:
	if strip_panel == null:
		return null
	if is_instance_valid(existing_layer):
		existing_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return existing_layer
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 6
	strip_panel.add_child(layer)
	strip_panel.move_child(layer, strip_panel.get_child_count() - 1)
	return layer

func _build_player_lane_targets() -> void:
	for target_panel in player_lane_target_panels:
		if is_instance_valid(target_panel):
			target_panel.queue_free()
	player_lane_target_panels.clear()
	player_lane_target_labels.clear()
	var lane_host: VBoxContainer = VBoxContainer.new()
	lane_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lane_host.add_theme_constant_override("separation", 6)
	lane_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_right_path_panel.add_child(lane_host)
	for lane_index in LANE_COUNT:
		var lane_panel: Panel = Panel.new()
		lane_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lane_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lane_style: StyleBoxFlat = StyleBoxFlat.new()
		lane_style.bg_color = Color(0.20, 0.28, 0.36, 0.35)
		lane_style.border_width_left = 1
		lane_style.border_width_top = 1
		lane_style.border_width_right = 1
		lane_style.border_width_bottom = 1
		lane_style.border_color = Color(0.52, 0.72, 0.84, 0.45)
		lane_style.corner_radius_top_left = 8
		lane_style.corner_radius_top_right = 8
		lane_style.corner_radius_bottom_left = 8
		lane_style.corner_radius_bottom_right = 8
		lane_panel.add_theme_stylebox_override("panel", lane_style)
		lane_host.add_child(lane_panel)
		player_lane_target_panels.append(lane_panel)
		var lane_label: Label = Label.new()
		lane_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lane_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lane_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lane_label.text = "Player Lane %d" % [lane_index + 1]
		lane_label.modulate = Color(0.76, 0.88, 0.98, 0.58)
		lane_label.add_theme_font_size_override("font_size", 11)
		lane_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lane_panel.add_child(lane_label)
		player_lane_target_labels.append(lane_label)

func _add_route_segment(
	host: Control,
	segment_rect: Rect2,
	lane_color: Color,
	edging_color: Color,
	glow_color: Color,
	fog_color: Color,
	is_vertical: bool
) -> void:
	var segment: Panel = Panel.new()
	segment.position = segment_rect.position
	segment.size = segment_rect.size
	segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var segment_style: StyleBoxFlat = StyleBoxFlat.new()
	segment_style.bg_color = lane_color
	segment_style.corner_radius_top_left = 10
	segment_style.corner_radius_top_right = 10
	segment_style.corner_radius_bottom_left = 10
	segment_style.corner_radius_bottom_right = 10
	segment_style.border_width_left = 2
	segment_style.border_width_top = 2
	segment_style.border_width_right = 2
	segment_style.border_width_bottom = 2
	segment_style.border_color = edging_color
	segment_style.shadow_size = 8
	segment_style.shadow_offset = Vector2(0.0, 2.0)
	segment_style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	segment.add_theme_stylebox_override("panel", segment_style)
	host.add_child(segment)

	var path_panel: ColorRect = ColorRect.new()
	path_panel.anchors_preset = Control.PRESET_FULL_RECT
	path_panel.offset_left = 3.0
	path_panel.offset_top = 3.0
	path_panel.offset_right = -3.0
	path_panel.offset_bottom = -3.0
	path_panel.color = lane_color.lightened(0.07)
	path_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segment.add_child(path_panel)

	var glow_panel: ColorRect = ColorRect.new()
	glow_panel.anchors_preset = Control.PRESET_FULL_RECT
	glow_panel.offset_left = 2.0
	glow_panel.offset_top = 2.0
	glow_panel.offset_right = -2.0
	glow_panel.offset_bottom = -2.0
	glow_panel.color = glow_color
	glow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segment.add_child(glow_panel)

	var fog_panel: ColorRect = ColorRect.new()
	fog_panel.anchors_preset = Control.PRESET_FULL_RECT
	fog_panel.offset_left = 1.0
	fog_panel.offset_top = 1.0
	fog_panel.offset_right = -1.0
	fog_panel.offset_bottom = -1.0
	fog_panel.color = fog_color
	fog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segment.add_child(fog_panel)

	_add_stone_edging(segment, edging_color, is_vertical)

func _add_stone_edging(segment: Control, edging_color: Color, is_vertical: bool) -> void:
	var stone_count: int = 6
	if is_vertical:
		stone_count = 5
	for stone_index in stone_count:
		var stone: ColorRect = ColorRect.new()
		stone.custom_minimum_size = Vector2(7.0, 7.0)
		stone.size = Vector2(7.0, 7.0)
		stone.color = edging_color.darkened(0.22)
		stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_vertical:
			var y_offset: float = (float(stone_index + 1) * segment.size.y) / float(stone_count + 1)
			stone.position = Vector2(1.0, y_offset - 3.0)
		else:
			var x_offset: float = (float(stone_index + 1) * segment.size.x) / float(stone_count + 1)
			stone.position = Vector2(x_offset - 3.0, 1.0)
		segment.add_child(stone)

func _apply_background_atmosphere() -> void:
	var forest_shadow: ColorRect = ColorRect.new()
	forest_shadow.anchors_preset = Control.PRESET_FULL_RECT
	forest_shadow.offset_top = 100.0
	forest_shadow.color = Color(0.04, 0.09, 0.07, 0.76)
	forest_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(forest_shadow)
	move_child(forest_shadow, get_child_count() - 1)

	var forest_depth: ColorRect = ColorRect.new()
	forest_depth.anchors_preset = Control.PRESET_FULL_RECT
	forest_depth.offset_left = -100.0
	forest_depth.offset_top = 170.0
	forest_depth.offset_right = 250.0
	forest_depth.offset_bottom = -160.0
	forest_depth.color = Color(0.03, 0.08, 0.06, 0.56)
	forest_depth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(forest_depth)
	move_child(forest_depth, get_child_count() - 1)

	var abyss_haze: ColorRect = ColorRect.new()
	abyss_haze.anchors_preset = Control.PRESET_FULL_RECT
	abyss_haze.offset_left = 380.0
	abyss_haze.offset_top = 130.0
	abyss_haze.offset_right = -120.0
	abyss_haze.offset_bottom = -40.0
	abyss_haze.color = Color(0.22, 0.10, 0.33, 0.26)
	abyss_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(abyss_haze)
	move_child(abyss_haze, get_child_count() - 1)

	var abyss_mist: ColorRect = ColorRect.new()
	abyss_mist.anchors_preset = Control.PRESET_FULL_RECT
	abyss_mist.offset_left = 0.0
	abyss_mist.offset_top = 500.0
	abyss_mist.offset_right = 0.0
	abyss_mist.offset_bottom = 0.0
	abyss_mist.color = Color(0.13, 0.14, 0.19, 0.38)
	abyss_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(abyss_mist)
	move_child(abyss_mist, get_child_count() - 1)

	var gate_glow: ColorRect = ColorRect.new()
	gate_glow.anchors_preset = Control.PRESET_FULL_RECT
	gate_glow.offset_left = 16.0
	gate_glow.offset_top = 20.0
	gate_glow.offset_right = -16.0
	gate_glow.offset_bottom = -600.0
	gate_glow.color = Color(0.48, 0.18, 0.66, 0.24)
	gate_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gate_glow)
	move_child(gate_glow, get_child_count() - 1)

	var ritual_ambience: ColorRect = ColorRect.new()
	ritual_ambience.anchors_preset = Control.PRESET_FULL_RECT
	ritual_ambience.offset_left = 240.0
	ritual_ambience.offset_top = 70.0
	ritual_ambience.offset_right = -240.0
	ritual_ambience.offset_bottom = -620.0
	ritual_ambience.color = Color(0.61, 0.24, 0.78, 0.15)
	ritual_ambience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ritual_ambience)
	move_child(ritual_ambience, get_child_count() - 1)

func _build_strip_ambience() -> void:
	for ambience_layer in strip_ambience_layers:
		if is_instance_valid(ambience_layer):
			ambience_layer.queue_free()
	strip_ambience_layers.clear()
	_add_strip_ambience(enemy_strip_panel, true)
	_add_strip_ambience(player_strip_panel, false)

func _add_strip_ambience(strip_panel: Panel, is_hostile_strip: bool) -> void:
	var ambience_layer: Control = Control.new()
	ambience_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ambience_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip_panel.add_child(ambience_layer)
	strip_panel.move_child(ambience_layer, 0)
	strip_ambience_layers.append(ambience_layer)

	var slab_shadow: ColorRect = ColorRect.new()
	slab_shadow.anchors_preset = Control.PRESET_FULL_RECT
	slab_shadow.offset_left = 8.0
	slab_shadow.offset_top = 10.0
	slab_shadow.offset_right = -8.0
	slab_shadow.offset_bottom = -10.0
	slab_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slab_shadow.color = Color(0.05, 0.06, 0.07, 0.48)
	ambience_layer.add_child(slab_shadow)

	var slab_core: ColorRect = ColorRect.new()
	slab_core.anchors_preset = Control.PRESET_FULL_RECT
	slab_core.offset_left = 14.0
	slab_core.offset_top = 16.0
	slab_core.offset_right = -14.0
	slab_core.offset_bottom = -16.0
	slab_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slab_core.color = Color(0.09, 0.11, 0.12, 0.44)
	if is_hostile_strip:
		slab_core.color = Color(0.10, 0.07, 0.13, 0.50)
	ambience_layer.add_child(slab_core)

	var grime_band: ColorRect = ColorRect.new()
	grime_band.anchors_preset = Control.PRESET_FULL_RECT
	grime_band.offset_left = 10.0
	grime_band.offset_top = 14.0
	grime_band.offset_right = -10.0
	grime_band.offset_bottom = -110.0
	grime_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grime_band.color = Color(0.02, 0.03, 0.03, 0.38)
	if is_hostile_strip:
		grime_band.color = Color(0.11, 0.04, 0.11, 0.34)
	ambience_layer.add_child(grime_band)

	var void_fog: ColorRect = ColorRect.new()
	void_fog.anchors_preset = Control.PRESET_FULL_RECT
	void_fog.offset_left = 24.0
	void_fog.offset_top = 96.0
	void_fog.offset_right = -24.0
	void_fog.offset_bottom = -20.0
	void_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	void_fog.color = Color(0.17, 0.22, 0.23, 0.16)
	if is_hostile_strip:
		void_fog.color = Color(0.28, 0.12, 0.34, 0.18)
	ambience_layer.add_child(void_fog)

func _style_battlefield_strips() -> void:
	var enemy_strip_style: StyleBoxFlat = StyleBoxFlat.new()
	enemy_strip_style.bg_color = Color(0.06, 0.05, 0.09, 0.97)
	enemy_strip_style.border_width_left = 4
	enemy_strip_style.border_width_top = 4
	enemy_strip_style.border_width_right = 4
	enemy_strip_style.border_width_bottom = 4
	enemy_strip_style.border_color = Color(0.46, 0.20, 0.52, 0.92)
	enemy_strip_style.corner_radius_top_left = 16
	enemy_strip_style.corner_radius_top_right = 16
	enemy_strip_style.corner_radius_bottom_left = 16
	enemy_strip_style.corner_radius_bottom_right = 16
	enemy_strip_style.shadow_size = 16
	enemy_strip_style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	enemy_strip_style.shadow_offset = Vector2(0.0, 6.0)
	enemy_strip_panel.add_theme_stylebox_override("panel", enemy_strip_style)

	var player_strip_style: StyleBoxFlat = StyleBoxFlat.new()
	player_strip_style.bg_color = Color(0.05, 0.07, 0.09, 0.97)
	player_strip_style.border_width_left = 4
	player_strip_style.border_width_top = 4
	player_strip_style.border_width_right = 4
	player_strip_style.border_width_bottom = 4
	player_strip_style.border_color = Color(0.27, 0.39, 0.47, 0.93)
	player_strip_style.corner_radius_top_left = 16
	player_strip_style.corner_radius_top_right = 16
	player_strip_style.corner_radius_bottom_left = 16
	player_strip_style.corner_radius_bottom_right = 16
	player_strip_style.shadow_size = 16
	player_strip_style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	player_strip_style.shadow_offset = Vector2(0.0, 6.0)
	player_strip_panel.add_theme_stylebox_override("panel", player_strip_style)
	_build_strip_ambience()

	_style_spawn_or_gate_panel(enemy_spawn_panel, Color(0.16, 0.05, 0.13, 0.96), Color(0.67, 0.20, 0.49, 0.92))
	_style_spawn_or_gate_panel(enemy_gate_panel, Color(0.09, 0.03, 0.11, 0.96), Color(0.75, 0.25, 0.57, 0.94))
	_style_spawn_or_gate_panel(player_spawn_panel, Color(0.06, 0.10, 0.12, 0.96), Color(0.39, 0.56, 0.64, 0.91))
	_style_spawn_or_gate_panel(player_gate_panel, Color(0.07, 0.10, 0.15, 0.96), Color(0.46, 0.68, 0.77, 0.94))
	_style_spawn_or_gate_panel(enemy_left_path_panel, Color(0.09, 0.05, 0.11, 0.92), Color(0.54, 0.20, 0.48, 0.84))
	_style_spawn_or_gate_panel(player_left_path_panel, Color(0.08, 0.10, 0.13, 0.92), Color(0.36, 0.48, 0.61, 0.84))
	_style_spawn_or_gate_panel(player_right_path_panel, Color(0.08, 0.10, 0.13, 0.92), Color(0.41, 0.57, 0.67, 0.86))
	_style_lane_identity_labels()
	_decorate_spawn_gate_identity()

func _style_spawn_or_gate_panel(target_panel: Panel, bg_color: Color, border_color: Color) -> void:
	var target_style: StyleBoxFlat = StyleBoxFlat.new()
	target_style.bg_color = bg_color
	target_style.border_width_left = 2
	target_style.border_width_top = 2
	target_style.border_width_right = 2
	target_style.border_width_bottom = 2
	target_style.border_color = border_color
	target_style.corner_radius_top_left = 12
	target_style.corner_radius_top_right = 12
	target_style.corner_radius_bottom_left = 12
	target_style.corner_radius_bottom_right = 12
	target_style.shadow_size = 8
	target_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	target_style.shadow_offset = Vector2(0.0, 3.0)
	target_panel.add_theme_stylebox_override("panel", target_style)

func _style_board_panel() -> void:
	var board_style: StyleBoxFlat = StyleBoxFlat.new()
	board_style.bg_color = Color(0.05, 0.06, 0.08, 0.97)
	board_style.border_width_left = 5
	board_style.border_width_top = 5
	board_style.border_width_right = 5
	board_style.border_width_bottom = 5
	board_style.border_color = Color(0.28, 0.26, 0.32, 0.93)
	board_style.corner_radius_top_left = 12
	board_style.corner_radius_top_right = 12
	board_style.corner_radius_bottom_left = 12
	board_style.corner_radius_bottom_right = 12
	board_style.shadow_size = 14
	board_style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	board_style.shadow_offset = Vector2(0.0, 5.0)
	board_panel.add_theme_stylebox_override("panel", board_style)
	board_label.text = "Player Ritual Slab"
	board_label.modulate = Color(0.83, 0.81, 0.89, 1.0)

func _style_opponent_board() -> void:
	var opponent_style: StyleBoxFlat = StyleBoxFlat.new()
	opponent_style.bg_color = Color(0.06, 0.06, 0.09, 0.94)
	opponent_style.border_width_left = 4
	opponent_style.border_width_top = 4
	opponent_style.border_width_right = 4
	opponent_style.border_width_bottom = 4
	opponent_style.border_color = Color(0.48, 0.28, 0.58, 0.92)
	opponent_style.corner_radius_top_left = 12
	opponent_style.corner_radius_top_right = 12
	opponent_style.corner_radius_bottom_left = 12
	opponent_style.corner_radius_bottom_right = 12
	opponent_style.shadow_size = 12
	opponent_style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	opponent_style.shadow_offset = Vector2(0.0, 4.0)
	opponent_board_panel.add_theme_stylebox_override("panel", opponent_style)
	opponent_title_label.text = "⛧ Hostile Ritual Board"
	opponent_title_label.modulate = Color(0.76, 0.70, 0.82, 0.96)
	for tile_index in opponent_tile_panels.size():
		var tile_panel: Panel = opponent_tile_panels[tile_index]
		var tile_style: StyleBoxFlat = StyleBoxFlat.new()
		tile_style.bg_color = Color(0.07, 0.06, 0.10, 0.93)
		tile_style.border_width_left = 3
		tile_style.border_width_top = 3
		tile_style.border_width_right = 3
		tile_style.border_width_bottom = 3
		tile_style.border_color = Color(0.44, 0.26, 0.53, 0.88)
		tile_style.corner_radius_top_left = 8
		tile_style.corner_radius_top_right = 8
		tile_style.corner_radius_bottom_left = 8
		tile_style.corner_radius_bottom_right = 8
		tile_panel.add_theme_stylebox_override("panel", tile_style)
		var void_underglow: ColorRect = ColorRect.new()
		void_underglow.anchors_preset = Control.PRESET_FULL_RECT
		void_underglow.offset_left = 6.0
		void_underglow.offset_top = 6.0
		void_underglow.offset_right = -6.0
		void_underglow.offset_bottom = -6.0
		void_underglow.color = Color(0.49, 0.21, 0.62, 0.14)
		void_underglow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_panel.add_child(void_underglow)
		tile_panel.move_child(void_underglow, 0)
	for label_index in opponent_tile_labels.size():
		var tile_label: Label = opponent_tile_labels[label_index]
		var lane_id: int = int(label_index / BOARD_COLUMNS) + 1
		var col_id: int = (label_index % BOARD_COLUMNS) + 1
		tile_label.modulate = Color(0.80, 0.77, 0.89, 0.90)
		tile_label.text = "Hostile\nL%d•C%d" % [lane_id, col_id]
		tile_label.add_theme_font_size_override("font_size", 12)
		tile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		if label_index < opponent_tile_icon_labels.size():
			var hostile_icon: String = HOSTILE_ICON_SET[label_index % HOSTILE_ICON_SET.size()]
			opponent_tile_icon_labels[label_index].text = hostile_icon

func _style_center_strip() -> void:
	var strip_style: StyleBoxFlat = StyleBoxFlat.new()
	strip_style.bg_color = Color(0.07, 0.04, 0.10, 0.94)
	strip_style.border_width_left = 4
	strip_style.border_width_top = 4
	strip_style.border_width_right = 4
	strip_style.border_width_bottom = 4
	strip_style.border_color = Color(0.49, 0.31, 0.66, 0.93)
	strip_style.corner_radius_top_left = 14
	strip_style.corner_radius_top_right = 14
	strip_style.corner_radius_bottom_left = 14
	strip_style.corner_radius_bottom_right = 14
	strip_style.shadow_size = 12
	strip_style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	strip_style.shadow_offset = Vector2(0.0, 2.0)
	center_strip_panel.add_theme_stylebox_override("panel", strip_style)
	battle_info_row.add_theme_constant_override("separation", 12)
	center_label.text = "Abyssal Fault • Corrupted Ground"
	center_label.modulate = Color(0.85, 0.74, 0.92, 0.95)
	life_info_label.text = "❤ 100  ⚔ 100"
	wave_info_label.text = "🌊 W1"
	timer_info_label.text = "⏱ 2.0s"
	boss_info_label.text = "👑 0/3"
	pressure_info_label.text = "☣ 0%"
	var strip_labels: Array[Label] = [life_info_label, wave_info_label, timer_info_label, boss_info_label, pressure_info_label]
	for info_label in strip_labels:
		info_label.add_theme_font_size_override("font_size", 15)
		info_label.add_theme_constant_override("outline_size", 1)
		info_label.modulate = Color(0.90, 0.86, 0.96, 0.97)
	center_label.add_theme_font_size_override("font_size", 13)

func _style_lane_identity_labels() -> void:
	enemy_spawn_label.text = "◉ Rift"
	enemy_gate_label_text.text = "⛨ Core"
	player_spawn_label.text = "◉ Spawn"
	player_gate_label_text.text = "⛨ Gate"
	enemy_left_path_label.text = "↺ Rim"
	player_left_path_label.text = "↺ Lane"
	player_right_path_label.text = "⇢ Exit"
	enemy_spawn_label.modulate = Color(0.91, 0.74, 0.86, 0.95)
	enemy_gate_label_text.modulate = Color(0.95, 0.72, 0.89, 0.96)
	player_spawn_label.modulate = Color(0.80, 0.90, 0.94, 0.96)
	player_gate_label_text.modulate = Color(0.85, 0.95, 0.99, 0.96)
	enemy_left_path_label.modulate = Color(0.80, 0.67, 0.86, 0.92)
	player_left_path_label.modulate = Color(0.73, 0.83, 0.90, 0.92)
	player_right_path_label.modulate = Color(0.77, 0.86, 0.93, 0.94)

func _style_top_bar() -> void:
	var top_style: StyleBoxFlat = StyleBoxFlat.new()
	top_style.bg_color = Color(0.09, 0.07, 0.12, 0.92)
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
	top_row.add_theme_constant_override("separation", 14)
	top_upgrade_cards.add_theme_constant_override("separation", 8)
	top_stats_box.add_theme_constant_override("separation", 4)
	var hero_style: StyleBoxFlat = StyleBoxFlat.new()
	hero_style.bg_color = Color(0.12, 0.09, 0.18, 0.98)
	hero_style.border_width_left = 2
	hero_style.border_width_top = 2
	hero_style.border_width_right = 2
	hero_style.border_width_bottom = 2
	hero_style.border_color = Color(0.62, 0.43, 0.78, 0.92)
	hero_style.corner_radius_top_left = 12
	hero_style.corner_radius_top_right = 12
	hero_style.corner_radius_bottom_left = 12
	hero_style.corner_radius_bottom_right = 12
	hero_panel.add_theme_stylebox_override("panel", hero_style)
	hero_label.add_theme_font_size_override("font_size", 14)
	hero_label.modulate = Color(0.94, 0.89, 0.98, 0.98)
	wave_label.modulate = Color(0.88, 0.87, 0.94, 1.0)
	gate_label.modulate = Color(0.93, 0.84, 0.97, 1.0)
	board_power_label.modulate = Color(0.78, 0.87, 0.90, 1.0)
	wave_label.add_theme_font_size_override("font_size", 13)
	gate_label.add_theme_font_size_override("font_size", 13)
	board_power_label.add_theme_font_size_override("font_size", 13)

func _style_bottom_controls() -> void:
	var controls_style: StyleBoxFlat = StyleBoxFlat.new()
	controls_style.bg_color = Color(0.10, 0.09, 0.14, 0.94)
	controls_style.border_width_left = 2
	controls_style.border_width_top = 2
	controls_style.border_width_right = 2
	controls_style.border_width_bottom = 2
	controls_style.border_color = Color(0.52, 0.38, 0.66, 0.88)
	controls_style.corner_radius_top_left = 14
	controls_style.corner_radius_top_right = 14
	controls_style.corner_radius_bottom_left = 14
	controls_style.corner_radius_bottom_right = 14
	bottom_controls_panel.add_theme_stylebox_override("panel", controls_style)
	bottom_row.add_theme_constant_override("separation", 12)
	summon_button.custom_minimum_size = Vector2(272.0, 62.0)
	roulette_button.custom_minimum_size = Vector2(164.0, 62.0)
	utility_button.custom_minimum_size = Vector2(96.0, 62.0)
	mana_label.custom_minimum_size = Vector2(172.0, 62.0)

	var summon_style: StyleBoxFlat = StyleBoxFlat.new()
	summon_style.bg_color = Color(0.30, 0.12, 0.38, 1.0)
	summon_style.border_width_left = 2
	summon_style.border_width_top = 2
	summon_style.border_width_right = 2
	summon_style.border_width_bottom = 2
	summon_style.border_color = Color(0.73, 0.54, 0.88, 0.95)
	summon_style.corner_radius_top_left = 10
	summon_style.corner_radius_top_right = 10
	summon_style.corner_radius_bottom_left = 10
	summon_style.corner_radius_bottom_right = 10
	summon_button.add_theme_stylebox_override("normal", summon_style)
	summon_button.add_theme_stylebox_override("hover", summon_style)
	summon_button.add_theme_stylebox_override("pressed", summon_style)
	summon_button.text = "⛧ Invoke"
	summon_button.modulate = Color(0.98, 0.95, 1.0, 1.0)
	summon_button.add_theme_font_size_override("font_size", 20)

	var roulette_style: StyleBoxFlat = StyleBoxFlat.new()
	roulette_style.bg_color = Color(0.14, 0.14, 0.19, 1.0)
	roulette_style.border_width_left = 2
	roulette_style.border_width_top = 2
	roulette_style.border_width_right = 2
	roulette_style.border_width_bottom = 2
	roulette_style.border_color = Color(0.45, 0.50, 0.62, 0.90)
	roulette_style.corner_radius_top_left = 10
	roulette_style.corner_radius_top_right = 10
	roulette_style.corner_radius_bottom_left = 10
	roulette_style.corner_radius_bottom_right = 10
	roulette_button.add_theme_stylebox_override("normal", roulette_style)
	roulette_button.add_theme_stylebox_override("hover", roulette_style)
	roulette_button.add_theme_stylebox_override("pressed", roulette_style)
	roulette_button.text = "✦ Hero"
	roulette_button.modulate = Color(0.92, 0.94, 0.98, 1.0)
	roulette_button.add_theme_font_size_override("font_size", 18)
	mana_label.modulate = Color(0.81, 0.91, 0.99, 1.0)
	mana_label.text = "✶ Mana 10/10"
	mana_label.add_theme_font_size_override("font_size", 20)
	utility_button.add_theme_stylebox_override("normal", roulette_style)
	utility_button.add_theme_stylebox_override("hover", roulette_style)
	utility_button.add_theme_stylebox_override("pressed", roulette_style)
	utility_button.modulate = Color(0.86, 0.90, 0.95, 1.0)
	utility_button.add_theme_font_size_override("font_size", 20)

func _style_upgrade_rows() -> void:
	var upgrade_row_style: StyleBoxFlat = StyleBoxFlat.new()
	upgrade_row_style.bg_color = Color(0.10, 0.09, 0.14, 0.94)
	upgrade_row_style.border_width_left = 2
	upgrade_row_style.border_width_top = 2
	upgrade_row_style.border_width_right = 2
	upgrade_row_style.border_width_bottom = 2
	upgrade_row_style.border_color = Color(0.46, 0.34, 0.62, 0.88)
	upgrade_row_style.corner_radius_top_left = 12
	upgrade_row_style.corner_radius_top_right = 12
	upgrade_row_style.corner_radius_bottom_left = 12
	upgrade_row_style.corner_radius_bottom_right = 12
	bottom_upgrade_row.add_theme_stylebox_override("panel", upgrade_row_style)
	bottom_upgrade_cards.add_theme_constant_override("separation", 8)
	for top_card in top_upgrade_buttons:
		_style_upgrade_card(top_card, true)
	for bottom_card in bottom_upgrade_buttons:
		_style_upgrade_card(bottom_card, false)

func _style_upgrade_card(card_button: Button, is_top_row: bool) -> void:
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.13, 0.22, 0.98)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.62, 0.48, 0.78, 0.92)
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.shadow_size = 7
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	card_style.shadow_offset = Vector2(0.0, 2.0)
	card_button.add_theme_stylebox_override("normal", card_style)
	card_button.add_theme_stylebox_override("hover", card_style)
	card_button.add_theme_stylebox_override("pressed", card_style)
	card_button.add_theme_font_size_override("font_size", 15)
	card_button.modulate = Color(0.95, 0.92, 0.99, 1.0)
	if is_top_row:
		card_button.custom_minimum_size = Vector2(118.0, 58.0)
	else:
		card_button.custom_minimum_size = Vector2(116.0, 50.0)

func _style_enemy_lanes() -> void:
	enemy_lane_box.add_theme_constant_override("separation", 4)
	enemy_title_label.text = "Path Progress ⇒ Gate"
	enemy_title_label.modulate = Color(0.86, 0.82, 0.92, 1.0)
	for lane_index in enemy_panels.size():
		var lane_panel: Panel = enemy_panels[lane_index]
		var lane_style: StyleBoxFlat = StyleBoxFlat.new()
		lane_style.bg_color = Color(0.06, 0.06, 0.10, 0.94)
		lane_style.border_width_left = 2
		lane_style.border_width_top = 2
		lane_style.border_width_right = 2
		lane_style.border_width_bottom = 2
		lane_style.border_color = Color(0.35, 0.18, 0.43, 0.86)
		lane_style.corner_radius_top_left = 8
		lane_style.corner_radius_top_right = 8
		lane_style.corner_radius_bottom_left = 8
		lane_style.corner_radius_bottom_right = 8
		lane_style.shadow_size = 7
		lane_style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
		lane_style.shadow_offset = Vector2(0.0, 2.0)
		lane_panel.add_theme_stylebox_override("panel", lane_style)
		_apply_lane_portal_ambience(lane_panel, lane_index)
	for lane_label in enemy_labels:
		lane_label.modulate = Color(0.86, 0.86, 0.91, 1.0)
		lane_label.add_theme_font_size_override("font_size", 13)
		lane_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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
	for tile_index in tile_panels.size():
		var panel: Panel = tile_panels[tile_index]
		var tile_style: StyleBoxFlat = StyleBoxFlat.new()
		tile_style.bg_color = Color(0.07, 0.08, 0.10, 0.97)
		tile_style.border_width_left = 2
		tile_style.border_width_top = 2
		tile_style.border_width_right = 2
		tile_style.border_width_bottom = 2
		tile_style.border_color = Color(0.30, 0.28, 0.32, 0.88)
		tile_style.corner_radius_top_left = 10
		tile_style.corner_radius_top_right = 10
		tile_style.corner_radius_bottom_left = 10
		tile_style.corner_radius_bottom_right = 10
		tile_style.shadow_size = 5
		tile_style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
		tile_style.shadow_offset = Vector2(0.0, 2.0)
		panel.add_theme_stylebox_override("panel", tile_style)
		_apply_tile_ritual_ambience(tile_index)

func _apply_lane_portal_ambience(lane_panel: Panel, lane_index: int) -> void:
	var portal_core: ColorRect = ColorRect.new()
	portal_core.anchors_preset = Control.PRESET_FULL_RECT
	portal_core.offset_left = 12.0
	portal_core.offset_top = 12.0
	portal_core.offset_right = -12.0
	portal_core.offset_bottom = -12.0
	portal_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lane_phase: float = float(lane_index) * 0.02
	portal_core.color = Color(0.20 + lane_phase, 0.08, 0.27 + lane_phase, 0.24)
	lane_panel.add_child(portal_core)
	lane_panel.move_child(portal_core, 0)
	lane_portal_core_rects.append(portal_core)

	var portal_ring: ColorRect = ColorRect.new()
	portal_ring.anchors_preset = Control.PRESET_FULL_RECT
	portal_ring.offset_left = 22.0
	portal_ring.offset_top = 22.0
	portal_ring.offset_right = -22.0
	portal_ring.offset_bottom = -22.0
	portal_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portal_ring.color = Color(0.58, 0.25 + lane_phase, 0.73, 0.12)
	lane_panel.add_child(portal_ring)
	lane_panel.move_child(portal_ring, 1)
	lane_portal_ring_rects.append(portal_ring)

func _apply_tile_ritual_ambience(tile_index: int) -> void:
	if tile_index < 0:
		return
	if tile_index >= tile_ritual_slab_rects.size():
		return
	if tile_index >= tile_ritual_glyph_rects.size():
		return
	if tile_index >= tile_ritual_crack_rects.size():
		return
	var slab_rect: ColorRect = tile_ritual_slab_rects[tile_index]
	var glyph_rect: ColorRect = tile_ritual_glyph_rects[tile_index]
	var crack_rect: ColorRect = tile_ritual_crack_rects[tile_index]
	var row_index: int = int(tile_index / BOARD_COLUMNS)
	var row_phase: float = float(row_index) * 0.015
	slab_rect.color = Color(0.09 + row_phase, 0.10 + row_phase, 0.12 + row_phase, 0.72)
	glyph_rect.color = Color(0.53 + row_phase, 0.31, 0.63, 0.15)
	crack_rect.color = Color(0.03, 0.04, 0.05, 0.45 + row_phase)

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
	_update_battle_info_strip()
	_update_lane_monster_positions()

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
		"progress": 0,
		"lane": lane_index,
		"is_hostile_strip": false
	}
	enemy["visual"] = _create_lane_monster_visual(false, lane_index, enemy)
	enemy_lanes[lane_index].append(enemy)
	var opponent_enemy: Dictionary = {
		"name": "W%d Shade" % wave_number,
		"hp": enemy_hp,
		"max_hp": enemy_hp,
		"damage": enemy_damage,
		"progress": 0,
		"lane": lane_index,
		"is_hostile_strip": true
	}
	opponent_enemy["visual"] = _create_lane_monster_visual(true, lane_index, opponent_enemy)
	opponent_lanes[lane_index].append(opponent_enemy)
	spawned_enemies_total += 1

	if spawned_enemies_total % 6 == 0:
		wave_number += 1
		_update_wave_ui()

	status_label.text = "Monsters spawned from both portals in lane %d." % [lane_index + 1]
	_update_enemy_lane_ui()
	_update_lane_monster_positions()

func _tick_enemy_loop() -> void:
	_apply_board_auto_damage()
	_apply_opponent_auto_damage()
	_advance_enemies_toward_gate()
	_advance_opponent_enemies()
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

			_spawn_projectile_feedback("player", tile_index, lane_index, role)
			_damage_front_enemy(lane_index, damage, support_contributed)
			if role == "cleave":
				var splash_ratio: float = float(_get_unit_stat(unit, "splash_ratio", 0.0))
				var splash_damage: int = int(round(float(damage) * splash_ratio))
				_damage_secondary_enemy(lane_index, splash_damage, support_contributed)
	_update_support_feedback_ui()

func _apply_opponent_auto_damage() -> void:
	for lane_index in LANE_COUNT:
		if opponent_lanes[lane_index].is_empty():
			continue
		var attacker_index: int = lane_index
		if attacker_index >= opponent_tile_panels.size():
			attacker_index = lane_index % max(1, opponent_tile_panels.size())
		_spawn_projectile_feedback("opponent", attacker_index, lane_index, "single")
		_damage_front_enemy_in_lanes(opponent_lanes, lane_index, 2 + wave_number)

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
		_remove_lane_monster_visual(enemy)
		enemy_lanes[lane_index].remove_at(front_index)
		status_label.text = "Lane %d enemy defeated by %d damage." % [lane_index + 1, damage]
	else:
		enemy_lanes[lane_index][front_index] = enemy

func _damage_front_enemy_in_lanes(lanes: Array[Array], lane_index: int, damage: int) -> void:
	if damage <= 0 or lane_index < 0 or lane_index >= lanes.size():
		return
	if lanes[lane_index].is_empty():
		return
	var front_index: int = _get_front_enemy_index(lanes[lane_index])
	var enemy: Dictionary = lanes[lane_index][front_index]
	enemy["hp"] = int(enemy["hp"]) - damage
	if int(enemy["hp"]) <= 0:
		_remove_lane_monster_visual(enemy)
		lanes[lane_index].remove_at(front_index)
	else:
		lanes[lane_index][front_index] = enemy

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
		_remove_lane_monster_visual(enemy)
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
				_remove_lane_monster_visual(enemy)
				enemy_lanes[lane_index].remove_at(enemy_index)
				status_label.text = "The gate was hit from lane %d for %d!" % [lane_index + 1, gate_damage]
				_show_gate_hit_feedback(gate_damage)
			else:
				enemy_lanes[lane_index][enemy_index] = enemy

	_update_gate_ui()
	if gate_hp <= 0:
		_trigger_loss()

func _advance_opponent_enemies() -> void:
	for lane_index in LANE_COUNT:
		if opponent_lanes[lane_index].is_empty():
			continue
		for enemy_index in range(opponent_lanes[lane_index].size() - 1, -1, -1):
			var enemy: Dictionary = opponent_lanes[lane_index][enemy_index]
			enemy["progress"] = int(enemy["progress"]) + 1
			if int(enemy["progress"]) >= LANE_LENGTH:
				var core_damage: int = int(enemy["damage"])
				opponent_core_hp = max(0, opponent_core_hp - core_damage)
				_remove_lane_monster_visual(enemy)
				opponent_lanes[lane_index].remove_at(enemy_index)
				status_label.text = "Hostile core was struck from top lane %d for %d." % [lane_index + 1, core_damage]
			else:
				opponent_lanes[lane_index][enemy_index] = enemy

func _trigger_loss() -> void:
	if game_over:
		return

	game_over = true
	loss_label.visible = true
	status_label.text = "Gate HP reached 0. You lost this run."

func _render_board() -> void:
	for i in board_units.size():
		var occupied: bool = not _is_tile_empty(i)
		tile_labels[i].text = _format_tile_compact_label(board_units[i]) if occupied else "Vacant"
		_update_tile_visual_identity(i, occupied)
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
	wave_label.text = "🌊 %d" % wave_number
	_update_battle_info_strip()

func _update_gate_ui() -> void:
	gate_label.text = "❤ %d" % gate_hp
	_update_battle_info_strip()

func _update_board_power_ui() -> void:
	board_power_label.text = "⚔ %d" % _get_board_power()
	_update_battle_info_strip()

func _update_battle_info_strip() -> void:
	var player_life: int = gate_hp
	var opponent_life: int = opponent_core_hp
	var timer_left: float = max(0.0, SPAWN_INTERVAL_SECONDS - spawn_timer)
	var enemy_count: int = 0
	var opponent_count: int = 0
	for lane_index in LANE_COUNT:
		enemy_count += enemy_lanes[lane_index].size()
		opponent_count += opponent_lanes[lane_index].size()
	var pressure: int = enemy_count + opponent_count
	var boss_count: int = int(wave_number / 5)
	life_info_label.text = "❤ %d | ☠ %d" % [player_life, opponent_life]
	wave_info_label.text = "🌊 %d" % wave_number
	timer_info_label.text = "⏱ %.1f" % timer_left
	boss_info_label.text = "👑 %d" % boss_count
	pressure_info_label.text = "☣ %d" % pressure

func _update_enemy_lane_ui() -> void:
	for lane_index in LANE_COUNT:
		var lane_text: String = "Lane %d: " % [lane_index + 1]
		_set_lane_panel_base_visual(lane_index)
		if enemy_lanes[lane_index].is_empty():
			var clear_line: String = lane_text + "Clear"
			if lane_index < support_feedback_lines.size():
				clear_line += " | " + support_feedback_lines[lane_index]
			enemy_labels[lane_index].text = clear_line
			if lane_index < player_lane_target_labels.size():
				player_lane_target_labels[lane_index].text = "Player Lane %d • Clear" % [lane_index + 1]
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
		if lane_index < player_lane_target_labels.size():
			player_lane_target_labels[lane_index].text = "Player Lane %d • %d mobs" % [lane_index + 1, enemy_lanes[lane_index].size()]

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
	_flash_gate_core(player_gate_panel)

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

func _update_tile_visual_identity(tile_index: int, occupied: bool) -> void:
	if tile_index < 0 or tile_index >= tile_icon_labels.size():
		return
	if tile_index >= tile_icon_glow_rects.size() or tile_index >= tile_level_badge_rects.size() or tile_index >= tile_level_badge_labels.size():
		return
	var icon_label: Label = tile_icon_labels[tile_index]
	var icon_glow: ColorRect = tile_icon_glow_rects[tile_index]
	var level_badge: ColorRect = tile_level_badge_rects[tile_index]
	var level_label: Label = tile_level_badge_labels[tile_index]
	if not occupied:
		icon_label.text = ""
		icon_glow.color = Color(0.56, 0.67, 0.92, 0.0)
		level_badge.color = Color(0.78, 0.68, 0.33, 0.0)
		level_label.text = ""
		level_label.modulate = Color(0.08, 0.08, 0.08, 0.0)
		return
	var unit: Dictionary = board_units[tile_index]
	var role: String = _get_unit_role(unit)
	var icon_color: Color = Color(0.78, 0.89, 0.98, 1.0)
	var glow_color: Color = Color(0.28, 0.44, 0.69, 0.36)
	if role == "support":
		icon_color = Color(0.91, 0.79, 0.99, 1.0)
		glow_color = Color(0.56, 0.33, 0.76, 0.44)
	elif role == "cleave":
		icon_color = Color(0.98, 0.82, 0.58, 1.0)
		glow_color = Color(0.75, 0.48, 0.20, 0.40)
	icon_label.text = _get_unit_icon(unit)
	icon_label.modulate = icon_color
	icon_glow.color = glow_color
	var level_value: int = int(unit["level"])
	level_badge.color = Color(0.86, 0.78, 0.41, 0.95)
	level_label.text = "L%d" % level_value
	level_label.modulate = Color(0.08, 0.08, 0.08, 1.0)

func _get_unit_icon(unit: Dictionary) -> String:
	var role: String = _get_unit_role(unit)
	var icon_variant: Variant = ROLE_ICONS.get(role, "◆")
	return str(icon_variant)

func _format_tile_compact_label(unit: Dictionary) -> String:
	var role_tag: String = _get_unit_role_tag(unit)
	var short_name: String = _get_unit_short_name(unit)
	if _get_unit_role(unit) == "support":
		var support_level: int = int(unit["level"])
		var lane_buff_total: int = int(_get_unit_stat(unit, "lane_buff_base", 0))
		lane_buff_total += int(_get_unit_stat(unit, "lane_buff_per_level", 0)) * support_level
		return "%s • %s\nAura +%d" % [short_name, role_tag, lane_buff_total]
	return "%s • %s\nATK %d" % [short_name, role_tag, _get_unit_base_damage(unit)]

func _spawn_projectile_feedback(owner: String, tile_index: int, lane_index: int, role: String) -> void:
	if combat_fx_layer == null:
		return
	var source_panel: Panel = _get_source_panel_for_owner(owner, tile_index)
	var lane_target_panel: Control = _get_lane_target_monster(owner, lane_index)
	if source_panel == null or lane_target_panel == null:
		return
	var source_center: Vector2 = _get_control_center_in(combat_fx_layer, source_panel)
	var target_center: Vector2 = _get_control_center_in(combat_fx_layer, lane_target_panel)
	var direction: Vector2 = target_center - source_center
	var travel_distance: float = direction.length()
	if travel_distance < 8.0:
		return
	var projectile: ColorRect = ColorRect.new()
	projectile.size = Vector2(max(24.0, travel_distance * 0.24), 3.0)
	projectile.position = source_center
	projectile.pivot_offset = Vector2(0.0, 1.5)
	projectile.rotation = direction.angle()
	projectile.color = Color(0.82, 0.90, 1.0, 0.90)
	if role == "support":
		projectile.color = Color(0.84, 0.66, 0.97, 0.90)
	elif role == "cleave":
		projectile.color = Color(0.97, 0.73, 0.48, 0.92)
	if owner == "opponent":
		projectile.color = Color(0.94, 0.52, 0.78, 0.90)
	projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_fx_layer.add_child(projectile)
	var tween: Tween = create_tween()
	tween.tween_property(projectile, "position", target_center, 0.18)
	tween.parallel().tween_property(projectile, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func() -> void:
		if is_instance_valid(projectile):
			projectile.queue_free()
	)

func _get_control_center_in(local_root: Control, target: Control) -> Vector2:
	var global_rect: Rect2 = target.get_global_rect()
	var local_position: Vector2 = _global_to_control_space(local_root, global_rect.position)
	return local_position + (global_rect.size * 0.5)

func _create_lane_monster_visual(is_hostile_strip: bool, lane_index: int, enemy: Dictionary) -> Control:
	var strip_panel: Panel = player_strip_panel
	var layer_host: Control = player_monster_layer
	if is_hostile_strip:
		strip_panel = enemy_strip_panel
		layer_host = hostile_monster_layer
	if strip_panel == null:
		return null
	if layer_host == null:
		return null
	var monster_panel: Panel = Panel.new()
	monster_panel.custom_minimum_size = Vector2(40.0, 40.0)
	monster_panel.size = Vector2(40.0, 40.0)
	monster_panel.pivot_offset = monster_panel.size * 0.5
	monster_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monster_panel.z_index = 10
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = OPPONENT_MONSTER_COLOR if is_hostile_strip else PLAYER_MONSTER_COLOR
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = OPPONENT_MONSTER_EDGE if is_hostile_strip else PLAYER_MONSTER_EDGE
	panel_style.corner_radius_top_left = 15
	panel_style.corner_radius_top_right = 15
	panel_style.corner_radius_bottom_left = 15
	panel_style.corner_radius_bottom_right = 15
	panel_style.shadow_size = 10
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	panel_style.shadow_offset = Vector2(0.0, 2.0)
	monster_panel.add_theme_stylebox_override("panel", panel_style)
	layer_host.add_child(monster_panel)
	layer_host.move_child(monster_panel, layer_host.get_child_count() - 1)
	lane_monster_visuals.append(monster_panel)

	var core: ColorRect = ColorRect.new()
	core.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	core.offset_left = 8.0
	core.offset_top = 8.0
	core.offset_right = -8.0
	core.offset_bottom = -8.0
	core.color = Color(0.10, 0.10, 0.12, 0.82)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monster_panel.add_child(core)

	var glyph_label: Label = Label.new()
	glyph_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph_label.add_theme_font_size_override("font_size", 24)
	glyph_label.add_theme_constant_override("outline_size", 2)
	glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_hostile_strip:
		glyph_label.text = OPPONENT_MONSTER_ICON_SET[lane_index % OPPONENT_MONSTER_ICON_SET.size()]
		glyph_label.modulate = Color(0.99, 0.82, 0.95, 1.0)
	else:
		glyph_label.text = PLAYER_MONSTER_ICON_SET[lane_index % PLAYER_MONSTER_ICON_SET.size()]
		glyph_label.modulate = Color(0.85, 0.97, 1.0, 1.0)
	monster_panel.add_child(glyph_label)
	var initial_position: Vector2 = _get_lane_point_for_progress(is_hostile_strip, lane_index, 0.0)
	monster_panel.position = initial_position - (monster_panel.size * 0.5)
	return monster_panel

func _remove_lane_monster_visual(enemy: Dictionary) -> void:
	var visual_variant: Variant = enemy.get("visual", null)
	var visual: Control = visual_variant as Control
	if visual == null:
		return
	lane_monster_visuals.erase(visual)
	if is_instance_valid(visual):
		visual.queue_free()

func _update_lane_monster_positions() -> void:
	var interp_alpha: float = clamp(advance_timer / ADVANCE_INTERVAL_SECONDS, 0.0, 1.0)
	_update_lane_set_visuals(enemy_lanes, false, interp_alpha)
	_update_lane_set_visuals(opponent_lanes, true, interp_alpha)

func _update_lane_set_visuals(lanes: Array[Array], is_hostile_strip: bool, interp_alpha: float) -> void:
	for lane_index in lanes.size():
		var lane_enemies: Array = lanes[lane_index]
		for enemy_data in lane_enemies:
			var enemy: Dictionary = enemy_data
			var visual_variant: Variant = enemy.get("visual", null)
			var visual: Control = visual_variant as Control
			if visual == null:
				continue
			var progress_value: float = float(int(enemy["progress"])) + interp_alpha
			var progress_ratio: float = clamp(progress_value / float(LANE_LENGTH), 0.0, 1.0)
			var point: Vector2 = _get_lane_point_for_progress(is_hostile_strip, lane_index, progress_ratio)
			visual.position = point - (visual.size * 0.5)

func _get_lane_point_for_progress(is_hostile_strip: bool, lane_index: int, progress_ratio: float) -> Vector2:
	var path_points: Array[Vector2] = _get_lane_path_points(is_hostile_strip)
	if path_points.size() < 2:
		return Vector2.ZERO
	var segment_count: int = path_points.size() - 1
	var scaled: float = clamp(progress_ratio, 0.0, 1.0) * float(segment_count)
	var segment_index: int = min(segment_count - 1, int(floor(scaled)))
	var segment_alpha: float = scaled - float(segment_index)
	var start_point: Vector2 = path_points[segment_index]
	var end_point: Vector2 = path_points[segment_index + 1]
	var lane_spread: float = (float(lane_index) - 1.0) * 12.0
	var base_position: Vector2 = start_point.lerp(end_point, segment_alpha)
	return base_position + Vector2(0.0, lane_spread)

func _get_lane_path_points(is_hostile_strip: bool) -> Array[Vector2]:
	var strip_panel: Panel = player_strip_panel
	var spawn_panel: Panel = player_spawn_panel
	var board_target: Panel = board_panel
	var gate_panel: Panel = player_gate_panel
	if is_hostile_strip:
		strip_panel = enemy_strip_panel
		spawn_panel = enemy_spawn_panel
		board_target = opponent_board_panel
		gate_panel = enemy_gate_panel
	if strip_panel == null or spawn_panel == null or board_target == null or gate_panel == null:
		return []
	var spawn_rect: Rect2 = _rect_in_local_space(strip_panel, spawn_panel)
	var board_rect: Rect2 = _rect_in_local_space(strip_panel, board_target)
	var gate_rect: Rect2 = _rect_in_local_space(strip_panel, gate_panel)
	var left_x: float = board_rect.position.x - 18.0
	var right_x: float = board_rect.position.x + board_rect.size.x + 18.0
	if is_hostile_strip:
		var top_y: float = board_rect.position.y + 10.0
		var bottom_y: float = board_rect.position.y + board_rect.size.y - 10.0
		var hostile_spawn_y: float = spawn_rect.position.y + 14.0
		var hostile_gate_y: float = gate_rect.position.y + 14.0
		return [
			Vector2(spawn_rect.position.x + spawn_rect.size.x - 10.0, hostile_spawn_y),
			Vector2(left_x, hostile_spawn_y),
			Vector2(left_x, top_y),
			Vector2(left_x, bottom_y),
			Vector2(right_x, bottom_y),
			Vector2(right_x, top_y),
			Vector2(gate_rect.position.x + 10.0, hostile_gate_y)
		]
	var player_bottom_y: float = board_rect.position.y + board_rect.size.y - 10.0
	var player_top_y: float = board_rect.position.y + 10.0
	var player_spawn_y: float = spawn_rect.position.y + spawn_rect.size.y - 14.0
	var player_gate_y: float = gate_rect.position.y + gate_rect.size.y - 14.0
	return [
		Vector2(spawn_rect.position.x + spawn_rect.size.x - 10.0, player_spawn_y),
		Vector2(left_x, player_spawn_y),
		Vector2(left_x, player_bottom_y),
		Vector2(left_x, player_top_y),
		Vector2(right_x, player_top_y),
		Vector2(right_x, player_bottom_y),
		Vector2(gate_rect.position.x + 10.0, player_gate_y)
	]

func _get_front_monster_visual(lanes: Array[Array], lane_index: int) -> Control:
	if lane_index < 0 or lane_index >= lanes.size():
		return null
	var lane_enemies: Array = lanes[lane_index]
	if lane_enemies.is_empty():
		return null
	var front_index: int = _get_front_enemy_index(lane_enemies)
	var enemy: Dictionary = lane_enemies[front_index]
	var visual_variant: Variant = enemy.get("visual", null)
	return visual_variant as Control

func _get_source_panel_for_owner(owner: String, tile_index: int) -> Panel:
	if owner == "opponent":
		if tile_index < 0 or tile_index >= opponent_tile_panels.size():
			return null
		return opponent_tile_panels[tile_index]
	if tile_index < 0 or tile_index >= tile_panels.size():
		return null
	return tile_panels[tile_index]

func _get_lane_target_monster(owner: String, lane_index: int) -> Control:
	if owner == "opponent":
		return _get_front_monster_visual(opponent_lanes, lane_index)
	return _get_front_monster_visual(enemy_lanes, lane_index)

func _decorate_spawn_gate_identity() -> void:
	_add_identity_overlay(player_spawn_panel, Color(0.42, 0.66, 0.73, 0.26), "◌")
	_add_identity_overlay(player_gate_panel, Color(0.57, 0.82, 0.88, 0.24), "✥")
	_add_identity_overlay(enemy_spawn_panel, Color(0.65, 0.24, 0.48, 0.30), "✶")
	_add_identity_overlay(enemy_gate_panel, Color(0.78, 0.25, 0.51, 0.30), "☬")

func _add_identity_overlay(panel: Panel, tint: Color, glyph: String) -> void:
	var haze: ColorRect = ColorRect.new()
	haze.anchors_preset = Control.PRESET_FULL_RECT
	haze.offset_left = 8.0
	haze.offset_top = 8.0
	haze.offset_right = -8.0
	haze.offset_bottom = -8.0
	haze.color = tint
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(haze)
	panel.move_child(haze, 0)
	var sigil: Label = Label.new()
	sigil.anchors_preset = Control.PRESET_FULL_RECT
	sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sigil.text = glyph
	sigil.modulate = Color(1.0, 1.0, 1.0, 0.30)
	sigil.add_theme_font_size_override("font_size", 36)
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sigil)
	if panel == player_gate_panel:
		gate_flash_overlays["player_gate"] = haze

func _flash_gate_core(gate_panel: Panel) -> void:
	if gate_panel != player_gate_panel:
		return
	var overlay_variant: Variant = gate_flash_overlays.get("player_gate", null)
	if overlay_variant == null:
		return
	var overlay: ColorRect = overlay_variant as ColorRect
	if overlay == null:
		return
	var base_color: Color = overlay.color
	var tween: Tween = create_tween()
	tween.tween_property(overlay, "color", Color(1.0, 0.45, 0.52, 0.52), 0.08)
	tween.tween_property(overlay, "color", base_color, 0.22)

func _set_lane_panel_base_visual(lane_index: int) -> void:
	if lane_index < 0 or lane_index >= enemy_panels.size():
		return
	var lane_panel: Panel = enemy_panels[lane_index]
	var lane_bonus: int = _get_lane_support_bonus(lane_index)
	if lane_bonus > 0:
		lane_panel.self_modulate = LANE_AURA_COLOR
	else:
		lane_panel.self_modulate = LANE_IDLE_COLOR
