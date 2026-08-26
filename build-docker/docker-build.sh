#!/bin/sh
# Build from this script's own directory, regardless of the caller's cwd.
docker build -t shakabuild "$(dirname "$0")"
