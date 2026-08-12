"""Source-faithful readers for the ISP 2026 generation inventory tables."""

function _isp2026_generation_header(value)
    ismissing(value) && return ""
    return strip(replace(string(value), r"\s+" => " "))
end

function _isp2026_generation_rows(raw, names, header_rows, source_id, first_source_row)
    size(raw, 2) == length(names) || throw(ArgumentError(
        "Source $(source_id) returned $(size(raw, 2)) columns; expected $(length(names)).",
    ))

    expected = replace.(_isp2026_generation_header.(names), r" \(\d+\)$" => "")
    for column in axes(raw, 2)
        observed = replace.([
            _isp2026_generation_header(raw[row, column])
            for row in 1:header_rows
            if !isempty(_isp2026_generation_header(raw[row, column]))
        ], r" \(\d+\)$" => "")
        expected[column] in observed || throw(ArgumentError(
            "Source $(source_id) has an unexpected header in column $(column): " *
            "expected `$(names[column])`, observed $(observed).",
        ))
    end

    data_rows = (header_rows + 1):size(raw, 1)
    columns = Pair{Symbol,Any}[:source_row => collect(first_source_row:(first_source_row + length(data_rows) - 1))]
    for (column, name) in enumerate(names)
        push!(columns, Symbol(name) => Any[raw[row, column] for row in data_rows])
    end
    return DataFrame(columns; makeunique = false)
end

function _validate_isp2026_generation_types(table, spec::XlsxSourceSpec)
    for column in spec.columns
        column.data_type === nothing && continue
        values = table[!, Symbol(column.name)]
        for (index, value) in enumerate(values)
            value === missing && continue
            valid = column.data_type == :Real ? value isa Number :
                column.data_type == :Integer ? value isa Integer : true
            valid || throw(ArgumentError(
                "Source $(spec.id) has invalid $(column.data_type) value for `$(column.name)` " *
                "at source row $(table.source_row[index]): $(repr(value)).",
            ))
        end
    end
    return table
end

function _read_isp2026_generation_table(path::AbstractString, spec::XlsxSourceSpec;
        header_rows::Integer = 1, first_source_row::Integer)
    isfile(path) || throw(ArgumentError("Source $(spec.id) workbook not found: $(path)."))
    raw = read_xlsx_rows(path, spec)
    table = _isp2026_generation_rows(
        raw,
        getfield.(spec.columns, :name),
        header_rows,
        spec.id,
        first_source_row,
    )
    validate_source_columns(table, spec)
    return _validate_isp2026_generation_types(table, spec)
end

"""Read `Existing Gen Data Summary!B10:AT738`, including its three header layers."""
function read_isp2026_existing_generator_summary(path::AbstractString)
    return _read_isp2026_generation_table(
        path,
        source_spec(:existing_generator_summary, 2026);
        header_rows = 3,
        first_source_row = 13,
    )
end

const read_isp2026_existing_generation = read_isp2026_existing_generator_summary

"""Read existing/committed/anticipated/additional generator emissions."""
function read_isp2026_generator_emissions_intensity(path::AbstractString)
    return _read_isp2026_generation_table(
        path,
        source_spec(:generator_emissions_intensity, 2026);
        first_source_row = 9,
    )
end

"""Read the separate ISP 2026 new-entrant technology emissions table."""
function read_isp2026_new_entrant_emissions_intensity(path::AbstractString)
    return _read_isp2026_generation_table(
        path,
        source_spec(:new_entrant_emissions_intensity, 2026);
        first_source_row = 9,
    )
end

"""Read existing/committed/anticipated/additional generator maximum capacity."""
function read_isp2026_generator_maximum_capacity(path::AbstractString)
    return _read_isp2026_generation_table(
        path,
        source_spec(:generator_maximum_capacity, 2026);
        first_source_row = 11,
    )
end

"""Read the separate ISP 2026 new-generation-technology capacity table."""
function read_isp2026_new_entrant_maximum_capacity(path::AbstractString)
    return _read_isp2026_generation_table(
        path,
        source_spec(:new_entrant_maximum_capacity, 2026);
        first_source_row = 11,
    )
end

"""Read `Summary Mapping!B4:AF1381`, retaining blank source rows."""
function read_isp2026_generator_summary_mapping(path::AbstractString)
    return _read_isp2026_generation_table(
        path,
        source_spec(:generator_summary_mapping, 2026);
        header_rows = 3,
        first_source_row = 7,
    )
end

const read_isp2026_summary_mapping = read_isp2026_generator_summary_mapping
