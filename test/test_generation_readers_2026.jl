using XLSX
using Test

function _write_generation_rows!(sheet, start_row, start_column, rows)
    for (row_offset, row) in enumerate(rows), (column_offset, value) in enumerate(row)
        sheet[start_row + row_offset - 1, start_column + column_offset - 1] =
            value === nothing ? missing : value
    end
end

function _generation_rows(header_rows, nrows, ncols; first_values = Any[])
    rows = [Any[header_rows[row]...] for row in eachindex(header_rows)]
    for row in 1:nrows
        values = Any[missing for _ in 1:ncols]
        for (column, value) in enumerate(first_values)
            values[column] = value
        end
        values[1] === missing && (values[1] = row)
        push!(rows, values)
    end
    return rows
end

function _write_generation_workbook(path)
    existing = ParseISP._ISP2026_EXISTING_GENERATION_COLUMNS
    emissions = ParseISP._ISP2026_EMISSIONS_COLUMNS
    new_emissions = ParseISP._ISP2026_NEW_EMISSIONS_COLUMNS
    maximum = ParseISP._ISP2026_MAXIMUM_CAPACITY_COLUMNS
    new_maximum = ParseISP._ISP2026_NEW_MAXIMUM_CAPACITY_COLUMNS
    mapping = ParseISP._ISP2026_SUMMARY_MAPPING_COLUMNS

    XLSX.openxlsx(path, mode = "w") do workbook
        sheet = XLSX.addsheet!(workbook, "Existing Gen Data Summary")
        headers = [Any[existing...], Any[fill(missing, length(existing))...], Any[fill(missing, length(existing))...]]
        _write_generation_rows!(sheet, 10, 2, _generation_rows(headers, 726, length(existing); first_values = ["GEN-1", "Example station", "Solar"]))

        sheet = XLSX.addsheet!(workbook, "Emissions intensity")
        _write_generation_rows!(sheet, 8, 2, _generation_rows([Any[emissions...]], 726, length(emissions); first_values = ["GEN-1", "Example station", "Solar", 1.5]))
        _write_generation_rows!(sheet, 8, 7, _generation_rows([Any[new_emissions...]], 21, length(new_emissions); first_values = ["Solar", 1.5]))

        sheet = XLSX.addsheet!(workbook, "Maximum capacity")
        _write_generation_rows!(sheet, 10, 2, _generation_rows([Any[maximum...]], 726, length(maximum); first_values = ["GEN-1", "Example station", "Existing", "Solar", "NSW", 10]))
        _write_generation_rows!(sheet, 10, 12, _generation_rows([Any[new_maximum...]], 21, length(new_maximum); first_values = ["Solar", 10, 1, 10]))

        sheet = XLSX.addsheet!(workbook, "Summary Mapping")
        mapping_headers = [
            Any[mapping...],
            Any[fill(missing, length(mapping))...],
            Any[fill(missing, length(mapping))...],
        ]
        _write_generation_rows!(sheet, 4, 2, _generation_rows(mapping_headers, 1375, length(mapping); first_values = [7, "GEN-1", "Example station", "Solar"]))
    end
    return path
end

@testset "ISP 2026 generation inventory readers" begin
    mktempdir() do directory
        workbook = _write_generation_workbook(joinpath(directory, "inputs.xlsm"))

        existing = ParseISP.read_isp2026_existing_generator_summary(workbook)
        @test size(existing) == (726, 46)
        @test existing.source_row == collect(13:738)
        @test existing[1, Symbol("IASR ID")] == "GEN-1"
        @test existing[end, Symbol("Power Station")] == "Example station"

        emissions = ParseISP.read_isp2026_generator_emissions_intensity(workbook)
        @test size(emissions) == (726, 5)
        @test emissions[1, Symbol("Scope 1 emissions intensity (kg/MWh as-gen)")] == 1.5

        new_emissions = ParseISP.read_isp2026_new_entrant_emissions_intensity(workbook)
        @test size(new_emissions) == (21, 3)

        maximum = ParseISP.read_isp2026_generator_maximum_capacity(workbook)
        @test size(maximum) == (726, 10)
        @test maximum[1, Symbol("Installed capacity (MW)")] == 10

        new_maximum = ParseISP.read_isp2026_new_entrant_maximum_capacity(workbook)
        @test size(new_maximum) == (21, 5)
        @test new_maximum[1, Symbol("Total plant size (MW)")] == 10

        mapping = ParseISP.read_isp2026_generator_summary_mapping(workbook)
        @test size(mapping) == (1375, 32)
        @test mapping.source_row == collect(7:1381)
        @test mapping[1, Symbol("IASR ID / DLT names")] == "GEN-1"
    end
end
