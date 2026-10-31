# Roblox studio pilot

Foundation for an AI-run Roblox studio: a reproducible Rojo project, headless Luau tests,
CI merge gates and an approval-gated Open Cloud publish workflow. See `CLAUDE.md` for the
operating rules, `docs/architecture/README.md` for the one-page architecture and
`studio/gates.md` for the release gates.

## Layout

```
src/server/        server-only services (authoritative state, remotes)
src/client/        UI and input; never decides outcomes
src/shared/        pure rules and config, unit-tested under Lune
src/kit/           pure reusable building blocks (saves, router, limits, format, stamp)
src/kit-roblox/    thin Roblox adapters for the kit, and the build stamp scripts
src/<game>/        each game's server; src/<game>-client/ its client (see src/<game>/CLAUDE.md)
build-info/        build stamp placeholder; CI writes the commit into it
tests/             test runner and specs
studio/            task schema, task files, gates
docs/              design, architecture, decisions, asset register
release/           release manifests
tools/             validation and release scripts
```

## Quick start

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then `rokit install`.
2. `lune run tests/run`
3. `rojo serve` and connect from the Rojo plugin in Studio, or `rojo build -o build/place.rbxl`.

The sample `RewardRules` module shows the pattern every gameplay system follows: the client
asks, the server validates the payload, applies pure rules, and stores the result.
