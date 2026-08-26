#!/bin/sh
# Resolve docker-run.sh relative to this script's own location, not the caller's cwd.
"$(dirname "$0")/docker-run.sh" python //app/build/build.py --mode debug --name vct +@complete -@ads -@ui -@offline -@cast