using ParseISP
using Test

financial_years(first_year, last_year) = [
    "$(year)-$(lpad(string(mod(year + 1, 100)), 2, '0'))"
    for year in first_year:last_year
]

const EXPECTED_ISP2026_XLSX_SPECS = [
    (
        id = :core_capacity_outlook,
        workbook = "Core scenarios/2026 ISP - {scenario} - Core.xlsx",
        worksheet = "Capacity",
        cell_range = "A3:AC7737",
        source_family = :generation_outlook,
        columns = ["CDP", "Region", "Subregion", "Technology", financial_years(2025, 2049)...],
    ),
    (
        id = :core_storage_capacity_outlook,
        workbook = "Core scenarios/2026 ISP - {scenario} - Core.xlsx",
        worksheet = "Storage Capacity",
        cell_range = "A3:AB3432",
        source_family = :storage_outlook,
        columns = ["CDP", "Region", "Subregion", "storage category", financial_years(2026, 2049)...],
    ),
    (
        id = :core_storage_energy_outlook,
        workbook = "Core scenarios/2026 ISP - {scenario} - Core.xlsx",
        worksheet = "Storage Energy",
        cell_range = "A3:AB3420",
        source_family = :storage_outlook,
        columns = ["CDP", "Region", "Subregion", "Technology", financial_years(2026, 2049)...],
    ),
    (
        id = :core_rez_generation_capacity,
        workbook = "Core scenarios/2026 ISP - {scenario} - Core.xlsx",
        worksheet = "REZ Generation Capacity",
        cell_range = "A3:AC8787",
        source_family = :generation_outlook,
        columns = ["CDP", "Region", "REZ", "REZ Name", "Technology", financial_years(2026, 2049)...],
    ),
    (
        id = :transmission_reliability,
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Transmission Reliability",
        cell_range = "B7:E13",
        source_family = :network,
        columns = ["Line/Flowpath", "Implementation", "Unplanned Outage Rate (%)", "Mean Time to Repair"],
    ),
    (
        id = :network_capability,
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Network capability",
        cell_range = "B8:K25",
        source_family = :network,
        columns = ["Flow path", "Forward peak (MW)", "Forward summer (MW)", "Forward winter (MW)",
                   "Reverse peak (MW)", "Reverse summer (MW)", "Reverse winter (MW)",
                   "Forward constraint", "Reverse constraint", "Notes"],
    ),
    (
        id = :flow_path_augmentation_options,
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Flow path augmentation options",
        cell_range = "B11:Q127",
        source_family = :network,
        columns = [
            "Flow path", "Development path", "Development driver", "Option name",
            "Augmentation description", "Pre-requisite options", "Power-flow direction",
            "Forward increase (MW)", "Reverse increase (MW)",
            "Indicative cost estimate (\$2025 million)", "Cost estimate source",
            "Cost estimate class", "Easement length (km)",
            "Lead time or earliest in service date",
            "Additional REZ transmission capacity provided", "Notes",
        ],
    ),
    (
        id = :renewable_energy_zones,
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Renewable energy zones",
        cell_range = "B6:E53",
        source_family = :renewable_energy_zones,
        columns = ["ID", "Name", "NEM region", "ISP sub-region"],
    ),
    (
        id = :hybrid_site_limits,
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Hybrid site limits",
        cell_range = "B9:G67",
        source_family = :generation_constraints,
        columns = ["IASR ID", "Status", "Technology", "Region", "Site Name", "Connection Capacity (MW)"],
    ),
    (
        id = :dsp_assumptions,
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "DSP",
        cell_range = "B9:AI164",
        source_family = :demand_side_participation,
        columns = ["Region", "Price band", "Scenario", "Season", financial_years(2025, 2054)...],
    ),
]

const EXPECTED_ISP2026_CSV_SPECS = [
    (:operational_demand_trace, "2026 ISP Model/2026 ISP {scenario}/Traces/demand/*.csv", :demand_traces, false),
    (:distributed_pv_demand_trace, "2026 ISP Model/2026 ISP {scenario}/Traces/rooftop PV/*.csv", :demand_traces, false),
    (:dnsp_cer_trace, "2026 ISP Model/2026 ISP {scenario}/Traces/dnsp/*.csv", :dnsp_traces, false),
    (:gas_limit_trace, "2026 ISP Model/2026 ISP {scenario}/Traces/gas/*.csv", :gas_traces, true),
    (:load_subtractor_trace, "2026 ISP Model/2026 ISP {scenario}/Traces/load_subtractor/*.csv", :load_subtractor_traces, false),
    (:solar_availability_traces, "Traces/2026 ISP Solar traces/solar/*.csv", :solar_traces, false),
    (:wind_availability_traces, "Traces/2026 ISP Wind traces/wind/*.csv", :wind_traces, false),
]

@testset "source specs: ISP 2026 definitions" begin
    specs = ParseISP.source_specs(2026)
    expected_ids = sort!(
        [
            getfield.(EXPECTED_ISP2026_XLSX_SPECS, :id)...,
            first.(EXPECTED_ISP2026_CSV_SPECS)...,
        ];
        by = string,
    )
    @test getfield.(specs, :id) == expected_ids
    for expected in EXPECTED_ISP2026_XLSX_SPECS
        spec = ParseISP.source_spec(expected.id, 2026)
        @test spec isa ParseISP.XlsxSourceSpec
        @test (
            spec.workbook,
            spec.worksheet,
            spec.cell_range,
            spec.source_family,
            getfield.(spec.columns, :name),
        ) == (
            expected.workbook,
            expected.worksheet,
            expected.cell_range,
            expected.source_family,
            expected.columns,
        )
    end

    expected_trace_columns = [
        "Year", "Month", "Day", lpad.(string.(1:48), 2, '0')...,
    ]
    for (id, filename_pattern, source_family, is_gas) in EXPECTED_ISP2026_CSV_SPECS
        spec = ParseISP.source_spec(id, 2026)
        @test spec isa ParseISP.CsvSourceSpec
        @test (spec.filename_pattern, spec.source_family, spec.keys) == (
            filename_pattern,
            source_family,
            ["Year", "Month", "Day"],
        )
        @test getfield.(spec.columns, :name) ==
              (is_gas ? ["Year", "Month", "Day", "Value"] : expected_trace_columns)
    end

    root = normpath("temporary", "isp2026-root")
    @test ParseISP.source_path(
        root,
        ParseISP.source_spec(:core_capacity_outlook, 2026);
        scenario = "Step Change",
    ) == normpath(root, "Core scenarios", "2026 ISP - Step Change - Core.xlsx")
    @test ParseISP.source_path(
        root,
        ParseISP.source_spec(:operational_demand_trace, 2026);
        scenario = "Step Change",
    ) == normpath(
        root,
        "2026 ISP Model",
        "2026 ISP Step Change",
        "Traces",
        "demand",
        "*.csv",
    )
end
