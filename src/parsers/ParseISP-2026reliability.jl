"""Source-faithful ISP 2026 reliability, operation, and retirement readers."""

function _isp2026_reliability_header(value)
    ismissing(value) && return ""
    return strip(replace(string(value), r"\s+" => " "))
end

function _read_isp2026_reliability_table(
    path::AbstractString,
    spec::XlsxSourceSpec;
    header_rows::Integer = 1,
    first_source_row::Integer,
)
    isfile(path) || throw(ArgumentError("Source $(spec.id) workbook not found: $(path)."))
    raw = read_xlsx_rows(path, spec)
    size(raw, 2) == length(spec.columns) || throw(ArgumentError(
        "Source $(spec.id) returned $(size(raw, 2)) columns; expected $(length(spec.columns)).",
    ))
    if spec.id === :coal_minimum_stable_level
        parent_header = _isp2026_reliability_header(raw[1, 4])
        parent_header == "Minimum Stable Level (MW)" || throw(ArgumentError(
            "Source $(spec.id) expected parent header `Minimum Stable Level (MW)`, " *
            "observed `$(parent_header)`.",
        ))
    end

    names = getfield.(spec.columns, :name)
    for column in axes(raw, 2)
        observed = replace.([
            _isp2026_reliability_header(raw[row, column])
            for row in 1:header_rows
            if !isempty(_isp2026_reliability_header(raw[row, column]))
        ], r" \(\d+\)$" => "")
        expected = replace(_isp2026_reliability_header(names[column]), r" \(\d+\)$" => "")
        expected in observed || throw(ArgumentError(
            "Source $(spec.id) has an unexpected header in column $(column): " *
            "expected `$(names[column])`, observed $(observed).",
        ))
    end

    data_rows = (header_rows + 1):size(raw, 1)
    columns = Pair{Symbol,Any}[:source_row => collect(first_source_row:(first_source_row + length(data_rows) - 1))]
    for (column, name) in enumerate(names)
        push!(columns, Symbol(name) => Any[raw[row, column] for row in data_rows])
    end
    table = DataFrame(columns; makeunique = false)
    validate_source_columns(table, spec)
    return table
end

read_isp2026_generator_reliability_long_duration(path::AbstractString) =
    _read_isp2026_reliability_table(path, source_spec(:generator_reliability_long_duration, 2026); first_source_row = 11)

read_isp2026_generator_reliability_outage_rates(path::AbstractString) =
    _read_isp2026_reliability_table(path, source_spec(:generator_reliability_outage_rates, 2026); first_source_row = 23)

read_isp2026_generator_reliability_new_entrants(path::AbstractString) =
    _read_isp2026_reliability_table(path, source_spec(:generator_reliability_new_entrants, 2026); first_source_row = 64)

read_isp2026_generator_retirement(path::AbstractString) =
    _read_isp2026_reliability_table(path, source_spec(:generator_retirement, 2026); first_source_row = 13)

read_isp2026_coal_minimum_stable_level(path::AbstractString) =
    _read_isp2026_reliability_table(path, source_spec(:coal_minimum_stable_level, 2026); header_rows = 2, first_source_row = 14)

read_isp2026_gpg_minimum_stable_level(path::AbstractString) =
    _read_isp2026_reliability_table(path, source_spec(:gpg_minimum_stable_level, 2026); first_source_row = 12)

read_isp2026_new_gpg_minimum_stable_level(path::AbstractString) =
    _read_isp2026_reliability_table(path, source_spec(:new_gpg_minimum_stable_level, 2026); first_source_row = 12)

read_isp2026_generator_max_ramp_rates(path::AbstractString) =
    _read_isp2026_reliability_table(path, source_spec(:generator_max_ramp_rates, 2026); first_source_row = 9)

read_isp2026_new_generator_max_ramp_rates(path::AbstractString) =
    _read_isp2026_reliability_table(path, source_spec(:new_generator_max_ramp_rates, 2026); first_source_row = 9)
