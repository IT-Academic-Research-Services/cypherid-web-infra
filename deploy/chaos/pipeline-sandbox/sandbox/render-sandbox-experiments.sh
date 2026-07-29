#!/usr/bin/env bash
# Render the dev-chaos P1-P6 experiments into sandbox-chaos variants (built-not-applied). Rewrites the
# disposable-copy identifiers off the dev-chaos copy (cypherid-workflow-infra, account 491013321714) onto
# the sandbox-chaos copy (seqtoid-ssot-infra workflows stack, account 941377154785). Keeps the two in sync:
# re-run after any change to ../experiments/*.yaml. Output lands in ./rendered/ -- kubectl apply from there.
#
# What it does NOT do: fill the per-experiment REPLACE-* placeholders (the exact chaos queue/SFN suffixes)
# -- those are set once the sandbox-chaos copy is stood up (see SETUP.md) and its resource names are known.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../experiments"
OUT="$HERE/rendered"
mkdir -p "$OUT"

for f in "$SRC"/p[1-6]-*.yaml; do
  base="$(basename "$f")"
  sed \
    -e 's#idseq-dev-chaos-#idseq-swipe-sandbox-chaos-#g' \
    -e 's#pipeline-dev-chaos#pipeline-sandbox-chaos#g' \
    -e 's#scope=dev-chaos#scope=sandbox-chaos#g' \
    -e 's#\bdev-chaos\b#sandbox-chaos#g' \
    -e 's#491013321714#941377154785#g' \
    "$f" > "$OUT/$base"
  echo "  rendered $base"
done
# The guard the rendered experiments reference (chaos-sandbox-guard ConfigMap) is the sandbox one.
cp "$HERE/guard-sandbox.yaml" "$OUT/_sandbox-guard.yaml"
echo "== OK: sandbox-chaos experiments in $OUT/ (apply _sandbox-guard.yaml first, then a single pN). =="
echo "NOTE: set each experiment's REPLACE-* queue/SFN suffix to the actual idseq-swipe-sandbox-chaos-*"
echo "      names AFTER standing up the sandbox-chaos copy (SETUP.md step 1)."
