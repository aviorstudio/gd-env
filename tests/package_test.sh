#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GODOT=${GODOT_BIN:-godot}
ARCHIVE=${1:-"$ROOT_DIR/dist/@aviorstudio_gd-env.zip"}
EXPECTED="$ROOT_DIR/package/addon_manifest.txt"
WORK=$(mktemp -d)
if [ "${KEEP_TEST_WORK:-0}" = "1" ]; then
    echo "Package test workspace: $WORK"
else
    trap 'rm -rf "$WORK"' EXIT
fi

test -f "$ARCHIVE"
unzip -Z1 "$ARCHIVE" | LC_ALL=C sort >"$WORK/archive-manifest.txt"
LC_ALL=C sort "$EXPECTED" >"$WORK/expected-manifest.txt"
diff -u "$WORK/expected-manifest.txt" "$WORK/archive-manifest.txt"
if zipinfo -l "$ARCHIVE" | grep -Eq '^l'; then
    echo "FAIL: release ZIP contains a symlink" >&2
    exit 1
fi

PROJECT="$WORK/project"
ADDON_DIR="$PROJECT/addons/@aviorstudio_gd-env"
mkdir -p "$ADDON_DIR"
unzip -q "$ARCHIVE" -d "$ADDON_DIR"

cat >"$PROJECT/project.godot" <<'EOF'
[application]
config/name="gd-env packaged lifecycle fixture"

[rendering]
renderer/rendering_method="gl_compatibility"
EOF

cat >"$PROJECT/smoke.gd" <<'EOF'
extends SceneTree

const EnvJsonModule = preload("res://addons/@aviorstudio_gd-env/src/env_json_module.gd")

func _initialize() -> void:
	var parsed = EnvJsonModule.parse_json_dict('{"installed":true}')
	if not parsed.success or parsed.data.get("installed") != true:
		push_error("Packaged autoload smoke failed")
		quit(1)
		return
	print("REACHED gd-env packaged_smoke assertions=2")
	print("PASS gd-env packaged_smoke")
	quit(0)
EOF

cat >"$PROJECT/disable_plugin.gd" <<'EOF'
@tool
extends SceneTree

func _initialize() -> void:
	call_deferred("_disable")

func _disable() -> void:
	var stop := Time.get_ticks_usec() + 20000000
	while (EditorInterface.get_resource_filesystem().is_scanning() \
		or not EditorInterface.is_plugin_enabled("@aviorstudio_gd-env")) \
		and Time.get_ticks_usec() < stop:
		await process_frame
	if not EditorInterface.is_plugin_enabled("@aviorstudio_gd-env"):
		push_error("Packaged plugin did not become enabled")
		quit(1)
		return
	EditorInterface.set_plugin_enabled("@aviorstudio_gd-env", false)
	await process_frame
	if EditorInterface.is_plugin_enabled("@aviorstudio_gd-env"):
		push_error("Packaged plugin did not disable")
		quit(1)
		return
	for frame in range(10):
		await process_frame
	ProjectSettings.save()
	print("REACHED gd-env packaged_disable assertions=2")
	print("PASS gd-env packaged_disable")
	quit(0)
EOF

cat >"$PROJECT/enable_plugin.gd" <<'EOF'
@tool
extends SceneTree

func _initialize() -> void:
	call_deferred("_enable")

func _enable() -> void:
	var stop := Time.get_ticks_usec() + 20000000
	while EditorInterface.get_resource_filesystem().is_scanning() and Time.get_ticks_usec() < stop:
		await process_frame
	EditorInterface.set_plugin_enabled("@aviorstudio_gd-env", true)
	await process_frame
	if not EditorInterface.is_plugin_enabled("@aviorstudio_gd-env"):
		push_error("Packaged plugin did not enable")
		quit(1)
		return
	ProjectSettings.save()
	print("REACHED gd-env packaged_enable assertions=1")
	print("PASS gd-env packaged_enable")
	quit(0)
