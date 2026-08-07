```@meta
EditURL = "../../../../literate/isp2024/reference/output_tables.jl"
```

# ISP 2024: Output tables

A ParseISP build writes static asset tables once per build and time-varying schedule tables under one or more schedule directories. The tables below list the current output names, identifiers, relationships, and columns.

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
using ParseISP
using DataFrames

const REPO_ROOT = normpath(get(ENV, "ParseISP_DOCS_REPO_ROOT", joinpath(@__DIR__, "..", "..", "..", "..")))

include(joinpath(REPO_ROOT, "docs", "utils", "ParseISPDocUtils.jl"))
import .ParseISPDocUtils

const ISP2024_PROFILE = ParseISPDocUtils.edition_profile(REPO_ROOT, "2024")


function container_inventory(container)
    rows = NamedTuple[]
    for field in fieldnames(typeof(container))
        table = getfield(container, field)
        table isa DataFrame || continue
        output_name = get(ParseISP.alt_names, field, string(field))
        columns = string.(names(table))
        id_columns = filter(name -> startswith(name, "id"), columns)
        relationship_ids = length(id_columns) > 1 ? id_columns[2:end] : String[]
        push!(
            rows,
            (
                output_table = output_name,
                container_field = string(field),
                primary_id = isempty(id_columns) ? "" : first(id_columns),
                relationship_ids = join(relationship_ids, ", "),
                columns = join(columns, ", "),
            ),
        )
    end
    return DataFrame(rows)
end

_tc, static_container, schedule_container = ParseISP.initialise_time_structures();
````

```@raw html
</details>
```

## Static asset tables

Static tables define asset identity and time-invariant attributes. Schedule rows should be joined back to these tables through the relationship identifier shown above.

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
static_tables = container_inventory(static_container)
ParseISPDocUtils.markdown_table(static_tables)
````

```@raw html
</details>
```

| **output\_table** | **container\_field** | **primary\_id** | **relationship\_ids** | **columns** |
|:--|:--|:--|:--|:--|
| Bus | bus | id\_bus | id\_area | id\_bus, name, alias, active, latitude, longitude, id\_area |
| Demand | dem | id\_dem | id\_bus | id\_dem, name, load\_, id\_bus, active, controllable, voll, contingency |
| ESS | ess | id\_ess | id\_bus | id\_ess, name, alias, tech, type, capacity, investment, active, id\_bus, ch\_eff, dch\_eff, eini, emin, emax, pmin, pmax, lmin, lmax, fullout, partialout, mttrfull, mttrpart, inertia, powerfactor, ffr, pfr, res2, res3, fr\_db, fr\_ad, fr\_dt, fr\_frt, fr\_fr, longitude, latitude, n, contingency |
| Generator | gen | id\_gen | id\_bus | id\_gen, name, alias, fuel, tech, type, capacity, forate, fullout, partialout, derate, mttrfull, mttrpart, id\_bus, pmin, pmax, rup, rdw, investment, active, cvar, cfuel, cvom, cfom, co2, slope, hrate, pfrmax, g, inertia, ffr, pfr, res2, res3, powerfactor, latitude, longitude, n, contingency, down\_time, up\_time, last\_state, last\_state\_period, last\_state\_output, start\_up\_cost, shut\_down\_cost, start\_up\_time, shut\_down\_time |
| Line | line | id\_lin | id\_bus\_from, id\_bus\_to | id\_lin, name, alias, tech, capacity, id\_bus\_from, id\_bus\_to, investment, active, r, x, rvcap, fwcap, fullout, mttrfull, voltage, segments, latitude, longitude, length, n, contingency |
| DER | der | id\_der | id\_dem | id\_der, name, tech, id\_dem, active, investment, capacity, reduct, pred\_max, cost\_red, n |


The `Bus` table fixes the spatial resolution of the dataset.

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
ParseISPDocUtils.RawMarkdown(
    "The static tables represent the NEM as $(length(ParseISP.NEMBUSES)) sub-regional network " *
    "nodes spanning the $(length(unique(values(ParseISP.BUS2AREA)))) NEM regions - Queensland, " *
    "New South Wales, Victoria, Tasmania, and South Australia - interconnected by the `Line` records.",
)
````

