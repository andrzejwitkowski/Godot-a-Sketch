# Godot-a-Sketch layer shaders

Paint stack layers must implement the contract in `layer_common.gdshaderinc`.

## Required uniforms

- `splat_mask` — RGBA splat weights; driven per mesh by the addon at apply time (#8).
- `mask_channel` — 0–3 (R/G/B/A slot for this layer); set from stack layer, not edited on `layer_material`.
- `layer_weight` — stack blend weight; set from stack layer.
- `layer_albedo` — layer albedo texture; edit on each layer’s `layer_material` in the inspector.

## Layer material

Each `ShaderStackLayer` owns a `layer_material` (`ShaderMaterial`) saved in the mesh stack `.tres`. Custom uniforms live there; use **Edit layer material** in the dock.

**Paint-ready shaders must sample the mask in `fragment()`** — call `godot_a_sketch_mask_weight(UV)` from `layer_common.gdshaderinc` and `discard` or modulate alpha where weight is 0. Declaring the uniforms alone is not enough (see `grass_blade.gdshader`).

`layer_template.gdshader` is for surface mask painting on brushable `MeshInstance3D` meshes.

## Surface vs MultiMesh shaders

The paint stack applies shaders to a **single brushable `MeshInstance3D`** (`material_override`). That only tints or discards fragments on that mesh’s geometry.

**MultiMesh / instance shaders** (e.g. grass that uses `INSTANCE_CUSTOM` and scales blade `VERTEX.y`) belong on the `MultiMeshInstance3D` material, not on the ground surface. Painting a splat mask on the surface does not spawn or hide instances — drive density at scatter/rebuild time by sampling the splat map in your field system (world XZ → UV).

Workflow: paint masks on the **ground surface** with `layer_template` (or a surface preview shader); keep blade shaders on the MultiMesh renderer.

The dock blocks mismatched pairings (instance shader on surface mesh, `layer_template` on MultiMesh). Mark **MultiMeshInstance3D** brushable for instance shader stacks; mark **MeshInstance3D** for splat painting.

## Optional uniforms

- `uv_scale`, `uv_offset`

## Authoring

1. Copy `layer_template.gdshader` or `#include` the inc file in your spatial shader.
2. Or select a project shader and click **Insert layer contract include** (adds the `#include` with editor Undo).
3. Drop the file under this folder or anywhere in `res://`.
4. Click **Refresh** in the dock **Shader Stack** section.

Bundled layers live in `layers/` (create the folder as needed).
