# Domain concepts

The ParseISP dataset layer connects asset identities, relationships, and schedule overlays.

ParseISP represents its implemented ISP 2024 workflow as a connected data model rather than as a collection of independent CSV files.
The central distinction is between **assets**, which retain stable identities and mostly static parameters, and **schedules**, which describe how selected asset quantities change with scenario and time.

## ISP 2024 dataset relationships

```text
                         +----------------+
                         |      Bus       |
                         +----------------+
                           ^      ^      ^
                           |      |      |
             +-------------+      |      +-------------+
             |                    |                    |
        +---------+          +-----------+         +-------+
        | Demand  |          | Generator |         |  ESS  |
        +---------+          +-----------+         +-------+
             ^                    ^                    ^
             |                    |                    |
          +-----+          schedule tables      schedule tables
          | DER |                 |
          +-----+                 v
             ^              scenario and time
             |
       schedule tables

Bus <---------------------- Line ----------------------> Bus
                               ^
                               |
                         schedule tables
```

The identifiers in the ISP 2024 static tables provide the joins:

- `Demand.id_bus`, `Generator.id_bus`, and `ESS.id_bus` attach assets to a bus.
- `DER.id_dem` attaches a demand-side resource to a demand node, which then identifies its bus.
- `Line.id_bus_from` and `Line.id_bus_to` connect two buses.
- Each schedule uses the corresponding asset identifier together with `scenario` and `date`.

## Modelling role of each static table

### `Bus`

An ISP 2024 ParseISP bus is an aggregated ISP sub-region, not an electrical busbar in a nodal network model.
The table provides the common spatial index used by demand, generation, storage, and transmission corridors.
Its representative coordinates support regional identification and visualisation; they do not define detailed network geometry.

### `Demand`

A demand row represents a load node attached to a ParseISP bus.
The static row preserves identity, location, and demand-related flags, while `Demand_load_sched` provides the time-varying load used for a selected scenario and trace.
Separating the node from its load profile allows the same asset identity to be retained across many planning periods.

### `DER`

The `DER` table represents demand-side participation and EV-related quantities linked to demand nodes.
It is narrower than the general power-system meaning of distributed energy resources: rooftop PV is represented in `Generator`, and storage is represented in `ESS`.
`DER_pred_sched` carries the time-varying predicted quantity associated with each DER row.

### `Generator`

A generator row represents an existing unit, an aggregated renewable resource, or a future build-out asset used within the planning horizon.
The static table records identity, technology, connection, capacity-related fields, costs, outage inputs, and unit-commitment parameters.
Schedules then describe quantities that can change with planning year or trace, including maximum output, available unit count, and hydro inflow.

### `ESS`

An `ESS` row represents a battery, pumped-storage asset, or other storage resource connected to a bus.
The static table distinguishes discharge power, charging power, energy capacity, efficiency, reliability, and service attributes.
Separate schedules can change discharge power, charging power, energy capacity, unit count, and inflow without replacing the asset row.

### `Line`

A line row represents an aggregated transfer corridor or augmentation option between two ParseISP buses.
It is a planning-level connection rather than a detailed AC branch model.
Forward and reverse capacity schedules allow transfer limits to change across the study horizon while preserving the corridor identity.

## Why static tables and schedules are separate

```text
static row     = asset identity + stable parameters
schedule row   = scenario + timestamp + changing value
complete state = static row + applicable schedule overlays
```

!!! note "Why use schedule overlays?"
    Repeating every asset field for every hour would duplicate large amounts of unchanged information and make scenario comparisons harder.
    The ISP 2024 output instead stores stable information once and writes schedules only for quantities that vary.
    This design also makes the source of a change explicit: the static asset remains the same while the scheduled quantity changes.

[ISP 2024 output tables](generated/isp2024/reference/output-tables.md) lists the static and schedule tables, output names, identifier columns, and relationships.

A missing schedule row does not necessarily mean that an asset is absent.
It can mean that the static value already applies, that no change was scheduled for that period, or that trace-dependent schedules were intentionally not written.

## ISP 2024 scenario model

The `scenarios` keyword to `build_ISP24_datasets` selects the package-defined ISP 2024 scenario IDs. Several source files use different labels for the same scenario, so ParseISP reconciles those labels and retains numeric scenario IDs in exported schedules.

[ISP 2024 parameters and mappings](generated/isp2024/reference/parameters-and-mappings.md) lists the public scenario names and source-specific labels.

## Candidate and optimal development paths

