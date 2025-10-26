#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

docker rm -f graphhopper 2>/dev/null || true
rm -rf graph-cache
mkdir -p graph-cache

docker run --rm --name gh-import \
  --user $(id -u):$(id -g) \
  -v "$PWD":/work \
  -v "$PWD/data":/data \
  -v "$PWD/graph-cache":/graph-cache \
  -v "$PWD/custom_models":/custom_models \
  -w /work eclipse-temurin:21-jre \
  sh -lc 'exec java -Xms2g -Xmx4g -jar bin/graphhopper-web.jar import config/config.yml'
