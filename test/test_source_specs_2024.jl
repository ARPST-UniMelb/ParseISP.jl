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
