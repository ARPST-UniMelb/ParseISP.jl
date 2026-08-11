using XLSX
using Test

function write_network_sheet!(workbook, name, start_row, start_column, rows)
    sheet = XLSX.addsheet!(workbook, name)
    for (row_offset, row) in enumerate(rows), (column_offset, value) in enumerate(row)
        sheet[start_row + row_offset - 1, start_column + column_offset - 1] =
            value === nothing ? missing : value
    end
end

function write_network_workbook(path; missing_reliability_header = false)
    capability_rows = Any[
        Any[
            "CQ-NQ", 1200, 1200, 1400, 800, 800, 800,
            "Forward constraint", "Reverse constraint", "Capability note",
        ],
        Any[
            "Unknown corridor", 1, 2, 3, 4, 5, 6,
            "Unknown forward constraint", "Unknown reverse constraint", nothing,
        ],
    ]
    append!(capability_rows, [
        Any[
            "Path $(row)", row, row, row, row, row, row,
            "Forward constraint $(row)", "Reverse constraint $(row)",
            iseven(row) ? nothing : "Note $(row)",
        ]
        for row in 3:18
    ])

    reliability_header = [
        "Line/Flowpath", "Implementation", "Unplanned Outage Rate (%)",
        "Mean Time to Repair",
    ]
    missing_reliability_header && (reliability_header[3] = "Outage")
    reliability_rows = Any[
        reliability_header,
        Any["QNI Credible Contingency", "Static annual unplanned outage rate", 0.00287, 21.1],
        Any["QNI Reclassification", "Static annual unplanned outage rate", 0.01761, 3.9],
        Any["Murraylink Credible Contingency", "Static annual unplanned outage rate", 0.0132, 65.3],
        Any["Basslink Credible Contingency", "Static annual unplanned outage rate", 0.04527, 189.5],
        Any["VSA Credible Contingency", "Annual, set to 0% post PEC stage 2", 0.00028, 2.2],
        Any["VSA Reclassification", "Annual, set to 0% post PEC stage 2", 0.00009, 4.7],
    ]

    option_header = Any[
        "Flow path", "Development path", "Development driver", "Option name",
        "Augmentation description", "Pre-requisite options", "Forward direction power flow",
        "Notional transfer level increase (MW)", nothing,
        "Indicative cost estimate  (\$2025, \$ million)", "Cost estimate source",
        "Cost estimate class", "Easement length (km)",
        "Lead time or earliest in service date",
        "Additional REZ transmission capacity provided", "Notes",
    ]
    option_rows = Any[
        Any["Central Queensland (CQ) to North Queensland (NQ)", fill(nothing, 15)...],
        option_header,
        Any[fill(nothing, 7)..., "Forward direction", "Reverse direction",
            fill(nothing, 7)...],
        Any[
            "CQ-NQ", "South of CQ-NQ path", "Increase stability limits in NQ",
            "CQ-NQ Option 3", "String the second circuit", nothing, "CQ to NQ",
            350, 500, 208.948, "AEMO TCD", "Class 5b(±50%)", 0,
            "Short: (4 years)", "CQ1: 600", nothing,
        ],
        Any[
            nothing, "CQ-NQ path", "Increase stability limits in NQ", "CQ-NQ Option 4",
            "Build a new double-circuit line", "CQ-NQ Option 3", nothing,
            500, 1000, 1850.16, "Powerlink", "Class 5b(±50%)", 307,
            "Long: (7 years)", "CQ1: 1,600", "Option note",
        ],
    ]
    append!(option_rows, [Any[fill(nothing, 16)...] for _ in 1:(116 - length(option_rows))])
    push!(option_rows, Any[
        "ZZ-ZZ", "Unknown path", "Unknown driver", "ZZ self-loop",
        "Unknown augmentation", nothing, "ZZ to ZZ", 2, 3, 4,
        "Unknown source", "Unknown class", 1, "1 year", "ZZ1: 5", nothing,
    ])

    XLSX.openxlsx(path, mode = "w") do workbook
        write_network_sheet!(workbook, "Network capability", 8, 2, capability_rows)
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
        @test size(capability) == (18, 11)
        @test capability.source_row == collect(8:25)
        @test capability[!, Symbol("Flow path")][1:2] == ["CQ-NQ", "Unknown corridor"]
        @test capability[1, Symbol("Forward constraint")] == "Forward constraint"
        @test capability[1, Symbol("Reverse constraint")] == "Reverse constraint"
        @test ismissing(capability[2, :Notes])

        reliability = ParseISP.read_isp2026_transmission_reliability(workbook)
        @test size(reliability) == (6, 5)
        @test reliability.source_row == collect(8:13)
        @test reliability[1, Symbol("Line/Flowpath")] == "QNI Credible Contingency"
        @test reliability[2, Symbol("Unplanned Outage Rate (%)")] == 0.01761

        options = ParseISP.read_isp2026_flow_path_augmentation_options(workbook)
        @test size(options) == (3, 17)
        @test options.source_row == [14, 15, 127]
        @test options[2, Symbol("Flow path")] == "CQ-NQ"
        @test ismissing(options[2, Symbol("Power-flow direction")])
        @test options[1, Symbol("Development driver")] == "Increase stability limits in NQ"
        @test options[2, Symbol("Pre-requisite options")] == "CQ-NQ Option 3"
        @test options[2, Symbol("Cost estimate source")] == "Powerlink"
        @test options[2, Symbol("Cost estimate class")] == "Class 5b(±50%)"
        @test options[2, Symbol("Additional REZ transmission capacity provided")] == "CQ1: 1,600"
        @test options[2, :Notes] == "Option note"
        @test options[end, Symbol("Option name")] == "ZZ self-loop"
        @test options[end, Symbol("Power-flow direction")] == "ZZ to ZZ"
    end

    mktempdir() do directory
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
