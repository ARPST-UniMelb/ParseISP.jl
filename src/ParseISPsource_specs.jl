"""Common abstraction for one semantic ParseISP source definition."""
abstract type SourceSpec end

"""Expected column metadata for a source table."""
struct ColumnSpec
    name::String
    required::Bool
    data_type::Union{Nothing,Symbol}
    unit::Union{Nothing,String}
    description::String
end

function ColumnSpec(;
    name,
    required::Bool = true,
    data_type = nothing,
    unit = nothing,
    description = "",
)
    column_name = strip(string(name))
    isempty(column_name) && throw(ArgumentError("ColumnSpec.name must not be empty."))

    return ColumnSpec(
        column_name,
        required,
        data_type === nothing ? nothing : Symbol(data_type),
        unit === nothing ? nothing : strip(string(unit)),
        strip(string(description)),
    )
end

"""Excel workbook source location and expected table schema."""
struct XlsxSourceSpec <: SourceSpec
    id::Symbol
    edition::Int
    workbook::String
    worksheet::String
    cell_range::Union{Nothing,String}
    description::String
    columns::Vector{ColumnSpec}
    source_family::Symbol
    consumer::Union{Nothing,Symbol}
end

function XlsxSourceSpec(;
    id,
    edition,
    workbook,
    worksheet,
    cell_range = nothing,
    description,
    columns = ColumnSpec[],
    source_family = :unspecified,
    consumer = nothing,
)
    spec = XlsxSourceSpec(
        Symbol(id),
        Int(edition),
        strip(string(workbook)),
        strip(string(worksheet)),
        cell_range === nothing ? nothing : strip(string(cell_range)),
        strip(string(description)),
        ColumnSpec[columns...],
        Symbol(source_family),
        consumer === nothing ? nothing : Symbol(consumer),
    )
    return validate_source_spec(spec)
end

"""CSV filename selection and expected table schema."""
struct CsvSourceSpec <: SourceSpec
    id::Symbol
    edition::Int
    filename_pattern::String
    description::String
    columns::Vector{ColumnSpec}
    keys::Vector{String}
    source_family::Symbol
    consumer::Union{Nothing,Symbol}
end

function CsvSourceSpec(;
    id,
    edition,
    filename_pattern,
    description,
    columns = ColumnSpec[],
    keys = String[],
    source_family = :unspecified,
    consumer = nothing,
)
    spec = CsvSourceSpec(
        Symbol(id),
        Int(edition),
        strip(string(filename_pattern)),
        strip(string(description)),
        ColumnSpec[columns...],
        string.(keys),
        Symbol(source_family),
        consumer === nothing ? nothing : Symbol(consumer),
    )
    return validate_source_spec(spec)
end

"""Validated collection of source definitions for one ISP edition."""
struct SourceSpecRegistry
    edition::Int
    specs::Vector{SourceSpec}

    function SourceSpecRegistry(edition::Integer, specs::AbstractVector{<:SourceSpec})
        registry_edition = Int(edition)
        registered = SourceSpec[specs...]
        all(spec -> spec.edition == registry_edition, registered) ||
            throw(ArgumentError("Every source specification must match registry edition $(registry_edition)."))

        ids = getfield.(registered, :id)
        length(ids) == length(unique(ids)) ||
            throw(ArgumentError("Source specification identifiers must be unique within edition $(registry_edition)."))

        foreach(validate_source_spec, registered)
        sort!(registered; by = spec -> string(spec.id))
        new(registry_edition, registered)
    end
end

"""Structural comparison of one semantic source between two ISP editions."""
struct SourceSpecDiff
    id::Symbol
    source_family::Symbol
    status::Symbol
    previous::Union{Nothing,SourceSpec}
    current::Union{Nothing,SourceSpec}
    columns_added::Vector{String}
    columns_removed::Vector{String}
    units_changed::Vector{String}
    types_changed::Vector{String}
end

const SOURCE_SPECS = SourceSpec[]

source_format(::XlsxSourceSpec) = :xlsx
source_format(::CsvSourceSpec) = :csv

