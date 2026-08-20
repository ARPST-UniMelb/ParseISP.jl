# ParseISP.jl: Julia parser of the Integrated System Plan

[![Build Status](https://github.com/ARPST-UniMelb/ParseISP.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ARPST-UniMelb/ParseISP.jl/actions/workflows/CI.yml?query=branch%3Amain)

**ParseISP** (short for *Julia Parser of the Integrated System Plan*) is an open-source toolkit for parsing and generating structured datasets of the East Coast Australian Power System for power system studies.

The data parsing functionalities are built on publicly available information from the Integrated System Plan (ISP) released by the Australian Energy Market Operator (AEMO) for the Australian National Electricity Market (NEM).

> [!CAUTION]
> The current release is fully functional and has been extensively tested; however, bugs or other issues may still arise. We would greatly appreciate any feedback or bug reports submitted via <https://github.com/ARPST-UniMelb/ParseISP.jl/issues>

> [!CAUTION]
> The data-files of the 2024 ISP that are provided by AEMO have been updated in June 2026. This introduces breaking changes (of the handling of the trace files, including missing and unclear traces of some renewable power plants). As current work is focused on developing a parser for the 2026 ISP files, these changes are not reflected in *ParseISP.jl*. 
> Please contact the research team for the original files (downloaded in May 2026) or download the traces manually via the [Web Archive](https://web.archive.org/web/20251117135835/https://www.aemo.com.au/energy-systems/major-publications/integrated-system-plan-isp/2024-integrated-system-plan-isp) and replace the downloaded traces in the download folder.


## Core function
Dataset construction in ParseISP is performed through a high-level function, `build_ISP24_datasets`. Usage examples are shown below.

**By planning year** (original mode):

```julia
using ParseISP

# Set some of the input parameters (see all parameters below)
reference_trace = 4006         # Reference weather trace. 4006 is the one of the Optimal Development Path (ODP) of the ISP
poe             = 10           # Probability of exceedance (POE) for demand
target_years    = [2030, 2031] # Planning years for which to generate datasets

ParseISP.build_ISP24_datasets(
    downloadpath = joinpath(@__DIR__, "..", "data", "2024", "pisp-downloads"),
    poe          = poe,
    reftrace     = reference_trace,
    years        = target_years,
    output_root  = joinpath(@__DIR__, "..", "data", "2024", "pisp-datasets"),
    write_csv    = true,
    write_arrow  = false,
    scenarios    = [1,2,3]
    )
```

**By arbitrary date range** (new `drange` mode):

```julia
using ParseISP

# Build datasets for specific date windows instead of full calendar years
ParseISP.build_ISP24_datasets(
    downloadpath = joinpath(@__DIR__, "..", "data", "2024", "pisp-downloads"),
    poe          = 10,
    reftrace     = 4006,
    drange       = [("01-01-2030", "31-03-2030"), ("01-07-2031", "30-09-2031")],
    output_root  = joinpath(@__DIR__, "..", "data", "2024", "pisp-datasets"),
    write_csv    = true,
    write_arrow  = false,
    scenarios    = [1,2,3]
    )
```

## Download ISP report PDFs

Download selected ISP report PDFs from AEMO:

```julia
using ParseISP

ParseISP.download_ISP24_reports(
    outdir    = joinpath(@__DIR__, "..", "data", "2024", "pisp-reports"),
    overwrite = false,
    )
```

## Optional parameters for ParseISP.build_ISP24_datasets()

There are multiple parameters that can be adjusted when generating the dataset from the public 2024 Integrated System Plan (ISP) datafiles:

| Parameter            | Default               | Description                                                                                                                                                                                                                                                                                        |
| -------------------- | --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `downloadpath`       | "../../data-download" | Path where all files from AEMO's website will be downloaded and extracted                                                                                                                                                                                                                          |
| `download_from_AEMO` | true                  | Whether to download files from AEMO's website                                                                                                                                                                                                                                                      |
| `poe`                | 10                    | Probability of exceedance (POE) for demand: 10% or 50%                                                                                                                                                                                                                                             |
| `reftrace`           | 4006                  | Reference weather year trace: select among 2011 - 2023 or 4006 (trace for the Optimal Development Path, ODP from the 2024 ISP)                                                                                                                                                                     |
| `years`              | nothing               | Planning years for which to build the time-varying schedules: select among 2025 - 2050. Mutually exclusive with `drange`. Defaults to `[2025]` when neither `years` nor `drange` is provided.                                                                                                      |
| `drange`             | nothing               | Alternative to `years`. An array of 2-tuples `(start, end)` where each element may be a `Date`, `DateTime`, or `AbstractString` in `"DD-MM-YYYY"` format. One dataset is generated per tuple per scenario. Output folders are named `schedule-DDMMYYYY-DDMMYYYY`. Mutually exclusive with `years`. |
| `output_name`        | "out"                 | Output folder name                                                                                                                                                                                                                                                                                 |
| `output_root`        | nothing               | Output folder path                                                                                                                                                                                                                                                                                 |
| `write_csv`          | true                  | Whether to write CSV (.csv) files                                                                                                                                                                                                                                                                  |
| `write_arrow`        | true                  | Whether to write Arrow (.arrow) files                                                                                                                                                                                                                                                              |
| `scenarios`          | [1,2,3]               | Scenarios to include in the output: 1 for `Progressive Change`, 2 for `Step Change`, 3 for `Green Energy Exports`, from the 2024 ISP                                                                                                                                                               |
| `buildout_filepath`  | nothing                | Path to an optional, user-supplied Excel workbook of new-entrant generation and storage assets (see [User-supplied buildout schedules](#user-supplied-buildout-schedules)). When `nothing` (default), no buildouts are applied.                                                                  |
| `sc_buildouts`       | Dict{Int,String}()     | Optional per-scenario worksheet mapping for `buildout_filepath` (see below). When empty (default) and `buildout_filepath` is set, all scenarios share the single worksheet `buildout_1`.                                                                                                          |

### User-supplied buildout schedules

`buildout_filepath` and `sc_buildouts` are unrelated to AEMO's published ISP data: ParseISP does not ship a buildout workbook and does not download one. They exist so you can inject your own planned new-entrant generation and storage assets into a dataset build, on top of the ISP's existing fleet.

To use this feature, provide your own Excel workbook (a common convention is to keep it at `data/ParseISP-buildouts/buildouts.xlsx`, alongside the other `data/` folders, but any path works) with one row per (technology, subregion, year) and these columns:

| Column      | Type    | Description                                                    |
| ----------- | ------- | ---------------------------------------------------------------- |
| `tech`      | String  | Technology label (matched against ParseISP's own technology set)     |
| `subregion` | String  | NEM subregion                                                    |
| `year`      | Integer | Year the entrant becomes available                              |
| `capacity`  | Real    | Capacity, in MW                                                  |
| `n`         | Integer | Number of units                                                  |

By default, ParseISP reads a single worksheet named `buildout_1` for every scenario. To give each scenario its own worksheet instead, pass `sc_buildouts`, mapping each scenario ID (`1`, `2`, `3`) to its worksheet name, e.g. `Dict(1 => "buildout_1", 2 => "buildout_2", 3 => "buildout_3")`.

## Description of dataset formatting

Below, an overview of each of the databases the parser produces is given.

## Files description
>
> [!NOTE]
> **NEM12**: Time-static information
>
> - Bus
> - Demand
> - DER
> - ESS
> - Generator
> - Line

## Time-varying parameters

> [!IMPORTANT]
> **Schedule**: Time-varying parameters
>
> - Demand_load_sched: `value` load (MW) at a given `date`. Match with column `load_` from Demand
> - DER_pred_max_sched: `value` pred (MW) starting at a given `date`. Match with column `pred` from DER
>   - `pred`: Maximum load reduction capacity (MW)
> - ESS_emax_sched: `value` emax (MWh) starting at a given `date`. Match with column `emax` from ESS
>   - `emax`: Maximum storage energy (MWh).
> - ESS_inflow_sched: approximate energy inflow (MWh), for one unit `n` (ESS.n column) of each hydro storage at a given `date`.
> - ESS_lmax_sched: `value` lmax (MW) starting at a given `date`. Match with column `lmax` from ESS
>   - `lmax`: Maximum storage charge input (MW) *[as a load]*.
> - ESS_n_sched: `value` n (p.u.) starting at a given `date`. Match with column `n` from Generator
>   - `n`: Maximum number of online units
> - ESS_pmax_sched: `value` pmax (MW) starting at a given `date`. Match with column `pmax` from ESS
>   - `pmax`: Maximum storage discharge output (MW).
> - Generator_inflow_sched: approximate energy inflow (MWh), for one unit `n` (Generators.n column) of each hydro generator at a given `date`.
> - Generator_pmax_sched: `value` pmax (MW) at a given `date`. Match with column `pmax` from Generator
>   - `pmax`: Maximum generator output (MW).
> - Generator_n_sched: `value` n (p.u.) starting at a given `date`. Match with column `n` from Generator
>   - `n`: Maximum number of online units
> - Line_fwcap_sched: `value` fwcap (MW) starting at a given `date`. Match with column `fwcap` from Line
>   - `fwcap`: Maximum line forward rating (MW)
> - Line_rvcap_sched: `value` rvcap (MW) starting at a given `date`. Match with column `rvcap` from Line
>   - `rvcap`: Maximum line reverse rating (MW)

## Relevant calculations

> [!IMPORTANT]
> *Calculations using parameters from the corresponding tables*
>
> - **Generator**:
>   - Maximum generation output = `pmax` * `n`
>   - Minimum generation output = `pmin` * `n`
> - **ESS**:
>   - Maximum discharging output = `pmax` * `n`
>   - Maximum charging input = `lmax` * `n`
>   - Minimum discharging output = `pmin` * `n`
>   - Minimum charging input = `lmin` * `n`
>   - Minimum state of charge = `emin` (%) * `emax` (MW)
>   - Initial state of charge in $t=1$ = `eini` (%) * `emax` (MW)
> - **Line**:
>   - Maximum forward capacity output = `fwcap` * `n`
>   - Maximum reverse capacity output = `rvcap` * `n`

## Time-static parameters in each database

### Bus

| Parameter | Description                                         |
| --------- | --------------------------------------------------- |
| `id_bus`  | id of the bus                                       |
| `active`  | Active flag (1: active; 0: inactive)                |
| `id_area` | NEM market area (1: QLD; 2:NSW; 3:VIC; 4:TAS; 5:SA) |

### Demand

| Parameter      | Description                                                             |
| -------------- | ----------------------------------------------------------------------- |
| `id_dem`       | id of the bus                                                           |
| `load_`        | Load (MW)                                                               |
| `id_bus`       | Bus the demand is connected to (match with `id_bus` from **Bus** table) |
| `active`       | Active flag (1:active; 0:inactive)                                      |
| `controllable` | Controllable flag (1:controllable; 0:non-controllable)                  |
| `voll`         | Value of Lost Load ($/MWh)                                              |

### DER

| Parameter  | Description                                                               |
| ---------- | ------------------------------------------------------------------------- |
| `id_der`   | id of the DER                                                             |
| `name`     | Name of the DER                                                           |
| `tech`     | Technology (DSP: demand-side participation)                               |
| `id_dem`   | Demand the DER is attached to (match with `id_dem` from **Demand** table) |
| `active`   | Active flag (1:active; 0:inactive)                                        |
| `capacity` | Capacity of the DER service (MW)                                          |
| `reduct`   | Reduction flag (1:yes, 0:no)                                              |
| `pred_max` | Maximum capacity reduction (MW)                                           |
| `cost_red` | Cost associated with the reduction ($/MWh)                                |

### ESS

| Parameter    | Description                                                          |
| ------------ | -------------------------------------------------------------------- |
| `id_ess`     | id of the ESS                                                        |
| `tech`       | Technology (BESS: battery; PS: pumped hydro)                         |
| `type`       | Type of storage (SHALLOW, MEDIUM, DEEP)                              |
| `investment` | Investment flag (1:investment; 0:non-investment)                     |
| `active`     | Active flag (1:active; 0:inactive)                                   |
| `id_bus`     | Bus the ESS is connected to (match with `id_bus` from **Bus** table) |
| `ch_eff`     | Charging efficiency (%)                                              |
| `dch_eff`    | Discharging efficiency (%)                                           |
| `eini`       | Initial energy capacity (% of `emax`)                                |
| `emin`       | Minimum energy capacity (% of `emax`)                                |
| `emax`       | Maximum energy capacity (MWh)                                        |
| `pmin`       | Minimum discharging power (MW)                                       |
| `pmax`       | Maximum discharging power (MW)                                       |
| `lmin`       | Minimum charging power (MW)                                          |
| `lmax`       | Maximum charging power (MW)                                          |
| `fullout`    | Forced outage rate - full outage (% of time in decimal form)         |
| `partialout` | Forced outage rate - partial outage (% of time in decimal form)      |
| `mttrfull`   | Mean time to repair - full outage (hr)                               |
| `mttrpart`   | Mean time to repair - partial outage (hr)                            |
| `n`          | Maximum number of units online (p.u)                                 |

### Generator

| Parameter        | Description                                                                                                                                                |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`             | id of the generator                                                                                                                                        |
| `fuel`           | Fuel type                                                                                                                                                  |
| `tech`           | Generator technology                                                                                                                                       |
| `type`           | Generator type                                                                                                                                             |
| `forate`         | Outage rate (%) `forate =` $\ \  1-(\mathcal{F}+\mathcal{P}(1-\alpha))$ ; $\mathcal{F}$, $\mathcal{P}$ full/partial outage rates, $\alpha$ derating factor |
| `fullout`        | Forced outage rate - full outage (% of time in decimal form)                                                                                               |
| `partialout`     | Forced outage rate - partial outage (% of time in decimal form)                                                                                            |
| `derate`         | Partial outage derating factor (% in decimal form)                                                                                                         |
| `mttrfull`       | Mean time to repair - full outage (hr)                                                                                                                     |
| `mttrpart`       | Mean time to repair - partial outage (hr)                                                                                                                  |
| `bus_id`         | Bus the generator is connected to (match with `id_bus` from **Bus** table)                                                                                 |
| `pmin`           | Minimum power output (MW)                                                                                                                                  |
| `pmax`           | Maximum power output (MW)                                                                                                                                  |
| `rup`            | Ramp-up capacity (MW/min)                                                                                                                                  |
| `rdw`            | Ramp-down capacity (MW/min)                                                                                                                                |
| `investment`     | Investment flag (1:investment; 0:non-investment)                                                                                                           |
| `active`         | Active flag (1:active; 0:inactive)                                                                                                                         |
| `cvar`           | Variable cost ($/MWh)                                                                                                                                      |
| `cfuel`          | Fuel cost ($/GJ)                                                                                                                                           |
| `cvom`           | Variable operation and maintenance cost ($/MWh)                                                                                                            |
| `cfom`           | Fixed operation and maintenance cost ($/MWh/yr)                                                                                                            |
| `co2`            | CO2 emmissions (kgC02/MWh)                                                                                                                                 |
| `hrate`          | Heat rate (MWh/GJ)                                                                                                                                         |
| `pfrmax`         | Maximum headroom (MW)                                                                                                                                      |
| `ffr`            | Fast frequency response provision flag                                                                                                                     |
| `pfr`            | Primary frequency response provision flag                                                                                                                  |
| `res2`           | Secondary reserve provision flag                                                                                                                           |
| `res3`           | Tertiary (Regulation) reserve provision flag                                                                                                               |
| `n`              | Maximum number of units online (p.u.)                                                                                                                      |
| `down_time`      | Minimum down time after being shut-down (h)                                                                                                                |
| `up_time`        | Minimum up time after being started (h)                                                                                                                    |
| `start_up_cost`  | Start-up cost ($)                                                                                                                                          |
| `shut_down_cost` | Shut-down cost ($)                                                                                                                                         |
| `start_up_time`  | Time to start-up units (h)                                                                                                                                 |
| `shut_down_time` | Time to shut-down units (h)                                                                                                                                |

- Forced Outage Rate (%) - The percentage of time per year that a generator is expected to be out of service due to forced outage.
- Mean time to repair (hrs) - The average time take to return a generating unit to service
- Partial Outage Derating Factor - The loss of capacity during a partial outage, relative to generator unit rating. If the outage factor is 20%, the generator will operate at 80% capacity during a partial outage.

### Line

| Parameter     | Description                                                                     |
| ------------- | ------------------------------------------------------------------------------- |
| `id`          | id of the line                                                                  |
| `tech`        | Technology                                                                      |
| `capacity`    | Maximum capacity                                                                |
| `id_bus_from` | Bus the line starts (match with `id_bus` from **Bus** table)                    |
| `id_bus_to`   | Bus the line ends (match with `id_bus` from **Bus** table)                      |
| `investment`  | Investment flag (1:investment; 0:non-investment)                                |
| `active`      | Active flag (1:active; 0:inactive)                                              |
| `rvcap`       | Maximum reverse capacity bus_a $\rightarrow$ bus_b (MW)                         |
| `fwcap`       | Maximum forward capacity bus_b $\rightarrow$ bus_a (MW)                         |
| `fullout`     | Unplanned outage rate - single credible contingency (% of time in decimal form) |
| `mttrfull`    | Mean time to repair - single credible contingency (hr)                          |
| `n`           | Maximum number of units online (p.u.)                                           |

## Data sources of ParseISP
>
> [!IMPORTANT]
> All the datasets that ParseISP generates are based on publicly available data from AEMO.
>
> All files are obtained from: <https://www.aemo.com.au/energy-systems/major-publications/integrated-system-plan-isp/2024-integrated-system-plan-isp>
>
> - 2024 Integrated System Plan **Inputs and Assumptions workbook**
> - 2024 Integrated System Plan **generation and storage outlook**
> - 2024 Integrated System Plan **Model**
> - 2024 Integrated System Plan **Demand & Variable Renewable Energy trace data**

ParseISP combines AEMO source files with package-defined mappings and records derived during dataset construction. The table below summarises how each static output table is created and identifies the additional source data used for its time-varying schedules.

| Table       | Static table construction                                                                                                              | Time-varying schedule sources                                                                                                                                                                      |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Bus`       | Bus names, locations, and NEM area mappings are defined as package constants.                                                          | No time-varying bus schedules are produced.                                                                                                                                                        |
| `Demand`    | ParseISP creates one demand record for each bus.                                                                                           | Hourly demand profiles are obtained from the **Demand & Variable Renewable Energy trace data**.                                                                                                    |
| `Line`      | Network capability, transmission reliability, and augmentation-option data are obtained from the **Inputs and Assumptions workbook**.  | Line schedules use the same source family; no additional AEMO dataset is required.                                                                                                                 |
| `Generator` | Generator characteristics, capacities, mappings, and reliability parameters are obtained from the **Inputs and Assumptions workbook**. | Solar and wind schedules also use the **generation and storage outlook** and the **Demand & Variable Renewable Energy trace data**. Hydro inflow schedules additionally use the **Model** dataset. |
| `ESS`       | Storage characteristics, capacities, mappings, and reliability parameters are obtained from the **Inputs and Assumptions workbook**.   | Behind-the-meter and virtual power plant battery schedules also use the **generation and storage outlook**.                                                                                        |
| `DER`       | DER records are constructed from the `Demand` and `Bus` tables.                                                                        | Demand-response and electric-vehicle charging schedules are obtained from the **Inputs and Assumptions workbook**.                                                                                 |

## Running the tests

The test suite uses Julia's standard `Test` framework. From a Julia session started in the package environment (`julia --project=.`):

```julia
using Pkg
Pkg.test()
```

Equivalently, press `]` to enter the Pkg REPL and run `test`.

### Tests that need local data skip automatically

Some test sets exercise the ISP report and source downloaders against the on-disk data layout. When the matching local data is absent, those tests report as *skipped* instead of failing, so a fresh checkout without the large AEMO assets still runs green. The suite looks for data under `data/2024/pisp-reports` and `data/2024/pisp-downloads`. To point it at data kept elsewhere, set any of these environment variables before running the tests:

| Environment variable         | Selects                            |
| ---------------------------- | ---------------------------------- |
| `ParseISP_ISP2024_REPORT_ROOT`   | ISP 2024 report PDFs               |
| `ParseISP_ISP2024_DOWNLOAD_ROOT` | ISP 2024 model and trace downloads |

A few tests also skip themselves when the `zip` / `unzip` command-line tools are not available.

### Coverage

Continuous integration measures line coverage on every run and uploads it to Codecov (see the build badge at the top of this README). To produce a coverage report locally, run the tests with coverage collection enabled:

```julia
using Pkg
Pkg.test(; coverage=true)
```

This writes `*.cov` files alongside the sources. Process them into a summary or `lcov` report with [Coverage.jl](https://github.com/JuliaCI/Coverage.jl), which you add to your own environment (it is not a dependency of ParseISP).

```sh
./scripts/test_coverage.sh
```

### Doctests

The `jldoctest` examples embedded in the package's docstrings are verified with [Documenter](https://documenter.juliadocs.org/)'s doctesting, independently of the ISP datasets and the full documentation build. Run them with `julia --project=docs docs/doctests.jl`.

## Documentation

- [Documentation home](docs/src/index.md)
- [Quickstart](docs/src/quickstart.md)
- [Contributor setup and tests](docs/src/contributing.md)
- [Documentation maintenance and complete regeneration](docs/README.md)
- [Download ISP source material](docs/src/editions/source-material.md)
- [Supported ISP editions](docs/src/editions/supported-editions.md)
- [ISP 2024 output tables and field dictionary](docs/src/generated/isp2024/reference/output-tables.md)
- [ISP 2024 source data](docs/src/generated/isp2024/reference/source-data.md)
- [Assumptions and scope](docs/src/assumptions.md)
- [API reference](docs/src/api.md)
