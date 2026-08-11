# Characterisation tests for the hard-coded 2024 source specifications.
#
# Each test reads a workbook range or CSV file used by the parser and checks its
# columns, dimensions, and representative values. Together, these checks define
# the source-data contracts that parser refactors must preserve.
#
# The tests use the same readers as the parser and skip when the required local
# AEMO data is unavailable.

using DataFrames
using CSV

source_specs_edition_2024 = only(filter(
    p -> p.edition == "2024",
    ParseISPDocUtils.source_availability_profiles(normpath(joinpath(@__DIR__, ".."))),
))
source_specs_2024_available = ParseISPDocUtils.inspect_edition(source_specs_edition_2024).state == :complete

@testset "source specs: hardcoded 2024 workbook/CSV read contracts" begin
    if !source_specs_2024_available
        @test_skip "2024 pisp-downloads material is absent; source-spec characterization requires the real AEMO workbooks/CSVs"
    else
        paths = ParseISP.default_data_paths(filepath=source_specs_edition_2024.download_root)

        @testset "existing_generators — 2024-isp-inputs-and-assumptions-workbook.xlsx / Existing Gen Data Summary / B11:K297" begin
            df = ParseISP.read_xlsx_with_header(paths.ispdata24, "Existing Gen Data Summary", "B11:K297")
            # This range has a blank header row. `read_xlsx_with_header` converts each blank
            # cell to `"missing"` and numbers the duplicate names. The parser reads this
            # table by column position rather than by name.
            @test names(df) == ["missing", "missing_1", "missing_2", "missing_3", "missing_4",
                                 "missing_5", "missing_6", "missing_7", "missing_8", "missing_9"]
            @test size(df) == (286, 10)
            @test collect(df[end, :]) ==
                  Any["Wambo Wind Farm", "Wind", "QLD", "SQ", "Darling Downs", "Wind", 252, 252, 252, 252]
        end

        @testset "network_capability — 2024-isp-inputs-and-assumptions-workbook.xlsx / Network Capability / B6:H21" begin
            df = ParseISP.read_xlsx_with_header(paths.ispdata24, "Network Capability", "B6:H21")
            @test names(df) == ["Flow paths\n(Forward power flow direction)",
                                 "Forward direction capability approximation (MW) - Notes 1,2&3",
                                 "missing", "missing_1",
                                 "Reverse direction capability approximation (MW) - Notes 1,2&3",
                                 "missing_2", "missing_3"]
            @test size(df) == (15, 7)
            @test collect(df[end, :]) == Any["TAS – VIC (Note 12)", 594, 594, 594, 478, 478, 478]
        end

        @testset "legacy_min_up_time — 2019-input-and-assumptions-workbook-v1-3-dec-19.xlsx / Generation limits / O9:Q69" begin
            df = ParseISP.read_xlsx_with_header(paths.ispdata19, "Generation limits", "O9:Q69")
            @test names(df) == ["Generator Station", "Generating unit", "Min Up Time (hours)"]
            @test size(df) == (60, 3)
            @test collect(df[1, :]) == Any["Bayswater", "BW01", 8]
            @test collect(df[end, :]) == Any["Tamar Valley Combined Cycle", "TVCC201", 6]
        end

        @testset "core_capacity_outlook — Core/2024 ISP - Step Change - Core.xlsx / Capacity / A3:AG5000" begin
            file = joinpath(paths.outlookdata, "2024 ISP - Step Change - Core.xlsx")
            df = ParseISP.read_xlsx_with_header(file, "Capacity", "A3:AG5000")
            @test size(df) == (4997, 33)
            @test names(df)[1:8] ==
                  ["CDP", "Region", "Subregion", "Technology", "2023-24", "2024-25", "2025-26", "2026-27"]
            # Match `build_capacity_outlook_aux`, which removes rows without any numeric
            # values before combining the scenarios.
            filtered = filter(row -> any(x -> x isa Number && !ismissing(x), row), df)
            @test size(filtered) == (4290, 33)
            @test collect(filtered[1, 1:8]) == Any["CDP1", "NSW", "NNSW", "Black coal", 0, 0, 0, 0]
            @test collect(filtered[end, 1:8]) ==
                  Any["Counterfactual", "TAS", "TAS", "DSP", 5.95, 8.19, 10.4, 12.81]
        end

        @testset "demand_trace — Traces/demand_CNSW_Step Change/CNSW_RefYear_2011_STEP_CHANGE_POE10_OPSO_MODELLING_PVLITE.csv" begin
            file = joinpath(paths.profiledata, "demand_CNSW_Step Change",
                             "CNSW_RefYear_2011_STEP_CHANGE_POE10_OPSO_MODELLING_PVLITE.csv")
            df = CSV.File(file) |> DataFrame
            @test size(df) == (11323, 51)
            @test names(df)[1:8] == ["Year", "Month", "Day", "01", "02", "03", "04", "05"]
            @test collect(df[1, 1:3]) == Real[2023, 7, 1]
            @test collect(df[end, 1:3]) == Real[2054, 6, 30]
        end

        @testset "hydro_inflow_trace — 2024 ISP Model/2024 ISP Step Change/Traces/hydro/MonthlyNaturalInflow_Tarraleah_RefYear4006_StepChange.csv" begin
            file = joinpath(paths.ispmodel, "2024 ISP Step Change", "Traces", "hydro",
                             "MonthlyNaturalInflow_Tarraleah_RefYear4006_StepChange.csv")
            df = CSV.read(file, DataFrame)
            @test names(df) == ["Year", "Month", "Day", "Inflows"]
            @test size(df) == (10592, 4)
            @test collect(df[1, :]) == Real[2024, 7, 1, 32.1619225771939]
            @test collect(df[end, :]) == Real[2053, 6, 30, 22.275636810599]
        end
    end
end

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

@testset "source specs: ISP 2024 registry snapshot" begin
    specs_2024 = ParseISP.source_specs(2024)
    records_2024 = ParseISP.source_spec_records(2024)
    canonical_records_2024 = _source_spec_snapshot_value(records_2024)

    @test getfield.(specs_2024, :id) == EXPECTED_ISP2024_SOURCE_SPEC_IDS
    @test _source_spec_snapshot_digest(canonical_records_2024) ==
          EXPECTED_ISP2024_SOURCE_SPEC_FNV1A64
end
