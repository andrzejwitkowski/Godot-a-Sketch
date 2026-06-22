@tool
extends Control

signal ghost_settings_changed

const SETTINGS_PREFIX := "godot_a_sketch/"
const DEFAULT_SIZE := 32.0
const DEFAULT_OPACITY := 100.0
const DEFAULT_HARDNESS := 50.0
const MAX_STACK_LAYERS := 4

const MENU_FROM_MESH := 0
const MENU_BROWSE := 1
const MENU_TEMPLATE := 2
const MENU_TEMPLATE_LAYER := 3
const _MASK_CHANNELS := ["R", "G", "B", "A"]
const SplatMapAssign := preload("res://addons/godot_a_sketch/godot_a_sketch_splat_map_assign.gd")
const ShaderStackAssign := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_stack_assign.gd")
const ShaderStack := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_stack.gd")
const ShaderStackLayer := preload("res://addons/godot_a_sketch/godot_a_sketch_shader_stack_layer.gd")

@onready var _stack_hint: Label = $Margin/VBox/StackSection/StackHintLabel
@onready var _refresh_button: Button = $Margin/VBox/StackSection/StackCatalogRow/RefreshButton
@onready var _catalog_count_label: Label = $Margin/VBox/StackSection/StackCatalogRow/CatalogCountLabel
@onready var _shader_catalog_list: ItemList = $Margin/VBox/StackSection/ShaderCatalogList
@onready var _add_layer_contract_button: Button = $Margin/VBox/StackSection/AddLayerContractButton
@onready var _stack_list: ItemList = $Margin/VBox/StackSection/StackList
@onready var _splat_preview_label: Label = $Margin/VBox/StackSection/SplatPreviewLabel
@onready var _splat_preview: TextureRect = $Margin/VBox/StackSection/SplatPreview
@onready var _add_menu: MenuButton = $Margin/VBox/StackSection/StackButtons/AddMenuButton
@onready var _remove_button: Button = $Margin/VBox/StackSection/StackButtons/RemoveButton
@onready var _up_button: Button = $Margin/VBox/StackSection/StackButtons/UpButton
@onready var _down_button: Button = $Margin/VBox/StackSection/StackButtons/DownButton
@onready var _copy_stack_button: Button = $Margin/VBox/StackSection/StackButtons2/CopyStackButton
@onready var _paste_stack_button: Button = $Margin/VBox/StackSection/StackButtons2/PasteStackButton
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
@onready var _status_label: Label = $Margin/VBox/TargetSection/StatusLabel
@onready var _show_ghost_check: CheckBox = $Margin/VBox/TargetSection/ShowGhostRow/ShowGhostCheck
@onready var _mode_option: OptionButton = $Margin/VBox/TargetSection/ModeRow/ModeOption

var _brush_size: float = DEFAULT_SIZE
var _brush_opacity: float = DEFAULT_OPACITY
var _brush_hardness: float = DEFAULT_HARDNESS
var _modifier_mask: int = GodotASketchConstants.DEFAULT_MODIFIER_MASK
var _show_ghost: bool = GodotASketchConstants.DEFAULT_SHOW_GHOST
var _brush_mode: int = GodotASketchConstants.BrushMode.PAINT
var _loading := false
var _target_mesh: MeshInstance3D
var _context_mesh: MeshInstance3D
var _pending_legacy_names: PackedStringArray = PackedStringArray()
var _stack_clipboard: GodotASketchShaderStack
var _selected_catalog_entry: GodotASketchShaderCatalogEntry
var _notify_dialog: AcceptDialog
var _browse_dialog: EditorFileDialog
var _template_dialog: EditorFileDialog


func _ready() -> void:
	_setup_brush_ranges()
	_setup_modifier_option()
	_setup_mode_option()
	_setup_add_menu()
	_setup_file_dialogs()
	_load_migration_state()
	_connect_signals()
	_load_settings()
	refresh_shader_catalog(true)
	refresh_shader_stack_ui()


func refresh_shader_catalog(probe_shaders: bool = false) -> void:
	GodotASketchShaderCatalog.rescan(probe_shaders)
	_populate_shader_catalog_list()
	_update_catalog_label()
	_update_layer_contract_button()


