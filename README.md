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
3. **Remove**, **Up**, **Down** edit the stack; changes save to the mesh `.tres` immediately. **Edit layer material** opens the layer’s `ShaderMaterial` for custom uniforms (per mesh).
4. Layer weight is shown read-only in the list; blend mode per layer is used when painting.
5. **Copy stack** / **Paste stack** duplicate stack data onto another mesh (new `.tres` file).
6. Click **Refresh** to rescan shaders (validates on refresh; use after adding or editing `.gdshader` files).

The **Available shaders** list shows every `.gdshader` under `res://`. Tags after **Refresh**: `[paint-ready]` = loads and passes splat layer validation; `[contract, fix compile]` = include present but shader does not compile yet; `[generic]` = no contract. Double-click to add to stack. **Insert layer contract include** adds the `#include` (with Undo); it does not wire fragment logic — painting still needs a paint-ready shader (#7/#8).

See `addons/godot_a_sketch/shaders/README.md` for the paint layer contract.

### Brush

- **Size**, **Opacity** (0–100%), and **Hardness** (0–100%) sliders update values in real time.
- **Mode → Paint** — stamps the active stack layer onto the splat mask (raises channel toward 1).
- **Mode → Erase** — rubber: lowers the active channel toward 0.
- **Splat mask** canvas — click/drag directly on the preview in the dock (no modifier; uses brush + mode below).
- Select a layer in **Stack layers** to choose which RGBA channel (R/G/B/A) receives paint or erase.
- 3D viewport painting: enable **3D tool active**, hold **modifier** (if set), then left-drag on the mesh.
- Brush settings persist across editor restarts via editor settings.
- Dock position and floating state persist via Godot's built-in editor layout system.

### Splat Map

Each brushable mesh owns a **SplatMap** resource (`.tres`) with an RGBA8 mask image. Path metadata: `godot_a_sketch_splat_map_path`. Default location: `res://godot_a_sketch_splats/`. Created when the mesh is marked brushable.

- Default fill is **black** (channel weight 0); painting raises values toward 1.
- Default resolution: **1024×1024** (override via editor setting `godot_a_sketch/splat/default_size`).
- If an old splat `.tres` was created when the default was white, delete it under `godot_a_sketch_splats/` and **Unmark → Mark Brushable** to recreate.
- Painting stamps the mask image directly on mouse drag; saved on mouse release.
- `SplatMap.to_texture()` returns a `Texture2D` for manual wiring; the addon also binds it automatically via **Material stack** (#8).
- UV mapping uses mesh `TEX_UV` / `TEX_UV2` when present; otherwise **planar fallback** from hit position (re-mark brushable after addon update to rebuild cache).

## Raycast

1. Select a `MeshInstance3D` in the scene tree.
2. Click **Mark Brushable** in the dock **Target** section.
   - If the mesh has no `StaticBody3D`, the addon creates one with a trimesh collider on **physics layer 20**.
   - If a `StaticBody3D` already exists, layer 20 is added to its collision layers.
3. Move the mouse in the 3D viewport (raycast is always on when **Modifier** is **None**, the default).
4. The dock shows the hit node and position, or **No hit** when the ray misses brushable geometry.
5. Use **Unmark** to remove brushable metadata, delete stack `.tres` under `godot_a_sketch_stacks/` and splat `.tres` under `godot_a_sketch_splats/`, and remove auto-created collision bodies.

Set **Modifier** to **Shift**, **Alt**, or **Ctrl** if you only want raycast while holding that key. The choice persists across editor restarts.

## Ghost Brush

1. Enable **Show Ghost Brush** in the dock **Target** section.
2. Mark a mesh brushable and move the mouse in the 3D viewport (same raycast rules as above).
3. A shader disc preview appears on the surface at the hit point.
4. **Size** sets the disc diameter in world units (slider value ÷ 10).
5. **Opacity** and **Hardness** adjust the preview falloff; **Mode** switches ghost color between **Paint** (blue) and **Erase** (orange).
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

## Manual test plan (Material stack #8)

1. Mark brushable, add two paint-ready layers with different `layer_albedo` textures via **Edit layer material**.
2. 3D viewport shows both layers blended by splat mask; reorder layers — pass order changes.
3. Paint mask channel — corresponding layer visibility updates in viewport.
4. Mesh A and Mesh B with same shader but different custom uniforms — independent after save/reload.

## Manual test plan (Splat Map)

1. Mark mesh brushable → `godot_a_sketch_splats/{scene}__{node}.tres` created (black 1024²).
2. Add a layer to the stack, select it in **Stack layers**.
3. **Splat mask** canvas — **Mode → Paint**, click/drag on the preview — mask updates.
4. **Mode → Erase**, drag over painted area — channel values drop.
5. Enable **3D tool active**, **Mode → Paint**, left-drag on the mesh — canvas and viewport stay in sync.
6. Fast drag — continuous stroke without gaps.
7. Change opacity/hardness — falloff changes.
8. Select another layer (different channel) — paint accumulates in another RGBA channel.
9. Release mouse — splat `.tres` saved; reload scene — mask persists.
10. Assign `SplatMap.to_texture()` to any `sampler2D` in the inspector to verify export readiness (#8).
