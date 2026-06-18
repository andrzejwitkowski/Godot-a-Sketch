@tool
extends Control

const SETTINGS_PREFIX := "godot_a_sketch/"
const DEFAULT_LAYER_NAME := "Layer 1"
const DEFAULT_SIZE := 32.0
const DEFAULT_OPACITY := 100.0
const DEFAULT_HARDNESS := 50.0

@onready var _stack_list: ItemList = $Margin/VBox/StackSection/StackList
@onready var _add_button: Button = $Margin/VBox/StackSection/StackButtons/AddButton
@onready var _remove_button: Button = $Margin/VBox/StackSection/StackButtons/RemoveButton
@onready var _size_slider: HSlider = $Margin/VBox/BrushSection/SizeRow/SizeSlider
@onready var _size_spin: SpinBox = $Margin/VBox/BrushSection/SizeRow/SizeSpin
@onready var _opacity_slider: HSlider = $Margin/VBox/BrushSection/OpacityRow/OpacitySlider
@onready var _opacity_label: Label = $Margin/VBox/BrushSection/OpacityRow/OpacityLabel
@onready var _hardness_slider: HSlider = $Margin/VBox/BrushSection/HardnessRow/HardnessSlider
@onready var _hardness_label: Label = $Margin/VBox/BrushSection/HardnessRow/HardnessLabel

var _brush_size: float = DEFAULT_SIZE
var _brush_opacity: float = DEFAULT_OPACITY
var _brush_hardness: float = DEFAULT_HARDNESS
var _loading := false


func _ready() -> void:
	_setup_brush_ranges()
	_connect_signals()
	_load_settings()


func _setup_brush_ranges() -> void:
	_size_slider.min_value = 1.0
	_size_slider.max_value = 256.0
	_size_slider.step = 1.0
	_size_spin.min_value = 1.0
	_size_spin.max_value = 256.0
	_size_spin.step = 1.0
	_opacity_slider.min_value = 0.0
	_opacity_slider.max_value = 100.0
	_opacity_slider.step = 1.0
	_hardness_slider.min_value = 0.0
	_hardness_slider.max_value = 100.0
	_hardness_slider.step = 1.0


func _connect_signals() -> void:
	_add_button.pressed.connect(_on_add_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)
	_size_slider.value_changed.connect(_on_size_slider_changed)
	_size_spin.value_changed.connect(_on_size_spin_changed)
	_opacity_slider.value_changed.connect(_on_opacity_changed)
	_hardness_slider.value_changed.connect(_on_hardness_changed)


func _load_settings() -> void:
	_loading = true
	var settings := EditorInterface.get_editor_settings()

	_brush_size = float(_read_setting(settings, SETTINGS_PREFIX + "brush/size", DEFAULT_SIZE))
	_brush_opacity = float(_read_setting(settings, SETTINGS_PREFIX + "brush/opacity", DEFAULT_OPACITY))
	_brush_hardness = float(_read_setting(settings, SETTINGS_PREFIX + "brush/hardness", DEFAULT_HARDNESS))
	var stack_names: PackedStringArray = _read_setting(
		settings,
		SETTINGS_PREFIX + "stack/names",
		PackedStringArray([DEFAULT_LAYER_NAME])
	)

	_size_slider.value = _brush_size
	_size_spin.value = _brush_size
	_opacity_slider.value = _brush_opacity
	_opacity_label.text = "%d%%" % int(_brush_opacity)
	_hardness_slider.value = _brush_hardness
	_hardness_label.text = "%d%%" % int(_brush_hardness)

	_stack_list.clear()
	for layer_name in stack_names:
		_stack_list.add_item(layer_name)

	_loading = false


func _read_setting(settings: EditorSettings, key: String, default_value: Variant) -> Variant:
	if settings.has_setting(key):
		return settings.get_setting(key)
	return default_value


func _save_settings() -> void:
	if _loading:
		return
	var settings := EditorInterface.get_editor_settings()
	settings.set_setting(SETTINGS_PREFIX + "brush/size", _brush_size)
	settings.set_setting(SETTINGS_PREFIX + "brush/opacity", _brush_opacity)
	settings.set_setting(SETTINGS_PREFIX + "brush/hardness", _brush_hardness)
	settings.set_setting(SETTINGS_PREFIX + "stack/names", _get_stack_names_packed())


func _get_stack_names_packed() -> PackedStringArray:
	var names := PackedStringArray()
	for i in _stack_list.item_count:
		names.append(_stack_list.get_item_text(i))
	return names


func _next_layer_name() -> String:
	var n := _stack_list.item_count + 1
	while _stack_list.find_item_text("Layer %d" % n) != -1:
		n += 1
	return "Layer %d" % n


func _on_add_pressed() -> void:
	_stack_list.add_item(_next_layer_name())
	_save_settings()


func _on_remove_pressed() -> void:
	var selected := _stack_list.get_selected_items()
	if selected.is_empty():
		return
	selected.sort()
	selected.reverse()
	for idx in selected:
		_stack_list.remove_item(idx)
	_save_settings()


func _on_size_slider_changed(value: float) -> void:
	_brush_size = value
	if not _loading and _size_spin.value != value:
		_size_spin.value = value
	if not _loading:
		_save_settings()


func _on_size_spin_changed(value: float) -> void:
	_brush_size = value
	if not _loading and _size_slider.value != value:
		_size_slider.value = value
	if not _loading:
		_save_settings()


func _on_opacity_changed(value: float) -> void:
	_brush_opacity = value
	_opacity_label.text = "%d%%" % int(value)
	if not _loading:
		_save_settings()


func _on_hardness_changed(value: float) -> void:
	_brush_hardness = value
	_hardness_label.text = "%d%%" % int(value)
	if not _loading:
		_save_settings()


func get_brush_size() -> float:
	return _brush_size


func get_brush_opacity_percent() -> float:
	return _brush_opacity


func get_brush_hardness_percent() -> float:
	return _brush_hardness


func get_stack_names() -> PackedStringArray:
	return _get_stack_names_packed()
