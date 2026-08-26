# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Shaka Player is Google's open-source JavaScript library for adaptive media streaming (DASH and HLS) in
browsers via MediaSource Extensions (MSE) and Encrypted Media Extensions (EME). It has no third-party
runtime dependencies (aside from an EME polyfill); everything needed to build and deploy is in this repo.

## Fork structure

This repo is a fork of the upstream Google Shaka Player project, pinned to the `v3.2.x` release line —
do not upgrade past 3.2.x (e.g. rebasing onto upstream `master` or a later `vX.x` branch) without explicit
instruction.

- `v3.2.x` tracks upstream's 3.2.x release branch.
- `base` merges `v3.2.x` in periodically and carries fixes/tooling meant to be shared across every
  client, e.g. the `build-docker/` toolchain. Prefer landing fixes here when they aren't client-specific.
- Client branches (`scotparl`, `fairplay`, `vualto-clipping-tool`, ...) hold hacks/features specific to a
  single client's deployment and periodically merge `base` in to pick up shared fixes. Don't assume a
  change on one client branch belongs on another or on `base` unless it's genuinely general-purpose.

## Build/test toolchain

The build system is Python-driven (Python 2.7 or 3, per `build/README.md`) and wraps the Google Closure
Compiler (requires JRE 8+) for type checking and compilation. Node/npm is used for the linter, karma test
runner, and other JS-side tooling — `npm install` before doing anything else.

Core scripts, all in `build/`:
- `python build/all.py` — runs gendeps, check, docs, and build. This is the full local CI equivalent; both
  compilation and lint must pass for a patch to be accepted. Pass `--force` to force a rebuild.
- `python build/build.py` — compiles the library only; fails on type or syntax errors from Closure Compiler.
- `python build/check.py` — style/type checks only (ESLint, stylelint, htmlhint, Closure type-checking of
  tests), no compiled output. Pass `--fix` to auto-fix style violations.
- `python build/test.py` — runs unit/integration tests via Karma. Mostly forwards args to Karma; run
  `karma start --help` for the full underlying option set.
- `python build/gendeps.py` — generates `deps.js`, required to run the uncompiled library directly.
- `python build/docs.py` — builds API docs into `docs/api`.