func _setup_add_menu() -> void:
	var popup := _add_menu.get_popup()
	popup.add_item("Template layer (quick start)", MENU_TEMPLATE_LAYER)
	popup.add_separator()
	popup.add_item("From selected mesh", MENU_FROM_MESH)
	popup.add_item("Browse shader…", MENU_BROWSE)
	popup.add_item("New from template…", MENU_TEMPLATE)
	popup.id_pressed.connect(_on_add_menu_id_pressed)


func _setup_file_dialogs() -> void:
	_browse_dialog = EditorFileDialog.new()
	_browse_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_browse_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_browse_dialog.add_filter("*.gdshader", "Godot Shaders")
	_browse_dialog.file_selected.connect(_on_browse_shader_selected)
	add_child(_browse_dialog)

	_template_dialog = EditorFileDialog.new()
	_template_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_template_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_template_dialog.add_filter("*.gdshader", "Godot Shaders")
	_template_dialog.file_selected.connect(_on_template_saved)
	add_child(_template_dialog)


func _setup_mode_option() -> void:
	_mode_option.clear()
	_mode_option.add_item("Paint")
	_mode_option.set_item_metadata(0, GodotASketchConstants.BrushMode.PAINT)
	_mode_option.add_item("Sculpt")
	_mode_option.set_item_metadata(1, GodotASketchConstants.BrushMode.SCULPT)


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
	_refresh_button.pressed.connect(_on_refresh_catalog_pressed)
	_shader_catalog_list.item_selected.connect(_on_shader_catalog_selected)
	_shader_catalog_list.item_activated.connect(_on_shader_catalog_activated)
	_add_layer_contract_button.pressed.connect(_on_add_layer_contract_pressed)
	_stack_list.item_selected.connect(_on_stack_layer_selected)
	_remove_button.pressed.connect(_on_remove_layer_pressed)
	_up_button.pressed.connect(_on_move_layer_up)
	_down_button.pressed.connect(_on_move_layer_down)
	_copy_stack_button.pressed.connect(_on_copy_stack_pressed)
	_paste_stack_button.pressed.connect(_on_paste_stack_pressed)
	_mark_brushable_button.pressed.connect(_on_mark_brushable_pressed)
	_unmark_brushable_button.pressed.connect(_on_unmark_brushable_pressed)
	_modifier_option.item_selected.connect(_on_modifier_selected)
	_show_ghost_check.toggled.connect(_on_show_ghost_toggled)
	_mode_option.item_selected.connect(_on_mode_selected)
	_size_slider.value_changed.connect(_on_size_slider_changed)
	_size_spin.value_changed.connect(_on_size_spin_changed)
	_opacity_slider.value_changed.connect(_on_opacity_changed)
	_hardness_slider.value_changed.connect(_on_hardness_changed)


func _load_migration_state() -> void:
	var settings := EditorInterface.get_editor_settings()
	if settings.has_setting(GodotASketchConstants.SETTINGS_STACK_MIGRATED):
		return
	if settings.has_setting(GodotASketchConstants.SETTINGS_STACK_LEGACY_NAMES):
		_pending_legacy_names = settings.get_setting(GodotASketchConstants.SETTINGS_STACK_LEGACY_NAMES)


func _finish_migration() -> void:
	var settings := EditorInterface.get_editor_settings()
	settings.set_setting(GodotASketchConstants.SETTINGS_STACK_MIGRATED, true)
	if settings.has_setting(GodotASketchConstants.SETTINGS_STACK_LEGACY_NAMES):
		settings.erase(GodotASketchConstants.SETTINGS_STACK_LEGACY_NAMES)
	_pending_legacy_names = PackedStringArray()


