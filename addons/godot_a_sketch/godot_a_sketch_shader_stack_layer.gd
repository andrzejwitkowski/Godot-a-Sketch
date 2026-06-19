extends Resource
class_name GodotASketchShaderStackLayer

enum BlendMode { MIX, ADD, MULTIPLY }

@export var display_name: String = "Layer"
@export var shader: Shader
@export_range(0.0, 1.0) var weight: float = 1.0
@export var blend_mode: BlendMode = BlendMode.MIX
@export_range(0, 3) var mask_channel: int = 0
@export var order: int = 0
