#!/usr/bin/env bash

set -euo pipefail

echo "path is \`pwd\` and files are \`ls -l\`"

# Prefer extracted artifact if present (as in CI), else fallback to local app file
INDEX_HTML="testing-folder/index.html"
if [ ! -f "$INDEX_HTML" ]; then
  INDEX_HTML="app/index.html"
fi

if [ ! -f "$INDEX_HTML" ]; then
  echo "Error: index.html not found in testing-folder/ or app/" >&2
  exit 2
fi

# What we expect to find in the title or body
EXPECTED_PATTERN="IaC Demo"

echo "Checking that '$EXPECTED_PATTERN' appears in $INDEX_HTML"

numTimesCourse=$(grep -i -o "$EXPECTED_PATTERN" "$INDEX_HTML" | wc -l | tr -d ' ')

if [ "$numTimesCourse" -eq 0 ]; then
  echo "Exit 1: the expected text '$EXPECTED_PATTERN' was not found in $INDEX_HTML" >&2
  exit 1
fi

echo "Exit normally: found $numTimesCourse occurrence(s) of '$EXPECTED_PATTERN' in $INDEX_HTML"


