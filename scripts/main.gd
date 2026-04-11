extends Control

const BOARD_COLUMNS := 5
const BOARD_ROWS := 3
const EMPTY_TILE_TEXT := "Empty"

var next_unit := 0
var unit_names := ["Unit A", "Unit B", "Unit C", "Unit D"]
var board_units: Array[String] = []
var tile_panels: Array[Panel] = []
var tile_labels: Array[Label] = []

@onready var summon_button: Button = $TopBar/TopRow/SummonButton
@onready var status_label: Label = $StatusLabel
@onready var wave_label: Label = $TopBar/TopRow/WaveLabel
@onready var tile_grid: GridContainer = $Board/BoardMargin/TileGrid

func _ready() -> void:
	board_units.resize(BOARD_COLUMNS * BOARD_ROWS)
	for i in board_units.size():
		board_units[i] = ""

	for tile in tile_grid.get_children():
		var panel := tile as Panel
		if panel == null:
			continue
		tile_panels.append(panel)
		var label := panel.get_node("TileLabel") as Label
		tile_labels.append(label)

	summon_button.pressed.connect(_on_summon_pressed)
	_render_board()
	status_label.text = "Prototype loaded. Ready to summon."

func _on_summon_pressed() -> void:
	var empty_index := board_units.find("")
	if empty_index == -1:
		status_label.text = "Board is full. Merge or clear a tile before summoning."
		return

	var summoned := unit_names[next_unit]
	next_unit = (next_unit + 1) % unit_names.size()
	board_units[empty_index] = summoned
	wave_label.text = "Wave: 1"
	_render_board()
	status_label.text = "Summoned %s into tile %d." % [summoned, empty_index + 1]

func _render_board() -> void:
	for i in board_units.size():
		var occupied := board_units[i] != ""
		tile_labels[i].text = board_units[i] if occupied else EMPTY_TILE_TEXT
		tile_panels[i].self_modulate = Color(0.31, 0.47, 0.38, 1.0) if occupied else Color(0.22, 0.24, 0.31, 1.0)
