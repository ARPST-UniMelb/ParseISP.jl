using XLSX
using Test

function write_network_sheet!(workbook, name, start_row, start_column, rows)
    sheet = XLSX.addsheet!(workbook, name)
    for (row_offset, row) in enumerate(rows), (column_offset, value) in enumerate(row)
        sheet[start_row + row_offset - 1, start_column + column_offset - 1] =
            value === nothing ? missing : value
    end
end

function write_network_workbook(path; duplicate_network = false,
        missing_reliability_header = false)
    capability_rows = Any[
        Any["Flow Paths", "Forward direction capability approximation (MW)", nothing,
            nothing, "Reverse direction capability approximation (MW)", nothing, nothing],
        Any[nothing, "Peak demand", "Summer typical", "Winter refernce", "Peak demand",
            "Summer typical", "Winter refernce"],
        Any["CQ-NQ", 1200, 1200, 1400, 800, 800, 800],
        Any["Unknown corridor", 1, 2, 3, 4, 5, 6],
        Any["Additional table notes:", nothing, nothing, nothing, nothing, nothing, nothing],
    ]
    duplicate_network && insert!(
        capability_rows,
        5,
        Any["CQ-NQ", 10, 10, 10, 10, 10, 10],
    )

    reliability_header = [
        "Line/Flowpath", "Implementation", "Unplanned Outage Rate (%)",
        "Mean Time to Repair",
    ]
    missing_reliability_header && (reliability_header[3] = "Outage")
    reliability_rows = Any[
        reliability_header,
        Any["QNI Credible Contingency", "Static annual unplanned outage rate", 0.00287, 21.1],
        Any["QNI Reclassification", "Static annual unplanned outage rate", 0.01761, 3.9],
    ]

    option_header = Any[
        "Flow path", "Development path", "Development driver", "Option name",
        "Augmentation description", "Pre-requisite options", "Forward direction power flow",
        "Notional transfer level increase (MW)", nothing,
        "Indicative cost estimate  (\$2025, \$ million)", "Cost estimate source",
        "Cost estimate class", "Easement length (km)",
        "Lead time or earliest in service date",
    ]
    option_rows = Any[
        Any["Central Queensland (CQ) to North Queensland (NQ)", fill(nothing, 13)...],
        option_header,
        Any[fill(nothing, 7)..., "Forward direction", "Reverse direction",
            fill(nothing, 5)...],
        Any["CQ-NQ", nothing, nothing, "CQ-NQ Option 3", nothing, nothing, "CQ to NQ",
            350, 500, 208.948, nothing, nothing, 0, "Short: (4 years)"],
        Any[nothing, nothing, nothing, "CQ-NQ Option 4", nothing, nothing, nothing,
            500, 1000, 1850.16, nothing, nothing, 307, "Long: (7 years)"],
    ]
    append!(option_rows, [Any[fill(nothing, 14)...] for _ in 1:(116 - length(option_rows))])
    push!(option_rows, Any[
        "ZZ-ZZ", nothing, nothing, "ZZ self-loop", nothing, nothing, "ZZ to ZZ",
        2, 3, 4, nothing, nothing, 1, "1 year",
    ])

    XLSX.openxlsx(path, mode = "w") do workbook
        write_network_sheet!(workbook, "Network capability", 6, 2, capability_rows)
        write_network_sheet!(workbook, "Transmission Reliability", 7, 2, reliability_rows)
        write_network_sheet!(workbook, "Flow path augmentation options", 11, 2, option_rows)
    end
    return path
end

function source_error(call)
    try
        call()
        return ""
    catch error
        return sprint(showerror, error)
    end
end

@testset "ISP 2026 network readers" begin
    mktempdir() do directory
        workbook = write_network_workbook(joinpath(directory, "inputs.xlsm"))

        capability = ParseISP.read_isp2026_network_capability(workbook)
        @test capability[!, Symbol("Flow path")] == ["CQ-NQ", "Unknown corridor"]
        @test capability.source_row == [8, 9]
        @test capability[2, Symbol("Forward peak (MW)")] == 1
        @test all(capability.source_range .== "B6:H30")

        reliability = ParseISP.read_isp2026_transmission_reliability(workbook)
        @test reliability.source_row == [8, 9]
        @test reliability[1, Symbol("Line/Flowpath")] == "QNI Credible Contingency"
        @test reliability[2, Symbol("Unplanned Outage Rate (%)")] == 0.01761

        options = ParseISP.read_isp2026_flow_path_augmentation_options(workbook)
        @test options.source_row == [14, 15, 127]
        @test options[2, Symbol("Flow path")] == "CQ-NQ"
        @test options[2, Symbol("Power-flow direction")] == "CQ to NQ"
        @test options[end, Symbol("Option")] == "ZZ self-loop"
        @test options[end, Symbol("Power-flow direction")] == "ZZ to ZZ"

    end

    mktempdir() do directory
        duplicate = write_network_workbook(
            joinpath(directory, "duplicate.xlsm");
            duplicate_network = true,
        )
        message = source_error(() -> ParseISP.read_isp2026_network_capability(duplicate))
        @test occursin("Network capability!B6:H30", message)
        @test occursin("source row 10", message)
        @test occursin("duplicate key", message)

        missing_header = write_network_workbook(
            joinpath(directory, "missing-header.xlsm");
            missing_reliability_header = true,
        )
        message = source_error(
            () -> ParseISP.read_isp2026_transmission_reliability(missing_header),
        )
        @test occursin("missing required columns", lowercase(message))
        @test occursin("Unplanned Outage Rate (%)", message)
    end
end