```@raw html
</details>
```

The static tables represent the NEM as 12 sub-regional network nodes spanning the 5 NEM regions - Queensland, New South Wales, Victoria, Tasmania, and South Australia - interconnected by the `Line` records.

## Schedule tables

Schedule tables carry scenario- and time-dependent values. The output filename is taken from the same `alt_names` mapping used by the CSV and Arrow writers.

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
schedule_tables = container_inventory(schedule_container)
ParseISPDocUtils.markdown_table(schedule_tables)
````

```@raw html
</details>
```

| **output\_table** | **container\_field** | **primary\_id** | **relationship\_ids** | **columns** |
|:--|:--|:--|:--|:--|
| Demand\_load\_sched | dem\_load | id | id\_dem | id, id\_dem, scenario, date, value |
| ESS\_emax\_sched | ess\_emax | id | id\_ess | id, id\_ess, scenario, date, value |
| ESS\_lmax\_sched | ess\_lmax | id | id\_ess | id, id\_ess, scenario, date, value |
| ESS\_n\_sched | ess\_n | id | id\_ess | id, id\_ess, scenario, date, value |
| ESS\_pmax\_sched | ess\_pmax | id | id\_ess | id, id\_ess, scenario, date, value |
| ESS\_inflow\_sched | ess\_inflow | id | id\_ess | id, id\_ess, scenario, date, value |
| Generator\_n\_sched | gen\_n | id | id\_gen | id, id\_gen, scenario, date, value |
| Generator\_pmax\_sched | gen\_pmax | id | id\_gen | id, id\_gen, scenario, date, value |
| Generator\_inflow\_sched | gen\_inflow | id | id\_gen | id, id\_gen, scenario, date, value |
| Line\_fwcap\_sched | line\_fwcap | id | id\_lin | id, id\_lin, scenario, date, value |
| Line\_rvcap\_sched | line\_rvcap | id | id\_lin | id, id\_lin, scenario, date, value |
| DER\_pred\_sched | der\_pred | id | id\_der | id, id\_der, scenario, date, value |


## Schedule value semantics

Each schedule row applies to one asset, scenario, and timestamp. The `value` column overlays the corresponding static quantity when reconstructing the system state for that scenario and time.

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
# Value meaning, unit, and overlay relationship for each current schedule.
const SCHEDULE_SEMANTICS = Dict(
    "Demand_load_sched" => ("Demand load at the timestamp.", "MW", "Overlays `Demand.load_` through `id_dem`."),
    "ESS_emax_sched" => ("Maximum stored-energy capacity at the timestamp.", "MWh", "Overlays `ESS.emax` through `id_ess`."),
    "ESS_lmax_sched" => ("Maximum charging input at the timestamp.", "MW", "Overlays `ESS.lmax` through `id_ess`."),
    "ESS_n_sched" => ("Available or online storage-unit count at the timestamp.", "unit count", "Overlays `ESS.n` through `id_ess`."),
    "ESS_pmax_sched" => ("Maximum discharging output at the timestamp.", "MW", "Overlays `ESS.pmax` through `id_ess`."),
    "ESS_inflow_sched" => ("Approximate energy inflow assigned to one unit of the storage asset.", "MWh per unit", "Relates to `ESS.n` through `id_ess`."),
    "Generator_n_sched" => ("Available or online generator-unit count at the timestamp.", "unit count", "Overlays `Generator.n` through `id_gen`."),
    "Generator_pmax_sched" => ("Maximum generator output at the timestamp.", "MW", "Overlays `Generator.pmax` through `id_gen`."),
    "Generator_inflow_sched" => ("Approximate energy inflow assigned to one hydro-generator unit.", "MWh per unit", "Relates to `Generator.n` through `id_gen`."),
    "Line_fwcap_sched" => ("Maximum forward transfer capacity at the timestamp.", "MW", "Overlays `Line.fwcap` through `id_lin`."),
    "Line_rvcap_sched" => ("Maximum reverse transfer capacity at the timestamp.", "MW", "Overlays `Line.rvcap` through `id_lin`."),
    "DER_pred_sched" => ("Available demand-reduction quantity at the timestamp.", "MW", "Overlays `DER.pred_max` through `id_der`."),
)

