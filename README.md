# gd-env

Game-agnostic environment/config helpers for Godot 4.

This package is intended to be linked/installed via `gdpm` and loaded from `res://addons/<addon-dir>/...`.

## Included scripts
- `autoload.gd` — optional singleton exposing the modules as `GdEnv.*` when added as an autoload.
- `src/env_var_module.gd` — typed `OS.get_environment(...)` helpers.
- `src/dotenv_module.gd` — minimal `.env` parser (KEY=VALUE).
- `src/env_json_module.gd` — load JSON config dictionaries from file or HTTP (web relative URLs resolve against `window.location.origin`).

## Usage
Preload the script you need:

```gdscript
const EnvJsonModule = preload("res://addons/@your_addon_dir/src/env_json_module.gd")
```

Or, if you autoload `autoload.gd` as `GdEnv`, use the built-in aliases:

```gdscript
GdEnv.Vars.get_string("PORT")
GdEnv.Json.load_dict_from_file("res://.env.json")
GdEnv.Dot.load_file("res://.env")
```

Note: scripts are intentionally loaded via `preload(...)` (they do not rely on global `class_name` registration).
