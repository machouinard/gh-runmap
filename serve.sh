#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

docker rm -f graphhopper 2>/dev/null || true
docker run -d --name graphhopper \
  --restart unless-stopped \
  -p 8989:8989 \
  -v "$PWD":/work \
  -v "$PWD/data":/data \
  -v "$PWD/graph-cache":/graph-cache \
  -w /work eclipse-temurin:21-jre \
  sh -lc 'exec java -Xms2g -Xmx4g -jar bin/graphhopper-web.jar server config/config.yml'