let live = schedule_tables.output_table
    stale = setdiff(Set(keys(SCHEDULE_SEMANTICS)), Set(live))
    isempty(stale) ||
        error("SCHEDULE_SEMANTICS documents schedules no longer produced: $(join(sort(collect(stale)), ", "))")
    rows = ["| Schedule | Meaning of `value` | Unit | Static relationship |", "|---|---|---|---|"]
    for name in live
        haskey(SCHEDULE_SEMANTICS, name) ||
            error("schedule `$name` is produced by the build but has no documented value semantics")
        meaning, unit, relationship = SCHEDULE_SEMANTICS[name]
        push!(rows, "| `$name` | $meaning | $unit | $relationship |")
    end
    ParseISPDocUtils.RawMarkdown(join(rows, "\n"))
end
````

```@raw html
</details>
```

| Schedule | Meaning of `value` | Unit | Static relationship |
|---|---|---|---|
| `Demand_load_sched` | Demand load at the timestamp. | MW | Overlays `Demand.load_` through `id_dem`. |
| `ESS_emax_sched` | Maximum stored-energy capacity at the timestamp. | MWh | Overlays `ESS.emax` through `id_ess`. |
| `ESS_lmax_sched` | Maximum charging input at the timestamp. | MW | Overlays `ESS.lmax` through `id_ess`. |
| `ESS_n_sched` | Available or online storage-unit count at the timestamp. | unit count | Overlays `ESS.n` through `id_ess`. |
| `ESS_pmax_sched` | Maximum discharging output at the timestamp. | MW | Overlays `ESS.pmax` through `id_ess`. |
| `ESS_inflow_sched` | Approximate energy inflow assigned to one unit of the storage asset. | MWh per unit | Relates to `ESS.n` through `id_ess`. |
| `Generator_n_sched` | Available or online generator-unit count at the timestamp. | unit count | Overlays `Generator.n` through `id_gen`. |
| `Generator_pmax_sched` | Maximum generator output at the timestamp. | MW | Overlays `Generator.pmax` through `id_gen`. |
| `Generator_inflow_sched` | Approximate energy inflow assigned to one hydro-generator unit. | MWh per unit | Relates to `Generator.n` through `id_gen`. |
| `Line_fwcap_sched` | Maximum forward transfer capacity at the timestamp. | MW | Overlays `Line.fwcap` through `id_lin`. |
| `Line_rvcap_sched` | Maximum reverse transfer capacity at the timestamp. | MW | Overlays `Line.rvcap` through `id_lin`. |
| `DER_pred_sched` | Available demand-reduction quantity at the timestamp. | MW | Overlays `DER.pred_max` through `id_der`. |

Inflow schedules are approximate energy allocations for one unit of the relevant asset. The applicable unit-count field or schedule determines the aggregate quantity represented by multiple units.

## Derived quantities

These quantities are not written as separate columns; they are reconstructed from the static columns when building a system state. Each uses the applicable static or scheduled value for the selected scenario and timestamp: when a corresponding schedule exists, its `value` replaces the static field before the quantity is derived.

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
# Per-unit static fields used to reconstruct derived capacities.
const DERIVED_QUANTITIES = [
    ("Generator", "Maximum generation output", ["pmax", "n"], "MW"),
    ("Generator", "Minimum generation output", ["pmin", "n"], "MW"),
    ("ESS", "Maximum discharging output", ["pmax", "n"], "MW"),
    ("ESS", "Maximum charging input", ["lmax", "n"], "MW"),
    ("ESS", "Minimum discharging output", ["pmin", "n"], "MW"),
    ("ESS", "Minimum charging input", ["lmin", "n"], "MW"),
    ("ESS", "Minimum stored energy", ["emin", "emax"], "MWh"),
    ("ESS", "Initial stored energy at the first time step", ["eini", "emax"], "MWh"),
    ("Line", "Maximum forward transfer capacity", ["fwcap", "n"], "MW"),
    ("Line", "Maximum reverse transfer capacity", ["rvcap", "n"], "MW"),
]

