# openjdk:11 was removed from Docker Hub, so build on top of its maintained
# successor (Eclipse Temurin) and copy in a pinned Node.js build instead of
# relying on whatever nodejs/npm version the base OS's package repos happen
# to carry.
FROM node:20-bookworm AS node
FROM eclipse-temurin:11-jdk-jammy

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# git is required by build/shakaBuildHelpers.py to derive the version from
# tags; python-is-python3 provides the `python` command the build docs and
# scripts expect (build/*.py is python2/3-compatible, python2 is long gone).
RUN apt-get update && \
    apt-get install -y --no-install-recommends git python3 python-is-python3 ca-certificates && \
    rm -rf /var/lib/apt/lists/*