func _load_settings() -> void:
	_loading = true
	var settings := EditorInterface.get_editor_settings()
	_brush_size = float(_read_setting(settings, SETTINGS_PREFIX + "brush/size", DEFAULT_SIZE))
	_brush_opacity = float(_read_setting(settings, SETTINGS_PREFIX + "brush/opacity", DEFAULT_OPACITY))
	_brush_hardness = float(_read_setting(settings, SETTINGS_PREFIX + "brush/hardness", DEFAULT_HARDNESS))
	_size_slider.value = _brush_size
	_size_spin.value = _brush_size
	_opacity_slider.value = _brush_opacity
	_opacity_label.text = "%d%%" % int(_brush_opacity)
	_hardness_slider.value = _brush_hardness
	_hardness_label.text = "%d%%" % int(_brush_hardness)
	_modifier_mask = int(_read_setting(
		settings, GodotASketchConstants.SETTINGS_MODIFIER_KEY, GodotASketchConstants.DEFAULT_MODIFIER_MASK))
	_select_modifier_option(_modifier_mask)
	_show_ghost = bool(_read_setting(
		settings, GodotASketchConstants.SETTINGS_SHOW_GHOST, GodotASketchConstants.DEFAULT_SHOW_GHOST))
	_show_ghost_check.button_pressed = _show_ghost
	_brush_mode = int(_read_setting(
		settings, GodotASketchConstants.SETTINGS_BRUSH_MODE, GodotASketchConstants.BrushMode.PAINT))
	_select_mode_option(_brush_mode)
	_loading = false


func _read_setting(settings: EditorSettings, key: String, default_value: Variant) -> Variant:
	return settings.get_setting(key) if settings.has_setting(key) else default_value


func _save_settings() -> void:
	if _loading:
		return
	var settings := EditorInterface.get_editor_settings()
	settings.set_setting(SETTINGS_PREFIX + "brush/size", _brush_size)
	settings.set_setting(SETTINGS_PREFIX + "brush/opacity", _brush_opacity)
	settings.set_setting(SETTINGS_PREFIX + "brush/hardness", _brush_hardness)
	settings.set_setting(GodotASketchConstants.SETTINGS_MODIFIER_KEY, _modifier_mask)
	settings.set_setting(GodotASketchConstants.SETTINGS_SHOW_GHOST, _show_ghost)
	settings.set_setting(GodotASketchConstants.SETTINGS_BRUSH_MODE, _brush_mode)


func set_context_mesh(mesh: MeshInstance3D) -> void:
	if mesh == _context_mesh:
		return
	_context_mesh = mesh
	if is_node_ready():
		refresh_shader_stack_ui()


func refresh_shader_stack_ui() -> void:
	if not is_node_ready():
		return
	_stack_list.clear()
	var mesh := _resolve_target_mesh()
	var selected := _get_selected_mesh_instance()
	_target_mesh = mesh
	_update_mark_buttons(selected if selected else mesh)
	_set_stack_controls_enabled(mesh != null)
	if mesh == null:
		_stack_hint.text = "Select a MeshInstance3D, or hover one in the 3D view"
		return
	if not GodotASketchBrushable.is_brushable(mesh):
		_stack_hint.text = "%s — click Mark Brushable to paint" % mesh.name
		refresh_splat_preview(null)
		# ponytail: stack layers can be set up before marking brushable
		var stack_early := ShaderStackAssign.load_stack(mesh)
		if stack_early:
			for layer in stack_early.layers:
				_stack_list.add_item(_layer_list_text(layer))
			if _stack_list.item_count > 0 and _stack_list.get_selected_items().is_empty():
				_stack_list.select(0)
		return
	_maybe_apply_legacy_migration(_target_mesh)
	var stack := ShaderStackAssign.load_stack(_target_mesh)
	_copy_stack_button.disabled = stack == null
	_paste_stack_button.disabled = _stack_clipboard == null
	if stack == null:
		_stack_hint.text = (
			"%s — add a stack layer to paint (Add → template layer, or double-click a shader below)"
			% _target_mesh.name
		)
		refresh_splat_preview(_target_mesh)
		return
	_stack_hint.text = "%s  (%s)" % [_target_mesh.name, ShaderStackAssign.stack_path(_target_mesh)]
	for layer in stack.layers:
		_stack_list.add_item(_layer_list_text(layer))
	if _stack_list.item_count > 0 and _stack_list.get_selected_items().is_empty():
		_stack_list.select(0)
	refresh_splat_preview(_target_mesh)
	var active := get_active_stack_layer(_target_mesh)
	if active:
		update_paint_target_label(active)