let asset_columns = Dict(row.output_table => Set(split(row.columns, ", ")) for row in eachrow(static_tables))
    rows = ["| Asset | Quantity | Expression | Unit |", "|---|---|---|---|"]
    for (asset, quantity, factors, unit) in DERIVED_QUANTITIES
        haskey(asset_columns, asset) ||
            error("derived quantity references unknown static table `$asset`")
        for factor in factors
            factor in asset_columns[asset] ||
                error("derived quantity `$quantity` references `$asset.$factor`, which is not a current column")
        end
        expression = "`" * join(factors, " × ") * "`"
        push!(rows, "| $asset | $quantity | $expression | $unit |")
    end
    ParseISPDocUtils.RawMarkdown(join(rows, "\n"))
end
````

```@raw html
</details>
```

| Asset | Quantity | Expression | Unit |
|---|---|---|---|
| Generator | Maximum generation output | `pmax × n` | MW |
| Generator | Minimum generation output | `pmin × n` | MW |
| ESS | Maximum discharging output | `pmax × n` | MW |
| ESS | Maximum charging input | `lmax × n` | MW |
| ESS | Minimum discharging output | `pmin × n` | MW |
| ESS | Minimum charging input | `lmin × n` | MW |
| ESS | Minimum stored energy | `emin × emax` | MWh |
| ESS | Initial stored energy at the first time step | `eini × emax` | MWh |
| Line | Maximum forward transfer capacity | `fwcap × n` | MW |
| Line | Maximum reverse transfer capacity | `rvcap × n` | MW |

`emin` and `eini` are interpreted as fractions of `emax` under the package's stored-value convention.

## Core static field meanings

The table above lists every column of the six static asset tables. The tables below define the core fields used to interpret them.

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
# Core field meanings for each current static table.
static_columns = Dict(row.output_table => split(row.columns, ", ") for row in eachrow(static_tables))

