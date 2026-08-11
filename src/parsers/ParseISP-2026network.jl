"""Source-faithful readers for the ISP 2026 network input tables."""

_isp2026_network_text(value) = ismissing(value) ? "" : strip(string(value))

"""Read the ISP 2026 network-capability records without mapping flow paths."""
function read_isp2026_network_capability(path::AbstractString)
    spec = source_spec(:network_capability, 2026)
    raw = read_xlsx_rows(path, spec)
    table = DataFrame(raw, Symbol.(getfield.(spec.columns, :name)))
    insertcols!(table, 1, :source_row => collect(8:25))
    return table
end

"""Read the ISP 2026 transmission-reliability records without positional mapping."""
function read_isp2026_transmission_reliability(path::AbstractString)
    spec = source_spec(:transmission_reliability, 2026)
    table = read_xlsx_with_header(path, spec; validate_columns = true)
    insertcols!(table, 1, :source_row => collect(8:13))
    return table
end

"""Read the semantic ISP 2026 flow-path augmentation option records.

Flow-path labels merged across option rows are filled down. All other missing source
values remain missing, and no bus mapping or output projection is applied.
"""
function read_isp2026_flow_path_augmentation_options(path::AbstractString)
    spec = source_spec(:flow_path_augmentation_options, 2026)
    raw = read_xlsx_rows(path, spec)
    table = DataFrame(Symbol(name) => Any[] for name in getfield.(spec.columns, :name))
    source_rows = Int[]
    current_flow_path = missing

    for row in axes(raw, 1)
        if all(ismissing, raw[row, :])
            current_flow_path = missing
            continue
        end

        option = _isp2026_network_text(raw[row, 4])
        (isempty(option) || option == "Option name") && continue

        flow_path = raw[row, 1]
        isempty(_isp2026_network_text(flow_path)) || (current_flow_path = flow_path)

        values = Any[raw[row, column] for column in axes(raw, 2)]
        values[1] = current_flow_path
        push!(table, values)
        push!(source_rows, row + 10)
    end

    insertcols!(table, 1, :source_row => source_rows)
    return table
end
