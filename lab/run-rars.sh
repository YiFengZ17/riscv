#!/usr/bin/env bash
set -euo pipefail

# WSLg may be available even when this terminal omits DISPLAY.
if [[ -z "${DISPLAY:-}" && -S /tmp/.X11-unix/X0 ]]; then
    export DISPLAY=:0
fi

exec java -jar /home/yifeng/.local/share/rars/rars1_6.jar "$@"
