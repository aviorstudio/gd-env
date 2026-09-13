#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DIST_DIR=${1:-"$ROOT_DIR/dist"}

(cd "$DIST_DIR" && sha256sum --check --strict '@aviorstudio_gd-env.zip.sha256')