const FIELD_MEANINGS = Dict(
    "Bus" => [
        "id_bus" => "Unique bus identifier.",
        "active" => "Inclusion flag: `1` for active and `0` for inactive.",
        "id_area" => "NEM market-area identifier: `1` QLD, `2` NSW, `3` VIC, `4` TAS, and `5` SA.",
    ],
    "Demand" => [
        "id_dem" => "Unique demand identifier.",
        "load_" => "Static load value in MW; `Demand_load_sched` supplies the time-varying load.",
        "id_bus" => "Bus to which the demand is connected.",
        "active" => "Inclusion flag: `1` for active and `0` for inactive.",
        "controllable" => "Controllability flag: `1` for controllable and `0` for non-controllable demand.",
        "voll" => "Value of lost load in `\$/MWh`.",
    ],
    "DER" => [
        "id_der" => "Unique DER identifier.",
        "name" => "DER name.",
        "tech" => "DER technology or service category, including `DSP` for demand-side participation.",
        "id_dem" => "Demand record to which the DER is attached.",
        "active" => "Inclusion flag: `1` for active and `0` for inactive.",
        "capacity" => "DER service capacity in MW.",
        "reduct" => "Reduction flag: `1` when the service represents load reduction and `0` otherwise.",
        "pred_max" => "Maximum predicted load-reduction capacity in MW.",
        "cost_red" => "Cost associated with load reduction in `\$/MWh`.",
    ],
    "ESS" => [
        "id_ess" => "Unique energy-storage identifier.",
        "tech" => "Storage technology, including `BESS` for battery energy storage and `PS` for pumped storage.",
        "type" => "Storage-duration category, such as shallow, medium, or deep.",
        "investment" => "Investment flag: `1` for an investment record and `0` for a non-investment record.",
        "active" => "Inclusion flag: `1` for active and `0` for inactive.",
        "id_bus" => "Bus to which the storage asset is connected.",
        "ch_eff" => "Charging efficiency under the package's stored fraction convention.",
        "dch_eff" => "Discharging efficiency under the package's stored fraction convention.",
        "eini" => "Initial stored-energy fraction relative to `emax`.",
        "emin" => "Minimum stored-energy fraction relative to `emax`.",
        "emax" => "Maximum stored-energy capacity in MWh.",
        "pmin" => "Minimum discharging power per unit in MW.",
        "pmax" => "Maximum discharging power per unit in MW.",
        "lmin" => "Minimum charging input per unit in MW.",
        "lmax" => "Maximum charging input per unit in MW.",
        "fullout" => "Full forced-outage rate, represented as a fraction of time.",
        "partialout" => "Partial forced-outage rate, represented as a fraction of time.",
        "mttrfull" => "Mean time to repair after a full outage, in hours.",
        "mttrpart" => "Mean time to repair after a partial outage, in hours.",
        "n" => "Maximum number of storage units available or online.",
        "ffr" => "Fast-frequency-response provision flag.",
        "pfr" => "Primary-frequency-response provision flag.",
        "res2" => "Secondary-reserve provision flag.",
        "res3" => "Tertiary or regulation-reserve provision flag.",
        "powerfactor" => "Power factor.",
        "contingency" => "Contingency.",
    ],
    "Generator" => [
        "id_gen" => "Unique generator identifier.",
        "fuel" => "Generator fuel category.",
        "tech" => "Generator technology.",
        "type" => "Generator type or planning classification.",
        "forate" => "Aggregate forced-outage parameter supplied by the package.",
        "fullout" => "Full forced-outage rate, represented as a fraction of time.",
        "partialout" => "Partial forced-outage rate, represented as a fraction of time.",
        "derate" => "Capacity derating applied during a partial outage.",
        "mttrfull" => "Mean time to repair after a full outage, in hours.",
        "mttrpart" => "Mean time to repair after a partial outage, in hours.",
        "id_bus" => "Bus to which the generator is connected.",
        "pmin" => "Minimum power output per unit in MW.",
        "pmax" => "Maximum power output per unit in MW.",
        "rup" => "Ramp-up capability in MW/min.",
        "rdw" => "Ramp-down capability in MW/min.",
        "investment" => "Investment flag: `1` for an investment record and `0` for a non-investment record.",
        "active" => "Inclusion flag: `1` for active and `0` for inactive.",
        "cvar" => "Variable generation cost in `\$/MWh`.",
        "cfuel" => "Fuel cost in `\$/GJ`.",
        "cvom" => "Variable operation and maintenance cost in `\$/MWh`.",
        "cfom" => "Fixed operation and maintenance cost parameter.",
        "co2" => "Carbon-dioxide emissions intensity in kgCO2/MWh.",
        "hrate" => "Generator heat-rate parameter used with fuel-cost information.",
        "pfrmax" => "Maximum headroom available for frequency response in MW.",
        "ffr" => "Fast-frequency-response provision flag.",
        "pfr" => "Primary-frequency-response provision flag.",
        "res2" => "Secondary-reserve provision flag.",
        "res3" => "Tertiary or regulation-reserve provision flag.",
        "n" => "Maximum number of generator units available or online.",
        "down_time" => "Minimum down time after shutdown, in hours.",
        "up_time" => "Minimum up time after startup, in hours.",
        "start_up_cost" => "Startup cost in dollars.",
        "shut_down_cost" => "Shutdown cost in dollars.",
        "start_up_time" => "Time required to start a unit, in hours.",
        "shut_down_time" => "Time required to shut down a unit, in hours.",
        "powerfactor" => "Power factor.",
        "contingency" => "Contingency.",
    ],
    "Line" => [
        "id_lin" => "Unique line or transfer-corridor identifier.",
        "tech" => "Line or transfer technology.",
        "capacity" => "Maximum line capacity in MW.",
        "id_bus_from" => "Bus at the forward-direction origin.",
        "id_bus_to" => "Bus at the forward-direction destination.",
        "investment" => "Investment flag: `1` for an investment record and `0` for a non-investment record.",
        "active" => "Inclusion flag: `1` for active and `0` for inactive.",
        "fwcap" => "Maximum forward transfer capacity per unit in MW.",
        "rvcap" => "Maximum reverse transfer capacity per unit in MW.",
        "fullout" => "Unplanned full-outage rate for a single credible contingency, represented as a fraction of time.",
        "mttrfull" => "Mean time to repair after the contingency, in hours.",
        "n" => "Maximum number of line units or parallel elements available.",
    ],
)

