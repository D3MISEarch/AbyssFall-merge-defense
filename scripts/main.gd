extends Control

const BOARD_COLUMNS := 5
const BOARD_ROWS := 3
const EMPTY_TILE_TEXT := "Empty"
const MAX_LEVEL := 3

var next_unit := 0
var unit_names := ["Unit A", "Unit B", "Unit C", "Unit D"]
var board_units: Array[Dictionary] = []
var tile_panels: Array[Panel] = []
var tile_labels: Array[Label] = []
var selected_tile_index := -1

@onready var summon_button: Button = $TopBar/TopRow/SummonButton
@onready var status_label: Label = $StatusLabel
@onready var wave_label: Label = $TopBar/TopRow/WaveLabel
@onready var tile_grid: GridContainer = $Board/BoardMargin/TileGrid

func _ready() -> void:
	board_units.resize(BOARD_COLUMNS * BOARD_ROWS)
	for i in board_units.size():
		board_units[i] = {}

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
	status_label.text = "Prototype loaded. Ready to summon."

func _on_summon_pressed() -> void:
	var empty_index := _find_empty_tile()
	if empty_index == -1:
		status_label.text = "Board is full. Merge or clear a tile before summoning."
		return

	var summoned_name := unit_names[next_unit]
	next_unit = (next_unit + 1) % unit_names.size()
	board_units[empty_index] = {"name": summoned_name, "level": 1}
	wave_label.text = "Wave: 1"
	_render_board()
	status_label.text = "Summoned %s into tile %d." % [_format_unit(board_units[empty_index]), empty_index + 1]

func _on_tile_gui_input(event: InputEvent, tile_index: int) -> void:
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

func _render_board() -> void:
	for i in board_units.size():
		var occupied := not _is_tile_empty(i)
		tile_labels[i].text = _format_unit(board_units[i]) if occupied else EMPTY_TILE_TEXT

		if i == selected_tile_index:
			tile_panels[i].self_modulate = Color(0.92, 0.75, 0.32, 1.0)
		else:
			tile_panels[i].self_modulate = Color(0.31, 0.47, 0.38, 1.0) if occupied else Color(0.22, 0.24, 0.31, 1.0)

func _find_empty_tile() -> int:
	for i in board_units.size():
		if _is_tile_empty(i):
			return i
	return -1

func _is_tile_empty(tile_index: int) -> bool:
	return board_units[tile_index].is_empty()

func _format_unit(unit: Dictionary) -> String:
	return "%s Lv%d" % [unit["name"], int(unit["level"])]
