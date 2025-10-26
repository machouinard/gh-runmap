#!/usr/bin/env bash
set -euo pipefail
VER="${1:-11.0}"
URL="https://github.com/graphhopper/graphhopper/releases/download/${VER}/graphhopper-web-${VER}.jar"
mkdir -p bin
echo "Downloading GraphHopper ${VER}..."
curl -fL --retry 3 -o "bin/graphhopper-web-${VER}.jar" "$URL"
ln -sfn "graphhopper-web-${VER}.jar" "bin/graphhopper-web.jar"
echo "Done. bin/graphhopper-web.jar -> graphhopper-web-${VER}.jar"
