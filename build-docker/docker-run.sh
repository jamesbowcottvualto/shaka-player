#!/bin/sh
# Always mount the repo root (this script's parent directory) at /app,
# regardless of the directory this script is invoked from.
cd "$(dirname "$0")/.." || exit 1
docker run --rm -it -v "/${PWD}://app" shakabuild "$@"