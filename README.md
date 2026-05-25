# gd-env

Load environment and configuration values in Godot 4.

Use this addon when you want typed access to OS environment variables, `.env` files, or JSON config without writing parsing code in every project.

## Installation

### Via gdpm

`gdpm install @aviorstudio/gd-env`

### Manual

Copy `addon/` into `res://addons/@aviorstudio_gd-env/` and enable the plugin.

## Quick Start

```gdscript
const EnvVarModule = preload("res://addons/@aviorstudio_gd-env/src/env_var_module.gd")
const DotenvModule = preload("res://addons/@aviorstudio_gd-env/src/dotenv_module.gd")

var port: int = EnvVarModule.get_int("PORT", 8080)
var use_tls: bool = EnvVarModule.get_bool("USE_TLS", false)

var dotenv := DotenvModule.load_file("res://.env")
var api_url: String = str(dotenv.get("API_URL", "http://localhost:3000"))
```

## What You Get

- `EnvVarModule`: typed OS environment lookup with defaults.
- `DotenvModule`: parse `.env` files or raw dotenv strings.
- `EnvJsonModule`: load JSON dictionaries from files or HTTP endpoints.

## Notes

- No project settings are required.
- Treat client-side config as public. Do not ship secrets in exported games.
- Use game code to decide which config source wins when multiple sources are available.

## Testing

`./tests/test.sh`

## License

MIT
