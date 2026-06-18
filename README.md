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

- **Shader Stack** — use **Add** / **Remove** to manage layer name entries (UI-only until shader resources are wired in a later issue).
- **Brush** — **Size**, **Opacity** (0–100%), and **Hardness** (0–100%) sliders update values in real time.
- Brush settings and stack names persist across editor restarts via editor settings.
- Dock position and floating state persist via Godot's built-in editor layout system.
