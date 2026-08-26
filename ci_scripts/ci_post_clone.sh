#!/bin/sh

set -eu

repository_path="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$repository_path"

if ! command -v mint >/dev/null 2>&1; then
    brew install mint
fi

mint bootstrap
mint run xcodegen generate --spec project.yml

test -d DynamicQRCodes.xcodeproj