func _set_stack_controls_enabled(enabled: bool) -> void:
	_add_menu.disabled = not enabled
	_remove_button.disabled = not enabled
	_up_button.disabled = not enabled
	_down_button.disabled = not enabled
	if not enabled:
		_copy_stack_button.disabled = true
		_paste_stack_button.disabled = true


func _maybe_apply_legacy_migration(mesh: MeshInstance3D) -> void:
	if _pending_legacy_names.is_empty():
		return
	if ShaderStackAssign.load_stack(mesh) != null:
		_finish_migration()
		return
	var stack := ShaderStack.new()
	for i in range(mini(_pending_legacy_names.size(), MAX_STACK_LAYERS)):
		var layer_name := _pending_legacy_names[i]
		var layer := ShaderStackLayer.new()
		layer.display_name = "%s (legacy)" % layer_name
		layer.mask_channel = i
		stack.add_layer(layer)
	if _pending_legacy_names.size() > MAX_STACK_LAYERS:
		set_status(
			"Legacy stack had more than %d layers; extra layers were skipped" % MAX_STACK_LAYERS
		)
	var err := ShaderStackAssign.assign_stack(mesh, stack)
	if err != "":
		set_status(err)
		return
	_finish_migration()
	set_status("Migrated legacy layer names — assign shaders to each layer")


func get_active_stack_layer(mesh: MeshInstance3D) -> GodotASketchShaderStackLayer:
	if mesh == null:
		return null
	var stack := ShaderStackAssign.load_stack(mesh)
	if stack == null or stack.layers.is_empty():
		return null
	if mesh == _target_mesh:
		var selected := _stack_list.get_selected_items()
		if not selected.is_empty():
			var idx: int = selected[0]
			if idx >= 0 and idx < stack.layers.size():
				return stack.layers[idx]
	return stack.layers[0]


func refresh_splat_preview(mesh: MeshInstance3D = null) -> void:
	if not is_node_ready():
		return
	if mesh == null:
		mesh = _target_mesh
	if mesh == null:
		_splat_preview.texture = null
		return
	var map: GodotASketchSplatMap = SplatMapAssign.working_map(mesh)
	if map == null:
		map = SplatMapAssign.load_map(mesh)
	if map == null:
		_splat_preview.texture = null
		return
	var layer := get_active_stack_layer(mesh)
	var channel := layer.mask_channel if layer else -1
	_splat_preview.texture = map.to_preview_texture(channel)


func set_splat_preview_texture(tex: Texture2D) -> void:
	if _splat_preview:
		_splat_preview.texture = null
		_splat_preview.texture = tex


func update_paint_target_label(layer: GodotASketchShaderStackLayer) -> void:
	if layer == null:
		return
	var channel: String = _MASK_CHANNELS[clampi(layer.mask_channel, 0, 3)]
	set_status("Paint target: %s (%s)" % [layer.display_name, channel])


func _on_stack_layer_selected(_index: int) -> void:
	if _target_mesh == null:
		return
	var layer := get_active_stack_layer(_target_mesh)
	if layer:
		update_paint_target_label(layer)


func _resolve_target_mesh() -> MeshInstance3D:
	var selected := _get_selected_mesh_instance()
	if selected:
		return selected
	return _context_mesh


func _get_selected_mesh_instance() -> MeshInstance3D:
	var node := _get_selected_node3d()
	if node == null:
		return null
	var mesh := GodotASketchBrushable.resolve_mesh(node)
	if mesh:
		return mesh
	var brushable := GodotASketchBrushable.find_brushable_for_collider(node)
	if brushable:
		return GodotASketchBrushable.resolve_mesh(brushable)
	return null


func _update_mark_buttons(mesh: MeshInstance3D) -> void:
	_mark_brushable_button.disabled = mesh == null
	_unmark_brushable_button.disabled = mesh == null or not GodotASketchBrushable.is_brushable(mesh)


func _current_stack() -> GodotASketchShaderStack:
	return ShaderStackAssign.load_stack(_target_mesh) if _target_mesh else null


