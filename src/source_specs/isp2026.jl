const _ISP2026_INPUTS_WORKBOOK = "2026-isp-inputs-and-assumptions-workbook.xlsm"
const _ISP2026_CORE_WORKBOOK = "Core scenarios/2026 ISP - {scenario} - Core.xlsx"
const _ISP2026_CSV_KEYS = ["Year", "Month", "Day"]

const _ISP2026_FY_2025_2050 = [
    "2025-26", "2026-27", "2027-28", "2028-29", "2029-30",
    "2030-31", "2031-32", "2032-33", "2033-34", "2034-35",
    "2035-36", "2036-37", "2037-38", "2038-39", "2039-40",
    "2040-41", "2041-42", "2042-43", "2043-44", "2044-45",
    "2045-46", "2046-47", "2047-48", "2048-49", "2049-50",
]
const _ISP2026_FY_2026_2050 = [
    "2026-27", "2027-28", "2028-29", "2029-30", "2030-31",
    "2031-32", "2032-33", "2033-34", "2034-35", "2035-36",
    "2036-37", "2037-38", "2038-39", "2039-40", "2040-41",
    "2041-42", "2042-43", "2043-44", "2044-45", "2045-46",
    "2046-47", "2047-48", "2048-49", "2049-50",
]
const _ISP2026_FY_2025_2055 = [
    _ISP2026_FY_2025_2050...,
    "2050-51", "2051-52", "2052-53", "2053-54", "2054-55",
]
const _ISP2026_HALF_HOURS = [
    "01", "02", "03", "04", "05", "06", "07", "08", "09", "10",
    "11", "12", "13", "14", "15", "16", "17", "18", "19", "20",
    "21", "22", "23", "24", "25", "26", "27", "28", "29", "30",
    "31", "32", "33", "34", "35", "36", "37", "38", "39", "40",
    "41", "42", "43", "44", "45", "46", "47", "48",
]

_isp2026_columns(names) = ColumnSpec[ColumnSpec(name = name) for name in names]

const _ISP2026_CAPACITY_COLUMNS = [
    "CDP", "Region", "Subregion", "Technology", _ISP2026_FY_2025_2050...,
]
const _ISP2026_STORAGE_CAPACITY_COLUMNS = [
    "CDP", "Region", "Subregion", "storage category", _ISP2026_FY_2026_2050...,
]
const _ISP2026_STORAGE_ENERGY_COLUMNS = [
    "CDP", "Region", "Subregion", "Technology", _ISP2026_FY_2026_2050...,
]
const _ISP2026_REZ_CAPACITY_COLUMNS = [
    "CDP", "Region", "REZ", "REZ Name", "Technology", _ISP2026_FY_2026_2050...,
]
const _ISP2026_TRANSMISSION_RELIABILITY_COLUMNS = [
    "Line/Flowpath", "Implementation", "Unplanned Outage Rate (%)", "Mean Time to Repair",
]
const _ISP2026_REZ_COLUMNS = ["ID", "Name", "NEM region", "ISP sub-region"]
const _ISP2026_HYBRID_COLUMNS = [
    "IASR ID", "Status", "Technology", "Region", "Site Name", "Connection Capacity (MW)",
]
const _ISP2026_DSP_COLUMNS = [
    "Region", "Price band", "Scenario", "Season", _ISP2026_FY_2025_2055...,
]
const _ISP2026_HALF_HOURLY_TRACE_COLUMNS = [
    _ISP2026_CSV_KEYS..., _ISP2026_HALF_HOURS...,
]
const _ISP2026_GAS_TRACE_COLUMNS = [_ISP2026_CSV_KEYS..., "Value"]

