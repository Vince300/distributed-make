#!/bin/bash
# Converts the stdin hostfile to a YAML for Grid5000

# Fail if any command fail
set -eo pipefail

FIRST=1
OUTPUT=$1 ; shift

tee "$OUTPUT" <<\HEAD >/dev/null
---
release_path: /home/dismake/distributed-make
user: dismake
hosts:
HEAD

while read -r MACHINE; do
  if [[ $FIRST -gt 0 ]]; then
    echo "  $MACHINE: [a, b, c, d, e, f, g, h]" >>"$OUTPUT"
    FIRST=0
  else
    echo "  $MACHINE: [a, b, c, d, e, f, g, h, i]" >>"$OUTPUT"
  fi
done

echo "" >> "$OUTPUT"
