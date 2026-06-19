# Godot-a-Sketch

Godot-a-Sketch — brush shader addon for Godot.

## Installation

1. Copy `addons/godot_a_sketch/` into your project's `addons/` folder.
2. Open the project in Godot **4.6.3** (4.6.x compatible).
3. Go to **Project → Project Settings → Plugins** and enable **Godot-a-Sketch**.
4. Confirm **Project → Project Settings → Autoload** shows `GodotASketch` while the plugin is enabled.
5. Disable the plugin — the autoload entry should disappear with no errors in the Output panel.

## Verification

After enabling the plugin:

- **Godot-a-Sketch** appears in the Plugins list.
- Output panel stays clean (no errors).
- `GodotASketch` autoload is registered.

After disabling the plugin:

- Autoload entry is removed.
- Output panel stays clean.

Re-enable and restart the editor with the plugin enabled to confirm it loads without errors.

## Dock

After enabling the plugin, the **Godot-a-Sketch** dock appears on the left side of the editor (default slot).

### Shader Stack

Each brushable `MeshInstance3D` owns a **ShaderStack** resource saved as a `.tres` file. The path is stored in mesh metadata (`godot_a_sketch_shader_stack_path`). Default location: `res://godot_a_sketch_stacks/` (created on first save).

1. Select a brushable mesh (see **Target** below).
2. Use **Add** menu:
   - **From selected mesh** — shader from the mesh `ShaderMaterial`
   - **Browse shader…** — pick any `.gdshader` in the project
   - **New from template…** — copy `layer_template.gdshader` to a new file and open it
   Or double-click a shader in **Available shaders** (max **4 layers** — RGBA splat channels).
3. **Remove**, **Up**, **Down** edit the stack; changes save to the mesh `.tres` immediately. Layer weight is shown read-only; blend/mask editing lands with splat painting (#7).
4. **Copy stack** / **Paste stack** duplicate stack data onto another mesh (new `.tres` file).
5. Click **Refresh** to rescan shaders (validates on refresh; use after adding or editing `.gdshader` files).

The **Available shaders** list shows every `.gdshader` under `res://`. Tags after **Refresh**: `[paint-ready]` = loads and passes splat layer validation; `[contract, fix compile]` = include present but shader does not compile yet; `[generic]` = no contract. Double-click to add to stack. **Insert layer contract include** adds the `#include` (with Undo); it does not wire fragment logic — painting still needs a paint-ready shader (#7/#8).

See `addons/godot_a_sketch/shaders/README.md` for the paint layer contract.

### Brush

- **Size**, **Opacity** (0–100%), and **Hardness** (0–100%) sliders update values in real time.
- Brush settings persist across editor restarts via editor settings.
- Dock position and floating state persist via Godot's built-in editor layout system.

## Raycast

1. Select a `MeshInstance3D` in the scene tree.
2. Click **Mark Brushable** in the dock **Target** section.
   - If the mesh has no `StaticBody3D`, the addon creates one with a trimesh collider on **physics layer 20**.
   - If a `StaticBody3D` already exists, layer 20 is added to its collision layers.
3. Move the mouse in the 3D viewport (raycast is always on when **Modifier** is **None**, the default).
4. The dock shows the hit node and position, or **No hit** when the ray misses brushable geometry.
5. Use **Unmark** to remove brushable metadata, delete the mesh stack `.tres` under `godot_a_sketch_stacks/`, and remove auto-created collision bodies.

Set **Modifier** to **Shift**, **Alt**, or **Ctrl** if you only want raycast while holding that key. The choice persists across editor restarts.

## Ghost Brush

1. Enable **Show Ghost Brush** in the dock **Target** section.
2. Mark a mesh brushable and move the mouse in the 3D viewport (same raycast rules as above).
3. A shader disc preview appears on the surface at the hit point.
4. **Size** sets the disc diameter in world units (slider value ÷ 10).
5. **Opacity** and **Hardness** adjust the preview falloff; **Mode** switches color between **Paint** (blue) and **Sculpt** (orange). Sculpt mode is visual-only until sculpting lands in a later issue.
6. Disable **Show Ghost Brush** to hide the preview.

The ghost node is editor-only and is not intended to be saved with the scene.

## Manual test plan (Shader Stack)

1. Mark mesh brushable → **Add → New from template…** → `.tres` created, meta set.
2. Save scene, reload — stack layers intact.
3. Add layer **From selected mesh** on a mesh with existing `ShaderMaterial`.
4. Add incompatible shader — validator blocks with dock message.
5. Copy stack on mesh A, paste on mesh B — independent `.tres` files.
6. Reorder layers — order persisted in `.tres`.
7. Add new `.gdshader` to project → **Refresh** → shader appears in **Available shaders**.
8. Legacy editor-settings stack names migrate once to the first edited brushable mesh.