func _save_current_stack(stack: GodotASketchShaderStack) -> String:
	if _target_mesh == null or stack == null:
		return "No target mesh"
	return ShaderStackAssign.assign_stack(_target_mesh, stack)


func _layer_list_text(layer: GodotASketchShaderStackLayer) -> String:
	var channel: String = _MASK_CHANNELS[clampi(layer.mask_channel, 0, 3)]
	if layer.shader == null:
		return "%s  (assign shader)" % layer.display_name
	var shader_file := layer.shader.resource_path.get_file() if layer.shader.resource_path else "?"
	return "%s  w=%.2f  %s  %s" % [layer.display_name, layer.weight, channel, shader_file]


func _shader_entry_label(entry: GodotASketchShaderCatalogEntry, with_folder: bool) -> String:
	var tag := ""
	if not entry.probed:
		tag = ""
	elif not entry.loadable:
		tag = " [load error]"
	elif entry.paint_ready:
		tag = " [paint-ready]"
	elif entry.has_contract:
		tag = " [contract, fix compile]"
	else:
		tag = " [generic]"
	if with_folder:
		var folder := entry.path.get_base_dir().trim_prefix("res://")
		if folder.is_empty():
			folder = "res://"
		return "%s  (%s)%s" % [entry.display_name, folder, tag]
	return "%s%s" % [entry.display_name, tag]


func _style_catalog_item(list: ItemList, idx: int, entry: GodotASketchShaderCatalogEntry) -> void:
	if not entry.probed:
		return
	if not entry.loadable:
		list.set_item_custom_fg_color(idx, Color(0.85, 0.35, 0.35))
		list.set_item_disabled(idx, true)
	elif not entry.paint_ready:
		list.set_item_custom_fg_color(idx, Color(0.75, 0.75, 0.45))


func _update_catalog_label() -> void:
	var total := GodotASketchShaderCatalog.total_count()
	var ready := GodotASketchShaderCatalog.paint_ready_count()
	_catalog_count_label.text = "%d shaders · %d paint-ready" % [total, ready] if ready < total else "%d shaders" % total


func _populate_shader_catalog_list() -> void:
	_shader_catalog_list.clear()
	_selected_catalog_entry = null
	_update_layer_contract_button()
	for entry in GodotASketchShaderCatalog.get_entries():
		_shader_catalog_list.add_item(_shader_entry_label(entry, true))
		var idx := _shader_catalog_list.item_count - 1
		_shader_catalog_list.set_item_metadata(idx, entry)
		_style_catalog_item(_shader_catalog_list, idx, entry)


func _on_shader_catalog_selected(index: int) -> void:
	_selected_catalog_entry = _shader_catalog_list.get_item_metadata(index)
	if _selected_catalog_entry:
		GodotASketchShaderCatalog.probe_entry(_selected_catalog_entry)
		_shader_catalog_list.set_item_text(index, _shader_entry_label(_selected_catalog_entry, true))
		_style_catalog_item(_shader_catalog_list, index, _selected_catalog_entry)
		_update_catalog_label()
		set_status(_selected_catalog_entry.path)
	_update_layer_contract_button()


func _needs_layer_contract(entry: GodotASketchShaderCatalogEntry) -> bool:
	return (
		entry != null
		and entry.source == "project"
		and not GodotASketchShaderContract.source_has_contract(entry.path)
	)


func _update_layer_contract_button() -> void:
	var show := _needs_layer_contract(_selected_catalog_entry)
	_add_layer_contract_button.visible = show
	_add_layer_contract_button.disabled = not show


func _on_add_layer_contract_pressed() -> void:
	if _selected_catalog_entry == null:
		set_status("Select a shader in Available shaders first")
		return
	_insert_contract_include(_selected_catalog_entry.path)


