# build-docker

A Docker image with the full `build/` toolchain (JDK 11 for Closure Compiler, Node/npm, Python,
git) preinstalled, for building Shaka Player without installing any of that locally. See
`build/README.md` at the repo root for what the underlying build scripts do.

## Scripts

- `docker-build.sh` — builds the `shakabuild` image from the `Dockerfile` in this directory. Run this
  once, and again any time `Dockerfile` changes.
- `docker-run.sh <command...>` — mounts the repo root into a `shakabuild` container at `/app` and runs
  `<command...>` inside it. This is the general-purpose entry point for running any `build/*.py` script.
- `build-vct-debug.sh` — an example built on `docker-run.sh`: produces a debug build named `vct` with
  ads, UI, offline, and cast support stripped out.

All three can be invoked from anywhere (repo root, this directory, elsewhere) — they resolve paths
relative to their own location, not your current directory.

## Usage

```sh
# One-time setup (repeat whenever Dockerfile changes):
./build-docker/docker-build.sh

# Run any build script inside the container, e.g. a full release build:
./build-docker/docker-run.sh python /app/build/build.py --name mybuild

# Or use the canned example build:
./build-docker/build-vct-debug.sh
```

Output lands in `dist/` at the repo root, same as running the build scripts natively.

## Notes

- `docker-run.sh` uses `docker run -it`, so it needs a real terminal (won't work piped into a
  non-interactive script/CI job as-is).
- The container mounts your working tree read-write, so build output and any files the build scripts
  write (e.g. `deps.js`) land directly in your checkout, owned by your host user.
