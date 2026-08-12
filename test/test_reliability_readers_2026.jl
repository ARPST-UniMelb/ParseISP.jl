using XLSX
using Test

function _write_reliability_rows!(sheet, start_row, start_column, rows)
    for (row_offset, row) in enumerate(rows), (column_offset, value) in enumerate(row)
        sheet[start_row + row_offset - 1, start_column + column_offset - 1] =
            value === nothing ? missing : value
    end
end

@testset "ISP 2026 reliability and operation readers" begin
    mktempdir() do directory
        workbook = joinpath(directory, "inputs.xlsm")
        XLSX.openxlsx(workbook, mode = "w") do file
            sheet = XLSX.addsheet!(file, "Generator Reliability Settings")
            reliability_years = [
                "$(year)-$(lpad(string(mod(year + 1, 100)), 2, '0'))"
                for year in 2025:2034
            ]
            reliability_header = ["Fuel type", "Property", reliability_years...]
            _write_reliability_rows!(sheet, 10, 2, Any[
                reliability_header,
                Any["Coal", "Long duration outage", 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
            ])
            _write_reliability_rows!(sheet, 22, 2, Any[
                reliability_header,
                Any["Gas", "Unplanned outage rate", "-", 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 0.2],
            ])
            _write_reliability_rows!(sheet, 63, 2, Any[
                Any[
                    "Fuel type", "Full outage (% of time)", "Partial outage (% of time)",
                    "Full outage MTTR (hrs)", "Partial outage MTTR (hrs)",
                    "Partial Outage Derating Factor (%)", "notes",
                ],
                Any["CCGT", 0.1, 0.2, 12, 8, 0.5, "fixture"],
            ])

            sheet = XLSX.addsheet!(file, "Retirement")
            _write_reliability_rows!(sheet, 12, 2, Any[
                Any["IASR ID", "Power Station", "Technology Type", "Status", "Expected Closure Year (Calendar year)"],
                Any["GEN-1", "Example station", "CCGT", "Existing", 2045],
            ])

            sheet = XLSX.addsheet!(file, "Coal Min Stable Level")
            _write_reliability_rows!(sheet, 12, 2, Any[
                Any["IASR ID", "Power Station", "Technology Type", "Minimum Stable Level (MW)", missing, missing],
                Any[missing, missing, missing, "IASR 2023 (Backcasting)", "Typical Lowest Band", "Minimum Continuous Operating Level"],
                Any["GEN-1", "Example station", "Steam Sub Critical", 200, 180, 170],
            ])

            sheet = XLSX.addsheet!(file, "GPG Min Stable Level")
            _write_reliability_rows!(sheet, 11, 2, Any[
                Any["IASR ID", "Power Station", "Technology Type", "Min Stable Level (MW)"],
                Any["GEN-1", "Example station", "CCGT", 120],
            ])
            _write_reliability_rows!(sheet, 11, 7, Any[
                Any["Technology", "Min Stable Level (% of nameplate)"],
                Any["OCGT", 0.5],
            ])

            sheet = XLSX.addsheet!(file, "Max Ramp Rates")
            _write_reliability_rows!(sheet, 8, 2, Any[
                Any["IASR ID", "Power Station", "Technology Type", "Max Ramp Up\n(MW/min)", "Max Ramp Down\n(MW/min)"],
                Any["GEN-1", "Example station", "CCGT", "Assumed sufficiently high", "Assumed sufficiently high"],
            ])
            _write_reliability_rows!(sheet, 8, 8, Any[
                Any["Technology", "Max Ramp Up (MW/min)", "Max Ramp Down (MW/min)"],
                Any["OCGT", 10, 8],
            ])
        end

        long_duration = ParseISP.read_isp2026_generator_reliability_long_duration(workbook)
        @test long_duration.source_row[1] == 11
        @test long_duration[1, Symbol("2025-26")] == 0.1

        outage_rates = ParseISP.read_isp2026_generator_reliability_outage_rates(workbook)
        @test outage_rates.source_row[1] == 23
        @test outage_rates[1, Symbol("2025-26")] == "-"

        new_reliability = ParseISP.read_isp2026_generator_reliability_new_entrants(workbook)
        @test new_reliability.source_row[1] == 64
        @test new_reliability[1, Symbol("Partial outage (% of time)")] == 0.2

        retirement = ParseISP.read_isp2026_generator_retirement(workbook)
        @test retirement.source_row[1] == 13
        @test retirement[1, Symbol("Expected Closure Year (Calendar year)")] == 2045

        coal = ParseISP.read_isp2026_coal_minimum_stable_level(workbook)
        @test coal.source_row[1] == 14
        @test coal[1, Symbol("Minimum Continuous Operating Level")] == 170

        gpg = ParseISP.read_isp2026_gpg_minimum_stable_level(workbook)
        @test gpg.source_row[1] == 12
        @test gpg[1, Symbol("Min Stable Level (MW)")] == 120

        new_gpg = ParseISP.read_isp2026_new_gpg_minimum_stable_level(workbook)
        @test new_gpg.source_row[1] == 12
        @test new_gpg[1, Symbol("Min Stable Level (% of nameplate)")] == 0.5

        ramp = ParseISP.read_isp2026_generator_max_ramp_rates(workbook)
        @test ramp.source_row[1] == 9
        @test ramp[1, Symbol("Max Ramp Up (MW/min)")] == "Assumed sufficiently high"

        new_ramp = ParseISP.read_isp2026_new_generator_max_ramp_rates(workbook)
        @test new_ramp.source_row[1] == 9
        @test new_ramp[1, Symbol("Max Ramp Down (MW/min)")] == 8
    end
end
