#!/usr/bin/env bash
# Zips the transformation modules the Glue job imports and optionally uploads.
# Usage: ./package_glue_lib.sh [s3://bucket/ppr/code/]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(pwd)/ppr_glue_lib.zip"

rm -f "$OUT"
(cd "$HERE" && zip -q "$OUT" ppr_transform.py metrics.py cancellations.py)
echo "wrote $OUT"
unzip -l "$OUT"

if [ "${1:-}" != "" ]; then
  aws s3 cp "$OUT" "${1%/}/ppr_glue_lib.zip"
fi