function field_glossary(table)
    haskey(static_columns, table) || error("unknown static table `$table`")
    live = Set(static_columns[table])
    rows = ["| Field | Meaning |", "|---|---|"]
    for (field, meaning) in FIELD_MEANINGS[table]
        field in live || error("`$table.$field` is documented but is not a current column")
        push!(rows, "| `$field` | $meaning |")
    end
    ParseISPDocUtils.RawMarkdown(join(rows, "\n"))
end
````

```@raw html
</details>
```

### `Bus`

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
field_glossary("Bus")
````

```@raw html
</details>
```

| Field | Meaning |
|---|---|
| `id_bus` | Unique bus identifier. |
| `active` | Inclusion flag: `1` for active and `0` for inactive. |
| `id_area` | NEM market-area identifier: `1` QLD, `2` NSW, `3` VIC, `4` TAS, and `5` SA. |

### `Demand`

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
field_glossary("Demand")
````

```@raw html
</details>
```

| Field | Meaning |
|---|---|
| `id_dem` | Unique demand identifier. |
| `load_` | Static load value in MW; `Demand_load_sched` supplies the time-varying load. |
| `id_bus` | Bus to which the demand is connected. |
| `active` | Inclusion flag: `1` for active and `0` for inactive. |
| `controllable` | Controllability flag: `1` for controllable and `0` for non-controllable demand. |
| `voll` | Value of lost load in `$/MWh`. |

### `DER`

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
field_glossary("DER")
````

```@raw html
</details>
```

| Field | Meaning |
|---|---|
| `id_der` | Unique DER identifier. |
| `name` | DER name. |
| `tech` | DER technology or service category, including `DSP` for demand-side participation. |
| `id_dem` | Demand record to which the DER is attached. |
| `active` | Inclusion flag: `1` for active and `0` for inactive. |
| `capacity` | DER service capacity in MW. |
| `reduct` | Reduction flag: `1` when the service represents load reduction and `0` otherwise. |
| `pred_max` | Maximum predicted load-reduction capacity in MW. |
| `cost_red` | Cost associated with load reduction in `$/MWh`. |

### `ESS`

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
field_glossary("ESS")
````

```@raw html
</details>
```

| Field | Meaning |
|---|---|
| `id_ess` | Unique energy-storage identifier. |
| `tech` | Storage technology, including `BESS` for battery energy storage and `PS` for pumped storage. |
| `type` | Storage-duration category, such as shallow, medium, or deep. |
| `investment` | Investment flag: `1` for an investment record and `0` for a non-investment record. |
| `active` | Inclusion flag: `1` for active and `0` for inactive. |
| `id_bus` | Bus to which the storage asset is connected. |
| `ch_eff` | Charging efficiency under the package's stored fraction convention. |
| `dch_eff` | Discharging efficiency under the package's stored fraction convention. |
| `eini` | Initial stored-energy fraction relative to `emax`. |
| `emin` | Minimum stored-energy fraction relative to `emax`. |
| `emax` | Maximum stored-energy capacity in MWh. |
| `pmin` | Minimum discharging power per unit in MW. |
| `pmax` | Maximum discharging power per unit in MW. |
| `lmin` | Minimum charging input per unit in MW. |
| `lmax` | Maximum charging input per unit in MW. |
| `fullout` | Full forced-outage rate, represented as a fraction of time. |
| `partialout` | Partial forced-outage rate, represented as a fraction of time. |
| `mttrfull` | Mean time to repair after a full outage, in hours. |
| `mttrpart` | Mean time to repair after a partial outage, in hours. |
| `n` | Maximum number of storage units available or online. |
| `ffr` | Fast-frequency-response provision flag. |
| `pfr` | Primary-frequency-response provision flag. |
| `res2` | Secondary-reserve provision flag. |
| `res3` | Tertiary or regulation-reserve provision flag. |
| `powerfactor` | Power factor. |
| `contingency` | Contingency. |

### `Generator`

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
field_glossary("Generator")
````

```@raw html
</details>
```

