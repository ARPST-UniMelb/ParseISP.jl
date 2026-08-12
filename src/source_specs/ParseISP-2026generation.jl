const _ISP2026_EXISTING_GENERATION_COLUMNS = [
    "IASR ID", "Power Station", "Technology Type", "Fuel Type", "Region",
    "Sub-region", "REZ Location", "REZ ID", "Status", "Regional build cost zone",
    "Maximum capacity (MW)", "Storage capacity (MWh)", "Summer peak rating (MW)",
    "Summer typical rating (MW)", "Winter rating (MW)", "Minimum Stable Limit",
    "No-Load Heat Rate", "Marginal Heat Rate", "Pumping efficiency (%)",
    "Charge efficiency (%)", "Discharge efficiency (%)", "Allowable max state of charge (%)",
    "Allowable min state of charge (%)", "Round trip efficiency (%)", "Annual degradation (%)",
    "Max Ramp Up (MW/min)", "Max Ramp Down (MW/min)",
    "Maintenance - Proportion of time out (%)",
    "Maintenance - Equivalent average days per year on planned outage",
    "Full outage (% of time)", "Partial outage (% of time)", "Full outage MTTR (hrs)",
    "Partial outage MTTR (hrs)", "Partial Outage Derating Factor (%)", "FOM (\$/kW/annum)",
    "VOM (\$/MWh sent-out)", "Heat rate (GJ/MWh HHV s.o.)", "Fuel cost (\$/GJ)",
    "Scope 1 Emissions (kg/MWh)", "MLF", "Auxiliary load (% of nameplate capacity)",
    "SRMC (\$/MWh)", "Expected Closure Year (Calendar year)",
    "Retirement / Rehabilitation cost (\$/MW)", "Fault Level Replacement Cost (\$M)",
]

const _ISP2026_EMISSIONS_COLUMNS = [
    "IASR ID", "Power Station", "Technology",
    "Scope 1 emissions intensity (kg/MWh as-gen)",
]
const _ISP2026_NEW_EMISSIONS_COLUMNS = [
    "Technology", "Scope 1 emissions intensity (kg/MWh as-gen)",
]
const _ISP2026_MAXIMUM_CAPACITY_COLUMNS = [
    "IASR ID", "Power Station", "Status5", "Technology", "Region",
    "Installed capacity (MW)", "Storage Capacity (MWh)", "Commissioning date", "Policy",
]
const _ISP2026_NEW_MAXIMUM_CAPACITY_COLUMNS = [
    "Technology Type", "Unit size (MW)", "Number of units", "Total plant size (MW)",
]
const _ISP2026_SUMMARY_MAPPING_COLUMNS = [
    "RowID", "IASR ID / DLT names", "Power Station", "Technology Type", "Region",
    "Sub-region", "REZ Location", "REZ ID", "Status", "Regional build cost zone",
    "Uptake", "Fuel type", "Fuel cost mapping", "Maintenance duration (%)",
    "Forced outage rate", "Partial outage (% of time)", "Mean time to repair",
    "Partial outage", "Minimum load (MW)", "Maximum capacity factor (%)",
    "FOM (\$/kW/annum)", "VOM (\$/MWh sent-out)", "Heat rate", "Pumping efficiency (%)",
    "MLF", "Auxiliary load (%)", "Connection cost", "Region (2)", "Build limit",
    "Region (3)", "Total lead time",
]

_isp2026_generation_columns(names) = ColumnSpec[ColumnSpec(name = name) for name in names]
register_source_specs!(
    XlsxSourceSpec(
        id = :existing_generator_summary,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Existing Gen Data Summary",
        cell_range = "B10:AT738",
        description = "ISP 2026 unit-level existing generation inventory and attributes.",
        columns = _isp2026_generation_columns(_ISP2026_EXISTING_GENERATION_COLUMNS),
        source_family = :generation,
    ),
    XlsxSourceSpec(
        id = :generator_emissions_intensity,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Emissions intensity",
        cell_range = "B8:E734",
        description = "ISP 2026 existing, committed, anticipated, and additional generator emissions intensity.",
        columns = ColumnSpec[
            ColumnSpec(name = name, data_type = name == last(_ISP2026_EMISSIONS_COLUMNS) ? :Real : nothing,
                       unit = name == last(_ISP2026_EMISSIONS_COLUMNS) ? "kg/MWh as-generated" : nothing)
            for name in _ISP2026_EMISSIONS_COLUMNS
        ],
        source_family = :generation,
    ),
    XlsxSourceSpec(
        id = :new_entrant_emissions_intensity,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Emissions intensity",
        cell_range = "G8:H29",
        description = "ISP 2026 new-entrant technology emissions intensity.",
        columns = ColumnSpec[
            ColumnSpec(name = name, data_type = name == last(_ISP2026_NEW_EMISSIONS_COLUMNS) ? :Real : nothing,
                       unit = name == last(_ISP2026_NEW_EMISSIONS_COLUMNS) ? "kg/MWh as-generated" : nothing)
            for name in _ISP2026_NEW_EMISSIONS_COLUMNS
        ],
        source_family = :generation,
    ),
    XlsxSourceSpec(
        id = :generator_maximum_capacity,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Maximum capacity",
        cell_range = "B10:J736",
        description = "ISP 2026 existing, committed, anticipated, and additional generation maximum capacity.",
        columns = _isp2026_generation_columns(_ISP2026_MAXIMUM_CAPACITY_COLUMNS),
        source_family = :generation,
    ),
    XlsxSourceSpec(
        id = :new_entrant_maximum_capacity,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Maximum capacity",
        cell_range = "L10:O31",
        description = "ISP 2026 new-generation-technology maximum capacity assumptions.",
        columns = ColumnSpec[
            ColumnSpec(name = name, data_type = i > 1 ? :Real : nothing,
                       unit = i > 1 ? "MW" : nothing)
            for (i, name) in enumerate(_ISP2026_NEW_MAXIMUM_CAPACITY_COLUMNS)
        ],
        source_family = :generation,
    ),
    XlsxSourceSpec(
        id = :generator_summary_mapping,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Summary Mapping",
        cell_range = "B4:AF1381",
        description = "ISP 2026 complete generator and technology summary mapping.",
        columns = _isp2026_generation_columns(_ISP2026_SUMMARY_MAPPING_COLUMNS),
        source_family = :generation,
    ),
)
