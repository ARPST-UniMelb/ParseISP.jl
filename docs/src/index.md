# ParseISP.jl

AEMO publishes the Integrated System Plan as workbooks, model archives, outlook files, and time-series traces.
Using those materials in a power-system study requires scenario reconciliation, common asset identifiers, financial-year handling, and explicit links between static assets and time-varying schedules.

ParseISP.jl implements this data-preparation workflow for the 2024 Integrated System Plan.
It converts supported ISP 2024 material and package-defined mappings into connected power-system tables for downstream optimisation, simulation, reliability, and data-analysis workflows.

## Choose an entry point

- [Quickstart](quickstart.md) installs ParseISP.jl, builds a small ISP 2024 dataset, and checks representative outputs.
- [AEMO ISP source material](editions/source-material.md) explains the source collections used by the ISP 2024 workflow.
- [ISP 2024](editions/isp2024.md) leads to the implemented source, output, tutorial, validation, and analysis documentation.
- [Supported ISP edition](editions/supported-editions.md) summarises the documented public workflow.

## ISP 2024 output model

An ISP 2024 ParseISP build produces three connected forms of information:

| Dataset layer | What it provides | Typical use |
| --- | --- | --- |
| Static asset tables | Buses, demand nodes, generators, storage, transmission corridors, and demand-side resources. | Define the assets and their time-invariant parameters. |
| Schedule tables | Scenario- and time-dependent demand, capacity, unit-count, transfer-limit, inflow, and DER values. | Reconstruct how the static system changes across a study period. |
| Scenario and time metadata | Scenario identifiers, requested planning years or date ranges, trace selection, and financial-year blocks. | Keep schedules comparable and reproducible. |

The static tables and schedules form one dataset model.
A schedule should be joined to its corresponding static table rather than interpreted as an independent asset inventory.
See [Domain concepts](concepts.md) for the relationships and [ISP 2024 output tables](generated/isp2024/reference/output-tables.md) for the exported files.

## Build entry point

The high-level entry point is `ParseISP.build_ISP24_datasets(; kwargs...)`.
It accepts whole planning years through `years` or explicit time windows through `drange`.
Where the underlying ISP inputs use Australian financial years, ParseISP splits the requested period at 1 July so each problem block remains aligned with the source convention.

New users should begin with the [Quickstart](quickstart.md).

## Understand ISP 2024 data before using it

- [Source data](generated/isp2024/reference/source-data.md) identifies the files, selections, keys, fields, and units.
- [Domain concepts](concepts.md) explains the asset relationships, scenario model, trace selection, and static-versus-schedule design.
- [Output tables](generated/isp2024/reference/output-tables.md) documents the exported files, join keys, units, and reconstruction rules.
- [Parameters and mappings](generated/isp2024/reference/parameters-and-mappings.md) records package-defined values that materially affect the dataset.
- [Assumptions and scope](assumptions.md) defines the modelling boundaries and validation responsibilities that remain with the user.

## API reference

See the [API reference](api.md) for the public ISP 2024 build entry point, problem-table helpers, and source-acquisition helpers.
