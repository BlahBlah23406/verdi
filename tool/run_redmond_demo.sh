#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

flutter build web --release --no-web-resources-cdn \
  --target lib/main_redmond_demo.dart --output build/redmond-demo

exec python3 backend/platform.py --redmond-demo \
  --port "${VERDI_DEMO_PORT:-8788}" \
  --db "${VERDI_DEMO_DB:-verdi-redmond-demo.sqlite}" \
  --static build/redmond-demo
