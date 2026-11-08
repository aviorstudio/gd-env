<!-- Generated from private documentation source. Do not edit directly. Source SHA256: 0cd5a95ea36007c8cd79227b7deee84bd48ad7bcb9f0cd5bc8c52ce429ac0fdd -->

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

HTTP configuration responses are limited to 1 MiB by default. Pass the optional
final `max_body_bytes` argument to select a positive limit up to 16 MiB. The
limit is assigned to Godot's `HTTPRequest.body_size_limit` before starting the
request, so declared, chunked, and decompressed bodies are bounded during
transfer rather than checked only after accumulation. `LoadResult.error_code`
provides typed timeout, body-size, transport, HTTP-status, and JSON parse
outcomes; `body_too_large` results retain no bytes beyond the selected cap.
The default body limit is 1 MiB, the ceiling is 16 MiB, and the default deadline is 10 seconds.


## License

See `LICENSE`.

## Contributor checks

Install [mise](https://mise.jdx.dev/), then prepare the pinned cookbook and SDKs:

```sh
mise run setup
mise run build
mise run test
```

`mise run help` lists the available commands. `mise.toml` pins SDK versions; `cookbook.toml` declares package inputs and native tests. Shared recipes come from the exact `nicodes/cookbook` revision in the generated `mise.toml` task block. Engine and template downloads are checksum verified.

`mise run build` packages the addon, validates its closed file manifest and checksums, and prepares any declared native export fixtures. `mise run test` runs all declared source, security and behavioral groups against the current source and prebuilt package. Individual groups are available as `mise run test:lint`, `mise run test:unit`, `mise run test:security`, and the integration or browser groups listed by `mise run help`. Tests do not prepare dependencies or rebuild the addon. Build and test receipts stay in `.artifacts/verification`.

`mise run fmt` formats owned GDScript. `mise run clean` removes declared generated outputs while preserving source and retained data. This package has no application development service.
