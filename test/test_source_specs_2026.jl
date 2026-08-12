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
        id = :existing_generator_summary,
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Existing Gen Data Summary",
        cell_range = "B10:AT738",
        source_family = :generation,
        columns = [
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
        ],
    ),
    (
        id = :generator_emissions_intensity,
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Emissions intensity",
        cell_range = "B8:E734",
        source_family = :generation,
        columns = ["IASR ID", "Power Station", "Technology", "Scope 1 emissions intensity (kg/MWh as-gen)"],
    ),
    (
        id = :new_entrant_emissions_intensity,
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Emissions intensity",
        cell_range = "G8:H29",
        source_family = :generation,
        columns = ["Technology", "Scope 1 emissions intensity (kg/MWh as-gen)"],
    ),
    (
        id = :generator_maximum_capacity,
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Maximum capacity",
        cell_range = "B10:J736",
        source_family = :generation,
        columns = ["IASR ID", "Power Station", "Status5", "Technology", "Region",
                   "Installed capacity (MW)", "Storage Capacity (MWh)", "Commissioning date", "Policy"],
    ),
    (
        id = :new_entrant_maximum_capacity,
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Maximum capacity",
        cell_range = "L10:O31",
        source_family = :generation,
        columns = ["Technology Type", "Unit size (MW)", "Number of units", "Total plant size (MW)"],
    ),
    (
        id = :generator_summary_mapping,
        workbook = "2026-isp-inputs-and-assumptions-workbook.xlsm",
        worksheet = "Summary Mapping",
        cell_range = "B4:AF1381",
        source_family = :generation,
        columns = [
            "RowID", "IASR ID / DLT names", "Power Station", "Technology Type", "Region",
            "Sub-region", "REZ Location", "REZ ID", "Status", "Regional build cost zone",
            "Uptake", "Fuel type", "Fuel cost mapping", "Maintenance duration (%)",
            "Forced outage rate", "Partial outage (% of time)", "Mean time to repair",
            "Partial outage", "Minimum load (MW)", "Maximum capacity factor (%)",
            "FOM (\$/kW/annum)", "VOM (\$/MWh sent-out)", "Heat rate", "Pumping efficiency (%)",
            "MLF", "Auxiliary load (%)", "Connection cost", "Region (2)", "Build limit", "Region (3)",
            "Total lead time",
        ],
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

const EXPECTED_ISP2026_RELIABILITY_SPECS = [
    (:generator_reliability_long_duration, "Generator Reliability Settings", "B10:M16"),
    (:generator_reliability_outage_rates, "Generator Reliability Settings", "B22:M57"),
    (:generator_reliability_new_entrants, "Generator Reliability Settings", "B63:H84"),
    (:generator_retirement, "Retirement", "B12:F738"),
    (:coal_minimum_stable_level, "Coal Min Stable Level", "B12:G57"),
    (:gpg_minimum_stable_level, "GPG Min Stable Level", "B11:E150"),
    (:new_gpg_minimum_stable_level, "GPG Min Stable Level", "G11:H32"),
    (:generator_max_ramp_rates, "Max Ramp Rates", "B8:F191"),
    (:new_generator_max_ramp_rates, "Max Ramp Rates", "H8:J29"),
]

@testset "source specs: ISP 2026 definitions" begin
    specs = ParseISP.source_specs(2026)
    expected_ids = sort!(
        [
            getfield.(EXPECTED_ISP2026_XLSX_SPECS, :id)...,
            first.(EXPECTED_ISP2026_CSV_SPECS)...,
            first.(EXPECTED_ISP2026_RELIABILITY_SPECS)...,
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

    new_capacity = ParseISP.source_spec(:new_entrant_maximum_capacity, 2026)
    @test [
        (column.name, column.data_type, column.unit)
        for column in new_capacity.columns
    ] == [
        ("Technology Type", nothing, nothing),
        ("Unit size (MW)", :Real, "MW"),
        ("Number of units", :Integer, nothing),
        ("Total plant size (MW)", :Real, "MW"),
    ]

    existing = ParseISP.source_spec(:existing_generator_summary, 2026)
    existing_descriptions = Dict(column.name => column.description for column in existing.columns)
    @test existing_descriptions["Summer peak rating (MW)"] == "Workbook row 12: `2025-26`"
    @test existing_descriptions["Fuel cost (\$/GJ)"] ==
          "Workbook row 11: `Step Change`; Workbook row 12: `2025-26`"
    @test existing_descriptions["Scope 1 Emissions (kg/MWh)"] ==
          "Workbook row 11: `Accelerated Transition`; Workbook row 12: `2025-26`"

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

@testset "source specs: ISP 2026 reliability boundaries" begin
    for (id, worksheet, cell_range) in EXPECTED_ISP2026_RELIABILITY_SPECS
        spec = ParseISP.source_spec(id, 2026)
        @test spec isa ParseISP.XlsxSourceSpec
        @test (spec.worksheet, spec.cell_range, spec.source_family) ==
              (worksheet, cell_range, id in (:generator_retirement,) ? :generation_retirement :
               id in (:coal_minimum_stable_level, :gpg_minimum_stable_level, :new_gpg_minimum_stable_level,
                      :generator_max_ramp_rates, :new_generator_max_ramp_rates) ? :generation_operation :
               :generation_reliability)
    end
end