function resolve_source_pattern(pattern::AbstractString; replacements...)
    resolved = String(pattern)
    for (name, value) in replacements
        resolved = replace(resolved, "{$(name)}" => string(value))
    end

    unresolved = match(r"\{[^{}]+\}", resolved)
    unresolved === nothing || throw(ArgumentError(
        "Unresolved source-pattern token $(unresolved.match) in `$(pattern)`.",
    ))
    return resolved
end

source_path(root::AbstractString, spec::XlsxSourceSpec; replacements...) =
    normpath(root, resolve_source_pattern(spec.workbook; replacements...))

source_path(root::AbstractString, spec::CsvSourceSpec; replacements...) =
    normpath(root, resolve_source_pattern(spec.filename_pattern; replacements...))

function is_valid_excel_range(cell_range::AbstractString)
    return occursin(
        r"^\$?[A-Za-z]{1,3}(?:\$?\d+)?(?::\$?[A-Za-z]{1,3}(?:\$?\d+)?)?$",
        cell_range,
    )
end

function _validate_columns(columns::Vector{ColumnSpec}, source_id::Symbol)
    names = getfield.(columns, :name)
    length(names) == length(unique(names)) ||
        throw(ArgumentError("Column names must be unique within source specification $(source_id)."))
    return nothing
end

function validate_source_spec(spec::XlsxSourceSpec)
    spec.edition > 0 || throw(ArgumentError("Source specification edition must be positive."))
    isempty(string(spec.id)) && throw(ArgumentError("XlsxSourceSpec.id must not be empty."))
    isempty(spec.workbook) && throw(ArgumentError("XlsxSourceSpec.workbook must not be empty."))
    isempty(spec.worksheet) && throw(ArgumentError("XlsxSourceSpec.worksheet must not be empty."))
    isempty(spec.description) && throw(ArgumentError("XlsxSourceSpec.description must not be empty."))
    spec.source_family == :unspecified &&
        throw(ArgumentError("XlsxSourceSpec.source_family must be specified for source $(spec.id)."))
    spec.cell_range === nothing || is_valid_excel_range(spec.cell_range) ||
        throw(ArgumentError("Invalid Excel range `$(spec.cell_range)` for source $(spec.id)."))
    _validate_columns(spec.columns, spec.id)
    return spec
end

function validate_source_spec(spec::CsvSourceSpec)
    spec.edition > 0 || throw(ArgumentError("Source specification edition must be positive."))
    isempty(string(spec.id)) && throw(ArgumentError("CsvSourceSpec.id must not be empty."))
    isempty(spec.filename_pattern) &&
        throw(ArgumentError("CsvSourceSpec.filename_pattern must not be empty."))
    isempty(spec.description) && throw(ArgumentError("CsvSourceSpec.description must not be empty."))
    spec.source_family == :unspecified &&
        throw(ArgumentError("CsvSourceSpec.source_family must be specified for source $(spec.id)."))
    length(spec.keys) == length(unique(spec.keys)) ||
        throw(ArgumentError("CSV keys must be unique within source specification $(spec.id)."))
    _validate_columns(spec.columns, spec.id)
    if !isempty(spec.columns)
        column_names = Set(getfield.(spec.columns, :name))
        unknown_keys = setdiff(Set(spec.keys), column_names)
        isempty(unknown_keys) || throw(ArgumentError(
            "CSV keys must be declared as columns for source $(spec.id): " *
            join(sort!(collect(unknown_keys)), ", "),
        ))
    end
    return spec
end

function register_source_specs!(specs::SourceSpec...)
    seen = Set((spec.edition, spec.id) for spec in SOURCE_SPECS)
    for spec in specs
        validate_source_spec(spec)
        key = (spec.edition, spec.id)
        key in seen && throw(ArgumentError(
            "Source specification $(spec.id) is already registered for edition $(spec.edition).",
        ))
        push!(seen, key)
    end
    append!(SOURCE_SPECS, specs)
    return nothing
end

source_specs(edition::Integer) = source_specs(Val(Int(edition)))
function source_specs(::Val{E}) where {E}
    specs = SourceSpec[spec for spec in SOURCE_SPECS if spec.edition == Int(E)]
    return sort!(specs; by = spec -> string(spec.id))
end

source_spec_registry(edition::Integer) = source_spec_registry(Val(Int(edition)))
source_spec_registry(::Val{E}) where {E} = SourceSpecRegistry(Int(E), source_specs(Val(E)))

