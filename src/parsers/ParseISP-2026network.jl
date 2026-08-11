"""Source-faithful readers for the ISP 2026 network input tables."""

_isp2026_network_text(value) = ismissing(value) ? "" : strip(string(value))

function _isp2026_network_start_row(spec::XlsxSourceSpec)
    return parse(Int, match(r"\d+", spec.cell_range).match)
end

function _isp2026_network_provenance!(table, path, spec, source_rows)
    insertcols!(
        table,
        1,
        :source_id => fill(spec.id, length(source_rows)),
        :source_workbook => fill(String(path), length(source_rows)),
        :source_sheet => fill(spec.worksheet, length(source_rows)),
        :source_range => fill(spec.cell_range, length(source_rows)),
        :source_row => source_rows,
    )
    return table
end

function _isp2026_network_require_unique(table, columns, spec)
    seen = Dict{Tuple,Int}()
    for row in eachrow(table)
        key = Tuple(_isp2026_network_text(row[column]) for column in columns)
        if haskey(seen, key)
            throw(ArgumentError(
                "$(spec.worksheet)!$(spec.cell_range), source row $(row.source_row): " *
                "duplicate key $(key); first occurrence is source row $(seen[key])",
            ))
        end
        seen[key] = row.source_row
    end
    return table
end

"""Read the complete ISP 2026 network-capability table without mapping flow paths."""
function read_isp2026_network_capability(path::AbstractString)
    spec = source_spec(:network_capability, 2026)
    raw = read_xlsx_rows(path, spec)
    size(raw, 2) == 7 && _isp2026_network_text(raw[1, 1]) == "Flow Paths" ||
        throw(ArgumentError("Unexpected header in $(spec.worksheet)!$(spec.cell_range)."))

    rows = Int[]
    for row in 3:size(raw, 1)
        label = _isp2026_network_text(raw[row, 1])
        (isempty(label) || startswith(label, "Additional table notes:")) && break
        any(ismissing, raw[row, :]) && throw(ArgumentError(
            "$(spec.worksheet)!$(spec.cell_range), source row " *
            "$(_isp2026_network_start_row(spec) + row - 1): incomplete capability row.",
        ))
        push!(rows, row)
    end

    table = DataFrame(raw[rows, :], Symbol.(getfield.(spec.columns, :name)))
    source_rows = _isp2026_network_start_row(spec) .+ rows .- 1
    _isp2026_network_provenance!(table, path, spec, source_rows)
    return _isp2026_network_require_unique(table, [Symbol("Flow path")], spec)
end

"""Read every ISP 2026 transmission-reliability row without positional mapping."""
function read_isp2026_transmission_reliability(path::AbstractString)
    spec = source_spec(:transmission_reliability, 2026)
    table = read_xlsx_with_header(path, spec; validate_columns = true)
    source_rows = collect((_isp2026_network_start_row(spec) + 1):
                          (_isp2026_network_start_row(spec) + nrow(table)))
    _isp2026_network_provenance!(table, path, spec, source_rows)
    return _isp2026_network_require_unique(
        table,
        [Symbol("Line/Flowpath"), Symbol("Implementation")],
        spec,
    )
end

"""Read every semantic ISP 2026 flow-path option through source row 127.

Merged flow-path and direction labels are filled down. No bus mapping or option
disposition is applied; unsupported or unknown source labels remain visible for the
later output-contract decision.
"""
function read_isp2026_flow_path_augmentation_options(path::AbstractString)
    spec = source_spec(:flow_path_augmentation_options, 2026)
    raw = read_xlsx_rows(path, spec)
    any(_isp2026_network_text(raw[row, 4]) == "Option name" for row in axes(raw, 1)) ||
        throw(ArgumentError("Missing option header in $(spec.worksheet)!$(spec.cell_range)."))

    positions = [1, 4, 7, 8, 9, 10, 13, 14]
    table = DataFrame(Symbol(name) => Any[] for name in getfield.(spec.columns, :name))
    source_rows = Int[]
    current_flow_path = ""
    current_direction = ""
    start_row = _isp2026_network_start_row(spec)

    for row in axes(raw, 1)
        if all(ismissing, raw[row, :])
            current_flow_path = ""
            current_direction = ""
            continue
        end

        option = _isp2026_network_text(raw[row, 4])
        (isempty(option) || option == "Option name") && continue
        flow_path = _isp2026_network_text(raw[row, 1])
        direction = _isp2026_network_text(raw[row, 7])
        isempty(flow_path) || (current_flow_path = flow_path)
        isempty(direction) || (current_direction = direction)
        source_row = start_row + row - 1
        isempty(current_flow_path) && throw(ArgumentError(
            "$(spec.worksheet)!$(spec.cell_range), source row $(source_row): " *
            "option has no flow-path label.",
        ))
        isempty(current_direction) && throw(ArgumentError(
            "$(spec.worksheet)!$(spec.cell_range), source row $(source_row): " *
            "option has no power-flow direction.",
        ))

        values = Any[raw[row, column] for column in positions]
        values[1] = current_flow_path
        values[3] = current_direction
        push!(table, values)
        push!(source_rows, source_row)
    end

    _isp2026_network_provenance!(table, path, spec, source_rows)
    return _isp2026_network_require_unique(
        table,
        [Symbol("Flow path"), Symbol("Option"), Symbol("Power-flow direction")],
        spec,
    )
end
