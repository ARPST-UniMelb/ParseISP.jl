# Contributing

This guide is for contributors working from a local checkout of ParseISP.jl.
For package installation and a first dataset build, begin with the [Quickstart](quickstart.md).

## Set up a development workspace

ParseISP.jl requires Julia `1.11`, as declared by the root `Project.toml`.
Clone the canonical repository, then instantiate the package and documentation environments separately:

```sh
git clone https://github.com/ARPST-UniMelb/ParseISP.jl.git
cd ParseISP.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
```

The root environment contains ParseISP and its test dependencies.
The `docs/` environment contains Documenter, Literate, and the packages used by the documentation workflow.
`docs/Project.toml` resolves ParseISP from the same checkout through `ParseISP = {path = ".."}`.

## Run contributor checks

Run these checks from the repository root:

| Check | Command |
| --- | --- |
| Package tests | `julia --project=. -e 'using Pkg; Pkg.test()'` |
| Documentation infrastructure tests | `julia --project=docs docs/test/runtests.jl` |
| Source-link routing | `julia --project=docs docs/test_source_links.jl` |

Package and documentation tests use fixtures or source-code checks unless a test explicitly declares an external-data prerequisite.
Checks for optional local source roots skip when the corresponding material is unavailable.

## Check documentation changes

Use the workflow that matches the documentation source being changed.

### Maintained Markdown

For changes to maintained Markdown under `docs/src/`, build the site directly from the committed generated pages:

```sh
julia --project=docs docs/make.jl
```

### Literate pages

For changes under `docs/literate/`, regenerate the affected pages before building the site:

```sh
julia --project=docs docs/render_changed.jl
julia --project=docs docs/make.jl
```

Inspect the generated Markdown and figures after rendering.
Before committing regenerated published pages, run the complete render and rebuild the site:

```sh
julia --project=docs docs/render_literate.jl
julia --project=docs docs/make.jl
```

Data-dependent Literate pages require the report, download, or generated-output roots declared by their registry entries.
The maintainer guide in `docs/README.md` defines the detailed registry, data-preflight, render-selection, and publication workflow, including the local ISP 2024 data roots required to regenerate published Literate pages.
