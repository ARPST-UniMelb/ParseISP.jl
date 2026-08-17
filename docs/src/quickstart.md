# Quickstart

This walkthrough installs ParseISP.jl, creates a small ISP 2024 dataset for one scenario and one week, and checks representative static and schedule outputs.

## Prerequisites

- Julia `1.11`, as declared by the package's root `Project.toml`.
- Internet access for repository installation and the first AEMO source download.
- A writable working directory with enough storage for the downloaded source archives, extracted inputs, and generated CSV files.

The exact download and output size depends on the selected source material and export settings.
ParseISP prepares data for downstream studies; the resulting tables still require review against the intended model, source vintage, network representation, mappings, and assumptions.

## Install ParseISP.jl

ParseISP.jl is installed directly from its repository URL:

```julia
using Pkg
Pkg.add(url = "https://github.com/ARPST-UniMelb/ParseISP.jl")
```

For a development checkout, contributor tests, and documentation maintenance, see [Contributing](contributing.md).

## Choose a small build

The example below uses:

- Progressive Change (`scenarios = [1]`);
- reference trace `4006`;
- 10% probability-of-exceedance demand;
- 1–7 January 2030;
- CSV output only.

The first build downloads and extracts the required ISP 2024 material.
Retaining the same download directory allows later builds to reuse those inputs.

## Build the dataset

Create a Julia script in a writable working directory:

```julia
using ParseISP

workspace = joinpath(@__DIR__, "pisp-quickstart")
download_root = joinpath(workspace, "downloads")
output_root = joinpath(workspace, "datasets")

ParseISP.build_ISP24_datasets(
    downloadpath = download_root,
    download_from_AEMO = true,
    poe = 10,
    reftrace = 4006,
    drange = [("01-01-2030", "07-01-2030")],
    output_root = output_root,
    write_csv = true,
    write_arrow = false,
    scenarios = [1],
)
```

`drange` is mutually exclusive with `years`.
A range that crosses 1 July is divided into financial-year-aligned problem blocks; this example remains within one block.

## Verify the result

The builder forms the output name from `output_name`, `reftrace`, and `poe`.
With the default `output_name = "out"`, the example writes:

```text
pisp-quickstart/
└── datasets/
    └── out-ref4006-poe10/
        └── csv/
            ├── Bus.csv
            ├── Demand.csv
            ├── DER.csv
            ├── ESS.csv
            ├── Generator.csv
            ├── Line.csv
            └── schedule-01012030-07012030/
                ├── Demand_load_sched.csv
                ├── Generator_pmax_sched.csv
                └── ...
```

Check representative files with:

```julia
build_root = joinpath(output_root, "out-ref4006-poe10", "csv")
schedule_root = joinpath(build_root, "schedule-01012030-07012030")

required_paths = [
    joinpath(build_root, "Bus.csv"),
    joinpath(build_root, "Demand.csv"),
    joinpath(build_root, "Generator.csv"),
    joinpath(schedule_root, "Demand_load_sched.csv"),
    joinpath(schedule_root, "Generator_pmax_sched.csv"),
]

for path in required_paths
    isfile(path) || error("Expected ParseISP output is missing: $(path)")
end
```

When `write_traces = false`, or when `check_exist_trace = true` and the trace outputs already exist, the builder can intentionally skip time-varying trace computation and writing.
CSV and Arrow outputs are independently controlled by `write_csv` and `write_arrow`.

## Understand what was produced

Static tables define assets and comparatively stable attributes.
Schedule tables overlay scenario- and time-dependent values on those assets through the documented identifiers, `scenario`, and `date` fields.

The [ISP 2024 output tables](generated/isp2024/reference/output-tables.md) page defines the complete file, field, unit, and join contract.

## Next steps

- [Working with ParseISP-generated outputs](generated/isp2024/tutorials/working-with-pisp-outputs.md) demonstrates static/schedule joins, aggregation, and plotting.
- [ISP 2024](editions/isp2024.md) provides the release-specific documentation route.
- [Source data](generated/isp2024/reference/source-data.md) identifies the files and selections used by the build.
- [Parameters and mappings](generated/isp2024/reference/parameters-and-mappings.md) records package-defined values and source-label reconciliation.
- [Domain concepts](concepts.md) explains assets, schedules, scenarios, traces, and the aggregated network model.
- [Assumptions and scope](assumptions.md) identifies study-relevant caveats and validation responsibilities.
- [API reference](api.md) documents complete build and acquisition options.
- [Supported ISP edition](editions/supported-editions.md) summarises the documented ISP 2024 capability boundary.