func _insert_contract_include(path: String) -> void:
	var before := GodotASketchShaderContract.read_text(path)
	var err := GodotASketchShaderContract.patch_error(before)
	if err != "":
		_notify("Layer contract", err, true)
		set_status(err)
		return
	var after := GodotASketchShaderContract.build_patched_source(before)
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Insert Godot-a-Sketch layer contract")
	undo.add_do_method(GodotASketchShaderContract, "write_text", path, after)
	undo.add_undo_method(GodotASketchShaderContract, "write_text", path, before)
	undo.commit_action()
	GodotASketchShaderContract.after_patch(path)
	refresh_shader_catalog(true)
	var idx := _find_catalog_index(path)
	if idx >= 0:
		_shader_catalog_list.select(idx)
		_on_shader_catalog_selected(idx)
	var msg := "Inserted layer contract in %s" % path.get_file()
	_notify("Layer contract", msg, false)
	set_status(msg)


func _find_catalog_index(path: String) -> int:
	for i in _shader_catalog_list.item_count:
		var entry: GodotASketchShaderCatalogEntry = _shader_catalog_list.get_item_metadata(i)
		if entry and entry.path == path:
			return i
	return -1


func _on_shader_catalog_activated(index: int) -> void:
	var entry: GodotASketchShaderCatalogEntry = _shader_catalog_list.get_item_metadata(index)
	if entry == null:
		return
	if _target_mesh == null:
		set_status("Select or hover a mesh, then double-click a shader to add it to the stack")
		return
	GodotASketchShaderCatalog.probe_entry(entry)
	if not entry.loadable:
		set_status("Shader failed to load — fix compile errors first")
		return
	_add_layer_from_shader(load(entry.path) as Shader, entry.display_name)


func _on_refresh_catalog_pressed() -> void:
	refresh_shader_catalog(true)
	set_status("Shader catalog refreshed")


func _on_add_menu_id_pressed(id: int) -> void:
	match id:
		MENU_TEMPLATE_LAYER:
			_add_bundled_template_layer()
		MENU_FROM_MESH:
			_add_layer_from_selected_mesh()
		MENU_BROWSE:
			_browse_dialog.popup_file_dialog()
		MENU_TEMPLATE:
			_template_dialog.current_file = "layer.gdshader"
			_template_dialog.popup_file_dialog()


func _add_bundled_template_layer() -> void:
	var shader: Shader = load(GodotASketchConstants.LAYER_TEMPLATE_PATH) as Shader
	if shader == null:
		set_status("Bundled template shader not found")
		return
	_add_layer_from_shader(shader, "layer_template")


func _on_browse_shader_selected(path: String) -> void:
	var shader: Shader = load(path) as Shader
	if shader == null:
		set_status("Could not load shader")
		return
	_add_layer_from_shader(shader)


func _on_template_saved(path: String) -> void:
	if not path.ends_with(".gdshader"):
		path += ".gdshader"
	var src := FileAccess.open(GodotASketchConstants.LAYER_TEMPLATE_PATH, FileAccess.READ)
	if src == null:
		set_status("Template not found")
		return
	var dst := FileAccess.open(path, FileAccess.WRITE)
	if dst == null:
		set_status("Could not write %s" % path)
		return
	dst.store_string(src.get_as_text())
	src.close()
	dst.close()
	EditorInterface.get_resource_filesystem().scan()
	var shader: Shader = load(path) as Shader
	if shader == null:
		set_status("Template saved, but the shader could not be loaded")
		return
	EditorInterface.edit_resource(shader)
	_add_layer_from_shader(shader, path.get_file().get_basename())


func _add_layer_from_selected_mesh() -> void:
	if _target_mesh == null:
		set_status("Select or hover a mesh first")
		return
	var shader := GodotASketchShaderCatalog.shader_from_mesh(_target_mesh)
	if shader == null and _selected_catalog_entry != null:
		GodotASketchShaderCatalog.probe_entry(_selected_catalog_entry)
		if _selected_catalog_entry.loadable:
			shader = load(_selected_catalog_entry.path) as Shader
	if shader == null:
		set_status("No shader on mesh — pick one in Available shaders, then Add or double-click")
		return
	_add_layer_from_shader(shader)


