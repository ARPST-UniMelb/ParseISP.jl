using ParseISP
using Test
using DataFrames

const EXPECTED_ISP2024_SOURCE_SPEC_IDS = [
    :additional_generator_summary,
    :anticipated_generator_maximum_capacity,
    :auxiliary_rez_generation_capacity,
    :bess_maximum_capacity,
    :bess_storage_properties,
    :bess_summary_mapping,
    :buildout_schedule,
    :coal_minimum_stable_generation,
    :committed_generator_maximum_capacity,
    :condensed_capacity_outlook,
    :core_capacity_outlook,
    :core_rez_generation_capacity,
    :core_storage_capacity_outlook,
    :core_storage_energy_outlook,
    :distributed_pv_demand_trace,
    :dsp_green_energy_exports_nsw_summer,
    :dsp_green_energy_exports_nsw_winter,
    :dsp_green_energy_exports_qld_summer,
    :dsp_green_energy_exports_qld_winter,
    :dsp_green_energy_exports_sa_summer,
    :dsp_green_energy_exports_sa_winter,
    :dsp_green_energy_exports_tas_summer,
    :dsp_green_energy_exports_tas_winter,
    :dsp_green_energy_exports_vic_summer,
    :dsp_green_energy_exports_vic_winter,
    :dsp_progressive_change_nsw_summer,
    :dsp_progressive_change_nsw_winter,
    :dsp_progressive_change_qld_summer,
    :dsp_progressive_change_qld_winter,
    :dsp_progressive_change_sa_summer,
    :dsp_progressive_change_sa_winter,
    :dsp_progressive_change_tas_summer,
    :dsp_progressive_change_tas_winter,
    :dsp_progressive_change_vic_summer,
    :dsp_progressive_change_vic_winter,
    :dsp_step_change_nsw_summer,
    :dsp_step_change_nsw_winter,
    :dsp_step_change_qld_summer,
    :dsp_step_change_qld_winter,
    :dsp_step_change_sa_summer,
    :dsp_step_change_sa_winter,
    :dsp_step_change_tas_summer,
    :dsp_step_change_tas_winter,
    :dsp_step_change_vic_summer,
    :dsp_step_change_vic_winter,
    :ev_bev_phev_charge_type,
    :ev_bev_phev_profile_weekday,
    :ev_bev_phev_profile_weekend,
    :ev_subregional_demand_allocation,
    :ev_vehicle_numbers,
    :existing_generator_maximum_capacity,
    :existing_generator_reliability,
    :existing_generator_summary,
    :existing_generators,
    :existing_solar_trace,
    :existing_wind_trace,
    :flow_path_augmentation_options,
    :generator_emissions_intensity,
    :generator_maximum_ramp_rates,
    :generator_minimum_up_down_times,
    :generator_retirements,
    :generator_summary_mapping,
    :generator_summary_mapping_mlf,
    :generator_summary_mapping_names,
    :gpg_minimum_stable_generation,
    :hydro_annual_energy_limit_trace,
    :hydro_natural_inflow_trace,
    :hydro_scheme_inflows,
    :legacy_generator_minimum_up_time,
    :network_capability,
    :new_generator_reliability,
    :operational_demand_trace,
    :pumped_storage_properties,
    :reference_year_trace,
    :renewable_energy_zones,
    :rez_solar_trace,
    :rez_wind_trace,
    :transmission_reliability,
    :vpp_capacity_outlook,
    :vpp_energy_outlook,
]

const EXPECTED_ISP2024_SOURCE_SPEC_FNV1A64 = "1d0d23037b5b560c"

_source_spec_snapshot_value(::Nothing) = "N;"
_source_spec_snapshot_value(value::Bool) = value ? "B1;" : "B0;"
_source_spec_snapshot_value(value::Integer) = "I$(value);"
_source_spec_snapshot_value(value::AbstractString) =
    "S$(ncodeunits(value)):$(value);"
_source_spec_snapshot_value(value::AbstractVector) =
    "V$(length(value)):" * join(_source_spec_snapshot_value.(value)) * ";"
