<!-- Generated from private documentation source. Do not edit directly. Source SHA256: 5ed8ff5cd988f6e73bfef9587c4ebb5444ce80795820d9aea907948082677b3f -->

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
make setup
make build
make test
```

`make help` lists the available commands. `mise.toml` pins SDK versions; `cookbook.toml` declares package inputs and native tests. Shared automation comes from the exact `nicodes/tools` revision in `Makefile`. Engine and template downloads are checksum verified.

`make build` packages the addon, validates its closed file manifest and checksums, and prepares any declared native export fixtures. `make test` runs all declared source, security and behavioral groups against the current source and prebuilt package. Individual groups are available as `make test:lint`, `make test:unit`, `make test:security`, and the integration or browser groups listed by `make help`. Tests do not prepare dependencies or rebuild the addon. Build and test receipts stay in `.artifacts/verification`.

`make fmt` formats owned GDScript. `make clean` removes declared generated outputs while preserving source and retained data. This package has no application development service.
