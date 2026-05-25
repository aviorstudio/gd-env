# gd-env

Environment and configuration helpers for Godot 4 projects.

This addon is intentionally focused on configuration value loading/parsing only.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-env`

### Manual
Copy `addon/` into `addons/@aviorstudio_gd-env/` and enable the plugin.

## Quick Start

```gdscript
const EnvVarModule = preload("res://addons/@aviorstudio_gd-env/src/env_var_module.gd")

var port: int = EnvVarModule.get_int("PORT", 8080)
var use_tls: bool = EnvVarModule.get_bool("USE_TLS", false)
```

## API Reference

- `EnvVarModule`: typed environment variable access (`get_string`, `get_int`, `get_float`, `get_bool`, `has`).
- `DotenvModule`: `.env` file parsing via `load_file` and `parse`.
- `EnvJsonModule`: JSON dictionary loading from files/HTTP with typed result wrappers.

## Scope Boundary

- In scope: env/config value retrieval and parsing.
- Out of scope: app bootstrap policy, secrets rotation flows, and service orchestration.

## Configuration

No project settings are required.

## Testing

`./tests/test.sh`

## License

MIT
