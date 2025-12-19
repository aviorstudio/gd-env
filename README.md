# gd-env

Game-agnostic environment and config helpers for Godot 4.

- Package: `@aviorstudio/gd-env`
- Godot: `4.x` (tested on `4.4`)

## Install

Place this folder under `res://addons/<addon-dir>/` (for example `res://addons/@aviorstudio_gd-env/`).

- With `gdpm`: install/link into your project's `addons/`.
- Manually: copy or symlink this repo folder into `res://addons/<addon-dir>/`.

## Files

- `plugin.cfg` / `plugin.gd`: editor plugin entry (no runtime behavior).
- `autoload.gd`: optional autoload exposing `GdEnv.Vars`, `GdEnv.Json`, and `GdEnv.Dot`.
- `src/env_var_module.gd`: typed `OS.get_environment(...)` helpers.
- `src/dotenv_module.gd`: minimal `.env` parser (`KEY=VALUE`).
- `src/env_json_module.gd`: load JSON dictionaries from file or HTTP.

## Usage

Preload the script you need:

```gdscript
const EnvVar = preload("res://addons/<addon-dir>/src/env_var_module.gd")

var port := EnvVar.get_int("PORT", 8080)
var is_ci := EnvVar.get_bool("CI", false)
```

Or add `autoload.gd` as an autoload named `GdEnv` and use the aliases:

```gdscript
var port := GdEnv.Vars.get_int("PORT", 8080)
var cfg := GdEnv.Json.load_dict_from_file("res://config.json")
var env := GdEnv.Dot.load_file("res://.env")
```

## Configuration

None (all behavior is configured via function parameters).

## Notes

- `autoload.gd` uses `preload(...)` paths; if you rename the addon directory, update the paths in `autoload.gd`.
- Web exports: `EnvJsonModule.load_dict_from_http(...)` resolves relative URLs against `window.location.origin`.