const _ISP2026_SOURCE_SPECS = SourceSpec[
    XlsxSourceSpec(
        id = :core_capacity_outlook,
        edition = 2026,
        workbook = _ISP2026_CORE_WORKBOOK,
        worksheet = "Capacity",
        cell_range = "A3:AC7737",
        description = "ISP 2026 core capacity outlook.",
        columns = _isp2026_columns(_ISP2026_CAPACITY_COLUMNS),
        source_family = :generation_outlook,
        consumer = nothing,
    ),
    XlsxSourceSpec(
        id = :core_storage_capacity_outlook,
        edition = 2026,
        workbook = _ISP2026_CORE_WORKBOOK,
        worksheet = "Storage Capacity",
        cell_range = "A3:AB3432",
        description = "ISP 2026 core storage capacity outlook.",
        columns = _isp2026_columns(_ISP2026_STORAGE_CAPACITY_COLUMNS),
        source_family = :storage_outlook,
        consumer = nothing,
    ),
    XlsxSourceSpec(
        id = :core_storage_energy_outlook,
        edition = 2026,
        workbook = _ISP2026_CORE_WORKBOOK,
        worksheet = "Storage Energy",
        cell_range = "A3:AB3420",
        description = "ISP 2026 core storage energy outlook.",
        columns = _isp2026_columns(_ISP2026_STORAGE_ENERGY_COLUMNS),
        source_family = :storage_outlook,
        consumer = nothing,
    ),
    XlsxSourceSpec(
        id = :core_rez_generation_capacity,
        edition = 2026,
        workbook = _ISP2026_CORE_WORKBOOK,
        worksheet = "REZ Generation Capacity",
        cell_range = "A3:AC8787",
        description = "ISP 2026 REZ generation capacity outlook.",
        columns = _isp2026_columns(_ISP2026_REZ_CAPACITY_COLUMNS),
        source_family = :generation_outlook,
        consumer = nothing,
    ),
    XlsxSourceSpec(
        id = :transmission_reliability,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Transmission Reliability",
        cell_range = "B7:E13",
        description = "ISP 2026 transmission reliability table.",
        columns = _isp2026_columns(_ISP2026_TRANSMISSION_RELIABILITY_COLUMNS),
        source_family = :network,
        consumer = nothing,
    ),
    XlsxSourceSpec(
        id = :renewable_energy_zones,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Renewable energy zones",
        cell_range = "B6:E53",
        description = "ISP 2026 renewable energy zones table.",
        columns = _isp2026_columns(_ISP2026_REZ_COLUMNS),
        source_family = :renewable_energy_zones,
        consumer = nothing,
    ),
    XlsxSourceSpec(
        id = :hybrid_site_limits,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Hybrid site limits",
        cell_range = "B9:G67",
        description = "ISP 2026 hybrid site limits table.",
        columns = _isp2026_columns(_ISP2026_HYBRID_COLUMNS),
        source_family = :generation_constraints,
        consumer = nothing,
    ),
    XlsxSourceSpec(
        id = :dsp_assumptions,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "DSP",
        cell_range = "B9:AI164",
        description = "ISP 2026 DSP assumptions table.",
        columns = _isp2026_columns(_ISP2026_DSP_COLUMNS),
        source_family = :demand_side_participation,
        consumer = nothing,
    ),
    CsvSourceSpec(
        id = :operational_demand_trace,
        edition = 2026,
        filename_pattern = "2026 ISP Model/2026 ISP {scenario}/Traces/demand/*.csv",
        description = "ISP 2026 operational demand traces.",
        columns = _isp2026_columns(_ISP2026_HALF_HOURLY_TRACE_COLUMNS),
        keys = _ISP2026_CSV_KEYS,
        source_family = :demand_traces,
        consumer = nothing,
    ),
    CsvSourceSpec(
        id = :distributed_pv_demand_trace,
        edition = 2026,
        filename_pattern = "2026 ISP Model/2026 ISP {scenario}/Traces/rooftop PV/*.csv",
        description = "ISP 2026 distributed PV demand traces.",
        columns = _isp2026_columns(_ISP2026_HALF_HOURLY_TRACE_COLUMNS),
        keys = _ISP2026_CSV_KEYS,
        source_family = :demand_traces,
        consumer = nothing,
    ),
    CsvSourceSpec(
        id = :dnsp_cer_trace,
        edition = 2026,
        filename_pattern = "2026 ISP Model/2026 ISP {scenario}/Traces/dnsp/*.csv",
        description = "ISP 2026 DNSP CER traces.",
        columns = _isp2026_columns(_ISP2026_HALF_HOURLY_TRACE_COLUMNS),
        keys = _ISP2026_CSV_KEYS,
        source_family = :dnsp_traces,
        consumer = nothing,
    ),
    CsvSourceSpec(
        id = :gas_limit_trace,
        edition = 2026,
        filename_pattern = "2026 ISP Model/2026 ISP {scenario}/Traces/gas/*.csv",
        description = "ISP 2026 gas limit traces.",
        columns = _isp2026_columns(_ISP2026_GAS_TRACE_COLUMNS),
        keys = _ISP2026_CSV_KEYS,
        source_family = :gas_traces,
        consumer = nothing,
    ),
    CsvSourceSpec(
        id = :load_subtractor_trace,
        edition = 2026,
        filename_pattern = "2026 ISP Model/2026 ISP {scenario}/Traces/load_subtractor/*.csv",
        description = "ISP 2026 load subtractor traces.",
        columns = _isp2026_columns(_ISP2026_HALF_HOURLY_TRACE_COLUMNS),
        keys = _ISP2026_CSV_KEYS,
        source_family = :load_subtractor_traces,
        consumer = nothing,
    ),
    CsvSourceSpec(
        id = :solar_availability_traces,
        edition = 2026,
        filename_pattern = "Traces/2026 ISP Solar traces/solar/*.csv",
        description = "ISP 2026 solar availability traces.",
        columns = _isp2026_columns(_ISP2026_HALF_HOURLY_TRACE_COLUMNS),
        keys = _ISP2026_CSV_KEYS,
        source_family = :solar_traces,
        consumer = nothing,
    ),
    CsvSourceSpec(
        id = :wind_availability_traces,
        edition = 2026,
        filename_pattern = "Traces/2026 ISP Wind traces/wind/*.csv",
        description = "ISP 2026 wind availability traces.",
        columns = _isp2026_columns(_ISP2026_HALF_HOURLY_TRACE_COLUMNS),
        keys = _ISP2026_CSV_KEYS,
        source_family = :wind_traces,
        consumer = nothing,
    ),
]

register_source_specs!(_ISP2026_SOURCE_SPECS...)
