#!/usr/bin/env bash
set -euo pipefail
./scripts/verify_package_checksum.sh
./tests/package_test.sh
./tests/web_package_test.sh