EOF

cat >"$PROJECT/editor_wait.gd" <<'EOF'
@tool
extends SceneTree

func _initialize() -> void:
	call_deferred("_wait")

func _wait() -> void:
	var stop := Time.get_ticks_usec() + 20000000
	while EditorInterface.get_resource_filesystem().is_scanning() and Time.get_ticks_usec() < stop:
		await process_frame
	if EditorInterface.get_resource_filesystem().is_scanning():
		push_error("Editor filesystem scan timed out")
		quit(1)
		return
	await process_frame
	print("REACHED gd-env packaged_editor assertions=1")
	print("PASS gd-env packaged_editor")
	quit(0)
EOF

export XDG_DATA_HOME="$WORK/data"
export XDG_CONFIG_HOME="$WORK/config"

timeout 30 "$GODOT" --headless --editor --path "$PROJECT" --script "$PROJECT/enable_plugin.gd"
grep -q '^GdEnv="\*' "$PROJECT/project.godot"
timeout 30 "$GODOT" --headless --editor --path "$PROJECT" --script "$PROJECT/editor_wait.gd"
timeout 30 "$GODOT" --headless --path "$PROJECT" --script "$PROJECT/smoke.gd"

timeout 30 "$GODOT" --headless --editor --path "$PROJECT" --script "$PROJECT/disable_plugin.gd"
timeout 30 "$GODOT" --headless --editor --path "$PROJECT" --script "$PROJECT/editor_wait.gd"
if grep -q '^GdEnv=' "$PROJECT/project.godot" || grep -q '^plugin_owns_autoload=' "$PROJECT/project.godot"; then
    echo "FAIL: disabling packaged plugin retained owned project settings" >&2
    exit 1
fi

mkdir -p "$PROJECT/consumer"
printf 'extends Node\nconst MARKER := "consumer-owned"\n' >"$PROJECT/consumer/autoload.gd"
cat >"$PROJECT/consumer_smoke.gd" <<'EOF'
extends SceneTree

func _initialize() -> void:
	var configured_path := str(ProjectSettings.get_setting("autoload/GdEnv", "")).trim_prefix("*")
	if configured_path.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(configured_path)
		if ResourceUID.has_id(uid):
			configured_path = ResourceUID.get_id_path(uid)
	if configured_path != "res://consumer/autoload.gd":
		push_error("Consumer-owned autoload was replaced")
		quit(1)
		return
	print("REACHED gd-env consumer_autoload assertions=1")
	print("PASS gd-env consumer_autoload")
	quit(0)
EOF
perl -0pi -e 's/\[autoload\]\n/\[autoload\]\n\nGdEnv="*res:\/\/consumer\/autoload.gd"\n/' "$PROJECT/project.godot"
timeout 30 "$GODOT" --headless --editor --path "$PROJECT" --script "$PROJECT/enable_plugin.gd"
timeout 30 "$GODOT" --headless --editor --path "$PROJECT" --script "$PROJECT/disable_plugin.gd"
timeout 30 "$GODOT" --headless --editor --path "$PROJECT" --script "$PROJECT/editor_wait.gd"
"$ROOT_DIR/tests/run_godot_case.sh" "$PROJECT/consumer_smoke.gd" consumer_autoload 30 "$WORK/consumer-smoke.log"
if grep -q '^plugin_owns_autoload=' "$PROJECT/project.godot"; then
    echo "FAIL: consumer-owned autoload acquired plugin ownership marker" >&2
    exit 1
fi

(cd "$ADDON_DIR" && find . -type f -printf '%P\0' | LC_ALL=C sort -z | xargs -0 sha256sum) >"$WORK/installed-tree.sha256"
sha256sum "$ARCHIVE"
sha256sum "$WORK/installed-tree.sha256"
echo "FAIL: editor lifecycle CLI emitted unclassified Godot runtime leak errors; gate remains blocked" >&2
exit 1
