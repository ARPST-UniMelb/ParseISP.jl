# ParseISP documentation maintenance

This guide describes the maintained documentation sources, the Literate rendering workflow, and the checks required before publishing the Documenter site.
It is for maintainers; ordinary readers should begin with the rendered site.

## Fresh-clone setup

Clone the repository, then instantiate the package and documentation environments separately:

```sh
git clone https://github.com/ARPST-UniMelb/ParseISP.jl.git
cd ParseISP.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
```

The root environment contains ParseISP and its runtime and test dependencies.
`docs/Project.toml` is a separate environment for Documenter, Literate, plotting, workbook inspection, and documentation tests.

Build the site from the committed generated Markdown with:

```sh
julia --project=docs docs/make.jl
```

This site build does not execute Literate pages and does not require local ISP data.

While iterating on Literate sources, re-render only changed registered pages with:

```sh
julia --project=docs docs/render_changed.jl
```

Run the complete published render before committing regenerated Markdown when the required local ISP 2024 data are available:

```sh
julia --project=docs docs/render_literate.jl
julia --project=docs docs/make.jl
```

The combined entry point is:

```sh
julia --project=docs docs/build_all.jl
```

## Local ISP 2024 data

The public executable documentation is scoped to ISP 2024.
By default it uses:

```text
data/2024/pisp-reports/
data/2024/pisp-downloads/
data/2024/pisp-datasets/
```

These paths are local inputs and generated data and remain ignored by Git.
Use `ParseISP.download_ISP24_reports` and the normal ISP 2024 build workflow to prepare required data.

## Documentation architecture

| Surface | Responsibility |
| --- | --- |
| `docs/src/index.md` | Package entry points and the ISP 2024 guide. |
| `docs/src/quickstart.md` | Installation, first ISP 2024 build, output verification, and next steps. |
| `docs/src/contributing.md` | Contributor setup and documentation-change checks. |
| `docs/src/editions/` | ISP 2024 support, source-material, output-model, trace, and mapping guidance. |
| `docs/src/concepts.md` | ISP 2024 asset, scenario, trace, and static/schedule model. |
| `docs/src/assumptions.md` | ISP 2024 modelling scope, caveats, and validation responsibilities. |
| `docs/src/api.md` | Public ISP 2024 build and source-acquisition API boundary. |
| `docs/literate/isp2024/` | Executable ISP 2024 reference, tutorial, validation, and analysis sources. |
| `docs/config/page-registry.toml` | Authority for registry-managed Literate sources and generated Markdown outputs. |
| `docs/config/source-links.toml` | Local-to-public source-link registry used by Documenter staging. |
| `docs/utils/` | Reusable tutorial support and documentation build helpers. |
| `docs/src/generated/` | Committed Markdown and embedded figures installed from registered Literate pages. |
| `docs/render_literate.jl` | Literate selection, data preflight, execution, and generated-output installation. |
| `docs/make.jl` | Source-link staging and Documenter site build. |

## Page registry

Each `[[page]]` entry in `docs/config/page-registry.toml` describes one executable ISP 2024 Literate page.
The registry validates metadata, source and output paths, navigation positions, related pages, registered sources, and generated Markdown.

| Field | Meaning |
| --- | --- |
| `id` | Stable page identity, independent of filenames. |
| `title` | Reader-facing page title. |
| `kind` | `reference`, `tutorial`, `validation`, or `analysis`. |
| `track` | The public registry uses the `isp2024` track. |
| `editions` | Edition scope; public pages use `["2024"]`. |
| `data_layer` | `package-workflow`, `source-data`, `pisp-dataset`, or `cross-layer`. |
| `source` | Literate source path relative to `docs/`. |
| `output` | Generated Markdown path relative to `docs/src/`. |
| `status` | Publication and render-selection state. |
| `nav_order` | Position within a track and kind. |
| `snapshot` | Whether the page describes a dated source or generated-data state. |
| `data_requirements` | Typed local files or directories required before page execution. |
| `related_reference_pages` | Static or generated pages defining the relevant package contract. |

Render the published ISP 2024 track with:

```sh
ParseISP_DOCS_TRACK=isp2024 julia --project=docs docs/render_literate.jl
```

Render one known page by registry ID with:

```sh
ParseISP_LITERATE_PAGES=isp2024-historical-trace-years julia --project=docs docs/render_literate.jl
```

## Validation before publication

For documentation changes:

1. Render every affected Literate page from its authoritative source.
2. Inspect the generated Markdown, tables, figures, links, and computed values.
3. Run the documentation tests.
4. Build Documenter when navigation, cross-references, source links, styling, or HTML behaviour changed.
5. Confirm generated files contain no local absolute paths or transient validation output.

Keep `docs/render_literate.jl` responsible for executable-page generation and `docs/make.jl` responsible for building the site from existing sources.
