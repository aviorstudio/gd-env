# gd-env

Load environment and configuration values in Godot 4.

Use this addon when you want typed access to OS environment variables, `.env` files, or JSON config without writing parsing code in every project.

## Installation

### Via gdam

`gdam install @aviorstudio/gd-env`

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

## HTTP deadlines

`load_dict_from_http` measures `timeout_s` from request start using
[monotonic ticks](https://docs.godotengine.org/en/4.7/classes/class_time.html).
A zero timeout disables the deadline; negative and nonfinite values fail with
`invalid_timeout`. The request belongs to the supplied node and is cancelled
when that owner is freed. Callbacks complete once for success or failure.
`LoadResult.request_result` preserves `HTTPRequest.Result` for transport outcomes
and is `-1` when no HTTP completion occurred. Existing error strings are retained.

Godot 4.7.2's HTTP timeout can consume the frame preceding request start. An
isolated reproduction expires a new one-second request in under one millisecond
after a 1.2-second frame. Owned monotonic deadlines avoid that stale frame delta.
Nonblocking HTTP polling also lets cancellation finish when the peer withholds
its response; native threaded blocking reads can otherwise stall cancellation.
The loopback regression suite exercises those paths, time scale zero, successful
completion, disabled deadlines and owner cleanup.

## Repository Layout

- `addon/`: Godot plugin source packaged for GDAM and manual installation.
- `addon/plugin.cfg`: plugin name, version, description, and entry script.
- `addon/src/`: reusable GDScript modules.
- `tests/`: Godot test project/scripts for addon behavior.
- `.github/workflows/ci.yml`: validates package shape and runs tests.
- `.github/workflows/release.yml`: creates GitHub release ZIPs and publishes to GDAM.

## Versioning And Releases

The version in `addon/plugin.cfg` is the addon package version. Releases are created from `main` with the manual release workflow and plain semver tags like `v0.0.1`; the workflow verifies `plugin.cfg`, builds `@aviorstudio_gd-env.zip`, and publishes `@aviorstudio/gd-env` to GDAM.

## Testing

Run locally with:

```sh
./tests/test.sh
```

CI and releases run the same bounded script with a checksum-verified Godot 4.7.2 binary. Runtime errors and missing PASS markers fail the suite, including when the engine exits zero.

## License

MIT