function source_spec(id, edition::Integer)
    source_id = Symbol(id)
    matches = filter(spec -> spec.id == source_id, source_specs(edition))
    isempty(matches) && throw(KeyError((edition, source_id)))
    return only(matches)
end

function _source_location(spec::XlsxSourceSpec)
    return (spec.workbook, spec.worksheet, spec.cell_range)
end

_source_location(spec::CsvSourceSpec) = (spec.filename_pattern,)

_column_signature(column::ColumnSpec) = (
    column.name,
    column.required,
    column.data_type,
    column.unit,
    column.description,
)

_source_schema(spec::XlsxSourceSpec) = (_column_signature.(spec.columns),)
_source_schema(spec::CsvSourceSpec) = (_column_signature.(spec.columns), spec.keys)

function _column_changes(previous::SourceSpec, current::SourceSpec)
    previous_columns = Dict(column.name => column for column in previous.columns)
    current_columns = Dict(column.name => column for column in current.columns)
    previous_names = Set(keys(previous_columns))
    current_names = Set(keys(current_columns))

    columns_added = sort!(collect(setdiff(current_names, previous_names)))
    columns_removed = sort!(collect(setdiff(previous_names, current_names)))
    common_names = sort!(collect(intersect(previous_names, current_names)))

    units_changed = String[]
    types_changed = String[]
    for name in common_names
        old_column = previous_columns[name]
        new_column = current_columns[name]
        old_column.unit == new_column.unit || push!(
            units_changed,
            "$(name): $(something(old_column.unit, "nothing")) -> $(something(new_column.unit, "nothing"))",
        )
        old_column.data_type == new_column.data_type || push!(
            types_changed,
            "$(name): $(something(old_column.data_type, :nothing)) -> $(something(new_column.data_type, :nothing))",
        )
    end

    return columns_added, columns_removed, units_changed, types_changed
end

function compare_source_specs(
    previous::SourceSpecRegistry,
    current::SourceSpecRegistry,
)
    previous_by_id = Dict(spec.id => spec for spec in previous.specs)
    current_by_id = Dict(spec.id => spec for spec in current.specs)
    source_ids = sort!(
        unique(vcat(collect(keys(previous_by_id)), collect(keys(current_by_id))));
        by = string,
    )
    diffs = SourceSpecDiff[]

    for source_id in source_ids
        previous_spec = get(previous_by_id, source_id, nothing)
        current_spec = get(current_by_id, source_id, nothing)

        if previous_spec === nothing
            push!(diffs, SourceSpecDiff(
                source_id,
                current_spec.source_family,
                :added,
                nothing,
                current_spec,
                sort!(getfield.(current_spec.columns, :name)),
                String[],
                String[],
                String[],
            ))
            continue
        elseif current_spec === nothing
            push!(diffs, SourceSpecDiff(
                source_id,
                previous_spec.source_family,
                :removed,
                previous_spec,
                nothing,
                String[],
                sort!(getfield.(previous_spec.columns, :name)),
                String[],
                String[],
            ))
            continue
        end

        columns_added, columns_removed, units_changed, types_changed =
            _column_changes(previous_spec, current_spec)
        location_changed = source_format(previous_spec) != source_format(current_spec) ||
            _source_location(previous_spec) != _source_location(current_spec)
        schema_changed = _source_schema(previous_spec) != _source_schema(current_spec)
        status = if !location_changed && !schema_changed
            :unchanged
        elseif location_changed && !schema_changed
            :location_changed
        elseif !location_changed && schema_changed
            :schema_changed
        else
            :manual_review_required
        end

        push!(diffs, SourceSpecDiff(
            source_id,
            current_spec.source_family,
            status,
            previous_spec,
            current_spec,
            columns_added,
            columns_removed,
            units_changed,
            types_changed,
        ))
    end

    return diffs
end

compare_source_specs(previous::Integer, current::Integer) = compare_source_specs(
    source_spec_registry(previous),
    source_spec_registry(current),
)

_column_record(column::ColumnSpec) = (
    name = column.name,
    required = column.required,
    data_type = column.data_type === nothing ? nothing : string(column.data_type),
    unit = column.unit,
    description = column.description,
)

