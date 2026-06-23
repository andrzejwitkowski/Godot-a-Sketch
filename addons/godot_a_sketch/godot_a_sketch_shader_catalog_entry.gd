extends RefCounted
class_name GodotASketchShaderCatalogEntry

var path: String = ""
var display_name: String = ""
var source: String = ""  # bundled | project
var loadable: bool = false
var has_contract: bool = false  # layer_common include present in source
var paint_ready: bool = false  # loads and passes GodotASketchShaderValidator
var uses_instance_data: bool = false  # INSTANCE_CUSTOM / INSTANCE_ID in source
var probed: bool = false