_source_spec_snapshot_value(value::NamedTuple) =
    "T$(length(value)):" * join(
        _source_spec_snapshot_value(string(name)) * _source_spec_snapshot_value(field)
        for (name, field) in pairs(value)
    ) * ";"

function _source_spec_snapshot_digest(value::AbstractString)
    digest = UInt64(0xcbf29ce484222325)
    for byte in codeunits(value)
        digest = xor(digest, UInt64(byte)) * UInt64(0x100000001b3)
    end
    return string(digest; base = 16, pad = 16)
end

const EXPECTED_ISP2026_FY_2025_2050 = [
    "2025-26", "2026-27", "2027-28", "2028-29", "2029-30",
    "2030-31", "2031-32", "2032-33", "2033-34", "2034-35",
    "2035-36", "2036-37", "2037-38", "2038-39", "2039-40",
    "2040-41", "2041-42", "2042-43", "2043-44", "2044-45",
    "2045-46", "2046-47", "2047-48", "2048-49", "2049-50",
]
const EXPECTED_ISP2026_FY_2026_2050 = [
    "2026-27", "2027-28", "2028-29", "2029-30", "2030-31",
    "2031-32", "2032-33", "2033-34", "2034-35", "2035-36",
    "2036-37", "2037-38", "2038-39", "2039-40", "2040-41",
    "2041-42", "2042-43", "2043-44", "2044-45", "2045-46",
    "2046-47", "2047-48", "2048-49", "2049-50",
]
const EXPECTED_ISP2026_FY_2025_2055 = [
    EXPECTED_ISP2026_FY_2025_2050...,
    "2050-51", "2051-52", "2052-53", "2053-54", "2054-55",
]
const EXPECTED_ISP2026_HALF_HOURS = [
    "01", "02", "03", "04", "05", "06", "07", "08", "09", "10",
    "11", "12", "13", "14", "15", "16", "17", "18", "19", "20",
    "21", "22", "23", "24", "25", "26", "27", "28", "29", "30",
    "31", "32", "33", "34", "35", "36", "37", "38", "39", "40",
    "41", "42", "43", "44", "45", "46", "47", "48",
]
const EXPECTED_ISP2026_KEYS = ["Year", "Month", "Day"]
const EXPECTED_ISP2026_HALF_HOURLY_COLUMNS = [
    EXPECTED_ISP2026_KEYS..., EXPECTED_ISP2026_HALF_HOURS...,
]
const EXPECTED_ISP2026_REUSED_IDS = [
    :core_capacity_outlook,
    :core_storage_capacity_outlook,
    :core_storage_energy_outlook,
    :core_rez_generation_capacity,
    :transmission_reliability,
    :renewable_energy_zones,
    :operational_demand_trace,
    :distributed_pv_demand_trace,
]
const EXPECTED_ISP2026_NEW_IDS = [
    :hybrid_site_limits,
    :dsp_assumptions,
    :dnsp_cer_trace,
    :gas_limit_trace,
    :load_subtractor_trace,
    :solar_availability_traces,
    :wind_availability_traces,
]