### Useful `build/test.py` flags
- `--filter="SomeSuite .*regex"` — run only matching tests (regex string).
- `--quick` — skip integration tests, unit tests only.
- `--uncompiled` — run tests against uncompiled source for easier debugging (some integration tests
  require the compiled build and won't run without it).
- `--no-drm` — skip tests requiring DRM license servers (avoids needing open internet access).
- `--external` — run tests against external assets (slow, needs a fast internet connection).
- `--browsers Chrome,Firefox` — required if you pass any other test.py args yourself (otherwise it
  auto-selects browsers for your platform).
- `--random` / `--seed=N` — randomize test order to catch cross-test pollution, reproducibly.
- `--enable-logging[=N]` — print library console logs during tests (level per `lib/debug/log.js`).

Building a custom, feature-limited bundle: `build.py` treats extra args as additive (`+path/or/@buildfile`)
or subtractive (`-path/or/@buildfile`) commands, e.g. `build.py +@complete -@offline -@cast`. Build-file
lists live in `build/types/` (e.g. `@complete`, `@networking`, `@offline`, `@ui`, `@cast`, `@manifests`).

Tests are written in Jasmine (see `test/`). For a bug fix, prefer a regression test that fails without the
fix and passes with it (per `CONTRIBUTING.md`).

## Contribution process notes (from CONTRIBUTING.md)

- File/claim a GitHub issue before large patches; a CLA (individual or corporate) is required.
- Each patch must compile and pass lint (`build/all.py`) and tests (`build/test.py`).
- Add yourself/your company to `AUTHORS` and `CONTRIBUTORS` for new contributions.

## Code architecture

### Language and style

Source is Closure-Compiler-annotated ES6+ (`.js`, compiled with `--language_in`/type checking), using
`goog.provide`/`goog.require`/`goog.requireType` module declarations (not ES modules) and full JSDoc type
annotations (`@param`, `@return`, `@extends`, `@implements`, etc.) — the compiler enforces these as real
static types, not just documentation. ESLint (`google` config + a local `eslint-plugin-shaka-rules` +
custom rules in `.eslintrc.js`) enforces additional conventions worth knowing before writing code:
- ES6 classes only — no `.prototype` assignment, no `goog.inherits`.
- Arrow functions only — no `function` expressions (except class methods).
- No `Function.bind`/`.call`; no `Array.forEach` with a callback (use `for...of`); no `.indexOf` for
  membership tests (use `.includes`).

Public API types (interfaces/typedefs consumed by applications embedding the player) live under
`shaka.extern.*`, declared in `externs/` — check there when changing a public-facing interface's shape.
Third-party ambient types (e.g. `cast`, `fetch`, `mux.js`) also live in `externs/`.

### Directory layout

- `lib/` — the library source, organized by subsystem (mirrors the `shaka.*` namespace):
  - `player.js` — `shaka.Player`, the primary API surface and central orchestrator; wires together nearly
    every other subsystem (DRM, streaming, ABR, text, networking, offline, cast).
  - `media/` — core playback engine: `streaming_engine.js` (segment fetch/append scheduling),
    `drm_engine.js` (EME/license handling), `media_source_engine.js` (MSE wrapper), `playhead.js` /
    `gap_jumping_controller.js` (playback position management), `manifest_parser.js` (parser registry),
    `presentation_timeline.js`, `adaptation_set*.js` (track/variant selection sets).
  - `dash/`, `hls/` — format-specific manifest parsers. Each registers itself with
    `shaka.media.ManifestParser.registerParserByMime`/`registerParserByExtension` at load time (see the
    bottom of `dash_parser.js` / `hls_parser.js`) — this is how a manifest URI/MIME type resolves to a
    parser implementation.
  - `net/` — pluggable network scheme handlers (`http_*_plugin.js`, `data_uri_plugin.js`) registered
    against `networking_engine.js`, plus retry/backoff logic (`backoff.js`).
  - `offline/` — storage for offline playback, backed by IndexedDB (`offline/indexeddb/`); manages
    downloading, storing, and converting manifests for offline use.
  - `abr/` — adaptive bitrate/track selection logic, pluggable via `shaka.extern.AbrManager`.
  - `cast/` — Chromecast sender/receiver integration.
  - `cea/` — CEA-608/708 closed caption decoding.
  - `text/` — subtitle/caption parsing (WebVTT, TTML, SRT, SSA, SubViewer) and rendering.
  - `routing/` — `shaka.routing.Walker`, a small state-machine executor that drives the player through
    async load/unload transitions (Player uses it internally to sequence loading states).
  - `polyfill/` — browser compatibility shims, installed at startup.
  - `deprecate/` — enforces deprecation timelines for old APIs.
  - `debug/`, `util/` — logging (`log.js`), error definitions (`util/error.js`, numeric error codes),
    and shared utilities (`EventManager`, `Destroyer`, `PublicPromise`, etc.).
- `ui/` — the optional, separately-buildable UI layer (controls, seek bar, menus, localization) that sits
  on top of `shaka.Player`; not required to use the library.
- `test/` — Jasmine specs mirroring `lib/`'s subsystem layout, plus `test/test/` (test utilities) and
  external/integration test assets.
- `demo/` — the browser-based demo app (served from `index.html` / app-engine deploy configs).
- `externs/` — Closure externs: `shaka.extern.*` public API types plus third-party ambient declarations.
- `docs/tutorials/` — the source of the published tutorials/guides (architecture diagrams, DRM config,
  offline, UI customization, plugin authoring, manifest parser authoring, etc.) — check here for existing
  documented behavior before re-deriving it from source.
- `build/` — the Python build/test/check toolchain described above.
- `app-engine/` — GAE deployment for the demo site and version-index service (separate from library code).

### Extension points (plugin architecture)

Several subsystems are designed for pluggability, each with a registration/factory pattern rather than
inheritance — this is the idiomatic way to add support for a new format/scheme/algorithm:
- Manifest formats: implement `shaka.extern.ManifestParser`, register via
  `shaka.media.ManifestParser.registerParserByMime`/`registerParserByExtension`.
- Network schemes: register a scheme plugin with `shaka.net.NetworkingEngine`.
- ABR strategy: implement `shaka.extern.AbrManager`, set via `player.configure({abrFactory: ...})`.
- Text/caption formats: register with `shaka.text.TextEngine`.
- Text rendering: implement `shaka.extern.TextDisplayer`.

See `docs/tutorials/plugins.md` and `docs/tutorials/manifest-parser.md` for the documented extension APIs.