func _add_layer_from_shader(shader: Shader, display_name: String = "") -> void:
	if _target_mesh == null:
		set_status("Select or hover a mesh first")
		return
	if shader == null:
		set_status("Could not load shader")
		return
	var stack := ShaderStackAssign.ensure_stack(_target_mesh)
	if stack == null:
		set_status("Could not create stack — check Output panel")
		return
	if stack.layers.size() >= MAX_STACK_LAYERS:
		set_status("Stack supports %d layers (RGBA splat channels)" % MAX_STACK_LAYERS)
		return
	var layer := ShaderStackLayer.new()
	layer.shader = shader
	layer.display_name = display_name if display_name != "" else shader.resource_path.get_file().get_basename()
	layer.mask_channel = stack.layers.size()
	stack.add_layer(layer)
	var had_shader_mat := _target_mesh.material_override is ShaderMaterial
	var err := _save_current_stack(stack)
	if err != "":
		set_status(err)
		return
	GodotASketchBrushable.apply_layer_to_mesh(_target_mesh, layer)
	refresh_shader_stack_ui()
	var paint_ready := GodotASketchShaderValidator.is_layer_shader(shader)
	var mat_note := " — ShaderMaterial created" if not had_shader_mat else ""
	set_status(
		"Layer added: %s%s%s" % [
			layer.display_name,
			mat_note,
			"" if paint_ready else " (generic — splat painting needs paint-ready shader)"
		]
	)


func _on_remove_layer_pressed() -> void:
	var stack := _current_stack()
	if stack == null:
		return
	var selected := _stack_list.get_selected_items()
	if selected.is_empty():
		return
	selected.sort()
	selected.reverse()
	for idx in selected:
		stack.remove_layer(idx)
	var err := _save_current_stack(stack)
	if err != "":
		set_status(err)
		return
	refresh_shader_stack_ui()


func _on_move_layer_up() -> void:
	_move_selected_layer(-1)


func _on_move_layer_down() -> void:
	_move_selected_layer(1)


func _move_selected_layer(delta: int) -> void:
	var stack := _current_stack()
	if stack == null:
		return
	var selected := _stack_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	var to_idx: int = idx + delta
	stack.move_layer(idx, to_idx)
	var err := _save_current_stack(stack)
	if err != "":
		set_status(err)
		return
	refresh_shader_stack_ui()
	if to_idx >= 0 and to_idx < _stack_list.item_count:
		_stack_list.select(to_idx)


func _on_copy_stack_pressed() -> void:
	var stack := _current_stack()
	if stack == null:
		return
	_stack_clipboard = stack.duplicate_stack()
	_paste_stack_button.disabled = _target_mesh == null
	set_status("Stack copied")


func _on_paste_stack_pressed() -> void:
	if _target_mesh == null or _stack_clipboard == null:
		return
	var copy := _stack_clipboard.duplicate_stack()
	var err := ShaderStackAssign.assign_stack_copy(_target_mesh, copy)
	if err != "":
		set_status(err)
		return
	refresh_shader_stack_ui()
	set_status("Stack pasted")


func _on_mark_brushable_pressed() -> void:
	var mesh := _resolve_target_mesh()
	if mesh == null:
		set_status("Select or hover a MeshInstance3D")
		return
	if GodotASketchBrushable.is_brushable(mesh):
		set_status("%s is already brushable" % mesh.name)
		return
	var err := GodotASketchBrushable.mark(mesh)
	set_status(err if err != "" else "Marked brushable: %s" % mesh.name)
	refresh_shader_stack_ui()


func _on_unmark_brushable_pressed() -> void:
	var mesh := _resolve_target_mesh()
	if mesh == null:
		set_status("Select or hover a MeshInstance3D")
		return
	var err := GodotASketchBrushable.unmark(mesh)
	set_status(err if err != "" else "Unmarked brushable")
	refresh_shader_stack_ui()


func _notify(title: String, message: String, is_error: bool) -> void:
	if is_error:
		push_error("Godot-a-Sketch: %s" % message)
	else:
		print("Godot-a-Sketch: %s" % message)
	if _notify_dialog:
		_notify_dialog.queue_free()
	_notify_dialog = AcceptDialog.new()
	_notify_dialog.title = title
	_notify_dialog.dialog_text = message
	EditorInterface.get_base_control().add_child(_notify_dialog)
	_notify_dialog.popup_centered()
	_notify_dialog.confirmed.connect(_notify_dialog.queue_free)


