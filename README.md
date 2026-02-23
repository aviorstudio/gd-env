# gd-env

Environment and configuration helpers for Godot 4 projects.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-env`

### Manual
Copy this directory into `addons/@aviorstudio_gd-env/` and enable the plugin.

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

## Configuration

No project settings are required.

## Testing

`./run_tests.sh`

## License

MIT