const EXPECTED_ISP2026_XLSX_SPECS = Dict(
    :core_capacity_outlook => (
        workbook = "Core scenarios/2026 ISP - {scenario} - Core.xlsx",
        worksheet = "Capacity",
        cell_range = "A3:AC7737",
        source_family = :generation_outlook,
        columns = ["CDP", "Region", "Subregion", "Technology", EXPECTED_ISP2026_FY_2025_2050...],
    ),
    :core_storage_capacity_outlook => (
        workbook = "Core scenarios/2026 ISP - {scenario} - Core.xlsx",
        worksheet = "Storage Capacity",
        cell_range = "A3:AB3432",
        source_family = :storage_outlook,
        columns = ["CDP", "Region", "Subregion", "storage category", EXPECTED_ISP2026_FY_2026_2050...],
    ),
    :core_storage_energy_outlook => (
        workbook = "Core scenarios/2026 ISP - {scenario} - Core.xlsx",
        worksheet = "Storage Energy",
        cell_range = "A3:AB3420",
        source_family = :storage_outlook,
        columns = ["CDP", "Region", "Subregion", "Technology", EXPECTED_ISP2026_FY_2026_2050...],
    ),
    :core_rez_generation_capacity => (
        workbook = "Core scenarios/2026 ISP - {scenario} - Core.xlsx",
        worksheet = "REZ Generation Capacity",
        cell_range = "A3:AC8787",
        source_family = :generation_outlook,
        columns = ["CDP", "Region", "REZ", "REZ Name", "Technology", EXPECTED_ISP2026_FY_2026_2050...],
    ),
    :transmission_reliability => (
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Transmission Reliability",
        cell_range = "B7:E13",
        source_family = :network,
        columns = ["Line/Flowpath", "Implementation", "Unplanned Outage Rate (%)", "Mean Time to Repair"],
    ),
    :renewable_energy_zones => (
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Renewable energy zones",
        cell_range = "B6:E53",
        source_family = :renewable_energy_zones,
        columns = ["ID", "Name", "NEM region", "ISP sub-region"],
    ),
    :hybrid_site_limits => (
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Hybrid site limits",
        cell_range = "B9:G67",
        source_family = :generation_constraints,
        columns = ["IASR ID", "Status", "Technology", "Region", "Site Name", "Connection Capacity (MW)"],
    ),
    :dsp_assumptions => (
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "DSP",
        cell_range = "B9:AI164",
        source_family = :demand_side_participation,
        columns = ["Region", "Price band", "Scenario", "Season", EXPECTED_ISP2026_FY_2025_2055...],
    ),
)

const EXPECTED_ISP2026_CSV_SPECS = Dict(
    :operational_demand_trace => (
        filename_pattern = "2026 ISP Model/2026 ISP {scenario}/Traces/demand/*.csv",
        source_family = :demand_traces,
        columns = EXPECTED_ISP2026_HALF_HOURLY_COLUMNS,
    ),
    :distributed_pv_demand_trace => (
        filename_pattern = "2026 ISP Model/2026 ISP {scenario}/Traces/rooftop PV/*.csv",
        source_family = :demand_traces,
        columns = EXPECTED_ISP2026_HALF_HOURLY_COLUMNS,
    ),
    :dnsp_cer_trace => (
        filename_pattern = "2026 ISP Model/2026 ISP {scenario}/Traces/dnsp/*.csv",
        source_family = :dnsp_traces,
        columns = EXPECTED_ISP2026_HALF_HOURLY_COLUMNS,
    ),
    :gas_limit_trace => (
        filename_pattern = "2026 ISP Model/2026 ISP {scenario}/Traces/gas/*.csv",
        source_family = :gas_traces,
        columns = [EXPECTED_ISP2026_KEYS..., "Value"],
    ),
    :load_subtractor_trace => (
        filename_pattern = "2026 ISP Model/2026 ISP {scenario}/Traces/load_subtractor/*.csv",
        source_family = :load_subtractor_traces,
        columns = EXPECTED_ISP2026_HALF_HOURLY_COLUMNS,
    ),
    :solar_availability_traces => (
        filename_pattern = "Traces/2026 ISP Solar traces/solar/*.csv",
        source_family = :solar_traces,
        columns = EXPECTED_ISP2026_HALF_HOURLY_COLUMNS,
    ),
    :wind_availability_traces => (
        filename_pattern = "Traces/2026 ISP Wind traces/wind/*.csv",
        source_family = :wind_traces,
        columns = EXPECTED_ISP2026_HALF_HOURLY_COLUMNS,
    ),
)