func set_status(message: String) -> void:
	if _status_label:
		_status_label.text = message


func update_raycast_debug(hit: Dictionary) -> void:
	if hit.is_empty():
		_raycast_label.text = "No hit"
		return
	var node: Node = hit.get("brushable_node", hit.get("collider"))
	var pos: Vector3 = hit.get("position", Vector3.ZERO)
	_raycast_label.text = "%s @ %s" % [node.name, _format_vector(pos)]


func _emit_ghost_settings_changed() -> void:
	if not _loading:
		ghost_settings_changed.emit()


func _select_mode_option(mode: int) -> void:
	for i in _mode_option.item_count:
		if int(_mode_option.get_item_metadata(i)) == mode:
			_mode_option.select(i)
			return
	_mode_option.select(0)
	_brush_mode = int(_mode_option.get_item_metadata(0))


func _select_modifier_option(mask: int) -> void:
	for i in _modifier_option.item_count:
		if int(_modifier_option.get_item_metadata(i)) == mask:
			_modifier_option.select(i)
			return
	_modifier_option.select(0)
	_modifier_mask = int(_modifier_option.get_item_metadata(0))


func _on_modifier_selected(index: int) -> void:
	_modifier_mask = int(_modifier_option.get_item_metadata(index))
	_save_settings()


func _on_show_ghost_toggled(enabled: bool) -> void:
	_show_ghost = enabled
	_save_settings()
	_emit_ghost_settings_changed()


func _on_mode_selected(index: int) -> void:
	_brush_mode = int(_mode_option.get_item_metadata(index))
	_save_settings()
	_emit_ghost_settings_changed()


func _get_selected_node3d() -> Node3D:
	var nodes := EditorInterface.get_selection().get_selected_nodes()
	if nodes.is_empty():
		return null
	var node: Node = nodes[0]
	return node if node is Node3D else null


func is_raycast_modifier_active(event: InputEvent) -> bool:
	return event is InputEventMouse and is_modifier_held()


func is_modifier_held() -> bool:
	if _modifier_mask == GodotASketchConstants.MODIFIER_NONE:
		return true
	if _modifier_mask == KEY_MASK_SHIFT:
		return Input.is_key_pressed(KEY_SHIFT)
	if _modifier_mask == KEY_MASK_ALT:
		return Input.is_key_pressed(KEY_ALT)
	if _modifier_mask == KEY_MASK_CTRL:
		return Input.is_key_pressed(KEY_CTRL)
	return false


func get_modifier_mask() -> int:
	return _modifier_mask


func is_ghost_enabled() -> bool:
	return _show_ghost


func get_brush_mode() -> int:
	return _brush_mode


func _format_vector(pos: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [pos.x, pos.y, pos.z]


func _on_size_slider_changed(value: float) -> void:
	_brush_size = value
	if not _loading and _size_spin.value != value:
		_size_spin.value = value
	if not _loading:
		_save_settings()
		_emit_ghost_settings_changed()


func _on_size_spin_changed(value: float) -> void:
	_brush_size = value
	if not _loading and _size_slider.value != value:
		_size_slider.value = value
	if not _loading:
		_save_settings()
		_emit_ghost_settings_changed()


func _on_opacity_changed(value: float) -> void:
	_brush_opacity = value
	_opacity_label.text = "%d%%" % int(value)
	if not _loading:
		_save_settings()
		_emit_ghost_settings_changed()


func _on_hardness_changed(value: float) -> void:
	_brush_hardness = value
	_hardness_label.text = "%d%%" % int(value)
	if not _loading:
		_save_settings()
		_emit_ghost_settings_changed()


func get_brush_size() -> float:
	return float(_size_spin.value) if is_node_ready() else _brush_size


func get_brush_opacity_percent() -> float:
	return float(_opacity_slider.value) if is_node_ready() else _brush_opacity


func get_brush_hardness_percent() -> float:
	return float(_hardness_slider.value) if is_node_ready() else _brush_hardness