function source_spec_record(spec::XlsxSourceSpec)
    return (
        id = string(spec.id),
        edition = spec.edition,
        source_format = "xlsx",
        workbook = spec.workbook,
        worksheet = spec.worksheet,
        cell_range = spec.cell_range,
        filename_pattern = nothing,
        description = spec.description,
        columns = _column_record.(spec.columns),
        keys = String[],
        source_family = string(spec.source_family),
        consumer = spec.consumer === nothing ? nothing : string(spec.consumer),
    )
end

function source_spec_record(spec::CsvSourceSpec)
    return (
        id = string(spec.id),
        edition = spec.edition,
        source_format = "csv",
        workbook = nothing,
        worksheet = nothing,
        cell_range = nothing,
        filename_pattern = spec.filename_pattern,
        description = spec.description,
        columns = _column_record.(spec.columns),
        keys = copy(spec.keys),
        source_family = string(spec.source_family),
        consumer = spec.consumer === nothing ? nothing : string(spec.consumer),
    )
end

source_spec_records(registry::SourceSpecRegistry) = source_spec_record.(registry.specs)
source_spec_records(edition::Integer) = source_spec_records(source_spec_registry(edition))

function _column_summary(columns::Vector{ColumnSpec})
    return join((column.required ? column.name : "$(column.name)?" for column in columns), "; ")
end

function _unit_summary(columns::Vector{ColumnSpec})
    return join(("$(column.name)=$(column.unit)" for column in columns if column.unit !== nothing), "; ")
end

function source_spec_row(spec::XlsxSourceSpec)
    return (
        id = string(spec.id),
        edition = spec.edition,
        source_format = "xlsx",
        workbook_or_pattern = spec.workbook,
        worksheet = spec.worksheet,
        cell_range = something(spec.cell_range, ""),
        columns = _column_summary(spec.columns),
        units = _unit_summary(spec.columns),
        keys = "",
        source_family = string(spec.source_family),
        consumer = spec.consumer === nothing ? "" : string(spec.consumer),
        description = spec.description,
    )
end

function source_spec_row(spec::CsvSourceSpec)
    return (
        id = string(spec.id),
        edition = spec.edition,
        source_format = "csv",
        workbook_or_pattern = spec.filename_pattern,
        worksheet = "",
        cell_range = "",
        columns = _column_summary(spec.columns),
        units = _unit_summary(spec.columns),
        keys = join(spec.keys, "; "),
        source_family = string(spec.source_family),
        consumer = spec.consumer === nothing ? "" : string(spec.consumer),
        description = spec.description,
    )
end

source_spec_rows(registry::SourceSpecRegistry) = source_spec_row.(registry.specs)
source_spec_rows(edition::Integer) = source_spec_rows(source_spec_registry(edition))

_optional_location(spec::Nothing, field::Symbol) = ""
function _optional_location(spec::XlsxSourceSpec, field::Symbol)
    value = getfield(spec, field)
    return value === nothing ? "" : string(value)
end
_optional_location(spec::CsvSourceSpec, field::Symbol) = field == :workbook ? spec.filename_pattern : ""

function source_spec_diff_row(diff::SourceSpecDiff)
    return (
        source_id = string(diff.id),
        source_family = string(diff.source_family),
        status = string(diff.status),
        workbook_previous = _optional_location(diff.previous, :workbook),
        workbook_current = _optional_location(diff.current, :workbook),
        worksheet_previous = _optional_location(diff.previous, :worksheet),
        worksheet_current = _optional_location(diff.current, :worksheet),
        range_previous = _optional_location(diff.previous, :cell_range),
        range_current = _optional_location(diff.current, :cell_range),
        columns_added = join(diff.columns_added, "; "),
        columns_removed = join(diff.columns_removed, "; "),
        units_changed = join(diff.units_changed, "; "),
        types_changed = join(diff.types_changed, "; "),
        description = something(
            diff.current === nothing ? nothing : diff.current.description,
            diff.previous === nothing ? "" : diff.previous.description,
        ),
    )
end

source_spec_diff_rows(diffs::AbstractVector{SourceSpecDiff}) = source_spec_diff_row.(diffs)

include("source_specs/ParseISP-2026specs.jl")
