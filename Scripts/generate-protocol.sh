#!/bin/zsh
#
#  generate-protocol.sh
#  SupaLookin
#
#  Created by Weirui Kong on 2026/11/10.
#
# Regenerates Sources/SPLKProtocol/Generated from Sources/SPLKProtocol/Schema.

set -euo pipefail

REQUIRED_PLUGIN_VERSION="1.39.0"
ROOT="${0:A:h:h}"
SCHEMA_DIR="$ROOT/Sources/SPLKProtocol/Schema"
OUT_DIR="$ROOT/Sources/SPLKProtocol/Generated"

# Generated code must match the swift-protobuf runtime that Package.swift pins.
PLUGIN_VERSION=$(protoc-gen-swift --version | awk '{print $2}')
if [[ "$PLUGIN_VERSION" != "$REQUIRED_PLUGIN_VERSION" ]]; then
    echo "protoc-gen-swift $REQUIRED_PLUGIN_VERSION is required, found $PLUGIN_VERSION" >&2
    exit 1
fi

rm -f "$OUT_DIR"/*.pb.swift(N)
protoc \
    --proto_path="$SCHEMA_DIR" \
    --swift_out="$OUT_DIR" \
    --swift_opt=Visibility=Public \
    "$SCHEMA_DIR"/*.proto

# Like every SPLKProtocol source, generated code compiles only where SHOULD_COMPILE_SPLK_SHARED is set.
for file in "$OUT_DIR"/*.pb.swift; do
    { echo "#if SHOULD_COMPILE_SPLK_SHARED"; echo; cat "$file"; echo; echo "#endif"; } > "$file.tmp"
    mv "$file.tmp" "$file"
done