A **candidate development path (CDP)** groups development paths that share a set of potential actionable projects. AEMO evaluates a shortlist of CDPs across scenarios and sensitivities before selecting an **optimal development path (ODP)**. The ODP is therefore a selected development path for an ISP edition, not a generic asset identifier. The [2024 ISP Cost-Benefit Analysis, p. 16](../../data/2024/pisp-reports/a6-cost-benefit-analysis.pdf#page=16) introduces this relationship.

For ISP 2024, AEMO selected `CDP14` as the ODP after ranking and sensitivity analysis ([2024 ISP Cost-Benefit Analysis, p. 124](../../data/2024/pisp-reports/a6-cost-benefit-analysis.pdf#page=124)). ParseISP currently filters relevant ISP 2024 generation and storage outlook reads to the literal `CDP14`.

## ISP 2024 planning years, date ranges, and the 1 July split

The ISP 2024 builder can write output by planning year or by explicit date range:

| Mode | Keyword | Output schedule tag | Split behaviour |
|---|---|---|---|
| Planning year | `years = [year]` | `schedule-<year>` | Creates January-June and July-December problem blocks for each scenario. |
| Date range | `drange = [(start, end)]` | `schedule-DDMMYYYY-DDMMYYYY` | Splits only when the requested range crosses 1 July. |

The split groups each problem block with the source inputs for the corresponding Australian financial year. Each build folder contains one set of static tables. The scenario and time-series data used to create schedules are organised by year.
The planning year determines which `schedule-<year>` period is generated. It does not select the reference-weather trace (`reftrace`) or the demand probability-of-exceedance series (`poe`).
[Working with ParseISP-generated outputs](generated/isp2024/tutorials/working-with-pisp-outputs.md) shows how `reftrace`, `poe`, and the planning year together identify an existing processed dataset.

## ISP 2024 reference-weather traces

`reftrace` selects the reference-weather trace used by the ISP 2024 builder.
`reftrace = 2017` selects the historical 2017 demand, solar, and wind traces directly.
`reftrace = 4006` selects a composite reference-weather trace that assigns selected historical weather years to financial-year windows across the planning horizon.
The composite can reuse historical year 2017 for particular windows, but `2017` and `4006` remain different trace identifiers.
A `reftrace` value does not select a candidate or optimal development path.

Comparisons that ignore the paired weather year can mix planning-year effects with weather-year effects.
[ISP 2024 parameters and mappings](generated/isp2024/reference/parameters-and-mappings.md) gives the complete `4006` map.

## ISP 2024 demand probability of exceedance

`poe` independently selects the demand probability-of-exceedance series used in ISP 2024 demand filenames.
The available source families include `POE10` and `POE50` series.
For annual peak demand, 10% POE means there is a 10% chance that the year's peak demand exceeds the stated level ([2024 ISP Consultation Summary Report, p. 60](../../data/2024/pisp-reports/2024-isp-consultation-summary-report.pdf#page=60)).
The [2023 ISP Methodology, p. 39](../../data/2024/pisp-reports/2023-isp-methodology.pdf#page=39) describes the use of 10%, 50%, and sometimes 90% POE simulations and the use of 10% POE demand profiles in capacity-outlook modelling.
A `poe` value does not select weather conditions, a planning year, or a development path.
[Trace coverage](editions/trace-coverage.md) keeps the report definition of POE separate from the filename labels used by the ISP 2024 workflow.

## ISP 2024 NEM bus and area model

ParseISP represents the ISP 2024 East Coast Australian system through package-defined ISP sub-regional buses and NEM market areas.
[ISP 2024 parameters and mappings](generated/isp2024/reference/parameters-and-mappings.md) lists the bus names, representative coordinates, and area relationships.

This representation is suitable for aggregated planning studies and data preparation.
It does not contain intra-sub-region topology, bus voltages, detailed line impedances, or the constraints required for a nodal AC network model.

## Solar and wind classification

When aggregating variable renewable generation from ISP 2024 ParseISP output, classify rows by `Generator.tech`, not by `Generator.fuel` alone.
Technology labels preserve distinctions such as rooftop PV and utility-scale PV that can be lost in a broader fuel grouping.
The [Working with ParseISP-generated outputs](generated/isp2024/tutorials/working-with-pisp-outputs.md) tutorial uses case-insensitive `pv` or `solar` matches for solar and `wind` for wind.

## See also

- [Output tables](generated/isp2024/reference/output-tables.md) documents the exported filenames, join keys, and value units.
- [Parameters and mappings](generated/isp2024/reference/parameters-and-mappings.md) records the trace-year map, bus constants, and technology-specific assumptions.
- [Assumptions and scope](assumptions.md) explains the limits of the aggregated network and static reliability treatment.