@testset "source specs: ISP 2026 runtime registry" begin
    expected_ids = sort!(collect(union(
        keys(EXPECTED_ISP2026_XLSX_SPECS),
        keys(EXPECTED_ISP2026_CSV_SPECS),
    )); by = string)
    specs = ParseISP.source_specs(2026)

    @test getfield.(specs, :id) == expected_ids
    @test length(unique((spec.edition, spec.id) for spec in specs)) == 15
    @test ParseISP.source_spec_registry(2026).edition == 2026
    @test all(spec -> spec.consumer === nothing, specs)
    @test all(
        id -> ParseISP.source_spec(id, 2026).source_family ==
              ParseISP.source_spec(id, 2024).source_family,
        EXPECTED_ISP2026_REUSED_IDS,
    )
    @test all(
        id -> try
            ParseISP.source_spec(id, 2024)
            false
        catch error
            error isa KeyError
        end,
        EXPECTED_ISP2026_NEW_IDS,
    )

    root = normpath("temporary", "isp2026-root")
    for (id, expected) in EXPECTED_ISP2026_XLSX_SPECS
        spec = ParseISP.source_spec(id, 2026)
        @test spec isa ParseISP.XlsxSourceSpec
        @test spec.edition == 2026
        @test spec.workbook == expected.workbook
        @test spec.worksheet == expected.worksheet
        @test spec.cell_range == expected.cell_range
        @test spec.source_family == expected.source_family
        @test getfield.(spec.columns, :name) == expected.columns
        @test all(column -> column.required, spec.columns)
        @test all(column -> column.data_type === nothing, spec.columns)
        @test all(column -> column.unit === nothing, spec.columns)
        @test all(column -> isempty(column.description), spec.columns)
        @test spec.consumer === nothing

        replacements = occursin("{scenario}", spec.workbook) ? (; scenario = "Step Change") : (;)
        expected_workbook = replace(expected.workbook, "{scenario}" => "Step Change")
        @test ParseISP.source_path(root, spec; replacements...) ==
              normpath(root, expected_workbook)
    end

    for (id, expected) in EXPECTED_ISP2026_CSV_SPECS
        spec = ParseISP.source_spec(id, 2026)
        @test spec isa ParseISP.CsvSourceSpec
        @test spec.edition == 2026
        @test spec.filename_pattern == expected.filename_pattern
        @test spec.keys == EXPECTED_ISP2026_KEYS
        @test spec.source_family == expected.source_family
        @test getfield.(spec.columns, :name) == expected.columns
        @test all(column -> column.required, spec.columns)
        @test all(column -> column.data_type === nothing, spec.columns)
        @test all(column -> column.unit === nothing, spec.columns)
        @test all(column -> isempty(column.description), spec.columns)
        @test spec.consumer === nothing

        replacements = occursin("{scenario}", spec.filename_pattern) ? (; scenario = "Step Change") : (;)
        expected_pattern = replace(expected.filename_pattern, "{scenario}" => "Step Change")
        resolved = ParseISP.source_path(root, spec; replacements...)
        @test resolved == normpath(root, expected_pattern)
        @test endswith(resolved, "*.csv")
    end

    unresolved_error = try
        ParseISP.source_path(root, ParseISP.source_spec(:operational_demand_trace, 2026))
        nothing
    catch error
        error
    end
    @test unresolved_error isa ArgumentError
    @test occursin("Unresolved source-pattern token {scenario}", sprint(showerror, unresolved_error))

    unknown_error = try
        ParseISP.source_spec(:not_registered_for_isp2026, 2026)
        nothing
    catch error
        error
    end
    @test unknown_error isa KeyError
    @test unknown_error.key == (2026, :not_registered_for_isp2026)

    trace_spec = ParseISP.source_spec(:operational_demand_trace, 2026)
    incomplete_trace = DataFrame([
        Symbol(name) => Int[]
        for name in EXPECTED_ISP2026_HALF_HOURLY_COLUMNS[1:end-1]
    ])
    missing_header_error = try
        ParseISP.validate_source_columns(incomplete_trace, trace_spec)
        nothing
    catch error
        error
    end
    @test missing_header_error isa ArgumentError
    @test sprint(showerror, missing_header_error) ==
          "ArgumentError: Source operational_demand_trace is missing required columns: 48."
end

@testset "source specs: ISP 2024 registry snapshot" begin
    specs_2024 = ParseISP.source_specs(2024)
    records_2024 = ParseISP.source_spec_records(2024)
    canonical_records_2024 = _source_spec_snapshot_value(records_2024)

    @test getfield.(specs_2024, :id) == EXPECTED_ISP2024_SOURCE_SPEC_IDS
    @test _source_spec_snapshot_digest(canonical_records_2024) ==
          EXPECTED_ISP2024_SOURCE_SPEC_FNV1A64
end
