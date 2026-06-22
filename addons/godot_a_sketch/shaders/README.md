# Godot-a-Sketch layer shaders

Paint stack layers must implement the contract in `layer_common.gdshaderinc`.

## Required uniforms

- `splat_mask` — RGBA splat weights; driven by per-mesh `SplatMap` resource (#6). Wired to materials in #8.
- `mask_channel` — 0–3 (R/G/B/A slot for this layer)
- `layer_weight` — stack blend weight
- `layer_albedo` — layer albedo texture

## Optional uniforms

- `uv_scale`, `uv_offset`

## Authoring

1. Copy `layer_template.gdshader` or `#include` the inc file in your spatial shader.
2. Or select a project shader and click **Insert layer contract include** (adds the `#include` with editor Undo).
3. Drop the file under this folder or anywhere in `res://`.
4. Click **Refresh** in the dock **Shader Stack** section.

Bundled layers live in `layers/` (create the folder as needed).