| Field | Meaning |
|---|---|
| `id_gen` | Unique generator identifier. |
| `fuel` | Generator fuel category. |
| `tech` | Generator technology. |
| `type` | Generator type or planning classification. |
| `forate` | Aggregate forced-outage parameter supplied by the package. |
| `fullout` | Full forced-outage rate, represented as a fraction of time. |
| `partialout` | Partial forced-outage rate, represented as a fraction of time. |
| `derate` | Capacity derating applied during a partial outage. |
| `mttrfull` | Mean time to repair after a full outage, in hours. |
| `mttrpart` | Mean time to repair after a partial outage, in hours. |
| `id_bus` | Bus to which the generator is connected. |
| `pmin` | Minimum power output per unit in MW. |
| `pmax` | Maximum power output per unit in MW. |
| `rup` | Ramp-up capability in MW/min. |
| `rdw` | Ramp-down capability in MW/min. |
| `investment` | Investment flag: `1` for an investment record and `0` for a non-investment record. |
| `active` | Inclusion flag: `1` for active and `0` for inactive. |
| `cvar` | Variable generation cost in `$/MWh`. |
| `cfuel` | Fuel cost in `$/GJ`. |
| `cvom` | Variable operation and maintenance cost in `$/MWh`. |
| `cfom` | Fixed operation and maintenance cost parameter. |
| `co2` | Carbon-dioxide emissions intensity in kgCO2/MWh. |
| `hrate` | Generator heat-rate parameter used with fuel-cost information. |
| `pfrmax` | Maximum headroom available for frequency response in MW. |
| `ffr` | Fast-frequency-response provision flag. |
| `pfr` | Primary-frequency-response provision flag. |
| `res2` | Secondary-reserve provision flag. |
| `res3` | Tertiary or regulation-reserve provision flag. |
| `n` | Maximum number of generator units available or online. |
| `down_time` | Minimum down time after shutdown, in hours. |
| `up_time` | Minimum up time after startup, in hours. |
| `start_up_cost` | Startup cost in dollars. |
| `shut_down_cost` | Shutdown cost in dollars. |
| `start_up_time` | Time required to start a unit, in hours. |
| `shut_down_time` | Time required to shut down a unit, in hours. |
| `powerfactor` | Power factor. |
| `contingency` | Contingency. |

### `Line`

```@raw html
<details class="source-code"><summary>Show source code</summary>
```

````julia
field_glossary("Line")
````

```@raw html
</details>
```

| Field | Meaning |
|---|---|
| `id_lin` | Unique line or transfer-corridor identifier. |
| `tech` | Line or transfer technology. |
| `capacity` | Maximum line capacity in MW. |
| `id_bus_from` | Bus at the forward-direction origin. |
| `id_bus_to` | Bus at the forward-direction destination. |
| `investment` | Investment flag: `1` for an investment record and `0` for a non-investment record. |
| `active` | Inclusion flag: `1` for active and `0` for inactive. |
| `fwcap` | Maximum forward transfer capacity per unit in MW. |
| `rvcap` | Maximum reverse transfer capacity per unit in MW. |
| `fullout` | Unplanned full-outage rate for a single credible contingency, represented as a fraction of time. |
| `mttrfull` | Mean time to repair after the contingency, in hours. |
| `n` | Maximum number of line units or parallel elements available. |

A full outage removes the affected unit from service. A partial outage leaves the unit available at a reduced capability determined by the partial-outage and derating parameters. Mean time to repair is the average restoration duration after the corresponding outage state.

## Output directory pattern

Static tables are written directly under a format directory such as `csv/` or `arrow/`. Time-varying tables are written under `schedule-<tag>/`, where the tag is either a planning year or an explicit date range.

A schedule is an overlay, not an independent asset inventory. Reconstruct a system state by selecting the required scenario and timestamp, joining the schedule to its static table, and replacing only the quantity represented by the schedule.

## Using the output tables

- Identifier columns define table relationships; row order does not.
- `scenario` and `date` are part of the schedule key even when an analysis displays only one scenario or period.
- Units follow the represented quantity: power and transfer limits are in MW, storage energy and inflow quantities are in MWh, and unit-count schedules are counts.
- Solar and wind schedule values should not be normalised by static `Generator.pmax` without applying the modelling convention described in [Assumptions and scope](@ref).
