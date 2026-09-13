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
"$ROOT_DIR/scripts/verify_package_checksum.sh" "$(dirname "$ARCHIVE")"

checksum_control="$WORK/checksum-control"
mkdir -p "$checksum_control"
cp "$ARCHIVE" "$checksum_control/@aviorstudio_gd-env.zip"
printf '%064d  @aviorstudio_gd-env.zip\n' 0 >"$checksum_control/@aviorstudio_gd-env.zip.sha256"
if "$ROOT_DIR/scripts/verify_package_checksum.sh" "$checksum_control" >/dev/null 2>&1; then
    echo "FAIL: checksum gate accepted a mutated identity" >&2
    exit 1
fi
echo "CONTROL_REJECTED gd-env package_checksum"
cp "$(dirname "$ARCHIVE")/@aviorstudio_gd-env.zip.sha256" "$checksum_control/"
"$ROOT_DIR/scripts/verify_package_checksum.sh" "$checksum_control"

python3 - "$ARCHIVE" "$WORK/traversal.zip" "$WORK/symlink.zip" <<'PY'
import stat
import sys
import zipfile

source, traversal, symlink = sys.argv[1:]
with zipfile.ZipFile(source) as src:
    entries = [(item, src.read(item.filename)) for item in src.infolist()]
with zipfile.ZipFile(traversal, "w") as out:
    for item, data in entries:
        out.writestr(item, data)
    out.writestr("../escape.gd", b"extends Node\n")
with zipfile.ZipFile(symlink, "w") as out:
    for index, (item, data) in enumerate(entries):
        if index == 0:
            item.create_system = 3
            item.external_attr = (stat.S_IFLNK | 0o777) << 16
            data = b"plugin.gd"
        out.writestr(item, data)
PY
for control in traversal symlink; do
    if "$ROOT_DIR/scripts/verify_package_archive.sh" "$WORK/$control.zip" "$EXPECTED" >/dev/null 2>&1; then
        echo "FAIL: package archive gate accepted $control control" >&2
        exit 1
    fi
    echo "CONTROL_REJECTED gd-env package_$control"
done
"$ROOT_DIR/scripts/verify_package_archive.sh" "$ARCHIVE" "$EXPECTED"

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
		or not EditorInterface.is_plugin_enabled("res://addons/@aviorstudio_gd-env/plugin.cfg")) \
		and Time.get_ticks_usec() < stop:
		await process_frame
	if not EditorInterface.is_plugin_enabled("res://addons/@aviorstudio_gd-env/plugin.cfg"):
		push_error("Packaged plugin did not become enabled")
		quit(1)
		return
	EditorInterface.set_plugin_enabled("res://addons/@aviorstudio_gd-env/plugin.cfg", false)
	await process_frame
	if EditorInterface.is_plugin_enabled("res://addons/@aviorstudio_gd-env/plugin.cfg"):
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
	EditorInterface.set_plugin_enabled("res://addons/@aviorstudio_gd-env/plugin.cfg", true)
	await process_frame
	if not EditorInterface.is_plugin_enabled("res://addons/@aviorstudio_gd-env/plugin.cfg"):
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

run_editor() {
    local log=$1
    shift
    set +e
    timeout --signal=TERM --kill-after=5 30 "$GODOT" --headless --editor --path "$PROJECT" "$@" >"$log" 2>&1
    local status=$?
    set -e
    while IFS= read -r line; do printf '%s\n' "$line"; done <"$log"
    grep -Ev "^ERROR: [0-9]+ RID allocations? of type '.+' were leaked at exit\.$" "$log" >"$log.filtered" || true
    grep -Ev '^ERROR: [0-9]+ resources still in use at exit \(run with --verbose for details\)\.$' "$log.filtered" >"$log.filtered2" || true
    if [ "$status" -ne 0 ] || grep -Eq '(^|[[:space:]])(SCRIPT ERROR:|ERROR:|FAIL:)' "$log.filtered2"; then
        echo "FAIL: packaged editor lifecycle command failed with status $status" >&2
        return 1
    fi
}

# These two exact Godot 4.7.2 headless MainLoop teardown diagnostics are also
# reproduced by the delivered gd-router known-good package lifecycle fixture.
run_editor "$WORK/enable.log" --script res://enable_plugin.gd
grep -q '^GdEnv="\*' "$PROJECT/project.godot"
run_editor "$WORK/restart-enabled.log" --quit-after 2
GODOT_PROJECT_DIR="$PROJECT" "$ROOT_DIR/tests/run_godot_case.sh" "$PROJECT/smoke.gd" packaged_smoke 30 "$WORK/smoke.log"

run_editor "$WORK/disable.log" --script res://disable_plugin.gd
run_editor "$WORK/restart-disabled.log" --quit-after 2
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
		push_error("Consumer-owned autoload was replaced: %s" % configured_path)
		quit(1)
		return
	print("REACHED gd-env consumer_autoload assertions=1")
	print("PASS gd-env consumer_autoload")
	quit(0)
EOF
if grep -Fqx '[autoload]' "$PROJECT/project.godot"; then
    perl -0pi -e 's/\[autoload\]\n/\[autoload\]\n\nGdEnv="*res:\/\/consumer\/autoload.gd"\n/' "$PROJECT/project.godot"
else
    printf '\n[autoload]\n\nGdEnv="*res://consumer/autoload.gd"\n' >>"$PROJECT/project.godot"
fi
run_editor "$WORK/consumer-enable.log" --script res://enable_plugin.gd
run_editor "$WORK/consumer-disable.log" --script res://disable_plugin.gd
run_editor "$WORK/consumer-restart.log" --quit-after 2
GODOT_PROJECT_DIR="$PROJECT" "$ROOT_DIR/tests/run_godot_case.sh" "$PROJECT/consumer_smoke.gd" consumer_autoload 30 "$WORK/consumer-smoke.log"
if grep -q '^plugin_owns_autoload=' "$PROJECT/project.godot"; then
    echo "FAIL: consumer-owned autoload acquired plugin ownership marker" >&2
    exit 1
fi

(cd "$ADDON_DIR" && find . -type f -printf '%P\0' | LC_ALL=C sort -z | xargs -0 sha256sum) >"$WORK/installed-tree.sha256"
sha256sum "$ARCHIVE"
sha256sum "$WORK/installed-tree.sha256"
echo "REACHED gd-env packaged_lifecycle assertions=8"
echo "PASS gd-env packaged_lifecycle"
