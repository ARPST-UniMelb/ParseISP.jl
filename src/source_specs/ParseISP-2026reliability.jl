const _ISP2026_RELIABILITY_YEARS = [
    "$(year)-$(lpad(string(mod(year + 1, 100)), 2, '0'))" for year in 2025:2034
]

const _ISP2026_RELIABILITY_COLUMNS = ["Fuel type", "Property", _ISP2026_RELIABILITY_YEARS...]
const _ISP2026_NEW_RELIABILITY_COLUMNS = [
    "Fuel type", "Full outage (% of time)", "Partial outage (% of time)",
    "Full outage MTTR (hrs)", "Partial outage MTTR (hrs)",
    "Partial Outage Derating Factor (%)", "notes",
]
const _ISP2026_RETIREMENT_COLUMNS = [
    "IASR ID", "Power Station", "Technology Type", "Status",
    "Expected Closure Year (Calendar year)",
]
const _ISP2026_COAL_MINIMUM_COLUMNS = [
    "IASR ID", "Power Station", "Technology Type", "IASR 2023 (Backcasting)",
    "Typical Lowest Band", "Minimum Continuous Operating Level",
]
const _ISP2026_GPG_MINIMUM_COLUMNS = [
    "IASR ID", "Power Station", "Technology Type", "Min Stable Level (MW)",
]
const _ISP2026_NEW_GPG_MINIMUM_COLUMNS = ["Technology", "Min Stable Level (% of nameplate)"]
const _ISP2026_RAMP_COLUMNS = [
    "IASR ID", "Power Station", "Technology Type", "Max Ramp Up (MW/min)",
    "Max Ramp Down (MW/min)",
]
const _ISP2026_NEW_RAMP_COLUMNS = [
    "Technology", "Max Ramp Up (MW/min)", "Max Ramp Down (MW/min)",
]

_isp2026_reliability_columns(names) = ColumnSpec[ColumnSpec(name = name) for name in names]

register_source_specs!(
    XlsxSourceSpec(
        id = :generator_reliability_long_duration,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Generator Reliability Settings",
        cell_range = "B10:M16",
        description = "ISP 2026 existing-generator long-duration outage factors and MTTR.",
        columns = _isp2026_reliability_columns(_ISP2026_RELIABILITY_COLUMNS),
        source_family = :generation_reliability,
    ),
    XlsxSourceSpec(
        id = :generator_reliability_outage_rates,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Generator Reliability Settings",
        cell_range = "B22:M57",
        description = "ISP 2026 existing-generator outage rates, derating, and MTTR.",
        columns = _isp2026_reliability_columns(_ISP2026_RELIABILITY_COLUMNS),
        source_family = :generation_reliability,
    ),
    XlsxSourceSpec(
        id = :generator_reliability_new_entrants,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Generator Reliability Settings",
        cell_range = "B63:H84",
        description = "ISP 2026 new-entrant outage and MTTR assumptions.",
        columns = _isp2026_reliability_columns(_ISP2026_NEW_RELIABILITY_COLUMNS),
        source_family = :generation_reliability,
    ),
    XlsxSourceSpec(
        id = :generator_retirement,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Retirement",
        cell_range = "B12:F738",
        description = "ISP 2026 generator expected closure records.",
        columns = _isp2026_reliability_columns(_ISP2026_RETIREMENT_COLUMNS),
        source_family = :generation_retirement,
    ),
    XlsxSourceSpec(
        id = :coal_minimum_stable_level,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Coal Min Stable Level",
        cell_range = "B12:G57",
        description = "ISP 2026 coal minimum stable level series.",
        columns = _isp2026_reliability_columns(_ISP2026_COAL_MINIMUM_COLUMNS),
        source_family = :generation_operation,
    ),
    XlsxSourceSpec(
        id = :gpg_minimum_stable_level,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "GPG Min Stable Level",
        cell_range = "B11:E150",
        description = "ISP 2026 existing GPG minimum stable levels.",
        columns = _isp2026_reliability_columns(_ISP2026_GPG_MINIMUM_COLUMNS),
        source_family = :generation_operation,
    ),
    XlsxSourceSpec(
        id = :new_gpg_minimum_stable_level,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "GPG Min Stable Level",
        cell_range = "F11:G32",
        description = "ISP 2026 new-entrant GPG minimum stable levels.",
        columns = _isp2026_reliability_columns(_ISP2026_NEW_GPG_MINIMUM_COLUMNS),
        source_family = :generation_operation,
    ),
    XlsxSourceSpec(
        id = :generator_max_ramp_rates,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Max Ramp Rates",
        cell_range = "B8:F191",
        description = "ISP 2026 existing thermal-generator ramp rates.",
        columns = _isp2026_reliability_columns(_ISP2026_RAMP_COLUMNS),
        source_family = :generation_operation,
    ),
    XlsxSourceSpec(
        id = :new_generator_max_ramp_rates,
        edition = 2026,
        workbook = _ISP2026_INPUTS_WORKBOOK,
        worksheet = "Max Ramp Rates",
        cell_range = "H8:J29",
        description = "ISP 2026 new-entrant ramp-rate assumptions.",
        columns = _isp2026_reliability_columns(_ISP2026_NEW_RAMP_COLUMNS),
        source_family = :generation_operation,
    ),
)
