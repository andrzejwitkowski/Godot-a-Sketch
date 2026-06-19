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
@onready var _mark_brushable_button: Button = $Margin/VBox/TargetSection/TargetButtons/MarkBrushableButton
@onready var _unmark_brushable_button: Button = $Margin/VBox/TargetSection/TargetButtons/UnmarkBrushableButton
@onready var _modifier_option: OptionButton = $Margin/VBox/TargetSection/ModifierRow/ModifierOption
@onready var _raycast_label: Label = $Margin/VBox/TargetSection/RaycastLabel

var _brush_size: float = DEFAULT_SIZE
var _brush_opacity: float = DEFAULT_OPACITY
var _brush_hardness: float = DEFAULT_HARDNESS
var _modifier_mask: int = GodotASketchConstants.DEFAULT_MODIFIER_MASK
var _loading := false


func _ready() -> void:
	_setup_brush_ranges()
	_setup_modifier_option()
	_connect_signals()
	_load_settings()


func _setup_modifier_option() -> void:
	_modifier_option.clear()
	_modifier_option.add_item("None")
	_modifier_option.set_item_metadata(0, GodotASketchConstants.MODIFIER_NONE)
	_modifier_option.add_item("Shift")
	_modifier_option.set_item_metadata(1, KEY_MASK_SHIFT)
	_modifier_option.add_item("Alt")
	_modifier_option.set_item_metadata(2, KEY_MASK_ALT)
	_modifier_option.add_item("Ctrl")
	_modifier_option.set_item_metadata(3, KEY_MASK_CTRL)


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
	_mark_brushable_button.pressed.connect(_on_mark_brushable_pressed)
	_unmark_brushable_button.pressed.connect(_on_unmark_brushable_pressed)
	_modifier_option.item_selected.connect(_on_modifier_selected)
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

	_modifier_mask = int(_read_setting(
		settings,
		GodotASketchConstants.SETTINGS_MODIFIER_KEY,
		GodotASketchConstants.DEFAULT_MODIFIER_MASK
	))
	_select_modifier_option(_modifier_mask)

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
	settings.set_setting(GodotASketchConstants.SETTINGS_MODIFIER_KEY, _modifier_mask)


func _select_modifier_option(mask: int) -> void:
	for i in _modifier_option.item_count:
		if int(_modifier_option.get_item_metadata(i)) == mask:
			_modifier_option.select(i)
			return
	_modifier_option.select(0)
	_modifier_mask = int(_modifier_option.get_item_metadata(0))


func _on_mark_brushable_pressed() -> void:
	var node := _get_selected_node3d()
	if node == null:
		update_raycast_debug_message("Select a MeshInstance3D")
		return
	var err := GodotASketchBrushable.mark(node)
	update_raycast_debug_message(err if err != "" else "Marked brushable")


func _on_unmark_brushable_pressed() -> void:
	var node := _get_selected_node3d()
	if node == null:
		update_raycast_debug_message("Select a MeshInstance3D")
		return
	var err := GodotASketchBrushable.unmark(node)
	update_raycast_debug_message(err if err != "" else "Unmarked brushable")


func _on_modifier_selected(index: int) -> void:
	_modifier_mask = int(_modifier_option.get_item_metadata(index))
	_save_settings()


func _get_selected_node3d() -> Node3D:
	var nodes := EditorInterface.get_selection().get_selected_nodes()
	if nodes.is_empty():
		return null
	var node: Node = nodes[0]
	if node is Node3D:
		return node
	return null


func is_raycast_modifier_active(event: InputEvent) -> bool:
	if not event is InputEventMouse:
		return false
	return _is_modifier_held()


func _is_modifier_held() -> bool:
	if _modifier_mask == GodotASketchConstants.MODIFIER_NONE:
		return true
	if _modifier_mask == KEY_MASK_SHIFT:
		return Input.is_key_pressed(KEY_SHIFT)
	if _modifier_mask == KEY_MASK_ALT:
		return Input.is_key_pressed(KEY_ALT)
	if _modifier_mask == KEY_MASK_CTRL:
		return Input.is_key_pressed(KEY_CTRL)
	return false


func update_raycast_debug(hit: Dictionary) -> void:
	if hit.is_empty():
		_raycast_label.text = "No hit"
		return
	var node: Node = hit.get("brushable_node", hit.get("collider"))
	var pos: Vector3 = hit.get("position", Vector3.ZERO)
	_raycast_label.text = "%s @ %s" % [node.name, _format_vector(pos)]


func update_raycast_debug_message(message: String) -> void:
	_raycast_label.text = message


func get_modifier_mask() -> int:
	return _modifier_mask


func _format_vector(pos: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [pos.x, pos.y, pos.z]


func _get_stack_names_packed() -> PackedStringArray:
	var names := PackedStringArray()
	for i in _stack_list.item_count:
		names.append(_stack_list.get_item_text(i))
	return names


func _next_layer_name() -> String:
	var n := _stack_list.item_count + 1
	var candidate := "Layer %d" % n
	while _stack_has_item(candidate):
		n += 1
		candidate = "Layer %d" % n
	return candidate


func _stack_has_item(text: String) -> bool:
	for i in _stack_list.item_count:
		if _stack_list.get_item_text(i) == text:
			return true
	return false


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
