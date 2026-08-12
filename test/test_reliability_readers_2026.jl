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

            sheet = XLSX.addsheet!(file, "Max Ramp Rates")
            _write_reliability_rows!(sheet, 8, 2, Any[
                Any["IASR ID", "Power Station", "Technology Type", "Max Ramp Up\n(MW/min)", "Max Ramp Down\n(MW/min)"],
                Any["GEN-1", "Example station", "CCGT", "Assumed sufficiently high", "Assumed sufficiently high"],
            ])
        end

        retirement = ParseISP.read_isp2026_generator_retirement(workbook)
        @test retirement.source_row == [13]
        @test retirement[1, Symbol("Expected Closure Year (Calendar year)")] == 2045

        coal = ParseISP.read_isp2026_coal_minimum_stable_level(workbook)
        @test coal[1, Symbol("Minimum Continuous Operating Level")] == 170

        ramp = ParseISP.read_isp2026_generator_max_ramp_rates(workbook)
        @test ramp[1, Symbol("Max Ramp Up (MW/min)")] == "Assumed sufficiently high"
    end
end
